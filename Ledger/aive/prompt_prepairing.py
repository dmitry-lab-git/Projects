from rich.traceback import install
import sys

# Настраиваем красивый вывод ошибок БЕЗ несуществующих аргументов
install(
    show_locals=True,     
    width=100,            
    extra_lines=1,        
    theme="monokai",      
    word_wrap=True,       
    suppress=[sys]
)

import os
from pathlib import Path
import tiktoken

def count_tokens(text: str, model_name: str = "gpt-4o") -> int:
    """Подсчитывает количество токенов в тексте."""
    try:
        encoding = tiktoken.encoding_for_model(model_name)
    except KeyError:
        encoding = tiktoken.get_encoding("cl100k_base")
    return len(encoding.encode(text))

def load_file(path: Path) -> str:
    """Безопасное чтение файла с выводом предупреждения, если он пустой."""
    if not path.exists():
        return f"[Файл {path.name} не найден]"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read().strip()
        return content if content else f"[Файл {path.name} пуст]"

def main():
    # Находим папку, где лежит сам скрипт (aive/)
    base_dir = Path(__file__).parent.resolve()
    
    # Папка с промптами теперь указывает строго на aive/prompts
    prompts_dir = base_dir / "prompts"
    
    # Папка со словарями (проверим оба варианта: в корне или внутри prompts)
    dicts_dir = prompts_dir / "dicts" if (prompts_dir / "dicts").exists() else base_dir / "dicts"

    # 1. Загрузка основных инструкций из папки prompts
    db_description = load_file(prompts_dir / "db_description.txt")
    memory_instructions = load_file(prompts_dir / "memory_instructions.txt")
    requirements = load_file(prompts_dir / "requirements.txt")
    task = load_file(prompts_dir / "task.txt")
    updates = load_file(prompts_dir / "updates.txt")

    # 2. Загрузка словарей из папки dicts
    #accounts = load_file(dicts_dir / "accounts.txt")
    #contragens = load_file(dicts_dir / "contragens.txt")
    #dict_categories = load_file(dicts_dir / "dict_categories.txt")
    #entities = load_file(dicts_dir / "entities.txt")

    # 3. Сборка максимально развернутого промпта
    final_prompt = (
        f"=== СИСТЕМНЫЕ ИНСТРУКЦИИ И ПАМЯТЬ ===\n{memory_instructions}\n\n"
        f"=== ОПИСАНИЕ БАЗЫ ДАННЫХ ===\n{db_description}\n\n"
        #f"=== СПРАВОЧНИКИ И СЛОВАРНЫЕ ДАННЫЕ ===\n"
        #f"--- Счета ---\n{accounts}\n\n"
        #f"--- Контрагенты ---\n{contragens}\n\n"
        #f"--- Категории ---\n{dict_categories}\n\n"
        #f"--- Сущности ---\n{entities}\n\n"
        f"=== ТЕКУЩАЯ ЗАДАЧА АУДИТА ===\n{task}\n\n"
        f"=== ПРАВИЛА И ТРЕБОВАНИЯ ===\n{requirements}\n\n"
        f"=== ДАННЫЕ И ОБНОВЛЕНИЯ ДЛЯ АНАЛИЗА ===\n{updates}"
    )

    num_characters = len(final_prompt)

    # 4. Безопасный подсчет токенов
    try:
        try:
            encoding = tiktoken.get_encoding("cl100k_base")
        except ValueError:
            encoding = tiktoken.get_encoding("gpt2")
        num_tokens = len(encoding.encode(final_prompt))
        method = f"tiktoken ({encoding.name})"
    except Exception:
        num_tokens = int(num_characters / 4)
        method = "аппроксимация (1 токен ~ 4 символа)"

    # 5. Вывод результатов в терминал
    print("\n" + "="*50)
    print("           ФИНАЛЬНЫЙ СФОРМИРОВАННЫЙ ПРОМПТ")
    print("="*50 + "\n")
    print(final_prompt)
    print("\n" + "="*50)
    print("           СТАТИСТИКА РАЗМЕРА ПРОМПТА")
    print("="*50)
    print(f"Количество символов: {num_characters:,} знаков.")
    print(f"Оценка размера в токенах: {num_tokens:,} ({method}).")
    print("="*50 + "\n")

if __name__ == "__main__":
    main()
