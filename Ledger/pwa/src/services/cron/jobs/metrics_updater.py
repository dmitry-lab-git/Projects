import os
import time
import json
import reflex as rx
from sqlalchemy import text
import logging
from datetime import datetime, timezone, timedelta

from pwa.db import get_household_session
from .git_service import run_git_push

logger = logging.getLogger(__name__)

# Фикс: абсолютный путь к файлу блокировки
LAST_RUN_FILE = "/home/fujitsu-u745/Projects/.pwa_metrics_last_run"
MIN_INTERVAL_SEC = 21600  # 6 часов для обычных запусков
GIT_DEBOUNCE_SEC = 90     # 90 сек защита от дублей

SYSTEM_REPORT_FILE = "/home/fujitsu-u745/Projects/digital_living_room/system_report_data.json"
EVENTS_JSON_FILE = "/home/fujitsu-u745/Projects/digital_living_room/events.json"

def fetch_version(session):
    try:
        res = session.execute(text("""
            SELECT current_ver, current_uvr, registration_date 
            FROM reports.version_registry_report LIMIT 1;
        """)).fetchone()
        if res:
            return {
                "ver": res[0] or "VER-???",
                "uvr": res[1] or "UVR-???",
                "date": str(res[2]) if res[2] else ""
            }
    except Exception as e:
        logger.warning(f"CRON: Не удалось получить версию из reports.version_registry_report: {e}")
    return {"ver": "VER-???", "uvr": "UVR-???", "date": ""}

