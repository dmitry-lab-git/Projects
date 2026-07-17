# SQL-запросы для модуля обработки чеков
QUERIES = {
    # Работа с source_files
    "MARK_FILE_UNREADABLE": """
        UPDATE processing.source_files 
        SET status_id = (SELECT id FROM dicts.dict_statuses WHERE code = 'UNREADABLE')
        WHERE file_hash = %s
    """,
    "GET_FILE_ID_BY_PATH": """
        SELECT id FROM processing.source_files WHERE file_path = %s
    """,
    "INSERT_SOURCE_FILE": """
    INSERT INTO processing.source_files 
    (id, file_name, file_path, file_size, file_hash, status_id, reject_reason, created_at, upload_date) 
    VALUES (%s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, %s)
    """,
    "GET_NEXT_UNPROCESSED_FILE": """
        SELECT id, file_path 
        FROM processing.source_files
        WHERE status_id = (
            SELECT id FROM dicts.dict_statuses 
            WHERE code = 'READY_TO_SEND' AND entity_type = 'source_files'
        )
        ORDER BY id LIMIT 1
    """,
    "UPDATE_FILE_STATUS": """
        UPDATE processing.source_files
        SET status_id = (
            SELECT id FROM dicts.dict_statuses 
            WHERE code = %s AND entity_type = 'source_files'
        )
        WHERE id = %s
    """,
    "CHECK_FINISHED_BY_HASH": "SELECT id FROM processing.source_files WHERE file_hash = %s AND status_id = (SELECT id FROM dicts.dict_statuses WHERE code = 'FINISHED')",
    "GET_STATUS_ID": """
        SELECT id FROM dicts.dict_statuses 
        WHERE code = %s AND entity_type = %s
    """,
    "INSERT_LEGAL_ENTITY": """
        INSERT INTO dicts.legal_entities (id, legal_name, tax_number, legal_address, status_id)
        VALUES (%s, %s, %s, %s, %s)
    """,
    "INSERT_RECEIPT": """
        INSERT INTO processing.receipts
        (
            id, source_file_id, receipt_index_on_file, status_id, created_at, 
            raw_payload, account_id, legal_entity_id, merchant_id, contragent_id, 
            amount, currency_id, operation_date, operation_time, description
        )
        VALUES 
        (%s, %s, %s, %s, CURRENT_TIMESTAMP, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """,
    "GET_CURRENCY_BY_CODE": """
        SELECT id FROM dicts.dicts_currencies WHERE currency_id = %s
    """,
    "GET_LEGAL_ENTITY_BY_TAX": """
        SELECT id FROM dicts.legal_entities WHERE tax_number = %s
    """
}