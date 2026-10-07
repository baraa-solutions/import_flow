from datetime import date, datetime, timezone

from sqlalchemy import Boolean, Column, Date, DateTime, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from database.database import Base


class CustomsTariff(Base):
    """
    MD-008: Customs Tariff / HS Code Master Table.

    يحتوي على نسب الضرائب والرسوم لكل بند جمركي (HS Code).
    هذا الجدول هو المرجع الأساسي لمحرك الحساب الجمركي المصري (إصدار البيانات المعتمدة محلياً - Addendum 3).

    قواعد حرجة:
    - لا يجوز Hard-Code أي نسبة ضريبية خارج هذا الجدول.
    - كل HS Code له نسبه الخاصة المستخرجة من هذا السجل.
    - يجب الحفاظ على effective_from / effective_to لدعم Snapshot التاريخي.
    """

    __tablename__ = "customs_tariffs"

    # ==================================================
    # Primary Key & Identification
    # ==================================================
    tariff_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    hs_code = Column(String(20), nullable=False, index=True)
    hs_description = Column(String(500), nullable=False)
    customs_category = Column(String(100), nullable=True)

    # ==================================================
    # Tax & Duty Rates (% values — never hard-coded externally)
    # ==================================================
    customs_duty_rate = Column(Numeric(5, 2), nullable=False, default=0.00)
    """ضريبة الوارد % — محسوبة من القيمة الجمركية (CIF)"""

    vat_rate = Column(Numeric(5, 2), nullable=False, default=0.00)
    """ضريبة القيمة المضافة % — محسوبة من الوعاء الضريبي (CIF + Import Duty + Freight + ...)"""

    schedule_tax_rate = Column(Numeric(5, 2), nullable=False, default=0.00)
    """ضريبة الجدول % — 0 إذا لم تنطبق على هذا البند"""

    development_fee_rate = Column(Numeric(5, 2), nullable=False, default=0.00)
    """رسم التنمية % — 0 إذا لم ينطبق على هذا البند"""

    import_fee_rate = Column(Numeric(5, 2), nullable=False, default=0.00)
    """رسم الوارد % — 0 إذا لم ينطبق"""

    customs_service_fee_rate = Column(Numeric(5, 2), nullable=False, default=1.00)
    """رسم الخدمات الجمركية (أ.ت.ص) % — ثابت 1% على القيمة الجمركية دائمًا، بغض النظر عن الإعفاء الجمركي"""

    # ==================================================
    # Import Requirements / Regulatory
    # ==================================================
    requires_coo = Column(Boolean, default=False, nullable=False)
    """يتطلب شهادة منشأ (Certificate of Origin)"""

    requires_inspection = Column(Boolean, default=False, nullable=False)
    """يتطلب شهادة فحص (Inspection Certificate)"""

    requires_acid = Column(Boolean, default=True, nullable=False)
    """يتطلب ACID (Advance Cargo Information Declaration)"""

    regulatory_authority = Column(String(500), nullable=True)
    """الجهات الرقابية المسؤولة (NTRA, GOEIC, MOH, etc.)"""

    prior_approval_note = Column(Text, nullable=True)
    """ملاحظات وشروط الموافقة المسبقة (ملحق 8 وتعديلاته)"""

    # ==================================================
    # Validity / Effective Date (Tariff History Support - Addendum 3)
    # ==================================================
    effective_from = Column(Date, nullable=False, default=date.today)
    """تاريخ بداية سريان هذه التعريفة"""

    effective_to = Column(Date, nullable=True, default=None)
    """تاريخ انتهاء سريان التعريفة. NULL يعني ساري حتى الآن."""

    # ==================================================
    # Manual Verification & Audit Trail (Addendum 3)
    # ==================================================
    source_url = Column(String(500), nullable=True)
    """رابط صفحة نافذة الرسمية للتحقق e.g. https://www.nafeza.gov.eg/ar/tarrif?code=8536410000"""

    last_verified_date = Column(Date, nullable=True, default=date.today)
    """تاريخ آخر مراجعة يدوية للتعريفة"""

    verified_by = Column(String(100), nullable=True, default="System Admin")
    """اسم/كود الموظف المسئول عن مراجعة البيانات"""

    confidence = Column(String(50), nullable=True, default="verified_manual")
    """مستوى الثقة: verified_manual, verified_official_gazette, draft"""

    # ==================================================
    # Notes & Status
    # ==================================================
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False, index=True)

    # Relationships
    agreements = relationship(
        "PreferentialAgreement",
        back_populates="tariff",
        cascade="all, delete-orphan",
        primaryjoin="CustomsTariff.hs_code == PreferentialAgreement.hs_code",
        foreign_keys="[PreferentialAgreement.hs_code]",
    )

    # ==================================================
    # Audit Timestamps
    # ==================================================
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    deleted_by = Column(String(100), nullable=True)
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)

    __table_args__ = (
        UniqueConstraint("hs_code", "effective_from", name="uq_customs_tariff_hs_code_eff_from"),
    )

    def __repr__(self) -> str:
        return f"<CustomsTariff hs_code={self.hs_code} duty={self.customs_duty_rate}% vat={self.vat_rate}%>"


