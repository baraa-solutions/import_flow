"""
Pydantic Schemas for Customs Special & Suspended Duty Regimes
"""

from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class RegimeType(str, Enum):
    TEMPORARY_ADMISSION = "TEMPORARY_ADMISSION"
    DRAWBACK = "DRAWBACK"
    FREE_ZONE = "FREE_ZONE"
    CUSTOMS_WAREHOUSE = "CUSTOMS_WAREHOUSE"
    TRANSIT = "TRANSIT"


class RegimeStatus(str, Enum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    SETTLED = "SETTLED"
    CLOSED = "CLOSED"
    EXPIRED = "EXPIRED"
    DEFAULTED = "DEFAULTED"


class GuaranteeType(str, Enum):
    LETTER_OF_GUARANTEE = "LETTER_OF_GUARANTEE"
    CASH_DEPOSIT = "CASH_DEPOSIT"
    INSURANCE_POLICY = "INSURANCE_POLICY"
    PROMISSORY_NOTE = "PROMISSORY_NOTE"


class CustomsRegimeBase(BaseModel):
    import_file_id: int = Field(..., description="Import File ID")
    shipment_id: Optional[int] = Field(None, description="Optional Shipment ID")
    regime_type: RegimeType = Field(..., description="Regime Type")
    status: RegimeStatus = Field(RegimeStatus.ACTIVE, description="Lifecycle Status")

    customs_office: Optional[str] = Field(None, max_length=100)
    release_form_number: Optional[str] = Field(None, max_length=100)
    release_date: Optional[date] = None

    guarantee_type: Optional[GuaranteeType] = None
    guarantee_reference: Optional[str] = Field(None, max_length=100)
    guarantee_bank: Optional[str] = Field(None, max_length=100)
    guarantee_amount: float = Field(0.0, ge=0.0)
    guarantee_currency: str = Field("EGP", max_length=10)
    guarantee_issue_date: Optional[date] = None
    guarantee_expiry_date: Optional[date] = None

    re_export_deadline: Optional[date] = None
    actual_re_export_date: Optional[date] = None
    re_export_export_declaration_no: Optional[str] = Field(None, max_length=100)
    drawback_reconciliation_ref: Optional[str] = Field(None, max_length=100)
    drawback_refund_amount: float = Field(0.0, ge=0.0)
    reconciled_date: Optional[date] = None
    is_settled: bool = False

    notes: Optional[str] = None


class CustomsRegimeCreate(CustomsRegimeBase):
    pass


class CustomsRegimeUpdate(BaseModel):
    regime_type: Optional[RegimeType] = None
    status: Optional[RegimeStatus] = None
    customs_office: Optional[str] = None
    release_form_number: Optional[str] = None
    release_date: Optional[date] = None

    guarantee_type: Optional[GuaranteeType] = None
    guarantee_reference: Optional[str] = None
    guarantee_bank: Optional[str] = None
    guarantee_amount: Optional[float] = Field(None, ge=0.0)
    guarantee_currency: Optional[str] = None
    guarantee_issue_date: Optional[date] = None
    guarantee_expiry_date: Optional[date] = None

    re_export_deadline: Optional[date] = None
    actual_re_export_date: Optional[date] = None
    re_export_export_declaration_no: Optional[str] = None
    drawback_reconciliation_ref: Optional[str] = None
    drawback_refund_amount: Optional[float] = Field(None, ge=0.0)
    reconciled_date: Optional[date] = None
    is_settled: Optional[bool] = None

    notes: Optional[str] = None


class CustomsRegimeSettle(BaseModel):
    actual_re_export_date: Optional[date] = None
    re_export_export_declaration_no: Optional[str] = None
    drawback_reconciliation_ref: Optional[str] = None
    drawback_refund_amount: float = Field(0.0, ge=0.0)
    reconciled_date: date = Field(default_factory=date.today)
    notes: Optional[str] = None


class CustomsRegimeOut(CustomsRegimeBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    regime_code: str
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    created_by_user_id: Optional[int] = None
    updated_by_user_id: Optional[int] = None

    # Calculated helper fields
    days_until_re_export: Optional[int] = None
    is_expired: bool = False
    guarantee_active: bool = False


class CustomsRegimeListOut(BaseModel):
    items: List[CustomsRegimeOut]
    total: int
    page: int
    size: int
