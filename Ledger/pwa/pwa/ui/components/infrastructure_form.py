import reflex as rx
from pwa.state.infrastructure import InfrastructureState


def infrastructure_form() -> rx.Component:
    return rx.vstack(
        # 1. Сводка с фильтром по месяцу и детальными вкладками
        rx.card(
            rx.vstack(
                rx.hstack(
                    rx.heading("Сводка по утилизации", size="4"),
                    rx.spacer(),
                    rx.input(
                        type="month",
                        value=InfrastructureState.selected_month,
                        on_change=InfrastructureState.set_selected_month,
                        width="auto",
                    ),
                    width="100%",
                    align="center",
                ),
                rx.tabs.root(
                    rx.tabs.list(
                        rx.tabs.trigger("По пунктам", value="by_point"),
                        rx.tabs.trigger("По ресурсам", value="by_resource"),
                    ),
                    # Вкладка 1: Разбивка по пунктам утилизации
                    rx.tabs.content(
                        rx.cond(
                            InfrastructureState.monthly_summary.length() > 0,
                            rx.scroll_area(
                                rx.table.root(
                                    rx.table.header(
                                        rx.table.row(
                                            rx.table.column_header_cell("Пункт утилизации"),
                                            rx.table.column_header_cell("Масса"),
                                            rx.table.column_header_cell("Количество"),
                                        ),
                                    ),
                                    rx.table.body(
                                        rx.foreach(
                                            InfrastructureState.monthly_summary,
                                            lambda row: rx.table.row(
                                                rx.table.cell(
                                                    row["disposition_point_name"], white_space="nowrap"
                                                ),
                                                rx.table.cell(
                                                    row["total_mass"], white_space="nowrap"
                                                ),
                                                rx.table.cell(
                                                    row["record_count"], white_space="nowrap"
                                                ),
                                            ),
                                        ),
                                    ),
                                    width="100%",
                                ),
                                width="100%",
                            ),
                            rx.text("За выбранный месяц записей пока нет.", color="gray", size="2"),
                        ),
                        value="by_point",
                    ),
                    # Вкладка 2: Разбивка по материалам/ресурсам
                    rx.tabs.content(
                        rx.cond(
                            InfrastructureState.resource_summary.length() > 0,
                            rx.scroll_area(
                                rx.table.root(
                                    rx.table.header(
                                        rx.table.row(
                                            rx.table.column_header_cell("Ресурс / Материал"),
                                            rx.table.column_header_cell("Масса"),
                                            rx.table.column_header_cell("Количество"),
                                        ),
                                    ),
                                    rx.table.body(
                                        rx.foreach(
                                            InfrastructureState.resource_summary,
                                            lambda row: rx.table.row(
                                                rx.table.cell(
                                                    row["resource_name"], white_space="nowrap"
                                                ),
                                                rx.table.cell(
                                                    row["total_mass"], white_space="nowrap"
                                                ),
                                                rx.table.cell(
                                                    row["record_count"], white_space="nowrap"
                                                ),
                                            ),
                                        ),
                                    ),
                                    width="100%",
                                ),
                                width="100%",
                            ),
                            rx.text("За выбранный месяц записей пока нет.", color="gray", size="2"),
                        ),
                        value="by_resource",
                    ),
                    default_value="by_point",
                    width="100%",
                ),
                spacing="3",
            ),
            width="100%",
        ),
        # 2. Добавить материал
        rx.card(
            rx.vstack(
                rx.heading("Добавить материал", size="4"),
                rx.form.root(
                    rx.vstack(
                        rx.input(
                            placeholder="Название материала",
                            name="material_name",
                            required=True,
                        ),
                        rx.input(
                            placeholder="Тип ресурса", name="resource_type"
                        ),
                        rx.input(
                            placeholder="Единица измерения", name="default_unit"
                        ),
                        rx.input(
                            placeholder="Тип тары", name="container_type"
                        ),
                        rx.button("Сохранить ресурс", type="submit"),
                    ),
                    on_submit=InfrastructureState.add_resource,
                    reset_on_submit=True,
                ),
                spacing="3",
            ),
            width="100%",
        ),
        # 3. Ввод расхода
        rx.card(
            rx.vstack(
                rx.heading("Ввод расхода", size="4"),
                rx.form.root(
                    rx.vstack(
                        rx.select(
                            InfrastructureState.resource_names,
                            value=InfrastructureState.selected_resource_name,
                            on_change=InfrastructureState.set_selected_resource_name,
                            placeholder="Выберите ресурс...",
                            width="100%",
                        ),
                        rx.select(
                            InfrastructureState.device_names,
                            value=InfrastructureState.selected_device_name,
                            on_change=InfrastructureState.set_selected_device_name,
                            placeholder="Выберите устройство...",
                            width="100%",
                        ),
                        rx.select(
                            InfrastructureState.disposition_point_names,
                            value=InfrastructureState.selected_disposal_point_name,
                            on_change=InfrastructureState.set_selected_disposal_point_name,
                            placeholder="Выберите пункт утилизации...",
                            width="100%",
                        ),
                        rx.select(
                            ["gross", "net"],
                            name="weighing_type",
                            default_value="gross",
                            placeholder="Тип взвешивания...",
                            width="100%",
                        ),
                        rx.input(
                            placeholder="Количество",
                            name="quantity",
                            type="number",
                            step="0.001",
                            required=True,
                        ),
                        rx.vstack(
                            rx.hstack(
                                rx.checkbox(
                                    checked=InfrastructureState.use_current_date,
                                    on_change=InfrastructureState.set_use_current_date,
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
                                name="utilized_at",
                                type="date",
                                disabled=InfrastructureState.use_current_date,
                                value=rx.cond(
                                    InfrastructureState.use_current_date,
                                    InfrastructureState.today_date_str,
                                    InfrastructureState.selected_date,
                                ),
                                on_change=InfrastructureState.set_selected_date,
                                width="100%",
                            ),
                            width="100%",
                            align="start",
                            spacing="2",
                        ),
                        rx.button("Записать расход", type="submit"),
                    ),
                    on_submit=InfrastructureState.add_disposition,
                ),
                spacing="3",
            ),
            width="100%",
        ),
        rx.divider(margin_y="1em"),
        rx.heading("Последние 20 транзакций", size="4"),
        rx.scroll_area(
            rx.table.root(
                rx.table.header(
                    rx.table.row(
                        rx.table.column_header_cell("Дата"),
                        rx.table.column_header_cell("Ресурс"),
                        rx.table.column_header_cell("Количество"),
                        rx.table.column_header_cell("Устройство"),
                        rx.table.column_header_cell("Пункт утилизации"),
                    ),
                ),
                rx.table.body(
                    rx.foreach(
                        InfrastructureState.disposition_history,
                        lambda row: rx.table.row(
                            rx.table.cell(
                                row["created_at"], white_space="nowrap"
                            ),
                            rx.table.cell(
                                row["material_name"], white_space="nowrap"
                            ),
                            rx.table.cell(
                                row["quantity"], white_space="nowrap"
                            ),
                            rx.table.cell(
                                row["device_name"], white_space="nowrap"
                            ),
                            rx.table.cell(
                                row["disposition_point_name"],
                                white_space="nowrap",
                            ),
                        ),
                    ),
                ),
                width="100%",
            ),
            width="100%",
        ),
        spacing="4",
        width="100%",
    )