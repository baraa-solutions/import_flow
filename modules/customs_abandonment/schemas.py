from datetime import date, datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, ConfigDict


class CustomsAbandonmentRadarBase(BaseModel):
    import_file_id: Optional[int] = None
    import_file_code: str
    port_type: str = Field(default="SEAPORT", description="SEAPORT, DRY_PORT, AIRPORT")
    port_name: Optional[str] = None
    arrival_date: date
    max_legal_days: int = 60
    days_in_port: int = 0
    days_remaining: int = 60
    risk_level: str = "NORMAL"
    extension_requested: bool = False
    extension_request_date: Optional[date] = None
    extension_reason: Optional[str] = None
    extension_request_ref: Optional[str] = None
    extension_granted_until: Optional[date] = None
    official_letter_issued: bool = False
    abandonment_status: str = "ACTIVE_CLEARING"
    importer_name: Optional[str] = None
    cargo_description: Optional[str] = None
    customs_declaration_no: Optional[str] = None
    bl_number: Optional[str] = None
    acid_number: Optional[str] = None
    container_numbers: Optional[List[str]] = None
    action_plan: Optional[str] = None
    notes: Optional[str] = None


class CustomsAbandonmentRadarCreate(BaseModel):
    import_file_id: Optional[int] = None
    import_file_code: str
    port_type: str = Field(default="SEAPORT", description="SEAPORT, DRY_PORT, AIRPORT")
    port_name: Optional[str] = None
    arrival_date: date
    importer_name: Optional[str] = None
    cargo_description: Optional[str] = None
    customs_declaration_no: Optional[str] = None
    bl_number: Optional[str] = None
    acid_number: Optional[str] = None
    container_numbers: Optional[List[str]] = None
    notes: Optional[str] = None


class CustomsAbandonmentRadarUpdate(BaseModel):
    port_type: Optional[str] = None
    port_name: Optional[str] = None
    arrival_date: Optional[date] = None
    max_legal_days: Optional[int] = None
    days_in_port: Optional[int] = None
    days_remaining: Optional[int] = None
    risk_level: Optional[str] = None
    extension_requested: Optional[bool] = None
    extension_request_date: Optional[date] = None
    extension_reason: Optional[str] = None
    extension_request_ref: Optional[str] = None
    extension_granted_until: Optional[date] = None
    official_letter_issued: Optional[bool] = None
    abandonment_status: Optional[str] = None
    importer_name: Optional[str] = None
    cargo_description: Optional[str] = None
    customs_declaration_no: Optional[str] = None
    bl_number: Optional[str] = None
    acid_number: Optional[str] = None
    container_numbers: Optional[List[str]] = None
    action_plan: Optional[str] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class CustomsAbandonmentRadarResponse(CustomsAbandonmentRadarBase):
    radar_id: int
    is_active: bool
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)


class ExtensionRequestCreate(BaseModel):
    reason: str = Field(..., description="Operational reason for customs delay (e.g. pending GOIEC test, food safety inspection, etc.)")
    requested_days: int = Field(default=30, ge=1, le=90, description="Additional days requested from Customs Authority")
    extension_request_ref: Optional[str] = Field(default=None, description="Internal or formal registry reference")
    action_plan: Optional[str] = Field(default=None, description="Clearance acceleration plan")


class ExtensionGrantCreate(BaseModel):
    extension_granted_until: date = Field(..., description="New statutory expiry date granted by Customs Authority")
    official_approval_ref: Optional[str] = Field(default=None, description="Customs Authority decree or approval letter number")
    notes: Optional[str] = None


class ExtensionLetterDraftResponse(BaseModel):
    letter_ref: str
    letter_date: date
    recipient_title: str
    importer_name: str
    import_file_code: str
    port_name: str
    subject: str
    formal_body_ar: str
    legal_basis: str
    metadata: Dict[str, Any]


class CustomsAbandonmentSummaryResponse(BaseModel):
    total_radars: int
    normal_count: int
    warning_15_days_count: int
    critical_7_days_count: int
    under_inventory_count: int
    extension_pending_count: int
    moved_to_warehouse_count: int
    auction_scheduled_count: int
    resolved_released_count: int
    seaport_count: int
    dry_port_count: int
    airport_count: int


class RecalculateResponse(BaseModel):
    total_evaluated: int
    updated_records: int
    critical_count: int
    warning_count: int
    inventory_count: int
    normal_count: int
    evaluated_at: datetime
