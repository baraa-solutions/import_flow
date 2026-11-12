"""Pydantic schemas of the air freight suite."""
from datetime import date, datetime
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

from modules.common.cargo_math import LengthUnit


class AirPackageLine(BaseModel):
    """One line of identical packages. Dimensions per package in ``dimension_unit`` (mm / cm / m); gross weight
    per package in ``weight_unit`` (kg / lb)."""
    length: float = Field(0.0, ge=0)
    width: float = Field(0.0, ge=0)
    height: float = Field(0.0, ge=0)
    dimension_unit: LengthUnit = "cm"
    quantity: int = Field(1, ge=1)
    gross_weight: float = Field(0.0, ge=0)
    weight_unit: Literal["kg", "lb"] = "kg"


class ChargeableWeightRequest(BaseModel):
    shipment_mode: str = Field("AIR", description="AIR or COURIER (selects the default divisor)")
    divisor: Optional[float] = Field(None, gt=0, description="Override of the configured volumetric divisor")
    packages: List[AirPackageLine] = Field(default_factory=list)
    # Whole-shipment gross weight when packages carry none (e.g. taken from the packing list).
    total_gross_weight: Optional[float] = Field(None, ge=0)
    total_gross_weight_unit: Literal["kg", "lb"] = "kg"


class ChargeableWeightLine(BaseModel):
    quantity: int
    length_cm: float
    width_cm: float
    height_cm: float
    gross_weight_kg: float
    volume_cbm: float
    volumetric_weight_kg: float


class ChargeableWeightResult(BaseModel):
    shipment_mode: str
    divisor: float
    pieces_count: int
    gross_weight_kg: float
    volume_cbm: float
    volumetric_weight_kg: float
    chargeable_weight_kg: float
    basis: Literal["GROSS", "VOLUMETRIC"]
    lines: List[ChargeableWeightLine] = Field(default_factory=list)


class AirShipmentRecordBase(BaseModel):
    shipment_mode: str = Field("AIR", description="AIR or COURIER")
    shipment_sub_mode: Optional[str] = None
    mawb_number: Optional[str] = Field(None, description="11-digit master AWB, e.g. 176-12345675")
    hawb_number: Optional[str] = Field(None, max_length=50)
    airline_id: Optional[int] = None
    origin_airport_id: Optional[int] = None
    destination_airport_id: Optional[int] = None
    flight_number: Optional[str] = Field(None, max_length=20)
    flight_date: Optional[date] = None
    arrival_date: Optional[date] = None
    pieces_count: Optional[int] = Field(None, ge=0)
    gross_weight_kg: Optional[float] = Field(None, ge=0)
    volumetric_divisor: Optional[float] = Field(None, gt=0)
    package_lines: Optional[List[AirPackageLine]] = None
    air_release_no: Optional[str] = Field(None, max_length=100)
    airport_storage_start_date: Optional[date] = None
    free_storage_days: Optional[int] = Field(None, ge=0, le=365)
    goods_description: Optional[str] = None
    notes: Optional[str] = None


class AirShipmentRecordCreate(AirShipmentRecordBase):
    import_file_id: int


class AirShipmentRecordUpdate(BaseModel):
    shipment_mode: Optional[str] = None
    shipment_sub_mode: Optional[str] = None
    mawb_number: Optional[str] = None
    hawb_number: Optional[str] = Field(None, max_length=50)
    airline_id: Optional[int] = None
    origin_airport_id: Optional[int] = None
    destination_airport_id: Optional[int] = None
    flight_number: Optional[str] = Field(None, max_length=20)
    flight_date: Optional[date] = None
    arrival_date: Optional[date] = None
    pieces_count: Optional[int] = Field(None, ge=0)
    gross_weight_kg: Optional[float] = Field(None, ge=0)
    volumetric_divisor: Optional[float] = Field(None, gt=0)
    package_lines: Optional[List[AirPackageLine]] = None
    air_release_no: Optional[str] = Field(None, max_length=100)
    airport_storage_start_date: Optional[date] = None
    free_storage_days: Optional[int] = Field(None, ge=0, le=365)
    goods_description: Optional[str] = None
    notes: Optional[str] = None


class StorageStatus(BaseModel):
    start_date: Optional[date] = None
    free_days: int
    free_until: Optional[date] = None
    days_remaining: Optional[int] = None
    chargeable_days: int = 0
    status: Literal["NOT_STARTED", "FREE", "LAST_DAY", "CHARGEABLE"]


class AirShipmentRecordResponse(AirShipmentRecordBase):
    model_config = ConfigDict(from_attributes=True)

    air_record_id: int
    air_record_code: str
    import_file_id: int
    airline_prefix: Optional[str] = None
    volume_cbm: Optional[float] = None
    volumetric_weight_kg: Optional[float] = None
    chargeable_weight_kg: Optional[float] = None
    package_lines: Optional[List[Dict[str, Any]]] = None
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    storage: Optional[StorageStatus] = None


class DraftAwbInput(BaseModel):
    """The draft AWB as received from the airline / forwarder. Every field is optional (progressive entry);
    a missing field is reported as MISSING in the checklist."""
    awb_number: Optional[str] = None
    shipper_name: Optional[str] = None
    consignee_name: Optional[str] = None
    origin_airport_code: Optional[str] = Field(None, description="IATA code or UN/LOCODE")
    destination_airport_code: Optional[str] = None
    pieces_count: Optional[int] = Field(None, ge=0)
    gross_weight_kg: Optional[float] = Field(None, ge=0)
    chargeable_weight_kg: Optional[float] = Field(None, ge=0)
    goods_description: Optional[str] = None


class DraftAwbReviewCreate(BaseModel):
    air_record_id: int
    draft: DraftAwbInput


class AwbChecklistItem(BaseModel):
    check: str
    status: Literal["MATCH", "MISMATCH", "MISSING", "WARNING"]
    blocking: bool
    draft_value: Optional[Any] = None
    system_value: Optional[Any] = None


class DraftAwbReviewDecision(BaseModel):
    decision: Literal["APPROVE", "REJECT"]
    notes: Optional[str] = None


class DraftAwbReviewResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    awb_review_id: int
    awb_review_code: str
    air_record_id: int
    import_file_id: int
    version_number: int
    draft_awb_number: Optional[str] = None
    draft_input_data: Optional[Dict[str, Any]] = None
    system_snapshot_data: Optional[Dict[str, Any]] = None
    checklist_data: Optional[List[AwbChecklistItem]] = None
    blocking_reasons_coded: Optional[List[Dict[str, Any]]] = None
    has_blocking_mismatch: bool
    open_discrepancies_count: int
    status: str
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    approved_by: Optional[str] = None
    approved_at: Optional[datetime] = None
    decision_notes: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None


class AirFreightSettings(BaseModel):
    """Configured constants (system parameters) the client needs for previews."""
    air_volumetric_divisor: float
    courier_volumetric_divisor: float
    free_storage_days: int
    weight_tolerance_pct: float


class AwbNumberCheck(BaseModel):
    awb_number: str
    is_valid: bool
    normalized: Optional[str] = None
    airline_prefix: Optional[str] = None
    reason_code: Optional[str] = None
