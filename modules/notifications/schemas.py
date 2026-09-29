from datetime import datetime
from typing import Any, Dict, Optional
from pydantic import BaseModel, ConfigDict, Field


class NotificationBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    message: str = Field(..., min_length=1)
    severity: str = Field("INFO", description="INFO, WARNING, or CRITICAL")
    category: str = Field("SYSTEM", description="COMPANY_EXPIRY, ACID_EXPIRY, DUTY_PAYMENT, SYSTEM")
    entity_type: Optional[str] = None
    entity_id: Optional[int] = None
    target_role: str = Field("ALL", description="ALL, ADMIN, MANAGER, OPERATOR")


class NotificationCreate(NotificationBase):
    pass


class NotificationResponse(NotificationBase):
    notification_id: int
    is_read: bool
    msg_code: Optional[str] = None
    msg_params: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class NotificationSummary(BaseModel):
    unread_count: int
    total_count: int
    critical_count: int
    warning_count: int
