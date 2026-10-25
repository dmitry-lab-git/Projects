import reflex as rx
from pwa.state.medicine_report import MedicineReportState

COLS = {
    "prep": "32%", 
    "brand": "10%", 
    "oct_taken": "13%", 
    "oct_days": "6%", 
    "oct_dose": "9%", 
    "sep_taken": "13%", 
    "sep_days": "6%", 
    "sep_dose": "9%"
}

def get_status_badge(row: rx.Var[dict]) -> rx.Component:
    return rx.match(
        row['badge_type'],
        ("active", rx.badge("Активен", color_scheme="green", variant="solid")),
        ("completed", rx.badge("Завершен", color_scheme="gray", variant="soft")),
        rx.badge("Без схемы", color_scheme="gray", variant="outline")
    )

def render_taken_cell(fact: rx.Var[int], unit_form: rx.Var[str], active_days: rx.Var[int], compliance: rx.Var[int], badge_type: rx.Var[str], color_scheme: str) -> rx.Component:
    return rx.cond(
        (badge_type == "active") & (active_days == 0),
        rx.vstack(
            rx.badge("Схема не активна", color_scheme="gray", variant="soft"),
            rx.text("—", size="2", color="gray"),
            align="center", spacing="1"
        ),
        rx.cond(
            (badge_type == "no_schedule") | (badge_type == "completed"),
            rx.vstack(
                rx.badge(f"{fact} {unit_form}", color_scheme="gray", variant="soft"),
                align="start", spacing="1"
            ),
            rx.vstack(
                rx.badge(f"{fact} {unit_form}", color_scheme=color_scheme, variant="soft"),
                rx.progress(value=compliance, color_scheme=color_scheme, width="100%"),
                rx.text(f"{compliance}%", size="1", font_weight="bold"),
                spacing="1", width="100%"
            )
        )
    )

def tab_current_status_row(row: rx.Var[dict]) -> rx.Component:
    return rx.table.row(
        rx.table.cell(
            rx.vstack(
                rx.text(row['supplement_name'], font_weight="semibold", size="3"),
                get_status_badge(row),
                spacing="1"
            ),
            width=COLS["prep"], vertical_align="top"
        ),
        rx.table.cell(row['brand'], width=COLS["brand"], vertical_align="middle"),
        
        # Октябрь 2026
        rx.table.cell(
            render_taken_cell(row['m1_fact'], row['m1_unit_form'], row['m1_active_days'], row['m1_compliance'], row['badge_type'], "green"),
            width=COLS["oct_taken"], vertical_align="top"
        ),
        rx.table.cell(row['m1_days_str'], width=COLS["oct_days"], vertical_align="middle"),
        rx.table.cell(
            rx.text(row['m1_dose_str'], title=row['m1_dose_tooltip'], white_space="nowrap", font_size="13px"),
            width=COLS["oct_dose"], vertical_align="middle"
        ),
        
        # Сентябрь 2026
        rx.table.cell(
            render_taken_cell(row['m2_fact'], row['m2_unit_form'], row['m2_active_days'], row['m2_compliance'], row['badge_type'], "blue"),
            width=COLS["sep_taken"], vertical_align="top"
        ),
        rx.table.cell(row['m2_days_str'], width=COLS["sep_days"], vertical_align="middle"),
        rx.table.cell(
            rx.text(row['m2_dose_str'], title=row['m2_dose_tooltip'], white_space="nowrap", font_size="13px"),
            width=COLS["sep_dose"], vertical_align="middle"
        ),
        
        style=rx.cond(
            row['badge_type'] == 'completed',
            {"opacity": 0.6},
            {}
        )
    )

