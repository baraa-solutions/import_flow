from datetime import datetime
from typing import Optional, Any, List, Dict
from pydantic import BaseModel, Field, ConfigDict


class PartnerBase(BaseModel):
    partner_name: str = Field(..., min_length=2, max_length=200, json_schema_extra={"example": "National Bank of Egypt"})
    partner_type: str = Field(..., json_schema_extra={"example": "Bank"})  # Bank, Shipping Line, Customs Broker, Freight Forwarder, Inland Transport, Inspection Agency

    tax_id: Optional[str] = Field(None, max_length=50)
    commercial_register: Optional[str] = Field(None, max_length=50)

    # Category Specific
    clearance_license_number: Optional[str] = Field(None, max_length=50)
    authorized_ports: Optional[str] = Field(None, max_length=300, description="الموانئ والمنافذ الجمركية المعتمدة للعمل بها")
    scac_code: Optional[str] = Field(None, max_length=20)
    tracking_url: Optional[str] = Field(None, max_length=300)
    default_free_days: Optional[int] = Field(None, ge=0, description="فترة السماح الافتراضية بالأيام (Free Days)")
    local_agent_name: Optional[str] = Field(None, max_length=200, description="اسم التوكيل الملاحي المحلي في مصر")
    booking_email: Optional[str] = Field(None, max_length=150, description="بريد الحجز والعمليات")
    fiata_id: Optional[str] = Field(None, max_length=50, description="رخصة الفياتا أو كود ترخيص الشحن الدولي")
    shipping_modes: Optional[str] = Field(None, max_length=200, description="طرق الشحن المدعومة (FCL, LCL, Air, Land)")
    supported_currencies: Optional[str] = Field(None, max_length=100, description="العملات المعتمدة لتقديم عروض الأسعار")
    inspection_accreditation_number: Optional[str] = Field(None, max_length=100, description="رقم اعتماد جهة الفحص والتسجيل بالرقابة على الصادرات GOIEC / ISO")
    inspection_scope: Optional[str] = Field(None, max_length=300, description="نطاق الفحص المعتمد وشهادات المطابقة CoC / VOC")
    transport_license_number: Optional[str] = Field(None, max_length=100, description="رقم ترخيص النقل البري / وزارة النقل")
    fleet_types: Optional[str] = Field(None, max_length=300, description="أنواع الشاحنات والأسطول (حاويات 20/40، كساحات، برادات، جامبو)")
    coverage_areas: Optional[str] = Field(None, max_length=300, description="نطاق التغطية الجغرافية والمحافظات والموانئ")
    insurance_license_number: Optional[str] = Field(None, max_length=100, description="رقم ترخيص الهيئة العامة للرقابة المالية FRA لشركة التأمين")
    insurance_coverage_types: Optional[str] = Field(None, max_length=300, description="أنواع التغطيات التأمينية المعتمدة (شروط أ، ب، ج، أخطار حرب)")
    swift_code: Optional[str] = Field(None, max_length=20)
    bank_code: Optional[str] = Field(None, max_length=20)
    branch_name: Optional[str] = Field(None, max_length=100)
    account_number: Optional[str] = Field(None, max_length=100, description="رقم الحساب البنكي")
    iban: Optional[str] = Field(None, max_length=100, description="رقم الآيبان الدولي")

    # Contact & Info
    contact_person: Optional[str] = Field(None, max_length=150)
    phone: Optional[str] = Field(None, max_length=50)
    mobile: Optional[str] = Field(None, max_length=50)
    fax: Optional[str] = Field(None, max_length=50)
    email: Optional[str] = Field(None, max_length=150)
    secondary_email: Optional[str] = Field(None, max_length=150)
    website: Optional[str] = Field(None, max_length=200)
    address: Optional[str] = Field(None, max_length=300)
    country: Optional[str] = Field("Egypt", max_length=100)

    # Financial & Rating
    payment_type: Optional[str] = Field("Credit", max_length=50)
    payment_terms: Optional[str] = Field(None, max_length=100, description="شروط الدفع والائتمان")
    credit_limit: Optional[float] = Field(0.0, ge=0.0)
    rating: Optional[float] = Field(5.0, ge=1.0, le=5.0)
    notes: Optional[str] = Field(None, max_length=1000)


