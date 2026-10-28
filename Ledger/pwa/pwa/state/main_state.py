import reflex as rx
from datetime import datetime, date
from sqlalchemy import select, insert, desc, text, func
from ..db import SessionLocal
# Импортируем классы моделей напрямую
from ..models.dicts import (
    DictType, 
    Contragent, 
    Account, 
    DictStatus, 
    DictsCurrency,  
    Responsible, 
    DictCategory, 
    Entity
)
from ..models.transactions import (
    Transaction, 
    StagingTransaction, 
    AccBalanceSnapshotRegister as AccBalanceSnapshot
)

class State(rx.State):
    staging_transactions: list[dict] = []
    
    # Поля для неопубликованных транзакций и плавающей плашки
    unposted_staging_transactions: list[dict] = []
    last_transaction_info: str = "Нет данных"
    unposted_count: int = 0

    @rx.event
    def on_load(self):
        return self.load_staging_transactions()

    @rx.event
    def refresh_staging_transactions(self):
        self.load_staging_transactions()
        return rx.toast.success("Данные успешно обновлены!")

    @rx.event
    def load_staging_transactions(self):
        with SessionLocal() as session:
            # 1. Загружаем неопубликованные транзакции через функцию audit.get_unposted_transactions()
            unposted_rows = session.execute(text("SELECT id, transaction_name, operation_date, operation_time, amount, code, current_status_code, current_status_name FROM audit.get_unposted_transactions()")).fetchall()
            
            self.unposted_staging_transactions = [
                {
                    "id": str(r[0])[:8] if r[0] else "-",
                    "transaction_name": str(r[1] or "-"),
                    "operation_date": str(r[2] or "-"),
                    "operation_time": str(r[3] or "-"),
                    "amount": f"{float(r[4] or 0.0):.2f}" if r[4] is not None else "-",
                    "code": str(r[5] or "-"),
                    "status_code": str(r[6] or "—"),
                    "status_name": str(r[7] or "—"),
                }
                for r in unposted_rows
            ]
            self.unposted_count = len(self.unposted_staging_transactions)

            # 2. Получаем последнюю транзакцию из представления reports.v_transactions_last
            last_tx = session.execute(
                text("SELECT code, transaction_name, amount, created_at FROM reports.v_transactions_last ORDER BY created_at DESC LIMIT 1")
            ).fetchone()
            
            if last_tx:
                self.last_transaction_info = f"{last_tx[0] or '—'} | {last_tx[1] or '—'} | {float(last_tx[2] or 0):.2f} | {str(last_tx[3])[:19] if last_tx[3] else '—'}"
            else:
                self.last_transaction_info = "Нет транзакций"

            # 3. Сохраняем базовый список staging для совместимости
            query = (
                select(StagingTransaction, DictStatus.code)
                .outerjoin(DictStatus, StagingTransaction.status_id == DictStatus.id)
                .order_by(desc(StagingTransaction.created_at))
            )
            results = session.execute(query).all()
            
            self.staging_transactions = [
                {
                    "id": str(tx.id)[:8] if tx.id else "-",
                    "transaction_name": str(tx.transaction_name or "-"),
                    "code": str(getattr(tx, "code", None) or getattr(tx, "transaction_code", None) or "-"),
                    "amount": f"{float(tx.amount or 0.0):.2f}" if tx.amount is not None else "-",
                    "operation_date": str(tx.operation_date or "-"),
                    "operation_time": str(tx.operation_time or "-"),
                    "status": status_code or "NEED_REVIEW"
                }
                for tx, status_code in results
            ]

    # Ввод даты и времени
    use_current_date: bool = False
    use_current_time: bool = False
    manual_date: str = ""
    manual_time: str = ""

    @rx.event
    def set_manual_date(self, value: str):
        self.manual_date = value

    @rx.event
    def set_manual_time(self, value: str):
        self.manual_time = value

    @rx.event
    def toggle_current_date(self, value: bool):
        self.use_current_date = value
        if value:
            self.manual_date = self.current_date

    @rx.event
    def toggle_current_time(self, value: bool):
        self.use_current_time = value
        if value:
            self.manual_time = self.current_time
    
    @rx.var
    def current_date(self) -> str:
        return date.today().isoformat()

    @rx.var
    def current_time(self) -> str:
        return datetime.now().strftime("%H:%M")

    type_id: str = ""
    account_id: str = ""
    search_text: str = ""

    @rx.event
    def set_type_id(self, value: str):
        self.type_id = value

    @rx.var
    def type_list(self) -> list[tuple[str, str]]:
        with SessionLocal() as session:
            stmt = select(DictType).order_by(desc(DictType.code))
            rows = session.execute(stmt).scalars().all()
            return [(str(r.type_id), r.type_name) for r in rows]

    @rx.var
    def filtered_types(self) -> list[tuple[str, str]]:
        if not self.search_text:
            return self.type_list
        return [item for item in self.type_list if self.search_text.lower() in item[1].lower()]

    @rx.event
    def set_account_id(self, value: str):
        self.account_id = value

    @rx.var
    def account_list(self) -> list[tuple[str, str]]:
        with SessionLocal() as session:
            sql = text("""
                SELECT 
                    a.account_id, 
                    a.account_name, 
                    a.code,
                    e.entity_name,
                    e.entity_id
                FROM dicts.accounts a
                LEFT JOIN dicts.entities e ON a.entity_id = e.entity_id
                ORDER BY a.code DESC NULLS LAST
            """)
            rows = session.execute(sql).fetchall()
            return [
                (
                    str(r.account_id), 
                    f"{r.account_name or '—'} | {r.account_name or '—'} | {r.entity_name or '—'}({r.entity_id or '—'}({r.account_id})) | {r.code if r.code is not None else '—'}"
                ) 
                for r in rows
            ]

    @rx.var
    def filtered_accounts(self) -> list[tuple[str, str]]:
        if not self.search_text:
            return self.account_list
        search = self.search_text.lower()
        return [item for item in self.account_list if search in item[1].lower()]

    entity_id: str = ""

    @rx.event
    def set_entity_id(self, value: str):
        self.entity_id = value

    @rx.var
    def entity_list(self) -> list[tuple[str, str]]:
        with SessionLocal() as session:
            sql = text("""
                SELECT 
                    e.entity_id, 
                    e.code,
                    e.entity_name, 
                    c.category_name 
                FROM dicts.entities e 
                LEFT JOIN dicts.dict_categories c 
                    ON e.category_id = c.category_id 
                ORDER BY e.code DESC NULLS LAST
            """)
            rows = session.execute(sql).fetchall()
            return [
                (
                    str(r.entity_id), 
                    f"{r.entity_name or '—'} | {r.category_name or 'Без категории'} | {r.code if r.code is not None else '—'}"
                ) 
                for r in rows
            ]

    @rx.var
    def filtered_entities(self) -> list[tuple[str, str]]:
        if not self.search_text:
            return self.entity_list
        search = self.search_text.lower()
        return [item for item in self.entity_list if search in item[1].lower()]

    category_id: str = ""
    contragent_from_id: str = ""
    contragent_to_id: str = ""

    @rx.event
    def set_category_id(self, value: str):
        self.category_id = value

    @rx.var
    def category_list(self) -> list[tuple[str, str]]:
        with SessionLocal() as session:
            sql = text("""
                SELECT 
                    c.category_id, 
                    c.code, 
                    c.category_name, 
                    p.category_name AS parent_name 
                FROM dicts.dict_categories c 
                LEFT JOIN dicts.dict_categories p ON c.parent_category_id = p.category_id 
                ORDER BY c.code DESC NULLS LAST
            """)
            rows = session.execute(sql).fetchall()
            return [
                (
                    str(r.category_id), 
                    f"{r.category_name or '—'} | {r.parent_name or 'Корневая'} | {r.code if r.code is not None else '—'}"
                ) 
                for r in rows
            ]

    @rx.var
    def filtered_categories(self) -> list[tuple[str, str]]:
        if not self.search_text:
            return self.category_list  
        search = self.search_text.lower()
        return [item for item in self.category_list if search in item[1].lower()]

    @rx.event
    def set_search_text(self, value: str):
        self.search_text = value
    
    @rx.event
    def set_contragent_from_id(self, value: str):
        self.contragent_from_id = value

    @rx.event
    def set_contragent_to_id(self, value: str):
        self.contragent_to_id = value

    @rx.var
    def contragent_list(self) -> list[tuple[str, str]]:
        with SessionLocal() as session:
            sql = text("""
                SELECT 
                    c.contragent_id, 
                    c.code, 
                    c.contragent_name, 
                    COALESCE(ad.address_name, cp."Адрес", '—') AS address_name
                FROM dicts.contragents c
                LEFT JOIN dicts.addresses ad ON c.address_id = ad.id
                LEFT JOIN dicts.counterperyid_t_flw_037_3006 cp ON c.code = cp."CtrCode"
                ORDER BY c.code DESC NULLS LAST
            """)
            rows = session.execute(sql).fetchall()
            return [
                (
                    str(r.contragent_id), 
                    f"{r.contragent_name or '—'} | {r.contragent_name or '—'} | {r.address_name or '—'} | {r.code if r.code is not None else '—'}"
                ) 
                for r in rows
            ]

    @rx.var
    def filtered_contragents(self) -> list[tuple[str, str]]:
        if not self.search_text:
            return self.contragent_list
        search = self.search_text.lower()
        return [item for item in self.contragent_list if search in item[1].lower()]

    @rx.event
    def handle_submit(self, form_data: dict):
        raw_amount = form_data.get("amount", "").strip().replace(",", ".")
        if not raw_amount:
            return rx.toast.error("Сумма не заполнена!")

        try:
            valid_amount = float(raw_amount)
        except (ValueError, TypeError):
            return rx.toast.error("Некорректный формат суммы!")

        import uuid

        with SessionLocal() as session:
            def get_uuid_by_field(model, field_name: str, val: str):
                if not val or not val.strip():
                    return None
                row = session.execute(
                    select(model).where(getattr(model, field_name) == val)
                ).scalars().first()
                return row.id if row else None

            status_row = session.execute(
                select(DictStatus).where(
                    DictStatus.entity_type == "TRANSACTION",
                    DictStatus.code == "NEED_REVIEW"
                )
            ).scalars().first()
            status_uuid = status_row.id if status_row else None

            currency_row = session.execute(
                select(DictsCurrency).where(DictsCurrency.currency_id == "KZT")
            ).scalars().first()
            currency_uuid = currency_row.id if currency_row else None

            resp_code = form_data.get("responsible_id", "RSP-001")
            responsible_row = session.execute(
                select(Responsible).where(Responsible.responsible_id == resp_code)
            ).scalars().first()
            responsible_uuid = responsible_row.id if responsible_row else None

            new_tx = StagingTransaction(
                id=uuid.uuid4(),
                transaction_name=form_data.get("transaction_name"),
                amount=round(valid_amount, 2),
                contragent_from_id=get_uuid_by_field(Contragent, "contragent_id", self.contragent_from_id),
                contragent_to_id=get_uuid_by_field(Contragent, "contragent_id", self.contragent_to_id),
                category_id=get_uuid_by_field(DictCategory, "category_id", self.category_id),
                account_id=get_uuid_by_field(Account, "account_id", self.account_id),
                type_id=get_uuid_by_field(DictType, "type_id", self.type_id),
                entity_id=get_uuid_by_field(Entity, "entity_id", self.entity_id),
                operation_date=form_data.get("operation_date") or None,
                operation_time=form_data.get("operation_time") or None,
                status_id=status_uuid,
                source_extraction_id=uuid.UUID("5d345cf0-a116-4f4d-a31e-84125f556212"),
                responsible_id=responsible_uuid,
                currency_id=currency_uuid,
                created_at=datetime.now(),
                registration_date=date.today(),
            )

            session.add(new_tx)
            session.commit()

        self.load_staging_transactions()
        return rx.window_alert("Запись с контрагентами ушла в staging!")

    @rx.event
    def create_transaction(self, form_data: dict):
        tx_name = form_data.get("transaction_name")
        amount_str = form_data.get("amount", "0")
        
        try:
            amount = float(amount_str.replace(",", "."))
        except ValueError:
            return rx.window_alert("Ошибка: Значение в поле 'Сумма' должно быть числом!")

        if not tx_name:
            return rx.window_alert("Ошибка: Название транзакции не заполнено!")

        new_transaction = Transaction(
            transaction_name=tx_name,
            amount=amount
        )

        with SessionLocal() as session:
            session.add(new_transaction)
            session.commit()
            
        return rx.window_alert("Транзакция успешно создана!")

