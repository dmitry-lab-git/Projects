#api_utils.py
import logging
import random
import time
from zoneinfo import ZoneInfo
from datetime import datetime, timezone
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
from rich.console import Console
from rich.table import Table
from rich.panel import Panel

# Сторонние библиотеки
from google.api_core import exceptions as google_exceptions

# Конфигурация проекта (Уже было верно)
from api_manager.config import ALLOWED_MODELS, BLOCKED_MODELS, MODEL_LIMITS, DEFAULT_MAX_RETRIES
from api_manager import config

# ИСПРАВЛЕНО: Абсолютные импорты от корня папки aive
from api_manager.exceptions import (
    SecureAPIError, 
    QuotaExhaustedError, 
    ContentPolicyViolationError, 
    ExceptionHandler
)

from api_manager.db_utils.db_utils import (
    log_request_start, 
    log_request_finish, 
    log_request_retry, 
    get_current_metrics,
    check_system_overload
)

def display_report(report):
    console = Console()
    
    table = Table(show_header=True, header_style="bold magenta")
    table.add_column("Параметр", style="dim")
    table.add_column("Статус / Значение")
    
    for key, value in report.items():
        # Красивое форматирование ключа
        display_key = key.replace('_', ' ').capitalize()
        # Добавляем цвет в зависимости от статуса
        display_val = f"[green]{value}[/green]" if "PASSED" in str(value) else f"[red]{value}[/red]"
        table.add_row(display_key, display_val)
        
    console.print(Panel(table, title="[bold blue]Отчет валидации системы[/bold blue]", expand=False))

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

# --- UI и Таймеры ---
def countdown_timer(seconds):
    """Аккуратный визуальный таймер для ожидания."""
    # Преобразуем float в int, так как range принимает целые числа
    int_seconds = max(1, int(seconds))
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        transient=True,
    ) as progress:
        task = progress.add_task(f"Ожидание {int_seconds}с...", total=int_seconds)
        for _ in range(int_seconds):
            time.sleep(1)
            progress.update(task, advance=1)


def model_rotation(conn, client, current_model, prompt_text, report):
    """Выполняет поиск альтернативы и повторную валидацию."""
    recommended_delay = report.get('dynamic_delay', 0)
    
    if recommended_delay <= 0:
        return current_model, None # Нет задержки — ротация не нужна

    logging.info(f"[{current_model}] Перегрузка, ищем альтернативу...")
    alt_model = check_actual_model(conn, exclude_model=current_model)
    
    if alt_model != current_model:
        logging.info(f"-> Найдена альтернатива: {alt_model}")
        _, input_tokens, metrics, new_report, reset_time = validate_system_state(
            conn, client, alt_model, prompt_text
        )
        return alt_model, input_tokens
    
    # Если альтернатив нет — возвращаем текущую и принудительный delay
    logging.warning(f"Альтернатив нет. Задержка {recommended_delay} сек.")
    if recommended_delay > 3:
        countdown_timer(recommended_delay)
    else:
        time.sleep(recommended_delay)
    
    return current_model, None

