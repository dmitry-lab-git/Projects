import reflex as rx


def main_menu() -> rx.Component:
    return rx.hstack(
        rx.link(
            rx.button("Новая транзакция", variant="outline"),
            href="/new-transaction",
        ),
        rx.link(
            rx.button("Справочники", variant="outline"),
            href="/dictionaries",
        ),
        rx.link(
            rx.button("Снимки баланса", variant="outline"), href="/snapshots"
        ),
        rx.link(
            rx.button("Активные счета", variant="outline"),
            href="/active-accounts",
        ),
        rx.link(
            rx.button("Шаблоны транзакций", variant="outline"),
            href="/transaction-templates",
        ),
        rx.link(
            rx.button("Сводка по параметрам", variant="outline"),
            href="/summary-report",
        ),
        justify="start",
        spacing="3",
        wrap="wrap",
        width="100%",
    )


def household_menu() -> rx.Component:
    return rx.hstack(
        rx.link(
            rx.button("Утилизация отходов", variant="outline"),
            href="/infrastructure",
        ),
        justify="start",
        spacing="3",
        wrap="wrap",
        width="100%",
    )


def medicine_menu() -> rx.Component:
    return rx.hstack(
        rx.link(
            rx.button("Управление медициной", variant="outline"),
            href="/medicine",
        ),
        justify="start",
        spacing="3",
        wrap="wrap",
        width="100%",
    )


def projects_menu() -> rx.Component:
    return rx.hstack(
        rx.link(
            rx.button("Реестр проектов (Cross-DB)", variant="outline"),
            href="/projects",
        ),
        justify="start",
        spacing="3",
        wrap="wrap",
        width="100%",
    )


@rx.page(route="/")
def index() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.heading("Ledger PWA - Главное меню", size="6"),
            main_menu(),
            rx.divider(margin_y="1em"),
            rx.heading("Household PWA - Главное меню", size="6"),
            household_menu(),
            rx.divider(margin_y="1em"),
            rx.heading("Medicine PWA - Главное меню", size="6"),
            medicine_menu(),
            rx.divider(margin_y="1em"),
            rx.heading("Projects PWA - Главное меню", size="6"),
            projects_menu(),
            align_items="start",
            padding="2em",
            spacing="3",
            width="100%",
        ),
        max_width="900px",
    )

