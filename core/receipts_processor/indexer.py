import os
import uuid
from core.db_utils.db_access import get_status_id, db_execute
import hashlib

def calculate_hash(file_path):
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return sha256.hexdigest()

def index_files(conn, folder_path):
    """Сканирует папку и добавляет/обновляет файлы в source_files."""
    ready_status = get_status_id(conn, 'source_files', 'READY_TO_SEND')
    valid_extensions = ('.jpg', '.jpeg', '.png', '.pdf', '.webp')
    
    files = [f for f in os.listdir(folder_path) if f.lower().endswith(valid_extensions)]
    print(f"Найдено файлов для индексации: {len(files)}")
    
    for filename in files:
        file_path = os.path.abspath(os.path.join(folder_path, filename))
        file_hash = calculate_hash(file_path)
        file_size = os.path.getsize(file_path)
        
        # Проверка наличия в базе
        existing_id = db_fetch_val(conn, "GET_FILE_ID_BY_PATH", (file_path,))
        
        if existing_id:
            print(f"Файл уже проиндексирован: {filename}")
            continue
        
        # Вставка
        try:
            db_execute(conn, "INSERT_SOURCE_FILE", (
                str(uuid.uuid4()), 
                filename, 
                file_path, 
                file_size, 
                file_hash, 
                ready_status
            ))
            print(f"Индексирован: {filename}")
        except Exception as e:
            print(f"Ошибка при вставке {filename}: {e}")

if __name__ == "__main__":
    # Здесь нужно добавить подключение к БД (как в вашем api_test.py)
    # и вызвать index_files(conn, "путь/к/папке")
    pass