from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field, field_validator

from modules.common.legacy_rows import LegacyRowTolerantModel, read_model
from .validators import normalize_lab_test_result

class CustomsClearanceCreate(BaseModel):
    import_file_id: int
    declaration_46_no: Optional[str] = None
    declaration_46_date: Optional[datetime] = None
    mts_certificate_number: Optional[str] = None
    customs_tariff_items_count: int = 1
    customs_office_name: str = "Alexandria Port Customs"
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    delegation_number: Optional[str] = None
    delegation_date: Optional[datetime] = None
    delegation_status: Optional[str] = "Authorized"
    authorization_notes: Optional[str] = None
    mandate_letter_code: Optional[str] = None
    channel_type: str = "Red Channel"
    inspection_date: Optional[datetime] = None
    inspection_type: Optional[str] = "Physical & Sampling"
    inspection_yard: Optional[str] = None
    inspector_name: Optional[str] = None
    inspection_result: str = "Conforming"
    is_sample_drawn: bool = True
    sampling_date: Optional[datetime] = None
    sampling_record_no: Optional[str] = None
    sampled_regulatory_bodies: List[str] = []
    goeic_certificate_no: Optional[str] = None
    regulatory_bodies: List[str] = []
    inspection_notes: Optional[str] = None
    cif_base_amount: float = 0.0
    customs_exchange_rate: float = 1.0
    import_duty_amount: float = 0.0
    vat_amount: float = 0.0
    schedule_tax_amount: float = 0.0
    development_fee_amount: float = 0.0
    customs_service_fees: float = 0.0
    wht_amount: float = 0.0
    lab_service_fees: float = 0.0
    estimated_duty_total: float = 0.0
    actual_duty_total: float = 0.0
    duty_variance_amount: float = 0.0
    duty_variance_percentage: float = 0.0
    duty_variance_reason: Optional[str] = None
    nafeza_claim_number: Optional[str] = None
    nafeza_claim_date: Optional[datetime] = None
    assessment_status: str = "Assessed"
    nafeza_assessment_json: Optional[Dict[str, Any]] = None
    port_arrival_date: Optional[datetime] = None
    delivery_order_number: Optional[str] = None
    delivery_order_date: Optional[datetime] = None
    delivery_order_expiry: Optional[datetime] = None
    free_days_allowed: int = 14
    shipping_agent_id: Optional[int] = None
    shipping_agent_name: Optional[str] = None
    delivery_order_fees: float = 0.0
    delivery_order_currency: str = "EGP"
    delivery_order_payment_ref: Optional[str] = None
    delivery_order_paid_at: Optional[datetime] = None
    delivery_order_status: str = "Pending"
    delivery_order_file_url: Optional[str] = None
    delivery_order_notes: Optional[str] = None
    port_gate_out_date: Optional[datetime] = None
    owner: Optional[str] = None  # defaults to the acting user
    notes: Optional[str] = None

# BP-027 / CS-01: Customs Broker Electronic Authorization Schema
class CustomsBrokerAuthorizationSubmit(BaseModel):
    import_file_id: int = Field(..., description="معرف ملف الشحنة الاستيرادية")
    broker_id: int = Field(..., description="معرف المخلص الجمركي (ExternalServiceProvider ID)")
    delegation_number: str = Field(..., min_length=3, description="رقم التفويض الإلكتروني للمخلص (Nafeza / MTS Code)")
    delegation_date: Optional[datetime] = Field(None, description="تاريخ صدور التفويض")
    customs_office_name: Optional[str] = Field("Alexandria Port Customs", description="الميناء الجمركي المعني بالتخليص")
    authorization_notes: Optional[str] = Field(None, description="ملاحظات وتوجيهات التفويض")
    generate_mandate_letter: bool = Field(True, description="توليد خطاب تفويض جمركي رسمي")

