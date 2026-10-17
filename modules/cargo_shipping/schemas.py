from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

class ContainerLoadingTrackingItem(BaseModel):
    container_no: str
    seal_no: Optional[str] = None
    liner_seal_no: Optional[str] = None
    customs_seal_no: Optional[str] = None
    container_type: str = "40HC"
    tare_weight_kg: float = 0.0
    net_weight_kg: float = 0.0
    gross_weight_kg: float = 0.0
    vgm_status: str = "Pending"  # nothing is submitted until the user says so
    vgm_ref_no: Optional[str] = None
    # 5 Milestones
    container_assignment_date: Optional[str] = None # YYYY-MM-DD
    arrival_at_supplier_at: Optional[str] = None    # ISO datetime (or arrival at CFS)
    loading_start_at: Optional[str] = None          # ISO datetime (or stuffing start)
    loading_end_at: Optional[str] = None            # ISO datetime (or stuffing end)
    port_gate_in_at: Optional[str] = None           # ISO datetime
    # SLA & Status
    sla_deadline_at: Optional[str] = None           # ISO datetime (assignment + 48h)
    is_sla_breached: bool = False
    tracking_status: str = "PENDING_ASSIGNMENT"     # PENDING_ASSIGNMENT, ASSIGNED, EN_ROUTE_TO_SUPPLIER, ARRIVED_AT_SUPPLIER, LOADING_IN_PROGRESS, LOADING_COMPLETED, GATED_IN_AT_PORT
    tracking_history: List[Dict[str, Any]] = []
    individual_units: List[Dict[str, str]] = []
    milestone_notes: Optional[Dict[str, str]] = None

class ContainerLoadingItem(BaseModel):
    container_no: str
    seal_no: Optional[str] = None
    liner_seal_no: Optional[str] = None
    customs_seal_no: Optional[str] = None
    container_type: str = "40HC"
    quantity: int = 1
    tare_weight_kg: float = 0.0
    net_weight_kg: float = 0.0
    gross_weight_kg: float = 0.0
    vgm_status: str = "Pending"  # nothing is submitted until the user says so
    vgm_ref_no: Optional[str] = None
    # 5-Milestones Tracking Fields
    container_assignment_date: Optional[str] = None
    arrival_at_supplier_at: Optional[str] = None
    loading_start_at: Optional[str] = None
    loading_end_at: Optional[str] = None
    port_gate_in_at: Optional[str] = None
    sla_deadline_at: Optional[str] = None
    is_sla_breached: bool = False
    tracking_status: str = "PENDING_ASSIGNMENT"
    tracking_history: List[Dict[str, Any]] = []
    individual_units: List[Dict[str, str]] = []
    milestone_notes: Optional[Dict[str, str]] = None

class ContainerLoadingTrackingUpdate(BaseModel):
    container_no: str
    container_assignment_date: Optional[str] = None
    arrival_at_supplier_at: Optional[str] = None
    loading_start_at: Optional[str] = None
    loading_end_at: Optional[str] = None
    port_gate_in_at: Optional[str] = None
    seal_no: Optional[str] = None
    liner_seal_no: Optional[str] = None
    customs_seal_no: Optional[str] = None
    notes: Optional[str] = None
    milestone_notes: Optional[Dict[str, str]] = None
    updated_by: Optional[str] = Field(None, description="Deprecated and ignored: the logged-in user is recorded")

class LclLoadingTrackingItem(BaseModel):
    shipment_type: str = "LCL"
    cfs_warehouse_name: Optional[str] = None
    consolidation_scheduled_date: Optional[str] = None # container_assignment_date equivalent
    arrival_at_cfs_at: Optional[str] = None            # arrival_at_supplier_at equivalent
    stuffing_start_at: Optional[str] = None            # loading_start_at equivalent
    stuffing_end_at: Optional[str] = None              # loading_end_at equivalent
    port_gate_in_at: Optional[str] = None
    sla_deadline_at: Optional[str] = None
    is_sla_breached: bool = False
    tracking_status: str = "PENDING_ASSIGNMENT"
    tracking_history: List[Dict[str, Any]] = []

