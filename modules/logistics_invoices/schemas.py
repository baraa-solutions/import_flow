"""
Pydantic Schemas for Logistics Service Invoices & Payments (LSI)
================================================================
Defines request and response schemas for service invoices, lines,
insurance policies, advance payments, vouchers, and knock-offs.
"""

from __future__ import annotations

from datetime import datetime, date, timezone
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


# ============================================================================
# Invoice Lines
# ============================================================================

class LogisticsInvoiceLineCreate(BaseModel):
    expense_code: Optional[str] = None
    line_description: str
    line_group: Optional[str] = None  # ocean_freight, port_charges, origin_charges, clearance_fees, inspection, insurance
    quantity: float = 1.0
    unit_price_fx: float = 0.0
    currency: str = "EGP"
    amount_fx: float = 0.0
    exchange_rate: float = 1.0
    amount_egp: float = 0.0
    tax_type: str = "professional_fee"  # professional_fee, government_fee, insurance_fee, other
    vat_rate: float = 0.0
    vat_amount: float = 0.0
    wht_rate: float = 0.0
    wht_amount: float = 0.0
    net_amount_egp: float = 0.0
    is_from_quotation: bool = False


class LogisticsInvoiceLineResponse(LogisticsInvoiceLineCreate):
    line_id: int
    invoice_id: int
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Invoice Containers Lock
# ============================================================================

class LogisticsInvoiceContainerCreate(BaseModel):
    container_number: str
    seal_number: Optional[str] = None


class LogisticsInvoiceContainerResponse(BaseModel):
    id: int
    invoice_id: int
    shipment_id: int
    bl_number: str
    container_number: str
    seal_number: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Logistics Service Invoices
# ============================================================================

class LogisticsInvoiceCreate(BaseModel):
    shipment_id: int
    bl_number: Optional[str] = None
    partner_id: int
    partner_type: str  # freight, clearance, inspection, insurance
    partner_name: str
    invoice_number: str
    invoice_date: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    currency: str = "EGP"
    total_amount_fx: float = 0.0
    exchange_rate: float = 1.0
    total_amount_egp: float = 0.0
    vat_included: bool = False
    vat_amount: float = 0.0
    wht_deducted: bool = False
    wht_amount: float = 0.0
    net_payable_egp: float = 0.0
    insurance_policy_id: Optional[int] = None
    document_url: Optional[str] = None
    notes: Optional[str] = None
    lines: List[LogisticsInvoiceLineCreate] = []
    containers: List[LogisticsInvoiceContainerCreate] = []


class LogisticsInvoiceUpdate(BaseModel):
    invoice_number: Optional[str] = None
    invoice_date: Optional[datetime] = None
    currency: Optional[str] = None
    total_amount_fx: Optional[float] = None
    exchange_rate: Optional[float] = None
    total_amount_egp: Optional[float] = None
    vat_included: Optional[bool] = None
    vat_amount: Optional[float] = None
    wht_deducted: Optional[bool] = None
    wht_amount: Optional[float] = None
    net_payable_egp: Optional[float] = None
    document_url: Optional[str] = None
    notes: Optional[str] = None
    lines: Optional[List[LogisticsInvoiceLineCreate]] = None
    containers: Optional[List[LogisticsInvoiceContainerCreate]] = None


class LogisticsInvoiceResponse(BaseModel):
    invoice_id: int
    invoice_code: str
    shipment_id: int
    bl_number: Optional[str] = None
    partner_id: int
    partner_type: str
    partner_name: str
    invoice_number: str
    invoice_date: datetime
    currency: str
    total_amount_fx: float
    exchange_rate: float
    total_amount_egp: float
    vat_included: bool
    vat_amount: float
    wht_deducted: bool
    wht_amount: float
    net_payable_egp: float
    paid_amount_egp: float
    remaining_amount_egp: float
    payment_status: str
    status: str
    approval_status: str
    insurance_policy_id: Optional[int] = None
    document_url: Optional[str] = None
    notes: Optional[str] = None
    is_active: bool
    created_at: datetime
    created_by: str
    lines: List[LogisticsInvoiceLineResponse] = []
    containers: List[LogisticsInvoiceContainerResponse] = []

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Insurance Policies
# ============================================================================

class InsurancePolicyCreate(BaseModel):
    shipment_id: int
    bl_number: Optional[str] = None
    insurance_company_id: int
    insurance_company_name: str
    policy_number: str
    policy_date: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    coverage_start: Optional[date] = None
    coverage_end: Optional[date] = None
    coverage_type: str = "all_risks"
    insured_value_fx: float = 0.0
    insured_value_currency: str = "USD"
    premium_rate: float = 0.0  # e.g. 0.35%
    premium_amount_fx: float = 0.0
    exchange_rate: float = 1.0
    premium_amount_egp: float = 0.0
    stamp_duty_egp: float = 0.0
    supervisory_fee_egp: float = 0.0
    net_premium_egp: float = 0.0
    beneficiary: Optional[str] = None
    notes: Optional[str] = None


