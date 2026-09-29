"""
Import Documentation & Regulatory Compliance Models (Phase 3 - BP-014 to BP-019)
"""

from datetime import datetime, date, timezone
from sqlalchemy import String, Float, Integer, DateTime, Date, ForeignKey, Boolean, Text, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from database.database import Base


class AcidRegistrationSession(Base):
    """
    ACID Registration & Verification Session (BP-014).
    Stores Nafeza 19-digit ACID Number, issue/expiry dates, matching verification flags, and approval status.
    Supports smart MTS parsing and discrepancy detection between requested & generated data.
    """

    __tablename__ = "acid_registration_sessions"

    acid_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    acid_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    acid_number: Mapped[str] = mapped_column(
        String(50), index=True, nullable=False
    )

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )
    po_number: Mapped[str] = mapped_column(String(100), nullable=True)
    po_date: Mapped[date] = mapped_column(Date, nullable=True)

    # Importer Details
    importer_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_companies.company_id"), nullable=True, index=True
    )
    importer_name: Mapped[str] = mapped_column(String(200), nullable=False)
    importer_tax_id: Mapped[str] = mapped_column(String(50), nullable=False)
    importer_address: Mapped[str] = mapped_column(String(300), nullable=True)

    # Foreign Exporter Details
    supplier_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("suppliers.supplier_id"), nullable=True, index=True
    )
    exporter_name: Mapped[str] = mapped_column(String(200), nullable=False)
    exporter_reg_type: Mapped[str] = mapped_column(String(100), default="VAT Number", nullable=True)
    exporter_reg_id: Mapped[str] = mapped_column(String(100), nullable=False)
    exporter_country: Mapped[str] = mapped_column(String(100), nullable=False)
    exporter_country_code: Mapped[str] = mapped_column(String(10), nullable=True)
    exporter_address: Mapped[str] = mapped_column(String(300), nullable=True)
    exporter_phone: Mapped[str] = mapped_column(String(50), nullable=True)
    cargox_id: Mapped[str] = mapped_column(String(100), nullable=True)

    # Invoice & Shipping Details
    proforma_invoice_no: Mapped[str] = mapped_column(String(100), nullable=False)
    proforma_invoice_date: Mapped[date] = mapped_column(Date, nullable=True)
    invoice_date: Mapped[date] = mapped_column(Date, nullable=True)
    invoice_type: Mapped[str] = mapped_column(String(50), default="Proforma Invoice", nullable=True)
    invoice_attachment_name: Mapped[str] = mapped_column(String(255), nullable=True)

    pol_name: Mapped[str] = mapped_column(String(150), nullable=False)
    pod_name: Mapped[str] = mapped_column(String(150), nullable=False)

    # Customs Broker Details
    customs_broker_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("external_service_providers.provider_id"), nullable=True, index=True
    )
    customs_broker_name: Mapped[str] = mapped_column(String(200), nullable=True)
    customs_broker_phone: Mapped[str] = mapped_column(String(50), nullable=True)

    # Dates
    requested_date: Mapped[date] = mapped_column(Date, default=date.today, nullable=False)
    generated_date: Mapped[date] = mapped_column(Date, nullable=True)
    expiry_date: Mapped[date] = mapped_column(Date, nullable=False)
    execution_days: Mapped[int] = mapped_column(Integer, nullable=True)

    # Raw MTS Text & Smart Parsing Snapshots
    raw_nafeza_text: Mapped[str] = mapped_column(Text, nullable=True)
    requested_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    generated_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    discrepancies_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    discrepancy_override_reason: Mapped[str] = mapped_column(Text, nullable=True)

    # Verification Match Flags
    is_importer_matched: Mapped[bool] = mapped_column(Boolean, default=True)
    is_exporter_matched: Mapped[bool] = mapped_column(Boolean, default=True)
    is_invoice_matched: Mapped[bool] = mapped_column(Boolean, default=True)
    is_ports_matched: Mapped[bool] = mapped_column(Boolean, default=True)
    has_discrepancies: Mapped[bool] = mapped_column(Boolean, default=False)
    verification_notes: Mapped[str] = mapped_column(Text, nullable=True)

    # Status: 'Requested', 'Generated', 'Verified', 'Discrepancy_Accepted', 'Rejected_For_Revision', 'Expired', 'Cancelled'
    status: Mapped[str] = mapped_column(
        String(50), default="Generated", nullable=False, index=True
    )

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


