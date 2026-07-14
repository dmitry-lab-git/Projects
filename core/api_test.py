import os
import time
import sys
import psycopg2
from dotenv import load_dotenv
from google import genai
import uuid

# Путь к вашему реальному .env
env_path = "/home/fujitsu-u745/Projects/secure_folder/api_manager/.env"
load_dotenv(env_path)

sys.path.append(os.getcwd())
from api_manager import secure_api_call

def run_test(use_file=False):
    
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("[ERROR] Переменная DATABASE_URL не найдена в .env")
        return

    print("\n=== ИНИЦИАЛИЗАЦИЯ ИНТЕГРАЦИОННОГО ТЕСТА ===")
    
    try:
        # Подключение через URL (psycopg2 умеет парсить его напрямую)
        conn = psycopg2.connect(db_url)
        print("[1/3] Соединение с БД установлено.")
    except Exception as e:
        print(f"[ERROR] Не удалось подключиться к БД: {e}")
        return

    test_uuid = str(uuid.uuid4())
    test_file_path = "/home/fujitsu-u745/Projects/Ledger/raw_data_ipad/docs/IMG_0901.JPG"
    print(f"DEBUG: Проверка существования файла: {os.path.exists(test_file_path)}")
    print(f"DEBUG: Проверка, является ли файлом: {os.path.isfile(test_file_path)}")

    try:
        print(f"[2/3] Вызов secure_api_call (UUID: {test_uuid})...")
        result = secure_api_call(
            client=client, 
            prompt_text="Проанализируй содержимое" if use_file else "Привет!", 
            conn=conn, 
            source_uuid=test_uuid, 
            model_name="gemini-3.1-flash-lite", # Или ваша версия 3.1-flash-lite
            file_path=test_file_path if use_file else None
        )
        print(f"[2/3] Результат функции: {result}")
        conn.commit()
    except Exception as e:
        print(f"[ERROR] Исключение: {e}")
        conn.rollback()
    finally:
        conn.close()
        print("[3/3] Тест завершен.")

if __name__ == "__main__":
    # Переключатель: поставьте True для теста с файлом, False для текста
    TEST_WITH_FILE = True 
    run_test(use_file=TEST_WITH_FILE)