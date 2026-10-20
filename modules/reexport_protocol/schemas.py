from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ReexportStatus(str, Enum):
    MANDATED = "MANDATED"
    BOOKING_CONFIRMED = "BOOKING_CONFIRMED"
    CUSTOMS_INSPECTED = "CUSTOMS_INSPECTED"
    LADEN_ON_BOARD = "LADEN_ON_BOARD"
    COMPLETED_CLOSED = "COMPLETED_CLOSED"


class DutyDrawbackStatus(str, Enum):
    PENDING_APPLICATION = "PENDING_APPLICATION"
    APPROVED_REFUNDED = "APPROVED_REFUNDED"
    EXEMPTION_SUSPENDED = "EXEMPTION_SUSPENDED"


class SupplierCreditNoteStatus(str, Enum):
    REQUESTED = "REQUESTED"
    RECEIVED = "RECEIVED"
    ARBITRATION = "ARBITRATION"


class ReexportDossierBase(BaseModel):
    import_file_id: int
    import_file_code: str
    rejection_authority: str
    rejection_decree_number: str
    rejection_date: date
    legal_reexport_deadline: Optional[date] = None
    reexport_reason: str
    container_numbers: List[str] = Field(default_factory=list)
    customs_outbound_declaration_no: Optional[str] = None
    supervision_committee_formed: bool = False
    customs_officer_in_charge: Optional[str] = None
    return_carrier_id: Optional[int] = None
    return_booking_number: Optional[str] = None
    outbound_bl_number: Optional[str] = None
    return_port_of_discharge: Optional[str] = None
    duty_drawback_status: DutyDrawbackStatus = DutyDrawbackStatus.PENDING_APPLICATION
    duty_amount_refundable_egp: float = 0.0
    supplier_credit_note_status: SupplierCreditNoteStatus = SupplierCreditNoteStatus.REQUESTED
    credit_note_amount_usd: float = 0.0
    status: ReexportStatus = ReexportStatus.MANDATED
    notes: Optional[str] = None


class ReexportDossierCreate(ReexportDossierBase):
    pass


class ReexportDossierUpdate(BaseModel):
    rejection_authority: Optional[str] = None
    rejection_decree_number: Optional[str] = None
    rejection_date: Optional[date] = None
    legal_reexport_deadline: Optional[date] = None
    reexport_reason: Optional[str] = None
    container_numbers: Optional[List[str]] = None
    customs_outbound_declaration_no: Optional[str] = None
    supervision_committee_formed: Optional[bool] = None
    customs_officer_in_charge: Optional[str] = None
    return_carrier_id: Optional[int] = None
    return_booking_number: Optional[str] = None
    outbound_bl_number: Optional[str] = None
    return_port_of_discharge: Optional[str] = None
    duty_drawback_status: Optional[DutyDrawbackStatus] = None
    duty_amount_refundable_egp: Optional[float] = None
    supplier_credit_note_status: Optional[SupplierCreditNoteStatus] = None
    credit_note_amount_usd: Optional[float] = None
    status: Optional[ReexportStatus] = None
    notes: Optional[str] = None


class OutboundBookingRequest(BaseModel):
    return_carrier_id: Optional[int] = None
    return_booking_number: str
    return_port_of_discharge: str
    outbound_bl_number: Optional[str] = None


class SupervisionCommitteeRequest(BaseModel):
    supervision_committee_formed: bool = True
    customs_officer_in_charge: str
    customs_outbound_declaration_no: str


class CreditNoteRequest(BaseModel):
    supplier_credit_note_status: SupplierCreditNoteStatus
    credit_note_amount_usd: float = Field(ge=0.0)


class DutyDrawbackRequest(BaseModel):
    duty_drawback_status: DutyDrawbackStatus
    duty_amount_refundable_egp: float = Field(ge=0.0)


class StatusTransitionRequest(BaseModel):
    status: ReexportStatus


class DestructionAlertSummary(BaseModel):
    reexport_id: int
    import_file_id: int
    import_file_code: str
    rejection_decree_number: str
    rejection_authority: str
    rejection_date: date
    legal_reexport_deadline: date
    days_remaining_to_destruction: int
    alert_level: str  # CRITICAL (<=0), URGENT (1-7), WARNING (8-14), NORMAL (>14)
    status: str

    model_config = ConfigDict(from_attributes=True)


class DestructionAlertOverviewResponse(BaseModel):
    total_active_dossiers: int
    critical_count: int
    urgent_count: int
    warning_count: int
    normal_count: int
    alerts: List[DestructionAlertSummary]


class ReexportDossierResponse(BaseModel):
    reexport_id: int
    import_file_id: int
    import_file_code: str
    rejection_authority: str
    rejection_decree_number: str
    rejection_date: date
    legal_reexport_deadline: date
    days_remaining_to_destruction: int
    reexport_reason: str
    customs_outbound_declaration_no: Optional[str]
    supervision_committee_formed: bool
    customs_officer_in_charge: Optional[str]
    return_carrier_id: Optional[int]
    return_booking_number: Optional[str]
    outbound_bl_number: Optional[str]
    container_numbers: List[str]
    return_port_of_discharge: Optional[str]
    duty_drawback_status: str
    duty_amount_refundable_egp: float
    supplier_credit_note_status: str
    credit_note_amount_usd: float
    status: str
    notes: Optional[str]
    is_active: bool
    created_at: datetime
    created_by: Optional[str]
    updated_at: datetime
    updated_by: Optional[str]

    model_config = ConfigDict(from_attributes=True)


class ReexportDossierListResponse(BaseModel):
    total: int
    items: List[ReexportDossierResponse]
