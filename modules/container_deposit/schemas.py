from datetime import date, datetime
from enum import Enum
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ContainerCondition(str, Enum):
    SOUND_CLEAN = "SOUND_CLEAN"
    DAMAGE_CLAIMED = "DAMAGE_CLAIMED"
    CLEANING_FEE_DEDUCTED = "CLEANING_FEE_DEDUCTED"


class DepositRefundStatus(str, Enum):
    PENDING_RETURN = "PENDING_RETURN"
    CLAIM_SUBMITTED = "CLAIM_SUBMITTED"
    OVERDUE_30_DAYS = "OVERDUE_30_DAYS"
    REFUNDED_FULL = "REFUNDED_FULL"
    REFUNDED_PARTIAL = "REFUNDED_PARTIAL"


class ContainerDepositBase(BaseModel):
    import_file_id: int
    carrier_id: Optional[int] = None
    carrier_name: str
    container_number: str
    container_type: str
    deposit_amount_egp: float = Field(gt=0.0)
    payment_reference: Optional[str] = None
    payment_date: date
    notes: Optional[str] = None


class ContainerDepositCreate(ContainerDepositBase):
    pass


class ContainerDepositUpdate(BaseModel):
    carrier_id: Optional[int] = None
    carrier_name: Optional[str] = None
    container_number: Optional[str] = None
    container_type: Optional[str] = None
    deposit_amount_egp: Optional[float] = Field(None, gt=0.0)
    payment_reference: Optional[str] = None
    payment_date: Optional[date] = None
    eir_return_number: Optional[str] = None
    eir_return_date: Optional[date] = None
    container_condition: Optional[ContainerCondition] = None
    deduction_amount_egp: Optional[float] = Field(None, ge=0.0)
    refund_status: Optional[DepositRefundStatus] = None
    refund_cheque_or_transfer_no: Optional[str] = None
    refund_received_date: Optional[date] = None
    notes: Optional[str] = None


class RecordEIRReturnRequest(BaseModel):
    eir_return_number: str
    eir_return_date: date
    container_condition: ContainerCondition = ContainerCondition.SOUND_CLEAN
    deduction_amount_egp: float = Field(0.0, ge=0.0)
    deduction_reason: Optional[str] = None


class RecordDepositRefundRequest(BaseModel):
    refund_cheque_or_transfer_no: str
    refund_received_date: date
    refund_amount_egp: float = Field(gt=0.0)


class DisputeDeductionRequest(BaseModel):
    dispute_reason: str
    revised_deduction_amount_egp: Optional[float] = Field(None, ge=0.0)
    waived: bool = False


class OverdueDepositAlert(BaseModel):
    deposit_id: int
    import_file_id: int
    carrier_name: str
    container_number: str
    container_type: str
    deposit_amount_egp: float
    eir_return_number: Optional[str]
    eir_return_date: Optional[date]
    days_overdue: int
    refund_status: str

    model_config = ConfigDict(from_attributes=True)


class ContainerDepositOverviewResponse(BaseModel):
    total_active_deposits: int
    total_deposit_amount_egp: float
    pending_return_count: int
    claim_submitted_count: int
    overdue_30_days_count: int
    overdue_deposit_amount_egp: float
    refunded_full_count: int
    refunded_partial_count: int
    total_refunded_amount_egp: float
    total_deductions_egp: float
    carrier_breakdown: Dict[str, Any]
    alerts: List[OverdueDepositAlert]


class ContainerDepositResponse(BaseModel):
    deposit_id: int
    import_file_id: int
    carrier_id: Optional[int]
    carrier_name: str
    container_number: str
    container_type: str
    deposit_amount_egp: float
    payment_reference: Optional[str]
    payment_date: date
    eir_return_number: Optional[str]
    eir_return_date: Optional[date]
    container_condition: str
    deduction_amount_egp: float
    refund_status: str
    refund_cheque_or_transfer_no: Optional[str]
    refund_received_date: Optional[date]
    days_overdue: int
    notes: Optional[str]
    dispute_history: List[Dict[str, Any]]
    is_active: bool
    created_at: datetime
    created_by: Optional[str]
    updated_at: datetime
    updated_by: Optional[str]

    model_config = ConfigDict(from_attributes=True)


class ContainerDepositListResponse(BaseModel):
    total: int
    items: List[ContainerDepositResponse]
