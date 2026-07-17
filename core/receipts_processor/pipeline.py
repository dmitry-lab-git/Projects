# receipts_processor/pipeline.py
import core
print("Пакет core импортируется из:", core.__file__)
import logging
import json
import uuid
import random
from api_manager.service import secure_api_call
from api_manager.exceptions import ExceptionHandler
from core.db_utils.db_access import get_db_connection, db_execute, db_fetch_val, db_fetch_row

PROMPT_CONTENT="""Вы — экспертная система для извлечения структурированных данных из фискальных документов и кассовых чеков (преимущественно Республики Казахстан).
Ваша задача — проанализировать предоставленное изображение и извлечь все данные чеков в строгом соответствии с заданным форматом JSON.

ОСНОВНЫЕ ПРАВИЛА:
1. МНОЖЕСТВЕННОСТЬ: На одной фотографии может находиться несколько чеков. Каждый обнаруженный чек должен стать отдельным объектом в массиве `extracted_documents`.
2. ТОЧНОСТЬ: Извлекайте данные точно так, как они напечатаны. Не придумывайте названия товаров или адреса. Если данные размыты, но угадываются с высокой долей вероятности — используйте их, но обязательно добавьте предупреждение в `ai_diagnostics`.
3. ОТСУТСТВУЮЩИЕ ДАННЫЕ: Если какое-либо поле из схемы отсутствует на чеке (например, нет скидки или ИИН), возвращайте `null`. ЗАПРЕЩЕНО удалять ключи из структуры JSON.
4. МАТЕМАТИКА: Проверьте логику итоговой суммы (subtotal + vat - discount = total). Если цифры на чеке не сходятся, отразите это в `parsing_warnings`.
5. ФОРМАТ ДАТЫ И ВРЕМЕНИ: Строго ISO. Дата: YYYY-MM-DD. Время: HH:MM:SS.
6. ФИСКАЛЬНЫЕ ДАННЫЕ РК: Обращайте особое внимание на маркеры ОФД (Казахтелеком, Транстелеком, Jusan Mobile и др.), наличие QR-кода, номер смены, номер чека, фискальный признак (ФП) и заводской номер ККМ/ЗНМ.

КОНТЕКСТ И МЕТОДИКА (AI NOTES):
- Будьте внимательны к инвертированным операциям (возвраты).
- Сохраняйте исторический след: заметки о примечаниях в чеке являются важными данными для отладки, не игнорируйте их.
- Используйте поле `ai_diagnostics` для обоснования оценки достоверности данных (trust_score) и любых заметок, помогающих отладить данные.

ТРЕБУЕМАЯ СТРУКТУРА JSON (КОНТРАКТ):
{
  "file_meta": {
    "file_hash": "string (оставь пустым или null, заполняется на стороне клиента)",
    "scanned_at": "string (ISO 8601, время обработки)",
    "total_documents_found": "integer (количество чеков на фото)"
  },
  "extracted_documents": [
    {
      "document_index": "integer (порядковый номер чека на фото, начиная с 1)", 
      "legal_entity": {
        "legal_entity_name": "string (Название ИП, ТОО, магазина)",
        "legal_entity_address": "string (Полный физический адрес торговой точки)",
        "legal_entity_bin_iin": "string (12 цифр БИН или ИИН)"
      },
      "transaction": {
        "operation_date": "string (YYYY-MM-DD)",
        "operation_time": "string (HH:MM:SS)",
        "currency": "string (Например, KZT)",
        "payment_method": "string (cash / card / mixed)",
        "subtotal_amount": "number (Сумма до налогов и скидок)",
        "discount_amount": "number (Сумма скидки)",
        "vat_amount": "number (Сумма НДС, если выделена)",
        "total_amount": "number (Итоговая сумма чека)",
        "received_amount": "number (Внесенная сумма)",
        "change_amount": "number (Сдача)"
      },
      "items": [
        {
          "position": "integer (Порядковый номер позиции)",
          "name": "string (Наименование товара/услуги)",
          "quantity": "number (Количество/вес)",
          "unit": "string (шт, кг, л, упак)",
          "price_per_unit": "number (Цена за единицу)",
          "total_price": "number (Общая стоимость позиции)",
          "vat_rate": "number (Ставка НДС в процентах, например 12, если указана)"
        }
      ],
      "fiscal_data": {
        "receipt_number": "string (Порядковый номер чека)",
        "shift_number": "string (Номер смены)",
        "kkm_number": "string (Заводской номер ККМ)",
        "fiscal_sign": "string (Фискальный признак, ФП)",
        "has_qr": "boolean (Есть ли QR-код на чеке)",
        "ofd_url": "string (URL из QR-кода, если удалось распознать)"
      }
    }
  ],
  "ai_diagnostics": {
    "parsing_warnings": [
      "string (Опиши любые аномалии: неверная дата на чеке, нечитаемый текст, несовпадение итоговой суммы с позициями. Если проблем нет - пустой массив [])"
    ]
  }
}"""

