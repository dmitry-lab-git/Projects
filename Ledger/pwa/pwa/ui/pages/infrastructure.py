import reflex as rx
from pwa.state.infrastructure import InfrastructureState
from pwa.ui.components.infrastructure_form import infrastructure_form

@rx.page(route="/infrastructure", on_load=InfrastructureState.load_resources)
def infrastructure_input_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/"),
            rx.heading("Учет материалов и ресурсов", size="7"),
            infrastructure_form(),
            spacing="4",
            padding_top="2em",
        ),
        size="2",
    )