class InsurancePolicyUpdate(BaseModel):
    policy_number: Optional[str] = None
    coverage_start: Optional[date] = None
    coverage_end: Optional[date] = None
    coverage_type: Optional[str] = None
    insured_value_fx: Optional[float] = None
    premium_rate: Optional[float] = None
    premium_amount_fx: Optional[float] = None
    exchange_rate: Optional[float] = None
    premium_amount_egp: Optional[float] = None
    stamp_duty_egp: Optional[float] = None
    supervisory_fee_egp: Optional[float] = None
    net_premium_egp: Optional[float] = None
    beneficiary: Optional[str] = None
    status: Optional[str] = None
    notes: Optional[str] = None


class InsurancePolicyClaimCreate(BaseModel):
    claim_reference: str
    claim_amount_egp: float
    claim_status: str = "filed"
    notes: Optional[str] = None


class InsurancePolicyResponse(BaseModel):
    policy_id: int
    policy_code: str
    shipment_id: int
    bl_number: Optional[str] = None
    insurance_company_id: int
    insurance_company_name: str
    policy_number: str
    policy_date: datetime
    coverage_start: Optional[date] = None
    coverage_end: Optional[date] = None
    coverage_type: str
    insured_value_fx: float
    insured_value_currency: str
    premium_rate: float
    premium_amount_fx: float
    exchange_rate: float
    premium_amount_egp: float
    stamp_duty_egp: float
    supervisory_fee_egp: float
    net_premium_egp: float
    beneficiary: Optional[str] = None
    status: str
    claim_reference: Optional[str] = None
    claim_amount_egp: float
    claim_status: Optional[str] = None
    invoice_generated: bool
    notes: Optional[str] = None
    is_active: bool
    created_at: datetime
    created_by: str

    model_config = ConfigDict(from_attributes=True)


class InsurancePreviewResponse(BaseModel):
    shipment_id: int
    cif_value_fx: float
    insured_value_fx: float  # CIF + 10%
    currency: str
    exchange_rate: float
    premium_rate: float
    premium_amount_fx: float
    premium_amount_egp: float
    stamp_duty_egp: float  # 0.1%
    supervisory_fee_egp: float  # 12%
    net_premium_egp: float


# ============================================================================
# Clearance Advance Payments
# ============================================================================

class ClearanceAdvancePaymentCreate(BaseModel):
    shipment_id: int
    bl_number: Optional[str] = None
    clearance_partner_id: int
    clearance_partner_name: str
    amount: float
    currency: str = "EGP"
    exchange_rate: float = 1.0
    amount_egp: float
    payment_date: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    cbe_rate_date: Optional[date] = None
    notes: Optional[str] = None


class ClearanceAdvanceSettlementCreate(BaseModel):
    invoice_id: int
    settled_amount_egp: float
    notes: Optional[str] = None


class ClearanceAdvanceSettlementResponse(BaseModel):
    settlement_id: int
    advance_id: int
    invoice_id: int
    settled_amount_egp: float
    settlement_date: datetime
    notes: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ClearanceAdvancePaymentResponse(BaseModel):
    advance_id: int
    advance_code: str
    shipment_id: int
    bl_number: Optional[str] = None
    clearance_partner_id: int
    clearance_partner_name: str
    amount: float
    currency: str
    exchange_rate: float
    amount_egp: float
    payment_date: datetime
    cbe_rate_date: Optional[date] = None
    disbursed_by: str
    settled_amount_egp: float
    remaining_amount_egp: float
    status: str
    notes: Optional[str] = None
    is_active: bool
    created_at: datetime
    created_by: str
    settlements: List[ClearanceAdvanceSettlementResponse] = []

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Payment Vouchers & Knock-Offs
# ============================================================================

class InvoiceKnockoffItem(BaseModel):
    invoice_id: int
    knocked_amount_egp: float
    notes: Optional[str] = None


class LogisticsPaymentVoucherCreate(BaseModel):
    shipment_id: Optional[int] = None
    partner_id: int
    partner_name: str
    payment_date: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    amount: float
    currency: str = "EGP"
    exchange_rate: float = 1.0
    amount_egp: float
    cbe_rate_date: Optional[date] = None
    payment_method: str = "BANK_TRANSFER"  # BANK_TRANSFER, CHEQUE, CASH
    bank_reference: Optional[str] = None
    notes: Optional[str] = None
    knockoffs: List[InvoiceKnockoffItem] = []