class BankingDocumentSession(Base):
    """
    Form 4 / Form 9 / Letter of Credit (L/C) Banking Operations (BP-015).
    Manages Central Bank of Egypt import banking forms and L/C opening.
    """

    __tablename__ = "banking_document_sessions"

    bank_doc_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    bank_doc_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )

    # Doc Type: 'Form 4', 'Form 9', 'Letter of Credit (L/C)'
    doc_type: Mapped[str] = mapped_column(
        String(50), default="Form 4", nullable=False, index=True
    )

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )
    bank_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("external_service_providers.provider_id"), nullable=True, index=True
    )
    bank_name: Mapped[str] = mapped_column(String(200), nullable=False)

    doc_reference_number: Mapped[str] = mapped_column(String(100), default="PENDING", nullable=False)
    amount: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    currency_code: Mapped[str] = mapped_column(String(10), default="USD", nullable=False)

    request_date: Mapped[date] = mapped_column(Date, default=date.today, nullable=False)
    received_date: Mapped[date] = mapped_column(Date, nullable=True)
    execution_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    issue_date: Mapped[date] = mapped_column(Date, default=date.today, nullable=False)
    expiry_date: Mapped[date] = mapped_column(Date, nullable=True)

    # Status: 'Requested', 'Draft', 'Submitted to Bank', 'Approved by Bank', 'Form Issued', 'Received', 'Rejected'
    status: Mapped[str] = mapped_column(
        String(50), default="Requested", nullable=False, index=True
    )
    notes: Mapped[str] = mapped_column(Text, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


class ShipmentDocumentItem(Base):
    """
    Shipment Document Lifecycle & CargoX / B/L Endorsement (BP-016, BP-017, BP-018).
    Tracks Commercial Invoice, Packing List, Bill of Lading, Certificate of Origin, Inspection Certs.
    """

    __tablename__ = "shipment_document_items"

    document_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    document_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )
    doc_name: Mapped[str] = mapped_column(
        String(100), nullable=False, index=True
    )  # e.g. 'Commercial Invoice', 'Packing List', 'Bill of Lading (B/L)', 'Certificate of Origin (COO)', 'Form 4'

    doc_number: Mapped[str] = mapped_column(String(100), nullable=False)
    issue_date: Mapped[date] = mapped_column(Date, default=date.today, nullable=False)
    received_date: Mapped[date] = mapped_column(Date, nullable=True)

    # Status: 'Draft', 'Received', 'Under Review', 'Approved', 'Rejected', 'Endorsed'
    status: Mapped[str] = mapped_column(
        String(50), default="Approved", nullable=False, index=True
    )

    # CargoX Integration & B/L Endorsement
    is_cargox_uploaded: Mapped[bool] = mapped_column(Boolean, default=False)
    cargox_envelope_id: Mapped[str] = mapped_column(String(100), nullable=True)
    is_bl_endorsed: Mapped[bool] = mapped_column(Boolean, default=False)
    endorsement_number: Mapped[str] = mapped_column(String(100), nullable=True)

    notes: Mapped[str] = mapped_column(Text, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


class CustomsDeclarationDraft(Base):
    """
    Customs Declaration 46 Preparation (BP-019).
    Draft for Egyptian Customs Declaration 46 ready for Nafeza Submission.
    """

    __tablename__ = "customs_declaration_drafts"

    declaration_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    declaration_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )
    acid_number: Mapped[str] = mapped_column(String(50), nullable=False)
    form4_number: Mapped[str] = mapped_column(String(100), nullable=True)
    bl_number: Mapped[str] = mapped_column(String(100), nullable=True)

    total_cif_val_egp: Mapped[float] = mapped_column(Float, default=0.0)
    total_customs_duties_egp: Mapped[float] = mapped_column(Float, default=0.0)
    total_vat_egp: Mapped[float] = mapped_column(Float, default=0.0)

    # Status: 'Draft Prepared', 'Submitted to Customs Broker', 'Clearance Declaration 46 Issued'
    declaration_status: Mapped[str] = mapped_column(
        String(50), default="Draft Prepared", nullable=False, index=True
    )

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


