from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model


# ---------------------------------------------------------------------------
# Wave 1 Receipt Types & Enums
# ---------------------------------------------------------------------------
class SettlementReceiptTypeEnum(str, Enum):
    WHITE_RECEIPT_CUSTOMS_DUTIES = "WHITE_RECEIPT_CUSTOMS_DUTIES"          # إيصال سداد جمركي أبيض
    RED_RECEIPT_EXAMINATION_INSPECTION = "RED_RECEIPT_EXAMINATION_INSPECTION"  # إيصال كشف ومعاينة أحمر
    PORT_AUTHORITY_RECEIPT = "PORT_AUTHORITY_RECEIPT"                      # إيصال هيئة الميناء
    BROKER_SERVICE_FEE = "BROKER_SERVICE_FEE"                              # فاتورة أتعاب التخليص الجمركي
    STORAGE_RECEIPT = "STORAGE_RECEIPT"                                    # إيصال أرضيات وتخزين
    OTHER_OFFICIAL_RECEIPT = "OTHER_OFFICIAL_RECEIPT"                      # إيصال رسمي آخر


class ReceiptVerificationStatusEnum(str, Enum):
    PENDING = "PENDING"
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"


# ---------------------------------------------------------------------------
# Official Settlement Receipt Schemas
# ---------------------------------------------------------------------------
class BrokerSettlementReceiptCreate(BaseModel):
    receipt_type: str = Field(..., description="Type of official receipt (WHITE, RED, PORT, FEE, etc.)")
    receipt_number: str = Field(..., description="Official receipt / invoice number")
    receipt_date: date = Field(..., description="Date on receipt")
    issuing_entity: str = Field(..., description="Government entity or vendor issuing the receipt")
    amount: float = Field(..., gt=0.0, description="Gross receipt amount")
    tax_withholding_rate: float = Field(0.0, ge=0.0, le=1.0, description="WHT rate (e.g. 0.01 for broker fees)")
    e_invoice_uuid: Optional[str] = Field(None, description="Egyptian E-Invoice UUID")
    is_official_receipt: bool = Field(True, description="Whether receipt is backed by official document")
    notes: Optional[str] = None


class BrokerSettlementReceiptUpdate(BaseModel):
    receipt_type: Optional[str] = None
    receipt_number: Optional[str] = None
    receipt_date: Optional[date] = None
    issuing_entity: Optional[str] = None
    amount: Optional[float] = Field(None, gt=0.0)
    tax_withholding_rate: Optional[float] = Field(None, ge=0.0, le=1.0)
    e_invoice_uuid: Optional[str] = None
    is_official_receipt: Optional[bool] = None
    verification_status: Optional[str] = None
    notes: Optional[str] = None


@read_model
class BrokerSettlementReceiptResponse(LegacyRowTolerantModel):
    id: int
    advance_id: int
    receipt_type: str
    receipt_number: str
    receipt_date: date
    issuing_entity: str
    amount: float
    tax_withholding_rate: float = 0.0
    tax_withheld_amount: float = 0.0
    net_amount: float = 0.0
    e_invoice_uuid: Optional[str] = None
    is_official_receipt: bool = True
    verification_status: str = "PENDING"
    notes: Optional[str] = None
    is_active: bool = True
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Customs Broker Advance Schemas (Wave 1)
# ---------------------------------------------------------------------------
class CustomsBrokerAdvanceCreate(BaseModel):
    import_file_id: int = Field(..., description="Import file ID")
    broker_id: int = Field(..., description="Customs broker provider ID")
    broker_name: Optional[str] = Field(None, description="Customs broker name")
    advance_amount: float = Field(..., gt=0.0, description="Disbursed advance amount in EGP")
    disbursement_date: date = Field(..., description="Disbursement date")
    payment_method: str = Field("BANK_TRANSFER", description="BANK_TRANSFER, CASH, CHECK")
    notes: Optional[str] = None


class CustomsBrokerAdvanceUpdate(BaseModel):
    broker_name: Optional[str] = None
    advance_amount: Optional[float] = Field(None, gt=0.0)
    disbursement_date: Optional[date] = None
    payment_method: Optional[str] = None
    status: Optional[str] = None
    notes: Optional[str] = None


