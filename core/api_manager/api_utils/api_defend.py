# api_defend.py
import logging
import time
import pathlib
from api_manager import config
from api_manager.config import GLOBAL_RPM_LIMIT, GLOBAL_TPM_LIMIT, PACING_DELAY, MODEL_LIMITS
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from api_manager.db_utils.db_utils import (
    get_current_metrics, 
    analyze_historical_health, 
    clear_timed_out_pending_requests, 
    check_system_overload,
    api_requests_log_check_health
)
from api_manager.exceptions import (
    SecureAPIError, 
    QuotaExhaustedError, 
    ContentPolicyViolationError, 
    ExceptionHandler
)

current_active_transactions = 0

def block_model(conn, model_name, duration_seconds=1800):
    from core.db_utils.db_access import db_execute
    # Передаем duration_seconds как второй параметр для SQL
    db_execute(conn, "BLOCK_MODEL_QUERY", (model_name, duration_seconds))

def reload_config():
    """Чтение настроек из settings.txt."""
    settings_path = pathlib.Path("settings.txt")
    if settings_path.exists():
        # Логика обновления настроек (концептуально)
        pass

class SystemHealthMonitor:
    def __init__(self, limit=10, window=60):
        """
        :param limit: Максимальное количество допустимых запросов в окне.
        :param window: Временное окно в секундах.
        """
        self.events = []
        self.limit = limit
        self.window = window

    def register_event(self):
        import time
        now = time.time()
        self.events = [t for t in self.events if now - t < self.window]
        self.events.append(now)
        logging.info(f"[DEBUG] События: {len(self.events)}/{self.limit}") # <--- Добавьте это
        return len(self.events) <= self.limit

local_storm_monitor = SystemHealthMonitor(limit=10, window=60)

def validate_system_state(conn, client, model_name, prompt_text, file_path=None):
    from api_manager.db_utils.db_utils import is_model_blocked
    from api_manager.api_utils.media_manager import get_file_part
    from api_manager import config
    from api_manager.config import ALLOWED_MODELS
    """
    Финальный оркестратор: превентивная проверка состояния системы перед API-вызовом.
    """
    # Проверка доступа к модели
    if model_name not in ALLOWED_MODELS:
        logging.warning(f"Модель {model_name} не в списке ALLOWED_MODELS. Переключение на fallback.")
    
    # 1. Проверка веса промпта (Самая быстрая проверка к API)

    prompt_tokens = client.models.count_tokens(model=model_name, contents=[prompt_text])
    print(f"[DEBUG] Промпт: {prompt_tokens.total_tokens} токенов")

    file_tokens_count = 0
    contents = [prompt_text]
    file_meta = None

    if file_path:
        file_part = get_file_part(file_path)
        print(f"[DEBUG] Тип file_part: {type(file_part)}")
        print(f"[DEBUG] Содержимое file_part: {file_part}")
        # Если данные в inline_data:
        if hasattr(file_part, 'inline_data'):
            print(f"[DEBUG] MIME: {file_part.inline_data.mime_type}, Размер данных: {len(file_part.inline_data.data)} байт")
        contents.append(file_part)

        file_tokens = client.models.count_tokens(model=model_name, contents=[file_part])
        file_tokens_count = file_tokens.total_tokens
        print(f"[DEBUG] Файл ({file_path}): {file_tokens_count} токенов")  
        print("Отладочная пауза 1 сек")
        time.sleep(1)
        print("Прошло 1 секунда")

    # 1.1 Считаем токены для всего (текст + файл)
    input_tokens = prompt_tokens.total_tokens + file_tokens_count
    print(f"[DEBUG] Итого: {input_tokens} токенов")

    print("Отладочная пауза 1 сек")
    time.sleep(1)
    print("Прошло 1 секунда")
    
    # 1.2 Проверяем вес
    if input_tokens > config.DEFAULT_MAX_PROMPT_WEIGHT:
        raise ValueError(f"Отказ: Промпт слишком тяжелый ({input_tokens} токенов)")

    # 2. Локальный детектор шторма
    while api_requests_log_check_health(conn, max_requests=3):
        print("Лимит превышен. Ожидание 60 секунд...")
        time.sleep(30)

    if not local_storm_monitor.register_event():
        raise RuntimeError("Блокировка: Локальный детектор обнаружил шторм запросов")

    # 3. Аналитический агент (Поиск аномалий в истории БД)
    if not analyze_historical_health(conn, model_name):
        raise RuntimeError(f"Блокировка: Аналитический агент выявил проблемы у {model_name}")

    # 4. Circuit Breaker (Проверка аппаратного бана)
    if is_model_blocked(conn, model_name):
        raise RuntimeError(f"Модель {model_name} временно заблокирована (Circuit Breaker)")

    # 5. Санитарная очистка зомби-запросов (Уборка БД)
    clear_timed_out_pending_requests(conn)

    # 6. Защита базы данных (Детектор шторма на уровне СУБД)
    import random
    if check_system_overload(conn, threshold=20):
        wait_time = random.uniform(5, 10) 
        logging.warning(f"Перегрузка СУБД! Локальная пауза {wait_time:.2f} сек.")
        time.sleep(wait_time)
        return None

    # Эти строки должны быть ВНЕ if, но ВНУТРИ функции (отступ 4 пробела):
    from api_manager.api_utils.api_utils import get_google_quota_reset_timestamp
    
    # 7. Финальные проверки квот
    reset_time = get_google_quota_reset_timestamp()
    metrics = get_current_metrics(conn, model_name, reset_time)
    
    internal_quota_gate_keeping(conn, model_name, reset_time, metrics, input_tokens)
    metrics = external_quota_gate_keeping(conn, model_name, reset_time, metrics, input_tokens)

    print(f"DEBUG: metrics type: {type(metrics)}, content: {metrics}")

    # 8. Расчет Dynamic Pacing (Превентивная задержка при >80% нагрузки RPM)
    dynamic_delay = 0
    max_rpm = MODEL_LIMITS.get(model_name, {}).get('max_rpm', 0)
    if max_rpm > 0:
        # Используем локальный RPM модели вместо глобального
        rpm_usage_percent = (metrics.get('local_rpm', 0) / max_rpm) * 100
        if rpm_usage_percent > 80:
            dynamic_delay = config.PACING_DELAY * 1.5

    # Вычисляем проценты использования для наглядности в отчете
    # Получаем лимиты для текущей модели из переданного словаря конфигов
    model_limits = config.MODEL_LIMITS.get(model_name, {})
    max_rpm = model_limits.get('max_rpm', 0)
    max_tpm = model_limits.get('max_tpm', 0)
    max_rpd = model_limits.get('max_rpd', 0)
    
    global_rpm_limit = config.GLOBAL_RPM_LIMIT
    global_tpm_limit = config.GLOBAL_TPM_LIMIT

    # Расчет утилизации
    global_rpm_pct = round((metrics.get('rpm', 0) / global_rpm_limit) * 100, 1) if global_rpm_limit > 0 else 0
    global_tpm_pct = round((metrics.get('tpm', 0) / global_tpm_limit) * 100, 1) if global_tpm_limit > 0 else 0
    local_rpm_pct = round((metrics.get('local_rpm', 0) / max_rpm) * 100, 1) if max_rpm > 0 else 0
    local_tpm_pct = round((metrics.get('local_tpm', 0) / max_tpm) * 100, 1) if max_tpm > 0 else 0
    
    model_rpd_usage = metrics.get('local_rpd', 0)
    model_rpd_pct = round((model_rpd_usage / max_rpd) * 100, 1) if max_rpd > 0 else 0

    # Сборка подробного аналитического отчета с указанием лимитов
    report = {
        "model_name": model_name,
        "local_sensor": "PASSED (Темп запросов в норме)",
        "circuit_breaker": "PASSED (Модель доступна)",
        "historical_health": "PASSED (Аномалий в логах не обнаружено)",
        "db_protection": "PASSED (Нагрузка на БД в норме)",
        "quota_gatekeeping": "PASSED (Внутренние и внешние лимиты в норме)",
        "global_rpm_usage": f"{metrics.get('rpm', 0)} / {global_rpm_limit} ({global_rpm_pct}%)",
        "global_tpm_usage": f"{metrics.get('tpm', 0)} / {global_tpm_limit} ({global_tpm_pct}%)",
        "model_rpm_usage": f"{metrics.get('local_rpm', 0)} / {max_rpm} ({local_rpm_pct}%)",
        "model_tpm_usage": f"{metrics.get('local_tpm', 0)} / {max_tpm} ({local_tpm_pct}%)",
        "model_rpd_usage": f"{model_rpd_usage} / {max_rpd} ({model_rpd_pct}%)",
        "dynamic_delay_sec": f"{dynamic_delay}"
    }

    return True, input_tokens, metrics, report, reset_time, contents, file_meta

