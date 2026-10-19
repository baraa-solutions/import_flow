from datetime import date, datetime
from decimal import Decimal
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from modules.common import enum_codes


def normalize_customs_category(value: Optional[str]) -> Optional[str]:
    """CUSTOMS_CATEGORY enum code for a known label; unknown free text is kept (trimmed)."""
    if value is None:
        return None
    return enum_codes.normalize(enum_codes.CUSTOMS_CATEGORY, value.strip())


# ==================================================
# Customs Tariff Schemas (MD-008)
# ==================================================

class CustomsTariffCreate(BaseModel):
    hs_code: str = Field(..., min_length=4, max_length=20, description="HS Code البند الجمركي")
    hs_description: str = Field(..., min_length=5, max_length=500, description="وصف البند")
    customs_category: Optional[str] = Field(None, max_length=100, description="تصنيف البند")

    # Tax rates — must be >= 0 and <= 100
    customs_duty_rate: Decimal = Field(..., ge=0, le=100, description="نسبة ضريبة الوارد %")
    vat_rate: Decimal = Field(..., ge=0, le=100, description="نسبة ضريبة القيمة المضافة %")
    schedule_tax_rate: Decimal = Field(default=Decimal("0.00"), ge=0, le=100, description="نسبة ضريبة الجدول %")
    development_fee_rate: Decimal = Field(default=Decimal("0.00"), ge=0, le=100, description="نسبة رسم التنمية %")
    import_fee_rate: Decimal = Field(default=Decimal("0.00"), ge=0, le=100, description="نسبة رسم الوارد %")
    customs_service_fee_rate: Decimal = Field(default=Decimal("1.00"), ge=0, le=100, description="نسبة رسم الخدمات الجمركية أ.ت.ص % (افتراضي 1%)")

    # Requirements
    requires_coo: bool = Field(default=False, description="يتطلب شهادة منشأ")
    requires_inspection: bool = Field(default=False, description="يتطلب شهادة فحص")
    requires_acid: bool = Field(default=True, description="يتطلب ACID")
    regulatory_authority: Optional[str] = Field(None, max_length=500, description="الجهات الرقابية")
    prior_approval_note: Optional[str] = Field(None, description="ملاحظات وشروط الموافقة المسبقة")

    # Effective dates
    effective_from: date = Field(default_factory=date.today, description="تاريخ بداية السريان")
    effective_to: Optional[date] = Field(None, description="تاريخ انتهاء السريان (None = ساري حتى الآن)")

    # Audit & Verification Metadata (Addendum 3)
    source_url: Optional[str] = Field(None, max_length=500, description="رابط صفحة نافذة الرسمية للتحقق")
    last_verified_date: Optional[date] = Field(default_factory=date.today, description="تاريخ آخر مراجعة يدوية")
    verified_by: Optional[str] = Field("System Admin", max_length=100, description="اسم المراجع المسؤول")
    confidence: Optional[str] = Field("verified_manual", max_length=50, description="مستوى الثقة")

    notes: Optional[str] = Field(None, description="ملاحظات")

    @field_validator("hs_code")
    @classmethod
    def normalize_hs_code(cls, v: str) -> str:
        """Normalize HS Code — trim whitespace, keep as-is (dots are valid in HS codes)."""
        return v.strip()

    @field_validator("customs_category")
    @classmethod
    def normalize_customs_category(cls, v: Optional[str]) -> Optional[str]:
        """Store the CUSTOMS_CATEGORY code (legacy Arabic / English labels are mapped; free text passes through)."""
        return normalize_customs_category(v)

    @model_validator(mode="after")
    def validate_effective_dates(self) -> "CustomsTariffCreate":
        if self.effective_to and self.effective_from:
            if self.effective_to <= self.effective_from:
                raise ValueError("effective_to must be after effective_from")
        return self