@read_model
class CustomsBrokerAdvanceResponse(LegacyRowTolerantModel):
    id: int
    advance_code: str
    import_file_id: int
    broker_id: int
    broker_name: str
    advance_amount: float
    disbursement_date: date
    payment_method: str = "BANK_TRANSFER"
    status: str = "OPEN"
    settled_amount: float = 0.0
    remaining_balance: float = 0.0
    notes: Optional[str] = None
    is_active: bool = True
    created_by: Optional[str] = "system"
    updated_by: Optional[str] = "system"
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    receipts: List[BrokerSettlementReceiptResponse] = []

    model_config = ConfigDict(from_attributes=True)


class CustomsBrokerAdvanceListResponse(BaseModel):
    total: int
    items: List[CustomsBrokerAdvanceResponse]


class CustomsSettlementVarianceResponse(BaseModel):
    advance_id: int
    advance_code: str
    advance_amount: float
    total_receipts_amount: float
    total_tax_withheld: float
    total_net_settled: float
    variance_amount: float  # advance_amount - total_net_settled (positive = refund to company, negative = broker reimbursement)
    status: str
    white_receipts_total: float
    red_receipts_total: float
    port_receipts_total: float
    broker_fees_total: float
    other_receipts_total: float
    verified_receipts_count: int
    pending_receipts_count: int


# ===========================================================================
# Legacy Compatibility Schemas
# ===========================================================================
class BrokerExpenseItemCreate(BaseModel):
    expense_category: str = Field(...)
    is_e_invoice_backed: bool = Field(False)
    e_invoice_uuid: Optional[str] = None
    receipt_reference: Optional[str] = None
    amount: float = Field(..., gt=0.0)
    tax_withholding_rate: float = Field(0.01, ge=0.0, le=1.0)
    approval_status: str = Field("PENDING")
    notes: Optional[str] = None


class BrokerExpenseItemUpdate(BaseModel):
    expense_category: Optional[str] = None
    is_e_invoice_backed: Optional[bool] = None
    e_invoice_uuid: Optional[str] = None
    receipt_reference: Optional[str] = None
    amount: Optional[float] = Field(None, gt=0.0)
    tax_withholding_rate: Optional[float] = Field(None, ge=0.0, le=1.0)
    approval_status: Optional[str] = None
    notes: Optional[str] = None


class ExpenseItemApprovalRequest(BaseModel):
    approval_status: str = Field("APPROVED")
    verified_by: Optional[str] = None
    notes: Optional[str] = None


@read_model
class BrokerExpenseItemResponse(LegacyRowTolerantModel):
    item_id: int
    advance_id: int
    expense_category: str
    is_e_invoice_backed: bool = False
    e_invoice_uuid: Optional[str] = None
    receipt_reference: Optional[str] = None
    amount: float
    tax_withholding_rate: float = 0.01
    tax_withheld_amount: float = 0.0
    net_settled_amount: float = 0.0
    approval_status: str = "PENDING"
    verified_by: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    is_active: bool = True

    model_config = ConfigDict(from_attributes=True)


class BrokerCustodyAdvanceCreate(BaseModel):
    import_file_id: int = Field(...)
    broker_id: int = Field(...)
    broker_name: Optional[str] = None
    advance_amount: float = Field(..., gt=0.0)
    disbursement_date: date = Field(...)
    payment_method: str = Field("BANK_TRANSFER")
    notes: Optional[str] = None


class BrokerCustodyAdvanceUpdate(BaseModel):
    broker_name: Optional[str] = None
    advance_amount: Optional[float] = Field(None, gt=0.0)
    disbursement_date: Optional[date] = None
    payment_method: Optional[str] = None
    status: Optional[str] = None
    notes: Optional[str] = None


@read_model
class BrokerCustodyAdvanceResponse(LegacyRowTolerantModel):
    advance_id: int
    advance_code: str
    import_file_id: int
    import_file_code: Optional[str] = None
    broker_id: int
    broker_name: str
    advance_amount: float
    disbursement_date: date
    payment_method: str = "BANK_TRANSFER"
    status: str = "OPEN"
    settled_amount: float = 0.0
    remaining_balance: float = 0.0
    notes: Optional[str] = None
    expense_items: List[BrokerExpenseItemResponse] = []
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    is_active: bool = True

    model_config = ConfigDict(from_attributes=True)


class BrokerCustodyAdvanceListResponse(BaseModel):
    total: int
    items: List[BrokerCustodyAdvanceResponse]


class SettlementReconciliationResponse(BaseModel):
    advance_id: int
    advance_code: str
    advance_amount: float
    total_expenses_claimed: float
    total_tax_withheld_w41: float
    total_net_settled: float
    balance_remaining: float
    status: str
    approved_items_count: int
    pending_items_count: int
    reconciliation_summary: str
