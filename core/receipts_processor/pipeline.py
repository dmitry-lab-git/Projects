# receipts_processor/pipeline.py
import core
print("Пакет core импортируется из:", core.__file__)
import logging
import json
import uuid
import random
from api_manager.service import secure_api_call
from api_manager.exceptions import ExceptionHandler
# Добавили get_status_id в импорт
from core.db_utils.db_access import get_db_connection, db_execute, db_fetch_val, db_fetch_row, get_status_id
from receipts_processor.document_processor import DocumentProcessor
from receipts_processor.prompt_manager import PROMPT_CONTENT
from receipts_processor.status_manager import StatusRegistry

def safe_parse_json(result):
    if not result:
        logging.error("safe_parse_json: Получен пустой результат от API.")
        return None
    if isinstance(result, (dict, list)):
        return result
    try:
        clean_result = result.strip()
        if clean_result.startswith('```'):
            clean_result = clean_result.split('```')
            clean_result = clean_result[1] if len(clean_result) > 1 else clean_result[0]
            if clean_result.startswith('json'):
                clean_result = clean_result[4:]
            clean_result = clean_result.strip()
        return json.loads(clean_result)
    except Exception as e:
        logging.error(f"safe_parse_json: Ошибка парсинга: {e}. Сырой ответ: {result[:100]}...")
        return None

def run_receipts_pipeline(client, prompt_text):
    conn = get_db_connection()
    registry = StatusRegistry(conn)
    try:
        status_legal = db_fetch_val(conn, "GET_STATUS_ID", ('UNVERIFIED', 'legal_entities'))
        status_receipt = db_fetch_val(conn, "GET_STATUS_ID", ('NEW', 'receipts'))

        while True:
            file_record = db_fetch_row(conn, "GET_NEXT_UNPROCESSED_FILE", ())
            if not file_record:
                logging.info("Очередь пуста. Все файлы обработаны.")
                break
            
            file_uuid = file_record.get('id') or file_record.get('file_uuid')
            file_path = file_record.get('file_path')

            logging.info(f"Взят в работу файл: {file_uuid}")

            try:
                # Статус PROCESSING
                with conn: 
                    db_execute(conn, "UPDATE_FILE_STATUS", (get_status_id(conn, 'source_files', 'PROCESSING'), file_uuid))
        
                result = secure_api_call(client=client, prompt_text=prompt_text, conn=conn, source_uuid=file_uuid, file_path=file_path)
                
                if not result:
                    logging.warning(f"Файл {file_uuid}: API не вернул данные.")
                    with conn: 
                        db_execute(conn, "UPDATE_FILE_STATUS", (get_status_id(conn, 'source_files', 'API_ERROR'), file_uuid))
                    continue
                
                receipt_data = safe_parse_json(result)
                if not receipt_data:
                    logging.error(f"Файл {file_uuid}: Не удалось распарсить JSON.")
                    with conn: 
                        db_execute(conn, "UPDATE_FILE_STATUS", (get_status_id(conn, 'source_files', 'NEEDS_REVIEW'), file_uuid))
                    continue

                documents = receipt_data.get("extracted_documents", [])
                with conn:
                    for doc in documents:
                        success, error = DocumentProcessor.process_and_save(conn, doc, file_uuid, status_receipt, status_legal)
                        if not success:
                            logging.error(f"Файл {file_uuid}: {error}")
                            continue

                    db_execute(conn, "UPDATE_FILE_STATUS", (get_status_id(conn, 'source_files', 'FINISHED'), file_uuid))
                    logging.info(f"Файл {file_uuid} успешно завершен.")

            except json.JSONDecodeError as jde:
                logging.error(f"Ошибка парсинга JSON для файла {file_uuid}: {jde}")
                with conn: 
                    db_execute(conn, "UPDATE_FILE_STATUS", (get_status_id(conn, 'source_files', 'NEEDS_REVIEW'), file_uuid))
            except Exception as e:
                conn.rollback()
                with conn: 
                    db_execute(conn, "UPDATE_FILE_STATUS", (get_status_id(conn, 'source_files', 'API_ERROR'), file_uuid))
                logging.error(f"Файл {file_uuid} завершился с ошибкой: {e}")
                
    finally:
        conn.close()

if __name__ == "__main__":
    from google import genai
    import os
    from dotenv import load_dotenv
    load_dotenv("/home/fujitsu-u745/Projects/secure_folder/api_manager/.env")
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
    logging.basicConfig(level=logging.INFO)
    run_receipts_pipeline(client, PROMPT_CONTENT)