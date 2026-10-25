import reflex as rx
# Импортируем страницы
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

from apscheduler.schedulers.background import BackgroundScheduler
from .services.readme_updater import update_readme_metrics
import atexit

scheduler = BackgroundScheduler(daemon=True)
if not scheduler.get_jobs():
    scheduler.add_job(update_readme_metrics, 'cron', hour=0, minute=0, id="readme_metrics_daily", replace_existing=True)
    scheduler.start()
    atexit.register(lambda: scheduler.shutdown())

# Инициализация приложения
app = rx.App()
