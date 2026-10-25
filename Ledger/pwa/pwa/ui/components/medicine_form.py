import reflex as rx
from pwa.state.medicine import MedicineState


def medicine_form() -> rx.Component:
    return rx.vstack(
        # 1. Справочник препаратов
        rx.card(
            rx.vstack(
                rx.heading("Справочник препаратов (Добавки)", size="4"),
                rx.form.root(
                    rx.vstack(
                        rx.input(
                            placeholder="Наименование препарата",
                            name="name",
                            required=True,
                        ),
                        rx.input(
                            placeholder="Производитель / Бренд",
                            name="brand",
                        ),
                        rx.input(
                            placeholder="Форма выпуска / Единица (например, таблетка)",
                            name="unit_type",
                            default_value="таблетка",
                        ),
                        rx.button("Добавить в справочник", type="submit"),
                    ),
                    on_submit=MedicineState.add_supplement,
                    reset_on_submit=True,
                ),
                rx.divider(),
                rx.heading("Существующие препараты", size="3"),
                rx.scroll_area(
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Наименование"),
                                rx.table.column_header_cell("Бренд"),
                                rx.table.column_header_cell("Единица"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                MedicineState.supplements,
                                lambda row: rx.table.row(
                                    rx.table.cell(row["name"], white_space="nowrap"),
                                    rx.table.cell(row["brand"], white_space="nowrap"),
                                    rx.table.cell(row["unit_type"], white_space="nowrap"),
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

        # 2. Регистрация приема препарата
        rx.card(
            rx.vstack(
                rx.heading("Регистрация приема препарата", size="4"),
                rx.form.root(
                    rx.vstack(
                        rx.select(
                            MedicineState.supplement_names,
                            value=MedicineState.selected_supplement_name,
                            on_change=MedicineState.set_selected_supplement_name,
                            placeholder="Выберите препарат...",
                            width="100%",
                        ),
                        rx.input(
                            placeholder="Количество",
                            name="amount",
                            type="number",
                            default_value="1",
                            required=True,
                        ),
                        rx.hstack(
                            rx.checkbox(
                                checked=MedicineState.use_current_date,
                                on_change=MedicineState.set_use_current_date,
                            ),
                            rx.text(
                                "Использовать текущую дату",
                                size="2",
                                white_space="nowrap",
                            ),
                            align="center",
                            spacing="2",
                        ),
                        rx.input(
                            name="intake_date",
                            type="date",
                            disabled=MedicineState.use_current_date,
                            value=rx.cond(
                                MedicineState.use_current_date,
                                MedicineState.observation_date_str,
                                MedicineState.selected_date,
                            ),
                            on_change=MedicineState.set_selected_date,
                            width="100%",
                        ),
                        rx.button("Зарегистрировать прием", type="submit"),
                    ),
                    on_submit=MedicineState.add_intake,
                ),
                spacing="3",
            ),
            width="100%",
        ),

        # 3. Дневник наблюдений
        rx.card(
            rx.vstack(
                rx.heading("Дневник наблюдений и самочувствия", size="4"),
                rx.form.root(
                    rx.vstack(
                        rx.input(
                            name="observation_date",
                            type="date",
                            value=MedicineState.observation_date_str,
                            on_change=MedicineState.set_observation_date_str,
                            width="100%",
                            required=True,
                        ),
                        rx.text_area(
                            placeholder="Заметки, физиологические реакции, самочувствие...",
                            name="notes",
                            value=MedicineState.observation_notes,
                            on_change=MedicineState.set_observation_notes,
                            width="100%",
                        ),
                        rx.button("Сохранить дневник", type="submit"),
                    ),
                    on_submit=MedicineState.save_observation,
                ),
                spacing="3",
            ),
            width="100%",
        ),

        rx.divider(margin_y="1em"),

        # 4. История приемов и наблюдений
        rx.heading("Журнал приемов (последние 50)", size="4"),
        rx.scroll_area(
            rx.table.root(
                rx.table.header(
                    rx.table.row(
                        rx.table.column_header_cell("Дата"),
                        rx.table.column_header_cell("Препарат"),
                        rx.table.column_header_cell("Количество"),
                        rx.table.column_header_cell("Ед."),
                    ),
                ),
                rx.table.body(
                    rx.foreach(
                        MedicineState.intakes,
                        lambda row: rx.table.row(
                            rx.table.cell(row["intake_date"], white_space="nowrap"),
                            rx.table.cell(row["supplement_name"], white_space="nowrap"),
                            rx.table.cell(row["amount"], white_space="nowrap"),
                            rx.table.cell(row["unit_type"], white_space="nowrap"),
                        ),
                    ),
                ),
                width="100%",
            ),
            max_height="300px",
            width="100%",
        ),

        rx.heading("Дневник наблюдений (последние 50)", size="4"),
        rx.scroll_area(
            rx.table.root(
                rx.table.header(
                    rx.table.row(
                        rx.table.column_header_cell("Дата"),
                        rx.table.column_header_cell("Заметки"),
                    ),
                ),
                rx.table.body(
                    rx.foreach(
                        MedicineState.observations,
                        lambda row: rx.table.row(
                            rx.table.cell(row["observation_date"], white_space="nowrap"),
                            rx.table.cell(row["notes"]),
                        ),
                    ),
                ),
                width="100%",
            ),
            max_height="300px",
            width="100%",
        ),
        spacing="4",
        width="100%",
    )
