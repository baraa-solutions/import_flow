"""
Pydantic Schemas for Shipment Update Engine & Daily Log
"""

from typing import Literal, Optional, List
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field, field_validator
from modules.common.legacy_rows import LegacyRowTolerantModel, read_model

UpdateCategory = Literal["Follow-up & Notes", "Phase Cost Adjustment", "Future Phase Alert", "Daily Check-in", "Milestone Phase Progression"]
PhaseStatus = Literal["Completed", "Current", "Future"]
AlertPriority = Literal["Normal", "High", "Critical"]
TARGET_PHASE_PATTERN = r"^Phase (10|[1-9])$"


def _check_log_date(value: Optional[str]) -> Optional[str]:
    if value is None:
        return value
    try:
        datetime.strptime(value.strip(), "%Y-%m-%d")
    except ValueError:
        raise ValueError("log_date must be YYYY-MM-DD")
    return value.strip()


class ShipmentUpdateLogBase(BaseModel):
    import_file_id: int
    import_file_code: str
    update_category: str = Field("Follow-up & Notes", description="Follow-up & Notes, Phase Cost Adjustment, Future Phase Alert, Daily Check-in")
    target_phase: str = Field(..., description="Target phase e.g. Phase 3")
    phase_status: str = Field("Current", description="Completed, Current, Future")
    log_date: str = Field(..., description="Date YYYY-MM-DD")
    note: str = Field(..., min_length=2, description="Update notes")
    adjusted_cost_item: Optional[str] = None
    previous_cost: Optional[float] = 0.0
    new_cost: Optional[float] = 0.0
    alert_priority: str = Field("Normal", description="Normal, High, Critical")
    assigned_user: Optional[str] = Field(None, description="User name (defaults to the logged-in user on create)")


class ShipmentUpdateLogCreate(ShipmentUpdateLogBase):
    import_file_code: Optional[str] = Field(None, description="Deprecated and ignored: the code is read from the import file")
    update_category: UpdateCategory = "Follow-up & Notes"
    target_phase: str = Field(..., pattern=TARGET_PHASE_PATTERN, description="Phase 1 .. Phase 10")
    phase_status: PhaseStatus = "Current"
    alert_priority: AlertPriority = "Normal"
    assigned_user: Optional[str] = Field(None, description="Defaults to the logged-in user")

    _log_date = field_validator("log_date")(_check_log_date)


class ShipmentUpdateLogUpdate(BaseModel):
    note: Optional[str] = None
    log_date: Optional[str] = None
    adjusted_cost_item: Optional[str] = None
    previous_cost: Optional[float] = None
    new_cost: Optional[float] = None
    alert_priority: Optional[AlertPriority] = None
    assigned_user: Optional[str] = None

    _log_date = field_validator("log_date")(_check_log_date)


@read_model
class ShipmentUpdateLogResponse(ShipmentUpdateLogBase, LegacyRowTolerantModel):
    update_id: int
    update_code: str
    target_phase: str = "Phase 1"
    phase_status: str = "Current"
    log_date: str = ""
    note: str = ""
    previous_cost: Optional[float] = None
    new_cost: Optional[float] = None
    alert_priority: str = "Normal"
    update_category: str = "Follow-up & Notes"
    is_active: bool = True
    created_at: Optional[datetime] = None
    created_by: str = "System"
    updated_at: Optional[datetime] = None
    updated_by: str = "System"

    model_config = ConfigDict(from_attributes=True)


class PhaseStatusInspection(BaseModel):
    phase_code: str
    phase_name: str
    phase_number: int
    status: str  # Completed, Current, Future
    completion_date: Optional[str] = None
    last_note: Optional[str] = None
    update_count: int = 0