class CustomsTariffUpdate(BaseModel):
    hs_description: Optional[str] = Field(None, min_length=5, max_length=500)
    customs_category: Optional[str] = Field(None, max_length=100)

    customs_duty_rate: Optional[Decimal] = Field(None, ge=0, le=100)
    vat_rate: Optional[Decimal] = Field(None, ge=0, le=100)
    schedule_tax_rate: Optional[Decimal] = Field(None, ge=0, le=100)
    development_fee_rate: Optional[Decimal] = Field(None, ge=0, le=100)
    import_fee_rate: Optional[Decimal] = Field(None, ge=0, le=100)
    customs_service_fee_rate: Optional[Decimal] = Field(None, ge=0, le=100)

    requires_coo: Optional[bool] = None
    requires_inspection: Optional[bool] = None
    requires_acid: Optional[bool] = None
    regulatory_authority: Optional[str] = Field(None, max_length=500)
    prior_approval_note: Optional[str] = None

    effective_from: Optional[date] = None
    effective_to: Optional[date] = None

    source_url: Optional[str] = None
    last_verified_date: Optional[date] = None
    verified_by: Optional[str] = None
    confidence: Optional[str] = None
    notes: Optional[str] = None

    @field_validator("customs_category")
    @classmethod
    def normalize_customs_category(cls, v: Optional[str]) -> Optional[str]:
        return normalize_customs_category(v)

    @model_validator(mode="after")
    def validate_effective_dates(self) -> "CustomsTariffUpdate":
        if self.effective_to and self.effective_from:
            if self.effective_to <= self.effective_from:
                raise ValueError("effective_to must be after effective_from")
        return self


class CustomsTariffResponse(BaseModel):
    tariff_id: int
    hs_code: str
    hs_description: str
    customs_category: Optional[str]

    customs_duty_rate: Decimal
    vat_rate: Decimal
    schedule_tax_rate: Decimal
    development_fee_rate: Decimal
    import_fee_rate: Decimal
    customs_service_fee_rate: Decimal

    requires_coo: bool
    requires_inspection: bool
    requires_acid: bool
    regulatory_authority: Optional[str]
    prior_approval_note: Optional[str]

    effective_from: date
    effective_to: Optional[date]

    source_url: Optional[str]
    last_verified_date: Optional[date]
    verified_by: Optional[str]
    confidence: Optional[str]

    notes: Optional[str]
    is_active: bool
    total_versions: int = Field(default=1, description="إجمالي عدد المراحل والإصدارات التاريخية والسارية لهذا البند")
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Fee Code Schemas (Nafeza Statement Fee Codes Registry)
# ==================================================

FeeCodeCalculationType = Literal["flat", "reference", "derived"]
FeeCodeReferenceSource = Literal["duty_amount", "service_fee_amount", "vat_amount"]


class FeeCodeCreate(BaseModel):
    code: str = Field(..., min_length=1, max_length=10, description="كود الرسم نافذة الرسمي")
    name_ar: str = Field(..., min_length=2, max_length=200, description="اسم الرسم باللغة العربية")
    collection_group: str = Field(..., max_length=100, description="المجموعة: رسم مستخلص / ضريبة جمارك / أ.ت.ص ...")
    calculation_type: FeeCodeCalculationType = Field(default="flat", description="نوع الحساب: flat, reference, derived")
    flat_amount: Optional[Decimal] = Field(default=Decimal("0.00"), ge=0)
    reference_source: Optional[FeeCodeReferenceSource] = Field(None, description="duty_amount, service_fee_amount, vat_amount")
    derived_formula_rate: Optional[Decimal] = Field(None, ge=0, le=100)
    derived_formula_base_codes: Optional[str] = Field(None, description="الأكواد بالفواصل e.g. 390,392")
    effective_from: date = Field(default_factory=date.today)
    effective_to: Optional[date] = None
    source_url: Optional[str] = None
    notes: Optional[str] = None

    @model_validator(mode="after")
    def validate_calculation_rules(self) -> "FeeCodeCreate":
        if self.calculation_type == "reference":
            if not self.reference_source:
                raise ValueError("reference_source is required when calculation_type is 'reference'")
        elif self.calculation_type == "derived":
            if self.derived_formula_rate is None or not (self.derived_formula_base_codes and self.derived_formula_base_codes.strip()):
                raise ValueError("derived_formula_rate and derived_formula_base_codes are required when calculation_type is 'derived'")
        return self


