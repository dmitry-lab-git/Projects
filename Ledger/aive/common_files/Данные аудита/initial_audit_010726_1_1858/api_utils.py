import sys
import time
import logging
import json
from decimal import Decimal
from datetime import date, datetime
from tqdm import tqdm
from google.api_core import exceptions
from google.genai.errors import ServerError
import random
from zoneinfo import ZoneInfo
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn

""" | Часовой пояс / Событие          | Зимнее время (PST) | Летнее время (PDT) |
    | :------------------------------ | :----------------- | :----------------- |
    | **Время в Калифорнии (Google)** | 00:00 (Полночь)    | 00:00 (Полночь)    |
    | **Время на ПК**                 | 13:00              | 12:00              |
    | **Время в БД**                  | **08:00**          | **07:00**          |

*Примечание: База данных отстает от ПК на 5 часов (БД = ПК - 5).* """

MODEL_LIMITS = {
    "gemini-2.5-flash": {
        "max_rpm": 5,
        "max_tpm": 250000,
        "max_rpd": 20
    },
    "gemini-3.5-flash": {  # Название модели для API может отличаться, проверьте в документации
        "max_rpm": 5,
        "max_tpm": 250000,
        "max_rpd": 18
    },
    "gemini-3.1-flash-lite": { # Название модели для API может отличаться, проверьте в документации
        "max_rpm": 15,
        "max_tpm": 250000,
        "max_rpd": 500
    },
    "gemini-2.5-flash-lite": {
        "max_rpm": 10,
        "max_tpm": 250000,
        "max_rpd": 20
    },
    "gemma-4-31b": {
        "max_rpm": 15,
        "max_tpm": 1000000,
        "max_rpd": 1500
    }
}

def get_google_quota_reset_timestamp():
    """
    Автоматически рассчитывает начало текущих суток по времени Калифорнии (PT)
    и возвращает метку времени в UTC для базы данных.
    Учитывает переходы на зимнее/летнее время сам.
    """
    # 1. Текущее время в Калифорнии (PT)
    tz_california = ZoneInfo("America/Los_Angeles")
    now_california = datetime.now(tz_california)
    
    # 2. Сбрасываем время на полночь (00:00:00) по калифорнийскому времени
    midnight_california = now_california.replace(hour=0, minute=0, second=0, microsecond=0)
    
    # 3. Переводим эту полночь в UTC
    midnight_utc = midnight_california.astimezone(timezone.utc)
    
    # Возвращаем строку в формате для Postgres (например: '2026-07-01 07:00:00+00')
    return midnight_utc.strftime('%Y-%m-%d %H:%M:%S%z')