class PreferentialAgreement(Base):
    """
    جدول الاتفاقيات التفضيلية المعتمدة محلياً (Addendum 3 Section 2.2).
    يرتبط بالبند الجمركي ويحدد المعاملات التفضيلية حسب بلد المنشأ.
    """

    __tablename__ = "preferential_agreements"

    agreement_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    hs_code = Column(String(20), nullable=False, index=True)

    agreement_name = Column(String(200), nullable=False)
    """اسم الاتفاقية e.g. اتفاقية التجارة الحرة العربية الكبرى (الأغادير / GAFTA)"""

    reduction_type = Column(String(50), nullable=False, default="percentage_of_duty")
    """نوع التخفيض: percentage_of_duty, full_duty_exemption, fixed_rate"""

    reduction_percentage = Column(Numeric(5, 2), nullable=False, default=1.00)
    """نسبة التخفيض الجمركي e.g. 1.00 تعني إعفاء 100% من ضريبة الوارد"""

    preferential_duty_rate = Column(Numeric(5, 2), nullable=True)
    """سعر الضريبة التفضيلية المحدد مباشرة e.g. 3.00% للميركسور"""

    publication_notice = Column(String(100), nullable=True)
    """رقم المنشور الجمركي e.g. 'ر6722', 'ر6668'"""

    required_document = Column(String(250), nullable=True)
    """المستند أو الشهادة المطلوبة لتطبيق التخفيض e.g. 'شهادة EUR.1'"""

    origin_countries = Column(String(500), nullable=False)
    """الدول المشمولة بالاتفاقية بالرمز الدولي مقسمة بفواصل e.g. 'JO,TN,MA'"""

    conditions_note = Column(Text, nullable=True)
    """الشروط والأحكام المطبقة للتخفيض وفق المنشورات الرسمية"""

    effective_from = Column(Date, nullable=False, default=date.today)
    effective_to = Column(Date, nullable=True, default=None)
    source_url = Column(String(500), nullable=True)
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)

    # Relationships
    tariff = relationship(
        "CustomsTariff",
        back_populates="agreements",
        primaryjoin="PreferentialAgreement.hs_code == CustomsTariff.hs_code",
        foreign_keys="[PreferentialAgreement.hs_code]",
    )


class FeeCode(Base):
    """
    جدول الرسوم الثابتة والمرجعية لمنظومة نافذة والجمارك المصرية (Fee Codes Registry).
    منفصل عن customs_tariffs — رسوم إدارية/خدمية وثابتة على مستوى الإقرار والشهادة.
    """

    __tablename__ = "fee_codes"

    fee_code_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    code = Column(String(10), nullable=False, unique=True, index=True)
    """كود الرسم الرسمي نافذة e.g. '77', '250', '798', '60', '74', '107', '3', '390', '392', '394'"""

    name_ar = Column(String(200), nullable=False)
    """اسم الرسم باللغة العربية e.g. 'رسم طباعة بيان جمركي موحد'"""

    collection_group = Column(String(100), nullable=False)
    """المجموعة: رسم مستخلص / ضريبة جمارك / أ.ت.ص / ض.مبيعات / رسوم النافذة الموحدة"""

    calculation_type = Column(String(20), nullable=False, default="flat")
    """نوع الحساب: flat (مقطوع), reference (مرجعي من ضريبة حاسبة), derived (محسوب من رسوم أخرى)"""

    flat_amount = Column(Numeric(12, 2), nullable=True, default=0.00)
    """المبلغ المقطوع بالجنيه لو الحساب flat"""

    reference_source = Column(String(50), nullable=True)
    """المصدر المرجعي لو الحساب reference: duty_amount, service_fee_amount, vat_amount"""

    derived_formula_rate = Column(Numeric(5, 2), nullable=True)
    """النسبة المئوية لو الحساب derived (مثل 14% ضريبة قيمة مضافة على النافذة)"""

    derived_formula_base_codes = Column(String(100), nullable=True)
    """الأكواد المرجعية المقسمة بفواصل e.g. '390,392'"""

    effective_from = Column(Date, nullable=False, default=date.today)
    effective_to = Column(Date, nullable=True, default=None)
    source_url = Column(String(500), nullable=True)
    notes = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_by = Column(String(100), nullable=True)
    updated_by = Column(String(100), nullable=True)

