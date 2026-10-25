import reflex as rx
from pwa.db import engine
from pwa.models import Address, Contragent, Merchant, DictStatus
from sqlalchemy import select, text
import uuid

class DictionariesState(rx.State):
    addresses: list[dict] = []
    merchants: list[dict] = []
    contragents: list[dict] = []

    # Выбранные значения для форм
    selected_address_name: str = ""
    selected_merchant_name: str = ""

    # Списки имен для селектов
    @rx.var
    def address_names(self) -> list[str]:
        return [a.get("address_name", "") for a in self.addresses if a.get("address_name")]

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
    def load_dictionaries(self):
        with engine.connect() as conn:
            # 1. Загрузка адресов
            addrs = conn.execute(select(Address).order_by(Address.address_name)).mappings().all()
            self.addresses = [
                {
                    "id": str(a["id"]),
                    "address_name": a["address_name"] or "",
                    "city": a["city"] or "",
                    "country": a["country"] or "",
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

            # 3. Загрузка контрагентов с привязанными именами
            query = text("""
                SELECT 
                    c.id,
                    c.contragent_name,
                    c.contragent_type,
                    c.description,
                    a.address_name,
                    m.merchant_name,
                    c.created_at
                FROM dicts.contragents c
                LEFT JOIN dicts.addresses a ON c.address_id = a.id
                LEFT JOIN dicts.merchants m ON c.merchant_id = m.id
                ORDER BY c.created_at DESC
                LIMIT 50
            """)
            results = conn.execute(query).fetchall()
            self.contragents = [
                {
                    "id": str(row.id),
                    "contragent_name": str(row.contragent_name) if row.contragent_name else "—",
                    "contragent_type": str(row.contragent_type) if row.contragent_type else "—",
                    "description": str(row.description) if row.description else "—",
                    "address_name": str(row.address_name) if row.address_name else "—",
                    "merchant_name": str(row.merchant_name) if row.merchant_name else "—",
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
        addr_name = self.selected_address_name
        merch_name = self.selected_merchant_name

        addr = next((a for a in self.addresses if a.get("address_name") == addr_name), None)
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
                    address_id=addr["id"] if addr else None,
                    merchant_id=merch["id"] if merch else None,
                    status_id=status_res or uuid.UUID("1e604e11-8e44-4da3-beb2-369a0113ffdf")
                )
            )

        self.selected_address_name = ""
        self.selected_merchant_name = ""
        self.load_dictionaries()
        return rx.window_alert("Контрагент успешно добавлен!")
