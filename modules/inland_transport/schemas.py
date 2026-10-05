from typing import Optional, List
from datetime import datetime, timezone
from pydantic import BaseModel, ConfigDict, Field

class InlandTransportBookingBase(BaseModel):
    import_file_id: int
    waybill_number: str = Field(..., min_length=2, description="رقم بوليصة الشحن البري أو إذن التحميل")
    booking_date: Optional[datetime] = None
    carrier_id: Optional[int] = None
    carrier_name: str = Field(..., min_length=2, description="اسم شركة النقل البري أو المقاول")
    truck_plate_number: str = Field(..., min_length=2, description="رقم لوحة الشاحنة")
    truck_type: str = Field("FLATBED", description="TRUCK_TYPE code (legacy labels are normalized)")
    driver_name: str = Field(..., min_length=2, description="اسم السائق")
    driver_phone: str = Field(..., min_length=5, description="رقم هاتف السائق")
    driver_national_id: Optional[str] = None
    container_numbers: Optional[str] = None
    pickup_port_location: str = Field(..., min_length=2, description="موقع التحميل / الميناء")
    destination_warehouse: str = Field("Main Warehouse - Cairo", description="مستودع الوجهة والتفريغ")
    planned_departure_at: datetime
    actual_departure_at: Optional[datetime] = None
    expected_arrival_at: datetime
    actual_arrival_at: Optional[datetime] = None
    transport_fare_egp: float = Field(default=0.0, ge=0.0)
    status: str = Field("Booking Confirmed", description="حالة النقل")
    tracking_notes: Optional[str] = None

class InlandTransportBookingCreate(InlandTransportBookingBase):
    pass

class InlandTransportBookingUpdate(BaseModel):
    waybill_number: Optional[str] = None
    carrier_id: Optional[int] = None
    carrier_name: Optional[str] = None
    truck_plate_number: Optional[str] = None
    truck_type: Optional[str] = None
    driver_name: Optional[str] = None
    driver_phone: Optional[str] = None
    driver_national_id: Optional[str] = None
    container_numbers: Optional[str] = None
    pickup_port_location: Optional[str] = None
    destination_warehouse: Optional[str] = None
    planned_departure_at: Optional[datetime] = None
    actual_departure_at: Optional[datetime] = None
    expected_arrival_at: Optional[datetime] = None
    actual_arrival_at: Optional[datetime] = None
    transport_fare_egp: Optional[float] = None
    status: Optional[str] = None
    tracking_notes: Optional[str] = None

class InlandTransportGateOutSubmit(BaseModel):
    actual_departure_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    gate_pass_no: Optional[str] = None
    notes: Optional[str] = None

class InlandTransportArrivalSubmit(BaseModel):
    actual_arrival_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    seal_intact: bool = True
    seal_number: Optional[str] = None
    notes: Optional[str] = None

class InlandTransportBookingResponse(InlandTransportBookingBase):
    transport_id: int
    transport_code: str
    is_active: bool
    created_at: datetime
    created_by: str
    updated_at: datetime
    updated_by: str

    model_config = ConfigDict(from_attributes=True)