class InvoiceKnockoffResponse(BaseModel):
    knockoff_id: int
    voucher_id: int
    invoice_id: int
    knocked_amount_egp: float
    knock_date: datetime
    notes: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class LogisticsPaymentVoucherResponse(BaseModel):
    voucher_id: int
    voucher_code: str
    shipment_id: Optional[int] = None
    partner_id: int
    partner_name: str
    payment_date: datetime
    amount: float
    currency: str
    exchange_rate: float
    amount_egp: float
    cbe_rate_date: Optional[date] = None
    payment_method: str
    bank_reference: Optional[str] = None
    allocated_amount_egp: float
    unallocated_amount_egp: float
    status: str
    notes: Optional[str] = None
    is_active: bool
    created_at: datetime
    created_by: str
    knockoffs: List[InvoiceKnockoffResponse] = []

    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# Auxiliary / Analytical Responses
# ============================================================================

class AgingBucket(BaseModel):
    current_30_days: float = 0.0
    days_31_to_60: float = 0.0
    days_61_to_90: float = 0.0
    days_90_plus: float = 0.0


class PartnerBalanceCardResponse(BaseModel):
    partner_id: int
    partner_name: str
    partner_type: str
    total_invoiced_egp: float = 0.0
    total_paid_egp: float = 0.0
    balance_due_egp: float = 0.0
    open_invoices_count: int = 0
    aging: AgingBucket = Field(default_factory=AgingBucket)


class ContainerLockStatusItem(BaseModel):
    container_number: str
    seal_number: Optional[str] = None
    is_billed: bool = False
    billed_by_partner_id: Optional[int] = None
    billed_by_partner_name: Optional[str] = None
    invoice_number: Optional[str] = None


class ContainerLockStatusResponse(BaseModel):
    shipment_id: int
    bl_number: str
    containers: List[ContainerLockStatusItem] = []


class ThreeWayMatchItem(BaseModel):
    item_description: str
    quoted_amount_egp: float = 0.0
    invoiced_amount_egp: float = 0.0
    variance_egp: float = 0.0
    is_matched: bool = True


class ThreeWayMatchResponse(BaseModel):
    invoice_id: int
    is_fully_matched: bool = True
    total_quoted_egp: float = 0.0
    total_invoiced_egp: float = 0.0
    total_variance_egp: float = 0.0
    items: List[ThreeWayMatchItem] = []


class PrefillLineItem(BaseModel):
    expense_code: Optional[str] = None
    line_description: str
    line_group: Optional[str] = None
    quantity: float = 1.0
    unit_price_fx: float = 0.0
    currency: str = "EGP"
    amount_fx: float = 0.0
    exchange_rate: float = 1.0
    amount_egp: float = 0.0
    tax_type: str = "professional_fee"
    vat_rate: float = 0.0
    vat_amount: float = 0.0
    wht_rate: float = 0.0
    wht_amount: float = 0.0
    net_amount_egp: float = 0.0
    is_from_quotation: bool = True


class PrefillLinesResponse(BaseModel):
    shipment_id: int
    partner_type: str
    currency: str
    exchange_rate: float
    lines: List[PrefillLineItem] = []


# ============================================================================
# Partner Ledger & Form 41 WHT Schemas
# ============================================================================

class PartnerLedgerEntrySchema(BaseModel):
    entry_date: datetime
    entry_type: str  # INVOICE, PAYMENT, ADVANCE, SETTLEMENT
    reference_no: str
    description: str
    debit_egp: float = 0.0   # Partner invoice net payable
    credit_egp: float = 0.0  # Company payments to partner
    running_balance_egp: float = 0.0


class PartnerLedgerResponse(BaseModel):
    partner_id: int
    partner_name: str
    partner_type: str
    from_date: Optional[date] = None
    to_date: Optional[date] = None
    total_invoiced_egp: float = 0.0
    total_paid_egp: float = 0.0
    closing_balance_egp: float = 0.0
    entries: List[PartnerLedgerEntrySchema] = []


class WhtForm41RecordSchema(BaseModel):
    invoice_id: int
    invoice_code: str
    invoice_number: str
    invoice_date: datetime
    partner_name: str
    partner_type: str
    service_type: str
    total_amount_egp: float
    wht_rate: float
    wht_amount_egp: float
    net_payable_egp: float


class WhtForm41ReportResponse(BaseModel):
    year: int
    month: Optional[int] = None
    total_gross_amount_egp: float = 0.0
    total_wht_amount_egp: float = 0.0
    records_count: int = 0
    records: List[WhtForm41RecordSchema] = []


class InsurancePolicyClaimStatusUpdate(BaseModel):
    claim_status: str  # filed, under_inspection, accepted, reimbursed, rejected
    claim_amount_egp: Optional[float] = None
    notes: Optional[str] = None