class DraftBLReviewSession(Base):
    """
    Draft Bill of Lading (B/L) Review & Multi-Source Intelligent Comparison Engine (Phase 6 / BP-017).
    Cross-checks Draft B/L with Shipment, Invoice, Packing List, and VGM/Container Tracking data in real-time.
    Supports fuzzy matching, ±0.5% tolerance, blocking critical field rules, and auto-generated correction letters.
    """

    __tablename__ = "draft_bl_review_sessions"

    bl_review_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    bl_review_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )
    booking_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("shipment_bookings.booking_id"), nullable=True, index=True
    )

    draft_bl_number: Mapped[str] = mapped_column(String(100), default="DRAFT-BL", nullable=False)
    shipping_line: Mapped[str] = mapped_column(String(150), nullable=True)
    vessel_name: Mapped[str] = mapped_column(String(150), nullable=True)
    voyage_number: Mapped[str] = mapped_column(String(100), nullable=True)
    booking_no: Mapped[str] = mapped_column(String(100), nullable=True)
    hbl_no: Mapped[str] = mapped_column(String(100), nullable=True)
    mbl_no: Mapped[str] = mapped_column(String(100), nullable=True)
    freight_terms: Mapped[str] = mapped_column(String(50), default="Prepaid", nullable=True)
    place_of_delivery: Mapped[str] = mapped_column(String(150), nullable=True)

    # Sub identifiers & Metrics
    importer_tax_id: Mapped[str] = mapped_column(String(100), nullable=True)
    shipper_reg_id: Mapped[str] = mapped_column(String(100), nullable=True)
    measurement_cbm: Mapped[float] = mapped_column(Float, default=0.0, nullable=True)
    net_weight_kg: Mapped[float] = mapped_column(Float, default=0.0, nullable=True)
    packages_count: Mapped[int] = mapped_column(Integer, default=0, nullable=True)
    container_summary: Mapped[str] = mapped_column(String(500), nullable=True)

    # Draft source: 'MANUAL_ENTRY', 'SMART_TEXT', 'EXCEL_UPLOAD', 'PDF_EXTRACT'
    draft_source: Mapped[str] = mapped_column(String(50), default="SMART_TEXT", nullable=False)

    # Version Tracking (v1, v2, v3...)
    version_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    parent_session_id: Mapped[int] = mapped_column(Integer, nullable=True)

    # Lifecycle Stage: 'Stage 1: Draft Review', 'Stage 2: Revision Required', 'Stage 3: Reviewed', 'Stage 4: Dual Approval', 'Stage 5: Final'
    stage: Mapped[str] = mapped_column(
        String(50), default="Stage 1: Draft Review", nullable=False, index=True
    )

    # Data Snapshots (Real-time reference vs draft comparison)
    system_snapshot_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    draft_input_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    comparison_matrix: Mapped[list] = mapped_column(JSON, nullable=True)
    checklist_data: Mapped[list] = mapped_column(JSON, nullable=True)
    revision_report_data: Mapped[list] = mapped_column(JSON, nullable=True)

    # Blocking Rules & Discrepancies
    has_blocking_mismatch: Mapped[bool] = mapped_column(Boolean, default=False)
    open_discrepancies_count: Mapped[int] = mapped_column(Integer, default=0)
    blocking_reasons: Mapped[list] = mapped_column(JSON, nullable=True)
    correction_request_letter: Mapped[str] = mapped_column(Text, nullable=True)

    # Dual Approval Stage 4
    importer_approval_status: Mapped[str] = mapped_column(String(50), default="Pending", nullable=False)
    importer_approved_by: Mapped[str] = mapped_column(String(100), nullable=True)
    importer_approval_date: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    importer_approval_notes: Mapped[str] = mapped_column(Text, nullable=True)

    broker_approval_status: Mapped[str] = mapped_column(String(50), default="Pending", nullable=False)
    broker_approved_by: Mapped[str] = mapped_column(String(100), nullable=True)
    broker_approval_date: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    broker_approval_notes: Mapped[str] = mapped_column(Text, nullable=True)

    # Status: 'DRAFT_RECEIVED', 'AUTO_COMPARISON_RUN', 'REVISION_REQUIRED', 'REVIEWED_PENDING_APPROVAL', 'APPROVED', 'FINAL', 'REJECTED'
    status: Mapped[str] = mapped_column(
        String(50), default="AUTO_COMPARISON_RUN", nullable=False, index=True
    )
    is_draft: Mapped[bool] = mapped_column(Boolean, default=False, nullable=True)

    reviewed_by: Mapped[str] = mapped_column(String(100), nullable=True)
    reviewed_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)
    approved_by: Mapped[str] = mapped_column(String(100), nullable=True)
    approved_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


