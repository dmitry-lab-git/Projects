import os
from dotenv import load_dotenv

# Загружаем переменные из .env
dotenv_path = '/home/fujitsu-u745/Projects/secure_folder/receipts_processor/.env'
load_dotenv(dotenv_path=dotenv_path)

# Путь к данным
RAW_DATA_PATH = os.path.abspath(os.getenv("RAW_DATA_PATH", "./data"))

# Конфигурация БД (предполагаем наличие соответствующих переменных в .env)
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "receipts_db")
DB_USER = os.getenv("DB_USER", "receipt_processor_svc")
DB_PASSWORD = os.getenv("DB_PASSWORD")

# Константы
VALID_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.pdf', '.webp')
SCHEMA_NAME = "processing"

# Базовые локальные статусы
STATUS_READY = 'READY_TO_SEND'
STATUS_UNREADABLE = 'UNREADABLE'
STATUS_REJECTED = 'REJECTED'

# Системные статусы маршрутизации
STATUS_PROCESSING = 'PROCESSING'

# Терминальные и статусы исключений
STATUS_FINISHED = 'FINISHED'
STATUS_API_ERROR = 'API_ERROR'
STATUS_NEEDS_REVIEW = 'NEEDS_REVIEW'