@rx.page(route="/medicine-report", on_load=MedicineReportState.on_mount)
def medicine_report_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/", color_scheme="gray", underline="none"),
            rx.heading("Аналитика приема нутрицевтиков", size="8", weight="bold"),
            
            rx.tabs.root(
                rx.tabs.list(
                    rx.tabs.trigger("Текущий статус (2 мес)", value="current"),
                    rx.tabs.trigger("Актуальные схемы", value="schemes"),
                    rx.tabs.trigger("Архив за период", value="archive"),
                ),
                
                # Вкладка 2: Текущий статус (Главная)
                rx.tabs.content(
                    rx.vstack(
                        rx.box(
                            rx.text(
                                "Оперативный контроль программ приема за текущий и прошлый календарные периоды.",
                                color="gray.500",
                                font_size="13px",
                                font_weight="400",
                            ),
                            margin_top="16px",
                            margin_bottom="20px",
                            padding_left="2px",
                        ),
                        rx.cond(
                            (MedicineReportState.current_active.length() == 0) & (MedicineReportState.current_completed.length() == 0),
                            rx.center(rx.text("Нет активных программ или приемов за этот период", color="gray"), padding="3em", width="100%"),
                            rx.vstack(
                                rx.table.root(
                                    rx.table.header(
                                        rx.table.row(
                                            rx.table.column_header_cell("Препарат", width=COLS["prep"]),
                                            rx.table.column_header_cell("Бренд", width=COLS["brand"]),
                                            rx.table.column_header_cell(MedicineReportState.month1_label, col_span=3, text_align="center", background="green.2", width="28%"),
                                            rx.table.column_header_cell(MedicineReportState.month2_label, col_span=3, text_align="center", background="blue.2", width="28%"),
                                        ),
                                        rx.table.row(
                                            rx.table.column_header_cell(""),
                                            rx.table.column_header_cell(""),
                                            rx.table.column_header_cell("Принято", width=COLS["oct_taken"]),
                                            rx.table.column_header_cell("Дней", width=COLS["oct_days"]),
                                            rx.table.column_header_cell("Доза", width=COLS["oct_dose"]),
                                            rx.table.column_header_cell("Принято", width=COLS["sep_taken"]),
                                            rx.table.column_header_cell("Дней", width=COLS["sep_days"]),
                                            rx.table.column_header_cell("Доза", width=COLS["sep_dose"]),
                                        ),
                                        position="sticky", top="0", z_index="10"
                                    ),
                                    rx.table.body(
                                        rx.foreach(MedicineReportState.current_active, tab_current_status_row)
                                    ),
                                    width="100%", variant="surface", size="3"
                                ),
                                rx.cond(
                                    MedicineReportState.current_completed.length() > 0,
                                    rx.vstack(
                                        rx.divider(),
                                        rx.heading("Завершенные курсы", size="3", color="gray"),
                                        rx.table.root(
                                            rx.table.body(
                                                rx.foreach(MedicineReportState.current_completed, tab_current_status_row)
                                            ),
                                            width="100%", variant="surface", size="3"
                                        ),
                                        spacing="3",
                                        padding_top="4",
                                        width="100%"
                                    )
                                ),
                                spacing="4",
                                width="100%"
                            )
                        ),
                        spacing="4",
                        align="stretch",
                        width="100%"
                    ),
                    value="current",
                ),

                # Вкладка 1: Актуальные схемы
                rx.tabs.content(
                    rx.vstack(
                        rx.text(
                            "Протокол приема на текущий момент. Что, когда и сколько пить сегодня.", 
                            color_scheme="gray", size="2", padding_y="1"
                        ),
                        rx.cond(
                            MedicineReportState.active_schemes_rows.length() == 0,
                            rx.center(rx.text("Нет активных схем приема", color="gray"), padding="3em", width="100%"),
                            rx.table.root(
                                rx.table.header(
                                    rx.table.row(
                                        rx.table.column_header_cell("Препарат"),
                                        rx.table.column_header_cell("Бренд"),
                                        rx.table.column_header_cell("Курс"),
                                        rx.table.column_header_cell("Доза / день"),
                                        rx.table.column_header_cell("Дата начала / конца"),
                                    ),
                                    position="sticky", top="0", z_index="10"
                                ),
                                rx.table.body(
                                    rx.foreach(MedicineReportState.active_schemes_rows, lambda row: rx.table.row(
                                        rx.table.cell(rx.text(row["supplement_name"], font_weight="semibold", size="3"), vertical_align="middle"),
                                        rx.table.cell(row["brand"], vertical_align="middle"),
                                        rx.table.cell(row["course_str"], vertical_align="middle"),
                                        rx.table.cell(row["dose_str"], vertical_align="middle"),
                                        rx.table.cell(row["date_range"], vertical_align="middle"),
                                    ))
                                ),
                                width="100%", variant="surface", size="3"
                            )
                        ),
                        spacing="3", width="100%"
                    ),
                    value="schemes",
                ),
                
                # Вкладка 3: Архив за период
                rx.tabs.content(
                    rx.vstack(
                        rx.card(
                            rx.vstack(
                                rx.text("Настройка исторического диапазона:", font_weight="bold", size="3"),
                                rx.hstack(
                                    rx.vstack(
                                        rx.text("Начало периода", size="1", color_scheme="gray"),
                                        rx.input(type="date", value=MedicineReportState.start_date, on_change=MedicineReportState.set_start_date)
                                    ),
                                    rx.vstack(
                                        rx.text("Конец периода", size="1", color_scheme="gray"),
                                        rx.input(type="date", value=MedicineReportState.end_date, on_change=MedicineReportState.set_end_date)
                                    ),
                                    rx.button("Сформировать", color_scheme="blue", margin_top="auto", on_click=MedicineReportState.fetch_archive),
                                    spacing="4", align="end"
                                ),
                                spacing="2"
                            ),
                            width="100%"
                        ),
                        rx.table.root(
                            rx.table.header(
                                rx.table.row(
                                    rx.table.column_header_cell("Препарат"),
                                    rx.table.column_header_cell("Бренд"),
                                    rx.table.column_header_cell("Всего принято"),
                                    rx.table.column_header_cell("Дней приема"),
                                    rx.table.column_header_cell("Средняя доза"),
                                )
                            ),
                            rx.table.body(
                                rx.cond(
                                    MedicineReportState.archive_rows.length() == 0,
                                    rx.table.row(
                                        rx.table.cell("Выберите диапазон дат и нажмите кнопку «Сформировать»", font_style="italic", color="gray", col_span=5, align="center")
                                    ),
                                    rx.foreach(MedicineReportState.archive_rows, lambda row: rx.table.row(
                                        rx.table.cell(row["supplement_name"], font_weight="medium"),
                                        rx.table.cell(row["brand"]),
                                        rx.table.cell(rx.badge(row['total_amount'], color_scheme="purple", variant="soft")),
                                        rx.table.cell(row['days_count']),
                                        rx.table.cell(row["average_dose"]),
                                    ))
                                )
                            ),
                            width="100%", variant="surface"
                        ),
                        spacing="4", width="100%"
                    ),
                    value="archive",
                ),
                width="100%",
                default_value="current"
            ),
            
            # Аккордеон
            rx.accordion.root(
                rx.accordion.item(
                    rx.accordion.header(
                        rx.accordion.trigger(
                            rx.text("Как устроен отчет", weight="bold", size="3"),
                            rx.accordion.icon(),
                            justify="between",
                            width="100%",
                        ),
                    ),
                    rx.accordion.content(
                        rx.vstack(
                            rx.markdown("""
**Как устроен отчет**

**Что такое схема?** 
План приема, который вы задаете сами. У схемы есть дата начала и дата конца. Устанавливает норму в день.

**Куда смотреть:**
* **Ежедневно** — Вкладка 2 "Текущий статус". Факт + оценка выполнения.
* **Проверить план** — Вкладка 1 "Актуальные схемы". Что должны пить сейчас.
* **История** — Вкладка 3 "Архив". Только факты.

**Столбцы:** 
* **Принято** — факт, количество.
* **Дней** — дни, когда принята хотя бы 1 ед.
* **Доза** — норма в сутки.

**Статусы:**
* **Активен** — есть действующая схема.
* **Без схемы** — принимали без плана.
* **Завершен** — схема закончилась.

**Проценты:**
Только для статуса *Активен*. 
Формула: 
Факт / (Доза × Активных дней) × 100, где *Активных дней* — количество дней от начала схемы до сегодня в пределах месяца.
                            """),
                            padding="4"
                        )
                    ),
                    value="how-it-works",
                ),
                type="single",
                collapsible=True,
                default_value="how-it-works",
                variant="soft",
                color_scheme="gray",
                width="100%",
                margin_top="8",
            ),
            
            spacing="5",
            padding_top="1em",
            width="100%"
        ),
        size="4"
    )