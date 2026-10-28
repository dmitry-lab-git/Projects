import reflex as rx
from pwa.state.dictionaries import DictionariesState


def dictionaries_form() -> rx.Component:
    return rx.vstack(
        # 1. Форма и таблица: Адреса
        rx.card(
            rx.vstack(
                rx.heading("Справочник адресов", size="4"),
                
                # Аккуратный двухколоночный макет
                rx.flex(
                    # Левая часть — форма ввода
                    rx.form.root(
                        rx.vstack(
                            rx.input(placeholder="Наименование адреса", name="address_name", required=True, width="100%"),
                            rx.input(placeholder="Город", name="city", default_value="Павлодар", width="100%"),
                            rx.input(placeholder="Страна", name="country", default_value="Казахстан", width="100%"),
                            rx.button("Добавить адрес", type="submit", width="100%", color_scheme="blue"),
                            spacing="3",
                            width="100%",
                        ),
                        on_submit=DictionariesState.add_address,
                        reset_on_submit=True,
                        width="100%",
                    ),
                    
                    # Правая часть — памятка регламента
                    rx.box(
                        rx.vstack(
                            rx.text("📋 Регламент адреса:", font_weight="bold", size="3", color="#1f2937", margin_bottom="4px"),
                            rx.vstack(
                                rx.text("• Начало со строчных: ул. / пр. / пер. / мкр.", size="2", color="#4b5563"),
                                rx.text("• Обязательно запятая перед номером дома", size="2", color="#4b5563"),
                                rx.text("• Исключить слова 'дом', 'д.', 'здание'", size="2", color="#4b5563"),
                                rx.text("• Ориентиры и ТД пишутся строго в конце", size="2", color="#4b5563"),
                                spacing="1",
                                align_items="start",
                            ),
                            rx.box(
                                rx.vstack(
                                    rx.text("💡 Пример ввода:", font_weight="bold", size="1", color="#166534"),
                                    rx.text("ул. Машхур Жусупа, 6, рядом со Швейным Домом", font_style="italic", size="1", color="#166534"),
                                    spacing="1",
                                    align_items="start",
                                ),
                                background_color="#f0fdf4",
                                border="1px solid #bbf7d0",
                                padding="8px 12px",
                                border_radius="6px",
                                width="100%",
                                margin_top="8px",
                            ),
                            spacing="2",
                            align_items="start",
                        ),
                        background_color="#f9fafb",
                        padding="16px",
                        border_radius="8px",
                        border="1px solid #e5e7eb",
                        min_width="320px",
                        width="100%",
                    ),
                    direction={"sm": "column", "md": "row"},
                    spacing="5",
                    align_items="stretch",
                    width="100%",
                ),
                
                rx.divider(),
                
                # Последние 5 адресов
                rx.flex(
                    rx.heading("Последние 5 адресов", size="3"),
                    rx.button(
                        "Обновить", 
                        size="1", 
                        variant="outline", 
                        color_scheme="gray", 
                        on_click=DictionariesState.load_dictionaries, 
                        cursor="pointer"
                    ),
                    justify="between",
                    align="center",
                    width="100%",
                    margin_bottom="2px"
                ),
                rx.scroll_area(
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Code"),
                                rx.table.column_header_cell("Адрес"),
                                rx.table.column_header_cell("Created_at"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                DictionariesState.addresses[:5],
                                lambda row: rx.table.row(
                                    rx.table.cell(row["code"]),
                                    rx.table.cell(row["address_name"], white_space="nowrap"),
                                    rx.table.cell(row["created_at"]),
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
                        rx.input(placeholder="Наименование мерчанта", name="merchant_name", required=True, width="100%"),
                        rx.button("Добавить мерчанта", type="submit", width="100%", color_scheme="blue"),
                        spacing="3",
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
                rx.flex(
                    rx.heading("Справочник контрагентов", size="4"),
                    rx.button(
                        "Обновить справочники", 
                        size="1", 
                        variant="outline", 
                        color_scheme="gray", 
                        on_click=DictionariesState.load_dictionaries, 
                        cursor="pointer"
                    ),
                    justify="between",
                    align="center",
                    width="100%",
                    margin_bottom="2px"
                ),
                rx.form.root(
                    rx.vstack(
                        rx.input(placeholder="Наименование контрагента", name="contragent_name", required=True, width="100%"),
                        rx.select(
                            ["Физическое лицо", "Юридическое лицо"],
                            name="contragent_type",
                            default_value="Физическое лицо",
                            placeholder="Тип контрагента...",
                            width="100%",
                        ),
                        rx.select(
                            DictionariesState.address_options,
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
                        rx.input(placeholder="Описание", name="description", width="100%"),
                        rx.button("Добавить контрагента", type="submit", width="100%", color_scheme="blue"),
                        spacing="3",
                    ),
                    on_submit=DictionariesState.add_contragent,
                    reset_on_submit=True,
                ),
                rx.divider(),
                rx.heading("Последние 5 контрагентов", size="3"),
                rx.scroll_area(
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Code"),
                                rx.table.column_header_cell("Name"),
                                rx.table.column_header_cell("Type"),
                                rx.table.column_header_cell("Address"),
                                rx.table.column_header_cell("Created_at"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                DictionariesState.contragents[:5],
                                lambda row: rx.table.row(
                                    rx.table.cell(row["code"]),
                                    rx.table.cell(row["contragent_name"], white_space="nowrap"),
                                    rx.table.cell(row["contragent_type"], white_space="nowrap"),
                                    rx.table.cell(row["address_name"], white_space="nowrap"),
                                    rx.table.cell(row["created_at"]),
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

        # 4. Форма и таблица: Категории
        rx.card(
            rx.vstack(
                rx.flex(
                    rx.heading("Справочник категорий", size="4"),
                    rx.button(
                        "Обновить справочники", 
                        size="1", 
                        variant="outline", 
                        color_scheme="gray", 
                        on_click=DictionariesState.load_dictionaries, 
                        cursor="pointer"
                    ),
                    justify="between",
                    align="center",
                    width="100%",
                    margin_bottom="2px"
                ),
                rx.form.root(
                    rx.vstack(
                        rx.input(placeholder="Наименование категории", name="category_name", required=True, width="100%"),
                        rx.select(
                            DictionariesState.category_options,
                            value=DictionariesState.selected_parent_category_name,
                            on_change=DictionariesState.set_selected_parent_category_name,
                            placeholder="Родительская категория (необязательно)...",
                            width="100%",
                        ),
                        rx.button("Добавить категорию", type="submit", width="100%", color_scheme="blue"),
                        spacing="3",
                    ),
                    on_submit=DictionariesState.add_category,
                    reset_on_submit=True,
                ),
                rx.divider(),
                rx.heading("Последние 5 категорий", size="3"),
                rx.scroll_area(
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Code"),
                                rx.table.column_header_cell("Category ID"),
                                rx.table.column_header_cell("Наименование"),
                                rx.table.column_header_cell("Родитель"),
                                rx.table.column_header_cell("Created_at"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                DictionariesState.categories[:5],
                                lambda row: rx.table.row(
                                    rx.table.cell(row["code"]),
                                    rx.table.cell(row["category_id"], white_space="nowrap"),
                                    rx.table.cell(row["category_name"], white_space="nowrap"),
                                    rx.table.cell(row["parent_category_id"], white_space="nowrap"),
                                    rx.table.cell(row["created_at"]),
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

        # 5. Форма и таблица: Направленности (Entities)
        rx.card(
            rx.vstack(
                rx.flex(
                    rx.heading("Справочник направленностей (Entities)", size="4"),
                    rx.button(
                        "Обновить справочники", 
                        size="1", 
                        variant="outline", 
                        color_scheme="gray", 
                        on_click=DictionariesState.load_dictionaries, 
                        cursor="pointer"
                    ),
                    justify="between",
                    align="center",
                    width="100%",
                    margin_bottom="2px"
                ),
                rx.form.root(
                    rx.vstack(
                        rx.input(placeholder="Наименование направленности", name="entity_name", required=True, width="100%"),
                        rx.select(
                            DictionariesState.category_options,
                            value=DictionariesState.selected_entity_category_name,
                            on_change=DictionariesState.set_selected_entity_category_name,
                            placeholder="Выберите категорию...",
                            width="100%",
                        ),
                        rx.button("Добавить направленность", type="submit", width="100%", color_scheme="blue"),
                        spacing="3",
                    ),
                    on_submit=DictionariesState.add_entity,
                    reset_on_submit=True,
                ),
                rx.divider(),
                rx.heading("Последние 5 направленностей", size="3"),
                rx.scroll_area(
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Code"),
                                rx.table.column_header_cell("Entity ID"),
                                rx.table.column_header_cell("Наименование"),
                                rx.table.column_header_cell("Категория"),
                                rx.table.column_header_cell("Created_at"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                DictionariesState.entities[:5],
                                lambda row: rx.table.row(
                                    rx.table.cell(row["code"]),
                                    rx.table.cell(row["entity_id"], white_space="nowrap"),
                                    rx.table.cell(row["entity_name"], white_space="nowrap"),
                                    rx.table.cell(row["category_id"], white_space="nowrap"),
                                    rx.table.cell(row["created_at"]),
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

        spacing="4",
        width="100%",
    )