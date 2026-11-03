"""
Pydantic Schemas for Refundable Deposits & Guarantee Releases
"""

from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class RefundableDepositBase(BaseModel):
    import_file_id: Optional[int] = None
    deposit_type: str = Field(..., description="SHIPPING_LINE_CONTAINER, CUSTOMS_DUTY_SECURITY, BANK_LETTER_OF_GUARANTEE, PORT_AUTHORITY_SECURITY, OTHER")
    beneficiary_type: str = Field(..., description="CARRIER, CUSTOMS, PORT, BANK, OTHER")
    beneficiary_name: str
    container_number: Optional[str] = None
    eir_number: Optional[str] = None
    eir_return_date: Optional[date] = None
    deposit_amount: float = Field(..., ge=0.0)
    currency: str = Field("EGP")
    paid_date: Optional[date] = None
    payment_reference: Optional[str] = None
    bank_lg_number: Optional[str] = None
    bank_lg_issuing_bank: Optional[str] = None
    bank_lg_expiry_date: Optional[date] = None
    notes: Optional[str] = None


class RefundableDepositCreate(RefundableDepositBase):
    deposit_code: Optional[str] = None


class RefundableDepositUpdate(BaseModel):
    beneficiary_name: Optional[str] = None
    container_number: Optional[str] = None
    deposit_amount: Optional[float] = None
    paid_date: Optional[date] = None
    payment_reference: Optional[str] = None
    bank_lg_number: Optional[str] = None
    bank_lg_issuing_bank: Optional[str] = None
    bank_lg_expiry_date: Optional[date] = None
    notes: Optional[str] = None


class EirReturnLinkRequest(BaseModel):
    container_number: str
    eir_number: str
    eir_return_date: date
    notes: Optional[str] = None


class RefundClaimSubmitRequest(BaseModel):
    claim_submission_date: date
    submission_reference: Optional[str] = None
    notes: Optional[str] = None


class RefundSettlementRequest(BaseModel):
    refunded_amount: float = Field(0.0, ge=0.0)
    refund_date: date
    refund_reference: Optional[str] = None
    deduction_amount: float = Field(0.0, ge=0.0)
    deduction_reason: Optional[str] = None
    notes: Optional[str] = None


class BankLgReleaseRequest(BaseModel):
    release_letter_reference: str
    release_date: date
    notes: Optional[str] = None


class RefundableDepositOut(RefundableDepositBase):
    id: int
    deposit_code: str
    recovery_status: str
    refunded_amount: float
    refund_date: Optional[date] = None
    refund_reference: Optional[str] = None
    deduction_amount: float
    deduction_reason: Optional[str] = None
    is_active: bool
    is_deleted: bool
    created_by_user_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class RefundableDepositListOut(BaseModel):
    items: List[RefundableDepositOut]
    total: int
    page: int
    size: int


class DepositRecoveryMetricsOut(BaseModel):
    total_deposits_count: int
    pending_recovery_count: int
    pending_recovery_amount_egp: float
    recovered_amount_egp: float
    total_deductions_egp: float
    active_bank_lg_count: int
    carrier_deposits_count: int
