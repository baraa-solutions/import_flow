"""
Pydantic Schemas for Financial & Management Approval (BP-012 & BP-013)
"""

from typing import Any, Dict, List, Literal, Optional
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field, field_validator

from modules.common.legacy_rows import read_model
from modules.financial_approval.validators import normalize_payment_type, require_payment_type

PaymentStatusLiteral = Literal["Draft", "Pending Approval", "Approved", "Paid", "Rejected"]
PaymentStatusFilter = Literal["All", "Draft", "Pending Approval", "Approved", "Paid", "Rejected"]
BudgetStatusFilter = Literal[
    "All", "Draft", "Pending Review", "Needs Revalidation", "Budget Approved", "Superseded", "Budget Exceeded", "Rejected"
]


# --- PAYMENT REQUEST SCHEMAS (BP-012) ---
class PaymentRequestBase(BaseModel):
    title: str = Field(..., min_length=3, max_length=200)
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    supplier_id: Optional[int] = None
    supplier_name: str = Field(..., min_length=2, max_length=200)
    project_id: Optional[int] = None
    payment_type: str = Field(
        default="ADVANCE_PAYMENT",
        description="PAYMENT_TYPE code: ADVANCE_PAYMENT, AGAINST_BL, LETTER_OF_CREDIT, DOCUMENTARY_COLLECTION, "
        "FINAL_SETTLEMENT (legacy English labels are accepted and normalized)",
    )
    requested_amount: float = Field(..., gt=0.0)
    advance_percentage: Optional[float] = Field(None, ge=0.0, le=100.0, description="Percentage of PO requested as advance")
    currency_code: str = Field(default="USD", max_length=10)
    exchange_rate: float = Field(default=50.0, gt=0.0)
    due_date: date
    request_date: Optional[date] = None
    status: Optional[str] = Field("Draft", description="Draft, Pending Approval, Approved, Paid, Rejected")
    beneficiary_name: Optional[str] = None
    bank_name: Optional[str] = None
    swift_code: Optional[str] = None
    iban_account_no: Optional[str] = None
    bank_country: Optional[str] = None
    notes: Optional[str] = None


class PaymentRequestCreate(PaymentRequestBase):
    # C1: no default rate. C4: ``status`` is server-owned (only Draft / Pending Approval are kept, else Draft).
    exchange_rate: float = Field(..., gt=0.0)

    @field_validator("payment_type", mode="before")
    @classmethod
    def _payment_type_code(cls, value: Any) -> str:
        return require_payment_type(value)


class ClonePaymentRequestRequest(BaseModel):
    new_title: Optional[str] = None
    target_supplier_id: Optional[int] = None
    new_requested_amount: Optional[float] = None
    unlink_import_file: bool = False
    remarks: Optional[str] = None


class PaymentRequestUpdate(BaseModel):
    """C4: the SWIFT reconciliation fields (``swift_reference_no`` ... ``swift_reconciliation_notes``) are ignored
    (written only by pay / reconcile); ``swift_code`` (beneficiary BIC) stays editable. ``status`` may only follow the user transitions (validators)."""
    title: Optional[str] = Field(None, min_length=3, max_length=200)
    import_file_id: Optional[int] = None
    payment_type: Optional[str] = None
    requested_amount: Optional[float] = Field(None, gt=0.0)
    advance_percentage: Optional[float] = Field(None, ge=0.0, le=100.0)
    currency_code: Optional[str] = Field(None, max_length=10)
    exchange_rate: Optional[float] = Field(None, gt=0.0)
    due_date: Optional[date] = None
    request_date: Optional[date] = None
    status: Optional[PaymentStatusLiteral] = None
    beneficiary_name: Optional[str] = None
    bank_name: Optional[str] = None
    swift_code: Optional[str] = None
    iban_account_no: Optional[str] = None
    swift_reference_no: Optional[str] = None
    swift_receipt_date: Optional[date] = None
    swift_transferred_amount: Optional[float] = None
    swift_transferred_currency: Optional[str] = None
    swift_variance_amount: Optional[float] = None
    swift_variance_status: Optional[str] = None
    swift_processing_days: Optional[int] = None
    swift_reconciliation_notes: Optional[str] = None
    notes: Optional[str] = None
    version: Optional[int] = Field(None, description="Current record version for optimistic concurrency control")

    @field_validator("payment_type", mode="before")
    @classmethod
    def _payment_type_code(cls, value: Any) -> Optional[str]:
        return None if value is None else require_payment_type(value)


class SwiftReconciliationRequest(BaseModel):
    swift_reference_no: str = Field(..., min_length=2, max_length=100, description="SWIFT Reference / MT103 No")
    swift_receipt_date: date = Field(..., description="Date SWIFT was received from the bank")
    swift_transferred_amount: float = Field(..., gt=0.0, description="Actual transferred amount according to SWIFT")
    swift_transferred_currency: str = Field(default="USD", max_length=10)
    swift_reconciliation_notes: Optional[str] = None


