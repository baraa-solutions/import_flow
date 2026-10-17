"""
SQLAlchemy Models for Import Files Master & Tracking (ملفات الشحنات الاستيرادية)
"""

from datetime import datetime, date, timezone
from typing import List, Optional
from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    Boolean,
    DateTime,
    Date,
    ForeignKey,
    JSON,
    Text,
    Index,
    text,
)
from sqlalchemy.orm import relationship

from database.database import Base

# Referenced Models for SQLAlchemy registry
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.external_service_providers.model import ExternalServiceProvider


class ImportFile(Base):
    __tablename__ = "import_files"

    import_file_id = Column(Integer, primary_key=True, index=True)
    import_file_code = Column(String(50), unique=True, index=True, nullable=False)
    custom_file_number = Column(String(50), unique=True, index=True, nullable=True) # e.g. 6701068100

    # Foreign Key References
    company_id = Column(Integer, ForeignKey("import_companies.company_id"), nullable=True, index=True)
    company_name = Column(String(255), nullable=False)
    
    supplier_id = Column(Integer, ForeignKey("suppliers.supplier_id"), nullable=True, index=True)
    supplier_name = Column(String(255), nullable=False)

    broker_id = Column(Integer, ForeignKey("external_service_providers.provider_id"), nullable=True, index=True)
    broker_name = Column(String(255), nullable=True)

    po_number = Column(String(100), nullable=True, index=True) # e.g. PO-1001
    po_ids = Column(JSON, nullable=True) # List of linked PO IDs
    
    pi_number = Column(String(100), nullable=True) # Main PI number e.g. PI-889
    invoices_data = Column(JSON, nullable=True) # List of Proforma/Commercial Invoices: [{"invoice_no": "PI-889", "date": "2026-08-01", "amount": 24500.0, "currency": "USD"}]
    packing_lists_data = Column(JSON, nullable=True) # List of Packing Lists: [{"pl_no": "PL-889", "date": "2026-08-01", "total_packages": 50, "gross_weight_kg": 12000.0, "cbm": 35.5}]
    invoices_count = Column(Integer, nullable=True, default=0)  # CGX-003: عدد الفواتير الفعلي للشحنة
    # CGX-003: آخر mode استُخدم في الاستخراج
    # values: "all_consolidated", "all_detailed", "per_invoice_consolidated", "per_invoice_detailed"
    extraction_preference = Column(String(50), nullable=True, default="all_consolidated")

    project_ids = Column(JSON, nullable=True) # List of linked Project IDs: [1, 2] (Must belong to company_id)
    project_names = Column(String(500), nullable=True)

    shipment_mode = Column(String(50), nullable=False, default="Sea FCL") # Sea FCL, Sea LCL, Air, Land
    incoterm_code = Column(String(20), nullable=False, default="FOB") # FOB, CIF, CFR, etc.
    priority = Column(String(20), nullable=False, default="High") # Low, Medium, High, Critical
    shipment_category = Column(String(50), nullable=False, default="New Purchase") # New Purchase, Repair, Replacement, Sample
    hs_code = Column(String(50), nullable=True) # e.g. 8520
    product_category = Column(String(100), nullable=True) # e.g. أجهزة ومعدات صوتية وأكوستيك
    
    required_eta = Column(Date, nullable=True) # 15-Aug-2026
    file_opening_date = Column(Date, nullable=True, default=date.today) # تاريخ فتح الملف
    selected_scenario = Column(String(100), nullable=True) # e.g. MSC Option

    # Logistics & Freight RFQ Details
    pickup_address = Column(Text, nullable=True) # Factory / Pickup address for EXW
    port_of_loading = Column(String(100), nullable=True) # POL e.g. Shanghai Port, London Gateway, Jeddah
    port_of_discharge = Column(String(100), nullable=True, default="El Dekheila Port (non TMT)") # POD e.g. El Dekheila Port
    cargo_ready_date = Column(Date, nullable=True) # Expected ready date for shipment
    target_free_days = Column(Integer, nullable=True, default=21) # Free time required (e.g. 21 days)
    service_type_preference = Column(String(50), nullable=True, default="Direct") # Direct, Transshipment, Any
    shipping_instructions_notes = Column(Text, nullable=True) # Special requirements e.g. Avoid TMT terminal, 21 days FT

    # Banking & Customs Document Links
    acid_number = Column(String(50), nullable=True, index=True) # e.g. 1987654321098765432
    acid_request_date = Column(Date, nullable=True)
    acid_issue_date = Column(Date, nullable=True)
    acid_expiry_date = Column(Date, nullable=True, index=True)
    acid_execution_days = Column(Integer, nullable=True)
    is_customs_released = Column(Boolean, default=False, nullable=False)
    customs_released_at = Column(DateTime, nullable=True)
    bl_number = Column(String(100), nullable=True, index=True)
    booking_no = Column(String(100), nullable=True, index=True)
    vessel_name = Column(String(200), nullable=True)
    form4_no = Column(String(100), nullable=True)
    form4_request_date = Column(Date, nullable=True)
    form4_received_date = Column(Date, nullable=True)
    form4_execution_days = Column(Integer, nullable=True)
    swift_no = Column(String(100), nullable=True)
    form46_no = Column(String(100), nullable=True)
    form46_date = Column(DateTime, nullable=True)
    form46_status = Column(String(50), nullable=True) # REGISTERED, PENDING
    cargox_envelope_id = Column(Integer, nullable=True, index=True)
    cargox_envelope_code = Column(String(100), nullable=True, index=True)
    cargox_envelope_status = Column(String(50), nullable=True)
    cargox_transferred_at = Column(DateTime, nullable=True)
    original_documents_status = Column(String(50), nullable=True) # FULLY_RECEIVED, PARTIALLY_RECEIVED, IN_TRANSIT, FULLY_VERIFIED
    original_documents_received_at = Column(DateTime, nullable=True)
    original_documents_courier_no = Column(String(100), nullable=True)
    original_documents_session_code = Column(String(50), nullable=True)
    customs_broker_delegation_no = Column(String(100), nullable=True)
    customs_broker_delegated_at = Column(DateTime, nullable=True)
    customs_broker_authorization_status = Column(String(50), nullable=True)
    delivery_order_no = Column(String(100), nullable=True)
    delivery_order_date = Column(DateTime, nullable=True)
    delivery_order_expiry_date = Column(DateTime, nullable=True)
    delivery_order_status = Column(String(50), nullable=True) # PAID_AND_RECEIVED, PENDING, EXPIRED
    customs_duty_paid_amount = Column(Float, default=0.0)
    customs_duty_receipt_no = Column(String(100), nullable=True)
    customs_duty_sadad_no = Column(String(100), nullable=True)
    customs_duty_payment_date = Column(DateTime, nullable=True)
    customs_duty_payment_status = Column(String(50), nullable=True) # PAID, PENDING
    customs_release_permit_no = Column(String(100), nullable=True)
    customs_release_type = Column(String(100), nullable=True)
    customs_release_officer = Column(String(255), nullable=True)
    customs_gate_pass_no = Column(String(100), nullable=True)
    total_clearance_expenses_egp = Column(Float, default=0.0)
    clearance_invoices_status = Column(String(50), default="Pending Invoices", nullable=True)
    inland_transport_status = Column(String(50), default="NOT_BOOKED", nullable=True) # NOT_BOOKED, BOOKED, IN_TRANSIT, ARRIVED, COMPLETED
    inland_transport_booking_no = Column(String(100), nullable=True)
    inland_carrier_name = Column(String(255), nullable=True)
    inland_truck_plate_no = Column(String(50), nullable=True)
    inland_driver_name = Column(String(100), nullable=True)
    inland_driver_phone = Column(String(50), nullable=True)
    inland_transport_cost_egp = Column(Float, default=0.0)
    inland_departure_date = Column(DateTime, nullable=True)
    inland_expected_arrival_date = Column(DateTime, nullable=True)
    inland_actual_arrival_date = Column(DateTime, nullable=True)
    empty_containers_returned_at = Column(DateTime, nullable=True)
    empty_containers_return_status = Column(String(50), nullable=True) # ALL_RETURNED, PARTIALLY_RETURNED, PENDING_RETURN
    empty_containers_eir_numbers = Column(String(255), nullable=True)
    empty_containers_depot_name = Column(String(255), nullable=True)

    # Financial Settlement (Stage 9: Landed Cost & File Closure - CLO-01 & CLO-02)
    financial_settlement_status = Column(String(50), default="PENDING_SETTLEMENT", nullable=True) # PENDING_SETTLEMENT, INVOICES_SETTLED, COST_ALLOCATED, CLOSED
    financial_settlement_date = Column(Date, nullable=True)
    financial_settlement_invoices_count = Column(Integer, default=0, nullable=True)
    financial_settlement_total_egp = Column(Float, default=0.0, nullable=True)
    actual_landed_cost_total_egp = Column(Float, default=0.0, nullable=True)
    actual_landed_cost_markup_factor = Column(Float, default=None, nullable=True)
    actual_landed_cost_variance_egp = Column(Float, default=0.0, nullable=True)
    actual_landed_cost_variance_pct = Column(Float, default=0.0, nullable=True)
    actual_landed_cost_calculated_at = Column(DateTime, nullable=True)

    # Comprehensive Shipment Dossier Export (Stage 9: Landed Cost & File Closure - CLO-03)
    dossier_exported_at = Column(DateTime, nullable=True)
    dossier_exported_by = Column(String(100), nullable=True)

    estimated_cost = Column(Float, nullable=False, default=0.0) # 24500.0
    estimated_cost_currency = Column(String(10), nullable=False, default="USD") # USD, EUR, EGP, etc.

    # Formulas & Stage Tracking
    current_module = Column(String(100), nullable=False, default="BP-001 Receive Purchase Order", index=True)
    current_stage = Column(String(100), nullable=False, default="Phase 1 - Planning & Feasibility", index=True)
    progress_percent = Column(Float, nullable=False, default=10.0) # 0 to 100
    next_action = Column(String(255), nullable=False, default="Review Proforma Invoice & Packing List")
    
    # Dynamic Lifecycle Controls (Start from any stage, Hold/Pause, and Skipped stages)
    initial_starting_stage = Column(String(100), default="Phase 1 - Planning & Feasibility", nullable=True)
    initial_starting_step = Column(String(50), default="STEP_01", nullable=True)
    paused_at_stage = Column(String(100), nullable=True)
    paused_at_step = Column(String(50), nullable=True)
    hold_reason = Column(Text, nullable=True)
    hold_date = Column(DateTime, nullable=True)
    skipped_stages = Column(JSON, default=list, nullable=True) # e.g. ["STEP_01", "STEP_06"]
    hold_reason_code = Column(String(50), nullable=True)  # HOLD_REASON enum code (hold_reason keeps the label/text)

    # Single-language storage: structured tracking next to the legacy English text columns
    current_step_code = Column(String(50), nullable=True)  # e.g. STEP_13
    current_phase_id = Column(Integer, nullable=True, index=False)  # 1..6
    current_stage_code = Column(String(50), nullable=True)  # PHASE_n or a special STAGE code (CUSTOMS_RELEASED)
    next_action_code = Column(String(80), nullable=True)  # NA_* system message code
    next_action_params = Column(JSON, nullable=True)

    status = Column(String(50), nullable=False, default="Open", index=True) # Open, In Progress, On Hold, Closed, Archived
    owner = Column(String(100), nullable=False, default="Kamal") # Operational owner e.g. Kamal
    notes = Column(Text, nullable=True)

    closure_reason = Column(Text, nullable=True)
    closed_at_phase = Column(String(100), nullable=True)

    # Audit Trail
    is_active = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    created_by = Column(String(100), default="System", nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    updated_by = Column(String(100), default="System", nullable=False)

    # Traceability & Cloning (UX-CLONE-011)
    cloned_from_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True)
    cloned_from_code = Column(String(50), nullable=True)

    # Partial Shipments Linkage (DEV-OPS-04)
    parent_import_file_id = Column(Integer, ForeignKey("import_files.import_file_id"), nullable=True)
    parent_file_code = Column(String(50), nullable=True)
    is_partial_shipment = Column(Boolean, default=False, server_default=text("0"), nullable=False)

    __table_args__ = (
        Index("idx_import_files_current_phase_id", "current_phase_id"),
        Index("idx_import_files_parent_id", "parent_import_file_id"),
    )


    # Relationships
    company = relationship("ImportCompany", foreign_keys=[company_id])
    supplier = relationship("Supplier", foreign_keys=[supplier_id])
    parent_file = relationship(
        "ImportFile",
        remote_side=[import_file_id],
        backref="child_partial_files",
        foreign_keys=[parent_import_file_id],
    )

