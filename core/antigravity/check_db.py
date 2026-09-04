import os
import psycopg2
from dotenv import load_dotenv

# Поддержка WSL и Windows путей
from pathlib import Path

env_paths = [
    Path("/home/fujitsu-u745/Projects/secure_folder/antigravity/.env"),
    Path(r"Z:\home\fujitsu-u745\Projects\secure_folder\antigravity\.env"),
]

loaded = False
for path in env_paths:
    if path.exists():
        print(f"Чтение конфигурации из: {path}")
        load_dotenv(dotenv_path=path)
        loaded = True
        break

if not loaded:
    print("❌ ОШИБКА: Файл .env не найден по указанным путям!")

db_name = os.getenv("DB_NAME")
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")
db_host = os.getenv("DB_HOST", "localhost")
db_port = os.getenv("DB_PORT", "5432")

print(f"Попытка подключения к БД '{db_name}' на {db_host}:{db_port} от имени '{db_user}'...")

try:
    conn = psycopg2.connect(
        dbname=db_name,
        user=db_user,
        password=db_password,
        host=db_host,
        port=db_port
    )
    cur = conn.cursor()
    cur.execute("SELECT current_user, current_database(), version();")
    u, db, ver = cur.fetchone()
    print("\n✅ УСПЕШНОЕ ПОДКЛЮЧЕНИЕ К БД!")
    print(f"Пользователь: {u}")
    print(f"База данных: {db}")
    print(f"Версия PostgreSQL: {ver}")
    cur.close()
    conn.close()
except Exception as e:
    print(f"\n❌ ОШИБКА ПОДКЛЮЧЕНИЯ К БД: {e}")