class FeeCodeResponse(BaseModel):
    fee_code_id: int
    code: str
    name_ar: str
    collection_group: str
    calculation_type: str
    flat_amount: Optional[Decimal]
    reference_source: Optional[str]
    derived_formula_rate: Optional[Decimal]
    derived_formula_base_codes: Optional[str]
    effective_from: date
    effective_to: Optional[date]
    source_url: Optional[str]
    notes: Optional[str]
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Preferential Trade Agreement & Manual Audit Schemas (Addendum 3)
# ==================================================

class PreferentialAgreementCreate(BaseModel):
    hs_code: str = Field(..., min_length=4, max_length=20)
    agreement_name: str = Field(..., max_length=200)
    reduction_type: str = Field(default="percentage_of_duty", description="percentage_of_duty, full_duty_exemption, fixed_rate")
    reduction_percentage: Decimal = Field(default=Decimal("1.00"), ge=0, le=1)
    preferential_duty_rate: Optional[Decimal] = Field(None, ge=0, le=100, description="سعر الضريبة التفضيلية المباشرة (مثل 3% للميركسور)")
    publication_notice: Optional[str] = Field(None, max_length=100, description="رقم المنشور الجمركي (مثل ر6722)")
    required_document: Optional[str] = Field(None, max_length=250, description="المستند أو الشهادة المطلوبة (مثل شهادة EUR.1)")
    origin_countries: str = Field(..., description="قائمة رموز الدول المعنية بالفواصل e.g. JO,TN,MA")
    conditions_note: Optional[str] = None
    effective_from: date = Field(default_factory=date.today)
    effective_to: Optional[date] = None
    source_url: Optional[str] = None

    @field_validator("hs_code")
    @classmethod
    def validate_hs_code_format(cls, v: str) -> str:
        clean = (v or "").strip()
        digits = clean.replace(".", "")
        if not digits.isdigit() or len(digits) < 4 or len(digits) > 10:
            raise ValueError("صيغة البند الجمركي غير صحيحة. يجب أن يتكون البند الجمركي من 4 إلى 10 أرقام.")
        return clean

    @model_validator(mode="after")
    def validate_dates(self) -> "PreferentialAgreementCreate":
        if self.effective_to and self.effective_to <= self.effective_from:
            raise ValueError("تاريخ انتهاء السريان يجب أن يكون بعد تاريخ البداية (effective_to must be after effective_from).")
        return self


class PreferentialAgreementResponse(BaseModel):
    agreement_id: int
    hs_code: str
    agreement_name: str
    reduction_type: str
    reduction_percentage: Decimal
    preferential_duty_rate: Optional[Decimal] = None
    publication_notice: Optional[str] = None
    required_document: Optional[str] = None
    origin_countries: str
    conditions_note: Optional[str]
    effective_from: date
    effective_to: Optional[date]
    source_url: Optional[str]

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Smart Nafeza Text Parser & Origin Check Schemas
# ==================================================

class TariffDiffItem(BaseModel):
    change_type: str = Field(..., description="added, removed, modified, unchanged")
    publication_notice: Optional[str] = None
    agreement_name: str
    origin_countries: Optional[str] = None
    old_value_desc: Optional[str] = None
    new_value_desc: Optional[str] = None
    color_code: str = Field(..., description="HEX color code: #27AE60 (added/green), #C0392B (removed/red), #E67E22 (modified/orange), #2C3E50 (unchanged)")
    summary_ar: str


class TariffVersionComparisonResponse(BaseModel):
    hs_code: str
    has_previous_version: bool
    previous_effective_from: Optional[date] = None
    previous_effective_to: Optional[date] = None
    new_effective_from: date
    added_count: int
    removed_count: int
    modified_count: int
    unchanged_count: int
    diff_items: List[TariffDiffItem]
    summary_ar: str


