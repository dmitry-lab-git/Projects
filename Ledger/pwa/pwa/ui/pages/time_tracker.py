import reflex as rx
from pwa.state.time_tracker import TimeTrackerState
from pwa.ui.components.time_tracker import time_tracker_main


@rx.page(
    route="/time-tracker",
    title="Фиксация рабочего времени",
    on_load=TimeTrackerState.load_data,
)
def time_tracker_page() -> rx.Component:
    """
    Страница тайм-трекера.
    Отображает интерфейс управления интервалами времени для задач в единой таблице.
    """
    return rx.container(
        rx.box(
            rx.heading("Учет времени над задачами", size="7", margin_bottom="4"),
            rx.text(
                "Простая фиксация активности и комментариев к рабочим сессиям. Данные сохраняются локально в инфраструктурную схему.",
                color_scheme="gray",
                margin_bottom="6",
            ),
            time_tracker_main(),
            padding_y="6",
            width="100%",
        ),
        size="3",
    )
