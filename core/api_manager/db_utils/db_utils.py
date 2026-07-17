#db_utils.py
import logging
import psycopg2
from datetime import datetime, timezone
from api_manager.config import GLOBAL_RPM_LIMIT, GLOBAL_TPM_LIMIT

# Приводим локальные модули к единому абсолютному стилю от корня aive
from api_manager.db_utils.db_queries import QUERIES
from core.db_utils.db_access import db_fetch_val, db_execute_update, db_execute, db_get_stats, get_status_id

def log_request_blob(conn, request_id, file_path):
    """Сохраняет бинарные данные файла в БД."""
    import os
    import logging
    from core.db_utils.db_access import db_execute
    
    if not os.path.exists(file_path):
        logging.error(f"Файл для BLOB не найден: {file_path}")
        return

    try:
        with open(file_path, "rb") as f:
            blob_data = f.read()
        
        # Используем централизованный db_execute
        db_execute(conn, "INSERT_BLOB", (request_id, blob_data))
        logging.info(f"BLOB для запроса {request_id} успешно записан.")
    except Exception as e:
        logging.error(f"Ошибка при записи BLOB: {e}")
        raise

def is_model_blocked(conn, model_name):
    """Проверка блокировки модели в БД."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT blocked_until > NOW() 
            FROM processing.api_blocked_models 
            WHERE model_name = %s
        """, (model_name,))
        result = cur.fetchone()
        return result[0] if result else False

def api_requests_log_check_health(conn, max_requests=1) -> bool:
    """
    Проверяет, не превышен ли лимит запросов за последнюю минуту.
    
    Возвращает:
        True  - лимит превышен, нужно ждать.
        False - лимит не превышен, можно работать.
    """
    try:
        # Используем db_get_stats для получения count
        stats = db_get_stats(conn, "CHECK_REQUEST_COUNT", ())
        count = stats.get("request_count", 0)
        
        if count >= max_requests:
            logging.warning(f"[ЛИМИТ] Превышен лимит запросов ({count} за мин). Пауза 30 сек.")
            return True
            
        return False
        
    except Exception as e:
        logging.error(f"[ОШИБКА] Ошибка проверки счетчика запросов: {e}")
        return False

def check_system_overload(conn, threshold=60):
    # Глобальная проверка без привязки к ID
    count = db_fetch_val(conn, "CHECK_LOAD", default=0) 
    
    if count >= threshold:
        logging.critical(f"[ОПАСНОСТЬ] Шторм: {count} запросов за 1 минуту.")
        return True
    return False

def clear_timed_out_pending_requests(conn):
    # Получаем ID из кэша (заполняется через load_status_cache)
    pending_id = get_status_id(conn, 'api_requests',"PENDING")
    abandoned_id = get_status_id(conn, 'api_requests',"ABANDONED")
    timeout_id = get_status_id(conn, 'api_requests',"TIMEOUT")

    # Выполняем очистку через обновленный DAL
    db_execute_update(conn, "CLEANUP_PENDING", (abandoned_id, 'CLEANUP_ABANDONED_OVER_24H', pending_id, '24 hours'))
    db_execute_update(conn, "CLEANUP_PENDING", (timeout_id, 'CLEANUP_TIMEOUT_10M', pending_id, '10 minutes'))

def analyze_historical_health(conn, model_name):
    from api_manager.api_utils.api_defend import block_model
    # Константы для поиска ошибок (вынесены для чистоты)
    params = (
        '%generate_content_free_tier_requests%', 
        '%generate_content_free_tier_input_tokens%', 
        model_name
    )
    
    stats = db_get_stats(conn, "GET_HEALTH_STATS", params)
    
    # Бизнес-логика: доступ по ключам словаря (намного надежнее индексов)
    req_breach = stats.get('req_limit', 0)
    tok_breach = stats.get('tok_limit', 0)


    if req_breach > 0 or tok_breach > 0:
        logging.error(f"[HEALTH] Превышение квот! Req: {req_breach}, Tok: {tok_breach}. Блокируем.")
        block_model(model_name, duration_seconds=1800)
        return False
        
    return True