class SnapshotRegisterState(rx.State):
    code: int = 1
    account_id: str = ""
    tr_id: str = ""
    balance: int | float = 0
    search_text: str = ""

    @rx.event
    def set_search_text(self, value: str):
        self.search_text = value

    @rx.event
    def set_account_id(self, value: str):
        self.account_id = value

    @rx.var
    def account_list(self) -> list[tuple[str, str]]:
        with SessionLocal() as session:
            stmt = select(Account).order_by(desc(Account.code))
            rows = session.execute(stmt).scalars().all()
            return [(str(r.account_id), r.account_name) for r in rows]

    @rx.var
    def filtered_accounts(self) -> list[tuple[str, str]]:
        if not self.search_text:
            return self.account_list
        return [item for item in self.account_list if self.search_text.lower() in item[1].lower()]

    @rx.event
    def load_snapshots(self):
        with SessionLocal() as session:
            max_code = session.execute(select(func.max(AccBalanceSnapshot.code))).scalar()
            self.code = (max_code or 45) + 1

    @rx.event
    def handle_submit(self, form_data: dict):
        try:
            valid_balance = int(form_data.get("balance", 0))
        except (ValueError, TypeError):
            return rx.toast.error("Некорректный формат баланса!")

        import datetime
        import uuid

        insert_values = {
            "code": self.code,
            "account_id": self.account_id if self.account_id else None,
            "tr_id": form_data.get("tr_id"),
            "balance": valid_balance,
            "registration_date": datetime.date.today(),
            "created_at": datetime.datetime.now(),
            "id": uuid.uuid4(),
        }

        with SessionLocal() as session:
            session.execute(insert(AccBalanceSnapshot).values(**insert_values))
            session.commit()

        self.load_snapshots()
        return rx.window_alert("Снимок баланса успешно записан!")