# CS-02: Delivery Order (D/O) Payment & Receipt Schema
class DeliveryOrderPaymentSubmit(BaseModel):
    import_file_id: int = Field(..., description="معرف ملف الشحنة الاستيرادية")
    delivery_order_number: str = Field(..., min_length=3, description="رقم إذن التسليم الملاحي (D/O Number)")
    delivery_order_date: Optional[datetime] = Field(None, description="تاريخ استلام إذن التسليم")
    delivery_order_expiry: datetime = Field(..., description="تاريخ انتهاء صلاحية إذن التسليم الملاحي")
    free_days_allowed: int = Field(14, ge=0, description="أيام السماح الممنوحة من التوكيل الملاحي")
    shipping_agent_id: Optional[int] = Field(None, description="معرف التوكيل أو الخط الملاحي")
    shipping_agent_name: Optional[str] = Field(None, description="اسم التوكيل أو الخط الملاحي")
    delivery_order_fees: float = Field(..., ge=0.0, description="قيمة مصاريف إذن التسليم الملاحي")
    delivery_order_currency: str = Field("EGP", description="عملة السداد")
    delivery_order_payment_ref: str = Field(..., min_length=2, description="رقم إيصال أو مرجع سداد مصاريف التوكيل")
    delivery_order_requested_at: Optional[datetime] = Field(None, description="تاريخ وساعة تقديم طلب إذن التسليم للتوكيل لحساب الـ SLA")
    delivery_order_paid_at: Optional[datetime] = Field(None, description="تاريخ سداد مصاريف التوكيل الملاحي")
    delivery_order_file_url: Optional[str] = Field(None, description="رابط أو مسار صورة إذن التسليم المرفوع")
    notes: Optional[str] = Field(None, description="ملاحظات إضافية")

# CS-03: Customs Declaration 46 Registration Schema
class CustomsDeclaration46Submit(BaseModel):
    import_file_id: int = Field(..., description="معرف ملف الشحنة الاستيرادية")
    declaration_46_no: str = Field(..., min_length=3, description="رقم الإقرار الجمركي ونموذج 46 ك.م (Declaration 46 Number)")
    declaration_46_date: Optional[datetime] = Field(None, description="تاريخ قيد الإقرار الجمركي")
    customs_office_name: str = Field("Alexandria Port Customs", description="الميناء / المركز الجمركي المعني بالقيد")
    channel_type: str = Field("Red Channel", description="المسار الجمركي المحدد (Red Channel, Yellow Channel, Green Channel)")
    regulatory_bodies: List[str] = Field(default_factory=list, description="جهات العرض الرقابية والفحص (GOEIC, Food Safety, etc.)")
    mts_certificate_number: Optional[str] = Field(None, description="رقم الشهادة الجمركية المبدئية أو المرجعية (MTS Ref)")
    customs_tariff_items_count: int = Field(1, ge=1, description="عدد بنود التعريفة الجمركية المتضمنة في الإقرار")
    inspection_notes: Optional[str] = Field(None, description="ملاحظات وتوجيهات الكشف والتثمين")

# CL-01: Inspection & Samples GOEIC Report Schema
class CustomsInspectionSamplingSubmit(BaseModel):
    import_file_id: int = Field(..., description="معرف ملف الشحنة الاستيرادية")
    inspection_date: Optional[datetime] = Field(None, description="تاريخ الكشف والمعاينة الفنية")
    inspection_type: str = Field("Physical & Sampling", description="نوع الكشف (Physical & Sampling, 100% Full, Random Sample, X-Ray Scan, Document Review)")
    inspection_yard: Optional[str] = Field(None, description="INSPECTION_YARD code (legacy yard names are normalized) or free text")
    inspector_name: Optional[str] = Field(None, description="اسم المفتش أو رئيس لجنة الفحص الجمركي المشترك")
    inspection_result: str = Field("Conforming", description="نتيجة المعاينة (Conforming, Shortage, Surplus, Discrepancy)")
    is_sample_drawn: bool = Field(True, description="هل تم سحب عينات للفحص والتحليل المعملي؟")
    sampling_date: Optional[datetime] = Field(None, description="تاريخ سحب العينات")
    sampling_record_no: Optional[str] = Field(None, description="رقم محضر سحب العينات الرسمي")
    sample_test_status: str = Field("Samples Under Testing", description="حالة فحص العينات (Samples Under Testing, Approved, Rejected)")
    sampled_regulatory_bodies: List[str] = Field(default_factory=list, description="الجهات الرقابية الساحبة للعينات (GOEIC, Radiation, Chemistry, etc.)")
    goeic_certificate_no: Optional[str] = Field(None, description="رقم شهادة الفحص أو إشعار المعاينة الصادر من الرقابة على الصادرات والواردات")
    lab_service_fees: float = Field(0.0, ge=0.0, description="رسوم ومصاريف التحليل المعملي للعينات (EGP)")
    inspection_notes: Optional[str] = Field(None, description="ملاحظات وتوصيات لجنة المعاينة والكشف")

