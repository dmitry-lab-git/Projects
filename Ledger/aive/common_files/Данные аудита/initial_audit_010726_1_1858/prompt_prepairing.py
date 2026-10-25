import json
import re
from api_utils import secure_api_call
import logging
from decimal import Decimal
import datetime
from api_utils import json_serial

TRANSACTION_FIELDS = [
    "transaction_name", "entity_id", "entity_name", "category_id",
    "category_name", "contragent_from_id", "contragent_from_name",
    "contragent_to_id", "contragent_to_name", "account_id",
    "account_name", "type_id", "type_name", "amount",
    "tr_currency", "code", "operation_date"
]

def get_max_transaction_code(conn):
    """
    Получает текущий максимальный код транзакции. 
    Стартовое значение согласно ТЗ: 1850.
    """
    with conn.cursor() as cur:
        cur.execute("SELECT COALESCE(MAX(code), 1849) FROM audit.transactions_fullfields;")
        return cur.fetchone()[0]

def fetch_pending_tx_data(conn, limit=13):
    query = """
    SELECT id, source_extraction_id, raw_line_text, processing_metadata
    FROM audit.tx_pending_posting
    WHERE status = 'pending'
    ORDER BY created_at ASC
    LIMIT %s
    FOR UPDATE SKIP LOCKED;
    """
    with conn.cursor() as cur:
        cur.execute(query, (limit,))
        rows = cur.fetchall()

        batch = []
        for row in rows:
            # Берем метаданные
            meta = row[3]
            # ПРИНУДИТЕЛЬНО делаем метаданные словарем
            if isinstance(meta, str):
                try: meta = json.loads(meta)
                except: meta = {}
            elif meta is None:
                meta = {}

            batch.append({
                "id": row[0],
                "source_extraction_id": row[1],
                "raw_line_text": row[2],
                "processing_metadata": meta  # Теперь это гарантированно словарь
            })
        return batch

def update_tx_status(conn, tx_id, new_status="processed"):
    """
    Обновляет статус транзакции в таблице tx_pending_posting по первичному ключу id.
    """
    query = "UPDATE audit.tx_pending_posting SET status = %s WHERE id = %s"
    
    # Используем контекстный менеджер для курсора, чтобы гарантировать его закрытие
    with conn.cursor() as cur:
        cur.execute(query, (new_status, tx_id))
        conn.commit()

def get_tx_template(conn, template_id):
    """
    Извлекает эталонный шаблон транзакции из processing.transactions_templates.
    template_id передается как входной параметр.
    """
    query = """
        SELECT sample_data 
        FROM processing.transactions_templates 
        WHERE template_id = %s
    """
    with conn.cursor() as cur:
        cur.execute(query, (template_id,))
        result = cur.fetchone()
        return result[0] if result else None

def extract_keywords_batch(client, tx_batch, conn):
    """Извлекает ключевые слова только для транзакций, где они еще NULL."""
    
    # Отфильтровываем те, где keywords уже заполнены
    pending = [tx for tx in tx_batch if tx.get("processing_metadata", {}).get("keywords") is None]
    
    if not pending:
        logging.info("Все ключевые слова уже заполнены.")
        return {tx["id"]: tx.get("processing_metadata", {}).get("keywords", []) for tx in tx_batch}

    logging.info(f"Дозаполнение ключевых слов для {len(pending)} транзакций.")
    
    batch_log_id = str(pending[0]["id"])
    prompt = (
        "Вы — анализатор транзакций. Извлеките уникальные ключевые слова. Проверьте наличие дубликатов по всему массиву пакета. Уникальность должна быть соблюдена на весь пакет данных "
        "Верните ответ строго в JSON: {\"results\": [{\"id\": \"uuid1\", \"keywords\": [\"w1\", \"w2\"]}, ...]}"
        + json.dumps([{"id": item["id"], "text": item["raw_line_text"]} for item in pending])
    )

    response_text = secure_api_call(
        client=client, prompt_text=prompt, 
        conn=conn, source_uuid=batch_log_id
    )

    try:
        clean_json = response_text.replace("```json", "").replace("```", "").strip()
        data = json.loads(clean_json)
        results = {item["id"]: item.get("keywords", []) for item in data.get("results", [])}
        
        with conn.cursor() as cur:
            for item in pending:
                tx_id = item["id"]
                # 1. Извлекаем слова
                raw_kws = results.get(tx_id, [])
                kws = [str(w).strip() for w in raw_kws if len(str(w).strip()) > 2]
                # 2. Если слов нет, ставим маркер-заглушку
                final_kws = kws if kws else ["keywords_not_found"]
                # 3. Сохраняем в БД (теперь там будет либо список слов, либо маркер)
                cur.execute(
                    "UPDATE audit.tx_pending_posting SET keywords = %s WHERE id = %s",
                    (final_kws, tx_id)
                )
        conn.commit()
        
        # Обновляем локальный список для следующего шага
        for tx in tx_batch:
            if tx["id"] in results: tx["keywords"] = results[tx["id"]]
        return {tx["id"]: tx.get("keywords", []) for tx in tx_batch}
    except Exception as e:
        logging.error(f"Ошибка парсинга Batch JSON: {e}")
        return {tx["id"]: [] for tx in tx_batch}