class CertificateOfOriginReviewSession(Base):
    """
    Draft Certificate of Origin (COO) & EUR.1 4-Tab Verification Engine (Phase 6 / BP-016).
    Manages generation, smart parsing, discrepancy comparison matrix, and registry for COO/EUR.1.
    """

    __tablename__ = "certificate_of_origin_review_sessions"

    coo_review_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    coo_review_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )

    # Certificate Type: 'Standard COO', 'EUR.1', 'Form A', 'COMESA', 'Agadir Agreement'
    certificate_type: Mapped[str] = mapped_column(String(50), default="EUR.1", nullable=False)
    certificate_number: Mapped[str] = mapped_column(String(100), default="DRAFT-COO", nullable=False)

    exporter_name: Mapped[str] = mapped_column(String(200), nullable=False)
    importer_name: Mapped[str] = mapped_column(String(200), nullable=False)
    country_of_origin: Mapped[str] = mapped_column(String(100), nullable=False)
    destination_country: Mapped[str] = mapped_column(String(100), default="Egypt", nullable=False)

    transport_details: Mapped[str] = mapped_column(String(300), nullable=True)
    invoice_number: Mapped[str] = mapped_column(String(100), nullable=True)
    invoice_date: Mapped[date] = mapped_column(Date, nullable=True)

    raw_input_text: Mapped[str] = mapped_column(Text, nullable=True)
    system_snapshot_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    draft_input_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    comparison_matrix: Mapped[list] = mapped_column(JSON, nullable=True)

    has_discrepancies: Mapped[bool] = mapped_column(Boolean, default=False)
    has_critical_mismatch: Mapped[bool] = mapped_column(Boolean, default=False)
    override_reason: Mapped[str] = mapped_column(Text, nullable=True)

    # Status: 'Draft Generated', 'Draft Inputted', 'Verified', 'Discrepancy_Accepted', 'Correction Requested', 'Approved'
    status: Mapped[str] = mapped_column(
        String(50), default="Draft Generated", nullable=False, index=True
    )
    is_draft: Mapped[bool] = mapped_column(Boolean, default=False, nullable=True)

    reviewed_by: Mapped[str] = mapped_column(String(100), nullable=True)
    reviewed_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


