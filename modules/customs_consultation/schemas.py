"""
Customs Consultation & Broker Price Lists Pydantic Schemas (BP-009)
"""

from datetime import datetime, date
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field, field_validator


# ==============================================================================
# Clearance Expense Types Schemas (تكويد أنواع المصروفات)
# ==============================================================================

class ClearanceExpenseTypeBase(BaseModel):
    expense_code: str = Field(..., min_length=2, max_length=50)
    name_ar: str = Field(..., min_length=2, max_length=200)
    name_en: Optional[str] = None
    category: str = Field(..., min_length=2, max_length=100)
    default_unit: str = Field("PER_INVOICE", min_length=2, max_length=100)
    default_currency: str = "EGP"
    display_order: int = 0
    is_active: bool = True


class ClearanceExpenseTypeCreate(ClearanceExpenseTypeBase):
    pass


class ClearanceExpenseTypeUpdate(BaseModel):
    expense_code: Optional[str] = None
    name_ar: Optional[str] = None
    name_en: Optional[str] = None
    category: Optional[str] = None
    default_unit: Optional[str] = None
    default_currency: Optional[str] = None
    display_order: Optional[int] = None
    is_active: Optional[bool] = None


class ClearanceExpenseTypeResponse(ClearanceExpenseTypeBase):
    expense_id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# Broker Price List Items Schemas (بنود قائمة أسعار المخلص)
# ==============================================================================

class BrokerPriceListItemBase(BaseModel):
    expense_type_id: Optional[int] = None
    expense_name: str = Field(..., min_length=2, max_length=200)
    category: str = Field(..., min_length=2, max_length=100)
    unit_type: str = Field(..., min_length=2, max_length=100)
    standard_price: float = 0.0
    currency: str = "EGP"
    min_price: Optional[float] = None
    max_price: Optional[float] = None
    notes: Optional[str] = None
    is_active: bool = True


class BrokerPriceListItemCreate(BrokerPriceListItemBase):
    pass


class BrokerPriceListItemUpdate(BaseModel):
    expense_type_id: Optional[int] = None
    expense_name: Optional[str] = None
    category: Optional[str] = None
    unit_type: Optional[str] = None
    standard_price: Optional[float] = None
    currency: Optional[str] = None
    min_price: Optional[float] = None
    max_price: Optional[float] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class BrokerPriceListItemResponse(BrokerPriceListItemBase):
    item_id: int
    price_list_id: int

    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# Broker Price List Header Schemas (قوائم أسعار المخلصين)
# ==============================================================================

class BrokerPriceListBase(BaseModel):
    title: str = Field(..., min_length=2, max_length=200)
    broker_id: int
    broker_name: str = Field(..., min_length=2, max_length=200)
    port_name: Optional[str] = None
    effective_from: date
    effective_to: Optional[date] = None
    version: int = 1
    is_active: bool = True
    notes: Optional[str] = None


class BrokerPriceListCreate(BrokerPriceListBase):
    items: List[BrokerPriceListItemCreate] = []


class BrokerPriceListUpdate(BaseModel):
    title: Optional[str] = None
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    port_name: Optional[str] = None
    effective_from: Optional[date] = None
    effective_to: Optional[date] = None
    version: Optional[int] = None
    is_active: Optional[bool] = None
    notes: Optional[str] = None
    items: Optional[List[BrokerPriceListItemCreate]] = None


class BrokerPriceListResponse(BrokerPriceListBase):
    price_list_id: int
    price_list_code: str
    cloned_from_id: Optional[int] = None
    cloned_from_code: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    items: List[BrokerPriceListItemResponse] = []

    model_config = ConfigDict(from_attributes=True)


class CloneBrokerPriceListRequest(BaseModel):
    new_price_list_code: Optional[str] = None
    new_title: str = Field(..., min_length=2, max_length=200)
    effective_from: Optional[date] = None
    effective_to: Optional[date] = None
    notes: Optional[str] = None



