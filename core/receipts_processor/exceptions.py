# core/exceptions.py

class CoreError(Exception):
    """Базовый класс для всех ошибок проекта"""
    pass

class DatabaseError(CoreError):
    """Ошибки при работе с БД"""
    pass

class ReceiptProcessorError(CoreError):
    """Базовый класс для обработки чеков"""
    pass

class FileProcessingError(ReceiptProcessorError):
    """Проблемы с чтением/валидацией файла"""
    pass