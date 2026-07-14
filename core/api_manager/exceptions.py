#C:\Users\admin\Desktop\Ledger\aive\api_manager\exceptions.py
from google.api_core import exceptions as google_exceptions
import logging

class SecureAPIError(Exception):
    def __init__(self, message: str, model_name: str = None, is_retryable: bool = False, status_key: str = "ERROR_GENERIC"):
        super().__init__(message)
        self.model_name = model_name
        self.is_retryable = is_retryable
        self.status_key = status_key


# --- Домены исключений ---
class ClientValidationError(SecureAPIError):
    def __init__(self, message: str, model_name: str = None):
        super().__init__(message, model_name, is_retryable=False, status_key="ABANDONED")

class ProviderError(SecureAPIError):
    pass

class RateLimitError(ProviderError):
    def __init__(self, message: str, model_name: str, suggested_delay: float = 5.0):
        super().__init__(message, model_name, is_retryable=True, status_key="ERROR_RETRY")
        self.suggested_delay = suggested_delay

class QuotaExhaustedError(ProviderError):
    def __init__(self, message: str, model_name: str):
        super().__init__(message, model_name, is_retryable=False, status_key="ERROR_QUOTA")

class ContentPolicyViolationError(ProviderError):
    def __init__(self, message: str, model_name: str):
        super().__init__(message, model_name, is_retryable=False, status_key="ERROR_SAFETY")


