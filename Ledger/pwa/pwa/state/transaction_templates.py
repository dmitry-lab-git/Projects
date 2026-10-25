import reflex as rx
from sqlmodel import select
from pwa.models.transactions import TransactionTemplate
from pwa.models.dicts import (
    Contragent,
    DictCategory as Category,
    Entity,
    Account,
    DictType as TransactionType,
    DictStatus as TransactionStatus,
)

class TransactionTemplateState(rx.State):
    selected_template_id: str = ""
    transaction_name: str = ""
    contragent_from_id: str = ""
    contragent_to_id: str = ""
    category_id: str = ""
    entity_id: str = ""
    account_id: str = ""
    type_id: str = ""
    status_id: str = ""
    amount: str = ""
    
    templates: list[dict] = []
    template_options: list[tuple[str, str]] = []
    
    filtered_contragents: list[tuple[str, str]] = []
    filtered_categories: list[tuple[str, str]] = []
    filtered_entities: list[tuple[str, str]] = []
    filtered_accounts: list[tuple[str, str]] = []
    filtered_types: list[tuple[str, str]] = []
    filtered_statuses: list[tuple[str, str]] = []

    # Явные сеттеры для всех полей формы
    @rx.event
    def set_transaction_name(self, value: str):
        self.transaction_name = value

    @rx.event
    def set_amount(self, value: str):
        self.amount = value

    @rx.event
    def set_contragent_from_id(self, value: str):
        self.contragent_from_id = value

    @rx.event
    def set_contragent_to_id(self, value: str):
        self.contragent_to_id = value

    @rx.event
    def set_category_id(self, value: str):
        self.category_id = value

    @rx.event
    def set_entity_id(self, value: str):
        self.entity_id = value

    @rx.event
    def set_account_id(self, value: str):
        self.account_id = value

    @rx.event
    def set_type_id(self, value: str):
        self.type_id = value

    @rx.event
    def set_status_id(self, value: str):
        self.status_id = value

    def load_templates(self):
        with rx.session() as session:
            # Загружаем шаблоны
            db_templates = session.exec(select(TransactionTemplate)).all()
            self.templates = [
                {
                    "id": str(t.id),
                    "transaction_name": t.transaction_name,
                    "amount": str(t.amount) if t.amount is not None else "",
                    "contragent_from_id": str(t.contragent_from_id) if t.contragent_from_id else "",
                    "contragent_to_id": str(t.contragent_to_id) if t.contragent_to_id else "",
                    "category_id": str(t.category_id) if t.category_id else "",
                    "entity_id": str(t.entity_id) if t.entity_id else "",
                    "account_id": str(t.account_id) if t.account_id else "",
                    "type_id": str(t.type_id) if t.type_id else "",
                    "status_id": str(t.status_id) if t.status_id else "",
                }
                for t in db_templates
            ]
            self.template_options = [(str(t.id), t.transaction_name) for t in db_templates]

            # Загружаем справочники
            self.filtered_contragents = [(str(c.id), c.contragent_name) for c in session.exec(select(Contragent)).all()]
            self.filtered_categories = [(str(c.id), c.category_name) for c in session.exec(select(Category)).all()]
            self.filtered_entities = [(str(e.id), e.entity_name) for e in session.exec(select(Entity)).all()]
            self.filtered_accounts = [(str(a.id), a.account_name) for a in session.exec(select(Account)).all()]
            self.filtered_types = [(str(t.id), t.type_name) for t in session.exec(select(TransactionType)).all()]
            self.filtered_statuses = [(str(s.id), s.name) for s in session.exec(select(TransactionStatus)).all()]

    @rx.event
    def select_template(self, template_id: str):
        if not template_id:
            return
        self.selected_template_id = str(template_id)
        with rx.session() as session:
            template = session.get(TransactionTemplate, template_id)
            if template:
                self.transaction_name = template.transaction_name or ""
                self.amount = str(template.amount) if template.amount is not None else ""
                self.contragent_from_id = str(template.contragent_from_id) if template.contragent_from_id else ""
                self.contragent_to_id = str(template.contragent_to_id) if template.contragent_to_id else ""
                self.category_id = str(template.category_id) if template.category_id else ""
                self.entity_id = str(template.entity_id) if template.entity_id else ""
                self.account_id = str(template.account_id) if template.account_id else ""
                self.type_id = str(template.type_id) if template.type_id else ""
                self.status_id = str(template.status_id) if template.status_id else ""

    @rx.event
    def create_template(self, form_data: dict):
        with rx.session() as session:
            new_template = TransactionTemplate(
                transaction_name=self.transaction_name,
                amount=float(self.amount) if self.amount else None,
                contragent_from_id=self.contragent_from_id if self.contragent_from_id else None,
                contragent_to_id=self.contragent_to_id if self.contragent_to_id else None,
                category_id=self.category_id if self.category_id else None,
                entity_id=self.entity_id if self.entity_id else None,
                account_id=self.account_id if self.account_id else None,
                type_id=self.type_id if self.type_id else None,
                status_id=self.status_id if self.status_id else None,
            )
            session.add(new_template)
            session.commit()
            
        # Очистка полей после успешного сохранения
        self.selected_template_id = ""
        self.transaction_name = ""
        self.contragent_from_id = ""
        self.contragent_to_id = ""
        self.category_id = ""
        self.entity_id = ""
        self.account_id = ""
        self.type_id = ""
        self.status_id = ""
        self.amount = ""

        # Перезагружаем список
        self.load_templates()