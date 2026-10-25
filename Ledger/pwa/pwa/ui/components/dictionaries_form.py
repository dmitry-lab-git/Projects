import reflex as rx
from pwa.state.dictionaries import DictionariesState


def dictionaries_form() -> rx.Component:
    return rx.vstack(
        # 1. Форма и таблица: Адреса
        rx.card(
            rx.vstack(
                rx.heading("Справочник адресов", size="4"),
                rx.form.root(
                    rx.vstack(
                        rx.input(placeholder="Наименование адреса", name="address_name", required=True),
                        rx.input(placeholder="Город", name="city", default_value="Павлодар"),
                        rx.input(placeholder="Страна", name="country", default_value="Казахстан"),
                        rx.button("Добавить адрес", type="submit"),
                    ),
                    on_submit=DictionariesState.add_address,
                    reset_on_submit=True,
                ),
                rx.divider(),
                rx.heading("Существующие адреса", size="3"),
                rx.scroll_area(
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Наименование"),
                                rx.table.column_header_cell("Город"),
                                rx.table.column_header_cell("Страна"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                DictionariesState.addresses,
                                lambda row: rx.table.row(
                                    rx.table.cell(row["address_name"], white_space="nowrap"),
                                    rx.table.cell(row["city"], white_space="nowrap"),
                                    rx.table.cell(row["country"], white_space="nowrap"),
                                ),
                            ),
                        ),
                        width="100%",
                    ),
                    max_height="250px",
                    width="100%",
                ),
                spacing="3",
            ),
            width="100%",
        ),

        # 2. Форма и таблица: Мерчанты
        rx.card(
            rx.vstack(
                rx.heading("Справочник мерчантов", size="4"),
                rx.form.root(
                    rx.vstack(
                        rx.input(placeholder="Наименование мерчанта", name="merchant_name", required=True),
                        rx.button("Добавить мерчанта", type="submit"),
                    ),
                    on_submit=DictionariesState.add_merchant,
                    reset_on_submit=True,
                ),
                rx.divider(),
                rx.heading("Существующие мерчанты", size="3"),
                rx.scroll_area(
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Наименование мерчанта"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                DictionariesState.merchants,
                                lambda row: rx.table.row(
                                    rx.table.cell(row["merchant_name"], white_space="nowrap"),
                                ),
                            ),
                        ),
                        width="100%",
                    ),
                    max_height="250px",
                    width="100%",
                ),
                spacing="3",
            ),
            width="100%",
        ),

        # 3. Форма и таблица: Контрагенты
        rx.card(
            rx.vstack(
                rx.heading("Справочник контрагентов", size="4"),
                rx.form.root(
                    rx.vstack(
                        rx.input(placeholder="Наименование контрагента", name="contragent_name", required=True),
                        rx.select(
                            ["Физическое лицо", "Юридическое лицо"],
                            name="contragent_type",
                            default_value="Физическое лицо",
                            placeholder="Тип контрагента...",
                            width="100%",
                        ),
                        rx.select(
                            DictionariesState.address_names,
                            value=DictionariesState.selected_address_name,
                            on_change=DictionariesState.set_selected_address_name,
                            placeholder="Выберите адрес...",
                            width="100%",
                        ),
                        rx.select(
                            DictionariesState.merchant_names,
                            value=DictionariesState.selected_merchant_name,
                            on_change=DictionariesState.set_selected_merchant_name,
                            placeholder="Выберите мерчанта...",
            width="100%",
        ),
                        rx.input(placeholder="Описание", name="description"),
                        rx.button("Добавить контрагента", type="submit"),
                    ),
                    on_submit=DictionariesState.add_contragent,
                ),
                spacing="3",
                ),
                width="100%",
            ),

        rx.divider(margin_y="1em"),

        # 4. Список контрагентов (последние 50)
        rx.heading("Список контрагентов (последние 50)", size="4"),
        rx.scroll_area(
            rx.table.root(
                rx.table.header(
                    rx.table.row(
                        rx.table.column_header_cell("Имя"),
                        rx.table.column_header_cell("Тип"),
                        rx.table.column_header_cell("Адрес"),
                        rx.table.column_header_cell("Мерчант"),
                        rx.table.column_header_cell("Описание"),
                    ),
                ),
                rx.table.body(
                    rx.foreach(
                        DictionariesState.contragents,
                        lambda row: rx.table.row(
                            rx.table.cell(row["contragent_name"], white_space="nowrap"),
                            rx.table.cell(row["contragent_type"], white_space="nowrap"),
                            rx.table.cell(row["address_name"], white_space="nowrap"),
                            rx.table.cell(row["merchant_name"], white_space="nowrap"),
                            rx.table.cell(row["description"]),
                        ),
                    ),
                ),
                width="100%",
            ),
            max_height="350px",
            width="100%",
        ),

        spacing="4",
        width="100%",
    )

