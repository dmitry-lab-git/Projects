# Data Access Layer
import psycopg2
from api_manager.db_utils.db_queries import QUERIES
import logging

_STATUS_CACHE = {}

def db_get_stats(conn, query_key, params):
    """Возвращает данные как словарь для удобного доступа по именам."""
    query = QUERIES.get(query_key)
    with conn.cursor() as cur:
        cur.execute(query, params)
        colnames = [desc[0] for desc in cur.description]
        row = cur.fetchone()
        return dict(zip(colnames, row)) if row else {}

def load_status_cache(conn):
    """Строго наполняет кэш из БД. Вызывается только внутри функций с живым conn."""
    global _STATUS_CACHE
    if conn is None:
        return  # Защита от случайного вызова без соединения
        
    query = "SELECT code, id FROM dicts.dict_statuses WHERE entity_type = 'aive_api_requests'"
    with conn.cursor() as cur:
        cur.execute(query)
        # row[0] - код ('PENDING'), row[1] - UUID из базы
        _STATUS_CACHE = {row[0]: row[1] for row in cur.fetchall()}

def get_status_id(conn, code):
    """
    Быстро и надежно возвращает UUID статуса напрямую из базы данных.
    Код строго в ВЕРХНЕМ РЕГИСТРЕ.
    """
    query = "SELECT id FROM dicts.dict_statuses WHERE entity_type = 'aive_api_requests' AND code = %s"
    with conn.cursor() as cur:
        cur.execute(query, (code,))
        row = cur.fetchone()
        
        if not row:
            raise RuntimeError(f"Критическая ошибка: Статус '{code}' не найден в таблице dicts.dict_statuses!")
            
        return row[0]

def db_execute_update(conn, query_key, params):
    """Выполняет UPDATE/DELETE."""
    query = QUERIES.get(query_key)
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
        # Убираем commit отсюда, если управление транзакцией 
        # вынесено в функции верхнего уровня
    except Exception as e:
        conn.rollback()
        logging.error(f"DB Update Error: {e}")
        raise

def db_execute(conn, query_key, params):
    """Выполняет запрос INSERT или сложный INSERT/UPDATE, возвращая результат."""
    query = QUERIES.get(query_key)
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
    query = QUERIES.get(query_key)
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            result = cur.fetchone()
            return result[0] if result else default
    except Exception as e:
        logging.error(f"DB Error: {e}")
        return default # Позволяет легко реализовать логику fail-closed