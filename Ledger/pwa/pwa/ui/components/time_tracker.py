import reflex as rx
from pwa.state.time_tracker import TimeTrackerState


def timer_panel() -> rx.Component:
    """Панель управления таймером (Инпуты + Кнопка Действия)."""
    return rx.card(
        rx.flex(
            rx.input(
                placeholder="Над какой задачей вы работаете?",
                value=TimeTrackerState.current_task_name,
                on_change=TimeTrackerState.change_task_name,
                size="3",
                width="100%",
            ),
            rx.text_area(
                placeholder="Добавьте комментарий к текущему интервалу...",
                value=TimeTrackerState.current_comment,
                on_change=TimeTrackerState.change_comment,
                size="2",
                width="100%",
            ),
            rx.flex(
                rx.cond(
                    TimeTrackerState.has_active_timer,
                    rx.badge("Таймер запущен", color_scheme="tomato", variant="soft", size="2"),
                    rx.badge("Готов к запуску", color_scheme="grass", variant="soft", size="2"),
                ),
                rx.cond(
                    TimeTrackerState.has_active_timer,
                    rx.button(
                        "Стоп", 
                        color_scheme="tomato", 
                        variant="solid", 
                        size="3", 
                        on_click=TimeTrackerState.stop_timer
                    ),
                    rx.button(
                        "Старт", 
                        color_scheme="grass", 
                        variant="solid", 
                        size="3", 
                        on_click=TimeTrackerState.start_timer, 
                        is_disabled=TimeTrackerState.current_task_name == ""
                    ),
                ),
                spacing="3",
                justify="between",
                align="center",
                width="100%",
            ),
            spacing="4",
            direction="column",
        ),
        width="100%",
        style={"boxShadow": "var(--shadow-3)"},
    )


def render_log_entry(entry) -> rx.Component:
    """Шаблон отрисовки одной строки лога времени (для rx.foreach)."""
    return rx.table.row(
        rx.table.cell(rx.text(entry.task_name, font_weight="bold")),
        rx.table.cell(rx.text(entry.comment, color_scheme="gray", size="2")),
        rx.table.cell(rx.text(entry.start_time.to_string(), size="2")),
        rx.table.cell(
            rx.cond(
                entry.end_time,
                rx.text(entry.end_time.to_string(), size="2"),
                rx.text("В процессе...", color_scheme="tomato", size="2"),
            )
        ),
    )


def time_entries_log() -> rx.Component:
    """Таблица со списком зафиксированных интервалов."""
    return rx.flex(
        rx.heading("Журнал фиксации времени", size="4", margin_bottom="2px"),
        rx.cond(
            TimeTrackerState.entries.length() == 0,
            rx.center(
                rx.text(
                    "История пуста. Запустите таймер, чтобы внести первую запись.",
                    color_scheme="gray"
                ),
                padding="6",
            ),
            rx.table.root(
                rx.table.header(
                    rx.table.row(
                        rx.table.column_header_cell("Задача"),
                        rx.table.column_header_cell("Комментарий"),
                        rx.table.column_header_cell("Начало"),
                        rx.table.column_header_cell("Конец"),
                    )
                ),
                rx.table.body(
                    rx.foreach(TimeTrackerState.entries, render_log_entry)
                ),
                width="100%",
                variant="surface",
            ),
        ),
        direction="column",
        spacing="3",
        width="100%",
    )


def time_tracker_main() -> rx.Component:
    return rx.vstack(
        rx.cond(
            TimeTrackerState.error_message,
            rx.callout.root(
                rx.callout.text(TimeTrackerState.error_message), 
                color_scheme="tomato", 
                icon="info", 
                width="100%"
            ),
        ),
        timer_panel(),
        rx.divider(),
        rx.cond(
            TimeTrackerState.is_loading, 
            rx.center(rx.spinner(size="3"), padding="6"), 
            time_entries_log()
        ),
        spacing="5",
        width="100%",
    )