# CL-02: Final Duty & Tax Assessment Schema
class FinalDutyAssessmentSubmit(BaseModel):
    import_file_id: int = Field(..., description="معرف ملف الشحنة الاستيرادية")
    nafeza_claim_number: str = Field(..., min_length=3, description="رقم المطالبة الجمركية بنظام نافذة MTS")
    nafeza_claim_date: Optional[datetime] = Field(None, description="تاريخ صدور المطالبة الجمركية")
    cif_base_amount: float = Field(..., ge=0.0, description="القيمة الجمركية للأغراض الجمركية CIF بالجنيه المصري")
    customs_exchange_rate: Optional[float] = Field(None, gt=0.0, description="سعر الصرف الجمركي الرسمي المعمول به (لا يُفترض 1.0 عند عدم الإرسال)")
    import_duty_amount: float = Field(..., ge=0.0, description="ضريبة الوارد الجمركية (Import Duty)")
    vat_amount: float = Field(..., ge=0.0, description="ضريبة القيمة المضافة (VAT)")
    schedule_tax_amount: float = Field(0.0, ge=0.0, description="ضريبة الجدول (Schedule Tax)")
    development_fee_amount: float = Field(0.0, ge=0.0, description="رسم التنمية (Development Fee)")
    customs_service_fees: float = Field(0.0, ge=0.0, description="رسوم الخدمات الجمركية وأ.ت.ص")
    wht_amount: float = Field(0.0, ge=0.0, description="ضريبة الأرباح التجارية والصناعية (WHT)")
    lab_service_fees: float = Field(0.0, ge=0.0, description="رسوم ومصاريف الفحص والتحاليل المعملية")
    actual_duty_total: Optional[float] = Field(None, ge=0.0, description="إجمالي الرسوم والضرائب الجمركية الفعلية بالمطالبة")
    duty_variance_reason: Optional[str] = Field(None, description="سبب انحراف الرسوم الفعلية عن التقديرية إن وجد")
    nafeza_assessment_json: Optional[Dict[str, Any]] = Field(None, description="البيانات التفصيلية للمطالبة الإلكترونية من نافذة")
    assessment_notes: Optional[str] = Field(None, description="ملاحظات وتوجيهات التثمين والاحتساب النهائي")

# CL-03: Customs Duty Payment Receipt Schema
class CustomsDutyPaymentSubmit(BaseModel):
    import_file_id: int = Field(..., description="معرف ملف الشحنة الاستيرادية")
    bank_receipt_no: str = Field(..., min_length=3, description="رقم إيصال التحويل / السداد البنكي")
    sadad_number: str = Field(..., min_length=3, description="رقم السداد الإلكتروني / سداد E-Finance")
    paying_bank_name: str = Field(..., min_length=2, description="اسم البنك المسدد من خلاله")
    payment_date: Optional[datetime] = Field(None, description="تاريخ ووقت السداد")
    payment_method: str = Field("SADAD_EFINANCE", description="طريقة ومنظومة السداد (Sadad / E-Finance, Bank CPS, Direct Debit)")
    duty_paid_amount: float = Field(..., gt=0.0, description="المبلغ المسدد فعلياً بالجنيه المصري")
    receipt_file_url: Optional[str] = Field(None, description="رابط صورة إيصال السداد")
    payment_notes: Optional[str] = Field(None, description="ملاحظات وتفاصيل عملية السداد")

class DutyPaymentSubmit(BaseModel):
    """Legacy /{id}/pay-duty body. The current screen sends bank_receipt_no + actual_duty_total (+ reason) only."""
    bank_receipt_no: str
    paying_bank_name: Optional[str] = None
    payment_date: Optional[datetime] = None  # defaults to now
    actual_duty_total: Optional[float] = None
    estimated_duty_total: Optional[float] = None
    duty_variance_reason: Optional[str] = None
    nafeza_assessment_json: Optional[Dict[str, Any]] = None
    payment_notes: Optional[str] = None
    sadad_number: Optional[str] = None
    payment_method: Optional[str] = "SADAD_EFINANCE"
    duty_paid_amount: Optional[float] = None
    receipt_file_url: Optional[str] = None

class CompleteReleaseSubmit(BaseModel):
    release_permit_no: str
    release_date: Optional[datetime] = None  # defaults to now
    release_officer_name: Optional[str] = None
    release_type: Optional[str] = "FINAL_GREEN"
    release_document_url: Optional[str] = None
    gate_pass_number: Optional[str] = None
    port_gate_out_date: Optional[datetime] = None
    demurrage_storage_fees: float = 0.0
    dispatch_authorized: bool = True
    transport_instructions: Optional[str] = None
    notes: Optional[str] = None

