"""
Pydantic Schemas for Logistics Operational Rules
"""

from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ScopeType(str, Enum):
    GLOBAL = "GLOBAL"
    SHIPPING_LINE = "SHIPPING_LINE"
    PORT = "PORT"
    COMMODITY = "COMMODITY"
    CONTAINER_TYPE = "CONTAINER_TYPE"


class ValueUnit(str, Enum):
    DAYS = "DAYS"
    HOURS = "HOURS"
    PERCENTAGE = "PERCENTAGE"
    KG = "KG"
    BOOLEAN = "BOOLEAN"
    MONTHS = "MONTHS"
    CURRENCY = "CURRENCY"
    TEXT = "TEXT"


class EnforcementLevel(str, Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    BLOCKING = "BLOCKING"


class VerificationStatus(str, Enum):
    UNVERIFIED = "UNVERIFIED"
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"


class LogisticsRuleBase(BaseModel):
    rule_name_ar: str = Field(..., description="Rule name in Arabic")
    rule_name_en: str = Field(..., description="Rule name in English")
    scope_type: ScopeType = Field(default=ScopeType.GLOBAL, description="Scope type")
    scope_id: Optional[int] = Field(default=None, description="Scope entity ID")
    conservative_default: Optional[str] = Field(
        default=None, description="Conservative default fallback"
    )
    verified_value: Optional[str] = Field(
        default=None, description="Verified value (must be verified)"
    )
    value_unit: ValueUnit = Field(..., description="Measurement unit")
    enforcement_level: EnforcementLevel = Field(
        default=EnforcementLevel.WARNING, description="Configured enforcement level"
    )
    source_ref: Optional[str] = Field(
        default=None, description="Citation / legal source reference"
    )
    evidence_ref: Optional[str] = Field(
        default=None, description="Evidence document reference / filename"
    )
    effective_from: Optional[date] = Field(default=None, description="Effective from date")
    effective_to: Optional[date] = Field(default=None, description="Effective to date")
    review_due_on: Optional[date] = Field(
        default=None, description="Scheduled review due date"
    )


class LogisticsRuleCreate(LogisticsRuleBase):
    rule_key: str = Field(..., max_length=100, description="Unique rule identifier key")


class LogisticsRuleUpdate(BaseModel):
    rule_name_ar: Optional[str] = None
    rule_name_en: Optional[str] = None
    scope_type: Optional[ScopeType] = None
    scope_id: Optional[int] = None
    conservative_default: Optional[str] = None
    verified_value: Optional[str] = None
    value_unit: Optional[ValueUnit] = None
    enforcement_level: Optional[EnforcementLevel] = None
    source_ref: Optional[str] = None
    evidence_ref: Optional[str] = None
    effective_from: Optional[date] = None
    effective_to: Optional[date] = None
    review_due_on: Optional[date] = None


class LogisticsRuleVerify(BaseModel):
    verified_value: str = Field(..., description="Verified value established by official evidence")
    evidence_ref: Optional[str] = Field(
        default=None, description="Evidence document attachment reference"
    )
    source_ref: Optional[str] = Field(
        default=None, description="Source article/decree/reference"
    )
    review_due_on: Optional[date] = Field(
        default=None, description="Next review due date if subject to change"
    )


class LogisticsRuleOut(LogisticsRuleBase):
    id: int
    rule_key: str
    verification_status: VerificationStatus
    verified_by_user_id: Optional[int] = None
    verified_on: Optional[datetime] = None
    version_id: int
    is_latest: bool
    is_active: bool
    created_by_user_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    # Computed safety guard fields
    effective_enforcement_level: str = "WARNING"
    safety_guard_triggered: bool = False
    guard_reason: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class EffectiveRuleOut(BaseModel):
    rule_key: str
    rule_name_ar: str
    rule_name_en: str
    scope_type: str
    scope_id: Optional[int] = None
    raw_enforcement_level: str
    effective_enforcement_level: str
    safety_guard_triggered: bool
    guard_reason: Optional[str] = None
    value: Optional[str] = None
    value_source: str  # VERIFIED | CONSERVATIVE_DEFAULT | NONE
    value_unit: str
    verification_status: str
    evidence_ref: Optional[str] = None
    source_ref: Optional[str] = None


class LogisticsRuleListOut(BaseModel):
    items: List[LogisticsRuleOut]
    total: int
    page: int
    size: int


class FieldQuestionOut(BaseModel):
    rule_key: str
    rule_name_ar: str
    rule_name_en: str
    value_unit: str
    conservative_default: Optional[str] = None
    suggested_party: str
    source_ref: Optional[str] = None
    question_text_ar: str
