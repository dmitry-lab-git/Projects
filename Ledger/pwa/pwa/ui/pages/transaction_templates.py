import reflex as rx
from pwa.state.transaction_templates import TransactionTemplateState

@rx.page(route="/transaction-templates", on_load=TransactionTemplateState.load_templates)
def transaction_templates_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.link("← Назад в меню", href="/"),
            rx.heading("Управление шаблонами транзакций", size="7"),
            rx.card(
                rx.vstack(
                    rx.heading("Новый шаблон транзакции", size="4"),
                    
                    # Выбор шаблона для автозаполнения (с защитой через rx.cond)
                    rx.vstack(
                        rx.text("Выбрать шаблон для автозаполнения:", size="2", weight="bold"),
                        rx.cond(
                            TransactionTemplateState.template_options,
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите шаблон..."),
                                rx.select.content(
                                    rx.foreach(
                                        TransactionTemplateState.template_options,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                on_change=TransactionTemplateState.select_template,
                                width="100%",
                            ),
                            rx.text("Загрузка...", size="2", color="gray"),
                        ),
                        spacing="1",
                        width="100%",
                    ),
                    
                    rx.divider(margin_y="0.5em"),

                    rx.form.root(
                        rx.vstack(
                            rx.text("Имя транзакции:", size="2", weight="bold"),
                            rx.input(
                                placeholder="Введите имя транзакции", 
                                value=TransactionTemplateState.transaction_name,
                                on_change=TransactionTemplateState.set_transaction_name,
                                name="transaction_name", 
                                required=True, 
                                width="100%"
                            ),

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

                            rx.text("Направленность:", size="2", weight="bold"),
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

                            rx.text("Тип транзакции:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите тип..."),
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

                            rx.text("Сумма по умолчанию:", size="2", weight="bold"),
                            rx.input(
                                placeholder="0.00",
                                value=TransactionTemplateState.amount,
                                on_change=TransactionTemplateState.set_amount,
                                name="amount",
                                type="text",
                                pattern=r"^-?[0-9]+([.,][0-9]{1,2})?$",
                                width="100%",
                            ),

                            rx.button("Сохранить шаблон", type="submit", color_scheme="blue", width="100%"),
                            spacing="3",
                        ),
                        on_submit=TransactionTemplateState.create_template,
                        reset_on_submit=True,
                    ),

                    rx.divider(margin_y="1em"),
                    rx.heading("Существующие шаблоны", size="4"),
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Название шаблона"),
                                rx.table.column_header_cell("Сумма"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                TransactionTemplateState.templates,
                                lambda t: rx.table.row(
                                    rx.table.cell(t.get("transaction_name")),
                                    rx.table.cell(t.get("amount")),
                                ),
                            ),
                        ),
                        width="100%",
                        margin_top="1em",
                    ),
                    spacing="3",
                ),
                width="100%",
                padding="1.5em",
            ),
            spacing="4",
            padding_bottom="4em",
        ),
        size="2",
    )