class CustomsFinalReleaseSubmit(BaseModel):
    import_file_id: int
    clearance_id: Optional[int] = None
    release_permit_no: str = Field(..., min_length=3, description="رقم إذن الإفراج الجمركي الأخضر النهائي")
    release_date: Optional[datetime] = None
    release_officer_name: Optional[str] = None
    release_type: str = "FINAL_GREEN"
    release_document_url: Optional[str] = None
    gate_pass_number: Optional[str] = None
    port_gate_out_date: Optional[datetime] = None
    demurrage_storage_fees: float = 0.0
    dispatch_authorized: bool = True
    transport_instructions: Optional[str] = None
    notes: Optional[str] = None

# LOG-BOND-003: Under-Bond & Lab Quarantine Schemas
class UnderBondReleaseSubmit(BaseModel):
    bond_guarantee_ref: str = Field(..., min_length=3, description="رقم التعهد أو خطاب الضمان الجمركي")
    temporary_release_date: datetime
    customs_warehouse_location: str = "Factory bonded warehouse"
    inspection_notes: Optional[str] = None
    regulatory_authority: str = "GOEIC"

class LabTestResultSubmit(BaseModel):
    lab_test_result: str = Field(
        ..., description="LAB_TEST_RESULT code: CONFORMING / NON_CONFORMING (legacy labels are mapped)"
    )
    lab_certificate_number: str = Field(..., min_length=2, description="رقم شهادة المطابقة المعملية")
    test_completion_date: datetime
    lift_quarantine_lock: bool = True
    laboratory_name: Optional[str] = "Chemistry Administration / GOEIC laboratories"
    remarks: Optional[str] = None

    @field_validator("lab_test_result")
    @classmethod
    def _lab_result_code(cls, value: str) -> str:
        return normalize_lab_test_result(value)


# CL-05: Clearance Fees & Port Invoices Schemas (تسجيل فواتير المخلص ومصاريف العتالة ونولون الميناء)
class ClearanceExpenseInvoiceBase(BaseModel):
    import_file_id: int = Field(..., description="معرف ملف الشحنة")
    customs_clearance_id: Optional[int] = Field(None, description="معرف قيد التخليص الجمركي")
    invoice_number: str = Field(..., min_length=1, description="رقم فاتورة المخلص أو إيصال رسوم الميناء")
    invoice_date: Optional[datetime] = Field(None, description="تاريخ الفاتورة")
    provider_id: Optional[int] = Field(None, description="معرف المخلص أو شركة الخدمات")
    provider_name: str = Field(..., min_length=2, description="اسم مقدم الخدمة أو المخلص أو هيئة الميناء")
    expense_category: str = Field(..., description="تصنيف المصروف (أتعاب تخليص، نولون موانئ، عتالة وتفريغ، كشف، إلخ)")
    currency: str = Field("EGP", description="عملة الفاتورة")
    amount_fx: float = Field(0.0, ge=0.0, description="المبلغ بالعملة الأجنبية إن وجد")
    exchange_rate: Optional[float] = Field(None, gt=0.0, description="سعر الصرف إلى الجنيه المصري (مطلوب لفاتورة بعملة أجنبية بدون مبلغ بالجنيه)")
    amount_egp: float = Field(..., ge=0.0, description="المبلغ بالجنيه المصري")
    vat_included: bool = Field(False, description="هل الفاتورة شاملة ضريبة القيمة المضافة؟")
    vat_amount: float = Field(0.0, ge=0.0, description="قيمة ضريبة القيمة المضافة")
    wht_deducted: bool = Field(False, description="هل تم خصم ضريبة أرباح تجارية وصناعية WHT؟")
    wht_amount: float = Field(0.0, ge=0.0, description="قيمة الخصم والإضافة")
    payment_status: str = Field("Unpaid", description="حالة السداد (Unpaid, Partially Paid, Paid)")
    payment_ref: Optional[str] = Field(None, description="مرجع السداد (رقم الشيك أو التحويل)")
    document_url: Optional[str] = Field(None, description="رابط صورة الفاتورة أو الإيصال")
    allocation_rule: str = Field("Equal", description="قاعدة توزيع التكلفة (Value-Based, Weight-Based, Volume-Based, Equal)")
    notes: Optional[str] = Field(None, description="ملاحظات وتفاصيل الفاتورة")

class ClearanceExpenseInvoiceCreate(ClearanceExpenseInvoiceBase):
    pass