@read_model
class PaymentRequestResponse(PaymentRequestBase):
    payment_id: int
    payment_code: str
    version: int = 1
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    requested_amount_egp: float
    request_date: date
    status: str
    swift_reference_no: Optional[str] = None
    swift_receipt_date: Optional[date] = None
    swift_transferred_amount: Optional[float] = None
    swift_transferred_currency: Optional[str] = None
    swift_variance_amount: Optional[float] = None
    swift_variance_status: Optional[str] = None
    swift_processing_days: Optional[int] = None
    swift_reconciliation_notes: Optional[str] = None
    smart_task_code: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_validator("payment_type", mode="before")
    @classmethod
    def _payment_type_code(cls, value: Any) -> Any:
        # Legacy rows are shown as codes; unknown legacy text is returned unchanged (never a 500 on read).
        return normalize_payment_type(value)


# --- IMPORT BUDGET APPROVAL SCHEMAS (BP-013) ---
class ImportBudgetBase(BaseModel):
    title: str = Field(..., min_length=3, max_length=200)
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    project_id: Optional[int] = None
    invoice_amount_egp: float = Field(default=0.0, ge=0.0)
    invoice_amount_foreign: float = Field(default=0.0, ge=0.0)
    invoice_currency: str = Field(default="USD", max_length=10)
    freight_cost_egp: float = Field(default=0.0, ge=0.0)
    freight_cost_foreign: float = Field(default=0.0, ge=0.0)
    freight_currency: str = Field(default="USD", max_length=10)
    customs_duties_egp: float = Field(default=0.0, ge=0.0)
    clearance_inland_egp: float = Field(default=0.0, ge=0.0)
    exchange_rate: float = Field(default=50.0, gt=0.0)
    notes: Optional[str] = None


class ImportBudgetCreate(ImportBudgetBase):
    exchange_rate: float = Field(..., gt=0.0)  # C1: no default rate


class CloneImportBudgetRequest(BaseModel):
    new_title: Optional[str] = None
    target_import_file_id: Optional[int] = None
    unlink_import_file: bool = False
    new_exchange_rate: Optional[float] = None
    remarks: Optional[str] = None



class ImportBudgetUpdate(BaseModel):
    """C4: ``budget_status`` and ``approved_by`` are accepted for compatibility and ignored (approval goes through
    /approve, revisions through /sync)."""
    title: Optional[str] = Field(None, min_length=3, max_length=200)
    import_file_id: Optional[int] = None
    invoice_amount_egp: Optional[float] = Field(None, ge=0.0)
    invoice_amount_foreign: Optional[float] = Field(None, ge=0.0)
    invoice_currency: Optional[str] = Field(None, max_length=10)
    freight_cost_egp: Optional[float] = Field(None, ge=0.0)
    freight_cost_foreign: Optional[float] = Field(None, ge=0.0)
    freight_currency: Optional[str] = Field(None, max_length=10)
    customs_duties_egp: Optional[float] = Field(None, ge=0.0)
    clearance_inland_egp: Optional[float] = Field(None, ge=0.0)
    exchange_rate: Optional[float] = Field(None, gt=0.0)
    budget_status: Optional[str] = None
    approved_by: Optional[str] = None
    notes: Optional[str] = None
    version: Optional[int] = Field(None, description="Current record version for optimistic concurrency control")


@read_model
class ImportBudgetResponse(ImportBudgetBase):
    budget_id: int
    budget_code: str
    version: int = 1
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    total_budget_egp: float
    budget_status: str
    approved_by: Optional[str] = None
    approved_date: Optional[date] = None
    parent_budget_id: Optional[int] = None
    revision_number: int = 1
    last_variance_check: Optional[datetime] = None
    has_unresolved_variance: bool = False
    variance_override_reason: Optional[str] = None
    variance_overridden_by: Optional[str] = None
    upstream_modified_by: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- CROSS-MODULE PREFILL SCHEMAS ---
class LinkedPOItemSchema(BaseModel):
    po_id: int
    po_number: str
    pi_number: Optional[str] = None
    project_id: Optional[int] = None
    project_name: Optional[str] = None
    payment_terms: str
    currency: str
    total_amount: float
    status: str


class BudgetPrefillResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    import_file_title: str
    incoterm: str
    supplier_id: Optional[int] = None
    supplier_name: str
    beneficiary_name: Optional[str] = None
    bank_name: Optional[str] = None
    swift_code: Optional[str] = None
    account_number: Optional[str] = None
    iban: Optional[str] = None
    payment_terms_summary: str
    linked_pos: List[LinkedPOItemSchema] = []
    
    # Financial estimates
    total_invoice_amount: float = 0.0
    invoice_currency: str = "USD"
    total_invoice_amount_egp: float = 0.0
    
    estimated_freight_cost: float = 0.0
    freight_currency: str = "USD"
    estimated_freight_cost_egp: float = 0.0
    
    estimated_customs_duties_egp: float = 0.0
    estimated_clearance_fees_egp: float = 0.0
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    estimated_grand_total_egp: float = 0.0
    # Commercial rate of invoice_currency. FA_FX_RATE_MISSING when the invoice amount > 0 and no rate is recorded;
    # None for an empty file (invoice amount 0) whose currency has no rate yet.
    exchange_rate: Optional[float] = None


