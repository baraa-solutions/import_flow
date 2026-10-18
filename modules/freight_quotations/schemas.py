"""
Freight Quotations Pydantic Schemas (BP-008)
"""

from datetime import datetime, date
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field


class FreightQuotationItemBase(BaseModel):
    provider_id: int
    provider_name: str
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    currency_code: str = "USD"
    ocean_freight_cost: float = Field(..., ge=0.0)
    local_charges_cost: float = Field(0.0, ge=0.0)
    inland_cost: float = Field(0.0, ge=0.0)
    total_cost: float = Field(0.0, ge=0.0)
    sailing_date: date
    estimated_arrival_date: date
    transit_days: int = 0
    free_days_at_pod: int = 14
    is_excluded_from_avg: bool = False
    remarks: Optional[str] = None


class FreightQuotationItemCreate(FreightQuotationItemBase):
    quotation_id: Optional[int] = None
    is_awarded: Optional[bool] = None  # Ignored: quotes can only be awarded via /award


class FreightQuotationItemResponse(FreightQuotationItemBase):
    quotation_id: int
    rfq_id: int
    is_awarded: bool = False

    model_config = ConfigDict(from_attributes=True)


class FreightRFQRequestBase(BaseModel):
    title: str = Field(..., min_length=2, max_length=200)
    shipping_method: str = "Ocean FCL"  # Ocean FCL, Ocean LCL, Air Freight, Inland Trucking
    crd_date: date
    pol_id: Optional[int] = None
    pol_name: str
    pod_id: Optional[int] = None
    pod_name: str
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    project_id: Optional[int] = None
    total_cbm: float = 0.0
    total_gross_weight_kg: float = 0.0
    chargeable_weight_kg: float = 0.0
    notes: Optional[str] = None


class FreightRFQRequestCreate(FreightRFQRequestBase):
    status: Optional[str] = None  # Ignored: RFQ always created as Draft
    selected_quotation_id: Optional[int] = None  # Ignored: quotes can only be awarded via /award
    quotations: List[FreightQuotationItemCreate] = []


class FreightRFQRequestUpdate(BaseModel):
    title: Optional[str] = None
    shipping_method: Optional[str] = None
    crd_date: Optional[date] = None
    pol_id: Optional[int] = None
    pol_name: Optional[str] = None
    pod_id: Optional[int] = None
    pod_name: Optional[str] = None
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    project_id: Optional[int] = None
    total_cbm: Optional[float] = None
    total_gross_weight_kg: Optional[float] = None
    chargeable_weight_kg: Optional[float] = None
    notes: Optional[str] = None
    quotations: Optional[List[FreightQuotationItemCreate]] = None


class FreightRFQRequestResponse(FreightRFQRequestBase):
    rfq_id: int
    rfq_code: str
    status: str = "Draft"
    selected_quotation_id: Optional[int] = None
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    quotations: List[FreightQuotationItemResponse] = []

    # Computed metrics
    total_quotations_count: int = 0
    lowest_freight_cost: float = 0.0
    average_freight_cost: float = 0.0
    fastest_transit_days: int = 0
    average_transit_days: float = 0.0
    awarded_provider_name: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)



# =========================================================================
# AI-BENCH-007: Trade-Lane Forwarder Benchmarking & Ranking Schemas
# =========================================================================

class RankedForwarderQuote(BaseModel):
    rank: int
    quotation_id: int
    provider_id: int
    provider_name: str
    vessel_name: Optional[str] = None
    total_cost: float
    currency_code: str = "USD"
    transit_days: int
    free_days_at_pod: int
    cost_score: float = 0.0
    free_days_score: float = 0.0
    transit_score: float = 0.0
    reliability_score: float = 0.0
    composite_score: float
    cost_saving_vs_average: float
    key_advantages: List[str]


class RFQBenchmarkResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    rfq_id: int
    rfq_code: str
    title: str
    route: str
    total_quotes_analyzed: int
    average_cost_usd: float
    top_three_quotes: List[RankedForwarderQuote]
    all_ranked_quotes: List[RankedForwarderQuote]
    executive_recommendation_ar: str

