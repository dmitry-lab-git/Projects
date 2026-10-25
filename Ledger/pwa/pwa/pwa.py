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

# === ЕДИНЫЙ ПОТОК КРОН (все расписание в src/services/cron/config.py) ===
from src.services.cron.scheduler import setup_cron
setup_cron()

# Инициализация приложения
app = rx.App()