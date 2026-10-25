import reflex as rx
from sqlmodel import select, insert, func
from ...db import SessionLocal 
# Импортируем классы моделей
from ...models.transactions import AccBalanceSnapshotRegister as AccBalanceSnapshot
from ...models.dicts import Account
from ...state.main_state import State, SnapshotRegisterState 

def snapshot_tab_view() -> rx.Component:
    return rx.card(
        rx.vstack(
            rx.heading("Регистр снимков баланса", size="4"),
            rx.form.root(
                rx.vstack(
                    rx.text("Code (int) [Авто]:", size="2", weight="bold"),
                    rx.input(value=SnapshotRegisterState.code.to_string(), read_only=True, width="100%"),
                    
                    rx.text("Account ID (выбор по имени счета):", size="2", weight="bold"),
                    rx.select.root(
                        rx.select.trigger(placeholder="Выберите счет..."),
                        rx.select.content(
                            rx.foreach(
                                SnapshotRegisterState.filtered_accounts,
                                lambda item: rx.select.item(item[1], value=item[0])
                            ),
                        ),
                        search_enabled=True,
                        on_change=SnapshotRegisterState.set_account_id,
                        width="100%",
                    ),
                    
                    rx.text("Transaction ID:", size="2", weight="bold"),
                    rx.input(placeholder="Введите Tr ID", name="tr_id", width="100%"),
                    
                    rx.text("Balance:", size="2", weight="bold"),
                    rx.input(placeholder="Введите баланс", name="balance", type="number", width="100%"),
                    
                    rx.button("Записать снимок", type="submit", color_scheme="blue", width="100%"),
                    spacing="3",
                ),
                on_submit=SnapshotRegisterState.handle_submit,
                reset_on_submit=True,
            ),
            spacing="3",
        ),
        width="100%",
        padding="1.5em",
    )