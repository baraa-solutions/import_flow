from datetime import datetime
from typing import Any, Dict, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from modules.common.system_messages import is_known_code, render_en


class NotificationBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    message: str = Field(..., min_length=1)
    severity: str = Field("INFO", description="INFO, WARNING, or CRITICAL")
    category: str = Field("SYSTEM", description="COMPANY_EXPIRY, ACID_EXPIRY, DUTY_PAYMENT, SYSTEM")
    entity_type: Optional[str] = None
    entity_id: Optional[int] = None
    target_role: str = Field("ALL", description="ALL, ADMIN, MANAGER, OPERATOR")


class NotificationCreate(NotificationBase):
    """``title``/``message`` may be omitted when ``msg_code`` is given: the server fills them with the
    English render (single-language storage). An unknown ``msg_code`` is rejected with 422."""

    title: Optional[str] = Field(None, min_length=1, max_length=200)
    message: Optional[str] = Field(None, min_length=1)
    msg_code: Optional[str] = Field(None, max_length=80)
    msg_params: Optional[Dict[str, Any]] = None

    @field_validator("target_role")
    @classmethod
    def _known_audience(cls, value: str) -> str:
        """target_role must be ALL, a seeded role code or a known audience alias (422 otherwise); stored normalised."""
        from .utils import known_audiences, normalize_audience

        normalized = normalize_audience(value) or "ALL"
        if normalized not in known_audiences():
            raise ValueError(f"Unknown notification audience '{value}'. Allowed: {', '.join(sorted(known_audiences()))}.")
        return normalized

    @model_validator(mode="before")
    @classmethod
    def _blank_texts_are_missing(cls, data: Any) -> Any:
        """An empty/blank title or message counts as omitted, so a valid msg_code fills it (no 422)."""
        if isinstance(data, dict):
            data = dict(data)
            for key in ("title", "message"):
                if isinstance(data.get(key), str) and not data[key].strip():
                    data[key] = None
        return data

    @model_validator(mode="after")
    def _apply_message_code(self) -> "NotificationCreate":
        if self.msg_code is not None:
            if not is_known_code(self.msg_code):
                raise ValueError("رمز الرسالة غير معروف")
            params = self.msg_params or {}
            if not self.title:
                self.title = render_en(self.msg_code, params, "title")[:200]
            if not self.message:
                self.message = render_en(self.msg_code, params, "body")
        elif self.msg_params is not None:
            raise ValueError("msg_params يتطلب msg_code")
        if not self.title or not self.message:
            raise ValueError("العنوان ونص الإشعار مطلوبان عند عدم إرسال رمز رسالة")
        return self


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
