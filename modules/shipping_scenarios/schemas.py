from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ShippingScenarioItemBase(BaseModel):
    provider_id: Optional[int] = None
    provider_name: str = Field(..., min_length=2, max_length=150)
    customs_broker_id: Optional[int] = None
    customs_broker_name: Optional[str] = None
    vessel_name: str = Field(..., min_length=2, max_length=150)
    voyage_number: Optional[str] = None
    port_of_loading_id: Optional[int] = None
    port_of_discharge_id: Optional[int] = None
    pol_name: Optional[str] = None
    pod_name: Optional[str] = None
    sailing_date: date
    estimated_arrival_date: date
    expected_line_delay_days: int = Field(0, ge=0)
    is_excluded_from_average: bool = False
    is_recommended: bool = False
    is_selected: bool = False
    risk_level: str = "Low"
    notes: Optional[str] = None

    # Quotation fields
    free_time_days: int = 14
    quotation_currency: Optional[str] = None
    total_quotation_amount: float = 0.0

    container_40ft_applicable: bool = False
    container_40ft_price: float = 0.0
    container_40ft_currency: Optional[str] = None
    container_40ft_qty: int = 0

    container_20ft_applicable: bool = False
    container_20ft_price: float = 0.0
    container_20ft_currency: Optional[str] = None
    container_20ft_qty: int = 0

    lcl_cbm_applicable: bool = False
    lcl_cbm_price: float = 0.0
    lcl_cbm_currency: Optional[str] = None
    lcl_cbm_qty: float = 0.0

    express_courier_applicable: bool = False
    express_courier_price: float = 0.0
    express_courier_currency: Optional[str] = None

    eur_atr_applicable: bool = False
    eur_atr_price: float = 0.0
    eur_atr_currency: Optional[str] = None

    solas_vgm_applicable: bool = False
    solas_vgm_price: float = 0.0
    solas_vgm_currency: Optional[str] = None

    vgm_notification_applicable: bool = False
    vgm_notification_price: float = 0.0
    vgm_notification_currency: Optional[str] = None

    telex_release_applicable: bool = False
    telex_release_price: float = 0.0
    telex_release_currency: Optional[str] = None

    insurance_applicable: bool = False
    insurance_price: float = 0.0
    insurance_currency: Optional[str] = None

    booking_cancellation_applicable: bool = False
    booking_cancellation_price: float = 0.0
    booking_cancellation_currency: Optional[str] = None

    ics2_filing_fee_applicable: bool = False
    ics2_filing_fee_price: float = 0.0
    ics2_filing_fee_currency: Optional[str] = None

    others_fee_applicable: bool = False
    others_fee_price: float = 0.0
    others_fee_currency: Optional[str] = None

    document_fees_applicable: bool = False
    document_fees_price: float = 0.0
    document_fees_currency: Optional[str] = None

    waiver_letter_fee_applicable: bool = False
    waiver_letter_fee_price: float = 0.0
    waiver_letter_fee_currency: Optional[str] = None

    dthc_applicable: bool = False
    dthc_price: float = 0.0
    dthc_currency: Optional[str] = None

    storage_per_week_applicable: bool = False
    storage_per_week_price: float = 0.0
    storage_per_week_currency: Optional[str] = None

    extra_day_storage_applicable: bool = False
    extra_day_storage_price: float = 0.0
    extra_day_storage_currency: Optional[str] = None

    # Customs clearance quotation integration fields
    clearance_fee_applicable: bool = False
    clearance_fee_price: float = 0.0
    clearance_fee_currency: Optional[str] = None

    inspection_fee_applicable: bool = False
    inspection_fee_price: float = 0.0
    inspection_fee_currency: Optional[str] = None

    inland_transport_fee_applicable: bool = False
    inland_transport_fee_price: float = 0.0
    inland_transport_fee_currency: Optional[str] = None

    port_expenses_applicable: bool = False
    port_expenses_price: float = 0.0
    port_expenses_currency: Optional[str] = None


