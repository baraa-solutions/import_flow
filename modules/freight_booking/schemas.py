from datetime import datetime, date
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

from modules.common.legacy_rows import LegacyRowTolerantModel, read_model


class ContainerAllocationItem(BaseModel):
    container_type: str = Field(..., description="e.g. 20GP, 40HC, 45HC")
    quantity: int = Field(default=1, ge=1)
    container_numbers: Optional[List[str]] = Field(default_factory=list)
    seal_numbers: Optional[List[str]] = Field(default_factory=list)
    vgm_weight_kg: Optional[float] = Field(default=0.0)


class BookingChargeItem(BaseModel):
    charge_type: str = Field(..., description="e.g. Sea Freight, THC, VGM Fee, BL Fee, EUR1")
    unit: str = Field(default="Per Container", description="Per Container or Per Shipment")
    quantity: float = Field(default=1.0, gt=0.0)
    container_type: Optional[str] = Field(default=None, description="e.g. 20GP, 40HC, 45HC")
    currency: str = Field(default="USD")
    rate: float = Field(default=0.0, ge=0.0)
    total: float = Field(default=0.0, ge=0.0)
    fx_rate_to_usd: Optional[float] = None
    amount_usd: Optional[float] = None
    charge_category: Optional[str] = Field(
        default=None,
        description="FREIGHT, ORIGIN_LOCAL, DESTINATION_LOCAL, INSURANCE, STORAGE, OTHER",
    )


class ShipmentBookingBase(BaseModel):
    booking_confirmation_no: Optional[str] = None
    bill_of_lading_no: Optional[str] = None
    import_file_id: Optional[int] = None
    rfq_request_id: Optional[int] = None
    scenario_session_id: Optional[int] = None
    scenario_item_id: Optional[int] = None
    scenario_provider_name: Optional[str] = None
    freight_forwarder_id: Optional[int] = None
    freight_forwarder_name: Optional[str] = None
    shipping_line_id: Optional[int] = None
    shipping_line_name: Optional[str] = None
    shipment_type: str = "Ocean FCL"
    pol_location_id: Optional[int] = None
    pol_name: Optional[str] = None
    pod_location_id: Optional[int] = None
    pod_name: Optional[str] = None
    etd: Optional[datetime] = None
    eta: Optional[datetime] = None
    atd: Optional[datetime] = None
    shipped_on_board_date: Optional[date] = None
    departure_delay_days: Optional[int] = 0
    expected_warehouse_days: Optional[int] = 7
    expected_warehouse_arrival_date: Optional[datetime] = None
    free_demurrage_days: Optional[int] = Field(None, ge=0)
    cargo_cutoff_date: Optional[datetime] = None
    si_cutoff_date: Optional[datetime] = None
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    container_release_order_no: Optional[str] = None
    freight_terms: str = "Collect"
    container_mismatch_reason: Optional[str] = None
    containers_data: List[ContainerAllocationItem] = Field(default_factory=list)
    cost_charges_data: List[BookingChargeItem] = Field(default_factory=list)
    quotation_details_data: Optional[dict] = Field(default_factory=dict)
    original_freight_cost_usd: float = 0.0
    cost_savings_usd: float = 0.0
    cost_variance_usd: float = 0.0
    savings_notes: Optional[str] = None
    status: str = "Draft"
    owner: Optional[str] = Field(None, description="Defaults to the logged-in user when not sent")
    notes: Optional[str] = None


class ShipmentBookingCreate(ShipmentBookingBase):
    pass


class ShipmentBookingUpdate(BaseModel):
    import_file_id: Optional[int] = None
    booking_confirmation_no: Optional[str] = None
    bill_of_lading_no: Optional[str] = None
    scenario_session_id: Optional[int] = None
    scenario_item_id: Optional[int] = None
    scenario_provider_name: Optional[str] = None
    freight_forwarder_name: Optional[str] = None
    shipping_line_name: Optional[str] = None
    shipment_type: Optional[str] = None
    pol_name: Optional[str] = None
    pod_name: Optional[str] = None
    etd: Optional[datetime] = None
    eta: Optional[datetime] = None
    atd: Optional[datetime] = None
    shipped_on_board_date: Optional[date] = None
    departure_delay_days: Optional[int] = None
    expected_warehouse_days: Optional[int] = None
    expected_warehouse_arrival_date: Optional[datetime] = None
    free_demurrage_days: Optional[int] = Field(None, ge=0)
    cargo_cutoff_date: Optional[datetime] = None
    si_cutoff_date: Optional[datetime] = None
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    container_release_order_no: Optional[str] = None
    freight_terms: Optional[str] = None
    container_mismatch_reason: Optional[str] = None
    containers_data: Optional[List[ContainerAllocationItem]] = None
    cost_charges_data: Optional[List[BookingChargeItem]] = None
    quotation_details_data: Optional[dict] = None
    original_freight_cost_usd: Optional[float] = None
    cost_savings_usd: Optional[float] = None
    cost_variance_usd: Optional[float] = None
    savings_notes: Optional[str] = None
    status: Optional[str] = None
    owner: Optional[str] = None
    notes: Optional[str] = None


class ShipmentBookingConfirm(BaseModel):
    booking_confirmation_no: str = Field(..., description="Carrier Booking Confirmation Number (e.g. MSC-CN-9900)")
    vessel_name: Optional[str] = Field(None, description="Vessel Name (e.g. MSC OSCAR)")
    voyage_number: Optional[str] = Field(None, description="Voyage Number (e.g. 2608W)")
    etd: Optional[datetime] = None
    eta: Optional[datetime] = None
    free_demurrage_days: Optional[int] = Field(None, ge=0, description="Agreed Free Demurrage Days")
    notes: Optional[str] = None


class ShipmentDepartureConfirm(BaseModel):
    actual_departure_date: datetime = Field(..., description="تاريخ الإبحار الفعلي (ATD)")
    bill_of_lading_no: str = Field(..., min_length=3, max_length=100, description="رقم بوليصة الشحن (B/L Number)")
    revised_eta: Optional[datetime] = Field(None, description="موعد الوصول المتوقع المحدث (Revised ETA)")
    vessel_name: Optional[str] = Field(None, description="اسم الباخرة")
    voyage_number: Optional[str] = Field(None, description="رقم الرحلة")
    shipped_on_board_date: Optional[date] = Field(None, description="تاريخ الشحن على ظهر السفينة (Shipped On Board Date)")
    notes: Optional[str] = Field(None, description="ملاحظات الإبحار والرحلة")


@read_model
class ShipmentBookingResponse(LegacyRowTolerantModel, ShipmentBookingBase):
    # free_demurrage_days is a nullable column an update may clear (PUT {"free_demurrage_days": null}).
    free_demurrage_days: Optional[int] = None
    booking_id: int
    booking_code: str
    booking_request_date: Optional[datetime] = None
    booking_confirmation_date: Optional[datetime] = None
    transit_time_days: int = 0
    # Amounts: a legacy NULL stays None (never a fabricated 0.0).
    total_freight_cost_usd: Optional[float] = 0.0
    original_freight_cost_usd: Optional[float] = 0.0
    cost_savings_usd: Optional[float] = 0.0
    cost_variance_usd: Optional[float] = 0.0
    savings_notes: Optional[str] = None
    is_active: bool = True
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