def execute_with_retry(client, model_name, prompt_text, conn, request_id):
    """
    Выполняет запрос к Gemini API с автоматическим повтором при ошибках,
    а также гарантирует запись результатов в БД.
    """
    for attempt in range(1, config.DEFAULT_MAX_RETRIES + 1):
        try:
            # 1. Сетевой запрос к API
            response = client.models.generate_content(model=model_name, contents=prompt_text)
            logging.info(f"Получен ответ от модели (Попытка {attempt})")
            
            # 2. Безопасное извлечение данных из ответа
            current_res_text = response.text if hasattr(response, 'text') and response.text else "[]"
            out_t = response.usage_metadata.candidates_token_count if hasattr(response, 'usage_metadata') else 0
            
            # Валидация контента
            if not current_res_text or current_res_text == "[]":
                raise ValueError("Критическая ошибка: Модель вернула пустой ответ.")

            # 3. Защищенная запись успешного исхода в БД
            try:
                log_request_finish(conn, request_id, current_res_text, "FINISHED", out_t)
                logging.info(f"✅ [БД] Ответ успешно сохранен для ID: {request_id}")
            except Exception as db_err:
                # Полный останов системы при потере данных в БД
                logging.critical(
                    f"❌ [КРИТИЧЕСКАЯ ОШИБКА] Ответ получен, но запись в БД не удалась! "
                    f"ID: {request_id}. Ошибка: {db_err}"
                )
                raise SystemExit("Остановка системы из-за сбоя записи финального статуса в БД.") from db_err

            # Пейсинг-пауза после успешного выполнения (если предусмотрена процессом)
            if hasattr(config, 'PACING_DELAY'):
                countdown_timer(config.PACING_DELAY)
                
            # Возвращаем результат, выходя из функции и цикла
            return current_res_text

        except Exception as e:
            # Защита: пропускаем системные выходы, чтобы они не попали в логику обработки ошибок API
            if isinstance(e, SystemExit):
                raise e
            
            logging.error(f"Ошибка на попытке {attempt}: {e}")
            
            # Единая точка интеграции: метод handle сам вернет нужный словарь
            decision = ExceptionHandler.handle(e, attempt, model_name=model_name)
            
            if decision["action"] == "RETRY":
                log_request_retry(conn, request_id, decision["status_key"])
                
                # Расчет времени ожидания с учетом данных из API или стандартного backoff
                wait_time = decision["delay"] or ((2 ** attempt) + random.uniform(1, 3))
                
                logging.info(f"Ожидание {wait_time:.2f} сек перед следующей попыткой...")
                countdown_timer(wait_time) 
                continue 
            
            # Если действие НЕ "RETRY", логируем финальный отказ и поднимаем исключение дальше
            log_request_finish(
                conn, 
                request_id, 
                None, 
                decision["status_key"], 
                0, 
                error_msg=decision["error_msg"]
            )
            raise e

    # 4. Если цикл завершился, а лимит попыток исчерпан
    log_request_finish(conn, request_id, None, "ERROR_RETRY", 0, error_msg="MAX_RETRIES_EXCEEDED")
    raise RuntimeError(f"Исчерпаны все {config.DEFAULT_MAX_RETRIES} попытки для модели {model_name}")