# --- Логирование БД ---
def log_request_start(conn, source_uuid, prompt_text, model_name, tokens, target_name="technical", file_meta=None):
    # Проверка на дубликат
    #existing_id = db_fetch_val(conn, "CHECK_DUPLICATE", (source_uuid,))
    #if existing_id:
    #    logging.warning(f"[Duplicate] Запрос с source_uuid {source_uuid} уже существует (ID: {existing_id})")
    #    return existing_id
    
    # 1. Гарантируем наличие родительской записи
    db_execute(conn, "ENSURE_SOURCE_EXTRACTION", (source_uuid, target_name))
    
    # 2. Получаем ID статуса
    status_id = get_status_id(conn, 'api_requests', "PENDING")
    
    # 3. Разбираем модель
    model_parts = model_name.split('-', 1)
    family = model_parts[0]
    version = model_parts[1] if len(model_parts) > 1 else "unknown"
    start_time = datetime.now(timezone.utc)
    # 4. Выполняем вставку (json нужен для преобразования dict в строку для JSONB)
    import json
    params = (source_uuid, family, version, prompt_text, json.dumps(file_meta) if file_meta else None, status_id, tokens)
    return db_execute(conn, "LOG_START", params)

def log_request_finish(conn, request_id, response_text, status_key, out_tokens, error_msg=None):
    from core.db_utils.db_access import db_execute, get_status_id, db_fetch_val
    from datetime import datetime, timezone
    
    try:
        # 1. Получаем ID статуса
        status_id = get_status_id(conn, 'api_requests', status_key)
        
        # 2. Вычисляем duration_ms (ваша логика)
        start_time = db_fetch_val(conn, "GET_START_TIME", (request_id,))
        if start_time is None:
            raise ValueError(f"Не удалось получить время старта для ID: {request_id}")
        duration = int((datetime.now(timezone.utc) - start_time).total_seconds() * 1000)
        
        # 3. Выполняем ОДИН UPDATE через централизованный QUERIES
        params = (response_text or "", status_id, out_tokens, duration, error_msg, request_id)
        db_execute(conn, "LOG_FINISH", params)
        
        logging.info(f"Лог завершения записан для ID: {request_id}")
    except Exception as e:
        conn.rollback()

def log_request_retry(conn, request_id, retry_status_key):
    status_id = get_status_id(conn, 'api_requests',retry_status_key)
    params = (status_id, request_id)
    
    db_execute_update(conn, "LOG_RETRY", params)

def get_current_metrics(conn, model_name, reset_timestamp):
    # Заранее получаем ID статусов для читаемости
    pending_status = get_status_id(conn, 'api_requests', "PENDING")
    finished_status = get_status_id(conn, 'api_requests', "FINISHED")
    
    # Корректный набор из 9 параметров под новый MIN(created_at) запрос
    params = (
        pending_status,       # 1. minute_stats: исключаем PENDING
        pending_status,       # 2. local_minute_stats: исключаем PENDING
        model_name,           # 3. local_minute_stats: фильтр по модели
        finished_status,      # 4. local_daily_stats: фильтр успешных для количества
        finished_status,      # 5. local_daily_stats: фильтр успешных для процента
        reset_timestamp,      # 6. local_daily_stats: отсчет со времени сброса квоты
        model_name,           # 7. local_daily_stats: фильтр по модели
        pending_status,       # 8. local_daily_stats: исключаем PENDING
        GLOBAL_RPM_LIMIT      # 9. CASE WHEN условие проверки лимита (global_rpm >= %s)
    )
    
    try:
        stats = db_get_stats(conn, "GET_METRICS_REPORT", params)
        # ОТЛАДОЧНЫЙ ЛОГ: Выводим внутренности расчетов базы
        logging.warning(
            f"[DEBUG RPM] Зафиксировано в транзакции (NOW): {stats.get('db_transaction_now')}, "
            f"Реальное время БД (clock): {stats.get('db_actual_clock')}, "
            f"Самый старый запрос окна: {stats.get('db_oldest_record')}"
        )
        
        # Возвращаем дефолтные значения, если запрос вернул пустоту
        return {
            "rpm": stats.get("global_rpm", 0) or 0,
            "tpm": int(stats.get("global_tpm", 0) or 0),
            "rpm_wait_sec": float(stats.get("global_rpm_wait_sec", 0) or 0),
            "local_rpm": stats.get("local_rpm", 0) or 0,
            "local_tpm": int(stats.get("local_tpm", 0) or 0),
            "local_rpd": stats.get("total_quota_usage", 0) or 0,
            "successful_requests": stats.get("successful_requests", 0) or 0,
            "success_rate": float(stats.get("success_rate_percent", 100.0) or 100.0)
        }
    except Exception as e:
        logging.critical(f"КРИТИЧЕСКИЙ СБОЙ БД при чтении метрик: {e}")
        raise RuntimeError(f"Не удалось получить метрики: {e}")