# api_manager/__init__.py

from api_manager.config import MODEL_LIMITS
import api_manager.config as config
import time
import logging
import psycopg2

_cleanup_done = False 

def _stage_execution(client, model_name, contents, conn, source_uuid, prompt_text, input_tokens, target_name, file_path, file_meta):
    from api_manager.db_utils.db_utils import log_request_start, log_request_blob
    from api_manager.api_utils.api_utils import execute_with_retry
    import logging

    request_id = log_request_start(conn, source_uuid, prompt_text, model_name, input_tokens, target_name, file_meta=file_meta)
    
    if file_path:
        from api_manager.db_utils.db_utils import log_request_blob
        log_request_blob(conn, request_id, file_path)
    
    response_text = execute_with_retry(client, model_name, contents, conn, request_id)
    logging.info("Исполнение успешно завершено.")
    return response_text

def _stage_rotation(client, prompt_text, contents, conn, model_name, input_tokens):
    from api_manager.api_utils.api_utils import model_rotation
    import logging
    
    USE_STATIC_MODEL = True
    STATIC_MODEL_NAME = "gemini-3.1-flash-lite"

    if USE_STATIC_MODEL:
        return STATIC_MODEL_NAME, input_tokens 

    return model_rotation(conn, model_name)

def _stage_validation(client, prompt_text, conn, model_name, file_path):
    from api_manager.api_utils.api_utils import check_actual_model, display_report
    from api_manager.api_utils.api_defend import validate_system_state
    
    _, input_tokens, _, report, _, contents, file_meta = validate_system_state(
        conn, client, model_name, prompt_text, file_path
    )
    
    if not model_name:
        raise ValueError("Не удалось определить активную модель из БД.")
    
    display_report(report)
    
    return model_name, contents, file_meta, input_tokens

def _ensure_cache_cleanup(conn):
    """Выполняет очистку кэша только один раз за сессию."""
    global _cleanup_done
    if not _cleanup_done:
        from api_manager.db_utils.db_utils import db_execute
        try:
            db_execute(conn, "CLEANUP_OLD_BLOBS", ())
            _cleanup_done = True
            logging.info("Очистка кэша BLOB-ов выполнена.")
        except Exception as e:
            logging.warning(f"Не удалось очистить кэш BLOB-ов: {e}")


def secure_api_call(client, prompt_text, conn, source_uuid, model_name="gemini-2.5-flash", target_name="technical", file_path=None):
    _ensure_cache_cleanup(conn)
    from api_manager.config import reload_config
    reload_config()
    try:
        # Этап 1: Валидация и подготовка
        print(f"DEBUG: client in secure_api_call is {client}")
        model_name, contents, file_meta, input_tokens = _stage_validation(client, prompt_text, conn, model_name, file_path)
        
        # Этап 2: Ротация и выбор модели
        model_name, input_tokens = _stage_rotation(client, prompt_text, contents, conn, model_name, input_tokens)
        
        # Этап 3: Исполнение
        return _stage_execution(client, model_name, contents, conn, source_uuid, prompt_text, input_tokens, target_name, file_path, file_meta)
            
    except psycopg2.OperationalError as e:
        logging.critical(f"Критическая ошибка соединения с БД: {e}. Пауза 60 сек.")
        from core.db_utils.db_access import countdown_timer
        countdown_timer(60)
        return None

    except Exception as e:
        import logging
        import traceback  # Добавьте этот импорт
        logging.error(f"Ошибка в процессе исполнения: {e}")
        traceback.print_exc() # Добавьте это, чтобы увидеть реальную строку
        if isinstance(e, SystemExit):
            raise e
        return None