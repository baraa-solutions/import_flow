"""
Freight Quotations Pydantic Schemas (BP-008)
"""

from datetime import datetime, date
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field

from modules.common.legacy_rows import LegacyRowTolerantModel, read_model


class FreightQuotationItemBase(BaseModel):
    provider_id: int
    provider_name: str
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    currency_code: Optional[str] = None
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


@read_model
class FreightQuotationItemResponse(FreightQuotationItemBase, LegacyRowTolerantModel):
    quotation_id: int
    rfq_id: int
    is_awarded: bool = False
    ocean_freight_cost: Optional[float] = None
    local_charges_cost: Optional[float] = None
    inland_cost: Optional[float] = None
    total_cost: Optional[float] = None
    transit_days: Optional[int] = 0
    free_days_at_pod: Optional[int] = 14

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


@read_model
class FreightRFQRequestResponse(FreightRFQRequestBase, LegacyRowTolerantModel):
    rfq_id: int
    rfq_code: str
    status: str = "Draft"
    selected_quotation_id: Optional[int] = None
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    total_cbm: Optional[float] = None
    total_gross_weight_kg: Optional[float] = None
    chargeable_weight_kg: Optional[float] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    quotations: List[FreightQuotationItemResponse] = []

    # Computed metrics
    total_quotations_count: int = 0
    lowest_freight_cost: Optional[float] = None
    average_freight_cost: Optional[float] = None
    fastest_transit_days: int = 0
    average_transit_days: Optional[float] = None
    awarded_provider_name: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)



# =========================================================================
# AI-BENCH-007: Trade-Lane Forwarder Benchmarking & Ranking Schemas
# =========================================================================

@read_model
class RankedForwarderQuote(LegacyRowTolerantModel):
    rank: int
    quotation_id: int
    provider_id: int
    provider_name: str
    vessel_name: Optional[str] = None
    total_cost: Optional[float] = None
    currency_code: Optional[str] = None
    transit_days: int
    free_days_at_pod: int
    cost_score: Optional[float] = 0.0
    free_days_score: Optional[float] = 0.0
    transit_score: Optional[float] = 0.0
    reliability_score: Optional[float] = 0.0
    composite_score: Optional[float] = None
    cost_saving_vs_average: Optional[float] = None
    key_advantages: List[str]


@read_model
class RFQBenchmarkResponse(LegacyRowTolerantModel):
    model_config = ConfigDict(from_attributes=True)

    rfq_id: int
    rfq_code: str
    title: str
    route: str
    total_quotes_analyzed: int
    average_cost_usd: Optional[float] = None
    top_three_quotes: List[RankedForwarderQuote] = []
    all_ranked_quotes: List[RankedForwarderQuote] = []
    executive_recommendation_ar: str



# =========================================================================
# Smart RFQ Generator Schemas (BP-008 & Operational Standards)
# =========================================================================

class SmartRFQPackageItem(BaseModel):
    length_cm: float = Field(..., gt=0)
    width_cm: float = Field(..., gt=0)
    height_cm: float = Field(..., gt=0)
    quantity: int = Field(1, ge=1)
    gross_weight_kg: float = Field(0.0, ge=0)
    net_weight_kg: Optional[float] = Field(None, ge=0)
    package_type: Optional[str] = "Pallet"


class SmartRFQGenerateRequest(BaseModel):
    import_file_id: Optional[int] = None
    shipment_mode: Optional[str] = None  # Sea FCL, Sea LCL, Air, Courier
    incoterm_code: Optional[str] = None  # EXW, FOB, FCA, CIF...
    pickup_address: Optional[str] = None
    port_of_loading: Optional[str] = None
    port_of_discharge: Optional[str] = None
    cargo_ready_date: Optional[date] = None
    commodity_description: Optional[str] = None
    hs_code: Optional[str] = None
    equipment_type: Optional[str] = None  # e.g. 1x20' GP, 1x40' HC
    container_count: Optional[int] = 1
    is_stackable: Optional[bool] = True
    is_dangerous_goods: Optional[bool] = False
    has_lithium_battery: Optional[bool] = False
    target_free_days: Optional[int] = 21
    avoid_tmt_terminal: Optional[bool] = True
    packages: Optional[List[SmartRFQPackageItem]] = None
    manual_gross_weight_kg: Optional[float] = None
    manual_net_weight_kg: Optional[float] = None
    manual_volume_cbm: Optional[float] = None
    custom_notes: Optional[str] = None


@read_model
class SmartRFQMetrics(LegacyRowTolerantModel):
    shipment_mode: str
    total_packages_count: int = 0
    total_gross_weight_kg: float = 0.0
    total_net_weight_kg: float = 0.0
    total_volume_cbm: float = 0.0
    chargeable_weight_kg: float = 0.0
    volumetric_divisor: Optional[float] = None
    is_volumetric_higher: bool = False
    is_stackable: bool = True
    dead_freight_applied: bool = False
    is_heavy_road_cargo: bool = False
    road_weight_warning: Optional[str] = None
    is_double_stackable: bool = False
    trade_agreement_applicable: Optional[str] = None
    free_days_at_pod: int = 21
    terminal_restriction: Optional[str] = None


@read_model
class SmartRFQResponse(LegacyRowTolerantModel):
    subject: str
    body_text: str
    metrics: SmartRFQMetrics
    warnings: List[str] = []
