from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

from modules.common.legacy_rows import LegacyRowTolerantModel

class GrnItemSchema(BaseModel):
    item_code: str = Field(..., min_length=1)
    item_name: str = Field(..., min_length=1)
    invoiced_qty: int = Field(0, ge=0)
    accepted_qty: int = Field(0, ge=0)
    shortage_qty: int = Field(0, ge=0)
    damaged_qty: int = Field(0, ge=0)
    quarantine_flag: bool = False

class WarehouseReceivingCreate(BaseModel):
    import_file_id: int
    warehouse_name: str = Field(..., min_length=2)
    arrival_datetime: Optional[datetime] = None
    truck_plate_number: Optional[str] = None
    driver_name: Optional[str] = None
    driver_phone: Optional[str] = None
    seal_number: Optional[str] = None
    seal_intact: bool = True
    grn_items: List[GrnItemSchema] = Field(..., min_length=1)
    discrepancy_notes: Optional[str] = None
    inspector_name: Optional[str] = Field(None, description="[Deprecated] Acting user is taken from the token")
    notes: Optional[str] = None

class DiscrepancyReportSubmit(BaseModel):
    discrepancy_type: str = Field(..., description="Shortage, Damage, Excess, Wrong Item")
    discrepancy_notes: str
    quarantine_zone_assigned: bool = False
    insurance_claim_filed: bool = False
    insurance_claim_ref: Optional[str] = None

class WarehouseInspectionSubmit(BaseModel):
    inspection_date: Optional[datetime] = None
    inspection_committee: Optional[str] = Field(None, description="Defaults to DEFAULT_INSPECTION_COMMITTEE")
    inspection_verdict: Optional[str] = Field(
        None,
        description="ACCEPTED_FULL, ACCEPTED_WITH_DISCREPANCY, REJECTED_QUARANTINED, DAMAGE_CLAIM_PENDING; null = derived from the quantities",
    )
    root_cause: Optional[str] = Field(None, description="Port Handling, Transit Vibration, Packaging Failure, Water Ingress, Factory Shortage")
    grn_items: Optional[List[GrnItemSchema]] = None
    discrepancy_type: Optional[str] = "None"
    discrepancy_notes: Optional[str] = None
    quarantine_zone_assigned: bool = False
    insurance_claim_filed: bool = False
    insurance_claim_ref: Optional[str] = None
    supplier_claim_filed: bool = False
    supplier_claim_ref: Optional[str] = None
    claim_amount_estimated: Optional[float] = Field(None, ge=0.0)
    claim_currency: Optional[str] = None
    inspector_name: Optional[str] = Field(None, description="[Deprecated] Acting user is taken from the token")
    notes: Optional[str] = None

class WarehouseReceivingUpdate(BaseModel):
    warehouse_name: Optional[str] = None
    truck_plate_number: Optional[str] = None
    driver_name: Optional[str] = None
    seal_intact: Optional[bool] = None
    grn_items: Optional[List[GrnItemSchema]] = None
    discrepancy_type: Optional[str] = None
    discrepancy_notes: Optional[str] = None
    status: Optional[str] = None
    inspector_name: Optional[str] = Field(None, description="[Deprecated] Acting user is taken from the token")
    notes: Optional[str] = None
    inspection_committee: Optional[str] = None
    inspection_verdict: Optional[str] = None
    root_cause: Optional[str] = None
    supplier_claim_filed: Optional[bool] = None
    supplier_claim_ref: Optional[str] = None
    claim_amount_estimated: Optional[float] = Field(None, ge=0.0)
    claim_currency: Optional[str] = None

class WarehouseReceivingResponse(LegacyRowTolerantModel):
    # supplier_claim_filed / claim_* / discrepancy_rate_percent were added on 2026-09-18: NULL on older rows.
    receiving_id: int
    grn_code: str
    import_file_id: int
    warehouse_name: str
    arrival_datetime: datetime
    truck_plate_number: Optional[str] = None
    driver_name: Optional[str] = None
    driver_phone: Optional[str] = None
    seal_number: Optional[str] = None
    seal_intact: bool
    grn_items: List[Dict[str, Any]]
    total_invoiced_qty: int
    total_accepted_qty: int
    total_shortage_qty: int
    total_damaged_qty: int
    discrepancy_type: str
    discrepancy_notes: Optional[str] = None
    quarantine_zone_assigned: bool
    insurance_claim_filed: bool
    insurance_claim_ref: Optional[str] = None
    is_under_bond_quarantine: bool = False
    quarantine_lock_active: bool = False
    dispatch_blocked: bool = False
    inspection_date: Optional[datetime] = None
    inspection_committee: Optional[str] = None
    inspection_protocol_number: Optional[str] = None
    inspection_verdict: Optional[str] = "PENDING"
    root_cause: Optional[str] = None
    supplier_claim_filed: bool = False
    supplier_claim_ref: Optional[str] = None
    claim_amount_estimated: Optional[float] = None  # amounts / rates: a legacy NULL stays None
    claim_currency: Optional[str] = None
    discrepancy_rate_percent: Optional[float] = 0.0
    status: str
    inspector_name: str
    notes: Optional[str] = None
    is_active: bool
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)


class InspectionSummaryResponse(BaseModel):
    receiving_id: int
    grn_code: str
    import_file_id: int
    inspection_protocol_number: Optional[str] = None
    inspection_date: Optional[datetime] = None
    inspection_committee: Optional[str] = None
    inspection_verdict: str
    root_cause: Optional[str] = None
    total_invoiced_qty: int
    total_accepted_qty: int
    total_shortage_qty: int
    total_damaged_qty: int
    discrepancy_rate_percent: float
    quarantine_zone_assigned: bool
    insurance_claim_filed: bool
    insurance_claim_ref: Optional[str] = None
    supplier_claim_filed: bool
    supplier_claim_ref: Optional[str] = None
    claim_amount_estimated: Optional[float] = None
    claim_currency: Optional[str] = None
    status: str
    is_ready_for_landed_cost: bool


class WarehouseDispatchValidationResponse(BaseModel):
    receiving_id: int
    grn_code: str
    is_dispatch_allowed: bool
    status: str
    message: str


class PaginatedWarehouseReceivingResponse(BaseModel):
    items: List[WarehouseReceivingResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