# ==============================================================================
# Broker Quote Item in Study Schemas (تفاصيل عرض سعر المخلص في الاستشارة)
# ==============================================================================

class CustomsBrokerQuoteItemBase(BaseModel):
    expense_type_id: Optional[int] = None
    expense_name: str = Field(..., min_length=2, max_length=200)
    category: str = Field(..., min_length=2, max_length=100)
    unit_type: str = "Per Invoice"
    unit_price: float = 0.0
    currency: str = "EGP"
    qty: float = 1.0
    is_applicable: bool = True
    total_amount: float = 0.0
    notes: Optional[str] = None


class CustomsBrokerQuoteItemCreate(CustomsBrokerQuoteItemBase):
    pass


class CustomsBrokerQuoteItemResponse(CustomsBrokerQuoteItemBase):
    quote_item_id: int
    consultation_id: int

    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# Checklist Items Schemas (قائمة فحص المستندات والاشتراطات)
# ==============================================================================

class CustomsChecklistItemBase(BaseModel):
    document_type: str = Field(..., min_length=2, max_length=100)
    hs_code: Optional[str] = None
    is_required: bool = True
    required_text: Optional[str] = "✓"
    is_blocking_shipment: bool = True
    responsible_party: str = "Customs Broker"
    status: str = "Pending"  # Pending, Received, Verified, Approved, Rejected
    received_date: Optional[date] = None
    verified_date: Optional[date] = None
    regulatory_agency: Optional[str] = None
    remarks: Optional[str] = None
    corrective_action_required: Optional[str] = None

    @field_validator("received_date", "verified_date", mode="before")
    @classmethod
    def empty_str_to_none(cls, v):
        if v == "" or v is None:
            return None
        if isinstance(v, str) and not v.strip():
            return None
        return v


class CustomsChecklistItemCreate(CustomsChecklistItemBase):
    pass


class CustomsChecklistItemResponse(CustomsChecklistItemBase):
    item_id: int
    consultation_id: int

    model_config = ConfigDict(from_attributes=True)


# ==============================================================================
# Consultation Session Schemas (دراسة الاستشارة والفحص الجمركي)
# ==============================================================================

class CustomsConsultationBase(BaseModel):
    title: str = Field(..., min_length=2, max_length=200)
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    broker_contact_person: Optional[str] = None
    broker_price_list_id: Optional[int] = None
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    project_id: Optional[int] = None
    overall_status: str = "Pending Review"  # Pending Review, In Progress, Action Required, Clearance Ready, Blocked
    estimated_duties_egp: float = 0.0
    total_broker_fees_egp: float = 0.0
    notes: Optional[str] = None


class CustomsConsultationCreate(CustomsConsultationBase):
    checklist_items: List[CustomsChecklistItemCreate] = []
    broker_quote_items: List[CustomsBrokerQuoteItemCreate] = []


class CustomsConsultationUpdate(BaseModel):
    title: Optional[str] = None
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    broker_contact_person: Optional[str] = None
    broker_price_list_id: Optional[int] = None
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    project_id: Optional[int] = None
    overall_status: Optional[str] = None
    estimated_duties_egp: Optional[float] = None
    total_broker_fees_egp: Optional[float] = None
    notes: Optional[str] = None
    checklist_items: Optional[List[CustomsChecklistItemCreate]] = None
    broker_quote_items: Optional[List[CustomsBrokerQuoteItemCreate]] = None


class CustomsConsultationResponse(CustomsConsultationBase):
    consultation_id: int
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    consultation_code: str
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    has_blocking_issues: bool
    readiness_percentage: float
    is_active: bool
    cloned_from_id: Optional[int] = None
    cloned_from_code: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    checklist_items: List[CustomsChecklistItemResponse] = []
    broker_quote_items: List[CustomsBrokerQuoteItemResponse] = []
    
    # Computed metrics
    total_documents_count: int = 0
    approved_documents_count: int = 0
    blocking_issues_count: int = 0
    applied_broker_items_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class CloneConsultationRequest(BaseModel):
    new_consultation_code: Optional[str] = None
    new_title: str = Field(..., min_length=2, max_length=200)
    target_import_file_id: Optional[int] = None
    copy_checklist_items: bool = Field(True, description="Copy regulatory document checklist")
    copy_broker_quote_items: bool = Field(True, description="Copy quote breakdown items")
    notes: Optional[str] = None



