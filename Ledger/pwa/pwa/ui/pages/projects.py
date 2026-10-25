import reflex as rx
from pwa.state.projects import ProjectsState
from pwa.ui.components.projects import projects_component
@rx.page(route="/projects", on_load=ProjectsState.load_projects_data)
def projects_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.hstack(
            rx.link("← Назад в меню", href="/"),
                rx.spacer(),
                rx.link(
                    rx.button("✏️ Редактор проектов", variant="soft", size="2"),
                    href="/projects/editor",
        ),
                width="100%",
            ),
            rx.heading("Кросс-базовый реестр проектов", size="7"),
            projects_component(),
            spacing="4",
            padding_top="2em",
        ),
        size="4",
    )