class InspectionCertificateReviewSession(Base):
    """
    Draft Inspection & Conformity Certificate (COA / COC / VOC / GOEIC) Review Session (Phase 6 / BP-016).
    Manages generation, smart parsing, discrepancy comparison matrix, and registry for inspection certificates.
    """

    __tablename__ = "inspection_certificate_review_sessions"

    inspection_review_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    inspection_review_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=True, index=True
    )
    po_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("purchase_orders.po_id"), nullable=True, index=True
    )

    # Inspection Type: 'COA (Certificate of Analysis)', 'COC (Certificate of Conformity)', 'VOC (Verification of Conformity)', 'Pre-shipment Inspection (PSI)', 'Phytosanitary Certificate', 'Radiation Free Certificate'
    inspection_type: Mapped[str] = mapped_column(String(100), default="COC (Certificate of Conformity)", nullable=False)
    inspection_agency: Mapped[str] = mapped_column(String(100), default="SGS", nullable=False)
    certificate_number: Mapped[str] = mapped_column(String(100), default="DRAFT-INSP", nullable=False)

    issue_date: Mapped[date] = mapped_column(Date, default=date.today, nullable=False)
    expiry_date: Mapped[date] = mapped_column(Date, nullable=True)

    # Regulatory Authority: 'GOEIC (الرقابة على الصادرات والواردات)', 'NFSA (سلامة الغذاء)', 'EDA (هيئة الدواء المصرية)', 'Atomic Energy Authority (هيئة الطاقة الذرية)'
    regulatory_authority: Mapped[str] = mapped_column(String(150), default="GOEIC", nullable=False)
    standard_specification: Mapped[str] = mapped_column(String(200), default="Egyptian Standard ES Egyptian Conformity", nullable=True)

    raw_input_text: Mapped[str] = mapped_column(Text, nullable=True)
    system_snapshot_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    draft_input_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    comparison_matrix: Mapped[list] = mapped_column(JSON, nullable=True)

    has_discrepancies: Mapped[bool] = mapped_column(Boolean, default=False)
    has_critical_mismatch: Mapped[bool] = mapped_column(Boolean, default=False)
    override_reason: Mapped[str] = mapped_column(Text, nullable=True)

    # Status: 'Required_Draft_Generated', 'Draft_Inputted', 'Verified', 'Discrepancy_Accepted', 'Correction Requested', 'Approved', 'Waived_Not_Required'
    status: Mapped[str] = mapped_column(
        String(50), default="Required_Draft_Generated", nullable=False, index=True
    )

    reviewed_by: Mapped[str] = mapped_column(String(100), nullable=True)
    reviewed_at: Mapped[datetime] = mapped_column(DateTime, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


class POPackingReconciliationSession(Base):
    """
    PO & Packing List Final Reconciliation Session Model (BP-016 / Phase 6).
    Persists 3-way reconciliation audit between PO in system, Commercial Invoice, and Packing List.
    Enforces uniqueness per Import File (One active reconciliation session per import_file_id).
    """

    __tablename__ = "po_packing_reconciliation_sessions"

    session_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    session_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )

    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=False, unique=True, index=True
    )

    final_invoice_number: Mapped[str] = mapped_column(String(100), nullable=True)
    final_packing_list_number: Mapped[str] = mapped_column(String(100), nullable=True)
    acid_number: Mapped[str] = mapped_column(String(50), nullable=True)
    shipper_name: Mapped[str] = mapped_column(String(200), nullable=True)

    total_invoice_amount: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="EUR", nullable=False)

    total_packages: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    total_net_weight_kg: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    total_gross_weight_kg: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    total_cbm: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)

    overall_status: Mapped[str] = mapped_column(
        String(50), default="FULLY_MATCHED", nullable=False, index=True
    )
    is_safe_for_certification: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    critical_discrepancies_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    warning_discrepancies_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    header_discrepancies: Mapped[list] = mapped_column(JSON, nullable=True)
    reconciled_invoice_items: Mapped[list] = mapped_column(JSON, nullable=True)
    reconciled_packing_items: Mapped[list] = mapped_column(JSON, nullable=True)
    extracted_invoice_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    extracted_packing_data: Mapped[dict] = mapped_column(JSON, nullable=True)

    notes: Mapped[str] = mapped_column(Text, nullable=True)
    certified_by: Mapped[str] = mapped_column(String(100), nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


class InvoiceBLMatchSession(Base):
    """
    Certified & Draft Session for Smart Commercial Invoice vs B/L Match Engine (STEP_08_MATCH).
    Persists AI / Regex extraction results, discrepancy comparison matrix, match score,
    and certification status.
    """

    __tablename__ = "invoice_bl_match_sessions"

    session_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, index=True, autoincrement=True
    )
    session_code: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    import_file_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("import_files.import_file_id"), nullable=False, index=True
    )
    import_file_code: Mapped[str] = mapped_column(String(100), nullable=True)

    invoice_number: Mapped[str] = mapped_column(String(100), nullable=True)
    bl_number: Mapped[str] = mapped_column(String(100), nullable=True)
    packing_list_number: Mapped[str] = mapped_column(String(100), nullable=True)
    acid_number: Mapped[str] = mapped_column(String(50), nullable=True)

    match_score_percentage: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    overall_status: Mapped[str] = mapped_column(
        String(50), default="FULLY_MATCHED", nullable=False, index=True
    )
    is_safe_for_certification: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_draft: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    critical_discrepancies_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    warning_discrepancies_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    comparison_matrix: Mapped[list] = mapped_column(JSON, nullable=True)
    invoice_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    bl_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    packing_list_data: Mapped[dict] = mapped_column(JSON, nullable=True)

    correction_letter: Mapped[str] = mapped_column(Text, nullable=True)
    notes: Mapped[str] = mapped_column(Text, nullable=True)
    certified_by: Mapped[str] = mapped_column(String(100), nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False
    )