class ShippingScenarioItemCreate(ShippingScenarioItemBase):
    item_id: Optional[int] = None

    free_time_days: int = Field(14, ge=0)
    total_quotation_amount: float = Field(0.0, ge=0)

    container_40ft_price: float = Field(0.0, ge=0)
    container_40ft_qty: int = Field(0, ge=0)

    container_20ft_price: float = Field(0.0, ge=0)
    container_20ft_qty: int = Field(0, ge=0)

    lcl_cbm_price: float = Field(0.0, ge=0)
    lcl_cbm_qty: float = Field(0.0, ge=0)

    express_courier_price: float = Field(0.0, ge=0)
    eur_atr_price: float = Field(0.0, ge=0)
    solas_vgm_price: float = Field(0.0, ge=0)
    vgm_notification_price: float = Field(0.0, ge=0)
    telex_release_price: float = Field(0.0, ge=0)
    insurance_price: float = Field(0.0, ge=0)
    booking_cancellation_price: float = Field(0.0, ge=0)
    ics2_filing_fee_price: float = Field(0.0, ge=0)
    others_fee_price: float = Field(0.0, ge=0)
    document_fees_price: float = Field(0.0, ge=0)
    waiver_letter_fee_price: float = Field(0.0, ge=0)
    dthc_price: float = Field(0.0, ge=0)
    storage_per_week_price: float = Field(0.0, ge=0)
    extra_day_storage_price: float = Field(0.0, ge=0)

    clearance_fee_price: float = Field(0.0, ge=0)
    inspection_fee_price: float = Field(0.0, ge=0)
    inland_transport_fee_price: float = Field(0.0, ge=0)
    port_expenses_price: float = Field(0.0, ge=0)


# Every stored scenario field (create payload == model columns besides ids): used for create, update,
# clone and the response so the ~90-field mapping is written once.
SCENARIO_ITEM_FIELDS = tuple(f for f in ShippingScenarioItemCreate.model_fields if f != "item_id")


class ShippingScenarioItemUpdate(BaseModel):
    provider_id: Optional[int] = None
    provider_name: Optional[str] = None
    customs_broker_id: Optional[int] = None
    customs_broker_name: Optional[str] = None
    vessel_name: Optional[str] = None
    voyage_number: Optional[str] = None
    port_of_loading_id: Optional[int] = None
    port_of_discharge_id: Optional[int] = None
    pol_name: Optional[str] = None
    pod_name: Optional[str] = None
    sailing_date: Optional[date] = None
    estimated_arrival_date: Optional[date] = None
    expected_line_delay_days: Optional[int] = None
    is_excluded_from_average: Optional[bool] = None
    is_recommended: Optional[bool] = None
    is_selected: Optional[bool] = None
    risk_level: Optional[str] = None
    notes: Optional[str] = None

    free_time_days: Optional[int] = None
    quotation_currency: Optional[str] = None
    total_quotation_amount: Optional[float] = None

    container_40ft_applicable: Optional[bool] = None
    container_40ft_price: Optional[float] = None
    container_40ft_currency: Optional[str] = None
    container_40ft_qty: Optional[int] = None

    container_20ft_applicable: Optional[bool] = None
    container_20ft_price: Optional[float] = None
    container_20ft_currency: Optional[str] = None
    container_20ft_qty: Optional[int] = None

    lcl_cbm_applicable: Optional[bool] = None
    lcl_cbm_price: Optional[float] = None
    lcl_cbm_currency: Optional[str] = None
    lcl_cbm_qty: Optional[float] = None

    express_courier_applicable: Optional[bool] = None
    express_courier_price: Optional[float] = None
    express_courier_currency: Optional[str] = None

    eur_atr_applicable: Optional[bool] = None
    eur_atr_price: Optional[float] = None
    eur_atr_currency: Optional[str] = None

    solas_vgm_applicable: Optional[bool] = None
    solas_vgm_price: Optional[float] = None
    solas_vgm_currency: Optional[str] = None

    vgm_notification_applicable: Optional[bool] = None
    vgm_notification_price: Optional[float] = None
    vgm_notification_currency: Optional[str] = None

    telex_release_applicable: Optional[bool] = None
    telex_release_price: Optional[float] = None
    telex_release_currency: Optional[str] = None

    insurance_applicable: Optional[bool] = None
    insurance_price: Optional[float] = None
    insurance_currency: Optional[str] = None

    booking_cancellation_applicable: Optional[bool] = None
    booking_cancellation_price: Optional[float] = None
    booking_cancellation_currency: Optional[str] = None

    ics2_filing_fee_applicable: Optional[bool] = None
    ics2_filing_fee_price: Optional[float] = None
    ics2_filing_fee_currency: Optional[str] = None

    others_fee_applicable: Optional[bool] = None
    others_fee_price: Optional[float] = None
    others_fee_currency: Optional[str] = None

    document_fees_applicable: Optional[bool] = None
    document_fees_price: Optional[float] = None
    document_fees_currency: Optional[str] = None

    waiver_letter_fee_applicable: Optional[bool] = None
    waiver_letter_fee_price: Optional[float] = None
    waiver_letter_fee_currency: Optional[str] = None

    dthc_applicable: Optional[bool] = None
    dthc_price: Optional[float] = None
    dthc_currency: Optional[str] = None

    storage_per_week_applicable: Optional[bool] = None
    storage_per_week_price: Optional[float] = None
    storage_per_week_currency: Optional[str] = None

    extra_day_storage_applicable: Optional[bool] = None
    extra_day_storage_price: Optional[float] = None
    extra_day_storage_currency: Optional[str] = None

    clearance_fee_applicable: Optional[bool] = None
    clearance_fee_price: Optional[float] = None
    clearance_fee_currency: Optional[str] = None

    inspection_fee_applicable: Optional[bool] = None
    inspection_fee_price: Optional[float] = None
    inspection_fee_currency: Optional[str] = None

    inland_transport_fee_applicable: Optional[bool] = None
    inland_transport_fee_price: Optional[float] = None
    inland_transport_fee_currency: Optional[str] = None

    port_expenses_applicable: Optional[bool] = None
    port_expenses_price: Optional[float] = None
    port_expenses_currency: Optional[str] = None



