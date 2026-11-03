"""
Master Items Schemas (MD-ITEM-001)
Pydantic v2 schemas for Item Master Data, Supplier Linkages, and Price History.
"""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


# ==================================================
# 1. Master Item Schemas
# ==================================================

class MasterItemBase(BaseModel):
    item_code: str = Field(..., max_length=100, description="Unique internal item code")
    description_ar: str = Field(..., max_length=500, description="Arabic item description")
    description_en: Optional[str] = Field(None, max_length=500, description="English item description")
    tariff_id: Optional[int] = Field(None, description="Linked customs tariff ID")
    default_uom: Optional[str] = Field("PCS", max_length=30, description="Default unit of measure")
    default_pkg_type: Optional[str] = Field("Carton", max_length=50, description="Default package type")
    cbm_per_unit: Optional[float] = Field(0.0, ge=0.0, description="Volume per unit in CBM")
    gross_weight_kg: Optional[float] = Field(0.0, ge=0.0, description="Gross weight per unit in KG")
    net_weight_kg: Optional[float] = Field(0.0, ge=0.0, description="Net weight per unit in KG")
    product_category: Optional[str] = Field(None, max_length=100, description="Category")
    product_subcategory: Optional[str] = Field(None, max_length=100, description="Subcategory")
    notes: Optional[str] = Field(None, description="General operational notes")


class MasterItemCreate(MasterItemBase):
    pass


class MasterItemUpdate(BaseModel):
    item_code: Optional[str] = Field(None, max_length=100)
    description_ar: Optional[str] = Field(None, max_length=500)
    description_en: Optional[str] = Field(None, max_length=500)
    tariff_id: Optional[int] = None
    default_uom: Optional[str] = Field(None, max_length=30)
    default_pkg_type: Optional[str] = Field(None, max_length=50)
    cbm_per_unit: Optional[float] = Field(None, ge=0.0)
    gross_weight_kg: Optional[float] = Field(None, ge=0.0)
    net_weight_kg: Optional[float] = Field(None, ge=0.0)
    product_category: Optional[str] = Field(None, max_length=100)
    product_subcategory: Optional[str] = Field(None, max_length=100)
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class MasterItemResponse(MasterItemBase):
    model_config = ConfigDict(from_attributes=True)

    item_id: int
    last_customs_duty_pct: Optional[float] = None
    last_vat_pct: Optional[float] = None
    last_schedule_tax_pct: Optional[float] = None
    hs_code: Optional[str] = None
    is_active: bool
    created_at: datetime
    created_by: Optional[str] = None
    updated_at: Optional[datetime] = None
    updated_by: Optional[str] = None


class MasterItemListResponse(BaseModel):
    total: int
    items: List[MasterItemResponse]


# ==================================================
# 2. Supplier Catalog Schemas
# ==================================================

class ItemSupplierCatalogBase(BaseModel):
    item_id: int
    supplier_id: int
    supplier_item_code: Optional[str] = Field(None, max_length=100)
    supplier_description: Optional[str] = Field(None, max_length=500)
    last_confirmed_price: Optional[float] = Field(None, ge=0.0)
    last_confirmed_currency: Optional[str] = Field("USD", max_length=10)
    last_confirmed_date: Optional[str] = None
    last_po_id: Optional[int] = None
    min_order_qty: Optional[float] = Field(None, ge=0.0)
    lead_time_days: Optional[int] = Field(None, ge=0)
    preferred_incoterm: Optional[str] = Field(None, max_length=10)
    is_preferred_supplier: bool = False
    notes: Optional[str] = None


class ItemSupplierCatalogCreate(ItemSupplierCatalogBase):
    pass


class ItemSupplierCatalogUpdate(BaseModel):
    supplier_item_code: Optional[str] = Field(None, max_length=100)
    supplier_description: Optional[str] = Field(None, max_length=500)
    last_confirmed_price: Optional[float] = Field(None, ge=0.0)
    last_confirmed_currency: Optional[str] = Field(None, max_length=10)
    last_confirmed_date: Optional[str] = None
    last_po_id: Optional[int] = None
    min_order_qty: Optional[float] = Field(None, ge=0.0)
    lead_time_days: Optional[int] = Field(None, ge=0)
    preferred_incoterm: Optional[str] = Field(None, max_length=10)
    is_preferred_supplier: Optional[bool] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class ItemSupplierCatalogResponse(ItemSupplierCatalogBase):
    model_config = ConfigDict(from_attributes=True)

    catalog_id: int
    supplier_name: Optional[str] = None
    item_code: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime] = None


# ==================================================
# 3. Price History & Analysis Schemas
# ==================================================

class ItemPriceHistoryCreate(BaseModel):
    item_id: int
    supplier_id: Optional[int] = None
    po_id: Optional[int] = None
    import_file_id: Optional[int] = None
    unit_price_fx: float
    currency: str = "USD"
    exchange_rate: Optional[float] = 1.0
    unit_price_egp: Optional[float] = None
    landed_cost_egp: Optional[float] = None
    landed_cost_markup: Optional[float] = None
    quantity: Optional[float] = None
    po_date: Optional[str] = None


class ItemPriceHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    history_id: int
    item_id: int
    supplier_id: Optional[int] = None
    supplier_name: Optional[str] = None
    po_id: Optional[int] = None
    po_number: Optional[str] = None
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    unit_price_fx: float
    currency: str
    exchange_rate: Optional[float] = 1.0
    unit_price_egp: Optional[float] = None
    landed_cost_egp: Optional[float] = None
    landed_cost_markup: Optional[float] = None
    quantity: Optional[float] = None
    po_date: Optional[str] = None
    recorded_at: datetime


class ItemPriceTrendResponse(BaseModel):
    item_id: int
    item_code: str
    description_ar: str
    total_purchases_count: int
    average_unit_price_fx: float
    min_unit_price_fx: float
    max_unit_price_fx: float
    average_landed_cost_egp: Optional[float] = None
    average_markup_percent: Optional[float] = None
    history: List[ItemPriceHistoryResponse]
