# receipts_processor/document_processor.py
import logging
import json
import uuid
from core.db_utils.db_access import db_execute, db_fetch_val

class DocumentProcessor:
    @staticmethod
    def validate_document(doc):
        """Проверка целостности отдельного чека."""
        transaction = doc.get("transaction", {})
        if transaction.get("total_amount") is None:
            return False, "Отсутствует total_amount"
        return True, None

    @staticmethod
    def process_api_response(receipt_data):
        """Фильтрация всего ответа."""
        valid_docs = []
        documents = receipt_data.get("extracted_documents", [])
        for doc in documents:
            is_valid, error = DocumentProcessor.validate_document(doc)
            if is_valid:
                valid_docs.append(doc)
            else:
                logging.warning(f"Чек пропущен: {error}")
        return valid_docs

    @staticmethod
    def process_and_save(conn, doc, file_uuid, status_receipt, status_legal):
        """Сохранение одного чека в БД."""
        transaction = doc.get("transaction", {})
        legal_data = doc.get("legal_entity", {})
        
        # 1. Поиск/Создание Юрлица
        bin_iin = legal_data.get("legal_entity_bin_iin")
        legal_name = legal_data.get("legal_entity_name")
        legal_uuid = None
        
        if bin_iin and legal_name:
            legal_record = db_fetch_val(conn, "GET_LEGAL_ENTITY_BY_TAX", (bin_iin,))
            legal_uuid = legal_record if legal_record else str(uuid.uuid4())
            if not legal_record:
                db_execute(conn, "INSERT_LEGAL_ENTITY", 
                           (legal_uuid, legal_name, bin_iin, legal_data.get("legal_entity_address"), status_legal))
        
        # 2. Валюта
        currency_code = transaction.get("currency", "KZT")
        currency_uuid = db_fetch_val(conn, "GET_CURRENCY_BY_CODE", (currency_code,))
        
        # 3. Вставка чека
        db_execute(conn, "INSERT_RECEIPT", (
            str(uuid.uuid4()), 
            file_uuid, 
            doc.get("document_index", 1), 
            status_receipt,
            json.dumps(doc, ensure_ascii=False), 
            legal_uuid, # legal_entity_id
            transaction.get("total_amount", 0.0), 
            currency_uuid, 
            transaction.get("operation_date"), 
            transaction.get("operation_time"), 
            legal_name
        ))
        return True, None