class ClearanceExpenseInvoiceUpdate(BaseModel):
    invoice_number: Optional[str] = None
    invoice_date: Optional[datetime] = None
    provider_id: Optional[int] = None
    provider_name: Optional[str] = None
    expense_category: Optional[str] = None
    currency: Optional[str] = None
    amount_fx: Optional[float] = None
    exchange_rate: Optional[float] = None
    amount_egp: Optional[float] = None
    vat_included: Optional[bool] = None
    vat_amount: Optional[float] = None
    wht_deducted: Optional[bool] = None
    wht_amount: Optional[float] = None
    payment_status: Optional[str] = None
    payment_ref: Optional[str] = None
    document_url: Optional[str] = None
    allocation_rule: Optional[str] = None
    notes: Optional[str] = None

@read_model
class ClearanceExpenseInvoiceResponse(ClearanceExpenseInvoiceBase):
    invoice_id: int
    invoice_code: str
    net_payable_egp: float
    is_verified: bool
    is_active: bool
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)

class ClearanceInvoicesSummaryResponse(BaseModel):
    import_file_id: int
    invoices_count: int
    total_amount_egp: float
    total_vat_egp: float
    total_wht_egp: float
    net_payable_egp: float
    total_clearance_fees_egp: float
    total_port_dues_egp: float
    total_handling_stevedoring_egp: float
    total_other_expenses_egp: float
    invoices: List[ClearanceExpenseInvoiceResponse]


class CustomsClearanceUpdate(BaseModel):
    """Generic PUT. Workflow, payment and derived fields (status, payment_*, duty_paid_amount, actual_duty_total,
    assessment / D/O status, variance, CL-05 aggregates) are not part of it: sent values are ignored."""

    declaration_46_no: Optional[str] = None
    declaration_46_date: Optional[datetime] = None
    mts_certificate_number: Optional[str] = None
    customs_tariff_items_count: Optional[int] = None
    customs_office_name: Optional[str] = None
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    delegation_number: Optional[str] = None
    delegation_date: Optional[datetime] = None
    delegation_status: Optional[str] = None
    authorization_notes: Optional[str] = None
    mandate_letter_code: Optional[str] = None
    channel_type: Optional[str] = None
    inspection_date: Optional[datetime] = None
    inspection_type: Optional[str] = None
    inspection_yard: Optional[str] = None
    inspector_name: Optional[str] = None
    inspection_result: Optional[str] = None
    is_sample_drawn: Optional[bool] = None
    sampling_date: Optional[datetime] = None
    sampling_record_no: Optional[str] = None
    sampled_regulatory_bodies: Optional[List[str]] = None
    goeic_certificate_no: Optional[str] = None
    regulatory_bodies: Optional[List[str]] = None
    sample_test_status: Optional[str] = None
    inspection_notes: Optional[str] = None
    cif_base_amount: Optional[float] = None
    customs_exchange_rate: Optional[float] = None
    import_duty_amount: Optional[float] = None
    vat_amount: Optional[float] = None
    schedule_tax_amount: Optional[float] = None
    development_fee_amount: Optional[float] = None
    customs_service_fees: Optional[float] = None
    wht_amount: Optional[float] = None
    lab_service_fees: Optional[float] = None
    estimated_duty_total: Optional[float] = None
    duty_variance_reason: Optional[str] = None
    nafeza_claim_number: Optional[str] = None
    nafeza_claim_date: Optional[datetime] = None
    nafeza_assessment_json: Optional[Dict[str, Any]] = None
    port_arrival_date: Optional[datetime] = None
    delivery_order_number: Optional[str] = None
    delivery_order_date: Optional[datetime] = None
    delivery_order_expiry: Optional[datetime] = None
    free_days_allowed: Optional[int] = None
    shipping_agent_id: Optional[int] = None
    shipping_agent_name: Optional[str] = None
    delivery_order_fees: Optional[float] = None
    delivery_order_currency: Optional[str] = None
    delivery_order_payment_ref: Optional[str] = None
    delivery_order_paid_at: Optional[datetime] = None
    delivery_order_file_url: Optional[str] = None
    delivery_order_notes: Optional[str] = None
    port_gate_out_date: Optional[datetime] = None
    owner: Optional[str] = None
    notes: Optional[str] = None