def handle_api_exception(raw_error, conn, request_id, attempt, model_name):
    """
    Централизованный диспетчер исключений.
    
    1. Автоматически переводит сырую ошибку Google SDK в наш доменный класс.
    2. Анализирует критичность ошибки и лимит оставшихся попыток (retry).
    3. Извлекает правильный UUID статуса из реестра и обновляет запись в БД.
    4. Рассчитывает точное время паузы для следующей попытки.
    
    Args:
        raw_error (Exception): Любое сырое исключение, пойманное в основном цикле.
        conn: Объект активного подключения к базе данных для логгера.
        request_id: Уникальный идентификатор текущего запроса в БД.
        attempt (int): Порядковый номер текущей попытки (начиная с 1).
        model_name (str): Имя используемой ИИ-модели.
        
    Returns:
        float: Время в секундах, которое нужно подождать перед следующим ретраем.
               Возвращает 0, если произошла критическая ошибка или попытки исчерпаны.
    """
    # ШАГ 1: Нормализуем ошибку через переводчик.
    # Теперь переменная 'e' — это гарантированно наш объект класса SecureAPIError
    e = ExceptionHandler.map_google_exception(raw_error, model_name)
    
    is_last_attempt = attempt >= config.DEFAULT_MAX_RETRIES
    error_msg = str(e)[:150]  # Безопасно ограничиваем длину сообщения для БД
    
    # Читаем стандартизированные свойства, которые зашил в ошибку переводчик
    is_retryable = getattr(e, 'is_retryable', False)
    status_key = getattr(e, 'status_key', 'ERROR_GENERIC')

    # =====================================================================
    # СЦЕНАРИЙ 1: НЕУСТРАНИМЫЕ ОШИБКИ ИЛИ КОНЕЦ РАЗРЕШЕННЫХ ПОПЫТОК
    # =====================================================================
    if not is_retryable or is_last_attempt:
        # Корректировка: если ошибка была повторяемой (например, таймаут), 
        # но попытки исчерпаны — фиксируем в БД финальный статус общей ошибки.
        if status_key == "ERROR_RETRY" and is_last_attempt:
            status_key = "ERROR_GENERIC"
            
        # Конвертируем строковый ключ (например, "ERROR_QUOTA") в реальный UUID из вашей таблицы
        final_status_uuid = get_status_id(conn,status_key)
        
        logging.error(
            f"Финальный отказ запроса {request_id} на модели {model_name}. "
            f"Статус в БД: {status_key}. Причина: {error_msg}"
        )
        
        # Финализируем запись в базе данных строго один раз (без ложных промежуточных статусов)
        log_request_finish(
            conn, 
            request_id, 
            response_text=None, 
            status_key=status_key,  # <-- Передаем строковый маркер (например, 'ERROR_SAFETY' или 'TIMEOUT')
            out_tokens=0, 
            error_msg=f"FINAL_LOCKED_{status_key}: {error_msg}"
        )
        
        # Если это жесткое исчерпание суточных квот (ResourceExhausted с маркером daily) — 
        # пробрасываем ошибку выше. Главный оркестратор поймает её и переключит модель.
        if isinstance(e, QuotaExhaustedError):
            raise e 
            
        return 0  # Для остальных критических ошибок (например, цензуры 400) возвращаем 0

    # =====================================================================
    # СЦЕНАРИЙ 2: МЯГКИЕ ПОВТОРЯЕМЫЕ ОШИБКИ (RETRYABLE)
    # =====================================================================
    retry_status_uuid = get_status_id(conn,"ERROR_RETRY")
    
    # Извлекаем индивидуальную паузу (если её настроил адаптер, например 5.0 сек для 429),
    # либо рассчитываем стандартный экспоненциальный бэккофф с добавлением случайного джиттера.
    wait_time = getattr(e, 'suggested_delay', (2 ** attempt) + random.uniform(2, 5))
    
    # Фиксируем в БД промежуточный статус, что запрос ушел на повторное ожидание
    log_request_retry(conn, request_id, retry_status_uuid)
    
    logging.warning(
        f"Временный сбой ({type(e).__name__}) на модели {model_name}. "
        f"Попытка {attempt}/{config.DEFAULT_MAX_RETRIES}. Ждем {wait_time:.2f} сек. до повтора."
    )
    
    return wait_time

def check_actual_model(conn):
    """
    Опрашивает БД и состояния блокировок.
    Возвращает строку с именем первой доступной модели.
    Блокирует выполнение (time.sleep), если доступных моделей нет.
    """
    # 1. Проверка шторма базы данных
    if check_system_overload(conn):
        logging.warning("Система перегружена (шторм запросов). Ожидание 60 сек.")
        countdown_timer(60)
        if check_system_overload(conn):
            raise RuntimeError("Критическая перегрузка БД: Шторм запросов продолжается")

    # 2. Бесконечный цикл поиска свободной модели
    while True:
        reset_timestamp = get_google_quota_reset_timestamp()
        
        for model in ALLOWED_MODELS:
            # Амнистия или пропуск заблокированной модели
            if model in BLOCKED_MODELS:
                if time.time() < BLOCKED_MODELS[model]:
                    continue
                else:
                    del BLOCKED_MODELS[model]
            
            # Чтение метрик
            try:
                metrics = get_current_metrics(conn, model, reset_timestamp)
            except RuntimeError as e:
                logging.critical(f"Сбой БД при выборе модели: {e}. Пауза 60 сек.")
                countdown_timer(60)
                break # Сброс цикла for, начинаем while заново
            
            # Если лимит позволяет — возвращаем модель
            if metrics.get("total_quota_usage", 0) < MODEL_LIMITS[model]["max_rpd"]:
                return model
        
        # 3. Если цикл for завершился и ничего не вернул
        logging.critical("[СТОП-КРАН] Все модели исчерпали лимиты (или в бане). Пауза 5 минут.")
        countdown_timer(300)

# --- Утилиты сериализации ---
def json_serial(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, (date, datetime)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")