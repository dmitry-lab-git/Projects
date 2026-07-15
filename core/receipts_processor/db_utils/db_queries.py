# SQL-запросы для модуля обработки чеков
QUERIES = {
    # Работа с source_files
    "GET_FILE_ID_BY_PATH": """
        SELECT id FROM public.source_files WHERE file_path = %s
    """,
    "INSERT_SOURCE_FILE": """
        INSERT INTO public.source_files 
        (id, file_name, file_path, file_size, file_hash, upload_date, created_at, status_id) 
        VALUES (%s, %s, %s, %s, %s, CURRENT_DATE, CURRENT_TIMESTAMP, %s)
    """,
    "GET_UNPROCESSED_PHOTOS": """
        SELECT id, file_path 
        FROM public.source_files 
        WHERE status_id = (SELECT id FROM dicts.dict_statuses WHERE code = 'READY_TO_SEND' AND entity_type = 'source_files')
    """,
    "UPDATE_PHOTO_STATUS": """
        UPDATE public.source_files 
        SET status_id = (SELECT id FROM dicts.dict_statuses WHERE code = %s AND entity_type = 'source_files')
        WHERE id = %s
    """,

    # Работа с receipts
    "INSERT_RECEIPT": """
        INSERT INTO public.receipts 
        (id, code, source_photo_id, receipt_index_on_photo, amount, currency_id, operation_date, description, created_at, status_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP, %s)
    """
}