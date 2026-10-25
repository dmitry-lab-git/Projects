from typing import Optional
from datetime import datetime
from uuid import UUID as PyUUID
from sqlmodel import SQLModel, Field, Column, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy import DateTime, String, ForeignKey

# =====================================================================
# БД 1: ledger (движок: pwa.db.engine)
# Таблица: projects.registry
# =====================================================================
class ProjectRegistry(SQLModel, table=True):
    __tablename__ = "registry"
    __table_args__ = {"schema": "projects", "extend_existing": True}

    id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    )
    slug: str = Field(sa_column=Column(String(255), nullable=False))
    status_id: Optional[PyUUID] = Field(
        sa_column=Column(PG_UUID(as_uuid=True), ForeignKey("dicts.dict_statuses.id"), nullable=True)
    )
    created_at: Optional[datetime] = Field(
        sa_column=Column(DateTime(timezone=True), server_default=text("CURRENT_TIMESTAMP"))
    )


# =====================================================================
# БД 2: household (движок: pwa.db.household_engine)
# Таблица: projects.metadata
# =====================================================================
class ProjectMetadata(SQLModel, table=True):
    __tablename__ = "metadata"
    __table_args__ = {"schema": "projects", "extend_existing": True}

    project_id: PyUUID = Field(
        sa_column=Column(PG_UUID(as_uuid=True), primary_key=True, nullable=False)
    )
    title: Optional[str] = Field(sa_column=Column(String(255)))
    meta: Optional[dict] = Field(
        sa_column=Column(JSONB, server_default=text("'{}'::jsonb"))
    )