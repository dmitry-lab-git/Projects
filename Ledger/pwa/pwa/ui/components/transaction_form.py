import reflex as rx
from pwa.state.main_state import State
from pwa.state.transaction_templates import TransactionTemplateState

# Единственная рабочая главная страница (декоратор оставляем только здесь)
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
                            rx.text("Название операции:", size="2"),
                            rx.input(
                                placeholder="Введите название",
                                name="transaction_name",
                                value=TransactionTemplateState.transaction_name,
                                on_change=TransactionTemplateState.set_transaction_name,
                            ),
                            rx.text("Дата операции:", size="2", weight="bold"),
                            rx.checkbox("Использовать текущую дату", on_change=State.toggle_current_date),
                            rx.input(
                                type="date",
                                name="operation_date",
                                value=rx.cond(State.use_current_date, State.current_date, State.manual_date),
                                on_change=State.set_manual_date,
                                read_only=State.use_current_date
                            ),
                            rx.text("Время операции:", size="2", weight="bold"),
                            rx.checkbox("Использовать текущее время", on_change=State.toggle_current_time),
                            rx.input(
                                type="time",
                                name="operation_time",
                                value=rx.cond(State.use_current_time, State.current_time, State.manual_time),
                                on_change=State.set_manual_time,
                                read_only=State.use_current_time
                            ),
                            rx.text("Контрагент донор (contragent_name (code)):", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Введите имя контрагента..."),
                                rx.select.content(
                                    rx.foreach(
                                        State.filtered_contragents,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                search_enabled=True,
                                value=State.contragent_from_id,
                                on_change=State.set_contragent_from_id,
                                width="100%",
                            ),
                            rx.text("Контрагент акцептор (contragent_name (code)):", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Введите имя контрагента..."),
                                rx.select.content(
                                    rx.foreach(
                                        State.filtered_contragents,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                search_enabled=True,
                                value=State.contragent_to_id,
                                on_change=State.set_contragent_to_id,
                                width="100%",
                            ),
                            rx.text("Категория (category_name (code) I parent_category_name):", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите категорию..."),
                                rx.select.content(
                                    rx.foreach(
                                        State.filtered_categories,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                search_enabled=True,
                                value=State.category_id,
                                on_change=State.set_category_id,
                                width="100%",
                            ),
                            rx.text("Направленность (entity_name (code) category_name):", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите направленность..."),
                                rx.select.content(
                                    rx.foreach(
                                        State.filtered_entities,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                search_enabled=True,
                                value=State.entity_id,
                                on_change=State.set_entity_id,
                                width="100%",
                            ),
                            rx.text("Название счета (активные счета):", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Введите название счета..."),
                                rx.select.content(
                                    rx.foreach(
                                        State.filtered_accounts,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                search_enabled=True,
                                value=State.account_id,
                                on_change=State.set_account_id,
                                width="100%",
                            ),
                            rx.text("Тип транзакции:", size="2", weight="bold"),
                            rx.select.root(
                                rx.select.trigger(placeholder="Выберите тип транзакции..."),
                                rx.select.content(
                                    rx.foreach(
                                        State.filtered_types,
                                        lambda item: rx.select.item(item[1], value=item[0])
                                    ),
                                ),
                                search_enabled=True,
                                value=State.type_id,
                                on_change=State.set_type_id,
                                width="100%",
                            ),
                            rx.text("Ответственный:", size="2", weight="bold"),
                            rx.input(default_value="RSP-001", read_only=True, width="100%"),
                            rx.text("Сумма транзакции:", size="2", weight="bold"),
                            rx.text_field(
                                placeholder="0.00",
                                name="amount",
                                required=True,
                                type="text",
                                pattern=r"^-?[0-9]+([.,][0-9]{1,2})?$",
                                value=TransactionTemplateState.amount,
                                on_change=TransactionTemplateState.set_amount,
                                width="100%",
                            ),

                            # Кнопки отправки транзакции и создания шаблона
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

                            rx.divider(margin_y="1em"),
                            rx.hstack(
                                rx.heading("Последние операции", size="4"),
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
                            spacing="3",
                        ),
                        on_submit=State.handle_submit,
                        reset_on_submit=True,
                    ),
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Наименование"),
                                rx.table.column_header_cell("Сумма"),
                                rx.table.column_header_cell("Дата операции"),
                                rx.table.column_header_cell("Статус"),
                            ),
                        ),
                        rx.table.body(
                            rx.foreach(
                                State.staging_transactions,
                                lambda tx: rx.table.row(
                                    rx.table.cell(tx.get("transaction_name")),
                                    rx.table.cell(tx.get("amount")),
                                    rx.table.cell(tx.get("operation_date")),
                                    rx.table.cell(tx.get("status")),
                                ),
                            ),
                        ),
                        width="100%",
                        margin_top="2em",
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