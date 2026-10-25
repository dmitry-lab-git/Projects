# aive_initial_audit.py
import json
import re
import logging
import argparse
import uuid
import sys
import api_manager.config as config
from psycopg2.extras import RealDictCursor
from api_manager.config import client, get_db_connection
from api_manager import secure_api_call
from decimal import Decimal, InvalidOperation
from prompt_manager import build_initial_audit_prompt, count_tokens
import time


# Интеграция обработчика ошибок Rich из config.py
if hasattr(config, 'setup_error_handling'):
    config.setup_error_handling()

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def restore_session_memory(conn, source_extraction_id):
    """Извлекает последние утвержденные правила AI_NOTES по заданному source_extraction_id."""
    query = """
        SELECT response_payload 
        FROM processing.aive_requests_log log
        JOIN dicts.dict_statuses dict ON log.status_id = dict.id
        WHERE dict.code = 'FINISHED' 
        AND log.response_payload IS NOT NULL 
        AND log.source_extraction_id = %s
        ORDER BY log.created_at DESC 
        LIMIT 1;
    """
    try:
        with conn.cursor() as cur:
            # Передаем параметр кортежем (source_extraction_id,)
            cur.execute(query, (source_extraction_id,))
            row = cur.fetchone()
            if not row or row[0] is None:
                return ""
            
            payload = row[0].strip()
            if payload.startswith("```"):
                payload = payload.split('\n', 1)[-1]
            if payload.endswith("```"):
                payload = payload.rsplit('\n', 1)[0]
                
            data = json.loads(payload.strip())
            if isinstance(data, dict) and "ai_notes" in data:
                return data["ai_notes"]
            return ""
    except Exception as e:
        logging.error(f"Ошибка при восстановлении памяти для ID {source_extraction_id}: {e}")
        return ""

def is_value_different(val_db, val_ai):
    try:
        d1 = Decimal(str(val_db)).normalize()
        d2 = Decimal(str(val_ai)).normalize()
        return d1 != d2
    except (InvalidOperation, ValueError, TypeError):
        return str(val_db) != str(val_ai)

