import json
import psycopg2
import contextlib
import collections
from psycopg2.extras import RealDictCursor
from config import get_db_connection

# Строгий список полей из DDL transactions
EXPECTED_FIELDS = {
    'id', 'code', 'parent_id', 'transaction_name', 'amount', 'currency_id', 
    'operation_date', 'operation_time', 'registration_date', 'type_id', 
    'entity_id', 'category_id', 'responsible_id', 'contragent_from_id', 
    'contragent_to_id', 'account_id', 'source_extraction_id', 'tx_hash', 
    'status', 'created_at'
}

# Словарь для перехвата частых опечаток в JSON
FIELD_MAPPING = {
    'name': 'transaction_name',
    'contragen_to_name': 'contragent_to_id',
    'contragent_to_name': 'contragent_to_id',
    'contragen_from_name': 'contragent_from_id',
    'contragent_from_name': 'contragent_from_id'
}

uuid_cache = {}

def get_safe_corrections(res):
    """Безопасное извлечение списка коррекций, учитывающее None и строки."""
    data = res.get('changes', {}).get('suggested_correction')
    if isinstance(data, list): 
        return data
    if isinstance(data, str):
        try:
            parsed = json.loads(data)
            return parsed if isinstance(parsed, list) else []
        except: 
            return []
    return [] # Возвращает пустой список, если data это None

def get_uuid_label(conn, uuid_val):
    """Расшифровка UUID в формате: Имя Код UUID."""
    if not uuid_val or len(str(uuid_val)) != 36: 
        return f"??? ??? {uuid_val}"
    if uuid_val in uuid_cache: 
        return uuid_cache[uuid_val]
        
    tables = [
        ('dicts.contragents', 'contragent_name', 'contragent_id'),
        ('dicts.entities', 'entity_name', 'entity_id'),
        ('dicts.accounts', 'account_name', 'account_id'),
        ('dicts.dict_categories', 'category_name', 'category_id'),
        ('dicts.dict_types', 'type_name', 'type_id'),
        ('dicts.responsibles', 'resp_name', 'responsible_id')
    ]
    
    with contextlib.closing(conn.cursor()) as cur:
        for table, name_col, id_col in tables:
            try:
                cur.execute(f"SELECT {name_col}, {id_col} FROM {table} WHERE id = %s::uuid LIMIT 1", (uuid_val,))
                res = cur.fetchone()
                if res:
                    label = f"{res[0]} {res[1]} {uuid_val}"
                    uuid_cache[uuid_val] = label
                    return label
            except psycopg2.Error: 
                continue
                
    fallback = f"??? ??? {uuid_val}"
    uuid_cache[uuid_val] = fallback
    return fallback

def get_parsed_data(raw_resp):
    """Безопасное извлечение JSON из строки."""
    if isinstance(raw_resp, dict): 
        return raw_resp
    if isinstance(raw_resp, str):
        try:
            data = json.loads(raw_resp)
            return data if isinstance(data, dict) else {}
        except (json.JSONDecodeError, TypeError): 
            return {}
    return {}