class SmartTariffParseRequest(BaseModel):
    raw_text: str = Field(..., min_length=10, description="نص البند الجمركي المجمع من شيت/منظومة نافذة")


class SmartTariffParseResponse(BaseModel):
    tariff_data: CustomsTariffCreate
    agreements: List[PreferentialAgreementCreate]
    parsed_agreements_count: int
    summary_ar: str
    comparison: Optional[TariffVersionComparisonResponse] = None


class TariffAgreementBulkSaveRequest(BaseModel):
    tariff: CustomsTariffCreate
    agreements: List[PreferentialAgreementCreate]
    update_date: Optional[date] = Field(None, description="تاريخ بداية سريان التحديث — الافتراضي تاريخ اليوم")


class OriginDutyCheckRequest(BaseModel):
    hs_code: str = Field(..., min_length=4, max_length=20, description="كود البند الجمركي")
    origin_country: str = Field(..., min_length=2, max_length=5, description="رمز بلد المنشأ ISO e.g. TR, GB, RS, CN, BR")
    has_preferential_document: bool = Field(default=False, description="هل تم إرفاق/تأكيد المستند والشهادة المطلوبة للاتفاقية")
    check_date: Optional[date] = Field(None, description="تاريخ الاستعلام — الافتراضي اليوم")


class OriginDutyCheckResponse(BaseModel):
    hs_code: str
    origin_country: str
    base_duty_rate: Decimal
    effective_duty_rate: Decimal
    applied_agreement_name: Optional[str] = None
    publication_notice: Optional[str] = None
    required_document: Optional[str] = None
    has_matching_agreement: bool
    document_verified: bool
    status_label: str
    warning_note: Optional[str] = None
    summary_ar: str


class TariffVerificationRequest(BaseModel):
    customs_duty_rate: Optional[Decimal] = Field(None, ge=0, le=100, description="نسبة ضريبة الوارد الجديدة")
    vat_rate: Optional[Decimal] = Field(None, ge=0, le=100, description="نسبة القيمة المضافة الجديدة")
    schedule_tax_rate: Optional[Decimal] = Field(None, ge=0, le=100, description="نسبة ضريبة الجدول الجديدة")
    development_fee_rate: Optional[Decimal] = Field(None, ge=0, le=100)
    import_fee_rate: Optional[Decimal] = Field(None, ge=0, le=100)
    customs_service_fee_rate: Optional[Decimal] = Field(None, ge=0, le=100)

    hs_description: Optional[str] = None
    regulatory_authority: Optional[str] = None
    prior_approval_note: Optional[str] = None

    source_url: Optional[str] = Field(None, max_length=500, description="رابط المرجعية الرسمية على منصة نافذة")
    verified_by: str = Field(..., min_length=2, max_length=100, description="اسم المراجع المسؤول")
    confidence: str = Field("verified_manual", description="مستوى الثقة: verified_manual, verified_official_gazette")


# ==================================================
# Customs Duty Estimation Schemas
# ==================================================

class CustomsDutyEstimateRequest(BaseModel):
    """
    طلب حساب تقديري للجمارك.
    يجب تمرير قيمة CIF مباشرة (FOB + Freight + Insurance + Packaging).
    """
    hs_code: str = Field(..., description="البند الجمركي المراد التقدير له")
    cif_value: Decimal = Field(..., gt=0, description="القيمة الجمركية CIF (بالجنيه المصري أو العملة المختارة)")
    freight: Decimal = Field(default=Decimal("0.00"), ge=0, description="النولون بالجنيه")
    freight_currency: Optional[str] = Field("EGP", description="عملة النولون الفعلي e.g. USD, EUR, EGP")
    freight_foreign_amount: Decimal = Field(default=Decimal("0.00"), ge=0, description="مبلغ النولون الفعلي بالعملة الأجنبية")
    freight_exchange_rate: Optional[Decimal] = Field(None, ge=0, description="معامل تحويل عملة النولون الأجنبي بالجنيه EGP")
    packaging_egp: Decimal = Field(default=Decimal("0.00"), ge=0, description="قيمة التعبئة والتغليف بالجنيه")
    origin_country: Optional[str] = Field(None, description="بلد المنشأ (رمز ISO e.g. IT, TR, CN)")
    estimate_date: Optional[date] = Field(None, description="تاريخ التقدير — None يعني اليوم")


