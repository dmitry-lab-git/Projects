# pwa/models/dicts.py
from typing import Optional, List
from uuid import UUID as PyUUID
from datetime import datetime, date
from sqlmodel import SQLModel, Field, Relationship
from sqlalchemy import Column, DateTime, Date, String, Integer, Text, Numeric, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, ARRAY
from .base import metadata

class Account(SQLModel, table=True):
    __tablename__ = "accounts"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True))
    code: Optional[int] = None
    account_name: Optional[str] = Field(sa_column=Column(String(50)))
    account_id: Optional[str] = Field(sa_column=Column(String(50)))
    entity_id: Optional[str] = Field(sa_column=Column(String(50)))
    opening_date: Optional[date] = Field(sa_column=Column(Date))
    keywords: Optional[str] = Field(sa_column=Column(Text))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True)))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False))

class Address(SQLModel, table=True):
    __tablename__ = "addresses"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: Optional[PyUUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")))
    code: Optional[int] = Field(sa_column=Column(Integer, nullable=False))
    address_name: Optional[str] = Field(sa_column=Column(String(64)))
    address_id: Optional[str] = Field(sa_column=Column(String(50)))
    external_status: Optional[str] = Field(sa_column=Column(String(50)))
    observed_at: Optional[str] = Field(sa_column=Column(String(50)))
    city: Optional[str] = Field(sa_column=Column(String(50)))
    country: Optional[str] = Field(sa_column=Column(String(50)))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False, server_default=text("'1e604e11-8e44-4da3-beb2-369a0113ffdf'::uuid")))

class Contragent(SQLModel, table=True):
    __tablename__ = "contragents"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: Optional[PyUUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")))
    code: Optional[int] = Field(sa_column=Column(Integer))
    contragent_name: Optional[str] = Field(sa_column=Column(String(50)))
    contragent_id: Optional[str] = Field(sa_column=Column(String(50)))
    contragent_type: Optional[str] = Field(sa_column=Column(String(50)))
    description: Optional[str] = Field(sa_column=Column(String(512)))
    address_id: Optional[PyUUID] = Field(sa_column=Column(PG_UUID(as_uuid=True)))
    keywords: Optional[List[str]] = Field(sa_column=Column(ARRAY(String)))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False))
    merchant_id: Optional[PyUUID] = Field(sa_column=Column(PG_UUID(as_uuid=True)))
    legal_entity_id: Optional[PyUUID] = Field(sa_column=Column(PG_UUID(as_uuid=True)))

class Merchant(SQLModel, table=True):
    __tablename__ = "merchants"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: Optional[PyUUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")))
    code: Optional[int] = Field(sa_column=Column(Integer))
    merchant_name: str = Field(sa_column=Column(String(100), nullable=False))
    default_legal_entity_id: Optional[PyUUID] = Field(sa_column=Column(PG_UUID(as_uuid=True)))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))

class DictCategory(SQLModel, table=True):
    __tablename__ = "dict_categories"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True))
    code: int = Field(nullable=False)
    category_name: str = Field(sa_column=Column(String(255), nullable=False))
    category_id: str = Field(sa_column=Column(String(50), nullable=False))
    parent_category_id: Optional[str] = Field(sa_column=Column(String(50)))
    keywords: Optional[List[str]] = Field(sa_column=Column(ARRAY(String)))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True)))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False))

class DictLedgerVersion(SQLModel, table=True):
    __tablename__ = "dict_ledger_versions"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True))
    code: int = Field(nullable=False)
    version_name: str = Field(sa_column=Column(Text, nullable=False))
    version_code: str = Field(sa_column=Column(Text, nullable=False))
    registration_date: date = Field(sa_column=Column(Date, nullable=False))
    description: Optional[str] = Field(sa_column=Column(Text))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True)))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False))

class DictType(SQLModel, table=True):
    __tablename__ = "dict_types"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True))
    code: Optional[int] = None
    type_name: Optional[str] = Field(sa_column=Column(String(50)))
    type_id: Optional[str] = Field(sa_column=Column(String(50)))
    net_value_effect: Optional[str] = Field(sa_column=Column(String(50)))
    account_effect: Optional[float] = Field(sa_column=Column(Numeric))
    needs_entity: Optional[str] = Field(sa_column=Column(String(50)))
    needs_project: Optional[str] = Field(sa_column=Column(String(50)))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True)))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False))

class Entity(SQLModel, table=True):
    __tablename__ = "entities"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True))
    code: Optional[int] = None
    entity_name: Optional[str] = Field(sa_column=Column(String(50)))
    entity_id: Optional[str] = Field(sa_column=Column(String(50)))
    category_id: Optional[str] = Field(sa_column=Column(String(50)))
    keywords: Optional[List[str]] = Field(sa_column=Column(ARRAY(String)))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True)))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False))

class Responsible(SQLModel, table=True):
    __tablename__ = "responsibles"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True))
    code: Optional[int] = None
    resp_name: Optional[str] = Field(sa_column=Column(String(50)))
    responsible_id: Optional[str] = Field(sa_column=Column(String(50)))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True)))
    status_id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), nullable=False))

class DictStatus(SQLModel, table=True):
    __tablename__ = "dict_statuses"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True))
    entity_type: str = Field(sa_column=Column(String(50), nullable=False))
    code: str = Field(sa_column=Column(String(20), nullable=False))
    name: str = Field(sa_column=Column(String(100), nullable=False))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))

class DictsCurrency(SQLModel, table=True):
    __tablename__ = "dicts_currencies"
    __table_args__ = {"schema": "dicts", "extend_existing": True}

    id: PyUUID = Field(sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")))
    currency_id: str = Field(sa_column=Column(String(10), nullable=False, unique=True))
    code: Optional[int] = Field(default=None, sa_column=Column(Integer, unique=True))