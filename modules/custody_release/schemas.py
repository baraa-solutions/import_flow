from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

from modules.common.legacy_rows import LegacyRowTolerantModel, read_model

# Standard Domain Constants
CUSTODY_STATUSES = (
    "RELEASED_UNDER_CUSTODY",
    "FROZEN_IN_WAREHOUSE",
    "SAMPLE_CLEAR_FINAL_RELEASE",
    "BREACH_REPORTED",
)


# -------------------------------------------------------------
# Input Schemas
# -------------------------------------------------------------

class CustodyReleaseDossierCreate(BaseModel):
    import_file_id: int = Field(..., gt=0, description="Associated Import File ID")
    warehouse_id: Optional[int] = Field(None, gt=0, description="Destination Warehouse ID")
    warehouse_address: Optional[str] = Field(None, max_length=255, description="Physical storage address of under-custody cargo")
    custody_undertaking_number: str = Field(..., min_length=3, max_length=100, description="Official undertaking / bond reference number")
    judicial_officer_name: Optional[str] = Field(None, max_length=150, description="Customs judicial enforcement officer name")
    lead_seals_count: int = Field(0, ge=0, description="Number of intact customs lead seals applied")
    lead_seal_numbers: List[str] = Field(default_factory=list, description="Unique serial numbers of the customs lead seals")
    transport_permit_number: Optional[str] = Field(None, max_length=100, description="Official port-to-warehouse transport permit number")
    status: str = Field("RELEASED_UNDER_CUSTODY", description="Initial dossier status")
    lock_active: bool = Field(True, description="Enforce strict warehouse dispensing block")
    notes: Optional[str] = Field(None, description="Operational remarks or judicial instructions")


class CustodyReleaseDossierUpdate(BaseModel):
    warehouse_id: Optional[int] = None
    warehouse_address: Optional[str] = None
    judicial_officer_name: Optional[str] = None
    lead_seals_count: Optional[int] = Field(None, ge=0)
    lead_seal_numbers: Optional[List[str]] = None
    transport_permit_number: Optional[str] = None
    notes: Optional[str] = None


class CustodyWarehouseFreezeSubmit(BaseModel):
    warehouse_address: Optional[str] = Field(None, max_length=255, description="Confirmed storage location")
    notes: Optional[str] = Field(None, description="Physical warehouse receipt confirmation and seal check")


class CustodyFinalClearanceSubmit(BaseModel):
    final_clearance_letter_number: str = Field(..., min_length=2, max_length=100, description="Official final release / laboratory conformity certificate number")
    release_approved_at: Optional[datetime] = Field(None, description="Date & time of lab clearance issuance")
    notes: Optional[str] = Field(None, description="Release remarks and authorization log")


class CustodyBreachReportSubmit(BaseModel):
    breach_reason: str = Field(..., min_length=5, description="Detailed report of the seal breach, unauthorized movement, or tampering")
    reported_at: Optional[datetime] = Field(None, description="Date & time when breach was discovered")
    notes: Optional[str] = Field(None, description="Judicial / customs notification notes")


class WarehouseDispenseValidationResult(BaseModel):
    is_allowed: bool = Field(..., description="Whether cargo dispensing from warehouse is permitted")
    lock_active: bool = Field(..., description="Whether under-custody lock is currently active")
    status: str = Field(..., description="Current status of the custody release dossier")
    message: str = Field(..., description="Detailed operational rationale or block reason")
    custody_id: Optional[int] = None
    custody_undertaking_number: Optional[str] = None


# -------------------------------------------------------------
# Read & Response Schemas
# -------------------------------------------------------------

@read_model
class CustodyReleaseDossierResponse(LegacyRowTolerantModel):
    custody_id: int
    custody_code: str
    import_file_id: int
    warehouse_id: Optional[int] = None
    warehouse_address: Optional[str] = None
    custody_undertaking_number: str
    judicial_officer_name: Optional[str] = None
    lead_seals_count: int = 0
    lead_seal_numbers: List[str] = Field(default_factory=list)
    transport_permit_number: Optional[str] = None
    status: str = "RELEASED_UNDER_CUSTODY"
    lock_active: bool = True
    final_clearance_letter_number: Optional[str] = None
    release_approved_at: Optional[datetime] = None
    breach_reason: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    is_active: bool = True

    model_config = ConfigDict(from_attributes=True)


class CustodyReleaseDossierListResponse(BaseModel):
    total: int
    items: List[CustodyReleaseDossierResponse]