def run_independent_audit_loop(batch_size, conn, ai_notes):
    # 1. Регистрация новой сессии
    # Задаем фиксированный ID сессии для всех записей этого запуска
    session_id = 'e1042b5c-e212-4ee2-9fac-6f2cbddcae87'
    logging.info(f"СИСТЕМА НЕЗАВИСИМОГО АУДИТА: Запуск. Session ID: {session_id}")

    manual_mode = True

    while True:
        processed_ids = []
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # 1. Захват очереди
                cur.execute("""
                    WITH locked_queue AS (
                        SELECT q.transaction_id
                        FROM audit.audit_process_queue q
                        JOIN audit.transactions_fullfields t ON q.transaction_id = t.transaction_id
                        WHERE q.audit_status = 'pending'
                        ORDER BY t.code ASC
                        LIMIT %s
                        FOR UPDATE OF q SKIP LOCKED
                    )
                    UPDATE audit.audit_process_queue q2
                    SET audit_status = 'processing'
                    FROM locked_queue
                    WHERE q2.transaction_id = locked_queue.transaction_id
                    RETURNING q2.transaction_id;
                """, (batch_size,))
                
                locked_rows = cur.fetchall()
                processed_ids = [r['transaction_id'] for r in locked_rows]
                
                # 2. ПРОВЕРКА: если очередь пуста, уходим в ожидание
                if not processed_ids:
                    logging.info("Очередь 'pending' пуста. Переход в режим ожидания (3 минуты).")
                    conn.commit() # Закрываем транзакцию перед сном
                    time.sleep(180) # Пауза 180 секунд
                    continue # Возвращаемся в начало цикла (повторная проверка)
                    
                # 3. Если данные есть, продолжаем работу
                cur.execute("""
                    SELECT * FROM audit.transactions_fullfields
                    WHERE transaction_id = ANY(%s::uuid[])
                    ORDER BY code ASC;
                """, (processed_ids,))
                rows = cur.fetchall()
                conn.commit()

            batch_request_id = str(uuid.uuid4())
            current_codes = [r['code'] for r in rows]
            logging.info(f"Обработка BATCH: code от {min(current_codes)} до {max(current_codes)} (Batch ID: {batch_request_id})")

            # Очистка служебных полей для передачи в API
            tx_data_list = []
            for row in rows:
                clean_row = {k: v for k, v in row.items() if k not in ['created_at', 'updated_at']}
                # Приведение дат и decimal к строкам для JSON сериализации
                for k, v in clean_row.items():
                    if v is not None and not isinstance(v, (int, float, str, bool)):
                        clean_row[k] = str(v)
                tx_data_list.append(clean_row)

            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Извлекаем статистику: 
                # 1. Считаем processed (всего в очереди)
                # 2. Считаем средний trust_score из таблицы результатов
                current_session_audit_id = 'e1042b5c-e212-4ee2-9fac-6f2cbddcae87'
                cur.execute("""
                    SELECT 
                        (SELECT COUNT(*) FROM audit.audit_process_queue WHERE audit_status = 'processed') as processed_count,
                        (SELECT COUNT(*) FROM audit.audit_process_queue) as total_count,
                        (SELECT AVG((raw_response->>'trust_score')::numeric) 
                        FROM audit.staging_audit_results 
                        WHERE raw_response ? 'trust_score'
                        AND audit_id = %s) as avg_trust;
                """, (current_session_audit_id,))
                stats = cur.fetchone()
                
                processed = stats['processed_count']
                total = stats['total_count']
                left = total - processed
                avg_trust = float(stats['avg_trust'] or 0)

            session_stats = (
                f"СТАТИСТИКА: Обработано {processed}/{total} транзакций. "
                f"Осталось: {left}. Средний Trust Score: {avg_trust:.2f}."
            )

            # БЕЗОПАСНЫЙ ЛОГ: проверяем, что ai_notes существует, прежде чем брать срез
            ai_notes_preview = f"{ai_notes[:20]}..." if ai_notes else "Пусто (первый запуск)"

            # ВАЖНО: Передаем ai_notes в промпт (убедитесь, что функция это поддерживает)
            prompt = build_initial_audit_prompt(tx_data_list, ai_notes=ai_notes,session_stats=session_stats) if ai_notes else build_initial_audit_prompt(tx_data_list)
            
            token_count = count_tokens(prompt)

            # Вывод в терминал для верификации
            if manual_mode:
                print("\n" + "="*80)
                print(f"ТЕСТИРОВАНИЕ ПРОМПТА | Пачка из {len(rows)} транзакций")
                print(f"Расчетное количество токенов: {token_count}")
                print("-" * 80)
                print("СОДЕРЖИМОЕ ПРОМПТА (первые 2000 символов):")
                print(prompt[:30000] + "\n...[скрыто для краткости]...")
                print("="*80 + "\n")

                user_choice = input("Нажмите Enter для подтверждения (a - АВТО, q - выход): ").strip().lower()
                if user_choice == 'a':
                    manual_mode = False
                    print("[АВТО] Режим подтверждения промптов ОТКЛЮЧЕН.")
                elif user_choice == 'q':
                    logging.info("Остановка процесса по запросу пользователя.")
                    break

            # Вызов API
            response = secure_api_call(client, prompt, conn, batch_request_id, target_name="technical")

            time.sleep(10)

            if response is None:
                logging.error("Критический сбой запроса: secure_api_call вернул None. Пауза 10 секунд для стабилизации.")
                time.sleep(10)
                continue

            # Очистка и парсинг
            start_idx = response.find('{')
            end_idx = response.rfind('}')

            if start_idx != -1 and end_idx != -1 and start_idx < end_idx:
                # Вырезаем только JSON, отсекая любой мусор до и после
                raw_data = response[start_idx:end_idx + 1]
                
                try:
                    data = json.loads(raw_data)
                    
                    # 2. Строгая проверка по Контракту
                    if isinstance(data, dict):
                        # Извлекаем audit_results, если ключа нет — вернется пустой список
                        results = data.get("audit_results", [])
                        
                        if not results:
                            logging.warning("Внимание: ИИ вернул JSON, но ключ 'audit_results' пуст или отсутствует.")
                            
                        # Обновляем ai_notes только если они есть в ответе
                        ai_notes = data.get("ai_notes", ai_notes)
                        
                    else:
                        logging.error("Нарушение контракта: корневой элемент не является объектом (dict).")
                        results = []
                        
                except json.JSONDecodeError as e:
                    logging.error(f"Критическая ошибка парсинга JSON: {e.msg} на позиции {e.pos}")
                    # Выводим края обрезанной строки для дебага скрытых символов
                    logging.debug(f"Текст, вызвавший ошибку: {repr(raw_data[:100])} ... {repr(raw_data[-100:])}")
                    results = []
            else:
                logging.error("JSON (фигурные скобки) не найден в ответе модели.")
                results = []

            row_map = {r['transaction_id']: r for r in rows if 'transaction_id' in r}

            # --- ФИКСАЦИЯ РЕЗУЛЬТАТОВ И ОБНОВЛЕНИЕ ОЧЕРЕДИ ---
            if not results:
                logging.warning("Пропуск записи БД: нет валидных результатов для сохранения.")
                conn.rollback()
                # return или continue — в зависимости от того, как устроен ваш внешний цикл
                return 

            with conn.cursor() as cur:
                for entry in results:
                    # Дополнительная защита на случай галлюцинаций внутри списка
                    if not isinstance(entry, dict):
                        continue
                        
                    t_id = entry.get('transaction_id')
                    row = row_map.get(t_id)
                    
                    if not row:
                        continue

                    clean_changes = {}
                    if 'changes' in entry and isinstance(entry['changes'], dict):
                        for key, ai_val in entry['changes'].items():
                            db_val = row.get(key)
                            if is_value_different(db_val, ai_val):
                                clean_changes[key] = ai_val

                    # Вставка записи с привязкой к сессии
                    cur.execute("""
                        INSERT INTO audit.staging_audit_results 
                        (transaction_id, audit_id, code, audit_type, status, diff_json, reasoning, raw_response, is_applied)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, false)
                    """, (
                        t_id, 
                        session_id,
                        entry.get('code', row.get('code')), 
                        'independent',
                        'pending', 
                        json.dumps(clean_changes, ensure_ascii=False), 
                        entry.get('reasoning'), 
                        json.dumps(entry, ensure_ascii=False)
                    ))
                
                # Перевод очереди в processed выполняется ТОЛЬКО если были валидные results
                if processed_ids:
                    cur.execute("""
                        UPDATE audit.audit_process_queue 
                        SET audit_status = 'processed', 
                            api_attempt_count = COALESCE(api_attempt_count, 0) + 1,
                            last_processed_at = CURRENT_TIMESTAMP 
                        WHERE transaction_id = ANY(%s::uuid[])
                    """, (processed_ids,))
                    
                    conn.commit()
                    logging.info(f"УСПЕХ: BATCH обработан. Записано {len(results)} результатов.")
                else:
                    conn.rollback()
                    logging.warning("Не найдено ID для обновления очереди.")

            if manual_mode:
                print("\n" + "="*50)
                user_choice = input("Пачка завершена. Продолжить? (y - след., a - АВТО, q - выход): ").strip().lower()
                if user_choice == 'a':
                    manual_mode = False
                    print("[ИНФО] Переключено в АВТОМАТИЧЕСКИЙ режим. Подача непрерывна.")
                elif user_choice == 'q':
                    logging.info("Остановка процесса по запросу пользователя.")
                    break
                elif user_choice != 'y':
                    logging.info("Некорректный ввод. Остановка процесса.")
                    break

        # 1. Ловим системные ошибки программирования и сразу роняем скрипт с трассировкой
        except (NameError, ImportError, SyntaxError, TypeError):
            # exc_info=True гарантирует, что стек вызовов попадет в систему логирования
            logging.critical("🚨 КРИТИЧЕСКАЯ ОШИБКА В КОДЕ (Необходимо исправить!)", exc_info=True)
            # Идиоматичный вызов без параметров, как и заявлено в вашем комментарии
            raise 

        # 2. Ловим ошибки бизнес-логики (наше скользящее окно, лимиты, тяжелые промпты)
        except RuntimeError as runtime_err:
            logging.warning(f"⚠️ Запрос отклонен оркестратором: {runtime_err}")
            
            # Делаем безопасный откат для бизнес-ошибок
            if processed_ids and conn and not conn.closed:
                try:
                    # ВАЖНО: Сначала откатываем всё, что успело накопиться в текущей транзакции до ошибки
                    conn.rollback() 
                    
                    with conn.cursor() as cur:
                        cur.execute("""
                            UPDATE audit.audit_process_queue 
                            SET audit_status = 'pending' 
                            WHERE transaction_id = ANY(%s::uuid[])
                        """, (processed_ids,))
                    # Теперь безопасно коммитим только обновление статусов
                    conn.commit()
                    logging.info("Статус транзакций возвращен в 'pending' для повторной попытки.")
                except Exception as rb_e:
                    logging.error(f"Не удалось откатить статус очереди: {rb_e}", exc_info=True)
                    # Откат на случай, если сам UPDATE вызвал ошибку
                    conn.rollback()

        # 3. Ловим только непредвиденные системные сбои (сеть, БД)
        except Exception:
            logging.error("💥 Непредвиденная системная ошибка (БД или Сеть):", exc_info=True)
            raise

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch_size", type=int, default=3, help="Количество транзакций в пачке")
    args = parser.parse_args()
    
    conn = get_db_connection()

    if conn is None:
        print("\n[КРИТИЧЕСКАЯ ОШИБКА] Не удалось установить подключение к PostgreSQL!")
        raise SystemExit(1)
    
    # ==================== ИНИЦИАЛИЗАЦИЯ ПАМЯТИ ====================
    print("\n=================== ПРОВЕРКА ПАМЯТИ ИИ ПЕРЕД ЗАПУСКОМ ===================")
    print("\n[ИНИЦИАЛИЗАЦИЯ] Режим загрузки динамической памяти:")
    print("1. Запустить с чистого листа (ai_notes пустой)")
    print("2. Загрузить последнюю сессию (ai_notes из БД)")
    
    choice = input("\nВыберите вариант (1 или 2): ").strip()

    # Флаг для управления состоянием памяти
    is_first_batch = True
    current_ai_notes = ""
    
    if choice == '1':
        print("\n[РЕЖИМ] Запуск с ЧИСТЫМ ФАЙЛОМ.")
    elif choice == '2':
        target_id = input("Введите source_extraction_id: ").strip()
        print(f"\n[РЕЖИМ] Подгрузка правил для ID: {target_id}...")
        
        # Передаем полученный ID в функцию
        ai_notes = restore_session_memory(conn, target_id)
        
        if ai_notes:
            print(f"[ИНФО] Память успешно загружена ({len(ai_notes)} символов).")
        else:
            print("[ПРЕДУПРЕЖДЕНИЕ] История для указанного ID не найдена, загружена пустая память.")
    else:
        print("\n[ОШИБКА] Неверный выбор. Запуск с чистого листа.")
    # =============================================================
    
    user_input = input("\nВы утверждаете эти параметры для запуска INDEPENDENT AUDIT? (y/n): ").strip().lower()
    
    if user_input == 'y':
        print(f"\n[УСПЕХ] Заметки утверждены. Запуск аудита (Batch: {args.batch_size})...\n")
        try:
            run_independent_audit_loop(args.batch_size, conn, ai_notes)
        finally:
            if conn:
                conn.close()
                print("[ИНФО] Соединение с PostgreSQL успешно закрыто.")
    else:
        print("\n[ОТМЕНА] Запуск заблокирован пользователем.")
        if conn: conn.close()
        sys.exit(0)