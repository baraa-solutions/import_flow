"""
Pydantic Schemas for Smart Shipment Experience Guide (KB-GUIDE-012)
Institutional Knowledge Engine & Operational Memory + Autonomous Learning Engine (Section 5A)
"""
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
import json
from pydantic import BaseModel, Field, ConfigDict, computed_field


class GuideScopeCreate(BaseModel):
    scope_type: str = Field(..., description="Scope dimension type (supplier, country_of_origin, hs_code, etc.)")
    scope_value: str = Field(..., description="Scope matching value, e.g. '8520' or 'Alexandria'")


class GuideScopeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    scope_id: int
    guide_entry_id: int
    scope_type: str
    scope_value: str


class GuideEntryCreate(BaseModel):
    title: str = Field(..., min_length=2, max_length=255, description="Guide entry title")
    content: str = Field(..., min_length=3, description="Detailed guidance, alert, or instructions")
    entry_type: str = Field(default="alert", description="alert | required_document | task | info")
    severity: str = Field(default="info", description="info | warning | critical | positive")
    department: Optional[str] = Field(None, description="Department or originating team")
    expires_at: Optional[datetime] = Field(None, description="Optional expiry timestamp for regulation changes")
    created_by: str = Field(default="System", description="Staff username or author")
    scopes: List[GuideScopeCreate] = Field(default_factory=list, description="Target scopes for multi-condition matching")


class GuideEntryUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=2, max_length=255)
    content: Optional[str] = Field(None, min_length=3)
    entry_type: Optional[str] = None
    severity: Optional[str] = None
    department: Optional[str] = None
    expires_at: Optional[datetime] = None
    is_active: Optional[bool] = None
    scopes: Optional[List[GuideScopeCreate]] = None


class GuideEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    entry_id: int
    title: str
    content: str
    entry_type: str
    severity: str
    department: Optional[str] = None
    expires_at: Optional[datetime] = None
    upvotes: int = 0
    created_by: str
    created_at: datetime
    updated_at: datetime
    is_active: bool
    scopes: List[GuideScopeResponse] = Field(default_factory=list)

    # Dynamic fields populated during matching / query
    match_score: int = 0
    matched_dimensions: List[str] = Field(default_factory=list)

    # Autonomous Learning Engine (Section 5A) Fields
    source_type: str = "HUMAN_AUTHORED"
    status: str = "ACTIVE"
    pattern_category: Optional[str] = None
    confidence_score: Optional[float] = None
    confidence_level: Optional[str] = None
    sample_size: Optional[int] = None
    evidence_summary: Optional[str] = None
    contributing_files_json: Optional[str] = None
    reason_why: Optional[str] = None
    first_detected_at: Optional[datetime] = None
    last_recalculated_at: Optional[datetime] = None
    confirmed_by: Optional[str] = None
    confirmed_at: Optional[datetime] = None
    rejected_by: Optional[str] = None
    rejected_at: Optional[datetime] = None
    rejection_reason: Optional[str] = None
    msg_code: Optional[str] = None
    msg_params: Optional[Dict[str, Any]] = None

    @computed_field
    @property
    def is_expired(self) -> bool:
        if self.expires_at is None:
            return False
        now = datetime.now(timezone.utc)
        exp = self.expires_at if self.expires_at.tzinfo else self.expires_at.replace(tzinfo=timezone.utc)
        return exp < now

    @computed_field
    @property
    def is_system_inferred(self) -> bool:
        return self.source_type == "SYSTEM_INFERRED"

    @computed_field
    @property
    def is_confirmed(self) -> bool:
        return self.status == "CONFIRMED"


class GuideMatchRequest(BaseModel):
    # 13 Multi-Dimensional Tagging Attributes
    supplier: Optional[str] = None
    country_of_origin: Optional[str] = None
    hs_code: Optional[str] = None
    hs_codes: Optional[List[str]] = None
    product_category: Optional[str] = None
    product_categories: Optional[List[str]] = None
    port_of_loading: Optional[str] = None
    port_of_discharge: Optional[str] = None
    destination_port: Optional[str] = None  # alias for port_of_discharge
    shipping_line: Optional[str] = None
    incoterm: Optional[str] = None
    payment_method: Optional[str] = None
    certificate_type: Optional[str] = None
    customs_broker: Optional[str] = None
    season_timing: Optional[str] = None
    import_file_reference: Optional[str] = None
    import_file_id: Optional[int] = None