# ==============================================================================
# Re-estimation & Variance Comparison Schemas (إعادة احتساب الجمارك ومقارنة الفروق)
# ==============================================================================

class CustomsRecalculationRequest(BaseModel):
    import_file_id: int
    # Manual customs rates (EGP per unit). exchange_rate = final side; when the preliminary (PO) currency
    # differs, preliminary_exchange_rate is the preliminary side. A side without a manual rate uses the table.
    exchange_rate: Optional[float] = None
    preliminary_exchange_rate: Optional[float] = None
    freight_egp: Optional[float] = 0.0
    insurance_egp: Optional[float] = 0.0
    estimate_date: Optional[date] = None


class LineVarianceComparison(BaseModel):
    item_name: str
    hs_code: str
    country_of_origin: Optional[str] = None
    # OK, or TARIFF_MISSING: no HS code / no tariff valid on the estimate date. Such a line carries zero
    # taxes and is excluded from every response total (no fallback rate is used).
    status: str = "OK"
    preliminary_qty: float = 0.0
    final_qty: float = 0.0
    qty_variance: float = 0.0
    preliminary_unit_price: float = 0.0
    final_unit_price: float = 0.0
    unit_price_variance: float = 0.0
    preliminary_fob_egp: float = 0.0
    final_fob_egp: float = 0.0
    fob_variance_egp: float = 0.0
    preliminary_cif_egp: float = 0.0
    final_cif_egp: float = 0.0
    cif_variance_egp: float = 0.0
    duty_rate_pct: float = 0.0
    preliminary_duty_egp: float = 0.0
    final_duty_egp: float = 0.0
    duty_variance_egp: float = 0.0
    vat_rate_pct: float = 0.0
    preliminary_vat_egp: float = 0.0
    final_vat_egp: float = 0.0
    vat_variance_egp: float = 0.0
    preliminary_total_taxes_egp: float = 0.0
    final_total_taxes_egp: float = 0.0
    total_taxes_variance_egp: float = 0.0


class CustomsRecalculationResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    final_invoice_number: Optional[str] = None
    reconciliation_session_id: Optional[int] = None
    is_reconciled: bool = False
    source_description: str = "Reconciled Final Commercial Invoice"
    exchange_rate: float  # final side (EGP per unit of final_currency)
    preliminary_exchange_rate: Optional[float] = None
    preliminary_currency: Optional[str] = None
    final_currency: Optional[str] = None
    exchange_rate_source: str = "table"  # final side: "table" (customs rate table on the date) / "manual"
    preliminary_exchange_rate_source: str = "table"
    estimate_date: date
    preliminary_fob_egp: float = 0.0
    final_fob_egp: float = 0.0
    fob_variance_egp: float = 0.0
    preliminary_cif_egp: float = 0.0
    final_cif_egp: float = 0.0
    cif_variance_egp: float = 0.0
    preliminary_duty_egp: float = 0.0
    final_duty_egp: float = 0.0
    duty_variance_egp: float = 0.0
    preliminary_vat_egp: float = 0.0
    final_vat_egp: float = 0.0
    vat_variance_egp: float = 0.0
    preliminary_total_taxes_egp: float = 0.0
    final_total_taxes_egp: float = 0.0
    total_taxes_variance_egp: float = 0.0
    variance_percentage: float = 0.0
    forecast_status: str = "Balanced"  # "Increased Cost", "Reduced Cost", "Exact Match"
    tariff_missing_lines_count: int = 0
    comparison_lines: List[LineVarianceComparison] = []