class ReportState(rx.State):
    report_data: list[dict] = []

    @rx.event
    def load_report(self):
        with SessionLocal() as session:
            sql_query = text("""
                SELECT 
                    r.account_id, 
                    r.account_name, 
                    r.balance, 
                    r.account_balance_status, 
                    r.last_updated, 
                    e.entity_name,
                    dc.currency_id 
                FROM reports.v_active_account_report r
                LEFT JOIN dicts.accounts a ON r.account_id = a.account_id
                LEFT JOIN dicts.entities e ON a.entity_id = e.entity_id
                LEFT JOIN dicts.dicts_currencies dc ON a.currency = dc.id
            """)
            results = session.execute(sql_query).fetchall()
            
            self.report_data = [
                {
                    "account_id": str(row.account_id),
                    "account_name": str(row.account_name),
                    "balance": f"{float(row.balance):.2f}" if row.balance is not None else "0.00",
                    "account_balance_status": str(row.account_balance_status),
                    "last_updated": str(row.last_updated),
                    "entity_name": str(row.entity_name).strip() if row.entity_name and str(row.entity_name).strip() != 'None' else "—",
                    "currency_id": str(row.currency_id).strip() if row.currency_id and str(row.currency_id).strip() != 'None' else "—"
                }
                for row in results
            ]


