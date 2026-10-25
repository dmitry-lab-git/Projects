import reflex as rx
from pwa.state.medicine import MedicineState
from pwa.ui.components.medicine_form import medicine_form

@rx.page(route="/medicine", on_load=MedicineState.load_medicine_data)
def medicine_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/"),
            rx.heading("Управление медициной и здоровьем", size="7"),
            medicine_form(),
            spacing="4",
            padding_top="2em",
        ),
        size="2",
    )
