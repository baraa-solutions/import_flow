"""
Pydantic Schemas for Cargo Claims, Time-Bars & Legal Reservations
"""

from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ClaimType(str, Enum):
    CARRIER_DAMAGE = "CARRIER_DAMAGE"
    CARRIER_SHORTAGE = "CARRIER_SHORTAGE"
    PORT_DAMAGE = "PORT_DAMAGE"
    INSURANCE_RECOVERY = "INSURANCE_RECOVERY"
    GENERAL_AVERAGE = "GENERAL_AVERAGE"


class DamageNature(str, Enum):
    APPARENT = "APPARENT"
    LATENT = "LATENT"


class ClaimStatus(str, Enum):
    DRAFT = "DRAFT"
    RESERVATION_ISSUED = "RESERVATION_ISSUED"
    SURVEY_SCHEDULED = "SURVEY_SCHEDULED"
    SURVEY_COMPLETED = "SURVEY_COMPLETED"
    CLAIM_SUBMITTED = "CLAIM_SUBMITTED"
    SETTLED = "SETTLED"
    REJECTED = "REJECTED"
    TIME_BARRED = "TIME_BARRED"


class LegalClaimBase(BaseModel):
    import_file_id: int = Field(..., description="Import File ID")
    shipment_id: Optional[int] = Field(None, description="Optional Shipment ID")
    claim_type: ClaimType = Field(..., description="Claim Type")
    damage_nature: DamageNature = Field(..., description="Apparent vs Latent Damage")
    delivery_date: Optional[date] = None
    latent_notice_deadline: Optional[date] = None
    apparent_notice_date: Optional[date] = None
    time_bar_statute_of_limitations_date: Optional[date] = None
    status: ClaimStatus = Field(ClaimStatus.RESERVATION_ISSUED)

    reservation_letter_ref: Optional[str] = Field(None, max_length=100)
    reservation_letter_date: Optional[date] = None
    target_party: str = Field(..., max_length=100)

    survey_requested: bool = False
    survey_date: Optional[date] = None
    surveyor_company: Optional[str] = Field(None, max_length=150)
    survey_report_ref: Optional[str] = Field(None, max_length=100)

    claimed_amount: float = Field(0.0, ge=0.0)
    claimed_currency: str = Field("USD", max_length=10)
    settled_amount: float = Field(0.0, ge=0.0)
    settlement_date: Optional[date] = None

    notes: Optional[str] = None


class LegalClaimCreate(LegalClaimBase):
    pass


class LegalClaimUpdate(BaseModel):
    claim_type: Optional[ClaimType] = None
    damage_nature: Optional[DamageNature] = None
    delivery_date: Optional[date] = None
    latent_notice_deadline: Optional[date] = None
    apparent_notice_date: Optional[date] = None
    time_bar_statute_of_limitations_date: Optional[date] = None
    status: Optional[ClaimStatus] = None

    reservation_letter_ref: Optional[str] = None
    reservation_letter_date: Optional[date] = None
    target_party: Optional[str] = None

    survey_requested: Optional[bool] = None
    survey_date: Optional[date] = None
    surveyor_company: Optional[str] = None
    survey_report_ref: Optional[str] = None

    claimed_amount: Optional[float] = Field(None, ge=0.0)
    claimed_currency: Optional[str] = None
    settled_amount: Optional[float] = Field(None, ge=0.0)
    settlement_date: Optional[date] = None

    notes: Optional[str] = None


class LegalClaimSettle(BaseModel):
    settled_amount: float = Field(..., ge=0.0)
    settlement_date: date = Field(default_factory=date.today)
    notes: Optional[str] = None


class ScheduleSurvey(BaseModel):
    survey_date: date
    surveyor_company: str = Field(..., max_length=150)
    notes: Optional[str] = None


class LegalClaimOut(LegalClaimBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    claim_code: str
    time_bar_statute_of_limitations_date: date
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    created_by_user_id: Optional[int] = None
    updated_by_user_id: Optional[int] = None

    # Calculated helper radar fields
    days_until_time_bar: int = 0
    days_until_latent_deadline: Optional[int] = None
    is_latent_notice_expired: bool = False
    is_time_barred: bool = False
    urgency_level: str = "NORMAL"  # NORMAL, WARNING_30_DAYS, CRITICAL_7_DAYS, EXPIRED


class LegalClaimListOut(BaseModel):
    items: List[LegalClaimOut]
    total: int
    page: int
    size: int
