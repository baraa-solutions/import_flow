from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    Integer,
    String,
    Boolean,
    DateTime,
    ForeignKey,
    Float,
    JSON,
    Text,
)
from sqlalchemy.orm import relationship
from database.database import Base

# Referenced models for SQLAlchemy registry
from modules.import_files.model import ImportFile
from modules.external_service_providers.model import ExternalServiceProvider

class CustomsClearanceRecord(Base):
    """
    Phase 7 Customs Clearance & Inspection Model (BP-029 to BP-032)
    Tracks field customs inspection, channel routing (Green/Red),
    duty payment request breakdown, payment receipt details, and final release permit.
    """
    __tablename__ = "customs_clearance_records"

    customs_clearance_id = Column(Integer, primary_key=True, index=True)
    clearance_code = Column(String(50), unique=True, index=True, nullable=False)

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False)
    declaration_46_no = Column(String(100), nullable=True, index=True)
    declaration_46_date = Column(DateTime, nullable=True)
    mts_certificate_number = Column(String(100), nullable=True)
    customs_tariff_items_count = Column(Integer, default=1)
    customs_office_name = Column(String(200), default="Alexandria Port Customs", nullable=False)

    # BP-027 / CS-01: Customs Broker Assignment & Electronic Authorization
    broker_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True)
    broker_name = Column(String(255), nullable=True)
    delegation_number = Column(String(100), nullable=True, index=True)
    delegation_date = Column(DateTime, nullable=True)
    delegation_status = Column(String(50), default="Authorized", nullable=False) # Authorized, Pending, Revoked
    authorization_notes = Column(Text, nullable=True)
    mandate_letter_code = Column(String(100), nullable=True)

    # BP-029 Field Inspection & Channel (CL-01)
    channel_type = Column(String(30), default="Red Channel") # Red Channel, Green Channel, Yellow Channel
    inspection_date = Column(DateTime, nullable=True)
    inspection_type = Column(String(50), default="Physical & Sampling", nullable=True)
    inspection_yard = Column(String(150), nullable=True)
    inspector_name = Column(String(150), nullable=True)
    inspection_result = Column(String(50), default="Conforming", nullable=False)
    is_sample_drawn = Column(Boolean, default=True, nullable=False)
    sampling_date = Column(DateTime, nullable=True)
    sampling_record_no = Column(String(100), nullable=True)
    sampled_regulatory_bodies = Column(JSON, default=list, nullable=False)
    goeic_certificate_no = Column(String(100), nullable=True)
    regulatory_bodies = Column(JSON, default=list, nullable=False) # ["GOEIC", "Food Safety Authority", "NTRA"]
    sample_test_status = Column(String(50), default="Samples Under Testing") # Pending, Samples Under Testing, Approved, Rejected
    inspection_notes = Column(Text, nullable=True)

    # BP-030 & CL-02 Duty Payment Breakdown & Nafeza Assessment
    cif_base_amount = Column(Float, default=0.0)
    customs_exchange_rate = Column(Float, default=1.0)
    import_duty_amount = Column(Float, default=0.0)
    vat_amount = Column(Float, default=0.0)
    schedule_tax_amount = Column(Float, default=0.0)
    development_fee_amount = Column(Float, default=0.0)
    customs_service_fees = Column(Float, default=0.0)
    wht_amount = Column(Float, default=0.0)
    lab_service_fees = Column(Float, default=0.0)
    total_duty_payable = Column(Float, default=0.0)

    # Variance & Final Customs Duty Ledger for Landed Cost
    estimated_duty_total = Column(Float, default=0.0)
    actual_duty_total = Column(Float, default=0.0)
    duty_variance_amount = Column(Float, default=0.0)
    duty_variance_percentage = Column(Float, default=0.0)
    duty_variance_reason = Column(Text, nullable=True)
    nafeza_claim_number = Column(String(100), nullable=True, index=True)
    nafeza_claim_date = Column(DateTime, nullable=True)
    assessment_status = Column(String(50), default="Assessed") # Assessed, Verified, Discrepancy
    nafeza_assessment_json = Column(JSON, default=dict, nullable=True)

    # Port & Delivery Order Tracking (CS-02)
    port_arrival_date = Column(DateTime, nullable=True)
    delivery_order_number = Column(String(100), nullable=True, index=True)
    delivery_order_date = Column(DateTime, nullable=True)
    delivery_order_expiry = Column(DateTime, nullable=True)
    free_days_allowed = Column(Integer, default=14)
    shipping_agent_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True)
    shipping_agent_name = Column(String(255), nullable=True)
    delivery_order_fees = Column(Float, default=0.0)
    delivery_order_currency = Column(String(10), default="EGP")
    delivery_order_payment_ref = Column(String(100), nullable=True)
    delivery_order_paid_at = Column(DateTime, nullable=True)
    delivery_order_status = Column(String(50), default="Pending") # Pending, Paid & Received, Expired
    delivery_order_file_url = Column(String(500), nullable=True)
    delivery_order_notes = Column(Text, nullable=True)
    port_gate_out_date = Column(DateTime, nullable=True)

    # BP-031 & CL-03 Duty Payment Recording (سداد الرسوم الجمركية)
    payment_status = Column(String(30), default="Unpaid") # Unpaid, Payment Requested, Paid & Verified
    bank_receipt_no = Column(String(100), nullable=True)
    paying_bank_name = Column(String(200), nullable=True)
    payment_date = Column(DateTime, nullable=True)
    payment_notes = Column(Text, nullable=True)
    sadad_number = Column(String(100), nullable=True, index=True)
    payment_method = Column(String(50), default="SADAD_EFINANCE", nullable=True)  # PAYMENT_METHOD code
    duty_paid_amount = Column(Float, default=0.0)
    receipt_file_url = Column(String(500), nullable=True)

    # BP-032 & CL-04 Complete Customs Release (إذن الإفراج النهائي)
    release_permit_no = Column(String(100), nullable=True, index=True)
    release_date = Column(DateTime, nullable=True)
    release_officer_name = Column(String(255), nullable=True)
    release_type = Column(String(100), default="FINAL_GREEN", nullable=True)  # RELEASE_TYPE code
    release_document_url = Column(String(500), nullable=True)
    gate_pass_number = Column(String(100), nullable=True)
    demurrage_storage_fees = Column(Float, default=0.0)
    dispatch_authorized = Column(Boolean, default=False)
    dispatch_date = Column(DateTime, nullable=True)
    transport_instructions = Column(Text, nullable=True)

    # LOG-BOND-003: Under-Bond Clearance & Laboratory Quarantine Lock
    is_under_bond_release = Column(Boolean, default=False, nullable=False)
    bond_guarantee_ref = Column(String(100), nullable=True)  # رقم التعهد / الضمان البنكي أو الجمركي
    quarantine_lock = Column(Boolean, default=False, nullable=False)  # حظر الصرف والتشغيل بالمخزن
    lab_test_result = Column(String(50), default="None", nullable=False)  # None, Pending, Conforming, Non-Conforming
    lab_certificate_number = Column(String(100), nullable=True)
    quarantine_lifted_date = Column(DateTime, nullable=True)
    quarantine_lifted_by = Column(String(100), nullable=True)

    # CL-05: Clearance Fees & Port Invoices Aggregates
    total_clearance_expenses_egp = Column(Float, default=0.0)
    total_port_expenses_egp = Column(Float, default=0.0)
    total_handling_expenses_egp = Column(Float, default=0.0)
    clearance_invoices_count = Column(Integer, default=0)

    # Status & Audit
    status = Column(String(50), default="Inspection In Progress", index=True) # Inspection In Progress, Duty Requested, Duty Paid, Final Release Granted, Under Bond Released

    owner = Column(String(100), default="Kamal", nullable=False)
    notes = Column(Text, nullable=True)

    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")

    # Relationships
    import_file = relationship("ImportFile", backref="customs_clearance_records")
    broker = relationship("ExternalServiceProvider", foreign_keys=[broker_id])
    shipping_agent = relationship("ExternalServiceProvider", foreign_keys=[shipping_agent_id])
    clearance_invoices = relationship("ClearanceExpenseInvoice", back_populates="customs_clearance_record", cascade="all, delete-orphan")


