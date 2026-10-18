from typing import Optional, List, Dict, Any, Literal
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model

# Invoice number prefix of the single adjustment row per field written by the recalculation engine (RC-01).
# Only these rows may carry a negative amount (live total lower than the user invoices).
RECALC_ADJUSTMENT_PREFIX = "RECALC-ADJ-"

# Statuses a client may set through PUT; "Approved" is reached only through approve-actual-landed-cost (FS-03).
EDITABLE_SETTLEMENT_STATUSES = ("Draft", "Calculated")

# Allocation rule names accepted from clients (review 2 #13); other values are a 422.
AllocationRule = Literal["Value-Based", "Weight-Based", "Volume-Based", "Equal"]


class SettlementMessage(BaseModel):
    """Language-neutral message (code + params) the client renders; same shape as ``SystemMessageItem``."""
    code: str
    params: Dict[str, Any] = {}
    severity: str = "warning"


class ExpenseInvoiceSchema(BaseModel):
    invoice_no: str
    category: str = Field(..., description="Freight, Customs Duty, Brokerage, Local Transport, Storage, Insurance, Other")
    provider_name: str
    currency: str = "USD"
    amount_fx: float
    # Optional: missing = 1.0 for EGP, else the rate table on the invoice date (409 SETTLEMENT_FX_RATE_MISSING).
    exchange_rate: Optional[float] = Field(None, gt=0.0)
    amount_egp: float = 0.0
    allocation_rule: AllocationRule = Field("Value-Based", description="Value-Based, Weight-Based, Volume-Based, Equal")

    @model_validator(mode="after")
    def _non_negative_unless_adjustment(self) -> "ExpenseInvoiceSchema":
        if not (self.invoice_no or "").startswith(RECALC_ADJUSTMENT_PREFIX):
            if self.amount_fx < 0:
                raise ValueError("amount_fx must be >= 0")
            if self.amount_egp < 0:
                raise ValueError("amount_egp must be >= 0")
        return self

class ItemLandedCostSchema(BaseModel):
    item_code: str
    item_name: str
    qty: float = Field(..., gt=0)
    gross_weight_kg: float = Field(0.0, ge=0.0)
    cbm: float = Field(0.0, ge=0.0)
    fob_unit_egp: float = Field(..., ge=0.0)
    fob_total_egp: float = Field(0.0, ge=0.0)
    allocated_freight_egp: float = 0.0
    allocated_customs_egp: float = 0.0
    allocated_clearance_egp: float = 0.0
    allocated_transport_egp: float = 0.0
    allocated_other_egp: float = 0.0
    total_landed_cost_egp: float = 0.0
    unit_landed_cost_egp: float = 0.0
    markup_factor: float = 1.0

VALID_INCOTERMS = {"EXW", "FCA", "CPT", "CIP", "DAP", "DPU", "DDP", "FAS", "FOB", "CFR", "CIF"}


def _validate_incoterm_code(v: Optional[str]) -> Optional[str]:
    if v is None:
        return v
    code = v.strip().upper()
    if code not in VALID_INCOTERMS:
        raise ValueError(f"شرط التسليم '{v}' غير صالح. يجب أن يكون أحد شروط التجارة الدولية (Incoterms 2020).")
    return code


class FinancialSettlementCreate(BaseModel):
    import_file_id: int
    incoterm_code: Optional[str] = "FOB"
    expense_invoices: List[ExpenseInvoiceSchema] = []
    item_landed_costs: List[ItemLandedCostSchema] = []
    accountant_name: Optional[str] = Field(None, description="Ignored: the acting user is recorded")
    notes: Optional[str] = None

    @field_validator("incoterm_code", mode="after")
    @classmethod
    def validate_incoterm(cls, v: Optional[str]) -> Optional[str]:
        return _validate_incoterm_code(v)


class FinancialSettlementUpdate(BaseModel):
    incoterm_code: Optional[str] = None
    expense_invoices: Optional[List[ExpenseInvoiceSchema]] = None
    item_landed_costs: Optional[List[ItemLandedCostSchema]] = None
    status: Optional[Literal["Draft", "Calculated"]] = None
    accountant_name: Optional[str] = Field(None, description="Ignored: the acting user is recorded")
    notes: Optional[str] = None

    @field_validator("incoterm_code", mode="after")
    @classmethod
    def validate_incoterm(cls, v: Optional[str]) -> Optional[str]:
        return _validate_incoterm_code(v)


