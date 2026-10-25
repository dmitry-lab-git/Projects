import psycopg2
import json
from datetime import datetime
from config import client, get_db_connection


def process_audit_manual_review(limit=200):
    conn = get_db_connection()
    cur = conn.cursor()

    query = """
    SELECT 
        re.staging_id, re.transaction_id, row_to_json(t) as tx,
        a_init.raw_response as init_audit, re.raw_response as re_audit
    FROM audit.staging_audit_results re
    JOIN audit.transactions_fullfields t ON re.transaction_id = t.transaction_id
    LEFT JOIN audit.staging_audit_results a_init ON re.transaction_id = a_init.transaction_id 
              AND a_init.audit_type = 'initial_audit'
    WHERE re.audit_type = 're_audit' 
      AND re.status = 'manual_review'
      AND NOT EXISTS (SELECT 1 FROM audit.staging_audit_results m 
                      WHERE m.transaction_id = re.transaction_id AND m.audit_type = 'manual_review')
    ORDER BY re.created_at ASC LIMIT %s;
    """
    
    cur.execute(query, (limit,))
    rows = cur.fetchall()

    for row in rows:
        re_id, tx_id, tx_data, init_res, re_res = row
        
        # 1. Исправленная кодировка для вывода
        print(f"\n{'='*80}")
        print(f"ТРАНЗАКЦИЯ (ID: {tx_id})")
        print(f"{'-'*80}")
        
        # 2. Вывод всех полей транзакции (включая пропущенные)
        # Получаем полный список ключей из tx_data
        for key, value in tx_data.items():
            print(f"{str(key).upper():<20}: {value}")
            
        # 3. Четкое разделение аудита с декодированием Unicode
        print(f"\n{'='*80}")
        print("ИСТОРИЯ АУДИТА:")
        print(f"INITIAL AUDIT: {json.dumps(init_res, ensure_ascii=False, indent=2)}")
        print(f"{'-'*40}")
        print(f"RE-AUDIT:      {json.dumps(re_res, ensure_ascii=False, indent=2)}")
        print(f"{'='*80}")
        
        # Интерактивный опрос
        reasoning = input("1. Введите reasoning: ")
        
        # Сбор правок через разделители
        changes_input = input("2. Если есть правки, введите: (поле1:значение; поле2:значение). Если нет, нажмите enter. ")
        corrections = []
        if changes_input.strip() and changes_input.lower() != "none":
            for item in changes_input.split(";"):
                if ":" in item:
                    field, value = item.split(":", 1)
                    corrections.append({"field": field.strip(), "value": value.strip()})
        
        new_score = input("3. Новый trust_score: ")
        status_code = input("4. Новый статус (1-need_correction, 2-verified): ")
        
        status = "need_correction" if status_code == "1" else "verified"
        
        # Формирование JSON в соответствии с вашим улучшенным контрактом
        verdict = {
            "audit_results": [{
                "transaction_id": tx_id,
                "code": tx_data.get("code", 0),
                "trust_score": int(new_score),
                "status": status,
                "changes": {
                    "acc_balance": "",
                    "suggested_correction": corrections if corrections else None # <-- ЭТА СТРОКА
                },
                "reasoning": reasoning
            }],
            "ai_notes": f"Manual Review by Admin at {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        }
        
        # Вставка с явным указанием поля reasoning
        insert_query = """
        INSERT INTO audit.staging_audit_results 
        (transaction_id, audit_type, status, raw_response, parent_staging_id, reasoning)
        VALUES (%s, 'manual_review', %s, %s, %s, %s);
        """
        cur.execute(insert_query, (tx_id, status, json.dumps(verdict), re_id, reasoning))
        conn.commit()
        print("-> Сохранено.")

    cur.close()
    conn.close()

if __name__ == "__main__":
    process_audit_manual_review(limit=200)