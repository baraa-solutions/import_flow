"""
Pydantic Schemas for Split Shipments & Multi-PO Allocations
"""

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class SplitShipmentAllocationBase(BaseModel):
    parent_bl_number: str = Field(..., description="Master bill of lading number")
    split_bl_number: str = Field(..., description="Target split / partial bill of lading number")
    po_id: Optional[int] = Field(default=None, description="Optional associated PO ID")
    po_item_id: Optional[int] = Field(default=None, description="Associated PO Line Item ID")
    item_sku: str = Field(..., description="Item SKU or material code")
    allocated_quantity: float = Field(..., gt=0.0, description="Allocated quantity in this split B/L")
    total_item_quantity: float = Field(..., gt=0.0, description="Total quantity ordered/received across order")
    currency: str = Field(default="EGP", description="Cost valuation currency")
    notes: Optional[str] = Field(default=None, description="Allocation or splitting notes")


class SplitShipmentAllocationCreate(SplitShipmentAllocationBase):
    shipment_id: int = Field(..., description="Associated import shipment / file ID")
    customs_cost_pool: Optional[float] = Field(default=0.0, ge=0.0, description="Total customs duties pool to prorate")
    freight_cost_pool: Optional[float] = Field(default=0.0, ge=0.0, description="Total freight cost pool to prorate")


class SplitShipmentAllocationUpdate(BaseModel):
    parent_bl_number: Optional[str] = None
    split_bl_number: Optional[str] = None
    po_id: Optional[int] = None
    po_item_id: Optional[int] = None
    item_sku: Optional[str] = None
    allocated_quantity: Optional[float] = Field(default=None, gt=0.0)
    total_item_quantity: Optional[float] = Field(default=None, gt=0.0)
    prorated_customs_cost: Optional[float] = Field(default=None, ge=0.0)
    prorated_freight_cost: Optional[float] = Field(default=None, ge=0.0)
    currency: Optional[str] = None
    notes: Optional[str] = None


class SplitShipmentAllocationOut(SplitShipmentAllocationBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    shipment_id: int
    allocation_ratio: float
    prorated_customs_cost: float
    prorated_freight_cost: float
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    created_by_user_id: Optional[int] = None
    updated_by_user_id: Optional[int] = None


class SplitShipmentAllocationListOut(BaseModel):
    items: List[SplitShipmentAllocationOut]
    total: int
    unique_split_bl_count: int
    total_allocated_quantity: float
    total_prorated_customs: float
    total_prorated_freight: float


class BatchAllocationItem(BaseModel):
    split_bl_number: str
    po_id: Optional[int] = None
    po_item_id: Optional[int] = None
    item_sku: str
    allocated_quantity: float = Field(..., gt=0.0)
    total_item_quantity: float = Field(..., gt=0.0)
    notes: Optional[str] = None


class BatchAllocationCreate(BaseModel):
    parent_bl_number: str
    shipment_id: int
    items: List[BatchAllocationItem]
    customs_cost_pool: float = Field(default=0.0, ge=0.0)
    freight_cost_pool: float = Field(default=0.0, ge=0.0)
    currency: str = Field(default="EGP")


class ProratedCostCalculationRequest(BaseModel):
    shipment_id: int
    customs_cost_pool: float = Field(..., ge=0.0)
    freight_cost_pool: float = Field(..., ge=0.0)
    currency: str = Field(default="EGP")


class ProratedCostItemResult(BaseModel):
    allocation_id: int
    item_sku: str
    split_bl_number: str
    allocated_quantity: float
    allocation_ratio: float
    prorated_customs_cost: float
    prorated_freight_cost: float


class ProratedCostCalculationResponse(BaseModel):
    shipment_id: int
    total_allocations: int
    customs_cost_pool: float
    freight_cost_pool: float
    currency: str
    allocations: List[ProratedCostItemResult]


class UnallocatedPoItemOut(BaseModel):
    po_item_id: int
    po_id: int
    po_number: str
    item_sku: str
    item_name: str
    unit_of_measure: Optional[str] = None
    total_quantity: float
    allocated_quantity: float
    remaining_quantity: float


class UnallocatedPoItemsOut(BaseModel):
    shipment_id: int
    bl_number: Optional[str] = Field(default=None, description="Master B/L of the import file, if recorded")
    items: List[UnallocatedPoItemOut]
    total: int