def generate_report():
    conn = get_db_connection()
    try:
        with contextlib.closing(conn.cursor(cursor_factory=RealDictCursor)) as cur:
            cur.execute("""
                SELECT s.raw_response, t.*
                FROM audit.staging_audit_results s
                JOIN audit.transactions_fullfields t ON s.transaction_id = t.transaction_id
                WHERE s.status = 'need_correction'
                ORDER BY t.transaction_code ASC, t.operation_date ASC;
            """)
            rows = cur.fetchall()
            
            field_errors, typo_errors, mapping_errors = set(), set(), set()
            
            # Проход 1: Сбор ошибок ключей и маппинга UUID
            for row in rows:
                data = get_parsed_data(row.get('raw_response'))
                tx_id = row.get('transaction_id')
                for res in data.get('audit_results', []):
                    for corr in get_safe_corrections(res):
                        if not isinstance(corr, dict):
                            continue
                            
                        field = corr.get('field')
                        val = corr.get('value')
                        
                        if field not in EXPECTED_FIELDS:
                            if field in FIELD_MAPPING:
                                typo_errors.add(f"TX {tx_id}: Опечатка '{field}' -> '{FIELD_MAPPING[field]}'")
                            else:
                                field_errors.add(f"TX {tx_id}: Неизвестное поле '{field}'")
                        
                        if isinstance(val, str) and len(val) == 36 and '-' in val:
                            if get_uuid_label(conn, val).startswith("???"):
                                mapping_errors.add(f"{val} - ошибка маппинга.")
            
            # Проход 2: Запись отчета с полными карточками
            with open("audit_report.txt", "w", encoding="utf-8") as f:
                f.write("=== СПИСОК ОБНАРУЖЕННЫХ ОШИБОК ===\n")
                if not field_errors and not typo_errors and not mapping_errors:
                    f.write("Ошибок не обнаружено.\n")
                else:
                    for err in sorted(typo_errors | field_errors | mapping_errors):
                        f.write(f"{err}\n")
                
                f.write("\n" + "="*80 + "\n")
                
                for row in rows:
                    tx_id_display = row.get('transaction_id', 'Unknown')
                    
                    # Формирование шапки карточки
                    f.write("="*80 + "\n")
                    f.write(f"ТРАНЗАКЦИЯ (ID: {tx_id_display})\n")
                    f.write("-"*80 + "\n")
                    
                    # КРАТКИЙ ФОРМАТ: Карточка транзакции закомментирована
                    # Вывод всех полей транзакции
                    #for k, v in row.items():
                    #    if k != 'raw_response':
                    #        display_val = "None" if v is None else str(v)
                    #        f.write(f"{k.upper():<20}: {display_val}\n")
                    
                    # Блок корректировок AI
                    f.write("-"*80 + "\n")
                    f.write("Действие / Корректировка:\n")
                    f.write("-"*80 + "\n")
                    
                    data = get_parsed_data(row.get('raw_response'))
                    for res in data.get('audit_results', []):
                        reasoning = res.get('reasoning', 'No reasoning provided')
                        f.write(f"Reasoning: {reasoning}\n\n")
                        
                        for corr in get_safe_corrections(res):
                            if not isinstance(corr, dict):
                                continue
                                
                            field = corr.get('field')
                            val = corr.get('value')
                            label = get_uuid_label(conn, val) if (isinstance(val, str) and len(val)==36) else ""
                            label_str = f" ({label})" if label else ""
                            
                            f.write(f"FIELD: {field:<20} | VALUE: {val}{label_str}\n")
                    f.write("\n\n")
                    
        print("[УСПЕХ] Отчет сгенерирован в файл: audit_report.txt")

        # Проход II: Запись короткого списка для формирования SQL
        unique_txs = set()
        field_stats = collections.Counter()
        
        with open("sql_instructions.txt", "w", encoding="utf-8") as f:
            for row in rows:
                tx_id = row.get('transaction_id')
                unique_txs.add(tx_id)
                data = get_parsed_data(row.get('raw_response'))
                
                for res in data.get('audit_results', []):
                    for corr in get_safe_corrections(res):
                        if not isinstance(corr, dict): continue
                        field, val = corr.get('field'), corr.get('value')
                        
                        # Запись строки
                        f.write(f"{tx_id} | {field} | {val}\n")
                        
                        # Сбор статистики
                        field_stats[field] += 1
            
            # Дописываем статистику в конец файла
            f.write("\n" + "="*80 + "\n")
            f.write("СТАТИСТИКА ПРАВОК\n")
            f.write(f"Количество уникальных транзакций: {len(unique_txs)}\n")
            f.write("-"*40 + "\n")
            for field, count in field_stats.most_common():
                f.write(f"{field:<20}: {count} правок\n")
                
        print("[УСПЕХ] Отчет с инструкциями и статистикой готов.")

        # --- БЛОК III: Формирование SQL-запросов (отдельный файл) ---
        seen_corrections = {}
        uuid_fields = {
            'parent_id', 'currency_id', 'type_id', 'entity_id', 
            'category_id', 'responsible_id', 'contragent_from_id', 
            'contragent_to_id', 'account_id', 'source_extraction_id'
        }

        with open("update_queries.sql", "w", encoding="utf-8") as f_sql, \
             open("conflicts.txt", "w", encoding="utf-8") as f_conf:
            
            for row in rows:
                tx_id = row.get('transaction_id')
                data = get_parsed_data(row.get('raw_response'))
                
                for res in data.get('audit_results', []):
                    for corr in get_safe_corrections(res):
                        if not isinstance(corr, dict): continue
                        
                        field, val = corr.get('field'), corr.get('value')
                        key = f"{tx_id}|{field}"
                        
                        if key in seen_corrections:
                            if seen_corrections[key] != val:
                                f_conf.write(f"TX {tx_id} | Field {field} | Conflict: {seen_corrections[key]} != {val}\n")
                            continue 
                        
                        seen_corrections[key] = val
                        
                        # Экранируем одинарные кавычки в значении перед формированием SQL
                        clean_val = str(val).replace("'", "''")
                        
                        # Генерация SQL-запроса
                        if field in uuid_fields:
                            # Для UUID экранирование тоже безопасно, если вдруг придет строка с мусором
                            sql = f"UPDATE public.transactions SET {field} = '{clean_val}'::uuid WHERE id = '{tx_id}'::uuid;"
                        else:
                            # Для обычных полей (например, transaction_name) это критически важно
                            sql = f"UPDATE public.transactions SET {field} = '{clean_val}' WHERE id = '{tx_id}'::uuid;"
                        
                        f_sql.write(f"{sql}\n")
        
        print("[УСПЕХ] Файлы update_queries.sql и conflicts.txt успешно созданы.")
    finally:
        if conn and not conn.closed:
            conn.close()

if __name__ == "__main__":
    generate_report()