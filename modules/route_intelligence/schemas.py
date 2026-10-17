"""
Route & Supplier Intelligence Engine Schemas (AI-ROUTE-006)
"""

from datetime import datetime, date
from typing import List, Optional
from pydantic import BaseModel, Field, ConfigDict


class ItemPriceHistory(BaseModel):
    item_code: str
    description_ar: str
    last_unit_price: float
    previous_unit_price: Optional[float] = None
    price_change_percentage: Optional[float] = None
    price_trend: Optional[str] = None
    currency: str = "USD"
    last_po_date: Optional[date] = None
    last_po_code: Optional[str] = None


class RouteShippingMemory(BaseModel):
    last_ocean_freight_cost: float = 0.0
    freight_currency: str = "USD"
    last_shipping_line: str = "غير محدد"
    last_freight_forwarder: str = "غير محدد"
    last_pol: str = "غير محدد"
    last_pod: str = "غير محدد"
    last_free_days_granted: int = 14
    average_transit_days: int = 0
    last_transit_days: int = 0


class CustomsAndClearanceMemory(BaseModel):
    last_customs_rate_used: float = 0.0
    last_duty_payable_egp: float = 0.0
    last_vat_payable_egp: float = 0.0
    last_clearance_fees_egp: float = 0.0
    last_customs_broker_name: str = "غير محدد"
    last_inspection_agency: str = "غير محدد"
    last_clearance_days: int = 0


class OperationalNoteItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    note_id: int
    note_category: str
    note_text: str
    created_at: datetime
    created_by: str


class RouteOperationalNoteCreate(BaseModel):
    supplier_id: int
    route_name: Optional[str] = None
    note_category: Optional[str] = "General"
    note_text: str = Field(..., min_length=3, description="نص الملاحظة أو التنبيه التشغيلي")


class SupplierRouteIntelligenceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    supplier_id: int
    supplier_code: str
    company_name: str
    country: str
    country_name: Optional[str] = None
    country_code: Optional[str] = None
    total_completed_shipments: int
    items_price_history: List[ItemPriceHistory]
    historical_prices: Optional[List[ItemPriceHistory]] = None
    shipping_memory: RouteShippingMemory
    recent_freight: Optional[dict] = None
    customs_memory: CustomsAndClearanceMemory
    customs_clearance: Optional[dict] = None
    operational_notes: List[OperationalNoteItem]
    last_actual_lead_time_days: int
    average_cycle_days: Optional[int] = None
    lead_time_breakdown_ar: str
    advisory_recommendation_ar: str
    executive_recommendation_ar: Optional[str] = None
    advisory_recommendation_en: Optional[str] = None
    executive_recommendation_en: Optional[str] = None
    advisory_points_ar: Optional[List[str]] = None
    advisory_points_en: Optional[List[str]] = None
