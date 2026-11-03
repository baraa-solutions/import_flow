"""
SQLAlchemy Model for Import Requirements Assessment (BP-011)
"""
from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, Float, ForeignKey, JSON
from database.database import Base

class ImportRequirementAssessment(Base):
    __tablename__ = "import_requirement_assessments"

    assessment_id = Column(Integer, primary_key=True, autoincrement=True)
    assessment_code = Column(String(50), unique=True, nullable=False)  # BP011-2026-0001
    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id", ondelete="CASCADE"), nullable=True)
    import_file_code = Column(String(50), nullable=True)  # denormalized
    
    # HS Code & Commodity
    hs_code = Column(String(20), nullable=True)
    commodity_description = Column(Text, nullable=True)
    country_of_origin = Column(String(100), nullable=True)
    currency = Column(String(10), nullable=True, default=None)
    shipment_value = Column(Float, nullable=False, default=0.0)
    shipment_value_usd = Column(Float, nullable=False, default=0.0)
    
    # Certificate of Origin (COO)
    coo_required = Column(Boolean, nullable=False, default=False)
    coo_type = Column(String(100), nullable=True)  # EUR.1, Form A, GSTP, Arab League COO
    coo_status = Column(String(50), nullable=False, default="Not Required")  # Not Required, Pending, Obtained, Waived
    coo_notes = Column(Text, nullable=True)
    
    # Inspection Certificate
    inspection_required = Column(Boolean, nullable=False, default=False)
    inspection_body = Column(String(200), nullable=True)  # SGS, Bureau Veritas, QIMA
    inspection_status = Column(String(50), nullable=False, default="Not Required")  # Not Required, Pending, Scheduled, Completed
    inspection_notes = Column(Text, nullable=True)
    
    # MSDS (Material Safety Data Sheet)
    msds_required = Column(Boolean, nullable=False, default=False)
    msds_status = Column(String(50), nullable=False, default="Not Required")  # Not Required, Pending, Obtained
    msds_notes = Column(Text, nullable=True)
    
    # Halal / Food Safety Certificate
    halal_cert_required = Column(Boolean, nullable=False, default=False)
    halal_cert_status = Column(String(50), nullable=False, default="Not Required")
    halal_cert_notes = Column(Text, nullable=True)
    
    # Import Permit (موافقة الجهات الرقابية)
    import_permit_required = Column(Boolean, nullable=False, default=False)
    permit_issuing_authority = Column(String(200), nullable=True)  # GOEIC, Ministry of Health, etc.
    permit_status = Column(String(50), nullable=False, default="Not Required")  # Not Required, Applied, Approved, Rejected
    permit_notes = Column(Text, nullable=True)
    
    # Decree 43 / White List (المحور 1: قرار 43 وتسجيل المصانع)
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=True)
    supplier_name = Column(String(200), nullable=True)
    decree_43_applicable = Column(Boolean, nullable=False, default=False)
    white_list_required = Column(Boolean, nullable=False, default=False)
    white_list_verified = Column(Boolean, nullable=False, default=False)
    factory_registration_no = Column(String(100), nullable=True)  # رقم قيد المصنع/المورد بالهيئة
    
    # Inspection Certificate (المحور 3: فحص ما قبل الشحن)
    inspection_report_no = Column(String(100), nullable=True)
    
    # Import Permit (المحور 4: موافقات وتصاريح الجهات الرقابية)
    permit_number = Column(String(100), nullable=True)
    
    # Technical & Special Certs (المحور 5: شهادات خاصة)
    coa_required = Column(Boolean, nullable=False, default=False)
    coa_status = Column(String(50), nullable=False, default="Not Required")
    coa_notes = Column(Text, nullable=True)
    
    # HS Code breakdown & Other Requirements (flexible JSON)
    hs_code_items = Column(JSON, nullable=True)  # [{hs_code, description, value, currency, origin, ...}]
    other_requirements = Column(JSON, nullable=True)  # [{name, required, status, notes}]
    
    # Post-ACID Confirmation & Linkage (مرحلة تأكيدية بعد إصدار ACID)
    acid_number = Column(String(50), nullable=True)
    consultation_id = Column(Integer, ForeignKey("customs_consultation_sessions.consultation_id"), nullable=True)
    consultation_code = Column(String(50), nullable=True)
    confirmation_status = Column(String(50), nullable=False, default="Pending Confirmation")  # Pending Confirmation, Confirmed, Approved for Shipping
    is_post_acid_confirmed = Column(Boolean, nullable=False, default=False)
    confirmed_at = Column(DateTime, nullable=True)
    confirmed_by = Column(String(100), nullable=True)

    # Sailing & Shipping Progress (من إصدار ACID حتى الإبحار)
    sailing_status = Column(String(50), nullable=True, default="Pre-Sailing")
    sailing_date = Column(String(50), nullable=True)

    # CargoX & Pre-ACID Readiness (الركيزة 1: التسجيل المسبق وجاهزية كارغو إكس)
    cargox_verified = Column(Boolean, nullable=False, default=False)
    cargox_status = Column(String(50), nullable=True, default="Not Verified")
    ready_for_acid = Column(Boolean, nullable=False, default=False)
    triple_match_status = Column(String(50), nullable=True, default="Pending")

    # Import Card & Commodity Group (الركيزة 2: مطابقة المجموعات السلعية)
    commodity_group_matched = Column(Boolean, nullable=False, default=True)
    import_card_group_code = Column(String(100), nullable=True)

    # Adaptive Shelf-Life & Labeling (الركيزة 3: الصلاحية والملصق العربي المشروط)
    is_shelflife_applicable = Column(Boolean, nullable=False, default=False)
    shelf_life_total_days = Column(Integer, nullable=True)
    shelf_life_remaining_percent = Column(Float, nullable=True)
    artwork_arabic_approved = Column(Boolean, nullable=True)
    labeling_notes = Column(Text, nullable=True)

    # Testing & Physical Sampling (الركيزة 4: مسار الفحص والمعامل والإفراج تحت التحفظ)
    sampling_required = Column(Boolean, nullable=False, default=False)
    lab_type = Column(String(100), nullable=True)
    detention_allowed = Column(Boolean, nullable=False, default=False)
    estimated_lab_fees = Column(Float, nullable=False, default=0.0)

    # Special Logistics: Cold Chain & Hazmat (الركيزة 5: النقل المبرد والمواد الخطرة)
    cold_chain_required = Column(Boolean, nullable=False, default=False)
    target_temperature = Column(String(50), nullable=True)
    data_logger_verified = Column(Boolean, nullable=False, default=False)
    is_hazmat = Column(Boolean, nullable=False, default=False)
    imo_class = Column(String(50), nullable=True)

    # Governance: Maker-Checker & Overrides (الركيزة 6: حوكمة الصلاحيات والاعتماد المزدوج)
    checker_user_id = Column(Integer, nullable=True)
    checker_approved = Column(Boolean, nullable=False, default=False)
    checker_notes = Column(Text, nullable=True)
    is_overridden = Column(Boolean, nullable=False, default=False)
    override_reason = Column(Text, nullable=True)

    # Assessment Summary
    overall_status = Column(String(50), nullable=False, default="Draft")  # Draft, In Progress, Complete, Cleared, Confirmed
    risk_level = Column(String(20), nullable=False, default="Low")  # Low, Medium, High
    assessed_by = Column(String(100), nullable=False, default="Kamal")
    assessment_notes = Column(Text, nullable=True)
    
    # Audit
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), nullable=False, default="System")
    updated_by = Column(String(100), nullable=False, default="System")
