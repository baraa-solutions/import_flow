"""
Pydantic Schemas for Multimodal Freight Details
"""

from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class TransportMode(str, Enum):
    AIR = "AIR"
    LCL = "LCL"
    RORO = "RORO"
    BULK = "BULK"


class MultimodalFreightBase(BaseModel):
    transport_mode: TransportMode = Field(default=TransportMode.AIR, description="Mode of transport")

    # Air Freight
    awb_number: Optional[str] = Field(default=None, description="Air Waybill number")
    airline_code: Optional[str] = Field(default=None, description="IATA airline code (e.g. MS, EK, QR)")
    flight_number: Optional[str] = Field(default=None, description="Flight number")
    terminal_handling_charges: Optional[float] = Field(default=0.0, ge=0.0, description="Airport terminal charges (THC)")

    # LCL
    lcl_cbm: Optional[float] = Field(default=0.0, ge=0.0, description="Cargo volume in Cubic Meters")
    lcl_rate_per_cbm: Optional[float] = Field(default=0.0, ge=0.0, description="Freight rate per CBM")
    lcl_cfs_fee: Optional[float] = Field(default=0.0, ge=0.0, description="Container Freight Station (CFS) fee")

    # Ro-Ro
    roro_vehicle_type: Optional[str] = Field(default=None, description="Type of vehicle or machinery")
    roro_dimensions_cbm: Optional[float] = Field(default=0.0, ge=0.0, description="Vehicle dimensions in CBM")

    # Bulk
    bulk_cargo_type: Optional[str] = Field(default=None, description="Bulk commodity type (Grain, Fertilizer, Ore)")
    bulk_tonnage: Optional[float] = Field(default=0.0, ge=0.0, description="Total metric tons")
    special_handling_notes: Optional[str] = Field(default=None, description="Special storage or handling requirements")


class MultimodalFreightCreate(MultimodalFreightBase):
    shipment_id: int = Field(..., description="Import shipment / file ID")


class MultimodalFreightUpdate(BaseModel):
    transport_mode: Optional[TransportMode] = None
    awb_number: Optional[str] = None
    airline_code: Optional[str] = None
    flight_number: Optional[str] = None
    terminal_handling_charges: Optional[float] = Field(default=None, ge=0.0)

    lcl_cbm: Optional[float] = Field(default=None, ge=0.0)
    lcl_rate_per_cbm: Optional[float] = Field(default=None, ge=0.0)
    lcl_cfs_fee: Optional[float] = Field(default=None, ge=0.0)

    roro_vehicle_type: Optional[str] = None
    roro_dimensions_cbm: Optional[float] = Field(default=None, ge=0.0)

    bulk_cargo_type: Optional[str] = None
    bulk_tonnage: Optional[float] = Field(default=None, ge=0.0)
    special_handling_notes: Optional[str] = None


class MultimodalFreightOut(MultimodalFreightBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    shipment_id: int
    calculated_subtotal: float = 0.0
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    created_by_user_id: Optional[int] = None
    updated_by_user_id: Optional[int] = None


class MultimodalFreightListOut(BaseModel):
    items: List[MultimodalFreightOut]
    total: int
    air_count: int
    lcl_count: int
    roro_count: int
    bulk_count: int
    total_estimated_charges: float


class ModeCostCalculationResult(BaseModel):
    details_id: int
    shipment_id: int
    transport_mode: str
    calculated_freight_subtotal: float
    breakdown: dict
