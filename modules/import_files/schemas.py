"""
Pydantic Schemas for Import Files Master & Tracking Module
"""

from typing import List, Optional, Any, Dict
from datetime import date, datetime
from pydantic import BaseModel, Field


from pydantic import BaseModel, Field, ConfigDict

class InvoiceItemSchema(BaseModel):
    invoice_no: str = Field(..., description="Invoice Number e.g. PI-889")
    invoice_type: str = Field("Proforma Invoice", description="Proforma or Commercial Invoice")
    date: Optional[str] = None
    amount: float = Field(0.0, ge=0.0)
    currency: str = Field("USD")


class PackingListItemSchema(BaseModel):
    pl_no: str = Field(..., description="Packing List Number e.g. PL-889")
    date: Optional[str] = None
    total_packages: int = Field(0, ge=0)
    gross_weight_kg: float = Field(0.0, ge=0.0)
    cbm: float = Field(0.0, ge=0.0)


class ImportFileBase(BaseModel):
    custom_file_number: Optional[str] = Field(None, description="Custom File ID e.g. 6701068100")
    company_id: Optional[int] = None
    company_name: str = Field(..., min_length=2, description="Importing Company Name")
    supplier_id: Optional[int] = None
    supplier_name: str = Field(..., min_length=2, description="Foreign Supplier Name")
    broker_id: Optional[int] = None
    broker_name: Optional[str] = Field(None, description="Customs Broker Name")
    po_number: Optional[str] = Field(None, description="PO Number e.g. PO-1001")
    po_ids: Optional[List[int]] = None
    pi_number: Optional[str] = Field(None, description="Main PI Number e.g. PI-889")
    invoices_data: Optional[List[Dict[str, Any]]] = Field(default_factory=list, description="Multiple Invoices")
    packing_lists_data: Optional[List[Dict[str, Any]]] = Field(default_factory=list, description="Multiple Packing Lists")
    project_ids: Optional[List[int]] = Field(default_factory=list, description="List of linked Project IDs")
    project_names: Optional[str] = None
    shipment_mode: str = Field("Sea FCL", description="Sea FCL, Sea LCL, Air, Courier, Land, Multimodal")
    incoterm_code: str = Field("FOB", description="FOB, CIF, CFR, etc.")
    priority: str = Field("High", description="Low, Medium, High, Critical")
    shipment_category: str = Field("New Purchase", description="New Purchase, Repair, Replacement, Sample")
    hs_code: Optional[str] = Field(None, description="HS Code e.g. 8520")
    product_category: Optional[str] = Field(None, description="Product Category e.g. أجهزة ومعدات صوتية وأكوستيك")
    required_eta: Optional[date] = None
    file_opening_date: Optional[date] = Field(default_factory=date.today, description="تاريخ فتح الملف")
    selected_scenario: Optional[str] = Field(None, description="e.g. MSC Option")
    
    # Logistics & Freight RFQ Fields
    pickup_address: Optional[str] = Field(None, description="Pickup address for EXW shipment")
    port_of_loading: Optional[str] = Field(None, description="POL e.g. London Gateway, Shanghai Port, Jeddah")
    port_of_discharge: Optional[str] = Field("El Dekheila Port (non TMT)", description="POD e.g. El Dekheila Port")
    cargo_ready_date: Optional[date] = Field(None, description="Expected cargo ready date")
    target_free_days: Optional[int] = Field(21, description="Required demurrage/detention free time in days")
    service_type_preference: Optional[str] = Field("Direct", description="Direct, Transshipment, Any")
    shipping_instructions_notes: Optional[str] = Field(None, description="Special shipping instructions")

    acid_number: Optional[str] = Field(None, description="19-digit Nafeza ACID Number")
    acid_request_date: Optional[date] = None
    acid_issue_date: Optional[date] = None
    acid_expiry_date: Optional[date] = None
    acid_execution_days: Optional[int] = None
    is_customs_released: bool = Field(False, description="Shipment cleared and released from customs")
    customs_released_at: Optional[datetime] = None
    bl_number: Optional[str] = Field(None, description="Master/House Bill of Lading Number")
    booking_no: Optional[str] = Field(None, description="Carrier Booking Confirmation Number")
    vessel_name: Optional[str] = Field(None, description="Vessel Name")
    form4_no: Optional[str] = None
    form4_request_date: Optional[date] = None
    form4_received_date: Optional[date] = None
    form4_execution_days: Optional[int] = None
    swift_no: Optional[str] = None
    form46_no: Optional[str] = None
    form46_date: Optional[datetime] = None
    form46_status: Optional[str] = None
    cargox_envelope_id: Optional[int] = None
    cargox_envelope_code: Optional[str] = None
    cargox_envelope_status: Optional[str] = None
    cargox_transferred_at: Optional[datetime] = None
    original_documents_status: Optional[str] = None
    original_documents_received_at: Optional[datetime] = None
    original_documents_courier_no: Optional[str] = None
    original_documents_session_code: Optional[str] = None
    customs_broker_delegation_no: Optional[str] = None
    customs_broker_delegated_at: Optional[datetime] = None
    customs_broker_authorization_status: Optional[str] = None
    delivery_order_no: Optional[str] = None
    delivery_order_date: Optional[datetime] = None
    delivery_order_expiry_date: Optional[datetime] = None
    delivery_order_status: Optional[str] = None
    customs_duty_paid_amount: Optional[float] = 0.0
    customs_duty_receipt_no: Optional[str] = None
    customs_duty_sadad_no: Optional[str] = None
    customs_duty_payment_date: Optional[datetime] = None
    customs_duty_payment_status: Optional[str] = None
    customs_release_permit_no: Optional[str] = None
    customs_release_type: Optional[str] = None
    customs_release_officer: Optional[str] = None
    customs_gate_pass_no: Optional[str] = None
    total_clearance_expenses_egp: Optional[float] = Field(0.0, description="Total logged customs clearance & port expenses in EGP")
    clearance_invoices_status: Optional[str] = Field("Pending Invoices", description="Pending Invoices, Partially Logged, Invoices Logged & Verified")
    inland_transport_status: Optional[str] = Field("NOT_BOOKED", description="NOT_BOOKED, BOOKED, IN_TRANSIT, ARRIVED, COMPLETED")
    inland_transport_booking_no: Optional[str] = None
    inland_carrier_name: Optional[str] = None
    inland_truck_plate_no: Optional[str] = None
    inland_driver_name: Optional[str] = None
    inland_driver_phone: Optional[str] = None
    inland_transport_cost_egp: Optional[float] = 0.0
    inland_departure_date: Optional[datetime] = None
    inland_expected_arrival_date: Optional[datetime] = None
    inland_actual_arrival_date: Optional[datetime] = None
    empty_containers_returned_at: Optional[datetime] = None
    empty_containers_return_status: Optional[str] = None
    empty_containers_eir_numbers: Optional[str] = None
    empty_containers_depot_name: Optional[str] = None
    financial_settlement_status: Optional[str] = Field("PENDING_SETTLEMENT", description="PENDING_SETTLEMENT, INVOICES_SETTLED, COST_ALLOCATED, CLOSED")
    financial_settlement_date: Optional[date] = None
    financial_settlement_invoices_count: Optional[int] = 0
    financial_settlement_total_egp: Optional[float] = 0.0
    actual_landed_cost_total_egp: Optional[float] = 0.0
    actual_landed_cost_markup_factor: Optional[float] = 1.0
    actual_landed_cost_variance_egp: Optional[float] = 0.0
    actual_landed_cost_variance_pct: Optional[float] = 0.0
    actual_landed_cost_calculated_at: Optional[datetime] = None
    dossier_exported_at: Optional[datetime] = None
    dossier_exported_by: Optional[str] = None
    estimated_cost: float = Field(0.0, ge=0.0, description="Estimated Landed/Import Cost")
    estimated_cost_currency: str = Field("USD", description="عملة التكلفة التقديرية")
    # Dynamic Lifecycle Controls
    initial_starting_stage: Optional[str] = Field("Phase 1 - Planning & Feasibility", description="Starting Phase name")
    initial_starting_step: Optional[str] = Field("STEP_01", description="Starting Step code e.g. STEP_01, STEP_06, STEP_13")
    paused_at_stage: Optional[str] = None
    paused_at_step: Optional[str] = None
    hold_reason: Optional[str] = None
    hold_date: Optional[datetime] = None
    skipped_stages: Optional[List[str]] = Field(default_factory=list, description="List of skipped step codes")

    status: str = Field("Open", description="Open, In Progress, On Hold, Closed, Archived")
    owner: Optional[str] = Field(None, description="Operational Owner")
    notes: Optional[str] = None
    closure_reason: Optional[str] = Field(None, description="Reason for early closure or termination")
    closed_at_phase: Optional[str] = Field(None, description="Operational phase where closure occurred")