@read_model
class FinancialSettlementResponse(LegacyRowTolerantModel):
    settlement_id: int
    settlement_code: str
    import_file_id: int
    incoterm_code: Optional[str] = "FOB"
    expense_invoices: List[Dict[str, Any]] = []
    total_fob_egp: float = 0.0
    total_expenses_egp: float = 0.0
    total_landed_cost_egp: float = 0.0
    average_markup_factor: float = 1.0
    item_landed_costs: List[Dict[str, Any]] = []
    status: Optional[str] = None
    accountant_name: Optional[str] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None
    deleted_at: Optional[datetime] = None
    deleted_by: Optional[str] = None
    created_at: Optional[datetime] = None
    created_by: Optional[str] = None
    updated_at: Optional[datetime] = None
    updated_by: Optional[str] = None
    messages: List[SettlementMessage] = []

    model_config = ConfigDict(from_attributes=True)

class OdooJournalLineItem(BaseModel):
    account_code: str
    account_name: str
    partner_name: str
    label: str
    debit: float = 0.0
    credit: float = 0.0
    currency: str = "EGP"
    amount_currency: Optional[float] = None
    analytic_account: Optional[str] = None
    cost_category: str = "Goods"

class OdooJournalEntryResponse(BaseModel):
    settlement_id: int
    settlement_code: str
    import_file_code: str
    company_name: str
    supplier_name: str
    project_name: Optional[str] = None
    entry_date: str
    journal_name: str = "Miscellaneous Operations / Vendor Bills"
    reference: str
    total_debit: float
    total_credit: float
    is_balanced: bool
    difference: float = 0.0
    lines: List[OdooJournalLineItem] = []
    items_breakdown: List[Dict[str, Any]] = []

class OdooExportConfig(BaseModel):
    inventory_account_code: str = "110400"
    inventory_account_name: str = "بضاعة بالطريق - Goods in Transit (Landed Cost)"
    supplier_account_code: str = "210100"
    freight_account_code: str = "210200"
    customs_broker_account_code: str = "210300"
    transport_account_code: str = "210400"
    customs_authority_account_code: str = "210500"
    demurrage_account_code: str = "210600"
    price_adjustment_account_code: str = "210700"
    other_expenses_account_code: str = "210800"
    journal_code: str = "MISC"


# ==============================================================================
# PL-08: Estimated Landed Cost Simulation Schemas
# ==============================================================================
from datetime import date

class EstimatedLandedCostItemBreakdown(BaseModel):
    line_no: int
    item_code: str
    item_name: str
    hs_code: str
    qty: float
    unit_price_fc: float
    fob_total_fc: float
    fob_unit_egp: float
    fob_total_egp: float
    allocated_freight_egp: float = 0.0
    allocated_insurance_egp: float = 0.0
    allocated_customs_duty_egp: float = 0.0
    allocated_vat_egp: float = 0.0
    allocated_clearance_and_port_egp: float = 0.0
    allocated_inland_transport_egp: float = 0.0
    allocated_other_egp: float = 0.0
    total_expenses_allocated_egp: float = 0.0
    total_landed_cost_egp: float = 0.0
    unit_landed_cost_egp: float = 0.0
    unit_landed_cost_fc: float = 0.0
    markup_factor: float = 1.0
    markup_percent: float = 0.0

class EstimatedLandedCostExpenseItem(BaseModel):
    category: str
    description: str
    amount_fc: float = 0.0
    currency: str = "EGP"
    amount_egp: float = 0.0
    is_estimated: bool = True
    source: str = "Standard Estimate"
    allocation_rule: str = "Value-Based"

class EstimatedLandedCostSimulationRequest(BaseModel):
    exchange_rate_override: Optional[float] = None
    freight_amount_egp_override: Optional[float] = None
    insurance_amount_egp_override: Optional[float] = None
    clearance_fees_egp_override: Optional[float] = None
    inland_transport_egp_override: Optional[float] = None
    port_handling_egp_override: Optional[float] = None
    bank_fees_egp_override: Optional[float] = None
    other_expenses_egp_override: Optional[float] = None
    allocation_preference: AllocationRule = Field("Value-Based", description="Value-Based, Weight-Based, Volume-Based")
    estimate_date: Optional[date] = None

class EstimatedLandedCostSimulationResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    currency: str = "USD"
    exchange_rate: float
    incoterm: str = "FOB"
    total_fob_fc: float
    total_fob_egp: float
    total_freight_egp: float
    total_insurance_egp: float
    total_customs_and_taxes_egp: float
    total_clearance_and_port_egp: float
    total_inland_transport_egp: float
    total_other_expenses_egp: float
    total_expenses_egp: float
    total_landed_cost_egp: float
    total_landed_cost_fc: float
    average_markup_factor: float
    average_markup_percent: float
    expenses_breakdown: List[EstimatedLandedCostExpenseItem] = []
    items_breakdown: List[EstimatedLandedCostItemBreakdown] = []
    executive_summary_ar: str
    # Additive (phase 09): the real import-duty / VAT-and-fees split of total_customs_and_taxes_egp.
    total_customs_duty_egp: float = 0.0
    total_vat_and_fees_egp: float = 0.0
    messages: List[SettlementMessage] = []


# ==============================================================================
# CLO-01: Final Settlement Invoices Aggregation Schemas
# ==============================================================================

class AggregatedInvoiceItemSchema(BaseModel):
    invoice_id: Optional[str] = None
    invoice_no: str
    invoice_date: Optional[str] = None
    party_type: str = Field("OTHER", description="SUPPLIER, CARRIER, CUSTOMS, INSURANCE, BROKER, TRANSPORT, DEMURRAGE, WAREHOUSE, OTHER")
    party_type_ar: str
    party_name: str
    category: str
    category_ar: str
    category_code: Optional[str] = None  # enum code when the source stores one (CLEARANCE_EXPENSE_CATEGORY)
    currency: str = "EGP"
    exchange_rate: float = 1.0
    amount_fc: float = 0.0
    amount_egp: float = 0.0
    paid_amount_egp: float = 0.0
    remaining_amount_egp: float = 0.0
    payment_status: str = Field("PAID", description="PAID, PARTIAL, UNPAID")
    payment_reference: Optional[str] = None
    withholding_tax_rate: float = 0.0
    withholding_tax_amount_egp: float = 0.0
    net_payable_egp: float = 0.0
    source_module: str = Field("Manual", description="Source module or table name")
    notes: Optional[str] = None


class InvoicesPartySummary(BaseModel):
    party_type: str
    party_type_ar: str
    party_name: str
    invoices_count: int = 0
    total_egp: float = 0.0
    paid_egp: float = 0.0
    remaining_egp: float = 0.0


class InvoicesAggregationResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    supplier_name: str
    currency: str = "USD"
    exchange_rate: float = 0.0
    total_invoices_count: int = 0
    total_amount_egp: float = 0.0
    total_paid_egp: float = 0.0
    total_remaining_egp: float = 0.0
    total_withholding_tax_egp: float = 0.0
    settlement_readiness_percent: float = 0.0
    financial_settlement_status: str = "PENDING_SETTLEMENT"
    parties_summary: List[InvoicesPartySummary] = []
    invoices: List[AggregatedInvoiceItemSchema] = []
    unsettled_warnings: List[str] = []  # deprecated (Arabic text): render ``messages``
    messages: List[SettlementMessage] = []


class ConfirmInvoicesSettlementRequest(BaseModel):
    import_file_id: int
    settled_by: Optional[str] = Field(None, description="Ignored: the acting user is recorded")
    settlement_notes: Optional[str] = None
    invoices_overrides: Optional[List[AggregatedInvoiceItemSchema]] = Field(
        None, description="Ignored: the server re-aggregates the invoices"
    )


class ConfirmInvoicesSettlementResponse(BaseModel):
    success: bool = True
    import_file_id: int
    import_file_code: str
    financial_settlement_status: str
    financial_settlement_date: str
    invoices_count: int
    total_settled_egp: float
    progress_percent: float
    current_stage: str
    current_module: str
    next_task_code: str
    next_task_title: str
    message: str


# ==============================================================================
# CLO-02: Actual Landed Cost Calculation & Variance Schemas
# ==============================================================================

