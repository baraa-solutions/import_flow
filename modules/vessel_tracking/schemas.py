from datetime import datetime
from typing import List, Optional, Any
from pydantic import BaseModel, ConfigDict, Field


class VesselBase(BaseModel):
    vessel_name: str = Field(..., max_length=150)
    imo_number: Optional[str] = Field(None, max_length=20)
    mmsi_number: Optional[str] = Field(None, max_length=20)
    call_sign: Optional[str] = Field(None, max_length=30)
    flag_country: str = Field(default="Panama", max_length=50)
    vessel_type: str = Field(default="Container Ship", max_length=50)
    built_year: Optional[int] = None
    capacity_teu: Optional[int] = None
    shipping_line_name: Optional[str] = Field(None, max_length=150)
    notes: Optional[str] = None


class VesselCreate(VesselBase):
    pass


class VesselResponse(VesselBase):
    vessel_id: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class VesselPositionBase(BaseModel):
    latitude: float
    longitude: float
    speed_knots: float = 14.5
    course_degrees: float = 0.0
    heading_degrees: float = 0.0
    nav_status: str = "Underway Using Engine"
    current_zone: str = "Open Sea"
    destination_port_code: Optional[str] = None
    distance_remaining_nm: Optional[float] = None
    eta_predicted: Optional[datetime] = None
    source: str = "AIS_LIVE"


class VesselPositionCreate(VesselPositionBase):
    vessel_id: int
    timestamp: Optional[datetime] = None


class VesselPositionResponse(VesselPositionBase):
    position_id: int
    vessel_id: int
    timestamp: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class WaypointPoint(BaseModel):
    name: str
    latitude: float
    longitude: float
    passed: bool = False
    estimated_pass_at: Optional[datetime] = None


class ShipmentTrackingCreate(BaseModel):
    import_file_id: int
    booking_id: Optional[int] = None
    vessel_id: int
    voyage_number: Optional[str] = None
    pol_port_code: str
    pol_port_name: str
    pod_port_code: str
    pod_port_name: str
    scheduled_departure: Optional[datetime] = None
    actual_departure: Optional[datetime] = None
    scheduled_arrival: Optional[datetime] = None
    estimated_arrival: Optional[datetime] = None
    tracking_milestone: str = "In Transit"
    route_waypoints: List[dict] = Field(default_factory=list)
    notes: Optional[str] = None


class ShipmentTrackingResponse(BaseModel):
    tracking_id: int
    tracking_code: str
    import_file_id: int
    booking_id: Optional[int]
    vessel_id: int
    voyage_number: Optional[str]
    pol_port_code: str
    pol_port_name: str
    pod_port_code: str
    pod_port_name: str
    scheduled_departure: Optional[datetime]
    actual_departure: Optional[datetime]
    scheduled_arrival: Optional[datetime]
    estimated_arrival: Optional[datetime]
    actual_arrival: Optional[datetime]
    tracking_milestone: str
    voyage_progress_pct: float
    delay_hours: float
    delay_severity: str
    last_polled_at: datetime
    route_waypoints: List[Any]
    notes: Optional[str]
    is_active: bool
    created_at: datetime

    # Expanded Vessel and Latest Position Details
    vessel_name: Optional[str] = None
    vessel_imo: Optional[str] = None
    shipping_line_name: Optional[str] = None
    current_latitude: Optional[float] = None
    current_longitude: Optional[float] = None
    current_speed_knots: Optional[float] = None
    current_course_degrees: Optional[float] = None
    current_nav_status: Optional[str] = None
    current_zone: Optional[str] = None
    distance_remaining_nm: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)


class LiveRadarOverviewResponse(BaseModel):
    total_active_shipments: int
    underway_count: int
    approaching_port_count: int
    in_port_count: int
    delayed_count: int
    on_time_count: int
    shipments: List[ShipmentTrackingResponse]


class VesselArrivalConfirmRequest(BaseModel):
    actual_arrival_date: Optional[datetime] = None
    notes: Optional[str] = None
