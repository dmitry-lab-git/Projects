import sys
import os
import uuid
import random
from unittest.mock import MagicMock


# Добавляем текущую директорию в путь, чтобы импорты видели соседей
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Импортируем вашу логику
from main import secure_api_call
from core.db_utils.db_access import get_db_connection 

def run_isolated_test():
    print("--- ИНИЦИАЛИЗАЦИЯ ТЕСТА ---")
    
    # 1. Подключение к БД через ваш config.py
    try:
        conn = get_db_connection()
        print("БД: Подключение успешно.")
    except Exception as e:
        print(f"Ошибка БД: {e}")
        return

    # 2. Подготовка параметров
    test_id = f"TEST_{uuid.uuid4().hex[:6]}"
    mock_client = MagicMock()

    mock_client.models.count_tokens.return_value.total_tokens = 50
    
    # Эмуляция ответа API
    mock_client.models.generate_content.return_value = MagicMock(
        text="Случайный тестовый текст: " + "".join([str(random.randint(0,9)) for _ in range(200)])
    )

    # 3. Запуск
    print(f"Запуск secure_api_call с ID: {test_id}")
    try:
        result = secure_api_call(
            client=mock_client,
            prompt_text="Тестовый запрос 100-500",
            conn=conn,
            source_uuid=test_id,
            model_name="gemini-2.5-flash"
        )
        print("API Вызов прошел успешно.")
    except Exception as e:
        print(f"Ошибка в процессе API вызова: {e}")
    finally:
        conn.close()
        print("Соединение закрыто.")
        print(f"Чтобы удалить данные, выполните: DELETE FROM api_requests WHERE source_extraction_id = '{test_id}';")

if __name__ == "__main__":
    run_isolated_test()