class ActualLandedCostCategoryBreakdown(BaseModel):
    category: str
    category_ar: str
    estimated_egp: float = 0.0
    actual_egp: float = 0.0
    variance_egp: float = 0.0
    variance_pct: float = 0.0
    invoices_count: int = 0
    allocation_rule: str = "Value-Based"


class ActualLandedCostItemLine(BaseModel):
    line_no: int
    item_code: str
    item_name: str
    hs_code: str
    qty: float
    gross_weight_kg: float = 0.0
    cbm: float = 0.0
    fob_unit_egp: float = 0.0
    fob_total_egp: float = 0.0
    allocated_freight_egp: float = 0.0
    allocated_insurance_egp: float = 0.0
    allocated_customs_duty_egp: float = 0.0
    allocated_vat_egp: float = 0.0
    allocated_clearance_egp: float = 0.0
    allocated_inland_transport_egp: float = 0.0
    allocated_demurrage_egp: float = 0.0
    allocated_other_egp: float = 0.0
    total_allocated_expenses_egp: float = 0.0
    actual_total_landed_cost_egp: float = 0.0
    actual_unit_landed_cost_egp: float = 0.0
    actual_markup_factor: float = 1.0
    actual_markup_pct: float = 0.0
    estimated_unit_landed_cost_egp: float = 0.0
    unit_cost_variance_egp: float = 0.0
    unit_cost_variance_pct: float = 0.0
    item_variance_status: str = "MATCHED" # "SAVING", "MATCHED", "INCREASED"


class ActualLandedCostCalculationRequest(BaseModel):
    allocation_preference: AllocationRule = Field("Value-Based", description="Value-Based, Weight-Based, Volume-Based, Equal")
    custom_category_allocation: Optional[Dict[str, str]] = None


class ActualLandedCostCalculationResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    supplier_name: str
    currency: str = "USD"
    exchange_rate: float = 0.0
    incoterm: str = "FOB"
    allocation_preference: str = "Value-Based"
    total_items_count: int = 0
    total_invoices_count: int = 0
    estimated_total_fob_egp: float = 0.0
    actual_total_fob_egp: float = 0.0
    fob_variance_egp: float = 0.0
    fob_variance_pct: float = 0.0
    estimated_total_expenses_egp: float = 0.0
    actual_total_expenses_egp: float = 0.0
    expenses_variance_egp: float = 0.0
    expenses_variance_pct: float = 0.0
    estimated_total_landed_cost_egp: float = 0.0
    actual_total_landed_cost_egp: float = 0.0
    landed_variance_egp: float = 0.0
    landed_variance_pct: float = 0.0
    estimated_markup_factor: float = 1.0
    actual_markup_factor: float = 1.0
    variance_status: str = "ON_BUDGET" # "UNDER_BUDGET", "ON_BUDGET", "OVER_BUDGET"
    variance_status_ar: str = "مطابق للميزانية التقديرية"
    categories_breakdown: List[ActualLandedCostCategoryBreakdown] = []
    items_breakdown: List[ActualLandedCostItemLine] = []
    executive_summary_ar: str = ""
    # Additive (phase 09): header landed cost minus the sum of the rounded item landed costs (not redistributed).
    reconciliation_difference_egp: float = 0.0
    messages: List[SettlementMessage] = []


class ApproveActualLandedCostRequest(BaseModel):
    import_file_id: int
    approved_by: Optional[str] = Field(None, description="Ignored: the acting user is recorded")
    allocation_preference: AllocationRule = Field("Value-Based", description="Value-Based, Weight-Based, Volume-Based, Equal")
    notes: Optional[str] = None
    custom_category_allocation: Optional[Dict[str, str]] = None


class ApproveActualLandedCostResponse(BaseModel):
    success: bool = True
    import_file_id: int
    import_file_code: str
    settlement_id: int
    settlement_code: str
    financial_settlement_status: str = "COST_ALLOCATED"
    actual_landed_cost_total_egp: float
    actual_landed_cost_markup_factor: float
    landed_variance_egp: float
    landed_variance_pct: float
    variance_status: str
    progress_percent: float
    current_stage: str
    current_module: str
    next_task_code: str
    next_task_title: str
    message: str


