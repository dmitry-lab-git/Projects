from datetime import datetime
from typing import Optional
from uuid import UUID  # ДОБАВЛЕНО
from pydantic import BaseModel, Field
from sqlalchemy import Column, String, DateTime, Boolean, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

# =====================================================================
# 1. СЛОЙ ОРМ (SQLAlchemy)
# =====================================================================
class TimeTrackerORM(Base):
    __tablename__ = "time_tracker"
    __table_args__ = {"schema": "infrastructure"}

    id = Column(PG_UUID(as_uuid=True), primary_key=True, nullable=False)
    task_name = Column(String(255), nullable=False)
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=True)
    comment = Column(String, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=text("now()"), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=text("now()"), onupdate=text("now()"), nullable=False)
    is_deleted = Column(Boolean, default=False, nullable=False)


# =====================================================================
# 2. СХЕМА ИНТЕРФЕЙСА (Pydantic)
# =====================================================================
class TimeEntryItem(BaseModel):
    id: UUID  # ИСПРАВЛЕНО: UUID вместо str для прохождения валидации from_orm
    task_name: str = Field(..., max_length=255)
    start_time: datetime
    end_time: Optional[datetime] = None
    comment: Optional[str] = None
    is_deleted: bool = False
    updated_at: datetime

    class Config:
        from_attributes = True
