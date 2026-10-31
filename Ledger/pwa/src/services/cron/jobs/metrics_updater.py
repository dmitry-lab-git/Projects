import os
import time
import json
import subprocess
import reflex as rx
from sqlalchemy import text
import logging
from datetime import datetime, timezone, timedelta

from pwa.db import get_household_session

logger = logging.getLogger(__name__)

LAST_RUN_FILE = ".pwa_metrics_last_run"
MIN_INTERVAL_SEC = 21600  # 6 часов

# Единый целевой файл отчетов системы
SYSTEM_REPORT_FILE = "/home/fujitsu-u745/Projects/digital_living_room/system_report_data.json"
EVENTS_JSON_FILE = "/home/fujitsu-u745/Projects/digital_living_room/events.json"
REPO_DIR = "/home/fujitsu-u745/Projects/digital_living_room" # Путь к корню репозитория

def run_git_push(commit_message="Auto-update system metrics"):
    """Автоматический коммит и пуш обновленного JSON в репозиторий"""
    try:
        # Переходим в директорию репозитория
        os.chdir(REPO_DIR)
        
        # Проверяем статус git
        status_res = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, check=True)
        if not status_res.stdout.strip():
            logger.info("CRON Git: Нет изменений для коммита.")
            return

        # Добавляем файлы отчетов
        subprocess.run(["git", "add", "system_report_data.json", "events.json"], check=True)
        
        # Делаем коммит
        subprocess.run(["git", "commit", "-m", commit_message], check=True)
        
        # Пушим в мастер (или текущую ветку)
        subprocess.run(["git", "push", "origin", "main"], check=True)
        logger.info("CRON Git: Изменения успешно отправлены в GitHub (git push выполнен).")
        
    except subprocess.CalledProcessError as e:
        logger.error(f"CRON Git Ошибка выполнения команд: {e}")
    except Exception as e:
        logger.error(f"CRON Git Непредвиденная ошибка: {e}")

def update_pwa_dashboard_metrics(force: bool = False):
    current_time = time.time()
    
    if not force and os.path.exists(LAST_RUN_FILE):
        with open(LAST_RUN_FILE, "r") as f:
            try:
                last_run = float(f.read().strip())
                if current_time - last_run < MIN_INTERVAL_SEC:
                    return
            except ValueError:
                pass

    logger.info(f"CRON: Запуск обновления метрик (force={force})...")
    
    digital_metrics = {"transactions": "0", "balance_snapshots": "0", "verified_states": "0", "pwa_staging_flow": "0"}
    textile_metrics = {"projects_implemented": "0", "finished_products": "0", "material_consumption_m": 0.0}
    
    current_month_str = datetime.now().strftime("%B %Y")
    recycling_metrics = {
        "period": current_month_str,
        "disposition_records": []
    }

    # Шаг 1: Чтение Digital (Ledger БД)
    try:
        with rx.session() as ledger_session:
            ledger_res = ledger_session.execute(text("""
                SELECT transactions, acc_balance_snapshot_register, system_verification_log, staging_transactions
                FROM reports.v_ledger_metrics LIMIT 1;
            """)).fetchone()
            
            if ledger_res:
                digital_metrics = {
                    "transactions": str(ledger_res[0]),
                    "balance_snapshots": str(ledger_res[1]),
                    "verified_states": str(ledger_res[2]),
                    "pwa_staging_flow": str(ledger_res[3])
                }
    except Exception as e:
        logger.error(f"CRON Ошибка Ledger: {str(e)}")

    # Шаг 2: Обращение к Household БД (Textile & Current Month Infrastructure)
    try:
        household_session_gen = get_household_session()
        if hasattr(household_session_gen, "__next__") or hasattr(household_session_gen, "__iter__"):
            household_session = next(household_session_gen)
        else:
            household_session = household_session_gen

        try:
            # 2.1 Textile
            try:
                textile_res = household_session.execute(text("""
                    SELECT 
                        SUM(total_projects) AS total_projects,
                        SUM(total_items_produced) AS total_items,
                        ROUND(SUM(total_fabric_consumed_m), 2) AS total_consumption
                    FROM texere.v_textile_production_metrics;
                """)).fetchone()
                
                if textile_res and textile_res[0] is not None:
                    textile_metrics = {
                        "projects_implemented": str(textile_res[0]),
                        "finished_products": str(textile_res[1]),
                        "material_consumption_m": float(textile_res[2]) if textile_res[2] else 0.0
                    }
            except Exception as e:
                household_session.rollback()
                logger.warning(f"CRON: Схема texere недоступна: {e}")

            # 2.2 Утилизация по текущему месяцу
            try:
                disposition_rows = household_session.execute(text("""
                    SELECT interval_start, resource_name, resource_type, unit, 
                           device_name, uncertainty, quantity, utilized_at, 
                           disposal_point_name, disposal_point_type
                    FROM infrastructure.v_material_disposition_current_month_report;
                """)).fetchall()

                records_list = []
                for row in disposition_rows:
                    interval_start, res_name, res_type, unit, dev_name, uncertainty, qty, utilized_at, dp_name, dp_type = row
                    
                    records_list.append({
                        "interval_start": str(interval_start) if interval_start else None,
                        "resource_name": res_name,
                        "resource_type": res_type,
                        "unit": unit,
                        "device_name": dev_name,
                        "uncertainty": float(uncertainty) if uncertainty is not None else None,
                        "quantity": float(qty) if qty is not None else 0.0,
                        "utilized_at": utilized_at.strftime("%Y-%m-%d %H:%M:%S") if utilized_at else None,
                        "disposal_point_name": dp_name or "Не указан",
                        "disposal_point_type": dp_type
                    })

                recycling_metrics["disposition_records"] = records_list
                
            except Exception as e:
                household_session.rollback()
                logger.warning(f"CRON: Не удалось получить данные текущего месяца утилизации: {e}")

        finally:
            if hasattr(household_session, "close"):
                household_session.close()

    except Exception as e:
        logger.error(f"CRON Ошибка подключения к базе Household: {e}")

    # Шаг 3: Сборка и запись в единый system_report_data.json
    try:
        tz_almaty = timezone(timedelta(hours=5))
        formatted_date = datetime.now(tz_almaty).strftime("%d.%m.%Y %H:%M:%S")

        full_payload = {
            "digital": digital_metrics,
            "textile": textile_metrics,
            "recycling": recycling_metrics,
            "updated_at": formatted_date
        }

        os.makedirs(os.path.dirname(SYSTEM_REPORT_FILE), exist_ok=True)
        with open(SYSTEM_REPORT_FILE, "w", encoding="utf-8") as f:
            json.dump(full_payload, f, ensure_ascii=False, indent=4)
        logger.info("CRON: Данные успешно записаны в system_report_data.json.")

        # Вспомогательный events.json
        try:
            events_payload = {
                "transactionsCount": digital_metrics["transactions"],
                "updated_at": formatted_date
            }
            with open(EVENTS_JSON_FILE, "w", encoding="utf-8") as f:
                json.dump(events_payload, f, ensure_ascii=False, indent=4)
        except Exception as e:
            logger.error(f"CRON: Ошибка записи в events.json: {e}")

        # Шаг 4: Выполнение Git Push для отправки на GitHub
        run_git_push(f"Auto-update metrics: {formatted_date}")

        with open(LAST_RUN_FILE, "w") as f:
            f.write(str(current_time))

    except Exception as general_error:
        logger.error(f"CRON Критическая ошибка: {str(general_error)}", exc_info=True)
        raise general_error