import os
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
from rxconfig import config

# Указываем точный путь к вашему .env
ENV_PATH = Path("/home/fujitsu-u745/Projects/secure_folder/pwa/.env")

if not ENV_PATH.exists():
    raise FileNotFoundError(f"Критическая ошибка: Файл конфигурации не найден по пути {ENV_PATH}")

# Загружаем переменные окружения
load_dotenv(dotenv_path=ENV_PATH)
DATABASE_URL = os.getenv("DATABASE_URL")
HOUSEHOLD_DATABASE_URL = os.getenv("HOUSEHOLD_DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("Переменная DATABASE_URL не найдена в файле .env или пуста.")
if not HOUSEHOLD_DATABASE_URL:
    raise ValueError("Переменная HOUSEHOLD_DATABASE_URL не найдена.")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

household_engine = create_engine(HOUSEHOLD_DATABASE_URL)
HouseholdSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=household_engine)

def get_session():
    with SessionLocal() as session:
        yield session

def get_household_session():
    with HouseholdSessionLocal() as session:
        yield session