class PartnerCreate(PartnerBase):
    pass


class PartnerUpdate(BaseModel):
    partner_name: Optional[str] = Field(None, min_length=2, max_length=200)
    partner_type: Optional[str] = None
    tax_id: Optional[str] = None
    commercial_register: Optional[str] = None
    clearance_license_number: Optional[str] = None
    authorized_ports: Optional[str] = None
    scac_code: Optional[str] = None
    tracking_url: Optional[str] = None
    default_free_days: Optional[int] = None
    local_agent_name: Optional[str] = None
    booking_email: Optional[str] = None
    fiata_id: Optional[str] = None
    shipping_modes: Optional[str] = None
    supported_currencies: Optional[str] = None
    inspection_accreditation_number: Optional[str] = None
    inspection_scope: Optional[str] = None
    transport_license_number: Optional[str] = None
    fleet_types: Optional[str] = None
    coverage_areas: Optional[str] = None
    insurance_license_number: Optional[str] = None
    insurance_coverage_types: Optional[str] = None
    swift_code: Optional[str] = None
    bank_code: Optional[str] = None
    branch_name: Optional[str] = None
    account_number: Optional[str] = None
    iban: Optional[str] = None
    contact_person: Optional[str] = None
    phone: Optional[str] = None
    mobile: Optional[str] = None
    fax: Optional[str] = None
    email: Optional[str] = None
    secondary_email: Optional[str] = None
    website: Optional[str] = None
    address: Optional[str] = None
    country: Optional[str] = None
    payment_type: Optional[str] = None
    payment_terms: Optional[str] = None
    credit_limit: Optional[float] = None
    rating: Optional[float] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class PartnerResponse(PartnerBase):
    provider_id: int
    partner_code: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Partner Statement of Account & Currency Balances Schemas
# كشف حساب مقدم الخدمة والشركاء متعدد العملات
# ==================================================

class PartnerCurrencyBalance(BaseModel):
    currency: str
    total_invoiced: float = 0.0
    total_paid: float = 0.0
    balance_due: float = 0.0
    exchange_rate_used: Optional[float] = None
    rate_type: Optional[str] = None
    rate_date: Optional[str] = None
    equivalent_egp: Optional[float] = None
    warning: Optional[str] = None


class PartnerLedgerEntry(BaseModel):
    entry_id: str
    entry_date: str
    entry_type: str  # 'Invoice (فاتورة مستحقة)', 'Payment (سداد مالي)', 'Quotation (عرض سعر معتمد)'
    reference_no: str
    description: str
    import_file_code: Optional[str] = None
    project_name: Optional[str] = None
    bl_number: Optional[str] = None
    importer_name: Optional[str] = None
    currency: str
    debit_amount: float = 0.0   # مستحق على الشركة لمقدم الخدمة
    credit_amount: float = 0.0  # مسدد لمقدم الخدمة
    running_balance: float = 0.0
    status: str = "Approved"


class PartnerStatementOfAccountResponse(BaseModel):
    provider_id: int
    partner_code: str
    partner_name: str
    partner_type: str
    currency_balances: list[PartnerCurrencyBalance] = []
    equivalent_egp_total: Optional[float] = None
    ledger_entries: list[PartnerLedgerEntry] = []
    total_invoices_count: int = 0
    total_payments_count: int = 0
    as_of_date: Optional[str] = None
    rate_type: Optional[str] = None
    has_unconverted_balances: bool = False


# ==================================================
# LOG-KPIS-005: Partner KPI Scorecard Response
# ==================================================

class PartnerScorecardResponse(BaseModel):
    provider_id: int
    partner_code: str
    partner_name: str
    partner_type: str
    total_jobs_completed: int
    on_time_performance_rate: float  # نسبة الالتزام بالمواعيد %
    average_clearance_days: Optional[float] = None
    average_transit_delay_days: Optional[float] = None
    green_channel_rate: Optional[float] = None
    quality_score_out_of_100: float
    star_rating: float  # 1.0 to 5.0
    tier_badge: str  # "Platinum A+", "Gold A", "Silver B", "Probation C"
    executive_summary_ar: str
    criteria_breakdown: Optional[list[dict[str, Any]]] = None

    model_config = ConfigDict(from_attributes=True)