from datetime import datetime
from typing import Annotated, Any, Dict, List, Literal, Optional, Tuple

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, PrivateAttr, model_validator

from modules.common import cargo_math, enum_codes


class CBMItemBase(BaseModel):
    package_type: str = Field(default="Carton", json_schema_extra={"example": "Carton"})
    quantity: int = Field(..., gt=0, json_schema_extra={"example": 10})
    length: float = Field(default=100.0, gt=0, json_schema_extra={"example": 120.0})
    width: float = Field(default=80.0, gt=0, json_schema_extra={"example": 80.0})
    height: float = Field(default=60.0, gt=0, json_schema_extra={"example": 100.0})
    unit: cargo_math.LengthUnit = Field(default="cm", json_schema_extra={"example": "cm"})
    gross_weight_per_unit_kg: float = Field(default=0.0, ge=0, json_schema_extra={"example": 25.0})
    is_stackable: bool = Field(default=True, json_schema_extra={"example": True})
    freight_type: Optional[str] = Field(default="air_freight", json_schema_extra={"example": "air_freight"})
    divisor: Optional[float] = Field(default=None, json_schema_extra={"example": 6000.0})

    @model_validator(mode="before")
    @classmethod
    def populate_dimensions(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "length_cm" in data and ("length" not in data or not data["length"]):
                data["length"] = data["length_cm"]
            if "width_cm" in data and ("width" not in data or not data["width"]):
                data["width"] = data["width_cm"]
            if "height_cm" in data and ("height" not in data or not data["height"]):
                data["height"] = data["height_cm"]
        return data

    _dims_cm: Tuple[float, float, float] = PrivateAttr(default=(0.0, 0.0, 0.0))

    def model_post_init(self, __context: Any) -> None:
        self._dims_cm = cargo_math.to_cm(self.length, self.width, self.height, self.unit)

    @property
    def length_cm(self) -> float:
        return self._dims_cm[0]

    @property
    def width_cm(self) -> float:
        return self._dims_cm[1]

    @property
    def height_cm(self) -> float:
        return self._dims_cm[2]


class CBMItemCreate(CBMItemBase):
    pass


class CBMItemResponse(BaseModel):
    item_id: int
    calc_id: int
    package_type: str
    quantity: int
    # DB stores dimensions in CM; optional raw fields for backwards compatibility
    length_cm: float
    width_cm: float
    height_cm: float
    # Virtual / optional raw fields (populated from compute, may be absent from DB rows)
    length: Optional[float] = None
    width: Optional[float] = None
    height: Optional[float] = None
    unit: Optional[str] = None
    gross_weight_per_unit_kg: float
    total_cbm: float
    volumetric_weight_kg: float
    total_gross_weight_kg: float
    is_stackable: bool = True
    freight_type: Optional[str] = None
    divisor: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)


def _shipment_mode_code(value: Any) -> Any:
    """SHIPMENT_MODE code via enum_codes (old clients send "air" / "sea"); blank -> None. Anything else
    stays as sent and fails the Literal (422)."""
    if isinstance(value, str):
        value = value.strip()
        return enum_codes.normalize(enum_codes.SHIPMENT_MODE, value) if value else None
    return value


# SHIPMENT_MODE code (AIR / SEA); None = not given (legacy rows: unknown)
ShipmentModeCode = Annotated[Optional[Literal["AIR", "SEA"]], BeforeValidator(_shipment_mode_code)]


class CBMCalculationBase(BaseModel):
    title: Optional[str] = Field(default=None, json_schema_extra={"example": "Solar Panels Batch Measurement"})
    shipment_mode: ShipmentModeCode = Field(default=None, json_schema_extra={"example": "SEA"})
    freight_type: Optional[str] = Field(default=None, json_schema_extra={"example": "air_freight"}) # air_freight | courier
    divisor: Optional[float] = Field(default=None, json_schema_extra={"example": 6000.0}) # 6000.0 or 5000.0
    import_file_id: Optional[int] = None
    project_id: Optional[int] = None
    po_id: Optional[int] = None
    notes: Optional[str] = None
    is_stackable: Optional[bool] = Field(default=True, json_schema_extra={"example": True})


