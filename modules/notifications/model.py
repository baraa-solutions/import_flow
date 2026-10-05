from datetime import datetime, timezone
from sqlalchemy import JSON, Boolean, Column, DateTime, Integer, String, Text
from database.database import Base


class SystemNotification(Base):
    __tablename__ = "system_notifications"

    notification_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    title = Column(String(200), nullable=False)
    message = Column(Text, nullable=False)
    severity = Column(String(50), nullable=False, default="INFO", index=True)  # INFO, WARNING, CRITICAL
    category = Column(String(100), nullable=False, default="SYSTEM", index=True)  # COMPANY_EXPIRY, ACID_EXPIRY, DUTY_PAYMENT, SYSTEM
    entity_type = Column(String(100), nullable=True)  # ImportCompany, ImportFile, PurchaseOrder, etc.
    entity_id = Column(Integer, nullable=True)
    target_role = Column(String(50), nullable=False, default="ALL", index=True)  # ALL, ADMIN, MANAGER, OPERATOR
    is_read = Column(Boolean, nullable=False, default=False, index=True)
    msg_code = Column(String(80), nullable=True)  # system message code; title/message hold the English render
    msg_params = Column(JSON, nullable=True)
    
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