def get_current_metrics(conn, model_name, reset_timestamp):
    """
    Высчитывает текущие RPM, TPM и RPD на основе таблицы processing.aive_requests_log.
    В логах время по UTC+0. 
    Расчет суточных квот (RPD, успехи, КПД) ведется строго с момента reset_timestamp.
    """
    query = """
        SELECT 
            -- 1. RPM: Кол-во запросов за последнюю минуту (исключая PENDING)
            COUNT(id) FILTER (
                WHERE created_at >= NOW() AT TIME ZONE 'UTC' - INTERVAL '1 minute'
                AND status != 'PENDING'
            ) as rpm,

            -- 2. TPM: Сумма input + output токенов за последнюю минуту
            COALESCE(SUM(COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0)) FILTER (
                WHERE created_at >= NOW() AT TIME ZONE 'UTC' - INTERVAL '1 minute'
                AND status != 'PENDING'
            ), 0) as tpm,

            -- 3. RPD (total_quota_usage): Расход квоты с момента обновления API
            COUNT(id) FILTER (
                WHERE status != 'PENDING' 
                AND created_at >= %s::timestamp
            ) as total_quota_usage,

            -- 4. Успешные запросы с момента обновления API
            COUNT(id) FILTER (
                WHERE status = 'FINISHED' 
                AND created_at >= %s::timestamp
            ) as successful_requests,

            -- 5. КПД (процент успеха) с момента обновления API
            ROUND(
                (COUNT(id) FILTER (
                    WHERE status = 'FINISHED' 
                    AND created_at >= %s::timestamp
                ))::numeric / 
                NULLIF(COUNT(id) FILTER (
                    WHERE status != 'PENDING' 
                    AND created_at >= %s::timestamp
                ), 0) * 100, 
                2
            ) as success_rate_percent
        FROM processing.aive_requests_log
        WHERE model_used = %s;
    """
    
    try:
        # Сброс контекста транзакции
        conn.rollback()
        
        with conn.cursor() as cur:
            # 1. Посмотрим последние записи для верификации
            cur.execute(
                "SELECT status, created_at FROM processing.aive_requests_log WHERE model_used = %s ORDER BY created_at DESC LIMIT 5", 
                (model_name,)
            )
            logging.debug(f"Последние 5 статусов для {model_name}: {cur.fetchall()}")

            # 2. Выполняем основной расчет метрик
            # Передаем reset_timestamp 4 раза для блоков фильтрации суток и 1 раз имя модели
            cur.execute(
                query, 
                (
                    reset_timestamp, 
                    reset_timestamp, 
                    reset_timestamp, 
                    reset_timestamp, 
                    model_name
                )
            )
            row = cur.fetchone()
            
            if row:
                return {
                    "rpm": row[0] if row[0] is not None else 0, 
                    "tpm": int(row[1]) if row[1] is not None else 0, 
                    "total_quota_usage": row[2] if row[2] is not None else 0, 
                    "successful_requests": row[3] if row[3] is not None else 0, 
                    "success_rate": float(row[4]) if row[4] is not None else 100.0 
                }
    except Exception as e:
        logging.error(f"Не удалось получить метрики квот из БД: {e}")
        conn.rollback()
        
    return {"rpm": 0, "tpm": 0, "total_quota_usage": 0, "successful_requests": 0, "success_rate": 100.0}

# --- Утилиты сериализации ---
def json_serial(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, (date, datetime)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")

# --- UI и Таймеры ---
def countdown_timer(seconds):
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        transient=True, # Автоматически удаляет прогресс-бар после завершения
    ) as progress:
        task = progress.add_task("Ожидание...", total=seconds)
        for _ in range(seconds):
            time.sleep(1)
            progress.update(task, advance=1)

# --- Логирование БД ---
def log_request_start(conn, source_uuid, request_text, model_name, in_tokens):
    query = """
        INSERT INTO processing.aive_requests_log 
        (source_extraction_id, model_used, request_payload, status, input_tokens)
        VALUES (%s, %s, %s, 'PENDING', %s)
        RETURNING id;
    """
    with conn.cursor() as cur:
        cur.execute(query, (source_uuid, model_name, request_text, in_tokens))
        request_id = cur.fetchone()[0]
    conn.commit()
    return request_id

def log_request_finish(conn, request_id, response_text, status, out_tokens, error_msg=None):
    query = """
        UPDATE processing.aive_requests_log 
        SET response_payload = %s, status = %s, output_tokens = %s, 
            error_message = %s, response_received_at = CURRENT_TIMESTAMP
        WHERE id = %s;
    """
    with conn.cursor() as cur:
        # Теперь статус может быть 'FINISHED', 'ERROR_LIMIT' и т.д.
        cur.execute(query, (response_text, status, out_tokens, error_msg, request_id))
    conn.commit()

def log_request_retry(conn, request_id, retry_status):
    # Мы делаем INSERT, а не UPDATE, если хотим видеть историю попыток
    # Но для простоты: обновим текущий статус, чтобы он перестал быть PENDING
    query = """
        UPDATE processing.aive_requests_log 
        SET status = %s, response_received_at = CURRENT_TIMESTAMP
        WHERE id = %s;
    """
    with conn.cursor() as cur:
        cur.execute(query, (retry_status, request_id))
    conn.commit()

