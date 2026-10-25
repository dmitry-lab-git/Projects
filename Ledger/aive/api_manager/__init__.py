# C:\Users\admin\Desktop\Ledger\aive\api_manager\__init__.py

# Оставляем только настройки
from api_manager.config import MODEL_LIMITS
import api_manager.config as config
import time



def secure_api_call(client, prompt_text, conn, source_uuid, model_name="gemini-2.5-flash", target_name="technical"):
    """
    Теперь эта функция живет здесь, а все импорты находятся ВНУТРИ нее.
    Это разрывает циклическую зависимость.
    """
    # Конфигурационный параметр (можно вынести в ваш config.py)
    USE_STATIC_MODEL = True
    STATIC_MODEL_NAME = "gemini-3.1-flash-lite"

    # Импортируем зависимости только в момент вызова функции
    from api_manager.api_utils.api_utils import (
        check_actual_model, 
        model_rotation, 
        execute_with_retry,
        display_report
    )
    from api_manager.api_utils.api_defend import validate_system_state
    from api_manager.db_utils.db_utils import log_request_start
    import logging

    # 1. Первичная валидация
    model_name = check_actual_model(conn)
    _, input_tokens, metrics, report, reset_time = validate_system_state(conn, client, model_name, prompt_text)
    if not model_name:
        raise ValueError("Не удалось определить активную модель из БД.")
    
    display_report(report)
    
    # 2. Ротация
    if USE_STATIC_MODEL:
        model_name = STATIC_MODEL_NAME
        logging.info(f"Используется статичная модель: {model_name}")
    else:
        # Ваша текущая логика ротации
        new_model, new_tokens = model_rotation(conn, client, model_name, prompt_text, report)
        if new_tokens is not None:
            model_name, input_tokens = new_model, new_tokens
        logging.info(f"Использована модель после ротации: {model_name}")

    # 3. Исполнение
    try:
        # Логируем начало
        request_id = log_request_start(conn, source_uuid, prompt_text, model_name, input_tokens, target_name)
        
        # ВЫПОЛНЯЕМ ЗАПРОС ЧЕРЕЗ ИСПОЛНИТЕЛЬ
        response_text = execute_with_retry(client, model_name, prompt_text, conn, request_id)
        
        logging.info(f"Исполнение успешно завершено.")
        return response_text # Теперь возвращается ID после реального исполнения
            
    except Exception as e:
        logging.error(f"Ошибка в процессе исполнения: {e}")
        # Если это критическая ошибка остановки БД
        if isinstance(e, SystemExit):
            raise e
        return None