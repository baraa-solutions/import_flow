from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc

from .model import InlandTransportBooking
from .schemas import InlandTransportBookingCreate, InlandTransportBookingUpdate

def generate_transport_code(db: Session) -> str:
    """Generate sequential TR code: TR-YYYY-XXXX."""
    year = datetime.now().year
    prefix = f"TR-{year}-"
    last_record = (
        db.query(InlandTransportBooking)
        .filter(InlandTransportBooking.transport_code.like(f"{prefix}%"))
        .order_by(desc(InlandTransportBooking.transport_id))
        .first()
    )
    if last_record and last_record.transport_code:
        try:
            last_seq = int(last_record.transport_code.split("-")[-1])
            new_seq = last_seq + 1
        except ValueError:
            new_seq = 1
    else:
        new_seq = 1
    return f"{prefix}{new_seq:04d}"

def create_transport_booking(
    db: Session,
    schema: InlandTransportBookingCreate,
    code: str,
    user: str = "System",
) -> InlandTransportBooking:
    booking = InlandTransportBooking(
        transport_code=code,
        import_file_id=schema.import_file_id,
        waybill_number=schema.waybill_number,
        booking_date=schema.booking_date or datetime.now(timezone.utc),
        carrier_id=schema.carrier_id,
        carrier_name=schema.carrier_name,
        truck_plate_number=schema.truck_plate_number,
        truck_type=schema.truck_type,
        driver_name=schema.driver_name,
        driver_phone=schema.driver_phone,
        driver_national_id=schema.driver_national_id,
        container_numbers=schema.container_numbers,
        pickup_port_location=schema.pickup_port_location,
        destination_warehouse=schema.destination_warehouse,
        planned_departure_at=schema.planned_departure_at,
        actual_departure_at=schema.actual_departure_at,
        expected_arrival_at=schema.expected_arrival_at,
        actual_arrival_at=schema.actual_arrival_at,
        transport_fare_egp=schema.transport_fare_egp,
        status=schema.status,
        tracking_notes=schema.tracking_notes,
        created_by=user,
        updated_by=user,
    )
    db.add(booking)
    # Flush only: create_transport_booking_service commits once after the file sync, tasks and notification.
    db.flush()
    return booking

def get_transport_booking_by_id(db: Session, transport_id: int) -> Optional[InlandTransportBooking]:
    return (
        db.query(InlandTransportBooking)
        .filter(InlandTransportBooking.transport_id == transport_id)
        .first()
    )

def get_transport_booking_by_file(db: Session, import_file_id: int) -> Optional[InlandTransportBooking]:
    return (
        db.query(InlandTransportBooking)
        .filter(
            InlandTransportBooking.import_file_id == import_file_id,
            InlandTransportBooking.is_active == True,
        )
        .order_by(desc(InlandTransportBooking.transport_id))
        .first()
    )

def list_transport_bookings(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[InlandTransportBooking]:
    q = db.query(InlandTransportBooking)
    if not include_inactive:
        q = q.filter(InlandTransportBooking.is_active == True)
    if import_file_id:
        q = q.filter(InlandTransportBooking.import_file_id == import_file_id)
    if status:
        q = q.filter(InlandTransportBooking.status == status)
    if search:
        pattern = f"%{search}%"
        q = q.filter(
            or_(
                InlandTransportBooking.transport_code.ilike(pattern),
                InlandTransportBooking.waybill_number.ilike(pattern),
                InlandTransportBooking.truck_plate_number.ilike(pattern),
                InlandTransportBooking.driver_name.ilike(pattern),
                InlandTransportBooking.carrier_name.ilike(pattern),
            )
        )
    return q.order_by(desc(InlandTransportBooking.transport_id)).all()

def update_transport_booking(
    db: Session,
    booking: InlandTransportBooking,
    schema: InlandTransportBookingUpdate,
    user: str = "System",
) -> InlandTransportBooking:
    data = schema.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(booking, key, value)
    booking.updated_at = datetime.now(timezone.utc)
    booking.updated_by = user
    db.commit()
    db.refresh(booking)
    return booking

def soft_delete_transport_booking(
    db: Session,
    booking: InlandTransportBooking,
    user: str = "System",
) -> InlandTransportBooking:
    booking.is_active = False
    booking.updated_at = datetime.now(timezone.utc)
    booking.updated_by = user
    db.commit()
    db.refresh(booking)
    return booking