# --- Ядро API ---
def secure_api_call(client, prompt_text, conn, source_uuid, 
                    model_name="gemini-3.1-flash-lite", 
                    max_prompt_weight=10000, max_retries=3):
    logging.info(f"API ЗАПРОС: ID сессии {source_uuid}")

    # 1. Проверка веса
    token_count = client.models.count_tokens(model=model_name, contents=prompt_text)
    input_tokens = token_count.total_tokens
    
    if input_tokens > max_prompt_weight:
        logging.warning(f"[ОТКАЗ] Превышен бюджет: {input_tokens} > {max_prompt_weight}")
        return None

    # ВЫЧИСЛЕНИЕ МЕТРИК НА ОСНОВЕ ЛОГОВ БД
    metrics = get_current_metrics(conn, model_name)
    
    # Считаем прогноз по токенам (текущие в базе + вес нового промпта)
    estimated_tpm = metrics["tpm"] + input_tokens 

    limits = MODEL_LIMITS.get(model_name, {"max_rpm": 5, "max_tpm": 250000, "max_rpd": 20})
    
    print(f"\n"
          f"====================== [МОНИТОРИНГ КВОТ БД] ======================\n"
          f" Модель: {model_name}\n"
          f" -> Текущий RPM: {metrics['rpm']} / {limits['max_rpm']} запросов/мин\n"
          f" -> Текущий TPM: {estimated_tpm} / {limits['max_tpm']} токенов/мин\n"
          f" -> Расход квоты (RPD): {metrics['total_quota_usage']} / {limits['max_rpd']} запросов/сутки\n"
          f" -> Успешных батчей: {metrics['successful_requests']} (КПД: {metrics['success_rate']}%)\n"
          f"==================================================================")

    logging.info(
        f"Квоты перед запросом: RPM={metrics['rpm']}/{limits['max_rpm']}, "
        f"TPM={estimated_tpm}/{limits['max_tpm']}, "
        f"RPD_Usage={metrics['total_quota_usage']}/{limits['max_rpd']} (Успех: {metrics['success_rate']}%)"
    )

    # ==================== ЗАЩИТА НА ПРЕВЫШЕНИЕ (RATE LIMITER) ====================
    
    # Защита 1: Суточный лимит (RPD) - используем total_quota_usage
    if metrics["total_quota_usage"] >= limits["max_rpd"]:
        logging.critical(f"[ЗАЩИТА] Суточный лимит {limits['max_rpd']} запросов ИСЧЕРПАН. Запрос заблокирован.")
        # Мягкий выход без Traceback, чтобы закрыть соединения с БД
        return 

    # Защита 2: Лимит токенов в минуту (TPM)
    if estimated_tpm >= limits["max_tpm"]:
        logging.warning(f"[ЗАЩИТА] Близко к превышению лимита токенов (TPM). Ожидаем сброса минуты...")
        time.sleep(15) 
        # Пересчитываем метрики после паузы
        metrics = get_current_metrics(conn, model_name)
        estimated_tpm = metrics["tpm"] + input_tokens

    # Защита 3: Минутный лимит запросов (RPM)
    if metrics["rpm"] >= limits["max_rpm"]:
        wait_seconds = 10
        logging.warning(f"[ЗАЩИТА] Достигнут лимит запросов в минуту ({metrics['rpm']}/{limits['max_rpm']}). Пауза {wait_seconds} сек...")
        time.sleep(wait_seconds)
        # Пересчитываем метрики, чтобы актуализировать данные перед выполнением запроса
        metrics = get_current_metrics(conn, model_name)

    # ==============================================================================

    request_id = log_request_start(conn, source_uuid, prompt_text, model_name, input_tokens)

    # 2. Исполнение с экспоненциальной задержкой
    for attempt in range(1, max_retries + 1):
        try:
            response = client.models.generate_content(model=model_name, contents=prompt_text)
            current_res_text = response.text if response and response.text else "[]"
            out_t = response.usage_metadata.candidates_token_count if response.usage_metadata else 0
            
            log_request_finish(conn, request_id, current_res_text, "FINISHED", out_t)

            # Плановая пауза после успешной обработки
            pacing_delay = 7  
            logging.info(f"Запрос успешно обработан. Плановая пауза {pacing_delay} сек перед следующим батчем...")
            time.sleep(pacing_delay)

            return current_res_text

        except ServerError as e:
            # Общее логирование попытки (через UPDATE в БД)
            attempt_label = f"RETRY_{e.code}_{attempt}"
            log_request_retry(conn, request_id, attempt_label)
            
            # Индивидуальная логика задержек
            if e.code == 503:
                wait_time = (20 * attempt) + random.uniform(0, 5)
                logging.warning(f"Сервер перегружен (503). Попытка {attempt}. Ждем {wait_time:.2f} сек.")
            
            elif e.code == 429:
                error_msg = str(e).lower()
                
                # 1. Проверка СУТОЧНОГО лимита
                if "free_tier_requests" in error_msg or "daily" in error_msg:
                    logging.critical(f"\n[КРИТИЧЕСКИЙ ОСТАНОВ] Превышен СУТОЧНЫЙ лимит запросов для {model_name}. Процесс остановлен.")
                    log_request_finish(conn, request_id, "NO_RESPONSE", "ERROR", 0, error_msg="DAILY_QUOTA_EXHAUSTED")
                    raise SystemExit("Работа завершена: исчерпан дневной лимит.")
                
                # 2. Проверка МИНУТНОГО лимита
                elif "requests_per_minute" in error_msg or "rpm" in error_msg or "limit: 20" in error_msg:
                    logging.critical(f"\n[КРИТИЧЕСКИЙ ОСТАНОВ] Превышена частота запросов в минуту (RPM) для {model_name}. Повторы заблокированы.")
                    log_request_finish(conn, request_id, "NO_RESPONSE", "ERROR", 0, error_msg="RPM_QUOTA_EXHAUSTED")
                    raise SystemExit("Работа завершена: превышен минутный лимит запросов.")
                
                # 3. Проверка лимита на ТОКЕНЫ (TPM)
                elif "tokens" in error_msg or "tpm" in error_msg:
                    logging.critical(f"\n[КРИТИЧЕСКИЙ ОСТАНОВ] Превышен лимит обработки токенов (TPM) для {model_name}. Объём текста слишком велик.")
                    log_request_finish(conn, request_id, "NO_RESPONSE", "ERROR", 0, error_msg="TOKEN_QUOTA_EXHAUSTED")
                    raise SystemExit("Работа завершена: превышена квота на количество токенов.")
                
                # Общий случай для остальных ошибок 429
                else:
                    logging.critical(f"\n[КРИТИЧЕСКИЙ ОСТАНОВ] Неизвестное ограничение квоты (429): {error_msg}")
                    log_request_finish(conn, request_id, "NO_RESPONSE", "ERROR", 0, error_msg="QUOTA_EXHAUSTED")
                    raise SystemExit("Работа завершена: превышены лимиты ресурса API.")
            
            else:
                # 500, 502 и другие
                wait_time = (10 * attempt) + random.uniform(0, 5)
                logging.error(f"Редкая ошибка API ({e.code}). Попытка {attempt}. Ждем {wait_time:.2f} сек.")
            
            # Финал для обоих случаев
            if attempt == max_retries:
                log_request_finish(conn, request_id, "NO_RESPONSE", "ERROR_LIMIT", 0, 
                                   error_msg=f"Исчерпаны попытки ({attempt}). Ошибка: {str(e)}")
                return None
                
            time.sleep(wait_time)
