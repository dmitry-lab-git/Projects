import os
import json
import logging
from pathlib import Path
import psycopg2
from google import genai
from dotenv import load_dotenv
from rich.traceback import install

GLOBAL_RPM_LIMIT = None
GLOBAL_RPD_LIMIT = None
GLOBAL_TPM_LIMIT = None
DEFAULT_MAX_PROMPT_WEIGHT = None
DEFAULT_MAX_RETRIES = None
PACING_DELAY = None

# 1. Сначала задаем путь динамически относительно файла config.py
# Проект теперь в /home/fujitsu-u745/Projects/
# config.py находится в /home/fujitsu-u745/Projects/api_manager/config.py
BASE_DIR = Path(__file__).resolve().parent.parent
# Путь к секретам теперь ожидается здесь
secure_env_path = BASE_DIR.parent / "secure_folder" / "api_manager" / ".env"
# 2. Загружаем переменные
if secure_env_path.exists():
    load_dotenv(dotenv_path=secure_env_path)
else:
    raise FileNotFoundError(f"Файл .env не найден по пути: {secure_env_path}")

# 3. Теперь проверяем, есть ли ключ
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise ValueError(f"КЛЮЧ GEMINI_API_KEY НЕ НАЙДЕН! Проверьте файл: {secure_env_path}")

# 4. И только потом инициализируем
client = genai.Client(api_key=api_key)

# api_manager/config.py

def reload_config():
    """Чтение лимитов из settings.txt без перезапуска приложения."""
    global GLOBAL_RPM_LIMIT, GLOBAL_RPD_LIMIT, GLOBAL_TPM_LIMIT, PACING_DELAY, \
           DEFAULT_MAX_PROMPT_WEIGHT, DEFAULT_MAX_RETRIES
    
    settings_path = BASE_DIR / "api_manager" / "settings.txt"
    if not settings_path.exists():
        logging.warning(f"Файл настроек {settings_path} не найден. Используются дефолтные значения.")
        return

    try:
        with open(settings_path, "r") as f:
            for line in f:
                if "=" in line:
                    key, val = line.strip().split("=")
                    if key == "GLOBAL_RPM_LIMIT": GLOBAL_RPM_LIMIT = int(val)
                    elif key == "GLOBAL_RPD_LIMIT": GLOBAL_RPD_LIMIT = int(val)
                    elif key == "GLOBAL_TPM_LIMIT": GLOBAL_TPM_LIMIT = int(val)
                    elif key == "PACING_DELAY": PACING_DELAY = int(val)
                    elif key == "DEFAULT_MAX_PROMPT_WEIGHT": DEFAULT_MAX_PROMPT_WEIGHT = int(val)
                    elif key == "DEFAULT_MAX_RETRIES": DEFAULT_MAX_RETRIES = int(val)
        logging.info("Настройки успешно обновлены из settings.txt")
    except Exception as e:
        logging.error(f"Ошибка при обновлении конфигурации: {e}")

def setup_error_handling():
    """Настраивает лаконичное и красивое отображение ошибок."""
    install(
        show_locals=False,     # Покажет значения переменных внутри функций
        width=100,            # Ограничит ширину вывода
        extra_lines=0,        # Скроет строки кода ДО и ПОСЛЕ ошибки
        theme="monokai",      # Стиль подсветки кода
        word_wrap=True,       # Аккуратно перенесет длинные строки
        
        # --- ОГРАНИЧЕНИЯ ДЛЯ СТАРОЙ ВЕРСИИ RICH ---
        locals_max_string=60,     # Срежет длинные строки внутри блока locals (например, ai_notes)
        locals_max_length=3,      # Покажет только 3 элемента в словарях/списках (свернет tx_data)
        # -------------------------------------------
        
        suppress=[            # Скроет системный мусор из логов
            "click",          
            "requests",       
            "psycopg2",       
        ],
        locals_hide_sunder=["DB_PASS", "password", "secret"]  
    )

def get_db_connection():
    # traceback: exclude
    return psycopg2.connect(
        dbname=os.getenv("DB_NAME"), 
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASS"), 
        host=os.getenv("DB_HOST"), 
        port=os.getenv("DB_PORT")
    )

setup_error_handling()

def load_models_config():
    """Загрузка конфигурации моделей из models_config.json."""
    config_path = BASE_DIR / "api_manager" / "models_config.json"
    try:
        if config_path.exists():
            with open(config_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("ALLOWED_MODELS", []), data.get("MODEL_LIMITS", {})
    except Exception as e:
        # Логирование через стандартный logging, если он настроен
        print(f"Ошибка загрузки моделей: {e}") 
    return [], {}

ALLOWED_MODELS, MODEL_LIMITS = load_models_config()

def reload_models_config():
    global ALLOWED_MODELS, MODEL_LIMITS
    ALLOWED_MODELS, MODEL_LIMITS = load_models_config()

# Инициализируем настройки при запуске
reload_config()