def find_relevant_rows_batch(conn, tables_config, keyword_map):
    """Ищет примеры только там, где transaction_examples еще NULL."""
    all_results = {}
    with conn.cursor() as cur:
        for tx_id, keywords in keyword_map.items():
            if not keywords or keywords == ["keywords_not_found"]:
                continue
            
            # Проверяем, есть ли уже примеры
            cur.execute("SELECT transaction_examples FROM audit.tx_pending_posting WHERE id = %s", (tx_id,))
            existing = cur.fetchone()[0]
            if existing:
                all_results[tx_id] = existing
                continue

            tx_results = {}
            for table, column in tables_config.items():
                cur.execute(f"SELECT {', '.join(TRANSACTION_FIELDS)} FROM {table} WHERE {column} && %s::text[] LIMIT 2", (keywords,))
                rows = cur.fetchall()
                if rows:
                    tx_results[table] = [dict(zip(TRANSACTION_FIELDS, row)) for row in rows]
            
            cur.execute(
                "UPDATE audit.tx_pending_posting SET transaction_examples = %s WHERE id = %s", 
                (json.dumps(tx_results, default=json_serial), tx_id)
            )
            all_results[tx_id] = tx_results
        conn.commit()
    return all_results
    
def prepare_final_prompt(batch_data, examples_map):
    """
    Формирует финальный промпт для всего батча транзакций.
    batch_data: список словарей транзакций (из fetch_pending_tx_data).
    examples_map: словарь {tx_id: {table: [rows_data]}}.
    """
    
    def convert_types(obj):
        if isinstance(obj, (datetime.date, datetime.datetime)):
            return obj.isoformat()
        if isinstance(obj, Decimal):
            return float(obj)
        if isinstance(obj, dict):
            return {k: convert_types(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [convert_types(v) for v in obj]
        return obj

    # Подготовка данных для всех транзакций в батче
    prepared_batch = []
    for tx in batch_data:
        tx_id = tx["id"]
        prepared_batch.append({
            "id": tx_id,
            "raw_line_text": tx["raw_line_text"],
            "processing_metadata": convert_types(tx["processing_metadata"]),
            "examples": convert_types(examples_map.get(tx_id, {}))
        })

    # Формирование JSON-строки для промпта
    batch_json = json.dumps(prepared_batch, ensure_ascii=False)

    # Итоговый промпт
    final_prompt = f"""
    Задача: заполнить данные транзакции из пакета, нормализовать согласно примеров и вернуть результат в формате JSON-массива.
    
    ПРАВИЛА:
    1. Инкремент 'code' начинается с 1851.
    2. 'transaction_id' равен 'TRS-' + 'code'.
    3. Значения по умолчанию: 'tr_currency': 'KZT', 'responsible_id': 'RSP-001'.
    4. Произведите сортировку транзакций в хронологическом порядке. .
    5. СТРОГОЕ ОГРАНИЧЕНИЕ: Для каждой входной записи (из блока ВХОДНЫЕ ДАННЫЕ) создавайте ровно ОДНУ транзакцию. 
        НЕ создавайте транзакции на основе данных из блока ПРИМЕРЫ.
    6. ПРИМЕРЫ (examples) используются ТОЛЬКО для определения категорий и контрагентов. 
        Сумма (amount) и дата (operation_date) должны быть взяты ТОЛЬКО из 'raw_line_text'.

    Constraint: ["You are a financial data processor. Output format: STRICT JSON. 
    Numbers in 'amount' field MUST be numbers (float or int). 
    NO text, NO currency symbols, NO special characters like hieroglyphs. 
    Example: 'amount': 3450.00. Fail if you cannot guarantee this."]
    
    ВХОДНЫЕ ДАННЫЕ ТРАНЗАКЦИЙ(JSON):
    {batch_json}

    Верните строго JSON-массив объектов (список), соответствующий структуре:
    [
      {{"id UUID", "code", "transaction_name", "entity_id", "entity_name", "category_id",
    "category_name", "contragent_from_id", "contragent_from_name",
    "contragent_to_id", "contragent_to_name", "account_id",
    "account_name", "type_id", "type_name", "amount",
    "tr_currency", "code", "operation_date"}},
      ...
    ]
    Важно: вначале JSON должен быть именно тот id UUID, который был внутри {batch_json}.
    Не пишите никаких пояснений, только JSON.
    """
    
    return final_prompt