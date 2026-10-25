import psycopg2
import os
from dotenv import load_dotenv
from config import client, get_db_connection

# Загружаем переменные окружения
load_dotenv()

# Ваш список идентификаторов, полученный из логов
error_ids = [
    "bb164edd-73d4-4bcc-abe3-099d6bbdee1e",
    "d581e1a1-4884-49dc-bd22-a9d34a3eb251",
    "349d8f09-fd45-46e9-966c-ac076924830d",
    "c2f4a991-1fe6-46a9-b16d-aa2b6d1a4e4c",
    "69516dd2-3c0c-4ee2-9cd2-fd3f47b1490b",
    "0fa925ae-5b1f-4a5c-876e-04c3d18ebcfb",
    "692ad331-e417-4012-9731-44c9ac3ff583",
    "3b55462f-27b9-45b7-abe5-6ca693fb4215",
    "3f5c8425-1267-49e1-b577-78f3aac29473",
    "7071e91b-3d7d-43da-9c6d-02a37ad70912",
    "814694aa-a96b-4928-b92e-b60e393c396a",
    "c8e9cd82-efd5-44c6-93ee-86117e01887a",
    "bd7e6bca-4012-4250-b938-ec008174e2a0",
    "8ab9e22f-dedc-40cc-85d1-f9c8d2c3a97d",
    "6efb810a-58b4-45c7-ad52-1f54de7fe9e5",
    "a14ae1f8-a689-44db-9e1c-a8592c346665",
    "2591fdac-0f31-4132-aedb-d26000ea6e49",
    "bb25b5fc-6889-4269-b1de-833a219b83ce",
    "cfdf373a-c895-489b-87ac-0832ad88d66f",
    "d4e3c90b-4ed6-4d4a-8ad9-6075d67ef43d",
    "4c1607f1-31b3-4cca-b065-ad1a1b9afcb9",
    "4b1e8617-c614-46a9-8b70-74e64e8ac408",
    "8c184d95-5112-40ee-81c3-6c1adca02c3d",
    "1b3007ec-8d85-4c58-8ab0-81e056a9d889",
    "c978e5ad-3227-4772-b4f3-3c74c164c90e",
    "8f8e71fe-dfaa-4004-9fdf-2939dcbd2b38",
    "14ca42b4-f1cd-43da-ad47-3b67376d483f",
    "e2814cdd-2906-4198-952c-2e77ffe77f0b",
    "533a1cff-ec4c-4601-82b1-dcdea3930b0a",
    "5d0de5fa-4536-4e00-a50a-0f89eb7fb5c2",
    "911cc5da-e98d-4ae7-be8e-09bac1eda3be",
    "1e8cfb55-c90e-4e82-995e-2f43d536d429",
    "13a00338-5cb8-4a4c-82ac-578dc4f67fea",
    "bf0cb81d-c4a7-4341-abd0-c6e74b49ccfc",
    "75fcfcb2-a425-41d9-8426-29ac15c9c700",
    "950fed24-59e4-4199-8e23-f1f49350016e",
    "4f0b473e-9098-4d4a-bbbf-67935441b643",
    "4bdda4d5-9141-4877-af24-229fd6d597a0",
    "9183e25a-98cf-4475-accd-2bf5f033a550",
    "268443a1-528e-4030-9fe8-a6df4474962d",
    "24dc9bef-cb10-4516-8040-1c93c03d69da",
    "3e999307-11ed-47bd-9b99-90df7abd0070",
    "14953ba2-9f19-4ccc-b2d8-d369aba60ad8",
    "928b8d70-d0e4-4034-b63e-01745e2bc81e",
    "f972ff1e-1284-4dbb-a718-bec51fec3ce8",
    "e6525802-2810-4df5-828e-47604a5ec468",
    "d09da02a-d555-485f-9405-9f3779227233",
    "44f362aa-cc54-4bd7-8237-e84fce97d3c7",
    "56e1ee85-c026-497b-823d-3ab99e7f1fed",
    "dc5db366-2106-431d-bcc1-a70840c297e8",
    "ccc331de-ba0e-4d0f-b5b5-a7b9e48149fe",
    "d24ba248-8934-4f35-81c3-6b1bb8a6552b",
    "08a31891-a2d4-480d-bc94-aaf1c34793e0",
    "10cd985e-f998-45ae-b38a-01c13573e98e",
    "5a978a8a-45eb-4adb-a91f-3b5ae3df47d4",
    "7cb0d454-9406-4311-9f3f-3be78f4cb6fa",
    "c12618a3-f651-435c-b00e-e9e4253a2881",
    "b792dfe4-2656-4458-8fb4-5110b5658595",
    "635be3f9-85a5-4a9d-9600-1d1d3151140a",
    "09a94a1f-eb6a-44f1-ab02-3f6b659d9d44",
    "6c2b49da-2440-4e1b-9cde-36555b8f1ec3",
    "91854d89-d0b1-4d28-a5f1-526a1176c342",
    "ce07092f-507f-4f6b-a3b3-b8e313e9f1f5",
    "8f3ece56-c900-4c7b-ab4e-0ae216d23b89",
    "dbac05f5-1118-4dab-98d7-59db9363d885",
    "20760617-58a3-47d1-b805-1a8506df818b",
    "8e71347a-39e2-4c08-9088-a6bdb71fbfcd",
    "86c9f441-e228-4a63-acac-c4808367d675",
    "c32e2859-e98b-4809-8bef-e0b945145f4f",
    "4b9da078-5b9c-41ef-be30-b90f9a679fa7",
    "5c1f0f4e-9158-4bdc-8f6e-abef07c6aad8",
    "5297d137-d001-4dbe-9560-a56b1f372168",
    "0b5d2d01-5f5d-4e21-8ea8-6ac183630036",
    "01552b45-782d-4301-82ae-7a38b7fa6c1a",
    "48d189c5-26e9-44c1-93b5-09504da078f8",
    "b64fe348-0325-45fa-b114-abc2d2db5273",
    "2b5170b0-f5f3-4850-ae2c-6773663ef663",
    "de1fd306-ed5c-4a00-82e7-1ae33cadc50a",
    "377e9f82-4d83-47dc-bf07-348a92b88f28",
    "4872fcf9-2281-48e2-a12e-1df20ef15aed",
    "4abdf4a0-84b5-466d-a1ed-e7b78aef7285",
    "11030a41-6f88-4a7e-9dda-e9ecd2c1ffcf",
    "7c976c25-0e2f-4b3d-b2fd-ce3656aa48cb",
    "cb2557ce-900f-4b4b-a7b2-7f970a6b26f7",
    "d361efcd-c761-4204-b39a-efb26e0e5e52",
    "203a9fa0-427d-4ed6-83a2-e6e3e066a3f6",
    "a37dddd6-721a-446b-8de8-157504422814",
    "df4c47a4-96e0-4493-b5ac-dcfc4e660035",
    "a24a582e-906f-4977-8dc2-d2b52abfc5ae",
    "8e860ac3-9fc6-4ab7-b8c4-65156e99d6f9",
    "fc8f2821-2823-428e-8ce8-d36a1bd18408",
    "ea85041a-3fa7-4c49-8772-54f169418d07",
    "96679a93-09b4-4021-95cd-7dcb9487838a",
    "e9e9ec64-ffb1-4949-87f5-3be0973bc215",
    "4bf5dd84-26c0-4c0a-9a8d-1607f5c7c188",
    "4d600352-f15a-4207-bb95-2b4a9c1ec16d",
    "720ac14f-ec86-47e0-995f-e9ff8d5d1acc",
    "60247504-3f84-4176-a210-09cd1e7c47aa",
    "42c844c6-48e3-4a65-9a7f-787f77730b8c",
    "7893af0e-e099-43e5-8499-5d5ae5ccce33"
]

