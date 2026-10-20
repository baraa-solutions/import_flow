from datetime import date, datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, ConfigDict


class TierDetail(BaseModel):
    tier_name: str
    days: int
    rate_per_day: float
    total_amount: float


class PortStorageBreakdown(BaseModel):
    """Output breakdown of port storage calculation engine."""
    terminal_code: str
    terminal_name: str
    container_size: str
    is_reefer: bool
    gate_in_date: date
    end_date: date
    total_days: int
    free_days_allowed: int
    chargeable_days: int
    tier1_days: int
    tier1_rate: float
    tier1_amount: float
    tier2_days: int
    tier2_rate: float
    tier2_amount: float
    penal_days: int
    penal_rate: float
    penal_amount: float
    storage_charges_egp: float
    reefer_plugging_charges_egp: float
    xray_scan_fee_egp: float
    scale_fee_egp: float
    total_port_storage_egp: float
    currency: str = "EGP"
    tier_details: Optional[List[TierDetail]] = None


class PortStorageCalculationRequest(BaseModel):
    """Input payload to calculate terminal storage."""
    terminal_code: str = Field(..., description="Terminal code: ACCHCO, DP_WORLD_SOKHNA, DCHC, SCCT")
    container_size: str = Field(default="20ft", description="20ft or 40ft")
    is_reefer: bool = Field(default=False, description="Is reefer container with temperature control")
    gate_in_date: date = Field(..., description="Date container discharged/gated in to terminal")
    current_or_gate_out_date: date = Field(..., description="Calculation cutoff or gate out date")
    customs_release_date: Optional[date] = Field(default=None, description="Customs final release date if applicable")
    include_xray: bool = Field(default=True, description="Include terminal x-ray scanning fee")
    include_scale: bool = Field(default=True, description="Include weighbridge scale fee")


# --- Rate Schemas ---

class PortTerminalRateBase(BaseModel):
    terminal_code: str
    terminal_name: str
    container_size: str
    is_reefer: bool = False
    free_days: int = 3
    tier1_rate_per_day: float = 0.0
    tier2_rate_per_day: float = 0.0
    penal_rate_per_day: float = 0.0
    reefer_plugging_daily_fee: float = 0.0
    xray_scan_fee: float = 0.0
    scale_fee: float = 0.0
    currency: str = "EGP"
    effective_date: date
    notes: Optional[str] = None
    is_active: bool = True


class PortTerminalRateCreate(PortTerminalRateBase):
    pass


class PortTerminalRateUpdate(BaseModel):
    terminal_name: Optional[str] = None
    free_days: Optional[int] = None
    tier1_rate_per_day: Optional[float] = None
    tier2_rate_per_day: Optional[float] = None
    penal_rate_per_day: Optional[float] = None
    reefer_plugging_daily_fee: Optional[float] = None
    xray_scan_fee: Optional[float] = None
    scale_fee: Optional[float] = None
    currency: Optional[str] = None
    effective_date: Optional[date] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class PortTerminalRateResponse(PortTerminalRateBase):
    rate_id: int
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)


# --- Accrual Schemas ---

class PortStorageAccrualBase(BaseModel):
    import_file_id: Optional[int] = None
    terminal_code: str
    container_number: str
    container_size_type: str
    is_reefer: bool = False
    gate_in_date: date
    customs_release_date: Optional[date] = None
    gate_out_date: Optional[date] = None
    free_days_allowed: int = 3
    chargeable_days: int = 0
    storage_charges_egp: float = 0.0
    reefer_plugging_charges_egp: float = 0.0
    xray_scan_fee_egp: float = 0.0
    scale_fee_egp: float = 0.0
    total_port_storage_egp: float = 0.0
    status: str = "ESTIMATED"
    invoice_number: Optional[str] = None
    invoice_date: Optional[date] = None
    paid_amount_egp: Optional[float] = None
    payment_reference: Optional[str] = None
    notes: Optional[str] = None


class PortStorageAccrualCreate(BaseModel):
    import_file_id: Optional[int] = None
    terminal_code: str
    container_number: str
    container_size_type: str
    is_reefer: bool = False
    gate_in_date: date
    customs_release_date: Optional[date] = None
    gate_out_date: Optional[date] = None
    auto_calculate: bool = Field(default=True, description="Auto-calculate charges from terminal tariff")
    free_days_allowed: Optional[int] = None
    chargeable_days: Optional[int] = None
    storage_charges_egp: Optional[float] = None
    reefer_plugging_charges_egp: Optional[float] = None
    xray_scan_fee_egp: Optional[float] = None
    scale_fee_egp: Optional[float] = None
    total_port_storage_egp: Optional[float] = None
    status: Optional[str] = "ESTIMATED"
    notes: Optional[str] = None


class PortStorageAccrualUpdate(BaseModel):
    terminal_code: Optional[str] = None
    container_number: Optional[str] = None
    container_size_type: Optional[str] = None
    is_reefer: Optional[bool] = None
    gate_in_date: Optional[date] = None
    customs_release_date: Optional[date] = None
    gate_out_date: Optional[date] = None
    free_days_allowed: Optional[int] = None
    chargeable_days: Optional[int] = None
    storage_charges_egp: Optional[float] = None
    reefer_plugging_charges_egp: Optional[float] = None
    xray_scan_fee_egp: Optional[float] = None
    scale_fee_egp: Optional[float] = None
    total_port_storage_egp: Optional[float] = None
    status: Optional[str] = None
    invoice_number: Optional[str] = None
    invoice_date: Optional[date] = None
    paid_amount_egp: Optional[float] = None
    payment_reference: Optional[str] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class PortStorageAccrualStatusUpdate(BaseModel):
    status: str = Field(..., description="ESTIMATED, INVOICED, PAID")
    invoice_number: Optional[str] = None
    invoice_date: Optional[date] = None
    paid_amount_egp: Optional[float] = None
    payment_reference: Optional[str] = None
    notes: Optional[str] = None


class PortStorageAccrualResponse(PortStorageAccrualBase):
    accrual_id: int
    is_active: bool
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)


class PortStorageSummaryResponse(BaseModel):
    total_accruals: int
    total_storage_charges_egp: float
    total_reefer_charges_egp: float
    total_ancillary_fees_egp: float
    total_port_storage_egp: float
    estimated_count: int
    invoiced_count: int
    paid_count: int