class SummaryReportState(rx.State):
    report_data: list[dict] = []
    selected_month: str = datetime.now().strftime("%Y-%m")
    current_tab: str = "entity"

    total_amount_str: str = "0.00 KZT"
    total_count_str: str = "0 шт."

    @rx.var
    def first_column_header(self) -> str:
        headers = {
            "entity": "Направленность",
            "contragent": "Контрагент",
            "category": "Категория",
            "account": "Счет",
        }
        return headers.get(self.current_tab, "Направленность")

    @rx.var
    def second_column_header(self) -> str:
        headers = {
            "entity": "Категория",
            "contragent": "Адрес",
            "category": "Родительская категория",
            "account": "Направленность",
        }
        return headers.get(self.current_tab, "Категория")

    @rx.event
    def set_selected_month(self, month: str):
        self.selected_month = month
        return SummaryReportState.load_summary_report

    @rx.event
    def change_tab(self, tab_name: str):
        self.current_tab = tab_name
        return SummaryReportState.load_summary_report

    @rx.event
    def load_summary_report(self):
        try:
            target_date = (
                datetime.strptime(self.selected_month, "%Y-%m").date()
                if self.selected_month
                else date.today()
            )
        except ValueError:
            target_date = date.today()

        if self.current_tab == "entity":
            sql_query = text(
                """
                SELECT 
                    COALESCE(v.entity_name, 'Не указано') AS group_name,
                    COALESCE(cat.category_name, '—') AS attr_val,
                    SUM(v.total_amount) AS total_amount,
                    SUM(v.trans_count) AS trans_count
                FROM reports.v_monthly_transactions_summary v
                LEFT JOIN dicts.entities e ON v.entity_id = e.id
                LEFT JOIN dicts.dict_categories cat ON e.category_id = cat.category_id
                WHERE v.report_month = date_trunc('month', CAST(:target_date AS DATE))
                GROUP BY group_name, attr_val
                ORDER BY total_amount DESC
                """
            )
        elif self.current_tab == "contragent":
            sql_query = text(
                """
                SELECT 
                    COALESCE(v.contragent_name, 'Не указано') AS group_name,
                    COALESCE(a.address_name, '—') AS attr_val,
                    SUM(v.total_amount) AS total_amount,
                    SUM(v.trans_count) AS trans_count
                FROM reports.v_monthly_transactions_summary v
                LEFT JOIN dicts.contragents c ON v.contragent_id = c.id
                LEFT JOIN dicts.addresses a ON c.address_id = a.id
                WHERE v.report_month = date_trunc('month', CAST(:target_date AS DATE))
                GROUP BY group_name, attr_val
                ORDER BY total_amount DESC
                """
            )
        elif self.current_tab == "category":
            sql_query = text(
                """
                SELECT 
                    COALESCE(v.category_name, 'Не указано') AS group_name,
                    COALESCE(pcat.category_name, 'Корневая') AS attr_val,
                    SUM(v.total_amount) AS total_amount,
                    SUM(v.trans_count) AS trans_count
                FROM reports.v_monthly_transactions_summary v
                LEFT JOIN dicts.dict_categories cat ON v.category_id = cat.id
                LEFT JOIN dicts.dict_categories pcat ON cat.parent_category_id = pcat.category_id
                WHERE v.report_month = date_trunc('month', CAST(:target_date AS DATE))
                GROUP BY group_name, attr_val
                ORDER BY total_amount DESC
                """
            )
        else:
            sql_query = text(
                """
                SELECT 
                    COALESCE(v.account_name, 'Не указано') AS group_name,
                    COALESCE(e.entity_name, '—') AS attr_val,
                    SUM(v.total_amount) AS total_amount,
                    SUM(v.trans_count) AS trans_count
                FROM reports.v_monthly_transactions_summary v
                LEFT JOIN dicts.accounts acc ON v.account_id = acc.id
                LEFT JOIN dicts.entities e ON acc.entity_id = e.entity_id
                WHERE v.report_month = date_trunc('month', CAST(:target_date AS DATE))
                GROUP BY group_name, attr_val
                ORDER BY total_amount DESC
                """
            )

        with SessionLocal() as session:
            try:
                results = session.execute(
                    sql_query, {"target_date": target_date}
                ).fetchall()

                total_sum = sum(float(row.total_amount or 0) for row in results)
                total_cnt = sum(int(row.trans_count or 0) for row in results)

                self.total_amount_str = f"{total_sum:,.2f} KZT".replace(",", " ")
                self.total_count_str = f"{total_cnt} шт."

                self.report_data = [
                    {
                        "name": str(row.group_name).strip()
                        if row.group_name and str(row.group_name).strip() != "None"
                        else "Не указано",
                        "attr": str(row.attr_val).strip()
                        if row.attr_val and str(row.attr_val).strip() != "None"
                        else "—",
                        "amount": f"{float(row.total_amount or 0):,.2f} KZT".replace(",", " "),
                        "count": f"{int(row.trans_count or 0)} шт.",
                    }
                    for row in results
                ]
            except Exception as e:
                print(f"[SummaryReport Exception]: {e}")
                self.report_data = []
                self.total_amount_str = "0.00 KZT"
                self.total_count_str = "0 шт."