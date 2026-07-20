import psycopg2
import os
import time
import logging
from dotenv import load_dotenv

class QueryRegistry:
    _queries = {}

    @classmethod
    def register(cls, queries: dict):
        cls._queries.update(queries)

    @classmethod
    def get(cls, key: str):
        if key not in cls._queries:
            raise KeyError(f"Запрос '{key}' не найден в реестре!")
        return cls._queries[key]

_STATUS_CACHE = {}
def get_db_connection():
    # traceback: exclude
    print(f"DEBUG: Connecting to DB: {os.getenv('DB_NAME')} as {os.getenv('DB_USER')} at {os.getenv('DB_HOST')}")
    return psycopg2.connect(
        dbname=os.getenv("DB_NAME"), 
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"), 
        host=os.getenv("DB_HOST"), 
        port=os.getenv("DB_PORT")
    )
    # Отладочный блок
    cur = conn.cursor()
    cur.execute("SELECT current_user, current_database(), current_schema();")
    u, db, schema = cur.fetchone()
    print(f"DEBUG: Подключились как: {u} к БД: {db}, схема по умолчанию: {schema}")
    cur.close()

def _validate_connection(conn):
    """Проверяет состояние соединения с паузой при ошибке."""
    if conn is None or conn.closed != 0:
        logging.error("Соединение с БД потеряно! Ожидание перед попыткой доступа...")
        time.sleep(5)  # Пауза 5 секунд, чтобы не «спамить» сеть и БД
        raise psycopg2.OperationalError("Database connection is closed.")
    return conn

def db_get_stats(conn, query_key, params):
    """Возвращает данные как словарь для удобного доступа по именам."""
    conn = _validate_connection(conn)
    query = QueryRegistry.get(query_key)
    with conn.cursor() as cur:
        cur.execute(query, params)
        colnames = [desc[0] for desc in cur.description]
        row = cur.fetchone()
        return dict(zip(colnames, row)) if row else {}

def load_status_cache(conn):
    """Строго наполняет кэш из БД. Вызывается только внутри функций с живым conn."""
    conn = _validate_connection(conn)
    global _STATUS_CACHE
    if conn is None:
        return  # Защита от случайного вызова без соединения
        
    query = "SELECT code, id FROM dicts.dict_statuses WHERE entity_type = 'api_requests'"
    with conn.cursor() as cur:
        cur.execute(query)
        # row[0] - код ('PENDING'), row[1] - UUID из базы
        _STATUS_CACHE = {row[0]: row[1] for row in cur.fetchall()}


def get_status_id(conn, entity_type, code):
    conn = _validate_connection(conn)
    query = "SELECT id FROM dicts.dict_statuses WHERE entity_type = %s AND code = %s"
    
    with conn.cursor() as cur:
        cur.execute(query, (entity_type, code))
        row = cur.fetchone()
        
    # Добавим вывод для отладки
    if not row:
        print(f"DEBUG: Статус не найден для: entity_type={entity_type}, code={code}")
        raise RuntimeError(f"Статус '{code}' для '{entity_type}' не найден!")
        
    print(f"DEBUG: Найден ID для {code}: {row[0]}")
    return row[0]

def db_execute_update(conn, query_key, params):
    """Выполняет UPDATE/DELETE."""
    conn = _validate_connection(conn)
    query = QueryRegistry.get(query_key)
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
    except Exception as e:
        conn.rollback()
        logging.error(f"DB Update Error: {e}")
        raise

def db_execute(conn, query_key, params):
    """Выполняет запрос INSERT или сложный INSERT/UPDATE, возвращая результат."""
    conn = _validate_connection(conn)
    query = QueryRegistry.get(query_key)
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            # Если запрос возвращает данные (например, RETURNING id), берем их
            if cur.description:
                result = cur.fetchone()
                val = result[0] if result else None
            else:
                val = True
            conn.commit()
            return val
    except Exception as e:
        conn.rollback()
        logging.error(f"DB Execute Error: {e}")
        raise

def db_fetch_val(conn, query_key, params=None, default=None):
    """Выполняет запрос и возвращает единственное значение."""
    conn = _validate_connection(conn)
    query = QueryRegistry.get(query_key)
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            result = cur.fetchone()
            return result[0] if result else default
    except Exception as e:
        logging.error(f"DB Error: {e}")
        return default # Позволяет легко реализовать логику fail-closed

def db_fetch_row(conn, query_key, params=None, key=None):
    """
    Выполняет запрос, забирает одну строку (fetchone) и возвращает:
    - Если передан key: конкретное значение этой колонки (строку, число и т.д.).
    - Если key равен None: всю строку в виде словаря {имя_колонки: значение}.
    """
    conn = _validate_connection(conn)
    query = QueryRegistry.get(query_key)
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            if not cur.description:
                return None
            
            row = cur.fetchone()
            if not row:
                return None
            
            # Собираем словарь: сопоставляем имена колонок из SELECT с их значениями
            columns = [desc[0] for desc in cur.description]
            row_dict = dict(zip(columns, row))
            
            # Если попросили конкретное поле — отдаем его, иначе весь словарь
            if key is not None:
                return row_dict.get(key)
            return row_dict
            
    except Exception as e:
        logging.error(f"DB Error (fetch_row): {e}")
        raise