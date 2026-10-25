import os
import psycopg2
from google import genai
from dotenv import load_dotenv
from rich.traceback import install

# Загружаем переменные один раз при импорте
load_dotenv()

# Инициализируем клиент один раз
client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

def setup_error_handling():
    """Настраивает лаконичное и красивое отображение ошибок."""
    install(
        show_locals=True,     # Покажет значения переменных внутри функций (очень помогает)
        width=100,            # Ограничит ширину вывода, чтобы текст не разъезжался
        extra_lines=1,        # Покажет только 1 строку кода ДО и ПОСЛЕ ошибки (вместо 3-5 по умолчанию)
        theme="monokai",      # Стиль подсветки кода
        word_wrap=True,       # Аккуратно перенесет длинные строки
        suppress=[            # Скроет системный мусор из логов (например, код самого Python или библиотек)
            "click",          
            "requests",       # Сюда можно вписать любые тяжелые библиотеки, ошибки которых не нужно детально разворачивать
            "psycopg2",       
        ],
        hide_locals=["DB_PASS", "password", "secret"] # Rich автоматически замажет звездочками (*) значения переменных с этими именами
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