class CBMCalculationCreate(CBMCalculationBase):
    items: List[CBMItemCreate] = Field(..., min_length=1)


class CBMCalculationUpdate(BaseModel):
    title: Optional[str] = None
    shipment_mode: ShipmentModeCode = None
    freight_type: Optional[str] = None
    divisor: Optional[float] = None
    import_file_id: Optional[int] = None
    project_id: Optional[int] = None
    po_id: Optional[int] = None
    notes: Optional[str] = None
    is_stackable: Optional[bool] = None
    items: Optional[List[CBMItemCreate]] = None


class CBMCalculationResponse(CBMCalculationBase):
    shipment_mode: Optional[str] = None
    calc_id: int
    calc_code: str
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    total_qty: int
    total_cbm: float
    total_gross_weight_kg: float
    total_volumetric_weight_kg: float
    air_chargeable_weight_kg: float
    recommended_shipping_method: Optional[str] = None
    recommended_container_type: Optional[str] = None
    recommended_container_count: int = 0
    smart_hybrid_containers: Optional[str] = None
    flat_only_containers: Optional[str] = None
    hybrid_savings_count: Optional[int] = 0
    smart_hybrid_containers_count: Optional[int] = None
    flat_only_containers_count: Optional[int] = None
    is_stackable: Optional[bool] = True
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    project_name: Optional[str] = None
    po_number: Optional[str] = None
    items: List[CBMItemResponse] = []

    model_config = ConfigDict(from_attributes=True)


class CBMQuickCalcRequest(BaseModel):
    items: List[CBMItemCreate] = Field(..., min_length=1)
    freight_type: Optional[str] = Field(default="air_freight", json_schema_extra={"example": "air_freight"})
    divisor: Optional[float] = Field(default=None, json_schema_extra={"example": 6000.0})


class CBMQuickCalcResponse(BaseModel):
    total_qty: int
    total_cbm: float
    total_gross_weight_kg: float
    total_volumetric_weight_kg: float
    air_chargeable_weight_kg: float
    # SHIPPING_METHOD code (AIR / LCL / FCL); CONTAINER_TYPE code (C20_ST / C40_ST / C40_HC / LCL), None for air
    recommended_shipping_method: str
    recommended_container_type: Optional[str] = None
    recommended_container_count: int
    # "<n> x C40_HC" (CONTAINER_TYPE code); the counts are also given as numbers
    smart_hybrid_containers: Optional[str] = None
    flat_only_containers: Optional[str] = None
    hybrid_savings_count: Optional[int] = 0
    smart_hybrid_containers_count: Optional[int] = None
    flat_only_containers_count: Optional[int] = None
    freight_type: Optional[str] = None
    divisor: Optional[float] = None
    items: List[dict]


class LinkToPORequest(BaseModel):
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    project_id: Optional[int] = None


class CloneCBMCalculationRequest(BaseModel):
    new_code: Optional[str] = None
    new_title: Optional[str] = None
    copy_items: bool = True
    notes: Optional[str] = None


class AirFreightComparisonRequest(BaseModel):
    packages: Optional[List[Dict[str, Any]]] = None
    length_cm: Optional[float] = None
    width_cm: Optional[float] = None
    height_cm: Optional[float] = None
    gross_weight_kg: Optional[float] = 0.0
    quantity: int = 1
    air_rate_per_kg: Optional[float] = 0.0
    courier_rate_per_kg: Optional[float] = 0.0
    estimated_rate_per_kg: Optional[float] = 0.0


class AirFreightComparisonResponse(BaseModel):
    cbm: float
    gross_weight_kg: float
    air_freight: Dict[str, Any]
    courier: Dict[str, Any]
    chargeable_weight_difference_kg: float
    chargeable_weight_increase_percent: float
    cost_difference: float
    recommendation: Optional[str] = None
