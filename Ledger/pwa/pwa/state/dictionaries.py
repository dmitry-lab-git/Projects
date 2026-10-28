import reflex as rx
from pwa.db import engine
from pwa.models import Address, Contragent, Merchant, DictStatus, DictCategory, Entity
from sqlalchemy import select, text
import uuid

class DictionariesState(rx.State):
    addresses: list[dict] = []
    merchants: list[dict] = []
    contragents: list[dict] = []
    categories: list[dict] = []
    entities: list[dict] = []

    # Выбранные значения для форм
    selected_address_name: str = ""
    selected_merchant_name: str = ""
    selected_parent_category_name: str = ""
    selected_entity_category_name: str = ""

    # Список опций для селекта адресов: 'code | address_name' (по убыванию кодов)
    @rx.var
    def address_options(self) -> list[str]:
        return [
            f"{a.get('code', 0)} | {a.get('address_name', '')}" 
            for a in self.addresses 
            if a.get("address_name")
        ]

    @rx.var
    def category_options(self) -> list[str]:
        # Сортировка по популярности/упоминаниям уже учтена на уровне SQL-запроса в load_dictionaries
        return [
            f"{cat.get('category_name')} | {cat.get('code')}" 
            for cat in self.categories 
            if cat.get("category_name")
        ]

    @rx.var
    def merchant_names(self) -> list[str]:
        return [m.get("merchant_name", "") for m in self.merchants if m.get("merchant_name")]

    @rx.event
    def set_selected_address_name(self, val: str):
        self.selected_address_name = val

    @rx.event
    def set_selected_merchant_name(self, val: str):
        self.selected_merchant_name = val

    @rx.event
    def set_selected_parent_category_name(self, value: str):
        self.selected_parent_category_name = value

    @rx.event
    def set_selected_entity_category_name(self, value: str):
        self.selected_entity_category_name = value

    @rx.event
    def load_dictionaries(self):
        with engine.connect() as conn:
            # 1. Загрузка адресов с сортировкой по убыванию кодов (сначала новые)
            addrs = conn.execute(select(Address).order_by(Address.code.desc())).mappings().all()
            self.addresses = [
                {
                    "id": str(a["id"]),
                    "code": a["code"],
                    "address_name": a["address_name"] or "",
                    "city": a["city"] or "",
                    "country": a["country"] or "",
                    "created_at": a["created_at"].strftime("%Y-%m-%d %H:%M") if a["created_at"] else "—",
                }
                for a in addrs
            ]

            # 2. Загрузка мерчантов
            merch = conn.execute(select(Merchant).order_by(Merchant.merchant_name)).mappings().all()
            self.merchants = [
                {
                    "id": str(m["id"]),
                    "merchant_name": m["merchant_name"] or "",
                }
                for m in merch
            ]

            # 3. Загрузка категорий с сортировкой по частоте упоминания в транзакциях по убыванию (usage_count DESC)
            cat_query = text("""
                SELECT 
                    id,
                    code,
                    category_name,
                    category_id,
                    parent_category_id,
                    created_at,
                    usage_count
                FROM reports.v_category_usage
                ORDER BY usage_count DESC, code DESC
            """)
            cat_results = conn.execute(cat_query).fetchall()
            self.categories = [
                {
                    "id": str(row.id),
                    "code": row.code,
                    "category_name": str(row.category_name) if row.category_name else "—",
                    "category_id": str(row.category_id) if row.category_id else "—",
                    "parent_category_id": str(row.parent_category_id) if row.parent_category_id else "—",
                    "created_at": row.created_at.strftime("%Y-%m-%d %H:%M") if row.created_at else "—",
                }
                for row in cat_results
            ]

            # 4. Загрузка направленностей (Entities)
            ent_query = text("""
                SELECT 
                    e.id,
                    e.code,
                    e.entity_name,
                    e.entity_id,
                    e.category_id,
                    e.created_at
                FROM dicts.entities e
                ORDER BY e.code DESC
            """)
            ent_results = conn.execute(ent_query).fetchall()
            self.entities = [
                {
                    "id": str(row.id),
                    "code": row.code,
                    "entity_name": str(row.entity_name) if row.entity_name else "—",
                    "entity_id": str(row.entity_id) if row.entity_id else "—",
                    "category_id": str(row.category_id) if row.category_id else "—",
                    "created_at": row.created_at.strftime("%Y-%m-%d %H:%M") if row.created_at else "—",
                }
                for row in ent_results
            ]

            # 5. Загрузка контрагентов с полями code и created_at (DESC)
            query = text("""
                SELECT 
                    c.id,
                    c.code,
                    c.contragent_name,
                    c.contragent_type,
                    c.description,
                    a.address_name,
                    m.merchant_name,
                    c.created_at
                FROM dicts.contragents c
                LEFT JOIN dicts.addresses a ON c.address_id = a.id
                LEFT JOIN dicts.merchants m ON c.merchant_id = m.id
                ORDER BY c.code DESC
                LIMIT 50
            """)
            results = conn.execute(query).fetchall()
            self.contragents = [
                {
                    "id": str(row.id),
                    "code": row.code if row.code else 0,
                    "contragent_name": str(row.contragent_name) if row.contragent_name else "—",
                    "contragent_type": str(row.contragent_type) if row.contragent_type else "—",
                    "description": str(row.description) if row.description else "—",
                    "address_name": str(row.address_name) if row.address_name else "—",
                    "merchant_name": str(row.merchant_name) if row.merchant_name else "—",
                    "created_at": row.created_at.strftime("%Y-%m-%d %H:%M") if row.created_at else "—",
                }
                for row in results
            ]

    @rx.event
    def add_address(self, form_data: dict):
        with engine.begin() as conn:
            status_res = conn.execute(
                select(DictStatus.id).where(DictStatus.entity_type == "addresses").limit(1)
            ).scalar()
            
            conn.execute(
                Address.__table__.insert().values(
                    id=uuid.uuid4(),
                    address_name=form_data.get("address_name"),
                    city=form_data.get("city"),
                    country=form_data.get("country"),
                    status_id=status_res or uuid.UUID("1e604e11-8e44-4da3-beb2-369a0113ffdf")
                )
            )
        self.load_dictionaries()
        return rx.window_alert("Адрес успешно добавлен!")

    @rx.event
    def add_merchant(self, form_data: dict):
        with engine.begin() as conn:
            status_res = conn.execute(
                select(DictStatus.id).where(DictStatus.entity_type == "merchants").limit(1)
            ).scalar()

            conn.execute(
                Merchant.__table__.insert().values(
                    id=uuid.uuid4(),
                    merchant_name=form_data.get("merchant_name"),
                    status_id=status_res or uuid.UUID("1e604e11-8e44-4da3-beb2-369a0113ffdf")
                )
            )
        self.load_dictionaries()
        return rx.window_alert("Мерчант успешно добавлен!")

    @rx.event
    def add_contragent(self, form_data: dict):
        selected_option = self.selected_address_name
        addr = None
        if selected_option and " | " in selected_option:
            try:
                parts = selected_option.split(" | ")
                parsed_code = int(parts[0])
                addr = next((a for a in self.addresses if a.get("code") == parsed_code), None)
            except (ValueError, IndexError):
                addr = None

        merch_name = self.selected_merchant_name
        merch = next((m for m in self.merchants if m.get("merchant_name") == merch_name), None)

        with engine.begin() as conn:
            status_res = conn.execute(
                select(DictStatus.id).where(DictStatus.entity_type == "contragents").limit(1)
            ).scalar()

            conn.execute(
                Contragent.__table__.insert().values(
                    id=uuid.uuid4(),
                    contragent_name=form_data.get("contragent_name"),
                    contragent_type=form_data.get("contragent_type"),
                    description=form_data.get("description"),
                    address_id=uuid.UUID(addr["id"]) if addr else None,
                    merchant_id=uuid.UUID(merch["id"]) if merch else None,
                    status_id=status_res or uuid.UUID("1e604e11-8e44-4da3-beb2-369a0113ffdf")
                )
            )

        self.selected_address_name = ""
        self.selected_merchant_name = ""
        self.load_dictionaries()
        return rx.window_alert("Контрагент успешно добавлен!")

    @rx.event
    def add_category(self, form_data: dict):
        # Обработка выбора родительской категории в формате "name | code"
        parent_cat_id = None
        selected_option = self.selected_parent_category_name
        if selected_option and " | " in selected_option:
            try:
                parts = selected_option.split(" | ")
                parsed_code = int(parts[1])  # code идет после разделителя
                parent_cat = next((c for c in self.categories if c.get("code") == parsed_code), None)
                if parent_cat:
                    parent_cat_id = parent_cat.get("category_id") # или parent_cat.get("id") в зависимости от структуры
            except (ValueError, IndexError):
                pass

        with engine.begin() as conn:
            status_res = conn.execute(
                select(DictStatus.id).where(DictStatus.entity_type == "dict_categories").limit(1)
            ).scalar()

            conn.execute(
                DictCategory.__table__.insert().values(
                    id=uuid.uuid4(),
                    category_name=form_data.get("category_name"),
                    parent_category_id=parent_cat_id,
                    status_id=status_res or uuid.UUID("1e604e11-8e44-4da3-beb2-369a0113ffdf")
                )
            )

        self.selected_parent_category_name = ""
        self.load_dictionaries()
        return rx.window_alert("Категория успешно добавлена!")

    @rx.event
    def add_entity(self, form_data: dict):
        # Обработка выбора категории для направленности
        cat_id_val = None
        selected_option = self.selected_entity_category_name
        if selected_option and " | " in selected_option:
            try:
                parts = selected_option.split(" | ")
                parsed_code = int(parts[1])
                parent_cat = next((c for c in self.categories if c.get("code") == parsed_code), None)
                if parent_cat:
                    cat_id_val = parent_cat.get("category_id")
            except (ValueError, IndexError):
                pass

        with engine.begin() as conn:
            status_res = conn.execute(
                select(DictStatus.id).where(DictStatus.entity_type == "entities").limit(1)
            ).scalar()

            conn.execute(
                Entity.__table__.insert().values(
                    id=uuid.uuid4(),
                    entity_name=form_data.get("entity_name"),
                    category_id=cat_id_val,
                    status_id=status_res or uuid.UUID("1e604e11-8e44-4da3-beb2-369a0113ffdf")
                )
            )

        self.selected_entity_category_name = ""
        self.load_dictionaries()
        return rx.window_alert("Направленность успешно добавлена!")