def safe_parse_json(result):
    """Безопасная очистка и парсинг JSON-ответа от API."""
    if not result:
        logging.error("safe_parse_json: Получен пустой результат от API.")
        return None
    
    if isinstance(result, (dict, list)):
        return result
    
    try:
        # Убираем возможные Markdown-блоки
        clean_result = result.strip()
        if clean_result.startswith('```'):
            # Удаляем ```json или просто ``` в начале и ``` в конце
            clean_result = clean_result.split('```')
            # Берем содержимое между блоками
            clean_result = clean_result[1] if len(clean_result) > 1 else clean_result[0]
            # Убираем "json" если он приклеился сразу после ```
            if clean_result.startswith('json'):
                clean_result = clean_result[4:]
            clean_result = clean_result.strip()
        
        return json.loads(clean_result)
    except Exception as e:
        logging.error(f"safe_parse_json: Ошибка парсинга: {e}. Сырой ответ: {result[:100]}...")
        return None

def run_receipts_pipeline(client, prompt_text):
    conn = get_db_connection()
    try:
        # Кешируем статусы один раз (они не меняются)
        status_legal = db_fetch_val(conn, "GET_STATUS_ID", ('UNVERIFIED', 'legal_entities'))
        status_receipt = db_fetch_val(conn, "GET_STATUS_ID", ('NEW', 'receipts'))

        # Запускаем цикл воркера: берем один файл, обрабатываем, берем следующий
        while True:
            # Используем db_fetch_row! Берем ровно ОДНУ запись.
            # Важно: SQL-запрос должен возвращать 1 строку (например, иметь LIMIT 1)
            file_record = db_fetch_row(conn, "GET_NEXT_UNPROCESSED_FILE", ())
            
            if not file_record:
                logging.info("Очередь пуста. Все файлы обработаны.")
                break # Выходим из бесконечного цикла
            
            # Извлекаем данные
            file_uuid = file_record.get('id') or file_record.get('file_uuid')
            file_path = file_record.get('file_path')

            logging.info(f"Взят в работу файл: {file_uuid}")

            try:
                # Меняем статус на PROCESSING
                with conn: 
                    db_execute(conn, "UPDATE_FILE_STATUS", ('PROCESSING', file_uuid))
        
                # Отправляем один файл в API
                result = secure_api_call(
                    client=client, 
                    prompt_text=prompt_text, 
                    conn=conn, 
                    source_uuid=file_uuid, 
                    file_path=file_path
                )
                
                if not result:
                    logging.warning(f"Файл {file_uuid}: API не вернул данные.")
                    with conn: 
                        db_execute(conn, "UPDATE_FILE_STATUS", ('API_ERROR', file_uuid))
                    continue # Переходим к следующему файлу в цикле while
                
                logging.info(f"DEBUG: Получен ответ от API (длина: {len(str(result))}): {str(result)[:200]}...")

                
                # Распаковываем ответ
                receipt_data = safe_parse_json(result)

                if not receipt_data:
                    logging.error(f"Файл {file_uuid}: Не удалось распарсить JSON.")
                    with conn: 
                        db_execute(conn, "UPDATE_FILE_STATUS", ('NEEDS_REVIEW', file_uuid))
                    continue

                documents = receipt_data.get("extracted_documents", [])
                
                with conn:
                    for doc in documents:
                        transaction = doc.get("transaction", {})
                        legal_data = doc.get("legal_entity", {})
                        
                        doc_payload = {**doc, "file_hash": file_uuid, "ai_diagnostics": receipt_data.get("ai_diagnostics", {})}
                        
                        # Валюта
                        currency_code = transaction.get("currency", "KZT")
                        currency_uuid = db_fetch_val(conn, "GET_CURRENCY_BY_CODE", (currency_code,))
                        
                        # Юрлицо
                        bin_iin = legal_data.get("legal_entity_bin_iin")
                        legal_name = legal_data.get("legal_entity_name") # Убедимся, что оно есть
                        legal_uuid = None
                        
                        # Проверка amount:
                        if extracted_data.get("amount") is None:
                            logging.error(f"Не удалось распознать сумму для файла {file_uuid}. Пропускаем запись.")
                            # Вместо INSERT_RECEIPT, сразу вызываем обновление статуса на API_ERROR
                            db_execute(conn, "UPDATE_FILE_STATUS", ("API_ERROR", file_uuid))
                            continue  # Переходим к следующему файлу в цикле

                        # Добавляем проверку: bin_iin должен быть, И имя не должно быть None/пустым
                        if bin_iin and legal_name:
                            legal_record = db_fetch_val(conn, "GET_LEGAL_ENTITY_BY_TAX", (bin_iin,))
                            if legal_record:
                                legal_uuid = legal_record
                            else:
                                legal_uuid = str(uuid.uuid4())
                                db_execute(conn, "INSERT_LEGAL_ENTITY", 
                                           (legal_uuid, legal_name, bin_iin, 
                                            legal_data.get("legal_entity_address"), status_legal))
                        else:
                            logging.warning(f"Файл {file_uuid}: Юрлицо не определено (нет БИН или имени).")
                        
                        # Сохраняем чек
                        db_execute(conn, "INSERT_RECEIPT", (
                            str(uuid.uuid4()), file_uuid, doc.get("document_index", 1), status_receipt,
                            json.dumps(doc_payload, ensure_ascii=False), None, legal_uuid, None, None,
                            transaction.get("total_amount", 0.0), currency_uuid, 
                            transaction.get("operation_date"), transaction.get("operation_time"), 
                            legal_data.get("legal_entity_name")
                        ))
                    
                    db_execute(conn, "UPDATE_FILE_STATUS", ('FINISHED', file_uuid))
                    logging.info(f"Файл {file_uuid} успешно завершен.")

            except json.JSONDecodeError as jde:
                logging.error(f"Ошибка парсинга JSON для файла {file_uuid}: {jde}")
                with conn: 
                    db_execute(conn, "UPDATE_FILE_STATUS", ('NEEDS_REVIEW', file_uuid))
            except Exception as e:
                conn.rollback()
                decision = ExceptionHandler.handle(e, attempt=1)
                with conn: 
                    db_execute(conn, "UPDATE_FILE_STATUS", (decision.get("status_key", "API_ERROR"), file_uuid))
                logging.error(f"Файл {file_uuid} завершился с ошибкой: {e}")
                
    finally:
        conn.close()

if __name__ == "__main__":
    from google import genai
    import os
    from dotenv import load_dotenv

    # 1. Загружаем переменные окружения
    load_dotenv("/home/fujitsu-u745/Projects/secure_folder/api_manager/.env")
    
    # 2. Инициализируем клиент так же, как в api_test.py
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
    
    # 3. Настраиваем логирование и запускаем
    logging.basicConfig(level=logging.INFO)
    
    # Промпт уже определен выше в коде как PROMPT_CONTENT
    run_receipts_pipeline(client, PROMPT_CONTENT)