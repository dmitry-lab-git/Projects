import os
import json
import logging
import datetime
from decimal import Decimal
from uuid import UUID
import tiktoken

def json_serial(obj):
    """Функция-помощник для сериализации дат/Decimal в JSON."""
    return str(obj)

PROMPTS_DIR = 'prompts'

def count_tokens(text: str, model_name: str = "gpt-4o") -> int:
    try:
        encoding = tiktoken.encoding_for_model(model_name)
    except KeyError:
        encoding = tiktoken.get_encoding("cl100k_base")
    return len(encoding.encode(text))

def json_serial(obj):
    """Преобразует несериализуемые типы в строковый формат."""
    if isinstance(obj, (datetime.datetime, datetime.date)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return str(obj)
    if isinstance(obj, UUID):
        return str(obj)
    raise TypeError(f"Type {type(obj)} not serializable")

def load_prompt_file(filename):
    """Считывает текстовый файл из директории prompts."""
    filepath = os.path.join(PROMPTS_DIR, filename)
    if not os.path.exists(filepath):
        logging.warning(f"[PromptManager] Файл {filename} не найден. Пропущен.")
        return ""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read().strip()

def build_re_audit_prompt(transaction_data, prev_raw_response, ai_notes):
    """
    Собирает итоговый промпт для режима повторного аудита.
    Явно выделяет предыдущий ответ ИИ как 'версию 1.0'.
    """
    task = load_prompt_file('task.txt')
    requirements = load_prompt_file('requirements.txt')
    db_desc = load_prompt_file('db_description.txt')
    memory_instructions = load_prompt_file('memory_instructions.txt')
    updates = load_prompt_file('updates.txt')

    # Формируем структуру payload для передачи ИИ
    payload = {
        "transaction_current_state": transaction_data,
        "previous_audit_data_v1": prev_raw_response,
        "ai_notes_session_context": ai_notes
    }

    # Собираем финальный текст промпта
    prompt = f"""
{memory_instructions}

=========================================
ОПИСАНИЕ БИЗНЕС-ЛОГИКИ И БД:
=========================================
{db_desc}

=========================================
КРИТЕРИИ И ТРЕБОВАНИЯ АУДИТА:
=========================================
{requirements}

=========================================
ТЕКУЩЕЕ ЗАДАНИЕ (RE-AUDIT 247):
=========================================
{task}

=========================================
АКТУАЛЬНЫЕ ОБНОВЛЕНИЯ/ЛОГИ:
=========================================
{updates}

=========================================
ДАННЫЕ ДЛЯ АНАЛИЗА (JSON):
=========================================
{json.dumps(payload, ensure_ascii=False, indent=2, default=json_serial)}
"""
    return prompt.strip()

def build_initial_audit_prompt(transaction_data, ai_notes=None, session_stats=None):
    """
    Собирает промпт, включая динамическую статистику и память.
    """
    task = load_prompt_file('task.txt')
    requirements = load_prompt_file('requirements_initial.txt')
    db_desc = load_prompt_file('db_description.txt')
    memory_instructions = load_prompt_file('memory_instructions.txt')
    updates = load_prompt_file('updates.txt')

    # 1. Формируем текст статистики и заметок
    stats_text = session_stats if session_stats else "Ожидание данных аудита..."
    notes_text = ai_notes if ai_notes else "База знаний пуста. Работаем по общим инструкциям."

    # Убрали искусственный заголовок [EDGE CASES & RULES]. 
    # Теперь ai_notes вставляется как есть, со своей внутренней структурой.
    dynamic_memory_block = f"""
=========================================
ДИНАМИЧЕСКИЙ КОНТЕКСТ СЕССИИ:
=========================================
Статистика рассчитанная на основе данных БД после логирования ответов ИИ:
{stats_text}

Ваши заметки. Пользуйтесь лимитом 1500 токенов. Исчерпывайте потенциал динамической памяти на максимум.
{notes_text}
"""

    # 2. Формируем payload для данных
    payload = {
        "transaction_current_state": transaction_data,
        "audit_mode": "initial_independent"
    }

    # 3. Собираем финальный промпт
    prompt = f"""
{memory_instructions}
{dynamic_memory_block}

=========================================
ОПИСАНИЕ БИЗНЕС-ЛОГИКИ И БД:
=========================================
{db_desc}

=========================================
КРИТЕРИИ И ТРЕБОВАНИЯ АУДИТА:
=========================================
{requirements}

=========================================
ТЕКУЩЕЕ ЗАДАНИЕ (INITIAL INDEPENDENT AUDIT):
=========================================
{task}

=========================================
АКТУАЛЬНЫЕ ОБНОВЛЕНИЯ:
=========================================
{updates}

=========================================
ДАННЫЕ ДЛЯ АНАЛИЗА (JSON):
=========================================
{json.dumps(payload, ensure_ascii=False, indent=2, default=json_serial)}
"""
    return prompt.strip()