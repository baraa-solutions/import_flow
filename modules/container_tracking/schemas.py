"""
Pydantic Schemas for Container Tracking & Demurrage Charges
"""

from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ContainerStatus(str, Enum):
    ON_VESSEL = "ON_VESSEL"
    DISCHARGED = "DISCHARGED"
    GATE_OUT_HELD = "GATE_OUT_HELD"
    RETURNED_EMPTY = "RETURNED_EMPTY"
    DAMAGED = "DAMAGED"


# -----------------------------------------------------------------------------
# Demurrage Charge Schemas
# -----------------------------------------------------------------------------

class ContainerDemurrageBase(BaseModel):
    free_time_days: int = Field(default=14, ge=0, description="Allowed free time in days")
    free_time_end_date: Optional[date] = Field(default=None, description="End date of free time")
    daily_demurrage_rate: float = Field(default=0.0, ge=0.0, description="Daily rate after free time")
    actual_return_date: Optional[date] = Field(default=None, description="Actual empty container return date")
    currency: str = Field(default="USD", description="Currency code (USD, EUR, EGP)")
    notes: Optional[str] = Field(default=None, description="Demurrage notes or waiver details")


class ContainerDemurrageCreate(ContainerDemurrageBase):
    pass


class ContainerDemurrageUpdate(BaseModel):
    free_time_days: Optional[int] = Field(default=None, ge=0)
    free_time_end_date: Optional[date] = None
    daily_demurrage_rate: Optional[float] = Field(default=None, ge=0.0)
    actual_return_date: Optional[date] = None
    currency: Optional[str] = None
    notes: Optional[str] = None


class ContainerDemurrageOut(ContainerDemurrageBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    container_id: int
    days_overdue: int
    total_demurrage_amount: float
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    created_by_user_id: Optional[int] = None
    updated_by_user_id: Optional[int] = None


class DemurrageCalculationResult(BaseModel):
    container_id: int
    free_time_days: int
    free_time_end_date: Optional[date]
    effective_return_date: Optional[date]
    days_overdue: int
    daily_demurrage_rate: float
    total_demurrage_amount: float
    currency: str


# -----------------------------------------------------------------------------
# Container Unit Schemas
# -----------------------------------------------------------------------------

class ContainerLifecycleUnitBase(BaseModel):
    container_number: str = Field(..., description="Container ISO standard number (e.g. MSKU1234567)")
    seal_number: Optional[str] = Field(default=None, description="Customs or carrier seal number")
    iso_type: str = Field(default="40HC", description="ISO container type: 20GP, 40GP, 40HC, etc.")
    tare_weight: Optional[float] = Field(default=None, ge=0.0, description="Tare weight in KG")
    payload_weight: Optional[float] = Field(default=None, ge=0.0, description="Payload weight in KG")
    gross_weight: Optional[float] = Field(default=None, ge=0.0, description="Total gross weight in KG")
    vgm_weight: Optional[float] = Field(default=None, ge=0.0, description="Verified Gross Mass in KG")
    discharge_date: Optional[date] = Field(default=None, description="Port discharge date")
    gate_out_held_date: Optional[date] = Field(default=None, description="Gate out release under custody date")
    empty_returned_date: Optional[date] = Field(default=None, description="Empty container return date")
    status: ContainerStatus = Field(default=ContainerStatus.ON_VESSEL, description="Container operational status")
    notes: Optional[str] = Field(default=None, description="Operational notes")


class ContainerLifecycleUnitCreate(ContainerLifecycleUnitBase):
    shipment_id: int = Field(..., description="Associated import file / shipment ID")
    initial_free_time_days: Optional[int] = Field(default=14, ge=0, description="Optional default free time")
    daily_demurrage_rate: Optional[float] = Field(default=0.0, ge=0.0, description="Optional daily rate")
    currency: Optional[str] = Field(default="USD", description="Demurrage currency")


class ContainerLifecycleUnitUpdate(BaseModel):
    container_number: Optional[str] = None
    seal_number: Optional[str] = None
    iso_type: Optional[str] = None
    tare_weight: Optional[float] = Field(default=None, ge=0.0)
    payload_weight: Optional[float] = Field(default=None, ge=0.0)
    gross_weight: Optional[float] = Field(default=None, ge=0.0)
    vgm_weight: Optional[float] = Field(default=None, ge=0.0)
    discharge_date: Optional[date] = None
    gate_out_held_date: Optional[date] = None
    empty_returned_date: Optional[date] = None
    status: Optional[ContainerStatus] = None
    notes: Optional[str] = None


class ContainerLifecycleUnitOut(ContainerLifecycleUnitBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    shipment_id: int
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    created_by_user_id: Optional[int] = None
    updated_by_user_id: Optional[int] = None
    demurrage_charges: List[ContainerDemurrageOut] = []


class ContainerLifecycleUnitListOut(BaseModel):
    items: List[ContainerLifecycleUnitOut]
    total: int
    on_vessel_count: int
    discharged_count: int
    gate_out_held_count: int
    returned_empty_count: int
    damaged_count: int
    total_demurrage_accrued: float