class CustomsDutyBreakdown(BaseModel):
    """
    تفاصيل كل بند من بنود الحساب الجمركي.
    يُحفظ هذا الـ Snapshot داخل ملف الاستيراد لضمان دقة الحساب التاريخي.
    """
    hs_code: str
    hs_description: str
    customs_category: Optional[str]
    estimate_date: date
    origin_country: Optional[str] = None

    # القيم المُدخلة
    cif_value: Decimal
    freight: Decimal
    packaging_egp: Decimal = Decimal("0.00")

    # نسب الضرائب والرسوم المُستخرجة من سجل HS Code (لا hard-coding)
    customs_duty_rate: Decimal
    vat_rate: Decimal
    schedule_tax_rate: Decimal
    development_fee_rate: Decimal
    import_fee_rate: Decimal
    customs_service_fee_rate: Decimal

    # نتائج الحساب
    import_duty_amount: Decimal
    """ضريبة الوارد الفعالة بعد أي إعفاء تفضيلي"""

    vat_base: Decimal
    """الوعاء الضريبي = CIF + Import Duty الفعلي"""

    vat_amount: Decimal
    """ضريبة القيمة المضافة = VAT Base × vat_rate%"""

    schedule_tax_amount: Decimal
    """ضريبة الجدول = CIF × schedule_tax_rate% (لا تتأثر بإعفاء ضريبة الوارد)"""

    development_fee_amount: Decimal
    """رسم التنمية = CIF × development_fee_rate%"""

    import_fee_amount: Decimal
    """رسم الوارد = CIF × import_fee_rate%"""

    customs_service_fee_amount: Decimal
    """رسم الخدمات الجمركية أ.ت.ص = CIF × 1% (لا يتأثر بإعفاء ضريبة الوارد)"""

    total_taxes_and_fees: Decimal
    """إجمالي الضرائب والرسوم = مجموع جميع البنود"""

    trade_agreement_applied: Optional[str] = None
    conditions_note: Optional[str] = None

    # متطلبات الاستيراد
    requires_coo: bool
    requires_inspection: bool
    requires_acid: bool
    regulatory_authority: Optional[str]

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Multi-Item (Multi HS Code) Customs Calculation Schemas
# (Nafeza Statement Engine + Technical Addendum)
# ==================================================

class MultiItemCustomsEstimateLine(BaseModel):
    line_no: int = Field(..., description="رقم السطر في الفاتورة")
    hs_code: str = Field(..., description="البند الجمركي للصنف")
    value_fc: Decimal = Field(..., gt=0, description="قيمة الصنف بالعملة الأجنبية")
    weight_kg: Decimal = Field(default=Decimal("0.00"), ge=0, description="وزن الصنف بالكيلوجرام")
    qty: Decimal = Field(default=Decimal("1.00"), gt=0, description="الكمية")
    origin_country: Optional[str] = Field(None, description="بلد المنشأ للصنف (رمز الدولة ISO 2 e.g. TR, DE, IT, CN)")
    exemption_code: Optional[str] = Field(None, description="كود الإعفاء الجمركي المطبق على السطر إن وجد")
    exempted_value_fc: Decimal = Field(default=Decimal("0.00"), ge=0, description="القيمة المعفاة إن وجدت")
    value_without_payment_fc: Decimal = Field(default=Decimal("0.00"), ge=0, description="قيمة بدون دفع إن وجدت")
    inspection_fee_egp: Decimal = Field(default=Decimal("0.00"), ge=0, description="رسوم فحص أجر خدمات مخصص للصنف إن وجد")
    is_exemption_conditions_met: Optional[bool] = Field(None, description="هل تم استيفاء وتطبيق شروط الإعفاء الجمركي للبند (اتفاقية شراكة / تصنيع / شهادة منشأ مستوفاة)")


