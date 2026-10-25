from typing import Optional
from datetime import datetime, date
from uuid import UUID as PyUUID
from sqlmodel import SQLModel, Field, Column, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import DateTime, String, Numeric, Date, ForeignKey, Text

class ResourceCatalog(SQLModel, table=True):
    __tablename__ = "resource_catalog"
    __table_args__ = {"schema": "infrastructure", "extend_existing": True}

    id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    )
    material_name: str
    resource_type: Optional[str] = None
    default_unit: Optional[str] = None
    container_type: Optional[str] = None  # <--- Добавленное поле для тары
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))

class MaterialDisposition(SQLModel, table=True):
    __tablename__ = "material_disposition"
    __table_args__ = {"schema": "infrastructure", "extend_existing": True}

    id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    )
    resource_id: PyUUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), ForeignKey("infrastructure.resource_catalog.id"), nullable=False)
    )
    quantity: float = Field(sa_column=Column(Numeric(15, 3), nullable=False))
    device_id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), ForeignKey("infrastructure.measuring_devices.id"), nullable=True)
    )
    weighing_type: str = Field(
        sa_column=Column(String(50), nullable=False, server_default=text("'gross'"))
    )
    # <-- ДОБАВЛЕНО НОВОЕ ПОЛЕ:
    disposal_point: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), ForeignKey("infrastructure.disposition_points.id"), nullable=True)
    )
    utilized_at: Optional[date] = Field(sa_column=Column(Date, server_default=text("CURRENT_TIMESTAMP")))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))

class MeasuringDevice(SQLModel, table=True):
    __tablename__ = "measuring_devices"
    __table_args__ = {"schema": "infrastructure", "extend_existing": True}

    id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    )
    device_name: str = Field(sa_column=Column(String(255), nullable=False))
    max_weight: Optional[float] = Field(sa_column=Column(Numeric(15, 3)))
    unit: Optional[str] = Field(sa_column=Column(String(50)))
    uncertainty: Optional[float] = Field(sa_column=Column(Numeric(10, 4)))
    created_at: Optional[datetime] = Field(sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP")))

class DisposalPoint(SQLModel, table=True):
    __tablename__ = "disposal_points"
    __table_args__ = {"schema": "infrastructure"}

    id: Optional[PyUUID] = Field(default=None, primary_key=True)
    name: Optional[str] = Field(default=None)
    type: Optional[str] = Field(default=None)
    coordinates: str = Field(sa_column=Column(Text, nullable=False))
    created_at: Optional[datetime] = Field(default=None)
    contragent_id: Optional[PyUUID] = Field(default=None)

    @property
    def display_name(self) -> str:
        if self.name and self.type:
            return f"{self.name} I {self.type}"
        return self.name or self.type or ""