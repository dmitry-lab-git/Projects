import json
import logging
import argparse
from tqdm import tqdm
import uuid
import config
from psycopg2.extras import RealDictCursor
from config import client, get_db_connection
from api_utils import secure_api_call, countdown_timer
from decimal import Decimal, InvalidOperation

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def restore_session_memory(conn):
    query = """
        SELECT response_payload 
        FROM processing.aive_requests_log
        WHERE status = 'FINISHED' AND response_payload IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 1;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query)
            row = cur.fetchone()
            
            # ДИАГНОСТИКА: выведет в консоль, что на самом деле пришло из БД
            logging.info(f"Результат запроса к БД: {row}")
            
            if not row or row[0] is None:
                logging.info("База данных вернула пустое значение (NULL) для payload.")
                return ""
            
            payload = row[0].strip()
            
            # Очистка от Markdown-обертки (```json ... ```)
            # Убираем первую строку, если она содержит тег кода
            if payload.startswith("```"):
                payload = payload.split('\n', 1)[-1]
            # Убираем последние ```, если они есть
            if payload.endswith("```"):
                payload = payload.rsplit('\n', 1)[0]
            
            payload = payload.strip()
            
            # Теперь парсим чистый JSON
            data = json.loads(payload)
            
            if isinstance(data, dict) and "ai_notes" in data:
                return data["ai_notes"]
            
            return ""

    except json.JSONDecodeError as e:
        logging.error(f"Ошибка парсинга JSON: {e}")
    except Exception as e:
        logging.error(f"Ошибка при восстановлении памяти: {e}")
    
    return ""

def is_value_different(val_db, val_ai):
    """Возвращает True, если значения реально отличаются, игнорируя форматирование."""
    try:
        # Приводим к Decimal, чтобы убрать лишние нули и разницу строк/чисел
        d1 = Decimal(str(val_db)).normalize()
        d2 = Decimal(str(val_ai)).normalize()
        return d1 != d2
    except (InvalidOperation, ValueError):
        # Если это не числа (например, имя транзакции), сравниваем как строки
        return str(val_db) != str(val_ai)

def run_audit_loop(batch_size, conn, ai_notes):
    logging.info(f"СИСТЕМА АУДИТА: Запуск. Размер пачки: {batch_size}")

    memory_instruction = ""
    if ai_notes: # Проверяет локальную переменную, которая придет со второй итерации
        memory_instruction = f"""
        === ВАШИ ЗАМЕТКИ ИЗ ПРЕДЫДУЩИХ ИТЕРАЦИЙ (AI-NOTES) ===
        {ai_notes}
        ======================================================
        Используйте эти заметки как контекст и кэш бизнес-логики, чтобы не дублировать одинаковые семантические замечания.
        """
    
    while True:
        try:
            # === ЗАЩИТА АВТОРЕКОННЕКТА ===
            # Проверяем, живой ли коннект. Если он закрыт или поврежден (status != 0)
            if conn is None or conn.closed != 0:
                logging.warning("[БАЗА ДАННЫХ] Соединение потеряно или закрыто. Попытка восстановления...")
                try:
                    if conn: 
                        conn.close() # на всякий случай закрываем старый
                except: 
                    pass
                
                # Пересоздаем соединение заново прямо внутри цикла
                conn = get_db_connection()
                logging.info("[БАЗА ДАННЫХ] Соединение успешно восстановлено!")
            # =============================

            # Теперь открытие курсора полностью защищено от любых сетевых сбоев
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Берем всё из таблицы, добавляя строгое упорядочивание
                cur.execute("""
                    SELECT t.* FROM audit.transactions_fullfields t
                    JOIN audit.audit_process_queue q ON t.transaction_id = q.transaction_id
                    WHERE q.audit_status = 'pending'
                    ORDER BY t.code ASC
                    LIMIT %s
                    FOR UPDATE OF q SKIP LOCKED;
                """, (batch_size,))
                
                rows = cur.fetchall()
                if not rows:
                    countdown_timer(60, message="Очередь пуста. Проверка через")
                    continue

                batch_request_id = str(uuid.uuid4())
                logging.info(f"Аудит потока транзакций. Начало обработки. Batch ID: {batch_request_id}")

                # Формируем payload для всей пачки
                payload = []
                for row in rows:
                    current_tx_id = row.get("transaction_id")
                    logging.info(f"Обработка транзакции ID: {current_tx_id}")
                    payload.append({
                        "transaction_id": row.get("transaction_id"),
                        "code": row.get("code"),  # Добавляем поле code
                        "transaction_name": row.get("transaction_name"),
                        "type_id": row.get("type_id"),
                        "type_name": row.get("type_name"),
                        "entity_id": row.get("entity_id"),
                        "entity_name": row.get("entity_name"),
                        "account_id": row.get("account_id"),
                        "account_name": row.get("account_name"),
                        "amount": str(row.get("amount")),
                        "category_name": row.get("category_name"),
                        "acc_balance": str(row.get("acc_balance")),
                        "prev_acc_tr_balance": str(row.get("prev_acc_tr_balance")),
                        "prev_acc_tr_id": row.get("prev_acc_tr_id"),
                        "contragent_from_name": row.get("contragent_from_name"),
                        "contragent_to_name": row.get("contragent_to_name"),
                        "operation_date": str(row.get("operation_date"))
                    })
                    batch_request_id = str(uuid.uuid4())
                    # logging.info(f"batch id UUID транзакции: {batch_request_id}")

                # === 1. Выделяем требования к формату и ограничения по токенам в переменную ===
                prompt_requirement = f"""
                ================================================================================
                КРИТИЧЕСКИ ВАЖНОЕ ТРЕБОВАНИЕ К ФОРМАТУ ОТВЕТА (СТРОГИЙ JSON):
                Верните ответ строго в виде массива JSON-объектов. Каждый объект долже соответствовать нижепредставленному контракту.
                Структура ответа:
                {{
                "audit_results": [
                    {{
                        "transaction_id": "UUID (из входящих данных)",
                        "code": "code (из входящих данных)",
                        "trust_score": "число от 1 до 10",
                        "status": "processed",
                        "changes": {{ 
                            "acc_balance": "String (новое значение баланса)",
                            "suggested_correction": "string" 
                        }},
                        "reasoning": "Строка с обоснованием, обязательно ссылайтесь на транзакции по их коду (code)."
                    }}
                ],
                "ai_notes": "Сюда запишите свою актуализированную, дополненную базу знаний по итогам этого батча."
                }}
                                Не добавляйте никаких вступлений, комментариев или markdown-оберток, кроме самого JSON-массива.

                ИНСТРУКЦИЯ ПО РАБОТЕ С ДИНАМИЧЕСКОЙ ПАМЯТЬЮ "ai_notes":
                1. Проанализируйте переданный блок 'AI-NOTES' (если он есть). Используйте его как кэш бизнес-логики, чтобы не повторять одни и те же семантические выводы для похожих ошибок.
                2. В поле "ai_notes" сформируйте обновленную, что важно, версию базы знаний. Перенесите туда важные правила из прошлых шагов, дополните их новыми наблюдениями, типизируйте новые ошибки, зафиксируйте правила для дальнейшей нормализации.
                3. Важно. Ограничение объема: Размер поля "ai_notes" строго ограничен — не более 1500 токенов (token_limit). Пишите емко, структурировано, удаляйте устаревшую или дублирующую информацию, удерживая только самую важную суть.
                4. Всегда ведите блок [SESSION STATISTICS].
                    Указывайте: 
                        - Общее кол-во обработанных транзакций в этой сессии.
                        - Кол-во выявленных ошибок (trust_score < 8).
                        - Текущее кол-во правил в базе знаний.
                    Можете расширять эту часть для дальнейшего анализа, вводя новые поля, метрики.
                    Возможно будет удобно типизировать ошибки и ставить счетчик на их количество.
                Записей в таблице транзакций: 1858. Учтите это при планировании выделенного объема (1500 токенов) на "ai_notes".
                ---Внимание: с 560 (по полю "code") записи есть обновления в промпте.---
                5. Испрользуйте весь объем: Не экономьте место. Ваша задача — максимально подробно документировать логику. Если блок пуст или мал (менее 2000 токенов), расширяйте его деталями, примерами и классификациями.
                6. Глубокая семантика: вместо кратких выводов пишите развернутые пояснения по каждому пункту базы знаний. Добавляйте секцию [EDGE CASES] для описания редких, но важных исключений.
                7. Статистическая эволюция: В блоке [SESSION STATISTICS] начните вести накопительные итоги в динамике (например, сравнение темпа ошибок текущего батча со средним по сессии).
                8. Предел сжатия: только когда объем заметок реально приблизится к 1300 токенам (token_limit), начинайте семантическую компрессию. До этого момента — пишите максимально подробно.
                
                Справочник терминов:
                1. Сессия - открытый канал взаимодействия с ИИ. Транзакции отправляются пачками. Вы получаете пачку из n транзакций. Всего в таблице 1858 записей.
                2. Текущий батч - текущая выборка транзакций, которая указана в промпте.
                ================================================================================
                """

                formatted_transactions = ",\n".join([json.dumps(tx, ensure_ascii=False) for tx in payload])

                # === 2. Выделяем переданный кэш памяти в переменную ===
                memory_instruction = ""
                if ai_notes:
                    memory_instruction = f"""
                    === ВАШИ ЗАМЕТКИ ИЗ ПРЕДЫДУЩИХ ИТЕРАЦИЙ (AI-NOTES) ===
                    {ai_notes}
                    ======================================================
                    Используйте эти заметки как контекст и кэш бизнес-логики в соответствии с перечисленными требованиями выше.
                    """

                # Промпт для анализа пачки
                prompt = f"""
                ---Внимание: с 560 (по полю "code") записи есть обновления в промпте.---
                ---Внимание: с 1677 (по полю "code") записи есть обновления в промпте. Обновлены лимиты по токена на заметки - 1500 токенов.---
                
                Таблица с реестром транзакции имеет 1858 записей. Для ориентира "code" указывает, над какой частью реестра производится анализ.
                Проанализируйте цепочку из {len(payload)} транзакций:
                [
                {formatted_transactions}
                ]
                {prompt_requirement}
                {memory_instruction}
                    Описание полей транзакции:
                "transaction_id": row.get("transaction_id"),
                "code": - порядковый код транзакции;
                "transaction_name": название транзакции;
                "type_id": ID типа транзакции: доход, расход, ревизия, перенос, корректировка.
                "type_name": название типа операции;
                "entity_id": идентификатор сущности (проект, задача, общая категория или направленность дохода или расхода);
                "entity_name": название сущности;
                "account_id": ID счета транзакции;
                "account_name": название счета транзакции;
                "amount": сумма транзакции (важно, что сумма может быть отрицательной);
                "category_name": - название категории транзакции;
                "acc_balance": баланс счета транзакции;
                "prev_acc_tr_balance": баланс счета на момент предыдущей транзакции;
                "prev_acc_tr_id": ID транзакции на момент предыдущей операции по счету;
                "contragent_from_name": название контрагента донора;
                "contragent_to_name": название контрагента акцептора;
                "operation_date": дата транзакции.
                    Для каждой транзакции верните JSON-массив. В транзакциях могут быть указаны
                неверные категории, контрагенты, сущности. Задача выявить противоречия. В случае обнаружнения
                существенной и серьезной ошибки пометить: "Критическое несоответствие". Также предложите нормализованное название транзакции.
                ВАЖНО: В поле "reasoning" обязательно ссылайся на транзакции по их полю "code", они в хронологическом порядке событий. 
                
                Не нумеруйте транзакции от себя, используйте предоставленные коды.

                Математическое выражение для расчета баланса счета следующей транзакции относительно предыдущей:
                acc.balance(i+1) = acc.balance(i)+amount(i)*AccountEffect(TypeID).
                AccountEffect("type_id") - коэффициент для расчета баланса в зависимости от "type_id".
                
                Изменение баланса счета транзакции в зависимости от типа и знака суммы транзакции:
                Транзакция дохода может уменьшать баланс, если сумма операции отрицательная.
                Транзакция расхода может увеличивать баланс, если сумма операции отрицательная.
                Транзакция корректировки может увеличивать или уменьшать баланс в зависимости от знака суммы операции.

                Таблица AccountEffect(TypeID):
                TPE-001 - "Доход" - ("1")
                TPE-002 - "Расход" - ("-1")
                TPE-003 - "Ревизия" - ("0")
                TPE-004 - "Перенос" - ("1")
                TPE-005 - "Корректировка" - ("-1")
                При расчете баланса используйте строгий алгоритм для каждой транзакции.
                Порядок расчета acc.balance(i+1):
                    1. Возьмите входящий acc_balance от предыдущей транзакции (для первой — используйте её собственный prev_acc_tr_balance(i+1)).
                    2. Определите множитель из таблицы AccountEffect для текущего TypeID.
                    3. Вычислите изменение: delta = amount * AccountEffect(TypeID).
                    4. Рассчитайте новый баланс: calculated_balance(i+1) = acc.balance(i+1) = acc.balance(i) + delta.
                    5. Сравните calculated_balance(i+1) и acc_balance. Если есть разница — статус "error (if calculated_balance(i+1) - acc_balance(i+1) > 0.01)
                При расчетах используйте точность до 2 знаков после запятой, сравнивайте значения с учетом погрешности 0.01

                Семантический анализ
                Обратите внимание на поля "entity_name", "category_name". Сравните с названием транзакции и проверьте есть ли семантическая неточность.
                Обратите внимание на поля "contragent_from_name" и "contragent_to_name". Обратите внимание на семантический смысл операции. Правильно ли указан контрагент?
                
                Если данные верны и соответствуют алгоритму, в поле reasoning укажите 'Данные корректны, расчет подтвержден'.
                
                Для каждой операции на свое усмотрение определите уровень доверия к качеству заполнения данных от 1 до 10. Пометьте параметром trust_score.
                """
                response = None

                response = secure_api_call(client, prompt, conn=conn, source_uuid=batch_request_id, max_retries=3)

                if response is None:
                    logging.error("Критическая ошибка API после всех попыток. Завершение работы программы.")
                    # Используем return для выхода из функции, где идет цикл (например, run_audit_loop)
                    return

                if response:
                    try:
                        raw_data = response.replace("```json", "").replace("```", "").strip()
                        data = json.loads(raw_data)
                         # === НАЧАЛО ИСПРАВЛЕНИЯ ДЛЯ ПОДДЕРЖКИ AI-NOTES ===
                        # Проверяем, вернул ли ИИ новую структуру (объект с ключами)
                        if isinstance(data, dict) and "audit_results" in data:
                            # Извлекаем чистый массив транзакций для вашего бэкэнда
                            results = data["audit_results"]
                            # Извлекаем заметки. Если их нет — берем старые
                            ai_notes = data.get("ai_notes", ai_notes)
                            logging.info(f"Успешно извлечены ai_notes (размер: {len(ai_notes)} симв.)")
                        else:
                            # Фолбэк: если ИИ по старой памяти вернул обычный массив
                            results = data if isinstance(data, list) else [data]
                        # === КОНЕЦ ИСПРАВЛЕНИЯ ===
                        
                        entry = None # Инициализация для безопасности
                        row_map = {r['transaction_id']: r for r in rows}

                        for entry in results:
                            try:
                                t_id = entry.get('transaction_id')
                                row = row_map.get(t_id)
                                
                                # Логика нормализации
                                clean_changes = {}
                                if row and 'changes' in entry:
                                    for key, ai_val in entry['changes'].items():
                                        db_val = row.get(key)
                                        if is_value_different(db_val, ai_val):
                                            clean_changes[key] = ai_val
                                
                                # Вставка данных в staging
                                cur.execute("""
                                    INSERT INTO audit.staging_audit_results 
                                    (transaction_id, code, status, diff_json, reasoning, raw_response)
                                    VALUES (%s, %s, %s, %s, %s, %s)
                                """, (
                                    t_id, 
                                    entry.get('code'), 
                                    entry.get('status'), 
                                    json.dumps(clean_changes), 
                                    entry.get('reasoning'), 
                                    json.dumps(entry)
                                ))
                                
                                # Обновление очереди
                                cur.execute("""
                                    UPDATE audit.audit_process_queue 
                                    SET audit_status = 'processed', 
                                        api_attempt_count = api_attempt_count + 1,
                                        last_processed_at = CURRENT_TIMESTAMP 
                                    WHERE transaction_id = %s::uuid
                                """, (t_id,))
                                
                            except Exception as e:
                                error_id = entry.get('transaction_id') if entry else "N/A"
                                logging.error(f"Ошибка сохранения транзакции {error_id}: {e}")
                                conn.rollback()
                                continue

                        conn.commit()
                        logging.info("УСПЕХ: Пачка обработана.")
                        
                    except Exception as e:
                        logging.error(f"Ошибка сохранения: {e}")
                        conn.rollback()

                countdown_timer(10)

        except NameError as e:
            logging.critical(f"ФАТАЛЬНАЯ ОШИБКА КОДА: {e}. Завершение работы.")
            import sys
            sys.exit(1) # Полная остановка процесса

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch_size", type=int, default=3)
    args = parser.parse_args()
    
    # 1. Открываем соединение
    conn = get_db_connection()

    # КРИТИЧЕСКАЯ ЗАЩИТА: Если база вернула None - останавливаем скрипт сразу
    if conn is None:
        print("\n[КРИТИЧЕСКАЯ ОШИБКА] Не удалось установить подключение к PostgreSQL!")
        print("Проверьте параметры подключения, статус сервера БД и повторите запуск.")
        raise SystemExit(1)
    
    print("\n[СТАРТ СЕССИИ] Восстановление динамической памяти ИИ...")
    
    # 2. Восстанавливаем кэш заметок
    ai_notes = restore_session_memory(conn)
    
    # ==================== ЗАЩИТНЫЙ БЛОК ПРОВЕРКИ КЭША ====================
    print("\n=================== ПРОВЕРКА ПАМЯТИ ИИ ПЕРЕД ЗАПУСКОМ ===================")
    if ai_notes.strip():
        print("В базе данных найдены следующие сохраненные AI-NOTES:")
        print("-" * 70)
        print(ai_notes)
        print("-" * 70)
    else:
        print("[ПРЕДУПРЕЖДЕНИЕ] Актуальные заметки не найдены в БД (возможно, это первый запуск).")
        print("ИИ начнет аудит с чистого листа.")
    print("=========================================================================")
    
    user_input = input("\nВы утверждаете эти заметки для запуска аудита? (y/n): ").strip().lower()
    
    if user_input != 'y':
        print("\n[ОТМЕНА] Запуск заблокирован пользователем. Скрипт завершает работу.")
        conn.close() 
        raise SystemExit(0)
        
    print("\n[УСПЕХ] Заметки утверждены. Запуск основного цикла аудита...\n")
    # =======================================================================
    
    # СТРОКА conn.close() УДАЛЕНА ОТСЮДА!
    
    try:
        # 3. Передаем все 3 параметра в обновленную функцию
        run_audit_loop(args.batch_size, conn, ai_notes)
    finally:
        # Соединение закроется ТОЛЬКО когда цикл True прервется (Ctrl+C или SystemExit)
        if conn:
            conn.close()
            print("[ИНФО] Соединение с PostgreSQL успешно закрыто.")