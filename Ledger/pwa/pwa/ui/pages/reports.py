import reflex as rx
from ...state.main_state import State, ReportState, SummaryReportState  # <-- ДОБАВИЛИ SummaryReportState
from ..components.report_page import report_page, summary_report_page 

# 1. Ваша существующая страница активных счетов
@rx.page(route="/active-accounts", on_load=ReportState.load_report)
def active_accounts_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/"),
            report_page(),
        ),
    )

# 2. НОВАЯ СТРАНИЦА: Сводный отчет с группировкой по 3 сущностям
@rx.page(route="/summary-report", on_load=SummaryReportState.load_summary_report) # <-- Автозагрузка данных при старте
def summary_report_view_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/"),
            summary_report_page(), # <-- Вызов вашего нового иерархического интерфейса
        ),
    )