from typing import Optional
from datetime import datetime, date
from uuid import UUID as PyUUID
from sqlmodel import SQLModel, Field, Column, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import DateTime, String, Integer, Date, ForeignKey, Text

class SupplementCatalog(SQLModel, table=True):
    __tablename__ = "supplements"
    __table_args__ = {"schema": "medicine", "extend_existing": True}

    id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    )
    name: str = Field(sa_column=Column(String(255), nullable=False))
    brand: Optional[str] = Field(sa_column=Column(String(255)))
    unit_type: str = Field(sa_column=Column(String(50), nullable=False, server_default=text("'таблетка'")))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))


class SupplementIntake(SQLModel, table=True):
    __tablename__ = "intakes"
    __table_args__ = {"schema": "medicine", "extend_existing": True}

    id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    )
    supplement_id: PyUUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), ForeignKey("medicine.supplements.id"), nullable=False)
    )
    intake_date: Optional[date] = Field(
        sa_column=Column(Date, server_default=text("CURRENT_DATE"), nullable=False)
    )
    amount: int = Field(sa_column=Column(Integer, nullable=False, server_default=text("1")))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))


class ObservationLog(SQLModel, table=True):
    __tablename__ = "observations"
    __table_args__ = {"schema": "medicine", "extend_existing": True}

    id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    )
    observation_date: date = Field(sa_column=Column(Date, index=True, nullable=False))
    notes: Optional[str] = Field(sa_column=Column(Text))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))

