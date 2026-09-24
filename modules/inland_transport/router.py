from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from .schemas import (
    InlandTransportBookingCreate,
    InlandTransportBookingUpdate,
    InlandTransportBookingResponse,
    InlandTransportGateOutSubmit,
    InlandTransportArrivalSubmit,
)
from .service import (
    create_transport_booking_service,
    get_transport_booking_service,
    get_transport_booking_by_file_service,
    list_transport_bookings_service,
    update_transport_booking_service,
    soft_delete_transport_booking_service,
    record_port_gate_out_service,
    record_warehouse_arrival_service,
)

router = APIRouter(prefix="/api/v1/inland-transport", tags=["Stage 8 - Inland Transport (TR-01)"], dependencies=[Depends(get_current_user)])

@router.post("/bookings", response_model=InlandTransportBookingResponse, status_code=status.HTTP_201_CREATED)
def create_transport_booking(
    schema: InlandTransportBookingCreate,
    db: Session = Depends(get_db),
):
    """TR-01: حجز وتنسيق سيارة وسائق النقل الداخلي للشحنة."""
    return create_transport_booking_service(db, schema)

@router.get("/bookings", response_model=List[InlandTransportBookingResponse])
def list_transport_bookings(
    include_inactive: bool = Query(False, description="Include soft-deleted records"),
    import_file_id: Optional[int] = Query(None, description="Filter by import file ID"),
    status: Optional[str] = Query(None, description="Filter by status"),
    search: Optional[str] = Query(None, description="Search term"),
    db: Session = Depends(get_db),
):
    """عرض قائمة حجوزات النقل الداخلي."""
    return list_transport_bookings_service(db, include_inactive, import_file_id, status, search)

@router.get("/bookings/by-file/{import_file_id}", response_model=Optional[InlandTransportBookingResponse])
def get_transport_booking_by_file(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    """جلب بيانات حجز النقل النشط لملف شحنة محدد."""
    return get_transport_booking_by_file_service(db, import_file_id)

@router.get("/bookings/{transport_id}", response_model=InlandTransportBookingResponse)
def get_transport_booking(
    transport_id: int,
    db: Session = Depends(get_db),
):
    """جلب تفاصيل حجز نقل داخلي بالمعرف."""
    return get_transport_booking_service(db, transport_id)

@router.put("/bookings/{transport_id}", response_model=InlandTransportBookingResponse)
def update_transport_booking(
    transport_id: int,
    schema: InlandTransportBookingUpdate,
    db: Session = Depends(get_db),
):
    """تعديل بيانات حجز النقل الداخلي."""
    return update_transport_booking_service(db, transport_id, schema)

@router.post("/bookings/{transport_id}/gate-out", response_model=InlandTransportBookingResponse)
def record_port_gate_out(
    transport_id: int,
    payload: InlandTransportGateOutSubmit,
    db: Session = Depends(get_db),
):
    """تسجيل خروج الشاحنة من بوابة الميناء وبدء التحرك للمخزن."""
    return record_port_gate_out_service(db, transport_id, payload)

@router.post("/bookings/{transport_id}/warehouse-arrival", response_model=InlandTransportBookingResponse)
def record_warehouse_arrival(
    transport_id: int,
    payload: InlandTransportArrivalSubmit,
    db: Session = Depends(get_db),
):
    """تسجيل وصول الشاحنة لمخزن الشركة وبدء إجراءات الاستلام (TR-03)."""
    return record_warehouse_arrival_service(db, transport_id, payload)

@router.delete("/bookings/{transport_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transport_booking(
    transport_id: int,
    db: Session = Depends(get_db),
):
    """حذف حجز النقل الداخلي (حذف منطقي Soft Delete)."""
    soft_delete_transport_booking_service(db, transport_id)
    return None