def extract_errors_to_file(ids, log_file, output_file):
    with open(log_file, 'r', encoding='utf-8') as f:
        log_content = f.read()

    with open(output_file, 'w', encoding='utf-8') as f:
        for eid in ids:
            # Ищем в логе ID и захватываем текст ошибки сразу после него
            # Паттерн ищет ID и забирает всё до конца строки или следующее сообщение
            pattern = rf"{eid}.*?ERROR - (.*?)(?:\n\d{{4}}-\d{{2}}-\d{{2}}|$)"
            match = re.search(pattern, log_content, re.DOTALL)
            
            if match:
                error_text = match.group(1).strip()
                f.write(f"{eid} - {error_text}\n")
            else:
                f.write(f"{eid} - Ошибка не найдена в терминале\n")

    print(f"Файл {output_file} успешно создан.")

def apply_errors_to_db(errors_file):
    # Словарь для хранения: {source_extraction_id: error_text}
    updates = {}
    with open(errors_file, 'r', encoding='utf-8') as f:
        for line in f:
            if " - " in line:
                parts = line.split(" - ", 1)
                sid, err_text = parts[0].strip(), parts[1].strip()
                updates[sid] = err_text

    if not updates:
        print("Нет данных для обновления.")
        return

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Обновляем каждую запись индивидуально или через CASE
        # Для небольшого количества (как у вас) цикл с execute безопасен и понятен
        query = """
        UPDATE processing.aive_requests_log 
        SET status = 'ERROR_429', error_message = %s 
        WHERE source_extraction_id = %s
        """
        
        for sid, err_text in updates.items():
            cur.execute(query, (err_text, sid))
            
        conn.commit()
        print(f"Обновление завершено. Обработано записей: {len(updates)}")
        
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Ошибка при обновлении БД: {e}")

if __name__ == "__main__":
    apply_errors_to_db('errors_output.txt')