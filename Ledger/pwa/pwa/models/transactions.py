from datetime import datetime, date, time
from decimal import Decimal
import uuid
from typing import Optional
from sqlmodel import SQLModel, Field, Column, text
import sqlmodel
from sqlalchemy import ForeignKey, Index, DateTime, Date, Time, String, Integer, Numeric, Text, Float
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from .base import metadata

class Transaction(SQLModel, table=True):
    __tablename__ = "transactions"
    __table_args__ = {"schema": "public", "extend_existing": True}

    code: int = Field(primary_key=True)
    transaction_name: Optional[str] = Field(sa_column=Column(String))
    amount: Optional[float] = Field(sa_column=Column(Float))

class AccBalanceSnapshotRegister(SQLModel, table=True):
    __tablename__ = "acc_balance_snapshot_register"
    __table_args__ = {"schema": "public", "extend_existing": True}

    code: int = Field(primary_key=True)
    account_id: Optional[str] = None
    tr_id: Optional[str] = None
    balance: Optional[int] = None
    registration_date: Optional[date] = Field(sa_column=Column(Date, server_default=text("CURRENT_TIMESTAMP")))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))
    id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), server_default=text("gen_random_uuid()")))
    
class StagingTransaction(SQLModel, table=True):
    __tablename__ = "staging_transactions"
    __table_args__ = (
        Index("idx_staging_v1_1_operation_time", "operation_date", "operation_time"),
        Index("idx_staging_v1_1_status", "status_id"),
        {"schema": "audit", "extend_existing": True},
    )

    id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    )
    source_extraction_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), nullable=False)
    )
    status_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), ForeignKey("dicts.dict_statuses.id"), nullable=True)
    )
    created_at: Optional[datetime] = Field(
        sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"))
    )
    transaction_name: Optional[str] = Field(sa_column=Column(String(512)))
    entity_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), nullable=True)
    )
    registration_date: Optional[date] = Field(sa_column=Column(Date))
    operation_date: Optional[date] = Field(sa_column=Column(Date))
    category_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), nullable=True)
    )
    responsible_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), nullable=True)
    )
    contragent_from_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), nullable=True)
    )
    contragent_to_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), nullable=True)
    )
    account_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), ForeignKey("dicts.accounts.id"), nullable=True)
    )
    type_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), nullable=True)
    )
    amount: Optional[Decimal] = Field(sa_column=Column(Numeric(19, 4)))
    currency_id: Optional[uuid.UUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), nullable=True)
    )
    operation_time: Optional[time] = Field(sa_column=Column(Time))
    code: Optional[int] = Field(default=None, sa_column=Column(Integer))

class TransactionTemplate(sqlmodel.SQLModel, table=True):
    __tablename__ = "transaction_templates"
    __table_args__ = {"schema": "processing", "extend_existing": True}

    id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"), nullable=False)
    )
    transaction_name: str = Field(sa_column=Column(String(150), nullable=False))
    amount: Optional[Decimal] = Field(sa_column=Column(Numeric(15, 2), nullable=True))
    
    currency_id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.dicts_currencies.id", nullable=True))
    type_id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.dict_types.id", nullable=True))
    entity_id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.entities.id", nullable=True))
    category_id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.dict_categories.id", nullable=True))
    responsible_id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.responsibles.id", nullable=True))
    contragent_from_id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.contragents.id", nullable=True))
    contragent_to_id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.contragents.id", nullable=True))
    account_id: Optional[uuid.UUID] = Field(sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.accounts.id", nullable=True))
    
    status_id: uuid.UUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), foreign_key="dicts.dict_statuses.id", nullable=False)
    )
    created_at: Optional[datetime] = Field(
        sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"), nullable=False)
    )