class ShippingScenarioItemCalculated(ShippingScenarioItemBase):
    item_id: Optional[int] = None
    vessel_lead_time_days: int
    ready_for_shipping_days: int
    expected_total_days_to_warehouse: int
    expected_warehouse_arrival_date: date

    model_config = ConfigDict(from_attributes=True)


class ShippingEvaluationBase(BaseModel):
    title: Optional[str] = None
    cargo_ready_date: date
    pick_up_address: Optional[str] = None
    port_of_loading_id: Optional[int] = None
    port_of_discharge_id: Optional[int] = None
    avg_form4_days: int = Field(5, ge=0)
    avg_clearance_days: int = Field(7, ge=0)
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    project_id: Optional[int] = None
    notes: Optional[str] = None


class ShippingEvaluationCreate(ShippingEvaluationBase):
    items: List[ShippingScenarioItemCreate] = Field(default_factory=list)


class ShippingEvaluationUpdate(BaseModel):
    title: Optional[str] = None
    cargo_ready_date: Optional[date] = None
    pick_up_address: Optional[str] = None
    port_of_loading_id: Optional[int] = None
    port_of_discharge_id: Optional[int] = None
    avg_form4_days: Optional[int] = None
    avg_clearance_days: Optional[int] = None
    import_file_id: Optional[int] = None
    po_id: Optional[int] = None
    project_id: Optional[int] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None
    items: Optional[List[ShippingScenarioItemCreate]] = None


class ShippingEvaluationResponse(ShippingEvaluationBase):
    session_id: int
    created_by: Optional[str] = None
    updated_by: Optional[str] = None
    session_code: str
    import_file_id: Optional[int] = None
    import_file_code: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    po_number: Optional[str] = None
    project_name: Optional[str] = None
    pol_name: Optional[str] = None
    pod_name: Optional[str] = None

    items: List[ShippingScenarioItemCalculated] = Field(default_factory=list)

    # Calculated summary metrics across all valid non-excluded scenarios
    avg_expected_transit_days: float = 0.0
    avg_expected_warehouse_arrival_date: Optional[date] = None
    earliest_arrival_scenario_provider: Optional[str] = None
    earliest_arrival_date: Optional[date] = None
    latest_arrival_scenario_provider: Optional[str] = None
    latest_arrival_date: Optional[date] = None
    recommended_scenario_provider: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class CloneShippingEvaluationRequest(BaseModel):
    new_title: Optional[str] = None
    cargo_ready_date: Optional[date] = None
    unlink_import_file: bool = True
    unlink_po: bool = True
    copy_carrier_options: bool = True
    remarks: Optional[str] = None
    target_import_file_id: Optional[int] = None
