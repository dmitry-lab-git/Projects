import os
import psycopg2
from google import genai
from dotenv import load_dotenv
from rich.traceback import install

# 1. Сначала задаем путь
secure_env_path = r"C:\Users\admin\Desktop\Ledger\secure_folder\aive\.env"

# 2. Загружаем переменные
load_dotenv(dotenv_path=secure_env_path)

# 3. Теперь проверяем, есть ли ключ
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise ValueError(f"КЛЮЧ GEMINI_API_KEY НЕ НАЙДЕН! Проверьте файл: {secure_env_path}")

# 4. И только потом инициализируем
client = genai.Client(api_key=api_key)
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

MODEL_LIMITS = {
    "gemini-3.5-flash": {"max_rpm": 5, "max_tpm": 250000, "max_rpd": 18, "priority": 10},
    "gemini-3.1-flash-lite": {"max_rpm": 15, "max_tpm": 250000, "max_rpd": 500, "priority": 5},
    "gemini-2.5-flash-lite": {"max_rpm": 10, "max_tpm": 250000, "max_rpd": 20, "priority": 2},
    "gemini-2.5-flash": {"max_rpm": 5, "max_tpm": 250000, "max_rpd": 20, "priority": 1},
    "gemma-4-31b": {"max_rpm": 15, "max_tpm": 1000000, "max_rpd": 1500, "priority": 0}
}

BLOCKED_MODELS = {}

# Определяем, какие модели разрешено использовать прямо сейчас
ALLOWED_MODELS = [
    "gemini-3.5-flash", 
    "gemini-3.1-flash-lite", 
    "gemini-2.5-flash-lite", 
    "gemini-2.5-flash"
]
GLOBAL_RPM_LIMIT = 1
GLOBAL_RPD_LIMIT = 500
GLOBAL_TPM_LIMIT = 20000
DEFAULT_MAX_PROMPT_WEIGHT = 25000
DEFAULT_MAX_RETRIES = 3
PACING_DELAY = 10

