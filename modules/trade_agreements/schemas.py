"""
Pydantic Schemas for Preferential Trade Agreements & Origin Verifications
"""

from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class AgreementName(str, Enum):
    EUR1 = "EUR1"
    GAFTA = "GAFTA"
    AGADIR = "AGADIR"
    COMESA = "COMESA"
    EFTA = "EFTA"
    TURKEY = "TURKEY"
    MERCOSUR = "MERCOSUR"
    OTHER = "OTHER"


class CertificateType(str, Enum):
    EUR1 = "EUR.1"
    EUR_MED = "EUR_MED"
    FORM_A = "FORM_A"
    ARAB_LEAGUE = "ARAB_LEAGUE"
    CERTIFICATE_OF_ORIGIN = "CERTIFICATE_OF_ORIGIN"


class SubmissionStatus(str, Enum):
    ORIGINAL_SUBMITTED = "ORIGINAL_SUBMITTED"
    COPY_SUBMITTED = "COPY_SUBMITTED"
    CUSTOMS_ESCHEATED = "CUSTOMS_ESCHEATED"
    VERIFIED_ELECTRONICALLY = "VERIFIED_ELECTRONICALLY"
    REJECTED = "REJECTED"


class OriginCriterion(str, Enum):
    WHOLLY_OBTAINED = "WHOLLY_OBTAINED"
    VALUE_ADDED = "VALUE_ADDED"
    SUFFICIENT_PROCESSING = "SUFFICIENT_PROCESSING"


class TradeAgreementBase(BaseModel):
    import_file_id: int = Field(..., description="Import File ID")
    shipment_id: Optional[int] = Field(None, description="Optional Shipment ID")
    agreement_name: AgreementName = Field(..., description="Preferential Agreement Name")
    certificate_type: CertificateType = Field(..., description="Certificate Type")
    certificate_number: str = Field(..., max_length=100)
    issuing_country: str = Field(..., max_length=100)
    issuing_authority: Optional[str] = Field(None, max_length=150)
    issuing_date: date
    validity_months: int = Field(4, ge=1, le=24)
    expiry_date: Optional[date] = None

    submission_status: SubmissionStatus = Field(SubmissionStatus.COPY_SUBMITTED)
    has_original_received: bool = False
    original_received_date: Optional[date] = None

    provisional_escrow_required: bool = False
    provisional_escrow_amount: float = Field(0.0, ge=0.0)
    provisional_escrow_receipt: Optional[str] = Field(None, max_length=100)
    provisional_escrow_deadline: Optional[date] = None
    provisional_escrow_refunded: bool = False
    refund_date: Optional[date] = None

    direct_transport_compliant: bool = True
    rules_of_origin_criterion: Optional[OriginCriterion] = None
    verification_notes: Optional[str] = None


class TradeAgreementCreate(TradeAgreementBase):
    pass


class TradeAgreementUpdate(BaseModel):
    agreement_name: Optional[AgreementName] = None
    certificate_type: Optional[CertificateType] = None
    certificate_number: Optional[str] = None
    issuing_country: Optional[str] = None
    issuing_authority: Optional[str] = None
    issuing_date: Optional[date] = None
    validity_months: Optional[int] = Field(None, ge=1, le=24)
    expiry_date: Optional[date] = None

    submission_status: Optional[SubmissionStatus] = None
    has_original_received: Optional[bool] = None
    original_received_date: Optional[date] = None

    provisional_escrow_required: Optional[bool] = None
    provisional_escrow_amount: Optional[float] = Field(None, ge=0.0)
    provisional_escrow_receipt: Optional[str] = None
    provisional_escrow_deadline: Optional[date] = None
    provisional_escrow_refunded: Optional[bool] = None
    refund_date: Optional[date] = None

    direct_transport_compliant: Optional[bool] = None
    rules_of_origin_criterion: Optional[OriginCriterion] = None
    verification_notes: Optional[str] = None


class TradeAgreementVerifyOriginal(BaseModel):
    original_received_date: date = Field(default_factory=date.today)
    provisional_escrow_refunded: bool = False
    refund_date: Optional[date] = None
    verification_notes: Optional[str] = None


class TradeAgreementOut(TradeAgreementBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    verification_code: str
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    created_by_user_id: Optional[int] = None
    updated_by_user_id: Optional[int] = None

    # Calculated helper fields
    days_until_expiry: Optional[int] = None
    days_until_escrow_deadline: Optional[int] = None
    is_cert_expired: bool = False
    is_escrow_at_risk: bool = False


class TradeAgreementListOut(BaseModel):
    items: List[TradeAgreementOut]
    total: int
    page: int
    size: int
