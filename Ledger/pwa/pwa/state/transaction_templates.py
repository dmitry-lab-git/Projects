import reflex as rx
from sqlmodel import select
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from sqlalchemy import text  # <--- Добавлено для поддержки сырых SQL запросов с JOIN
from pwa.models.transactions import TransactionTemplate, StagingTransaction
from pwa.models.dicts import (
    Contragent,
    DictCategory as Category,
    Entity,
    Account,
    DictType,
    DictsCurrency,
    Responsible,
)

class TransactionTemplateState(rx.State):
    selected_template_id: str = ""
    transaction_name: str = ""
    amount: str = ""
    currency_id: str = "c1edc08f-a70a-4f89-aed4-8b547e7637f3"  # Дефолтная валюта из ТЗ
    type_id: str = ""
    entity_id: str = ""
    category_id: str = ""
    responsible_id: str = "d461b979-31b1-46d5-a1fd-e2165a693902"  # Дефолтный ответственный из ТЗ
    contragent_from_id: str = ""
    contragent_to_id: str = ""
    account_id: str = ""
    
    # Поля для даты и времени операции с галочкой "Текущее"
    operation_date: str = ""
    operation_time: str = ""
    use_current_date: bool = True
    use_current_time: bool = True

    templates: list[dict] = []
    template_options: list[tuple[str, str]] = []

    filtered_contragents: list[tuple[str, str]] = []
    filtered_categories: list[tuple[str, str]] = []
    filtered_entities: list[tuple[str, str]] = []
    filtered_accounts: list[tuple[str, str]] = []
    filtered_types: list[tuple[str, str]] = []
    filtered_currencies: list[tuple[str, str]] = []
    filtered_responsibles: list[tuple[str, str]] = []

    @rx.event
    def set_transaction_name(self, v: str): self.transaction_name = v
    @rx.event
    def set_amount(self, v: str): self.amount = v
    @rx.event
    def set_currency_id(self, v: str): self.currency_id = str(v) if v else ""
    @rx.event
    def set_type_id(self, v: str): self.type_id = str(v) if v else ""
    @rx.event
    def set_entity_id(self, v: str): self.entity_id = str(v) if v else ""
    @rx.event
    def set_category_id(self, v: str): self.category_id = str(v) if v else ""
    @rx.event
    def set_responsible_id(self, v: str): self.responsible_id = str(v) if v else ""
    @rx.event
    def set_contragent_from_id(self, v: str): self.contragent_from_id = str(v) if v else ""
    @rx.event
    def set_contragent_to_id(self, v: str): self.contragent_to_id = str(v) if v else ""
    @rx.event
    def set_account_id(self, v: str): self.account_id = str(v) if v else ""

    @rx.event
    def set_operation_date(self, v: str):
        self.operation_date = v
        self.use_current_date = False

    @rx.event
    def set_operation_time(self, v: str):
        self.operation_time = v
        self.use_current_time = False

    @rx.event
    def toggle_current_date(self, checked: bool):
        self.use_current_date = checked
        if checked:
            self.operation_date = datetime.now().date().isoformat()

    @rx.event
    def toggle_current_time(self, checked: bool):
        self.use_current_time = checked
        if checked:
            self.operation_time = datetime.now().strftime("%H:%M")

    def _set_now_if_checked(self):
        now = datetime.now()
        if self.use_current_date:
            self.operation_date = now.date().isoformat()
        if self.use_current_time:
            self.operation_time = now.strftime("%H:%M")

    @rx.event
    def load_templates(self):
        with rx.session() as session:
            db_templates = session.exec(select(TransactionTemplate)).all()
            self.templates = [
                {
                    "id": str(t.id),
                    "transaction_name": t.transaction_name or "",
                    "amount": str(t.amount) if t.amount is not None else "",
                    "currency_id": str(t.currency_id) if t.currency_id else self.currency_id,
                    "type_id": str(t.type_id) if t.type_id else "",
                    "entity_id": str(t.entity_id) if t.entity_id else "",
                    "category_id": str(t.category_id) if t.category_id else "",
                    "responsible_id": str(t.responsible_id) if t.responsible_id else self.responsible_id,
                    "contragent_from_id": str(t.contragent_from_id) if t.contragent_from_id else "",
                    "contragent_to_id": str(t.contragent_to_id) if t.contragent_to_id else "",
                    "account_id": str(t.account_id) if t.account_id else "",
                }
                for t in db_templates
            ]
            self.template_options = [(str(t.id), t.transaction_name) for t in db_templates]

            # 1. Направленность (Entity): name | category_name | code - отсортировать по убыванию
            entity_rows = session.exec(text("""
                SELECT 
                    e.id, 
                    e.entity_name, 
                    c.category_name, 
                    e.code 
                FROM dicts.entities e 
                LEFT JOIN dicts.dict_categories c ON e.category_id = c.category_id 
                ORDER BY e.code DESC NULLS LAST
            """)).fetchall()
            self.filtered_entities = [
                (str(r[0]), f"{r[1] or '—'} | {r[2] or 'Без категории'} | {r[3] if r[3] is not None else '—'}")
                for r in entity_rows
            ]

            # 2. Категория (Category): name | parent_category_name | code - отсортировать по убыванию
            category_rows = session.exec(text("""
                SELECT 
                    cat.id, 
                    cat.category_name, 
                    p.category_name AS parent_name, 
                    cat.code 
                FROM dicts.dict_categories cat 
                LEFT JOIN dicts.dict_categories p ON cat.parent_category_id = p.category_id 
                ORDER BY cat.code DESC NULLS LAST
            """)).fetchall()
            self.filtered_categories = [
                (str(r[0]), f"{r[1] or '—'} | {r[2] or 'Корневая'} | {r[3] if r[3] is not None else '—'}")
                for r in category_rows
            ]

            # 3. Контрагенты: name | contragent_name | adress | code - отсортировать по убыванию
            contragent_rows = session.exec(text("""
                SELECT 
                    c.id, 
                    c.contragent_name, 
                    COALESCE(ad.address_name, cp."Адрес", '—') AS address_name, 
                    c.code 
                FROM dicts.contragents c
                LEFT JOIN dicts.addresses ad ON c.address_id = ad.id
                LEFT JOIN dicts.counterperyid_t_flw_037_3006 cp ON c.code = cp."CtrCode"
                ORDER BY c.code DESC NULLS LAST
            """)).fetchall()
            self.filtered_contragents = [
                (str(r[0]), f"{r[1] or '—'} | {r[1] or '—'} | {r[2] or '—'} | {r[3] if r[3] is not None else '—'}")
                for r in contragent_rows
            ]

            # 4. Счета (Account): name | account_name | entity_name(entity_id(account_id)) | code - отсортировать по убыванию
            account_rows = session.exec(text("""
                SELECT 
                    a.id, 
                    a.account_name, 
                    e.entity_name, 
                    e.entity_id, 
                    a.account_id, 
                    a.code 
                FROM dicts.accounts a
                LEFT JOIN dicts.entities e ON a.entity_id = e.entity_id
                ORDER BY a.code DESC NULLS LAST
            """)).fetchall()
            self.filtered_accounts = [
                (str(r[0]), f"{r[1] or '—'} | {r[1] or '—'} | {r[2] or '—'}({r[3] or '—'}({r[4] or '—'})) | {r[5] if r[5] is not None else '—'}")
                for r in account_rows
            ]

            # Остальные справочники
            self.filtered_types = [(str(t.id), t.type_name or "") for t in session.exec(select(DictType)).all()]
            self.filtered_currencies = [(str(cur.id), cur.currency_id or "") for cur in session.exec(select(DictsCurrency)).all()]
            self.filtered_responsibles = [(str(r.id), r.resp_name or "") for r in session.exec(select(Responsible)).all()]

        self._set_now_if_checked()

    @rx.event
    def select_template(self, template_id: str | list):
        if isinstance(template_id, list):
            template_id = template_id[0] if template_id else ""
            
        if not template_id:
            return
            
        template_id = str(template_id)
        self.selected_template_id = template_id
        
        tpl = next((t for t in self.templates if t["id"] == template_id), None)
        
        if not tpl:
            with rx.session() as session:
                db_t = session.get(TransactionTemplate, UUID(template_id))
                if db_t:
                    tpl = {
                        "transaction_name": db_t.transaction_name or "",
                        "amount": str(db_t.amount) if db_t.amount is not None else "",
                        "currency_id": str(db_t.currency_id) if db_t.currency_id else self.currency_id,
                        "type_id": str(db_t.type_id) if db_t.type_id else "",
                        "entity_id": str(db_t.entity_id) if db_t.entity_id else "",
                        "category_id": str(db_t.category_id) if db_t.category_id else "",
                        "responsible_id": str(db_t.responsible_id) if db_t.responsible_id else self.responsible_id,
                        "contragent_from_id": str(db_t.contragent_from_id) if db_t.contragent_from_id else "",
                        "contragent_to_id": str(db_t.contragent_to_id) if db_t.contragent_to_id else "",
                        "account_id": str(db_t.account_id) if db_t.account_id else "",
                    }

        if tpl:
            self.transaction_name = tpl.get("transaction_name", "")
            self.amount = tpl.get("amount", "")
            self.currency_id = tpl.get("currency_id", self.currency_id)
            self.type_id = tpl.get("type_id", "")
            self.entity_id = tpl.get("entity_id", "")
            self.category_id = tpl.get("category_id", "")
            self.responsible_id = tpl.get("responsible_id", self.responsible_id)
            self.contragent_from_id = tpl.get("contragent_from_id", "")
            self.contragent_to_id = tpl.get("contragent_to_id", "")
            self.account_id = tpl.get("account_id", "")

        self._set_now_if_checked()

    @rx.event
    def create_template(self, form_data: dict):
        raw_amount = self.amount.replace(",", ".") if self.amount else None
        
        def to_uuid_or_none(val: str):
            return UUID(val) if val and val.strip() else None

        with rx.session() as session:
            new_template = TransactionTemplate(
                transaction_name=self.transaction_name,
                amount=float(raw_amount) if raw_amount else None,
                currency_id=to_uuid_or_none(self.currency_id),
                type_id=to_uuid_or_none(self.type_id),
                entity_id=to_uuid_or_none(self.entity_id),
                category_id=to_uuid_or_none(self.category_id),
                responsible_id=to_uuid_or_none(self.responsible_id),
                contragent_from_id=to_uuid_or_none(self.contragent_from_id),
                contragent_to_id=to_uuid_or_none(self.contragent_to_id),
                account_id=to_uuid_or_none(self.account_id),
                status_id=UUID("63c67651-152d-4b3f-a33d-89d2958b88ba"),
            )
            session.add(new_template)
            session.commit()
            
        self.load_templates()
        return rx.toast.success("Шаблон успешно создан!")

    @rx.event
    def create_staging_transaction(self, form_data: dict):
        self._set_now_if_checked()

        raw_amount = self.amount.replace(",", ".") if self.amount else None
        if not raw_amount:
            return rx.toast.error("Сумма не заполнена!")

        try:
            valid_amount = Decimal(raw_amount)
        except (ValueError, TypeError):
            return rx.toast.error("Некорректный формат суммы!")

        required_fields = [
            (self.type_id, "Тип операции"),
            (self.entity_id, "Направленность операции"),
            (self.category_id, "Категория"),
            (self.responsible_id, "Ответственный"),
            (self.contragent_from_id, "Контрагент донор"),
            (self.contragent_to_id, "Контрагент акцептор"),
            (self.account_id, "Название счета"),
            (self.currency_id, "Валюта")
        ]
        
        for val, name in required_fields:
            if not val or not val.strip():
                return rx.toast.error(f"Поле '{name}' обязательно для заполнения!")

        with rx.session() as session:
            new_staging = StagingTransaction(
                source_extraction_id=UUID("5d345cf0-a116-4f4d-a31e-84125f556212"),
                transaction_name=self.transaction_name,
                amount=valid_amount,
                entity_id=UUID(self.entity_id),
                category_id=UUID(self.category_id),
                responsible_id=UUID(self.responsible_id),
                contragent_from_id=UUID(self.contragent_from_id),
                contragent_to_id=UUID(self.contragent_to_id),
                account_id=UUID(self.account_id),
                type_id=UUID(self.type_id),
                currency_id=UUID(self.currency_id),
                status_id=UUID("dbcb7867-333e-4cac-a2ad-dbf897f1dd73"),
                operation_date=datetime.strptime(self.operation_date, "%Y-%m-%d").date(),
                operation_time=datetime.strptime(self.operation_time, "%H:%M").time() if len(self.operation_time) == 5 else datetime.strptime(self.operation_time, "%H:%M:%S").time(),
                registration_date=datetime.now().date(),
                created_at=datetime.now()
            )
            session.add(new_staging)
            session.commit()
            
        return rx.toast.success("Успешно записано в staging!")