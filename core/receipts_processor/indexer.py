import os
import uuid
import datetime
from core.db_utils.db_access import get_status_id, db_execute, db_fetch_val, get_db_connection
import hashlib
from receipts_processor.config import RAW_DATA_PATH, VALID_EXTENSIONS
from dotenv import load_dotenv
import time


import magic  # pip install python-magic
from PIL import Image  # pip install Pillow
from pypdf import PdfReader



from receipts_processor.config import (
    VALID_EXTENSIONS,
    SCHEMA_NAME,
    STATUS_READY,
    STATUS_REJECTED,
    STATUS_UNREADABLE,
)
def validate_file(file_path, file_hash, conn):
    try:
        # 0. Первичная проверка расширения по белому списку
        if not file_path.lower().endswith(VALID_EXTENSIONS):
            return STATUS_REJECTED, f'Unsupported extension: {file_path.split(".")[-1]}'

        # 1. Глобальный дубликат (запрос выполняется в схеме SCHEMA_NAME)
        if db_fetch_val(conn, "CHECK_FINISHED_BY_HASH", (file_hash,)):
            return STATUS_REJECTED, 'Global Duplicate'

        # 2. Пустой файл
        if os.path.getsize(file_path) == 0:
            return STATUS_REJECTED, 'Empty file'

        # 3. MIME-type через сигнатуру
        file_mime = magic.from_file(file_path, mime=True)
        
        SUPPORTED_IMAGES = {'image/jpeg', 'image/png', 'image/webp'}
        SUPPORTED_DOCS = {'application/pdf'}

        if file_mime not in SUPPORTED_IMAGES and file_mime not in SUPPORTED_DOCS:
            return STATUS_REJECTED, f'Unsupported MIME-type: {file_mime}'

        # 4. Разрешение (для картинок)
        if file_mime in SUPPORTED_IMAGES:
            with Image.open(file_path) as img:
                if img.width < 400 or img.height < 400:
                    return STATUS_REJECTED, 'Low Resolution'

        # 5. Защита паролем (для PDF)
        if file_mime in SUPPORTED_DOCS:
            reader = PdfReader(file_path)
            if reader.is_encrypted:
                return STATUS_REJECTED, 'Locked PDF'

        return STATUS_READY, None

    except Exception as e:
        return STATUS_UNREADABLE, f'Parser crash: {type(e).__name__} - {str(e)}'

def calculate_hash(file_path):
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return sha256.hexdigest()

def index_files(conn, folder_path):
    """Сканирует папку и добавляет/обновляет файлы в source_files."""
    ready_status = get_status_id(conn, 'source_files', 'READY_TO_SEND')
    files = [f for f in os.listdir(folder_path) if f.lower().endswith(VALID_EXTENSIONS)]
    print(f"Найдено файлов для индексации: {len(files)}")
    
    for filename in files:
        file_path = os.path.abspath(os.path.join(folder_path, filename))
        file_hash = calculate_hash(file_path)
        file_size = os.path.getsize(file_path)
        
        # 1. Проверка наличия (уже в БД)
        if db_fetch_val(conn, "GET_FILE_ID_BY_PATH", (file_path,)):
            print(f"Файл уже проиндексирован: {filename}")
            continue
        
        # 2. Валидация
        status_code, reason = validate_file(file_path, file_hash, conn)
        status_id = get_status_id(conn, 'source_files', status_code)
        
        file_date = datetime.datetime.fromtimestamp(os.path.getmtime(file_path)).date()

        # 3. Вставка
        try:
            db_execute(conn, "INSERT_SOURCE_FILE", (
                str(uuid.uuid4()),    # id
                filename,             # file_name
                file_path,            # file_path
                file_size,            # file_size
                file_hash,            # file_hash
                status_id,            # status_id
                reason,               # reject_reason
                file_date             # upload_date
            ))
            conn.commit()
            print(f"Индексирован: {filename} (Статус: {status_code})")
            time.sleep(0.1)
        except Exception as e:
            conn.rollback()
            print(f"Ошибка при вставке {filename}: {e}")
            time.sleep(1)
            continue

if __name__ == "__main__":
    conn = get_db_connection()
    try:
        index_files(conn, RAW_DATA_PATH)
        conn.commit()
        print("Индексация завершена успешно.")
    except Exception as e:
        print(f"Критическая ошибка индексации: {e}")
        conn.rollback()
    finally:
        conn.close()
