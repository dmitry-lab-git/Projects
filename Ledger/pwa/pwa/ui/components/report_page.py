import reflex as rx
from sqlalchemy import text
from ...db import SessionLocal
from ...state.main_state import State, ReportState, SummaryReportState

def report_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.heading("Отчет по активным счетам", size="6"),
            rx.button(
                "Обновить данные", 
                on_click=ReportState.load_report, 
                color_scheme="blue"
            ),
            rx.table.root(
                rx.table.header(
                    rx.table.row(
                        rx.table.column_header_cell("ID Счета"),
                        rx.table.column_header_cell("Название счета"),
                        rx.table.column_header_cell("Направленность"),  
                        rx.table.column_header_cell("Баланс", text_align="right"),
                        rx.table.column_header_cell("Валюта"),  # <-- ДОБАВЛЕНО
                        rx.table.column_header_cell("Статус"),
                        rx.table.column_header_cell("Последнее обновление"),
                    ),
                ),
                rx.table.body(
                    rx.foreach(
                        ReportState.report_data, 
                        lambda row: rx.table.row(
                            rx.table.cell(row["account_id"], white_space="nowrap"),
                            rx.table.cell(row["account_name"], white_space="nowrap"),
                            rx.table.cell(
                                rx.box(
                                    rx.cond(
                                        row["entity_name"].to(str).length() > 22,
                                        row["entity_name"].to(str)[:22] + "...",
                                        row["entity_name"],
                                    ),
                                    max_width="160px",
                                    overflow="hidden",
                                    text_overflow="ellipsis",
                                    white_space="nowrap",
                                    title=row["entity_name"],  # Полный текст при наведении мыши
                                )
                            ),        
                            rx.table.cell(row["balance"], text_align="right", white_space="nowrap"),
                            rx.table.cell(row["currency_id"], white_space="nowrap"),  # <-- ДОБАВЛЕНО
                            rx.table.cell(
                                rx.badge(
                                    row["account_balance_status"],
                                    color_scheme=rx.cond(row["account_balance_status"] == "verified", "green", "gray"),
                                    variant="surface",
                                ),
                                white_space="nowrap",
                            ),
                            rx.table.cell(row["last_updated"], white_space="nowrap"),
                        ),
                    ),
                ),
                width="100%",
                margin_top="1em",
                style={"table-layout": "fixed"},  # Жестко фиксирует ширину колонок
            ),
            padding="2em",
        ),
    )

def summary_report_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            # 1. Заголовок и фильтр месяца
            rx.hstack(
                rx.heading("Сводка по параметрам", size="5"),
                rx.spacer(),
                rx.input(
                    type="month",
                    value=SummaryReportState.selected_month,
                    on_change=SummaryReportState.set_selected_month,
                    width="auto",
                ),
                width="100%",
                align_items="center",
                margin_bottom="0.5em",
            ),
            # 2. Итоговые метрики
            rx.hstack(
                rx.card(
                    rx.vstack(
                        rx.text("Итого расходы", size="1", color="var(--gray-10)"),
                        rx.text(
                            SummaryReportState.total_amount_str,
                            size="4",
                            weight="bold",
                        ),
                        spacing="1",
                    ),
                    width="100%",
                ),
                rx.card(
                    rx.vstack(
                        rx.text("Всего операций", size="1", color="var(--gray-10)"),
                        rx.text(
                            SummaryReportState.total_count_str,
                            size="4",
                            weight="bold",
                        ),
                        spacing="1",
                    ),
                    width="100%",
                ),
                width="100%",
                spacing="3",
                margin_bottom="1em",
            ),
            # 3. Вкладки группировки
            rx.tabs.root(
                rx.tabs.list(
                    rx.tabs.trigger("По направлениям", value="entity"),
                    rx.tabs.trigger("По партнерам", value="contragent"),
                    rx.tabs.trigger("По категориям", value="category"),
                    rx.tabs.trigger("По счетам", value="account"),
                ),
                value=SummaryReportState.current_tab,
                on_change=SummaryReportState.change_tab,
                width="100%",
            ),
            # 4. Таблица
            rx.table.root(
                rx.table.header(
                    rx.table.row(
                        rx.table.column_header_cell(SummaryReportState.first_column_header),
                        rx.table.column_header_cell(SummaryReportState.second_column_header),
                        rx.table.column_header_cell("Сумма", text_align="right"),
                        rx.table.column_header_cell("Количество", text_align="right"),
                    ),
                ),
                rx.table.body(
                    rx.foreach(
                        SummaryReportState.report_data,
                        lambda row: rx.table.row(
                            rx.table.cell(row["name"], white_space="nowrap"),
                            rx.table.cell(
                                row["attr"], 
                                white_space="nowrap", 
                                color="var(--gray-10)"
                            ),
                            rx.table.cell(
                                row["amount"],
                                text_align="right",
                                white_space="nowrap",
                                font_weight="medium",
                            ),
                            rx.table.cell(
                                row["count"],
                                text_align="right",
                                white_space="nowrap",
                                color="var(--gray-10)",
                            ),
                        ),
                    ),
                ),
                width="100%",
                margin_top="1em",
            ),
            padding="2em",
            align_items="flex-start",
            width="100%",
        ),
        max_width="1000px",
        on_mount=SummaryReportState.load_summary_report,
    )