class CustomsClearanceResponse(LegacyRowTolerantModel):
    # Columns added after 2026-08-09 (e.g. clearance_invoices_count, assessment_status) are NULL on rows that
    # predate the startup ADD COLUMN; LegacyRowTolerantModel reads them as their defaults instead of a 500.
    customs_clearance_id: int
    clearance_code: str
    import_file_id: int
    declaration_46_no: Optional[str] = None
    declaration_46_date: Optional[datetime] = None
    mts_certificate_number: Optional[str] = None
    customs_tariff_items_count: int = 1
    customs_office_name: str
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    delegation_number: Optional[str] = None
    delegation_date: Optional[datetime] = None
    delegation_status: Optional[str] = "Authorized"
    authorization_notes: Optional[str] = None
    mandate_letter_code: Optional[str] = None
    channel_type: str
    inspection_date: Optional[datetime] = None
    inspection_type: Optional[str] = "Physical & Sampling"
    inspection_yard: Optional[str] = None
    inspector_name: Optional[str] = None
    inspection_result: str = "Conforming"
    is_sample_drawn: bool = True
    sampling_date: Optional[datetime] = None
    sampling_record_no: Optional[str] = None
    sampled_regulatory_bodies: List[str] = []
    goeic_certificate_no: Optional[str] = None
    regulatory_bodies: List[str]
    sample_test_status: str
    inspection_notes: Optional[str] = None
    # Money / rate fields are nullable on read: a legacy NULL stays None (never a fabricated 0.0 or 1.0 rate).
    cif_base_amount: Optional[float] = 0.0
    customs_exchange_rate: Optional[float] = None
    import_duty_amount: Optional[float] = None
    vat_amount: Optional[float] = None
    schedule_tax_amount: Optional[float] = None
    development_fee_amount: Optional[float] = 0.0
    customs_service_fees: Optional[float] = 0.0
    wht_amount: Optional[float] = None
    lab_service_fees: Optional[float] = None
    total_duty_payable: Optional[float] = None
    estimated_duty_total: Optional[float] = 0.0
    actual_duty_total: Optional[float] = 0.0
    duty_variance_amount: Optional[float] = 0.0
    duty_variance_percentage: Optional[float] = 0.0
    duty_variance_reason: Optional[str] = None
    nafeza_claim_number: Optional[str] = None
    nafeza_claim_date: Optional[datetime] = None
    assessment_status: str = "Assessed"
    nafeza_assessment_json: Optional[Dict[str, Any]] = None
    port_arrival_date: Optional[datetime] = None
    delivery_order_number: Optional[str] = None
    delivery_order_requested_at: Optional[datetime] = None
    delivery_order_date: Optional[datetime] = None
    delivery_order_expiry: Optional[datetime] = None
    free_days_allowed: int = 14
    shipping_agent_id: Optional[int] = None
    shipping_agent_name: Optional[str] = None
    delivery_order_fees: Optional[float] = 0.0
    delivery_order_currency: str = "EGP"
    delivery_order_payment_ref: Optional[str] = None
    delivery_order_paid_at: Optional[datetime] = None
    delivery_order_status: str = "Pending"
    delivery_order_file_url: Optional[str] = None
    delivery_order_notes: Optional[str] = None
    port_gate_out_date: Optional[datetime] = None
    payment_status: str
    bank_receipt_no: Optional[str] = None
    paying_bank_name: Optional[str] = None
    payment_date: Optional[datetime] = None
    payment_notes: Optional[str] = None
    sadad_number: Optional[str] = None
    payment_method: Optional[str] = "SADAD_EFINANCE"
    duty_paid_amount: Optional[float] = 0.0
    receipt_file_url: Optional[str] = None
    release_permit_no: Optional[str] = None
    release_date: Optional[datetime] = None
    release_officer_name: Optional[str] = None
    release_type: Optional[str] = "FINAL_GREEN"
    release_document_url: Optional[str] = None
    gate_pass_number: Optional[str] = None
    demurrage_storage_fees: Optional[float] = None
    dispatch_authorized: bool
    dispatch_date: Optional[datetime] = None
    transport_instructions: Optional[str] = None
    is_under_bond_release: bool = False
    bond_guarantee_ref: Optional[str] = None
    quarantine_lock: bool = False
    lab_test_result: str = "None"
    lab_certificate_number: Optional[str] = None
    quarantine_lifted_date: Optional[datetime] = None
    quarantine_lifted_by: Optional[str] = None
    total_clearance_expenses_egp: Optional[float] = 0.0
    total_port_expenses_egp: Optional[float] = 0.0
    total_handling_expenses_egp: Optional[float] = 0.0
    clearance_invoices_count: int = 0
    status: str
    owner: str

    notes: Optional[str] = None
    is_active: bool
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)