class MultiItemCustomsEstimateRequest(BaseModel):
    currency: str = Field(default="USD", description="عملة الفاتورة")
    exchange_rate: Optional[Decimal] = Field(None, description="سعر التحويل / الصرف الرسمي للجمارك (اختياري - يتم جلبه بناءً على تاريخ السريان إن لم يحدد)")
    insurance_egp: Decimal = Field(default=Decimal("0.00"), ge=0, description="إجمالي التأمين بالجنيه")
    freight_egp: Decimal = Field(default=Decimal("0.00"), ge=0, description="إجمالي النولون / الشحن بالجنيه")
    freight_currency: Optional[str] = Field("EGP", description="عملة النولون الفعلي e.g. USD, EUR, EGP")
    freight_foreign_amount: Decimal = Field(default=Decimal("0.00"), ge=0, description="مبلغ النولون الفعلي بالعملة الأجنبية")
    freight_exchange_rate: Optional[Decimal] = Field(None, ge=0, description="معامل تحويل عملة النولون الأجنبي بالجنيه EGP")
    packaging_egp: Decimal = Field(default=Decimal("0.00"), ge=0, description="قيمة التعبئة/التغليف بالجنيه")
    has_insurance_document: bool = Field(default=True, description="وجود وثيقة تأمين فعلية (إلا تحسب حكمياً 2.5%)")
    has_freight_document: bool = Field(default=True, description="وجود وثيقة شحن فعلية (إلا تحسب حكمياً 2.0%)")
    deemed_insurance_rate: Decimal = Field(default=Decimal("0.025"), description="نسبة التأمين الحكمي الافتراضية (2.5%)")
    deemed_freight_rate: Decimal = Field(default=Decimal("0.020"), description="نسبة النولون الحكمي الافتراضية (2.0%)")
    additional_fees_egp: Decimal = Field(default=Decimal("0.00"), ge=0, description="رسوم إضافية/أساسية على مستوى الفاتورة بالجنيه")
    cif_declared_total_egp: Optional[Decimal] = Field(None, ge=0, description="إجمالي القيمة المقرة نهائياً بالجنيه (CIF Final Declared)")
    vat_rate_override: Optional[Decimal] = Field(None, description="تجاوز نسبة ضريبة القيمة المضافة العامة إن وجد")
    exemption_code: Optional[str] = Field(None, description="كود إعفاء عام للشحنة إن وجد")
    estimate_date: Optional[date] = Field(None, description="تاريخ الإقرار الجمركي")
    lines: List[MultiItemCustomsEstimateLine] = Field(..., min_length=1, description="قائمة أصناف الفاتورة")


class MultiItemCustomsLineBreakdown(BaseModel):
    line_no: int
    hs_code: str
    hs_description: str
    customs_category: Optional[str]
    origin_country: Optional[str]

    value_fc: Decimal
    value_share: Decimal
    allocated_insurance_freight_egp: Decimal
    cif_value_egp: Decimal

    # Exemption & Tax Bases Audit
    duty_taxable_base_egp: Decimal
    schedule_taxable_base_egp: Decimal
    vat_taxable_base_egp: Decimal

    customs_duty_rate: Decimal
    duty_egp: Decimal

    schedule_tax_rate: Decimal
    schedule_tax_base: str = Field("cif", description="أساس ضريبة الجدول: cif أو duty")
    schedule_tax_egp: Decimal

    vat_rate: Decimal
    vat_base_egp: Decimal
    vat_egp: Decimal

    development_fee_rate: Decimal = Decimal("0.00")
    development_fee_egp: Decimal = Decimal("0.00")

    import_fee_rate: Decimal = Decimal("0.00")
    import_fee_egp: Decimal = Decimal("0.00")

    customs_service_fee_rate: Decimal = Decimal("1.00")
    customs_service_fee_egp: Decimal = Decimal("0.00")

    inspection_fee_egp: Decimal

    # Audit Trail Flags
    insurance_source: str = Field("actual", description="مصدر حساب التأمين: actual أو deemed")
    freight_source: str = Field("actual", description="مصدر حساب النولون: actual أو deemed")
    exemption_code_applied: Optional[str] = None
    exemption_applied_details: Optional[str] = None
    is_exemption_applied: bool = False
    preferential_agreement_applied: Optional[str] = None
    conditions_note: Optional[str] = None

    requires_coo: bool
    requires_inspection: bool
    requires_acid: bool
    regulatory_authority: Optional[str]