class GuideMatchResponse(BaseModel):
    matched_entries: List[GuideEntryResponse] = Field(default_factory=list)
    critical_entries: List[GuideEntryResponse] = Field(default_factory=list)
    warning_entries: List[GuideEntryResponse] = Field(default_factory=list)
    info_entries: List[GuideEntryResponse] = Field(default_factory=list)
    positive_entries: List[GuideEntryResponse] = Field(default_factory=list)
    has_critical_alert: bool = False
    has_blocking_critical_alert: bool = False
    has_warning_alert: bool = False
    mandatory_ports: List[str] = Field(default_factory=list)
    required_documents: List[str] = Field(default_factory=list)
    suggested_notes: List[str] = Field(default_factory=list)


class SimilarShipmentResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    company_name: str
    supplier_name: str
    country_of_origin: Optional[str] = None
    port_of_loading: Optional[str] = None
    port_of_discharge: Optional[str] = None
    shipping_line: Optional[str] = None
    status: str
    opening_date: Optional[str] = None
    clearance_duration_days: Optional[int] = None
    cost_variance_pct: Optional[float] = None
    matched_dimensions: List[str] = Field(default_factory=list)


class DetectedPatternResponse(BaseModel):
    pattern_id: str
    pattern_type: str  # delay | cost_variance | port_sampling | document_error
    dimension_type: str  # supplier | shipping_line | product_category | port_of_discharge
    dimension_value: str
    occurrence_count: int
    suggested_title: str
    suggested_content: str
    suggested_severity: str  # critical | warning | info
    suggested_entry_type: str  # alert | task | required_document
    evidence_shipments: List[str] = Field(default_factory=list)


class SmartReferenceCardResponse(BaseModel):
    import_file_id: int
    import_file_code: str
    custom_file_number: Optional[str] = None
    product_summary: Dict[str, Any]
    route_summary: Dict[str, Any]
    critical_dates: Dict[str, Any]
    document_status: Dict[str, Any]
    matched_guide_entries: List[GuideEntryResponse] = Field(default_factory=list)
    similar_shipments: List[SimilarShipmentResponse] = Field(default_factory=list)
    cost_summary: Dict[str, Any]


class GuideEntryPromoteRequest(BaseModel):
    promoted_by: str = Field(default="Authorized Staff", description="Name of the user promoting the note")
    edited_title: Optional[str] = Field(None, description="Optional override title")
    edited_content: Optional[str] = Field(None, description="Optional override content")
    edited_severity: Optional[str] = Field(None, description="Optional override severity")


class GuideEntryRejectRequest(BaseModel):
    rejected_by: str = Field(default="Authorized Staff", description="Name of the user rejecting the note")
    rejection_reason: str = Field(..., min_length=3, description="Operational explanation for rejection")


class ProvenanceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    entry_id: int
    title: str
    content: str
    source_type: str
    status: str
    pattern_category: Optional[str] = None
    confidence_score: Optional[float] = None
    confidence_level: Optional[str] = None
    sample_size: Optional[int] = None
    evidence_summary: Optional[str] = None
    contributing_files: List[Dict[str, Any]] = Field(default_factory=list)
    reason_why: Optional[str] = None
    first_detected_at: Optional[datetime] = None
    last_recalculated_at: Optional[datetime] = None
    confirmed_by: Optional[str] = None
    confirmed_at: Optional[datetime] = None
    rejected_by: Optional[str] = None
    rejected_at: Optional[datetime] = None
    rejection_reason: Optional[str] = None


class AutonomousAuditLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    log_id: int
    entry_id: Optional[int] = None
    pattern_key: str
    trigger_import_file_id: Optional[int] = None
    action: str
    previous_confidence: Optional[float] = None
    new_confidence: Optional[float] = None
    sample_size: int
    change_summary: str
    created_at: datetime


class AutonomousRecalculateResponse(BaseModel):
    status: str
    patterns_detected: int
    patterns_updated: int
    patterns_archived: int
    summary: str
