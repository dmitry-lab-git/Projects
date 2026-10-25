================================================================================
АРХИТЕКТУРА ИНТЕРФЕЙСА РУЧНОГО АУДИТА (PYTHON)
docid:3218e873-0e3a-41c9-9d0f-cef4b68f1f80
================================================================================

Данный скрипт реализует интерактивный интерфейс для поэтапной обработки 
транзакций, находящихся в статусе 'manual_review'. 

Логика работы:
1. Выборка транзакций с объединением данных initial_audit, re_audit.
2. Отображение транзакции согласно утвержденной структуре полей.
3. Валидация через контракт ответа (JSON), включающий trust_score и reasoning.
4. Сохранение вердикта в staging_audit_results.

--------------------------------------------------------------------------------
КОД РЕАЛИЗАЦИИ
--------------------------------------------------------------------------------

import psycopg2
import json

def process_audit_batch(limit=10):
    conn = psycopg2.connect("dbname=your_db user=your_user password=your_pass")
    cur = conn.cursor()

    # Запрос собирает все стадии аудита для формирования стека истории
    query = """
    SELECT 
        t.transaction_id, t.transaction_name, t.amount,
        a_init.raw_response as initial_audit,
        a_re.raw_response as re_audit,
        row_to_json(t) as transaction_data,
        a_re.staging_id
    FROM audit.staging_audit_results a_re
    JOIN audit.transactions_fullfields t ON a_re.transaction_id = t.transaction_id
    LEFT JOIN audit.staging_audit_results a_init ON a_re.transaction_id = a_init.transaction_id 
              AND a_init.audit_type = 'initial'
    WHERE a_re.status = 'manual_review'
    ORDER BY a_re.created_at ASC
    LIMIT %s;
    """
    
    cur.execute(query, (limit,))
    rows = cur.fetchall()

    for row in rows:
        tx_id, tx_name, amount, init_res, re_res, tx_json, stage_id = row
        
        print(f"\nТРАНЗАКЦИЯ: {tx_name} (ID: {tx_id}) | Сумма: {amount}")
        print("ИСТОРИЯ АУДИТА:")
        print(f"Initial: {json.dumps(init_res, indent=2)}")
        print(f"Re-audit: {json.dumps(re_res, indent=2)}")
        print("ДАННЫЕ ТРАНЗАКЦИИ:")
        print(json.dumps(tx_json, indent=2))
        
        # Интерактивный сбор вердикта по контракту
        score = input("Введите trust_score (1-10): ")
        reason = input("Введите reasoning (пояснение): ")
        status = input("Статус [verified/need_correction]: ")
        
        # Формирование JSON по контракту
        verdict = {
            "audit_results": [{
                "transaction_id": tx_id,
                "trust_score": int(score),
                "status": status,
                "changes": {"suggested_correction": "None"},
                "reasoning": reason
            }],
            "ai_notes": "Manual Review Completed"
        }
        
        # Обновление БД
        update_query = """
        UPDATE audit.staging_audit_results 
        SET status = %s, raw_response = %s, applied_at = CURRENT_TIMESTAMP
        WHERE staging_id = %s;
        """
        cur.execute(update_query, (status, json.dumps(verdict), stage_id))
        conn.commit()

    cur.close()
    conn.close()

================================================================================
ПРИМЕЧАНИЯ К КОДУ
================================================================================
1. Контракт ответа (JSON) жестко задан для обеспечения однородности данных.
2. Статус транзакции обновляется в таблице staging_audit_results.
3. Поле raw_response перезаписывается итоговым вердиктом оператора.
================================================================================