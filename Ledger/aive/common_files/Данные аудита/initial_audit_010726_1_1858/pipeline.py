from config import get_db_connection
from api_utils import secure_api_call
from propmt_prepairing import (
    fetch_pending_tx_data, extract_keywords, find_relevant_rows, 
    prepare_final_prompt, update_tx_status
)

def run_aive_pipeline(client):
    conn = get_db_connection()
    try:
        pending_tasks = fetch_pending_tx_data(conn)
        for task in pending_tasks:
            # 1. Извлечение ключей
            keywords = extract_keywords(client, [task], conn, task['id'])
            
            # 2. Обогащение контекстом
            tables_config = {"public.transactions": "transaction_name"}
            context_data = find_relevant_rows(conn, tables_config, keywords)
            
            # --- ДИАГНОСТИЧЕСКИЙ ВЫВОД (DEBUG) ---
            print("\n" + "="*80)
            print("КОНТРОЛЬНЫЕ ТОЧКИ ПЕРЕД ОТПРАВКОЙ В API:")
            print("-" * 80)
            print(f"1. transaction_keywords_examples:\n{json.dumps(context_data, indent=2, ensure_ascii=False)}")
            print(f"\n2. raw_line_text:\n{task['raw_line_text']}")
            print(f"\n3. processing_metadata:\n{json.dumps(task['processing_metadata'], indent=2, ensure_ascii=False)}")
            print("="*80 + "\n")
            # --------------------------------------

            # 3. Сборка промпта
            prompt = prepare_final_prompt(
                context_data, "System prompt...", 
                task['raw_line_text'], task['processing_metadata']
            )
            
            # 4. Вызов ИИ
            resp = secure_api_call(client, prompt, "Classification", conn=conn, source_uuid=task['id'])
            
            # 5. Статус
            update_tx_status(conn, task['id'], 'processed')
            print(f"Обработано: {task['id']}")
    finally:
        conn.close()