class CourierTrackingItem(BaseModel):
    courier_provider: str = "DHL Express"
    tracking_number: Optional[str] = None
    dispatch_date: Optional[str] = None
    receipt_status: str = "Dispatched" # Dispatched, Received at Office, Received at Bank
    received_at: Optional[str] = None
    received_by: Optional[str] = None

class CargoXVerificationRule(BaseModel):
    rule_name: str
    passed: bool = False
    details: Optional[str] = None

class CargoXExchangeItem(BaseModel):
    platform_provider: str = "CargoX Platform"
    envelope_id: Optional[str] = None
    envelope_status: str = "Created" # Created, Invited, Checklist Passed, Ready for Upload, Uploaded, Completed
    blockchain_tx_hash: Optional[str] = None
    verification_checklist: List[CargoXVerificationRule] = []

class CargoShippingCreate(BaseModel):
    import_file_id: int
    booking_id: Optional[int] = None
    shipment_type: str = "FCL" # FCL, LCL, Air
    crd_date: Optional[datetime] = None
    cargo_cutoff_date: Optional[datetime] = None
    containers_loading_data: List[ContainerLoadingItem] = []
    lcl_tracking_data: Optional[Dict[str, Any]] = None
    courier_tracking_data: Optional[CourierTrackingItem] = None
    cargox_exchange_data: Optional[CargoXExchangeItem] = None
    live_tracking_url: Optional[str] = None
    status: str = "Cargo Ready"
    owner: Optional[str] = Field(None, description="Defaults to the logged-in user when not sent")
    notes: Optional[str] = None

class DualApprovalLevel1Submit(BaseModel):
    approved_by: Optional[str] = Field(None, description="Deprecated and ignored: the approver is the logged-in user")
    approved: bool
    notes: Optional[str] = None

class DualApprovalLevel2Submit(BaseModel):
    approved_by: Optional[str] = Field(None, description="Deprecated and ignored: the approver is the logged-in user")
    approved: bool
    notes: Optional[str] = None

class CargoShippingUpdate(BaseModel):
    booking_id: Optional[int] = None
    shipment_type: Optional[str] = None
    crd_date: Optional[datetime] = None
    cargo_cutoff_date: Optional[datetime] = None
    containers_loading_data: Optional[List[ContainerLoadingItem]] = None
    lcl_tracking_data: Optional[Dict[str, Any]] = None
    courier_tracking_data: Optional[CourierTrackingItem] = None
    cargox_exchange_data: Optional[CargoXExchangeItem] = None
    live_tracking_url: Optional[str] = None
    # Only Cargo Ready / Loaded & Sealed / Docs Dispatched are applied, never below a workflow status
    status: Optional[str] = None
    owner: Optional[str] = None
    notes: Optional[str] = None

class CargoShippingResponse(BaseModel):
    cargo_shipping_id: int
    cargo_shipping_code: str
    import_file_id: int
    import_file_code: Optional[str] = None
    company_name: Optional[str] = None
    booking_id: Optional[int] = None
    shipment_type: str = "FCL"
    crd_date: Optional[datetime] = None
    cargo_cutoff_date: Optional[datetime] = None
    is_crd_validated: bool
    containers_loading_data: List[Dict[str, Any]]
    lcl_tracking_data: Optional[Dict[str, Any]] = None
    level1_approval_status: str
    level1_approved_by: Optional[str] = None
    level1_approved_at: Optional[datetime] = None
    level1_notes: Optional[str] = None
    level2_approval_status: str
    level2_approved_by: Optional[str] = None
    level2_approved_at: Optional[datetime] = None
    level2_notes: Optional[str] = None
    dual_approval_status: str
    courier_tracking_data: Dict[str, Any]
    cargox_exchange_data: Dict[str, Any]
    live_tracking_url: Optional[str] = None
    status: str
    owner: str
    notes: Optional[str] = None
    is_active: bool
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)
