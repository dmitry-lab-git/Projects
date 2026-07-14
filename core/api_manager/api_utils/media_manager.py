import os
import logging
from pathlib import Path
from google.genai import types

MAX_FILE_SIZE = 20 * 1024 * 1024  # 20 МБ

# Определяем разрешенные директории (используем абсолютные пути)
BASE_DIR = Path("/home/fujitsu-u745/Projects")
ALLOWED_DIRS = [
    (BASE_DIR / "data").resolve(),
    (BASE_DIR / "uploads").resolve(),
    (BASE_DIR / "Ledger").resolve()  # Добавляем путь к папке Ledger
]

def is_path_safe(file_path: str) -> bool:
    """Проверяет, лежит ли файл внутри одной из разрешенных папок."""
    try:
        requested_path = Path(file_path).resolve()
        return any(requested_path.is_relative_to(allowed) for allowed in ALLOWED_DIRS)
    except Exception:
        return False

def validate_file_path(file_path: str):
    """Базовая проверка существования, прав и безопасности файла на диске."""
    # 1. Проверка безопасности (белый список)
    if not is_path_safe(file_path):
        logging.error(f"[MediaManager] Security Alert: Доступ к {file_path} заблокирован (вне ALLOWED_DIRS)")
        raise PermissionError(f"Безопасность: доступ к файлу {file_path} запрещен (вне разрешенных директорий).")

    # 2. Проверка существования
    if not os.path.exists(file_path):
        logging.error(f"[MediaManager] File Error: Файл не найден по пути {file_path}")
        raise FileNotFoundError(f"Файл не найден: {file_path}")
    
    if not os.path.isfile(file_path):
        logging.error(f"[MediaManager] File Error: Путь не является файлом: {file_path}")
        raise ValueError(f"Путь не является файлом: {file_path}")
    
    if not os.access(file_path, os.R_OK):
        logging.error(f"[MediaManager] Permission Error: Нет прав на чтение файла: {file_path}")
        raise PermissionError(f"Нет прав на чтение файла: {file_path}")

    # 3. Проверка размера
    file_size = os.path.getsize(file_path)
    if file_size == 0:
        logging.warning(f"[MediaManager] Validation Error: Файл пуст: {file_path}")
        raise ValueError(f"Файл пуст: {file_path}")
    
    if file_size > MAX_FILE_SIZE:
        logging.warning(f"[MediaManager] Validation Error: Файл слишком большой ({file_size} байт): {file_path}")
        raise ValueError(f"Файл превышает допустимый размер: {file_size} байт")

    logging.info(f"[MediaManager] Файл успешно прошел валидацию: {file_path}")

def get_file_part(file_path: str) -> types.Part:
    """Проверяет файл для API и возвращает объект Part."""
    # 1. Базовая проверка (вызываем первую функцию)
    validate_file_path(file_path)

    # 2. API-специфичная валидация (MIME-типы)
    mime_type_map = {
        ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".png": "image/png", ".webp": "image/webp",
        ".csv": "text/csv", ".txt": "text/plain",
        ".pdf": "application/pdf"
    }
    
    ext = os.path.splitext(file_path)[1].lower()
    mime_type = mime_type_map.get(ext)
    if not mime_type:
        raise ValueError(f"Формат {ext} не поддерживается для API")

    # 3. Чтение данных
    try:
        with open(file_path, "rb") as f:
            return types.Part.from_bytes(data=f.read(), mime_type=mime_type)
    except Exception as e:
        logging.error(f"Ошибка при подготовке файла для API: {e}")
        raise

