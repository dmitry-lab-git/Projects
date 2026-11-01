import reflex as rx
from .ui.components.transaction_form import add_transaction_page
from .ui.pages.snapshots import snapshots_page
from .ui.pages.reports import active_accounts_page, summary_report_view_page
from .ui.pages.index import index
from .ui.pages.infrastructure import infrastructure_input_page
from .ui.pages.transaction_templates import transaction_templates_page
from .ui.pages.medicine import medicine_page
from .ui.pages.medicine_report import medicine_report_page
from .ui.pages.dictionaries import dictionaries_page
from .ui.pages.projects import projects_page
from .ui.pages.project_editor import project_editor_page
# Импорт страницы тайм-трекера для ее автоматической регистрации через декоратор @rx.page
from .ui.pages.time_tracker import time_tracker_page

from apscheduler.schedulers.background import BackgroundScheduler
import atexit

# Импорт CRON-задач
from src.services.cron.jobs.readme_updater import update_readme_metrics
# Отредактируйте путь импорта ниже, если файл metrics_updater лежит в другом месте
from src.services.cron.jobs.metrics_updater import update_pwa_dashboard_metrics

# ---- CRON (singleton чтобы не дублировался) ----
_scheduler = BackgroundScheduler(daemon=True)

# 1. Ежедневное обновление readme в полночь
_scheduler.add_job(
    update_readme_metrics, 
    'cron', 
    hour=0, 
    minute=0, 
    id="readme_metrics_daily", 
    replace_existing=True
)

# 2. Обновление метрик PWA и Git-пуш каждые 6 часов (21600 секунд)
_scheduler.add_job(
    update_pwa_dashboard_metrics, 
    'interval', 
    seconds=21600, 
    id="pwa_dashboard_metrics_interval", 
    replace_existing=True
)

# Принудительный запуск обновления PWA-метрики сразу при старте приложения, 
# чтобы не ждать 6 часов (параметр force=True игнорирует временной лок файла)
try:
    update_pwa_dashboard_metrics(force=True)
except Exception as e:
    print(f"Ошибка предварительного запуска метрик PWA: {e}")

# Старт планировщика
_scheduler.start()
atexit.register(lambda: _scheduler.shutdown())

# ---- APP (ЭТО ОБЯЗАТЕЛЬНО) ----
app = rx.App()
