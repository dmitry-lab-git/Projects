import reflex as rx
from pwa.state.main_state import State
from pwa.state.transaction_templates import TransactionTemplateState

@rx.page(
    route="/new-transaction", 
    on_load=[State.on_load, TransactionTemplateState.load_templates]
)
def add_transaction_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/"),
            rx.heading("Реестр транзакций", size="7"),
            rx.card(
                rx.vstack(
                    rx.heading("Новая операция", size="4"),

                    # Селектор выбора существующих шаблонов
                    rx.text("Выбрать шаблон для автозаполнения:", size="2", weight="bold"),
                    rx.select.root(
                        rx.select.trigger(placeholder="Выберите шаблон..."),
                        rx.select.content(
                            rx.foreach(
                                TransactionTemplateState.template_options,
                                lambda item: rx.select.item(item[1], value=item[0])
                            ),
                        ),
                        value=TransactionTemplateState.selected_template_id,
                        on_change=TransactionTemplateState.select_template,
                        width="100%",
                    ),
                    
                    rx.divider(margin_y="0.5em"),
                    rx.form.root(
                        rx.vstack(
                            # 1. Название операции
                            rx.text("Название операции:", size="2", weight="bold"),
                            rx.input(
                                placeholder="Введите название",
                                name="transaction_name",
                                value=TransactionTemplateState.transaction_name,
                                on_change=TransactionTemplateState.set_transaction_name,
                                width="100%",
                            ),
                            
                            # 2. Валюта
                            rx.text("Валюта:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите валюту..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.filtered_currencies,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                value=TransactionTemplateState.currency_id,
                                on_change=TransactionTemplateState.set_currency_id,
                                width="100%",
                            ),

                            # 3. Сумма операции
                            rx.text("Сумма операции:", size="2", weight="bold"),
                            rx.input(
                                placeholder="0.00",
                                name="amount",
                                required=True,
                                type="text",
                                pattern=r"^-?[0-9]+([.,][0-9]{1,2})?$",
                                value=TransactionTemplateState.amount,
                                on_change=TransactionTemplateState.set_amount,
                                width="100%",
                            ),

                            # 4. Дата операции
                            rx.hstack(
                                rx.vstack(
                                    rx.text("Дата операции:", weight="bold"),
                                    rx.input(
                                        type="date",
                                        name="operation_date",
                                        value=TransactionTemplateState.operation_date,
                                        on_change=TransactionTemplateState.set_operation_date,
                                        disabled=TransactionTemplateState.use_current_date,
                                        width="100%",
                                    ),
                                    flex="1",
                                ),
                                rx.vstack(
                                    rx.text(" ", size="1"),
                                    rx.hstack(
                                        rx.checkbox(
                                            checked=TransactionTemplateState.use_current_date,
                                            on_change=TransactionTemplateState.toggle_current_date
                                        ),
                                        rx.text("Текущая", size="2"),
                                        align="center"
                                    ),
                                    justify="end",
                                ),
                                align="end",
                                width="100%",
                            ),

                            # 5. Время операции
                            rx.hstack(
                                rx.vstack(
                                    rx.text("Время операции:", weight="bold"),
                                    rx.input(
                                        type="time",
                                        step="60",
                                        name="operation_time",
                                        value=TransactionTemplateState.operation_time,
                                        on_change=TransactionTemplateState.set_operation_time,
                                        disabled=TransactionTemplateState.use_current_time,
                                        width="100%",
                                    ),
                                    flex="1",
                                ),
                                rx.vstack(
                                    rx.text(" ", size="1"),
                                    rx.hstack(
                                        rx.checkbox(
                                            checked=TransactionTemplateState.use_current_time,
                                            on_change=TransactionTemplateState.toggle_current_time
                                        ),
                                        rx.text("Текущее", size="2"),
                                        align="center"
                                    ),
                                    justify="end",
                                ),
                                align="end",
                                width="100%",
                            ),

                            # 6. Ответственный
                            rx.text("Ответственный:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите ответственного..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.filtered_responsibles,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                value=TransactionTemplateState.responsible_id,
                                on_change=TransactionTemplateState.set_responsible_id,
                                width="100%",
                            ),

                            # 7. Контрагент донор
                            rx.text("Контрагент донор:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите контрагента..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.filtered_contragents,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                value=TransactionTemplateState.contragent_from_id,
                                on_change=TransactionTemplateState.set_contragent_from_id,
                                width="100%",
                            ),

                            # 8. Контрагент акцептор
                            rx.text("Контрагент акцептор:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите контрагента..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.filtered_contragents,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                value=TransactionTemplateState.contragent_to_id,
                                on_change=TransactionTemplateState.set_contragent_to_id,
                                width="100%",
                            ),

                            # 9. Категория
                            rx.text("Категория:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите категорию..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.filtered_categories,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                value=TransactionTemplateState.category_id,
                                on_change=TransactionTemplateState.set_category_id,
                                width="100%",
                            ),

                            # 10. Тип операции
                            rx.text("Тип операции:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите тип операции..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.filtered_types,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                value=TransactionTemplateState.type_id,
                                on_change=TransactionTemplateState.set_type_id,
                                width="100%",
                            ),

                            # 11. Название счета
                            rx.text("Название счета:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите счет..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.filtered_accounts,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                value=TransactionTemplateState.account_id,
                                on_change=TransactionTemplateState.set_account_id,
                                width="100%",
                            ),

                            # 12. Направленность операции
                            rx.text("Направленность операции:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите направленность..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.filtered_entities,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                value=TransactionTemplateState.entity_id,
                                on_change=TransactionTemplateState.set_entity_id,
                                width="100%",
                            ),

                            # Кнопки формы
                            rx.hstack(
                                rx.button("Записать в базу данных", type="submit", color_scheme="blue", flex="1"),
                                rx.button(
                                    "Создать шаблон",
                                    type="button",
                                    color_scheme="green",
                                    on_click=TransactionTemplateState.create_template,
                                    flex="1"
                                ),
                                width="100%",
                                spacing="3",
                            ),
                            spacing="3",
                        ),
                        on_submit=TransactionTemplateState.create_staging_transaction,
                        reset_on_submit=True,
                    ),

                    # Блок неопубликованных транзакций из Staging
                    rx.divider(margin_y="1em"),
                    rx.hstack(
                        rx.heading(
                            rx.cond(
                                State.unposted_count > 0,
                                "Не опубликованные транзакции таблицы Staging:",
                                "Все транзакции опубликованы"
                            ),
                            size="4"
                        ),
                        rx.spacer(),
                        rx.icon_button(
                            rx.icon(tag="refresh-cw"),
                            on_click=State.refresh_staging_transactions,
                            type="button",
                            variant="soft",
                            color_scheme="gray",
                            size="2",
                            cursor="pointer",
                        ),
                        width="100%",
                        align="center",
                    ),
                    
                    rx.cond(
                        State.unposted_count > 0,
                        rx.table.root(
                            rx.table.header(
                                rx.table.row(
                                    rx.table.column_header_cell("UUID"),
                                    rx.table.column_header_cell("Название"),
                                    rx.table.column_header_cell("Код"),
                                    rx.table.column_header_cell("Дата"),
                                    rx.table.column_header_cell("Время"),
                                    rx.table.column_header_cell("Сумма"),
                                    rx.table.column_header_cell("Статус"),
                                ),
                            ),
                            rx.table.body(
                                rx.foreach(
                                    State.unposted_staging_transactions,
                                    lambda tx: rx.table.row(
                                        rx.table.cell(tx["id"]),
                                        rx.table.cell(tx["transaction_name"]),
                                        rx.table.cell(tx["code"]),
                                        rx.table.cell(tx["operation_date"]),
                                        rx.table.cell(tx["operation_time"]),
                                        rx.table.cell(tx["amount"]),
                                        rx.table.cell(tx["status_name"]),
                                    ),
                                ),
                            ),
                            width="100%",
                            margin_top="0.5em",
                        ),
                        rx.text("Все транзакции опубликованы", color="green", weight="bold", margin_top="0.5em")
                    ),
                    spacing="3",
                ),
                width="100%",
                padding="1.5em",
            ),
            spacing="4",
            padding_bottom="6em",
        ),
        
        # Плавающая кнопка обновления справочников в правом нижнем углу
        rx.box(
            rx.button(
                rx.icon(tag="refresh-cw"),
                "Обновить справочники",
                on_click=State.refresh_staging_transactions,
                color_scheme="gray",
                variant="solid",
                size="3",
                box_shadow="lg",
                cursor="pointer",
            ),
            position="fixed",
            bottom="2rem",
            right="2rem",
            z_index="1000",
        ),

        # Плавающая плашка снизу страницы
        rx.box(
            rx.vstack(
                rx.text("Последняя транзакция в transactions: " + State.last_transaction_info, size="1", weight="bold"),
                rx.text("Количество неопубликованных транзакций staging: " + State.unposted_count.to_string(), size="1"),
                spacing="1",
                align="start",
            ),
            position="fixed",
            bottom="1rem",
            left="50%",
            transform="translateX(-50%)",
            bg="white",
            border="1px solid #e2e8f0",
            box_shadow="lg",
            padding="0.75rem 1.25rem",
            border_radius="md",
            z_index="1000",
            max_width="90vw",
        ),
        size="2",
    )