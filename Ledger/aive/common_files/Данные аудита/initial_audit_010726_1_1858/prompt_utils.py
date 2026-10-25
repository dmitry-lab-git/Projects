import json

def build_main_prompt(context, transactions):
    """Формирует финальный JSON-промпт."""
    return json.dumps({
        "context": context,
        "transactions": transactions
    }, default=str, indent=2)