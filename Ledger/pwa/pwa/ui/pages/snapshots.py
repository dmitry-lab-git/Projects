# pwa/ui/pages/snapshots.py
import reflex as rx
from ...state.main_state import State, SnapshotRegisterState 
from ..components.snapshot_page import snapshot_tab_view

# Страница снимков баланса
@rx.page(route="/snapshots", on_load=SnapshotRegisterState.load_snapshots)
def snapshots_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/"),
            rx.heading("Запись состояния баланса", size="7"),
            snapshot_tab_view(),
            spacing="4",
            padding_top="2em",
        ),
        size="2",
    )