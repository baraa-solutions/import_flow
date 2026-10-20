"""
Customs Clearance Quotations & Price Lists Schemas
"""

from __future__ import annotations

from datetime import datetime, date
from typing import List, Optional, Any
from pydantic import BaseModel, Field, ConfigDict, field_validator


# ─────────────────────────────────────────────────────────────────────────────
# Quotation Items Schemas
# ─────────────────────────────────────────────────────────────────────────────

class CustomsClearanceQuotationCreate(BaseModel):
    provider_id: int
    provider_name: Optional[str] = None
    license_number: Optional[str] = None
    clearance_fee: float = Field(default=0.0, ge=0)
    inland_transport_fee: float = Field(default=0.0, ge=0)
    inspection_fee: float = Field(default=0.0, ge=0)
    port_expenses: float = Field(default=0.0, ge=0)
    miscellaneous_fee: float = Field(default=0.0, ge=0)
    total_cost: Optional[float] = Field(default=None, ge=0)
    currency: str = Field(default="EGP")
    estimated_turnaround_days: int = Field(default=3, ge=1)
    validity_date: Optional[date] = None
    remarks: Optional[str] = None


class CustomsClearanceQuotationUpdate(BaseModel):
    clearance_fee: Optional[float] = Field(default=None, ge=0)
    inland_transport_fee: Optional[float] = Field(default=None, ge=0)
    inspection_fee: Optional[float] = Field(default=None, ge=0)
    port_expenses: Optional[float] = Field(default=None, ge=0)
    miscellaneous_fee: Optional[float] = Field(default=None, ge=0)
    total_cost: Optional[float] = Field(default=None, ge=0)
    currency: Optional[str] = None
    estimated_turnaround_days: Optional[int] = Field(default=None, ge=1)
    validity_date: Optional[date] = None
    remarks: Optional[str] = None


class CustomsClearanceQuotationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    quotation_id: int
    rfq_id: int
    provider_id: int
    provider_name: str
    license_number: Optional[str] = None
    clearance_fee: float
    inland_transport_fee: float
    inspection_fee: float
    port_expenses: float
    miscellaneous_fee: float
    total_cost: float
    currency: str
    estimated_turnaround_days: int
    validity_date: Optional[date] = None
    is_awarded: bool
    remarks: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None
    updated_by: Optional[str] = None


# ─────────────────────────────────────────────────────────────────────────────
# Master RFQ Schemas
# ─────────────────────────────────────────────────────────────────────────────

class CustomsClearanceRFQCreate(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    port_id: Optional[int] = None
    port_name: str
    import_file_id: Optional[int] = None
    project_id: Optional[int] = None
    commodity_description: Optional[str] = None
    hs_code: Optional[str] = None
    shipment_type: str = "Ocean FCL (40HQ)"
    containers_count: int = Field(default=1, ge=1)
    packages_count: int = Field(default=0, ge=0)
    gross_weight_kg: float = Field(default=0.0, ge=0)
    cbm: float = Field(default=0.0, ge=0)
    quotations: Optional[List[CustomsClearanceQuotationCreate]] = None


class CustomsClearanceRFQUpdate(BaseModel):
    title: Optional[str] = None
    port_name: Optional[str] = None
    port_id: Optional[int] = None
    import_file_id: Optional[int] = None
    project_id: Optional[int] = None
    commodity_description: Optional[str] = None
    hs_code: Optional[str] = None
    shipment_type: Optional[str] = None
    containers_count: Optional[int] = Field(default=None, ge=1)
    packages_count: Optional[int] = Field(default=None, ge=0)
    gross_weight_kg: Optional[float] = Field(default=None, ge=0)
    cbm: Optional[float] = Field(default=None, ge=0)
    status: Optional[str] = None


class AwardClearanceQuotationRequest(BaseModel):
    quotation_id: int
    notes: Optional[str] = None


class CustomsClearanceRFQResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    rfq_id: int
    rfq_code: str
    title: str
    port_id: Optional[int] = None
    port_name: str
    import_file_id: Optional[int] = None
    project_id: Optional[int] = None
    commodity_description: Optional[str] = None
    hs_code: Optional[str] = None
    shipment_type: str
    containers_count: int
    packages_count: int
    gross_weight_kg: float
    cbm: float
    status: str
    lowest_clearance_cost: float
    fastest_turnaround_days: int
    awarded_provider_id: Optional[int] = None
    awarded_provider_name: Optional[str] = None
    awarded_quotation_id: Optional[int] = None
    awarded_at: Optional[datetime] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    quotations: List[CustomsClearanceQuotationResponse] = []

    @field_validator("quotations", mode="before")
    def filter_active_quotations(cls, v: Any) -> Any:
        if v is None:
            return []
        if isinstance(v, (list, tuple)):
            return [
                q for q in v
                if (getattr(q, "is_active", True) is not False)
                and (not isinstance(q, dict) or q.get("is_active") is not False)
            ]
        return v


# ─────────────────────────────────────────────────────────────────────────────
# Price List Schemas
# ─────────────────────────────────────────────────────────────────────────────

class ClearancePriceListItemCreate(BaseModel):
    provider_id: int
    provider_name: Optional[str] = None
    port_name: str
    service_category: str = "CLEARANCE_FEE"
    container_type: str = "40HQ"
    unit_price: float = Field(gt=0)
    currency: str = "EGP"
    effective_from: Optional[date] = None
    effective_to: Optional[date] = None
    notes: Optional[str] = None


class ClearancePriceListItemUpdate(BaseModel):
    provider_id: Optional[int] = None
    port_name: Optional[str] = None
    service_category: Optional[str] = None
    container_type: Optional[str] = None
    unit_price: Optional[float] = Field(default=None, gt=0)
    currency: Optional[str] = None
    effective_from: Optional[date] = None
    effective_to: Optional[date] = None
    notes: Optional[str] = None


class ClearancePriceListItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    price_item_id: int
    provider_id: int
    provider_name: str
    port_name: str
    service_category: str
    container_type: str
    unit_price: float
    currency: str
    effective_from: Optional[date] = None
    effective_to: Optional[date] = None
    notes: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
