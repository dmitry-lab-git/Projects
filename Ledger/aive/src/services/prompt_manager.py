import os
import json
import logging

PROMPTS_DIR = 'prompts'

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
{json.dumps(payload, ensure_ascii=False, indent=2)}
"""
    return prompt.strip()