# --- Хэндлер для api_utils.py ---
class ExceptionHandler:
    @staticmethod
    def handle(e: Exception, attempt: int, model_name: str = "unknown") -> dict:
        """
        Преобразует исключение в унифицированный словарь решений для пайплайна.
        """
        # Получаем нормализованный объект ошибки
        mapped = ExceptionHandler.map_google_exception(e, model_name=model_name)
        
        # Формируем словарь, используя getattr для защиты от отсутствующих атрибутов
        return {
            "action": "RETRY" if getattr(mapped, "is_retryable", False) else "FAIL",
            "status_key": getattr(mapped, "status_key", "ERROR_GENERIC"),
            "delay": getattr(mapped, "suggested_delay", None),
            "error_msg": getattr(mapped, "message", str(e))
        }
    
    @staticmethod
    def map_google_exception(e: Exception, model_name: str = "unknown") -> SecureAPIError:
        """
        Конвертирует сырые низкоуровневые ошибки Google SDK и системы в 
        нормализованные доменные исключения SecureAPIError.
        
        Каждому типу ошибки жестко сопоставляется флаг возможности повтора (is_retryable)
        и строковый маркер для реестра статусов базы данных (status_key).
        
        Args:
            e (Exception): Оригинальное пойманное исключение.
            model_name (str): Имя модели (например, 'gemini-1.5-flash'), на которой произошел сбой.
            
        Returns:
            SecureAPIError: Наш типизированный объект ошибки для диспетчера логирования.
        """
        error_msg = str(e)
        error_msg_lower = error_msg.lower()

        # =====================================================================
        # 1. ДОМЕН КВОТ И МЯГКИХ ЛИМИТОВ (HTTP 429 / gRPC RESOURCE_EXHAUSTED)
        # =====================================================================
        
        # Точечный перехват стандартной ошибки TooManyRequests (лимиты RPM/TPM в минуту/токены)
        if isinstance(e, google_exceptions.TooManyRequests):
            return RateLimitError(
                message=f"Превышен минутный лимит запросов RPM/TPM: {error_msg}",
                model_name=model_name,
                suggested_delay=5.0
            )

        # Жесткая gRPC ошибка исчерпания ресурсов. Может означать как минутный затор, так и суточный бан.
        if isinstance(e, google_exceptions.ResourceExhausted):
            # Внимательно анализируем текст ответа Google, чтобы выявить суточное исчерпание (RPD)
            is_daily_quota = any(marker in error_msg_lower for marker in ["daily", "rpd", "limit exceeded for day"])
            
            if is_daily_quota:
                # Суточный лимит — фатальный отказ для этой модели, запускает ротацию (ERROR_QUOTA)
                return QuotaExhaustedError(
                    message=f"Суточный лимит RPD полностью исчерпан на стороне Google: {error_msg}",
                    model_name=model_name,
                    reset_time="00:00 UTC"
                )
            else:
                # Обычный минутный затор (RPM) — мягкая ошибка, можно переждать на паузе (ERROR_RETRY)
                return RateLimitError(
                    message=f"Кратковременное (минутное) превышение лимита запросов: {error_msg}",
                    model_name=model_name,
                    suggested_delay=4.0
                )

        # =====================================================================
        # 2. ДОМЕН ПОЛИТИК БЕЗОПАСНОСТИ И ВАЛИДАЦИИ (HTTP 400 INVALID_ARGUMENT)
        # =====================================================================
        
        if isinstance(e, google_exceptions.InvalidArgument):
            # У Gemini ошибка 400 чаще всего означает, что промпт или ответ забанен цензурой
            is_safety_block = any(marker in error_msg_lower for marker in ["safety", "policy", "block", "content"])
            
            if is_safety_block:
                # Создаем ошибку политики безопасности и явно крепим к ней маркер ERROR_SAFETY
                error_obj = ContentPolicyViolationError(
                    message=f"Запрос отклонен фильтрами безопасности Google Gemini: {error_msg}",
                    model_name=model_name
                )
                error_obj.status_key = "ERROR_SAFETY"
                return error_obj
            else:
                # Если это 400 Bad Request по другой причине (например, неверный формат параметров в коде)
                return SecureAPIError(
                    message=f"Некорректный запрос к API (400 Bad Request): {error_msg}",
                    model_name=model_name,
                    is_retryable=False,
                    status_key="ERROR_GENERIC"
                )

        # =====================================================================
        # 3. ДОМЕН СЕТЕВЫХ ТАЙМАУТОВ (HTTP 504 / gRPC DEADLINE_EXCEEDED)
        # =====================================================================
        
        if isinstance(e, (google_exceptions.DeadlineExceeded, google_exceptions.GatewayTimeout)):
            return SecureAPIError(
                message=f"Превышено время ожидания ответа от Google API (Timeout): {error_msg}",
                model_name=model_name,
                is_retryable=True, # Обязательно пробуем повторить запрос, сеть могла моргнуть
                status_key="TIMEOUT"
            )

        # =====================================================================
        # 4. ДОМЕН ВРЕМЕННЫХ СБОЕВ СЕРВЕРА GOOGLE (HTTP 500 / 503)
        # =====================================================================
        
        if isinstance(e, (google_exceptions.InternalServerError, google_exceptions.ServiceUnavailable)):
            return ProviderError(
                message=f"Временный внутренний сбой на серверах Google: {error_msg}",
                model_name=model_name,
                is_retryable=True, # Ошибки 5xx обычно кратковременны, делаем ретрай
                status_key="ERROR_GENERIC"
            )

        # =====================================================================
        # 5. СИСТЕМНЫЙ ФОЛБЕК ДЛЯ ПРОЧИХ И СИСТЕМНЫХ ИСКЛЮЧЕНИЙ
        # =====================================================================
        
        # Если это любая другая редкая ошибка из официального SDK Google API
        if isinstance(e, google_exceptions.GoogleAPICallError):
            return ProviderError(
                message=f"Неспецифицированная ошибка Google API ({type(e).__name__}): {error_msg}",
                model_name=model_name,
                is_retryable=False,
                status_key="ERROR_GENERIC"
            )

        # Если упала встроенная ошибка таймаута Python (например, urllib3 или httpx)
        if isinstance(e, TimeoutError):
            return SecureAPIError(
                message=f"Системный таймаут соединения: {error_msg}",
                model_name=model_name,
                is_retryable=True,
                status_key="TIMEOUT"
            )

        # Абсолютный фолбек для неизвестных критических сбоев (ошибки кода, БД и т.д.)
        logging.critical(f"Поймано непредвиденное системное исключение: {type(e).__name__} -> {error_msg}")
        return SecureAPIError(
            message=f"Непредвиденный системный сбой приложения: {error_msg}",
            model_name=model_name,
            is_retryable=False,
            status_key="ERROR_GENERIC"
        )