class ClearanceExpenseInvoice(Base):
    """
    CL-05: Clearance Fees & Port Invoices Model (تسجيل فواتير المخلص ومصاريف العتالة ونولون الميناء)
    Tracks individual invoices and expense receipts issued by customs brokers, port terminals,
    stevedoring companies, and laboratories to feed the Egyptian Landed Cost Engine.
    """
    __tablename__ = "clearance_expense_invoices"

    invoice_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    invoice_code = Column(String(50), unique=True, index=True, nullable=False)

    import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True)
    customs_clearance_id = Column(Integer, ForeignKey("customs_clearance_records.customs_clearance_id"), nullable=True, index=True)

    invoice_number = Column(String(100), nullable=False)
    invoice_date = Column(DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))

    provider_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True)
    provider_name = Column(String(255), nullable=False)

    expense_category = Column(String(100), nullable=False)
    currency = Column(String(10), default="EGP", nullable=False)
    amount_fx = Column(Float, default=0.0)
    exchange_rate = Column(Float, default=1.0)
    amount_egp = Column(Float, nullable=False, default=0.0)

    vat_included = Column(Boolean, default=False)
    vat_amount = Column(Float, default=0.0)
    wht_deducted = Column(Boolean, default=False)
    wht_amount = Column(Float, default=0.0)
    net_payable_egp = Column(Float, nullable=False, default=0.0)

    payment_status = Column(String(50), default="Unpaid") # Unpaid, Partially Paid, Paid
    payment_ref = Column(String(100), nullable=True)
    document_url = Column(String(500), nullable=True)
    allocation_rule = Column(String(50), default="Equal") # Value-Based, Weight-Based, Volume-Based, Equal
    notes = Column(Text, nullable=True)

    is_verified = Column(Boolean, default=True)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), default="System")
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    updated_by = Column(String(100), default="System")

    # Relationships
    import_file = relationship("ImportFile", backref="clearance_expense_invoices")
    customs_clearance_record = relationship("CustomsClearanceRecord", back_populates="clearance_invoices")
    provider = relationship("ExternalServiceProvider", foreign_keys=[provider_id])
