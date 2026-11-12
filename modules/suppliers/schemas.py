from datetime import date, datetime
from typing import ClassVar, List

from pydantic import BaseModel, Field
from pydantic import ConfigDict


# ==================================================
# Base Schema
# ==================================================

class SupplierBase(BaseModel):

    company_name: str

    # Supplier Classification

    supplier_type: str = "Manufacturer"

    registration_type: str = "Foreign Exporter"

    foreign_exporter_id: str = ""

    cargox_platform_id: str | None = None

    foreign_exporter_country: str = "United Kingdom"

    foreign_exporter_country_code: str = "GB"

    tax_id: str | None = None

    currency: str = "USD"

    # Contact & Location Information

    contact_person: str | None = None

    city: str | None = None

    postal_code: str | None = None

    address: str = "Exporter Address"

    phone: str | None = None

    mobile: str | None = None

    fax: str | None = None

    email: str | None = None

    secondary_email: str | None = None

    website: str | None = None

    bank_name: str | None = None

    swift_code: str | None = None

    account_number: str | None = None

    iban: str | None = None

    has_iso: bool = False

    # Trademark & Quality Certificates
    has_wipo: bool = False
    wipo_number: str | None = None
    has_euipo: bool = False
    euipo_number: str | None = None
    has_global_brand: bool = False
    global_brand_number: str | None = None
    has_iso_9001: bool = False
    iso_9001_number: str | None = None
    wipo_expiry: date | None = None
    euipo_expiry: date | None = None
    global_brand_expiry: date | None = None
    iso_9001_expiry: date | None = None

    registered_decree_43: bool = False

    white_list_registered: bool = False

    brands: str | None = None

    payment_terms: str | None = None

    credit_limit: float = 0.0

    rating: float = 5.0

    notes: str | None = None


# ==================================================
# Create Supplier
# ==================================================

class SupplierCreate(SupplierBase):

    created_by: str | None = None


# ==================================================
# Update Supplier
# ==================================================

class SupplierUpdate(BaseModel):

    company_name: str | None = None

    supplier_type: str | None = None

    registration_type: str | None = None

    foreign_exporter_id: str | None = None

    cargox_platform_id: str | None = None

    tax_id: str | None = None

    currency: str | None = None

    foreign_exporter_country: str | None = None

    foreign_exporter_country_code: str | None = None

    contact_person: str | None = None

    city: str | None = None

    postal_code: str | None = None

    address: str | None = None

    phone: str | None = None

    mobile: str | None = None

    fax: str | None = None

    email: str | None = None

    secondary_email: str | None = None

    website: str | None = None

    bank_name: str | None = None

    swift_code: str | None = None

    account_number: str | None = None

    iban: str | None = None

    has_iso: bool | None = None

    has_wipo: bool | None = None
    wipo_number: str | None = None
    has_euipo: bool | None = None
    euipo_number: str | None = None
    has_global_brand: bool | None = None
    global_brand_number: str | None = None
    has_iso_9001: bool | None = None
    iso_9001_number: str | None = None
    wipo_expiry: date | None = None
    euipo_expiry: date | None = None
    global_brand_expiry: date | None = None
    iso_9001_expiry: date | None = None

    registered_decree_43: bool | None = None

    white_list_registered: bool | None = None

    brands: str | None = None

    payment_terms: str | None = None

    credit_limit: float | None = None

    rating: float | None = None

    notes: str | None = None

    is_active: bool | None = None

    updated_by: str | None = None

    # Fields where an explicit JSON null means "clear the stored value".
    # Every other field keeps the legacy behaviour: null is ignored, so partial
    # payloads (e.g. Nafeza supplier coding) never wipe existing data.
    CLEARABLE_FIELDS: ClassVar[frozenset[str]] = frozenset({
        "wipo_expiry", "euipo_expiry", "global_brand_expiry", "iso_9001_expiry",
    })

    def to_update_dict(self) -> dict:
        """Fields to apply on update: set values, plus explicit nulls on clearable fields."""
        data = self.model_dump(exclude_unset=True)
        return {
            field: value for field, value in data.items()
            if value is not None or field in self.CLEARABLE_FIELDS
        }



# ==================================================
# Response Schema
# ==================================================

class SupplierResponse(SupplierBase):

    supplier_id: int

    # Auto Generated Supplier Code
    supplier_code: str

    is_active: bool

    created_at: datetime

    updated_at: datetime | None = None

    created_by: str | None = None

    updated_by: str | None = None

    # Credit limit governance (set through PUT /suppliers/{id}/credit-limit)
    credit_limit_currency: str | None = None

    credit_limit_policy: str | None = "BLOCK"


    model_config = ConfigDict(
        from_attributes=True
    )


class SupplierScorecardResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    supplier_id: int
    supplier_code: str
    company_name: str
    supplier_type: str
    country: str
    total_orders_completed: int
    crd_adherence_rate: float
    documentation_accuracy_rate: float
    order_fulfillment_rate: float
    quality_score_out_of_100: float
    star_rating: float
    tier_badge: str
    executive_summary_ar: str


# ==================================================
# Sub-Ledger, Aging & Credit Limit (Trello GzFff0Pc)
# ==================================================

class SupplierLedgerWarning(BaseModel):
    code: str
    import_file_id: int | None = None
    import_file_code: str | None = None
    reason: str | None = None


class SupplierLedgerEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    entry_code: str | None = None
    source_key: str
    entry_type: str
    direction: str
    payment_pathway: str | None = None
    reference: str | None = None
    description: str | None = None
    import_file_id: int | None = None
    payment_id: int | None = None
    finance_instrument_id: int | None = None
    entry_date: date
    due_date: date | None = None
    currency: str
    amount_fx: float
    exchange_rate: float | None = None
    amount_egp: float
    open_amount_fx: float
    status: str
    balance_fx: float
    balance_egp: float


class SupplierCurrencyBalanceResponse(BaseModel):
    currency: str
    billed_fx: float
    paid_fx: float
    balance_fx: float
    open_payable_fx: float
    unapplied_fx: float
    open_commitments_fx: float
    book_balance_egp: float
    current_rate: float | None = None
    current_balance_egp: float | None = None


class SupplierCurrencyStatementResponse(BaseModel):
    currency: str
    opening_balance_fx: float
    opening_balance_egp: float
    closing_balance_fx: float
    closing_balance_egp: float
    lines: List[SupplierLedgerEntryResponse]


class SupplierStatementResponse(BaseModel):
    supplier_id: int
    supplier_code: str
    company_name: str
    date_from: date | None = None
    date_to: date | None = None
    balances: List[SupplierCurrencyBalanceResponse]
    statements: List[SupplierCurrencyStatementResponse]
    warnings: List[SupplierLedgerWarning] = []


class SupplierAgingItemResponse(BaseModel):
    entry_code: str | None = None
    reference: str | None = None
    import_file_id: int | None = None
    payment_pathway: str | None = None
    entry_date: date
    due_date: date | None = None
    amount_fx: float
    open_amount_fx: float
    days_past_due: int
    bucket: str


class SupplierCurrencyAgingResponse(BaseModel):
    currency: str
    current: float
    days_1_30: float
    days_31_60: float
    days_61_90: float
    over_90: float
    total_open_fx: float
    unapplied_fx: float
    current_rate: float | None = None
    total_open_egp: float | None = None
    items: List[SupplierAgingItemResponse] = []


class SupplierAgingResponse(BaseModel):
    supplier_id: int
    supplier_code: str
    company_name: str
    as_of: date
    currencies: List[SupplierCurrencyAgingResponse]
    total_open_egp: float | None = None
    warnings: List[SupplierLedgerWarning] = []


class SupplierAgingReportRow(BaseModel):
    supplier_id: int
    supplier_code: str
    company_name: str
    currencies: List[SupplierCurrencyAgingResponse]
    total_open_egp: float | None = None


class SupplierAgingReportResponse(BaseModel):
    as_of: date
    rows: List[SupplierAgingReportRow]


class SupplierCreditCheckRequest(BaseModel):
    amount: float = Field(..., ge=0)
    currency: str | None = Field(None, max_length=10)


class SupplierCreditCheckResponse(BaseModel):
    has_limit: bool
    currency: str
    policy: str
    limit_amount: float
    utilization_amount: float
    requested_amount: float
    projected_amount: float
    available_amount: float | None = None
    utilization_pct: float | None = None
    exceeded: bool
    allowed: bool
    decision: str


class SupplierCreditLimitUpdate(BaseModel):
    credit_limit: float = Field(..., ge=0)
    credit_limit_currency: str | None = Field(None, max_length=10)
    credit_limit_policy: str = Field("BLOCK", max_length=10)


class SupplierCreditOverrideResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    override_id: int
    context: str
    reference: str | None = None
    currency: str
    limit_amount: float
    utilization_amount: float
    requested_amount: float
    projected_amount: float
    reason: str
    created_at: datetime
    created_by: str


class SupplierCreditStatusResponse(BaseModel):
    supplier_id: int
    credit: SupplierCreditCheckResponse
    balances: List[SupplierCurrencyBalanceResponse]
    overrides: List[SupplierCreditOverrideResponse] = []
