import logging
from pathlib import Path
from src.services.api_client import AuditAPIClient
from src.storage.database import execute_select

logger = logging.getLogger("aive.database_dialogue")


class DatabaseDialogue:
    """Класс для организации прямого диалога пользователя с БД через ИИ.

    ===========================================================================
    ТЕХНИЧЕСКОЕ ОПИСАНИЕ ПРОЕКТА И ТЕКУЩЕЙ АРХИТЕКТУРЫ «AIVE»
    ===========================================================================
    
    Проект представляет собой модульную автоматизированную систему ИИ-аудита
    финансовых логов, обновлений и транзакций с поддержкой интерактивного 
    Text-to-SQL взаимодействия с базой данных.

    Локация проекта: C:\\Users\\admin\\Desktop\\Ledger\\aive\\

    ФИКСИРОВАННЫЕ ОГРАНИЧЕНИЯ ТЕКУЩЕЙ СЕССИИ:
    - Максимальный размер ответа ИИ: строго до 1 000 токенов.
    - Входной контекст оптимизирован (словари отключены для экономии ресурсов).
    - Базовый размер системного промпта: ~2,440 токенов (6,134 знаков).

    ТЕКУЩАЯ СТРУКТУРА ФАЙЛОВ И ПАПОК ПРОЕКТА:
    aive/
    ├── dicts/                          # Отключенные справочники (для оптимизации контекста)
    │   ├── accounts.txt                # Реестр счетов компании
    │   ├── contragens.txt              # Список контрагентов
    │   ├── dict_categories.txt         # Классификатор категорий
    │   └── entities.txt                # Перечень связанных сущностей
    │
    ├── prompts/                        # Слой управления ИИ-контекстом (чистый текст)
    │   ├── ddl.txt (или .sql)          # Структура таблиц БД для Text-to-SQL режима
    │   ├── db_description.txt          # Бизнес-описание логики хранения данных
    │   ├── memory_instructions.txt     # Системные инструкции по ведению сессии
    │   ├── requirements.txt            # Бизнес-правила и критерии аудита
    │   ├── task.txt                    # Текущее задание на аудит
    │   └── updates.txt                 # Свежие логи/транзакции для текущего анализа
    │
    ├── src/                            # Исполняемый исходный код системы
    │   ├── __init__.py
    │   ├── config.py                   # Конфигурация, логирование, лимиты, .env
    │   ├── exceptions.py               # Кастомные исключения (например, APITimeoutError)
    │   ├── main.py                     # Оркестрация пайплайна и CLI-интерфейс
    │   │
    │   ├── core/                       # Ядро бизнес-логики
    │   │   ├── __init__.py
    │   │   ├── database_dialogue.py    # Текущий модуль (режим вопрос-ответ к БД)
    │   │   ├── engine.py               # Главный цикл аудита (run_audit_loop)
    │   │   └── extraction.py           # Алгоритмы извлечения аномалий и ключевых слов
    │   │
    │   ├── services/                   # Инфраструктурные сервисы
    │   │   ├── __init__.py
    │   │   ├── api_client.py           # Защищенный API-клиент (3 попытки, backoff, паузы)
    │   │   └── prompt_manager.py       # Динамическая сборка и валидация промптов
    │   │
    
    │   └── storage/                    # Работа со свойствами хранения данных
    │       ├── __init__.py
    │       ├── database.py             # Пул подключений и исполнение SQL (execute_select)
    │       └── session_repository.py   # Управление памятью и шагами (restore_session_memory)
    │
    ├── prompt_prepairing.py            # Изолированный скрипт для валидации и замера токенов
    └── requirements.txt                # Зависимости проекта (включая tiktoken, rich)
    ===========================================================================
    """

    def __init__(self, api_client: AuditAPIClient, base_dir: str = "."):
        self.api_client = api_client
        self.base_dir = Path(base_dir)
        self.prompts_dir = self.base_dir / "prompts"

    def _load_ddl(self) -> str:
        """Загружает структуру таблиц из DDL файла."""
        ddl_path = self.prompts_dir / "ddl.txt"
        if not ddl_path.exists():
            ddl_path = self.prompts_dir / "ddl.sql"
        
        if not ddl_path.exists():
            raise FileNotFoundError(f"Критическая ошибка: DDL-файл структуры БД не найден в {self.prompts_dir}")
            
        with open(ddl_path, "r", encoding="utf-8") as f:
            return f.read().strip()

    def is_dialogue_command(self, user_input: str) -> bool:
        """Проверяет, является ли ввод командой активации диалога с БД."""
        return user_input.strip().lower().startswith(("/query", "sql:", "база:"))

    def validate_sql_safety(self, sql_query: str) -> bool:
        """Проверяет SQL-запрос на безопасность перед выполнением в БД.
        
        Разрешены только безопасные операции чтения данных (SELECT).
        """
        clean_query = sql_query.strip().upper()
        
        if not clean_query.startswith("SELECT"):
            return False
            
        dangerous_keywords = [
            "INSERT", "UPDATE", "DELETE", "DROP", "ALTER", 
            "CREATE", "TRUNCATE", "REPLACE", "GRANT", "REVOKE"
        ]
        
        for keyword in dangerous_keywords:
            if keyword in clean_query:
                return False
                
        return True

    def ask_database(self, user_question: str) -> str:
        """Принимает вопрос на естественном языке, заставляет ИИ сгенерировать SQL,

        выполняет его в БД и возвращает результат пользователю.
        """
        clean_question = user_question.replace("/query", "").replace("SQL:", "").replace("база:", "").strip()
        ddl_structure = self._load_ddl()
        
        sql_prompt = (
            f"=== СТРУКТУРА БАЗЫ ДАННЫХ (DDL) ===\n{ddl_structure}\n\n"
            f"=== ИНСТРУКЦИЯ ===\n"
            f"Напиши один валидный SQL-запрос SELECT для СУБД PostgreSQL, который решает задачу пользователя.\n"
            f"Выводи ТОЛЬКО чистый SQL-код запроса. Без разметки ```sql, без пояснений и без комментариев.\n\n"
            f"=== ЗАДАЧА ПОЛЬЗОВАТЕЛЯ ===\n{clean_question}"
        )
        
        logger.info("Запрос к ИИ для генерации SQL...")
        
        # Вызов API (Внутренние механизмы обеспечивают лимит ответа до 1000 токенов)
        generated_sql = self.api_client.secure_api_call(sql_prompt).strip()
        generated_sql = generated_sql.replace("```sql", "").replace("```", "").strip()
        
        logger.info(f"Сгенерированный SQL: {generated_sql}")
        
        if not self.validate_sql_safety(generated_sql):
            logger.error(f"Блокировка потенциально опасного SQL-запроса: {generated_sql}")
            return "Ошибка безопасности: Сгенерированный SQL-запрос содержит запрещенные команды модификации данных."

        try:
            db_results = execute_select(generated_sql)
            
            if not db_results:
                return "Запрос выполнен успешно, но совпадений в базе данных не найдено."
                
            formatted_output = "Результаты выборки из БД:\n"
            for row in db_results:
                formatted_output += f"- {row}\n"
                
            return formatted_output

        except Exception as db_error:
            logger.error(f"Ошибка выполнения SQL в базе данных: {db_error}")
            return f"Ошибка синтаксиса базы данных при исполнении запроса: {db_error}"
