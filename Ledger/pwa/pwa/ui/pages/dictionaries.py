import reflex as rx
from pwa.state.dictionaries import DictionariesState
from pwa.ui.components.dictionaries_form import dictionaries_form

@rx.page(route="/dictionaries", on_load=DictionariesState.load_dictionaries)
def dictionaries_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/"),
            rx.heading("Управление справочниками (Адреса, Мерчанты, Контрагенты)", size="7"),
            dictionaries_form(),
            spacing="4",
            padding_top="2em",
        ),
        size="2",
    )
