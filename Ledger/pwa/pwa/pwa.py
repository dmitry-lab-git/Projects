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

from apscheduler.schedulers.background import BackgroundScheduler
from src.services.cron.jobs.readme_updater import update_readme_metrics
import atexit

# ---- CRON (singleton чтобы не дублировался) ----
_scheduler = BackgroundScheduler(daemon=True)
_scheduler.add_job(update_readme_metrics, 'cron', hour=0, minute=0, id="readme_metrics_daily", replace_existing=True)
_scheduler.start()
atexit.register(lambda: _scheduler.shutdown())

# ---- APP (ЭТО ОБЯЗАТЕЛЬНО) ----
app = rx.App()