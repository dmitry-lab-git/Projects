import reflex as rx
from pwa.state.transaction_templates import TransactionTemplateState

def transaction_template_form() -> rx.Component:
    return rx.vstack(
        rx.card(
            rx.vstack(
                rx.heading("Новая операция", size="5"),
                
                # 1. Выбор шаблона для автозаполнения
                rx.vstack(
                    rx.text("Выбрать шаблон для автозаполнения:", size="2", weight="bold"),
                    rx.select(
                        items=TransactionTemplateState.template_options,
                        placeholder="Выберите шаблон...",
                        on_change=TransactionTemplateState.select_template,
                        value=TransactionTemplateState.selected_template_id,
                    ),
                    spacing="1",
                    width="100%",
                ),
                
                rx.divider(),

                rx.form.root(
                    rx.vstack(
                        # Название операции
                        rx.text("Название операции:", size="2"),
                        rx.input(
                            placeholder="Название операции", 
                            value=TransactionTemplateState.transaction_name,
                            on_change=TransactionTemplateState.set_transaction_name,
                            name="transaction_name", 
                            required=True
                        ),
                        
                        # Сумма
                        rx.text("Сумма:", size="2"),
                        rx.input(
                            placeholder="Сумма по умолчанию", 
                            value=TransactionTemplateState.amount,
                            on_change=TransactionTemplateState.set_amount,
                            name="amount", 
                            type="number", 
                            step="0.01"
                        ),

                        # Счет (account_id)
                        rx.text("Счет:", size="2"),
                        rx.select(
                            items=TransactionTemplateState.filtered_accounts,
                            value=TransactionTemplateState.account_id,
                            on_change=TransactionTemplateState.set_account_id,
                            placeholder="Выберите счет...",
                            key=TransactionTemplateState.account_id,
                        ),

                        # Категория (category_id)
                        rx.text("Категория:", size="2"),
                        rx.select(
                            items=TransactionTemplateState.filtered_categories,
                            value=TransactionTemplateState.category_id,
                            on_change=TransactionTemplateState.set_category_id,
                            placeholder="Выберите категорию...",
                            key=TransactionTemplateState.category_id,
                        ),

                        # Тип транзакции (type_id)
                        rx.text("Тип транзакции:", size="2"),
                        rx.select(
                            items=TransactionTemplateState.filtered_types,
                            value=TransactionTemplateState.type_id,
                            on_change=TransactionTemplateState.set_type_id,
                            placeholder="Выберите тип...",
                            key=TransactionTemplateState.type_id,
                        ),

                        # Направленность (entity_id)
                        rx.text("Направленность:", size="2"),
                        rx.select(
                            items=TransactionTemplateState.filtered_entities,
                            value=TransactionTemplateState.entity_id,
                            on_change=TransactionTemplateState.set_entity_id,
                            placeholder="Выберите направленность...",
                            key=TransactionTemplateState.entity_id,
                        ),

                        # Контрагент акцептор (contragent_to_id)
                        rx.text("Контрагент акцептор:", size="2"),
                        rx.select(
                            items=TransactionTemplateState.filtered_contragents,
                            value=TransactionTemplateState.contragent_to_id,
                            on_change=TransactionTemplateState.set_contragent_to_id,
                            placeholder="Выберите контрагента...",
                            key=TransactionTemplateState.contragent_to_id,
                        ),

                        # Статус (status_id)
                        rx.text("Статус:", size="2"),
                        rx.select(
                            items=TransactionTemplateState.filtered_statuses,
                            value=TransactionTemplateState.status_id,
                            on_change=TransactionTemplateState.set_status_id,
                            placeholder="Выберите статус...",
                            key=TransactionTemplateState.status_id,
                        ),
                        
                        rx.button("Сохранить шаблон", type="submit"),
                    ),
                    on_submit=TransactionTemplateState.create_template,
                    reset_on_submit=False,
                ),
                spacing="3",
            ),
            width="100%",
        ),
        spacing="4",
        width="100%",
    )