class CloseShipmentSubmit(BaseModel):
    closure_reason: str = Field(..., min_length=3, description="Reason for stopping/closing shipment")
    closed_at_phase: str = Field(..., description="Operational phase e.g. Phase 3 - Import Documentation")


class ReopenShipmentSubmit(BaseModel):
    reopen_reason: str = Field(..., min_length=3, description="Reason for reopening closed shipment")


class HoldShipmentPayload(BaseModel):
    hold_reason: str = Field(..., min_length=3, description="Reason for placing shipment on hold (English label or user text)")
    hold_reason_code: Optional[str] = Field(None, max_length=50, description="HOLD_REASON enum code (modules/common/enum_codes.py)")
    hold_notes: Optional[str] = None
    stage_name: Optional[str] = None
    step_name: Optional[str] = None


class ResumeShipmentPayload(BaseModel):
    resume_notes: Optional[str] = None


class ImportFileCreate(ImportFileBase):
    pass


class ImportFileUpdate(BaseModel):
    custom_file_number: Optional[str] = None
    company_id: Optional[int] = None
    company_name: Optional[str] = None
    supplier_id: Optional[int] = None
    supplier_name: Optional[str] = None
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    po_number: Optional[str] = None
    po_ids: Optional[List[int]] = None
    pi_number: Optional[str] = None
    invoices_data: Optional[List[Dict[str, Any]]] = None
    packing_lists_data: Optional[List[Dict[str, Any]]] = None
    project_ids: Optional[List[int]] = None
    project_names: Optional[str] = None
    shipment_mode: Optional[str] = None
    incoterm_code: Optional[str] = None
    priority: Optional[str] = None
    shipment_category: Optional[str] = None
    hs_code: Optional[str] = None
    product_category: Optional[str] = None
    required_eta: Optional[date] = None
    file_opening_date: Optional[date] = None
    selected_scenario: Optional[str] = None
    
    # Logistics & Freight RFQ Fields
    pickup_address: Optional[str] = None
    port_of_loading: Optional[str] = None
    port_of_discharge: Optional[str] = None
    cargo_ready_date: Optional[date] = None
    target_free_days: Optional[int] = None
    service_type_preference: Optional[str] = None
    shipping_instructions_notes: Optional[str] = None

    acid_number: Optional[str] = None
    acid_request_date: Optional[date] = None
    acid_issue_date: Optional[date] = None
    acid_expiry_date: Optional[date] = None
    acid_execution_days: Optional[int] = None
    is_customs_released: Optional[bool] = None
    customs_released_at: Optional[datetime] = None
    form4_no: Optional[str] = None
    form4_request_date: Optional[date] = None
    form4_received_date: Optional[date] = None
    form4_execution_days: Optional[int] = None
    swift_no: Optional[str] = None
    form46_no: Optional[str] = None
    form46_date: Optional[datetime] = None
    form46_status: Optional[str] = None
    cargox_envelope_id: Optional[int] = None
    cargox_envelope_code: Optional[str] = None
    cargox_envelope_status: Optional[str] = None
    cargox_transferred_at: Optional[datetime] = None
    original_documents_status: Optional[str] = None
    original_documents_received_at: Optional[datetime] = None
    original_documents_courier_no: Optional[str] = None
    original_documents_session_code: Optional[str] = None
    customs_broker_delegation_no: Optional[str] = None
    customs_broker_delegated_at: Optional[datetime] = None
    customs_broker_authorization_status: Optional[str] = None
    delivery_order_no: Optional[str] = None
    delivery_order_date: Optional[datetime] = None
    delivery_order_expiry_date: Optional[datetime] = None
    delivery_order_status: Optional[str] = None
    customs_duty_paid_amount: Optional[float] = None
    customs_duty_receipt_no: Optional[str] = None
    customs_duty_sadad_no: Optional[str] = None
    customs_duty_payment_date: Optional[datetime] = None
    customs_duty_payment_status: Optional[str] = None
    customs_release_permit_no: Optional[str] = None
    customs_release_type: Optional[str] = None
    customs_release_officer: Optional[str] = None
    customs_gate_pass_no: Optional[str] = None
    total_clearance_expenses_egp: Optional[float] = None
    clearance_invoices_status: Optional[str] = None
    inland_transport_status: Optional[str] = None
    inland_transport_booking_no: Optional[str] = None
    inland_carrier_name: Optional[str] = None
    inland_truck_plate_no: Optional[str] = None
    inland_driver_name: Optional[str] = None
    inland_driver_phone: Optional[str] = None
    inland_transport_cost_egp: Optional[float] = None
    inland_departure_date: Optional[datetime] = None
    inland_expected_arrival_date: Optional[datetime] = None
    inland_actual_arrival_date: Optional[datetime] = None
    empty_containers_returned_at: Optional[datetime] = None
    empty_containers_return_status: Optional[str] = None
    empty_containers_eir_numbers: Optional[str] = None
    empty_containers_depot_name: Optional[str] = None
    financial_settlement_status: Optional[str] = None
    financial_settlement_date: Optional[date] = None
    financial_settlement_invoices_count: Optional[int] = None
    financial_settlement_total_egp: Optional[float] = None
    actual_landed_cost_total_egp: Optional[float] = None
    actual_landed_cost_markup_factor: Optional[float] = None
    actual_landed_cost_variance_egp: Optional[float] = None
    actual_landed_cost_variance_pct: Optional[float] = None
    actual_landed_cost_calculated_at: Optional[datetime] = None
    dossier_exported_at: Optional[datetime] = None
    dossier_exported_by: Optional[str] = None
    estimated_cost: Optional[float] = None
    estimated_cost_currency: Optional[str] = None
    initial_starting_stage: Optional[str] = None
    initial_starting_step: Optional[str] = None
    paused_at_stage: Optional[str] = None
    paused_at_step: Optional[str] = None
    hold_reason: Optional[str] = None
    hold_date: Optional[datetime] = None
    skipped_stages: Optional[List[str]] = None
    status: Optional[str] = None
    owner: Optional[str] = None
    notes: Optional[str] = None


class FreightRfqDataResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    custom_file_number: Optional[str] = None
    company_name: str
    supplier_name: str
    incoterm_code: str
    commodity: str
    shipment_mode: str
    recommended_containers: str
    total_cbm: float
    gross_weight_kg: float
    net_weight_kg: float
    total_packages: int
    packages_breakdown: str
    pickup_address: str
    port_of_loading: str
    port_of_discharge: str
    cargo_ready_date: str
    target_free_days: int
    service_type: str
    special_requirements: str
    email_subject: str
    email_body_template: str
    whatsapp_text_template: str


class ImportFileResponse(ImportFileBase):
    model_config = ConfigDict(from_attributes=True)

    import_file_id: int
    import_file_code: str
    current_module: str
    current_stage: str
    progress_percent: float
    next_action: str
    # Single-language storage (additive, nullable): codes next to the English text columns
    current_step_code: Optional[str] = None
    current_phase_id: Optional[int] = None
    current_stage_code: Optional[str] = None
    next_action_code: Optional[str] = None
    next_action_params: Optional[Dict[str, Any]] = None
    hold_reason_code: Optional[str] = None
    is_active: bool = True
    cloned_from_id: Optional[int] = None
    cloned_from_code: Optional[str] = None
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str


class CloneImportFileRequest(BaseModel):
    target_import_file_code: Optional[str] = Field(None, min_length=3, description="New unique import file code")
    new_import_file_code: Optional[str] = Field(None, min_length=3, description="Alias for target_import_file_code")
    target_custom_file_number: Optional[str] = Field(None, description="New custom file number")
    copy_invoices_data: bool = Field(True, description="Copy items/invoices data")
    copy_packing_lists: bool = Field(True, description="Copy packing lists data")
    copy_items: Optional[bool] = Field(None, description="Alias for copy_invoices_data & copy_packing_lists")
    copy_attachments: bool = Field(False, description="Copy documents and attachments (default false per UX-CLONE-011)")
    notes: Optional[str] = Field(None, description="Optional notes on the cloned shipment")



class ImportMasterReportSummary(BaseModel):
    total_import_files: int
    open_files_count: int
    in_progress_count: int
    closed_files_count: int
    total_estimated_cost: float
    files: List[ImportFileResponse]


class OperationalDashboardBroker(BaseModel):
    broker_id: Optional[int] = None
    broker_name: str


class OperationalDashboardResponse(BaseModel):
    shipment_count: int
    shipments: List[ImportFileResponse]
    last_updated_at: datetime
    available_brokers: List[OperationalDashboardBroker]
    phase_counts: Dict[str, int]


class PaginatedImportFilesResponse(BaseModel):
    items: List[ImportFileResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
