from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model


# ---------------------------------------------------------------------------
# Expense Item Schemas
# ---------------------------------------------------------------------------
class BrokerExpenseItemCreate(BaseModel):
    expense_category: str = Field(
        ...,
        description=(
            "Expense category: OFFICIAL_DUTIES_TAXES, PORT_AUTHORITY_FEES, "
            "LAB_TESTING_FEES, HANDLING_AND_PORTERAGE, INSPECTION_TRANSPORT, SUNDRY_PETTY_CASH"
        ),
    )
    is_e_invoice_backed: bool = Field(False, description="Whether expense has an official E-Invoice")
    e_invoice_uuid: Optional[str] = Field(None, description="UUID of Egyptian E-Invoice if backed")
    receipt_reference: Optional[str] = Field(None, description="Official receipt or document number")
    amount: float = Field(..., gt=0.0, description="Gross expense amount")
    tax_withholding_rate: float = Field(0.01, ge=0.0, le=1.0, description="WHT rate (default 0.01 for 1% W-41)")
    approval_status: str = Field("PENDING", description="Approval status: PENDING, APPROVED, REJECTED")
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
    approval_status: str = Field("APPROVED", description="APPROVED or REJECTED")
    verified_by: Optional[str] = Field(None, description="Name/username of approver")
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


# ---------------------------------------------------------------------------
# Custody Advance Schemas
# ---------------------------------------------------------------------------
class BrokerCustodyAdvanceCreate(BaseModel):
    import_file_id: int = Field(..., description="ID of the associated import file")
    broker_id: int = Field(..., description="Provider ID of the customs broker")
    broker_name: Optional[str] = Field(None, description="Customs broker full name")
    advance_amount: float = Field(..., gt=0.0, description="Custody advance disbursement amount in EGP")
    disbursement_date: date = Field(..., description="Date advance was disbursed")
    payment_method: str = Field("BANK_TRANSFER", description="Disbursement payment method: CASH, BANK_TRANSFER, CHECK")
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


# ---------------------------------------------------------------------------
# Settlement Reconciliation Schemas
# ---------------------------------------------------------------------------
class SettlementReconciliationResponse(BaseModel):
    advance_id: int
    advance_code: str
    advance_amount: float
    total_expenses_claimed: float
    total_tax_withheld_w41: float
    total_net_settled: float
    balance_remaining: float
    status: str  # OPEN, PARTIALLY_SETTLED, SETTLED
    approved_items_count: int
    pending_items_count: int
    reconciliation_summary: str