def update_pwa_dashboard_metrics(force: bool = False):
    current_time = time.time()
    
    # --- ЗАЩИТА ОТ ДУБЛЕЙ ---
    if os.path.exists(LAST_RUN_FILE):
        with open(LAST_RUN_FILE, "r") as f:
            try:
                last_run = float(f.read().strip())
                interval = GIT_DEBOUNCE_SEC if force else MIN_INTERVAL_SEC
                elapsed = current_time - last_run
                if elapsed < interval:
                    logger.info(f"CRON: скип обновления, прошло только {elapsed:.0f}с < {interval}с (force={force})")
                    return
            except ValueError:
                pass

    logger.info(f"CRON: Запуск обновления метрик (force={force})...")
    
    # Инициализация дефолтных значений
    digital_metrics = {"transactions": "0", "balance_snapshots": "0", "verified_states": "0", "pwa_staging_flow": "0"}
    textile_metrics = {"projects_implemented": "0", "finished_products": "0", "material_consumption_m": 0.0}
    repair_metrics = {"total_projects": "0", "completed_projects": "0", "planning_projects": "0", "outsourced_count": "0", "outsource_share_percent": "0.0", "disposed_count": "0"}
    gardening_metrics = {"total_flowers": 0, "flowering_count": 0, "seeds_germinating": 0, "free_const_boxes_count": 0, "free_seedling_boxes_count": 0, "free_transplant_boxes_count": 0, "active_alerts_count": 0}
    version_data = {"ver": "VER-???", "uvr": "UVR-???", "date": ""}
    
    current_month_str = datetime.now().strftime("%B %Y")
    recycling_metrics = {
        "period": current_month_str,
        "disposition_records": []
    }

    # --- ШАГ 1: Чтение Digital (Ledger БД) и версии ---
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

            # Получение актуальной версии из схемы reports
            version_data = fetch_version(ledger_session)

    except Exception as e:
        logger.error(f"CRON Ошибка Ledger / версии: {str(e)}")

    # --- ШАГ 2: Обращение к Household БД ---
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

            # 2.2 Repair & DIY
            try:
                repair_res = household_session.execute(text("""
                    SELECT total_projects, completed_projects, planning_projects, 
                           outsourced_count, outsource_share_percent, disposed_count
                    FROM repair.v_project_consolidated_report LIMIT 1;
                """)).fetchone()
                
                if repair_res:
                    repair_metrics = {
                        "total_projects": str(repair_res[0]),
                        "completed_projects": str(repair_res[1]),
                        "planning_projects": str(repair_res[2]),
                        "outsourced_count": str(repair_res[3]),
                        "outsource_share_percent": str(repair_res[4]),
                        "disposed_count": str(repair_res[5])
                    }
            except Exception as e:
                household_session.rollback()
                logger.warning(f"CRON: Представление repair.v_project_consolidated_report недоступно: {e}")

            # 2.3 Gardening
            try:
                gardening_res = household_session.execute(text("""
                    SELECT total_flowers, flowering_count, seeds_germinating, 
                           free_const_boxes_count, free_seedling_boxes_count, 
                           free_transplant_boxes_count, active_alerts_count
                    FROM gardening.v_gardening_dashboard LIMIT 1;
                """)).fetchone()
                
                if gardening_res:
                    gardening_metrics = {
                        "total_flowers": int(gardening_res[0]),
                        "flowering_count": int(gardening_res[1]),
                        "seeds_germinating": int(gardening_res[2]),
                        "free_const_boxes_count": int(gardening_res[3]),
                        "free_seedling_boxes_count": int(gardening_res[4]),
                        "free_transplant_boxes_count": int(gardening_res[5]),
                        "active_alerts_count": int(gardening_res[6])
                    }
            except Exception as e:
                household_session.rollback()
                logger.warning(f"CRON: Представление gardening.v_gardening_dashboard недоступно: {e}")

            # 2.4 Утилизация по текущему месяцу
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

        except Exception as inner_db_error:
            logger.error(f"CRON: Внутренняя ошибка выполнения запросов в Household БД: {inner_db_error}")

        finally:
            if hasattr(household_session, "close"):
                household_session.close()

    except Exception as e:
        logger.error(f"CRON Ошибка подключения к базе Household: {e}")

    # --- ШАГ 3: Сборка и запись файлов ---
    try:
        tz_almaty = timezone(timedelta(hours=5))
        formatted_date = datetime.now(tz_almaty).strftime("%d.%m.%Y %H:%M:%S")

        full_payload = {
            "digital": digital_metrics,
            "textile": textile_metrics,
            "repair": repair_metrics,
            "gardening": gardening_metrics,
            "recycling": recycling_metrics,
            "version": version_data,
            "updated_at": formatted_date
        }

        # Проверка хеша контента (пропуск пуша, если данные не изменились)
        old_content = ""
        if os.path.exists(SYSTEM_REPORT_FILE):
            with open(SYSTEM_REPORT_FILE, "r", encoding="utf-8") as f_old:
                old_content = f_old.read()
        
        old_hash = hash(old_content)
        new_hash = hash(json.dumps(full_payload, sort_keys=True))

        if old_hash == new_hash:
            logger.info("CRON: Данные метрик не изменились, пропуск сохранения и пуша.")
            with open(LAST_RUN_FILE, "w") as f_lr:
                f_lr.write(str(current_time))
            return

        # Запись system_report_data.json
        os.makedirs(os.path.dirname(SYSTEM_REPORT_FILE), exist_ok=True)
        with open(SYSTEM_REPORT_FILE, "w", encoding="utf-8") as f:
            json.dump(full_payload, f, ensure_ascii=False, indent=4)
        logger.info("CRON: Данные успешно записаны в system_report_data.json.")

        # Запись events.json
        try:
            events_payload = {
                "transactionsCount": digital_metrics["transactions"],
                "updated_at": formatted_date
            }
            with open(EVENTS_JSON_FILE, "w", encoding="utf-8") as f_ev:
                json.dump(events_payload, f_ev, ensure_ascii=False, indent=4)
            logger.info("CRON: Данные успешно записаны в events.json.")
        except Exception as e:
            logger.error(f"CRON: Ошибка записи в events.json: {e}")

        # --- ШАГ 4: Git Push с предварительным pull --rebase ---
        pushed = run_git_push(
            files_to_add=[
                "digital_living_room/system_report_data.json",
                "digital_living_room/events.json"
            ],
            commit_message=f"Auto-update metrics: {formatted_date}"
        )
        if pushed:
            with open(LAST_RUN_FILE, "w") as f_lr:
                f_lr.write(str(current_time))
            logger.info("CRON: Git push выполнен успешно, LAST_RUN обновлен.")
        else:
            logger.warning("CRON: Пуш не удался, LAST_RUN не обновляем для ретрая")
            
    except Exception as general_error:
        logger.error(f"CRON Критическая ошибка: {str(general_error)}", exc_info=True)
        raise general_error