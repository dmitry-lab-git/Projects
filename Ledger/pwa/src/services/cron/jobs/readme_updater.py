"""
Service: Automatic Ledger metrics updater for README.md
Runs daily 00:00 via APScheduler integrated in Reflex PWA.
"""
import os
import re
import logging
from datetime import datetime
from zoneinfo import ZoneInfo
from pathlib import Path
from dotenv import load_dotenv
import psycopg2

load_dotenv("/home/fujitsu-u745/Projects/secure_folder/pwa/.env")
README_PATH = Path("/home/fujitsu-u745/Projects/README.md")
START_MARKER = "<!-- LEDGER_METRICS_START -->"
END_MARKER = "<!-- LEDGER_METRICS_END -->"
DB_URL = os.getenv("DATABASE_URL")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("readme_updater")

def get_counts():
    counts = {
        "transactions": 0,
        "acc_balance_snapshot_register": 0,
        "system_verification_log": 0,
        "staging_transactions": 0,
    }
    if not DB_URL:
        logger.error("DATABASE_URL not set")
        return counts
    try:
        conn = psycopg2.connect(DB_URL, connect_timeout=5)
        cur = conn.cursor()
        cur.execute(
            "SELECT transactions, acc_balance_snapshot_register, system_verification_log, staging_transactions FROM reports.v_ledger_metrics;"
        )
        row = cur.fetchone()
        if row:
            counts["transactions"] = row[0]
            counts["acc_balance_snapshot_register"] = row[1]
            counts["system_verification_log"] = row[2]
            counts["staging_transactions"] = row[3]
        cur.close()
        conn.close()
    except Exception as e:
        logger.exception(f"DB error in get_counts: {e}")
    return counts

def build_markdown_block(counts: dict) -> str:
    # Get time for Asia/Almaty zone (Pavlodar / Astana)
    now = datetime.now(ZoneInfo("Asia/Almaty")).strftime("%d.%m.%Y %H:%M:%S")
    block = f"""{START_MARKER}
## 📊 Ledger SystemMetrics (auto-updated: {now})

| Metric | Value | Description |
|--------|-------|-------------|
| **Current transaction count** | **{counts['transactions']}** | `public.transactions` |
| **Account reconciliation statements** | **{counts['acc_balance_snapshot_register']}** | `public.acc_balance_snapshot_register` |
| **Verified states** | **{counts['system_verification_log']}** | `reports.system_verification_log` since 13.10.2026 |
| **PWA Staging stream** | **{counts['staging_transactions']}** | `audit.staging_transactions` |

> Balance formula: `balance(i+1) = balance(i) + sum(i) * AccountEffect(TypeID)`

_Updated daily at 00:00 (Pavlodar, Astana) via APScheduler (Reflex PWA backend)_
{END_MARKER}"""
    return block

def update_readme_metrics():
    logger.info("Starting README metrics update...")
    counts = get_counts()
    logger.info(f"Counts: {counts}")
    
    if not README_PATH.exists():
        logger.error(f"README not found: {README_PATH}")
        return False
        
    content = README_PATH.read_text(encoding="utf-8")
    new_block = build_markdown_block(counts)
    
    # 1. Удаляем старый блок метрик из любого места, если он уже существовал
    if START_MARKER in content and END_MARKER in content:
        pattern = re.compile(f"{re.escape(START_MARKER)}.*?{re.escape(END_MARKER)}\\s*", re.DOTALL)
        content = pattern.sub("", content)
    
    # 2. Вставляем новый блок в самый верх файла, отделяя его пустой строкой от остального текста
    new_content = new_block.strip() + "\n\n---\n\n" + content.lstrip()
    
    README_PATH.write_text(new_content, encoding="utf-8")
    logger.info(f"README updated successfully and placed at the top: {README_PATH}")
    return True

if __name__ == "__main__":
    update_readme_metrics()