# --- SMART AI SWIFT MT103 EXTRACTOR & RECONCILER SCHEMAS ---
class SwiftFieldResponse(BaseModel):
    id: int
    batch_id: int
    field_key: str
    swift_field_code: Optional[str] = None
    field_label: str
    raw_ocr_text: Optional[str] = None
    parsed_value: Optional[str] = None
    confidence_score: float = 0.0
    is_edited_by_user: bool = False
    edited_value: Optional[str] = None
    final_value: Optional[str] = None
    is_mandatory: bool = False
    is_empty: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class SwiftBatchResponse(BaseModel):
    batch_id: int
    batch_code: str
    source_filename: Optional[str] = None
    source_file_type: Optional[str] = None
    raw_source_text: str
    normalized_text: Optional[str] = None
    status: str
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    matched_payment_id: Optional[int] = None
    reconciled_at: Optional[datetime] = None
    fields: List[SwiftFieldResponse] = []
    all_mandatory_valid: bool = False
    missing_mandatory_fields: List[str] = []
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class SwiftFieldUpdateRequest(BaseModel):
    value: str = Field(..., description="New value for the field entered by user")
    user_name: Optional[str] = Field(None, description="Ignored: the editor is the authenticated user")


class SwiftBatchConfirmRequest(BaseModel):
    user_name: Optional[str] = Field(None, description="Ignored: the reviewer is the authenticated user")


class SwiftBatchConfirmResponse(BaseModel):
    success: bool
    batch_id: int
    batch_code: str
    status: str
    message: str
    message_code: Optional[str] = None
    message_params: Dict[str, Any] = {}
    confirmed_fields: dict
    batch: SwiftBatchResponse


class SwiftBatchMatchResponse(BaseModel):
    success: bool
    batch_id: int
    status: str
    matched_payment_request: Optional[dict] = None
    candidate_matches: List[dict] = []
    confirmed_fields: dict


class SwiftBatchReconcileRequest(BaseModel):
    payment_id: int
    auto_execute: bool = True
    notes: Optional[str] = None
    user_name: Optional[str] = Field(None, description="Ignored: the actor is the authenticated user")


class SmartSwiftExtractRequest(BaseModel):
    raw_text: str = Field(..., min_length=1, description="Raw SWIFT MT103 block or bank transfer advice text")
    target_payment_id: Optional[int] = Field(None, description="Optional target payment request ID to match specifically")


class SmartSwiftFileExtractRequest(BaseModel):
    filename: str
    file_base64: str
    target_payment_id: Optional[int] = None


class SmartSwiftExtractResponse(BaseModel):
    success: bool
    parsed_swift: dict
    matched_payment_request: Optional[dict] = None
    candidate_matches: List[dict] = []
    raw_text: Optional[str] = None
    detected_filename: Optional[str] = None
    detected_file_type: Optional[str] = None
    error: Optional[str] = None
    batch_id: Optional[int] = None
    batch: Optional[SwiftBatchResponse] = None


class SmartSwiftReconcileRequest(BaseModel):
    payment_id: int
    raw_text: Optional[str] = None
    swift_reference_no: str
    swift_receipt_date: date
    swift_transferred_amount: float
    swift_transferred_currency: str = "USD"
    bank_name: Optional[str] = None
    swift_code: Optional[str] = None
    iban_account_no: Optional[str] = None
    swift_reconciliation_notes: Optional[str] = None
    auto_execute: bool = True


# --- BUDGET VARIANCE & REVISION SCHEMAS ---
class BudgetVarianceLogResponse(BaseModel):
    id: int
    budget_id: int
    import_file_id: int
    field_name: str
    old_value: float
    new_value: float
    variance_amount: float
    variance_percentage: float
    threshold_percentage: float
    is_hard_block: bool
    detected_at: datetime
    modified_by: Optional[str] = None
    resolved_at: Optional[datetime] = None
    resolved_by: Optional[str] = None
    resolution_type: str
    justification_note: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class BudgetVarianceOverrideRequest(BaseModel):
    justification_note: str = Field(..., min_length=5, description="Written justification required to override hard block")


class BudgetVarianceSettingResponse(BaseModel):
    setting_id: int
    setting_key: str
    setting_value: str
    description: Optional[str] = None
    updated_by: Optional[str] = None
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class BudgetVarianceSettingUpdate(BaseModel):
    threshold_percentage: float = Field(..., gt=0.0, le=100.0, description="Variance threshold percentage e.g. 5.0")


class BudgetSyncResultResponse(BaseModel):
    budget: ImportBudgetResponse
    action_taken: str  # 'auto_updated', 'revalidation_required', 'revision_created'
    revision_created: bool = False
    original_budget_status: Optional[str] = None
    variance_logs: List[BudgetVarianceLogResponse] = []
    message: str
    message_code: Optional[str] = None
    message_params: Dict[str, Any] = {}

