import json
import logging
import argparse
import uuid
import tiktoken
import config
from psycopg2.extras import RealDictCursor
from config import client, get_db_connection
from api_utils import secure_api_call, countdown_timer
from decimal import Decimal, InvalidOperation
from prompt_manager import build_re_audit_prompt, count_tokens

is_first_init = False

# Интеграция обработчика ошибок Rich из config.py
if hasattr(config, 'setup_error_handling'):
    config.setup_error_handling()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')



def restore_session_memory(conn):
    query = """
        SELECT response_payload 
        FROM processing.aive_requests_log WHERE status = 'FINISHED' AND response_payload IS NOT NULL ORDER BY created_at DESC LIMIT 1;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query)
            row = cur.fetchone()
            if not row or row[0] is None:
                return ""
            payload = row[0].strip()
            if payload.startswith("```"):
                payload = payload.split('\n', 1)[-1]
            if payload.endswith("```"):
                payload = payload.rsplit('\n', 1)[0]
            payload = payload.strip()
            data = json.loads(payload)
            if isinstance(data, dict) and "ai_notes" in data:
                return data["ai_notes"]
            return ""
    except Exception as e:
        logging.error(f"Ошибка при восстановлении памяти: {e}")
        return ""

def is_value_different(val_db, val_ai):
    try:
        d1 = Decimal(str(val_db)).normalize()
        d2 = Decimal(str(val_ai)).normalize()
        return d1 != d2
    except (InvalidOperation, ValueError, TypeError):
        return str(val_db) != str(val_ai)

def run_re_audit_loop(conn, ai_notes):
    logging.info("СИСТЕМА РЕ-АУДИТА: Запуск. Обработка по 1 транзакции.")

    while True:
        try:
            # Защита автореконнекта
            if conn is None or conn.closed != 0:
                logging.warning("[БАЗА ДАННЫХ] Соединение потеряно. Попытка восстановления...")
                try:
                    if conn: conn.close()
                except: pass
                conn = get_db_connection()
                logging.info("[БАЗА ДАННЫХ] Успешно восстановлено!")

            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Извлекаем ровно 1 транзакцию, требующую повторного аудита.
                # Выбираем последнюю итерацию 'initial_audit' для привязки parent_staging_id
                cur.execute("""
                    SELECT 
                        t.*,
                        sar.staging_id AS parent_staging_id,
                        sar.raw_response AS prev_raw_response
                    FROM audit.transactions_fullfields t
                    JOIN audit.audit_process_queue q ON t.transaction_id = q.transaction_id
                    JOIN audit.staging_audit_results sar ON t.transaction_id = sar.transaction_id
                    WHERE (sar.raw_response->>'trust_score')::int < 8
                    AND sar.audit_type = 'initial_audit'
                    -- Берем только последнюю итерацию для каждой транзакции
                    AND sar.staging_id = (
                        SELECT staging_id 
                        FROM audit.staging_audit_results 
                        WHERE transaction_id = t.transaction_id 
                            AND audit_type = 'initial_audit' 
                        ORDER BY created_at DESC LIMIT 1
                    )
                    -- Исключаем уже обработанные в re_audit
                    AND NOT EXISTS (
                        SELECT 1 FROM audit.staging_audit_results sar2 
                        WHERE sar2.transaction_id = t.transaction_id 
                            AND sar2.audit_type = 're_audit'
                    )
                    ORDER BY sar.created_at ASC -- Самая старая транзакция первой
                    LIMIT 1
                    FOR UPDATE OF q SKIP LOCKED;
                """)
                
                row = cur.fetchone()
                if not row:
                    logging.info("Очередь ре-аудита пуста. Все 247 транзакций обработаны.")
                    countdown_timer(60, message="Проверка появления новых транзакций через")
                    continue

                t_id = row.get("transaction_id")
                parent_staging_id = row.get("parent_staging_id")
                prev_raw_response = row.get("prev_raw_response")
                batch_request_id = str(uuid.uuid4())
                
                logging.info(f"Обработка RE-AUDIT для транзакции ID: {t_id}")

                # Устанавливаем статус pending_re_audit перед отправкой в API
                cur.execute("""
                    UPDATE audit.audit_process_queue 
                    SET audit_status = 'pending_re_audit' 
                    WHERE transaction_id = %s
                """, (t_id,))
                conn.commit()

                # Отделяем чистые данные транзакции от служебных полей запроса
                tx_data = {k: v for k, v in row.items() if k not in ['parent_staging_id', 'prev_raw_response']}
                
                # Обращение к prompt_manager
                prompt = build_re_audit_prompt(tx_data, prev_raw_response, ai_notes)

                # 2. Подсчитываем токены
                token_count = count_tokens(prompt)

                # 3. Вывод в терминал для верификации
                print("\n" + "="*80)
                print(f"ТЕСТИРОВАНИЕ ПРОМПТА | Транзакция ID: {t_id}")
                print(f"Расчетное количество токенов: {token_count}")
                print("-" * 80)
                print("СОДЕРЖИМОЕ ПРОМПТА:")
                print(prompt[:100000] + "\n...[остальная часть промпта скрыта для краткости]...")
                print("="*80 + "\n")

                # --- КОНТРОЛЬ ПОДАЧИ (ПРОМПТ) ---
                if 'manual_mode' not in locals():
                    manual_mode = True

                if manual_mode:
                    user_choice = input("Нажмите Enter для подтверждения (a - АВТО, q - выход): ").strip().lower()
                    if user_choice == 'a':
                        manual_mode = False
                        print("[АВТО] Режим подтверждения промптов ОТКЛЮЧЕН.")
                    elif user_choice == 'q':
                        logging.info("Остановка процесса по запросу пользователя.")
                        break
                else:
                    print("[АВТО] Автоматическая отправка промпта...")
                #------------------------------------------------------------

                # Вызов API
                response = secure_api_call(
                    client,               # 1. client
                    prompt,               # 2. prompt_text
                    conn,                 # 3. conn
                    batch_request_id,     # 4. source_uuid
                    "gemini-3.1-flash-lite", # 5. model_name (теперь передаем явно!)
                    12000,                # 6. max_prompt_weight
                    3                     # 7. max_retries
                )

                if response is None:
                    logging.error("Критическая ошибка API. Завершение работы программы.")
                    return

                try:
                    # Очистка и парсинг
                    raw_data = response.replace("```json", "").replace("```", "").strip()
                    data = json.loads(raw_data)
                    
                    if isinstance(data, dict) and "audit_results" in data:
                        results = data["audit_results"]
                        ai_notes = data.get("ai_notes", ai_notes)
                    else:
                        results = data if isinstance(data, list) else [data]
                    
                    entry = results[0] if results else None
                    
                    if entry:
                        clean_changes = {}
                        if 'changes' in entry:
                            for key, ai_val in entry['changes'].items():
                                db_val = row.get(key)
                                if is_value_different(db_val, ai_val):
                                    clean_changes[key] = ai_val
                        
                        # Вставка записи с указанием audit_type и parent_staging_id, is_applied всегда false
                        cur.execute("""
                            INSERT INTO audit.staging_audit_results 
                            (transaction_id, code, audit_type, parent_staging_id, status, diff_json, reasoning, raw_response, is_applied)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, false)
                        """, (
                            t_id, 
                            entry.get('code', tx_data.get('code')), 
                            're_audit',
                            parent_staging_id,
                            'manual_review', 
                            json.dumps(clean_changes, ensure_ascii=False), 
                            entry.get('reasoning'), 
                            json.dumps(entry, ensure_ascii=False)
                        ))
                        
                        # Обновление очереди до manual_review
                        cur.execute("""
                            UPDATE audit.audit_process_queue 
                            SET audit_status = 'manual_review', 
                                api_attempt_count = api_attempt_count + 1,
                                last_processed_at = CURRENT_TIMESTAMP 
                            WHERE transaction_id = %s::uuid
                        """, (t_id,))
                        
                        conn.commit()
                        logging.info(f"УСПЕХ: RE-AUDIT транзакции {t_id} завершен и ожидает manual_review.")

                        # --- Инициализация режима перед началом цикла while True ---
                        if 'manual_mode' not in locals():
                            manual_mode = True

                        # --- ДОБАВЛЯЕМ КОНТРОЛЬ ПОДАЧИ ---
                        if manual_mode:
                            print("\n" + "="*50)
                            user_choice = input("Транзакция завершена. Продолжить? (y - след., a - АВТО, q - выход): ").strip().lower()
                            
                            if user_choice == 'a':
                                manual_mode = False
                                print("[ИНФО] Переключено в АВТОМАТИЧЕСКИЙ режим. Подача непрерывна.")
                            elif user_choice == 'q':
                                logging.info("Остановка процесса по запросу пользователя.")
                                break
                            elif user_choice != 'y':
                                logging.info("Некорректный ввод. Остановка процесса.")
                                break
                        else:
                            print("Подготовка следующей транзакции...\n")
                        # --- ДОБАВЛЯЕМ КОНТРОЛЬ ПОДАЧИ ---
                    else:
                        logging.warning(f"ИИ вернул пустой результат для транзакции {t_id}")

                except Exception as e:
                    logging.error(f"Ошибка парсинга/сохранения транзакции {t_id}: {e}")
                    conn.rollback()

        except NameError as e:
            logging.critical(f"ФАТАЛЬНАЯ ОШИБКА КОДА: {e}. Завершение работы.")
            import sys
            sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    # Batch size убран из аргументов, так как работаем строго по 1 транзакции
    args = parser.parse_args()
    
    conn = get_db_connection()

    if conn is None:
        print("\n[КРИТИЧЕСКАЯ ОШИБКА] Не удалось установить подключение к PostgreSQL!")
        raise SystemExit(1)
    
    print("\n[СТАРТ СЕССИИ] Восстановление динамической памяти ИИ (ai_notes)...")
    ai_notes = restore_session_memory(conn)
    # === ВРЕМЕННАЯ МЕРА: ПРИНУДИТЕЛЬНОЕ ПЕРЕПРИСВОЕНИЕ ИЗ ФАЙЛА ===
    if is_first_init:
        import os
        file_path = r"C:\Users\admin\Desktop\Ledger\aive\prompts\ai_notes_1858.txt"

        if os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8") as f:
                ai_notes = f.read()
            print("[ВРЕМЕННЫЙ ХАК] Данные из файла успешно подгружены при первой инициализации.")
            is_first_init = False  # Выключаем флаг для следующих проходов
        else:
            print(f"Ошибка: Временный файл не найден по пути {file_path}")
    # ============================================================
    
    print("\n=================== ПРОВЕРКА ПАМЯТИ ИИ ПЕРЕД ЗАПУСКОМ ===================")
    if ai_notes.strip():
        print(ai_notes)
    else:
        print("[ПРЕДУПРЕЖДЕНИЕ] Актуальные заметки не найдены в БД.")
    print("=========================================================================")
    
    user_input = input("\nВы утверждаете эти заметки для запуска RE-AUDIT? (y/n): ").strip().lower()
    
    #if user_input != 'y':
    #    print("\n[ОТМЕНА] Запуск заблокирован пользователем.")
    #    conn.close() 
    #    raise SystemExit(0)
        
    print("\n[УСПЕХ] Заметки утверждены. Запуск цикла RE-AUDIT...\n")

    print(f"DEBUG: Статус соединения перед запуском: {'ЗАКРЫТО' if conn.closed else 'ОТКРЫТО'}")
    
    try:
        run_re_audit_loop(conn, ai_notes)
    finally:
        if conn:
            conn.close()
            print("[ИНФО] Соединение с PostgreSQL успешно закрыто.")