class MultiItemCustomsBreakdown(BaseModel):
    currency: str
    exchange_rate: Decimal
    rate_date: Optional[date] = None
    exchange_rate_id: Optional[int] = None
    invoice_total_value_fc: Decimal
    fob_value_egp: Decimal
    insurance_egp: Decimal
    freight_egp: Decimal
    packaging_egp: Decimal = Decimal("0.00")
    insurance_source: str = Field("actual", description="مصدر التأمين الكلي: actual أو deemed")
    freight_source: str = Field("actual", description="مصدر النولون الكلي: actual أو deemed")
    freight_exchange_rate_used: Optional[Decimal] = None
    freight_rate_source: Optional[str] = Field(None, description="مصدر سعر صرف النولون: invoice_currency أو table أو manual")
    additional_fees_egp: Decimal
    estimate_date: date

    lines: List[MultiItemCustomsLineBreakdown]

    total_duty_egp: Decimal
    total_schedule_tax_egp: Decimal
    total_vat_egp: Decimal
    total_customs_service_fee_egp: Decimal = Decimal("0.00")
    total_development_fee_egp: Decimal = Decimal("0.00")
    total_import_fee_egp: Decimal = Decimal("0.00")
    total_inspection_fees_egp: Decimal

    items_taxes_total_egp: Decimal
    grand_total_payable_egp: Decimal

    fee_codes_breakdown: Optional[dict] = Field(None, description="تفاصيل جدول تحصيل رسوم نافذة والإقرارات الجمركية الرسمية")


class ImportFileCustomsSimulationRequest(BaseModel):
    exchange_rate: Optional[Decimal] = Field(None, ge=0, description="سعر الصرف الرسمي للجمارك (اختياري - يتم جلبه آلياً إن لم يحدد)")
    freight_egp: Optional[Decimal] = Field(None, ge=0, description="قيمة النولون بالجنيه (اختياري - يتم جلبه من عروض الشحن المعتمدة أو حسابه حكمياً 2%)")
    insurance_egp: Optional[Decimal] = Field(None, ge=0, description="قيمة التأمين بالجنيه (اختياري - يحسب حكمياً 2.5% إن لم يحدد)")
    packaging_egp: Optional[Decimal] = Field(Decimal("0.00"), ge=0, description="قيمة التعبئة والتغليف بالجنيه")
    estimate_date: Optional[date] = Field(None, description="تاريخ التقدير - الافتراضي اليوم")
    save_to_consultation: bool = Field(True, description="تحديث أو حفظ التقدير في دراسة الاستشارة الجمركية وميزانية الملف")


class ImportFileCustomsSimulationResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    po_numbers: List[str]
    currency: str
    breakdown: MultiItemCustomsBreakdown
    consultation_id: Optional[int] = None
    summary_ar: str
    warnings: List[str] = Field(default_factory=list, description="تحذيرات محاكاة الجمارك (مثل عدم وجود مخلص)")
    skipped_lines: List[dict] = Field(default_factory=list, description="البنود التي تم استبعادها لعدم وجود بند جمركي أو قيمة")