def internal_quota_gate_keeping(conn, model_name, reset_time, metrics, input_tokens):
    import time
    global_tpm = GLOBAL_TPM_LIMIT
    global_rpm = GLOBAL_RPM_LIMIT
    
    # Глобальный TPM
    while (metrics["tpm"] + input_tokens) >= global_tpm:
        logging.warning("[WAIT] Лимит глобального TPM. Сон 15 сек...")
        time.sleep(15)
        metrics = get_current_metrics(conn, model_name, reset_time)

    # Глобальный RPM (опираемся на время самой БД и точный расчет окна)
    while metrics["rpm"] >= global_rpm:
        wait_sec = metrics.get("rpm_wait_sec", 0)
        # Если БД возвращает точное время ожидания, спим его + 1 сек буфера, иначе дефолт
        sleep_duration = (wait_sec + 1) if wait_sec > 0 else PACING_DELAY
        
        logging.warning(f"[WAIT] Лимит глобального RPM. Сон {int(sleep_duration)} сек (по часам БД)...")
        time.sleep(sleep_duration)
        
        # Обновляем метрики в конце итерации для перепроверки актуального состояния
        metrics = get_current_metrics(conn, model_name, reset_time)
        
    return True

def external_quota_gate_keeping(conn, model_name, reset_time, metrics, input_tokens):
    import time
    """
    Контролирует лимиты конкретной выбранной модели API (согласно квотам Google).
    """
    limits = config.MODEL_LIMITS.get(model_name)
    if not limits:
        raise RuntimeError(f"Конфигурация лимитов для модели {model_name} не найдена!")

    # 1. Локальный RPD (жесткая блокировка - переключает Circuit Breaker на другую модель)
    if metrics.get("local_rpd", 0) >= limits.get("max_rpd", 0):
        raise ModelExhaustedError(f"Локальный лимит RPD исчерпан для {model_name}")

    # 2. Локальный TPM
    while (metrics.get("local_tpm", 0) + input_tokens) >= limits.get("max_tpm", 0):
        logging.warning(f"[ЗАЩИТА] Близко к лимиту TPM для {model_name}. Ожидание 15 сек...")
        time.sleep(15)
        metrics = get_current_metrics(conn, model_name, reset_time)

    # 3. Локальный RPM
    while metrics.get("local_rpm", 0) >= limits.get("max_rpm", 0):
        logging.warning(f"[ЗАЩИТА] Лимит RPM для {model_name} достигнут. Пауза 10 сек...")
        time.sleep(10)
        metrics = get_current_metrics(conn, model_name, reset_time)
        
    return metrics