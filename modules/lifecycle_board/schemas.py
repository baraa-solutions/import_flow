"""
Pydantic Schemas for Shipment Stage Activity & Lifecycle Board
"""

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, Field


class StageStepInfo(BaseModel):
    step_code: str
    phase_id: int
    name_en: str
    name_ar: str
    action_url: str
    icon: str
    color: str


class StageActivityBase(BaseModel):
    import_file_code: str = Field(..., min_length=2, max_length=50)
    step_code: str = Field(..., min_length=2, max_length=50)
    status: str = Field("In-Progress", max_length=50)
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    assigned_user: Optional[str] = None
    action_data: Optional[str] = None
    notes: Optional[str] = None


class StageActivityCreate(StageActivityBase):
    pass


class StageActivityUpdate(BaseModel):
    status: Optional[str] = None
    completed_at: Optional[str] = None
    assigned_user: Optional[str] = None
    action_data: Optional[str] = None
    notes: Optional[str] = None


class StageActivityResponse(StageActivityBase):
    id: int
    msg_code: Optional[str] = None
    msg_params: Optional[Dict[str, Any]] = None
    model_config = ConfigDict(from_attributes=True)


class StepAdvancePayload(BaseModel):
    import_file_code: str
    current_step_code: str
    next_step_codes: List[str] = [] # Supports multi-target next steps
    notes: Optional[str] = None
    action_data: Optional[Dict[str, Any]] = None
    auto_complete_prior: bool = True


class LifecycleSyncRequest(BaseModel):
    completed_step_code: str = Field(..., min_length=2, max_length=50, description="The operational step completed (e.g. STEP_06)")
    import_file_code: Optional[str] = Field(None, min_length=2, max_length=50, description="Import file business code (e.g. IMP-2026-0001)")
    import_file_id: Optional[int] = Field(None, description="Import file database primary key ID")
    target_step_codes: Optional[List[str]] = Field(None, description="Target step codes to activate as In-Progress (None = auto-infer next)")
    assigned_user: Optional[str] = Field(
        None,
        description="Deprecated: acting user is derived from the JWT authentication token.",
        json_schema_extra={"deprecated": True},
    )
    action_data: Optional[Dict[str, Any]] = None
    notes: Optional[str] = None
    source_module: Optional[str] = None
    auto_complete_prior: bool = Field(True, description="Auto-complete prior steps (honoured for ADMIN only)")



class SkipStepPayload(BaseModel):
    import_file_code: str
    current_step_code: str
    skip_reason: str = Field(..., min_length=2, description="Reason for skipping the operational step")
    next_step_codes: List[str] = Field(default_factory=list, description="Next operational step codes to activate")


class MultiStageSetPayload(BaseModel):
    import_file_code: str
    active_step_codes: List[str]
    notes: Optional[str] = None


class ShipmentStageCard(BaseModel):
    import_file_code: str
    company_name: str
    supplier_name: str
    po_number: Optional[str] = None
    shipment_mode: Optional[str] = None
    incoterm_code: Optional[str] = None
    priority: Optional[str] = None
    estimated_cost: Optional[float] = None
    estimated_cost_currency: Optional[str] = None
    step_code: str
    step_name_en: str
    step_name_ar: str
    previous_step_code: Optional[str] = None
    previous_step_name_en: Optional[str] = None
    previous_step_name_ar: Optional[str] = None
    next_step_code: Optional[str] = None
    next_step_name_en: Optional[str] = None
    next_step_name_ar: Optional[str] = None
    status: str
    started_at: Optional[str] = None
    notes: Optional[str] = None
    msg_code: Optional[str] = None  # system message code of ``notes`` (English render in ``notes``)
    msg_params: Optional[Dict[str, Any]] = None


class PhaseSummary(BaseModel):
    phase_id: int
    title_en: str
    title_ar: str
    color_hex: str
    step_codes: List[str]
    total_active_shipments: int
    step_counts: Dict[str, int]


class LifecycleBoardSummaryResponse(BaseModel):
    phases: List[PhaseSummary]
    total_active_files: int
    all_shipments: List[ShipmentStageCard]


