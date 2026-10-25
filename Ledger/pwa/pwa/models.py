from sqlmodel import SQLModel, Field
from sqlalchemy import Table, Column, Integer, String, Float, MetaData, Date, Numeric, text, Text, ARRAY, Time, DateTime, MetaData
from sqlalchemy.dialects.postgresql import UUID
from typing import Optional, List
import uuid
import datetime
from decimal import Decimal

metadata = MetaData()

# ==========================================
# Существующая таблица (schema = public по умолчанию) +
# ==========================================
transaction_table = Table(
    "transactions",
    metadata,
    Column("code", Integer, primary_key=True),
    Column("transaction_name", String),
    Column("amount", Float),
    extend_existing=True,
)

# ==========================================
# НОВЫЕ СПРАВОЧНИКИ (schema = "dicts")
# ==========================================

# 1. Accounts +
accounts_table = Table(
    "accounts", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("code", Integer),
    Column("account_name", String(50)),
    Column("account_id", String(50)),
    Column("entity_id", String(50)),
    Column("opening_date", Date),
    Column("keywords", Text),
    Column("created_at", DateTime(timezone=True)),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    schema="dicts", extend_existing=True
)

# 2. Addresses +
addresses_table = Table(
    "addresses", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("code", Integer),
    Column("adress_name", String(64)),
    Column("address_id", String(50)),
    Column("external_status", String(50)),
    Column("observed_at", String(50)),
    Column("city", String(50)),
    Column("country", String(50)),
    Column("created_at", DateTime(timezone=True)),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    schema="dicts", extend_existing=True
)

# 3. Contragents +
contragents_table = Table(
    "contragents", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("code", Integer, nullable=False),
    Column("contragent_name", String(50)),
    Column("contragent_id", String(50)),
    Column("contragent_type", String(50)),
    Column("description", String(512)),
    Column("address_id", UUID(as_uuid=True)),
    Column("keywords", ARRAY(String)),
    Column("created_at", DateTime(timezone=True)),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    schema="dicts", extend_existing=True
)

# 4. Dict Categories +
dict_categories_table = Table(
    "dict_categories", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("code", Integer, nullable=False),
    Column("category_name", String(255), nullable=False),
    Column("category_id", String(50), nullable=False),
    Column("parent_category_id", String(50)),
    Column("keywords", ARRAY(String)),
    Column("created_at", DateTime(timezone=True)),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    schema="dicts", extend_existing=True
)

# 5. Dict Ledger Versions +
dict_ledger_versions_table = Table(
    "dict_ledger_versions", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("code", Integer, nullable=False),
    Column("version_name", Text, nullable=False),
    Column("version_code", Text, nullable=False),
    Column("registration_date", Date, nullable=False),
    Column("description", Text),
    Column("created_at", DateTime(timezone=True)),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    schema="dicts", extend_existing=True
)

# 6. Dict Types +
dict_types_table = Table(
    "dict_types", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("code", Integer),
    Column("type_name", String(50)),
    Column("type_id", String(50)),
    Column("net_value_effect", String(50)),
    Column("account_effect", Numeric),
    Column("needs_entity", String(50)),
    Column("needs_project", String(50)),
    Column("created_at", DateTime(timezone=True)),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    schema="dicts", extend_existing=True
)

# 7. Entities +
entities_table = Table(
    "entities", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("code", Integer),
    Column("entity_name", String(50)),
    Column("entity_id", String(50)),
    Column("category_id", String(50)),
    Column("keywords", ARRAY(String)),
    Column("created_at", DateTime(timezone=True)),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    schema="dicts", extend_existing=True
)

# 8. Responsibles +
responsibles_table = Table(
    "responsibles", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("code", Integer),
    Column("resp_name", String(50)),
    Column("responsible_id", String(50)),
    Column("created_at", DateTime(timezone=True)),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    schema="dicts", extend_existing=True
)
# 9. Staging +
staging_table = Table(
    "staging_transactions",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")),
    Column("source_extraction_id", UUID(as_uuid=True), nullable=False),
    Column("status_id_str", String(20), server_default=text("'NEW'::character varying")),
    Column("created_at", DateTime, server_default=text("CURRENT_TIMESTAMP")),
    Column("transaction_name", String(512)),
    Column("entity_id_str", String(50)),
    Column("registration_date", Date),
    Column("operation_date", Date),
    Column("category_id_str", String(50)),
    Column("responsible_id_str", String(50)),
    Column("contragent_from_id_str", String(50)),
    Column("contragent_to_id_str", String(50)),
    Column("account_id_str", String(50)),
    Column("type_id_str", String(50)),
    Column("amount", Numeric(15, 2)),
    Column("currency_id_str", String(50)),
    Column("operation_time", Time),
    Column("code", Integer),
    schema="audit",
    extend_existing=True,
)
# 10. Snapshot +
acc_balance_snapshot_register = Table(
    "acc_balance_snapshot_register", metadata,
    Column("code", Integer, primary_key=True, nullable=False),
    Column("account_id", String(50), nullable=True),
    Column("tr_id", String(50), nullable=True),
    Column("balance", Integer, nullable=True),
    Column("registration_date", Date, server_default=text("CURRENT_TIMESTAMP"), nullable=True),
    Column("created_at", DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=True),
    Column("id", UUID(as_uuid=True), server_default=text("gen_random_uuid()"), nullable=True),
    schema="public",
    extend_existing=True
)

# 11. Receipts +
receipts_table = Table(
    "receipts", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("status_id", UUID(as_uuid=True), nullable=False),
    Column("amount", Numeric(15, 2)),
    Column("operation_date", Date),
    Column("operation_time", Time),
    # ... остальные поля по схеме
    schema="processing", extend_existing=True
)

# 12. Statuses +
dict_statuses_table = Table(
    "dict_statuses", metadata,
    Column("id", UUID(as_uuid=True), primary_key=True),
    Column("entity_type", String(50), nullable=False),
    Column("code", String(20), nullable=False),
    Column("name", String(100), nullable=False),
    schema="dicts", extend_existing=True
)