class LiveLogisticsTrackingItem(BaseModel):
    import_file_id: int
    import_file_code: str
    company_name: str
    supplier_name: str
    po_number: Optional[str] = None
    shipment_mode: Optional[str] = None
    incoterm_code: Optional[str] = None
    priority: Optional[str] = None

    # Voyage & Vessel Logistics
    bl_number: Optional[str] = None
    carrier_name: Optional[str] = None
    vessel_name: Optional[str] = None
    pol_name: Optional[str] = None
    pod_name: Optional[str] = None
    etd: Optional[str] = None
    eta: Optional[str] = None
    eta_countdown_days: Optional[int] = None # Positive = Days remaining to arrival, Negative = Days in port
    arrival_status: str = "Pre-Shipment" # Pre-Shipment, In Transit, In Port / Clearing, Cleared

    # Demurrage & Detention Free Time Radar
    demurrage_tracking_code: Optional[str] = None
    demurrage_status: str = "No Active Session" # Safe, Warning, Critical, Overdue, No Active Session
    free_days_total: Optional[int] = None
    free_days_remaining: Optional[int] = None
    used_free_days: int = 0
    demurrage_risk_level: str = "Unknown" # Low, Medium, High, Critical, Unknown
    accumulated_demurrage_fx: float = 0.0
    accumulated_demurrage_egp: float = 0.0

    # Regulatory Testing & Laboratory Samples
    sample_test_status: str = "Not Applicable" # Pending, Under Testing, Approved, Rejected, Exempted, Not Applicable
    regulatory_agency: Optional[str] = None # GOEIC, Food Safety, Radiation, NTRA
    lab_receipt_number: Optional[str] = None
    sample_result_countdown_days: Optional[int] = None

    # Smart Document Readiness
    doc_readiness_percent: float = 0.0 # 0.0 to 100.0%
    verified_documents_count: int = 0
    total_required_documents: int = 7
    missing_documents: List[str] = []

    # Overall Operational Health & Stage
    operational_health_score: str = "Optimal" # Optimal, Attention Needed, Critical Alert
    current_step_code: str = "STEP_01"
    current_step_name_ar: str = ""
    current_step_name_en: str = ""
    next_action: str = ""
    next_action_code: Optional[str] = None  # NA_* system message code of ``next_action``
    next_action_params: Optional[Dict[str, Any]] = None


class LiveLogisticsSummaryResponse(BaseModel):
    total_active_shipments: int
    in_transit_count: int
    in_port_count: int
    high_risk_demurrage_count: int
    under_sample_testing_count: int
    incomplete_documents_count: int
    items: List[LiveLogisticsTrackingItem]


# ─── Configurable Step Risk Classification Schemas (Addendum: Section 10) ───

class StepConfigResponse(BaseModel):
    id: int
    step_code: str
    step_name_ar: str
    step_name_en: str
    phase_id: int
    skip_policy: str = "blocked" # "blocked", "single_approval", "dual_approval"
    reason_required: bool = True # always True
    reason_categories: List[str] = Field(default_factory=list)
    approver_roles: List[str] = Field(default_factory=lambda: ["Manager"])
    supports_pending_reference: bool = False
    last_modified_by: Optional[str] = None
    last_modified_at: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)


class StepConfigUpdateRequest(BaseModel):
    skip_policy: Optional[str] = Field(None, pattern=r"^(blocked|single_approval|dual_approval)$")
    reason_categories: Optional[List[str]] = None
    approver_roles: Optional[List[str]] = None
    supports_pending_reference: Optional[bool] = None
    justification: str = Field(..., min_length=5, description="Mandatory short explanation for classification change (Section 10.3 & 10.7)")


class StepConfigAuditLogResponse(BaseModel):
    id: int
    step_code: str
    action: str
    changed_by: str
    changed_at: str
    old_policy: Optional[str] = None
    new_policy: Optional[str] = None
    old_approver_roles: Optional[List[str]] = None
    new_approver_roles: Optional[List[str]] = None
    old_supports_pending_reference: Optional[bool] = None
    new_supports_pending_reference: Optional[bool] = None
    justification: str
    model_config = ConfigDict(from_attributes=True)


class RegisterPendingReferenceRequest(BaseModel):
    import_file_code: str = Field(..., min_length=2, max_length=50)
    step_code: str = Field(..., min_length=2, max_length=50)
    reference_number: str = Field(..., min_length=1, max_length=100)
    reason_text: str = Field(..., min_length=3)
    expected_completion_date: Optional[str] = None


class RegisterPendingReferenceResponse(BaseModel):
    message: str
    import_file_code: str
    step_code: str
    reference_number: str
    reason_text: str
    expected_completion_date: Optional[str] = None
    status: str = "Reference recorded – pending full documentation"
    registered_at: str

