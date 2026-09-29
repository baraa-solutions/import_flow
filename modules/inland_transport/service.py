from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException

from .model import InlandTransportBooking
from .schemas import (
    InlandTransportBookingCreate,
    InlandTransportBookingUpdate,
    InlandTransportGateOutSubmit,
    InlandTransportArrivalSubmit,
)
from .repository import (
    generate_transport_code,
    create_transport_booking,
    get_transport_booking_by_id,
    get_transport_booking_by_file,
    list_transport_bookings,
    update_transport_booking,
    soft_delete_transport_booking,
)
from .validators import (
    validate_transport_booking_input,
    validate_import_file_for_transport,
)
from modules.import_files.model import ImportFile
from modules.common import enum_codes

def create_transport_booking_service(
    db: Session,
    schema: InlandTransportBookingCreate,
    user: str = "System",
) -> InlandTransportBooking:
    validate_transport_booking_input(schema)
    imp_file = validate_import_file_for_transport(db, schema.import_file_id)
    schema = schema.model_copy(update={"truck_type": enum_codes.normalize(enum_codes.TRUCK_TYPE, schema.truck_type)})

    code = generate_transport_code(db)
    booking = create_transport_booking(db, schema, code, user)

    # Synchronize ImportFile
    status_str = "IN_TRANSIT" if schema.actual_departure_at else "BOOKED"
    imp_file.inland_transport_status = status_str
    imp_file.inland_transport_booking_no = schema.waybill_number
    imp_file.inland_carrier_name = schema.carrier_name
    imp_file.inland_truck_plate_no = schema.truck_plate_number
    imp_file.inland_driver_name = schema.driver_name
    imp_file.inland_driver_phone = schema.driver_phone
    imp_file.inland_transport_cost_egp = schema.transport_fare_egp
    imp_file.inland_departure_date = schema.planned_departure_at
    imp_file.inland_expected_arrival_date = schema.expected_arrival_at
    if schema.actual_departure_at:
        imp_file.inland_departure_date = schema.actual_departure_at

    imp_file.current_module = "Phase 8 - Inland Transport & Warehouse Delivery"
    imp_file.current_stage = f"Inland Transport (حجز سيارات النقل: {schema.truck_plate_number})"
    imp_file.next_action = "متابعة خروج الشحنة (TR-01) ورادار فترات السماح (TR-02) والاستلام بالمخزن (TR-03)"
    if (imp_file.progress_percent or 0.0) < 97.0:
        imp_file.progress_percent = 97.0

    # Auto-complete pending TR-01 smart tasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == imp_file.import_file_id,
            SmartTask.is_active == True,
            SmartTask.status.in_(["PENDING", "IN_PROGRESS"]),
            SmartTask.task_name.ilike("%نقل%") | SmartTask.task_name.ilike("%TR-01%"),
        ).all()
        for t in pending_tasks:
            t.status = "COMPLETED"
            t.completed_at = datetime.now(timezone.utc)
            t.completed_by = user
    except Exception:
        pass

    # Create downstream TR-02/TR-03 smart task
    try:
        from modules.smart_tasks.model import SmartTask
        downstream_task = SmartTask(
            import_file_id=imp_file.import_file_id,
            task_code=f"TSK-TR02-{imp_file.import_file_id}",
            task_name="متابعة وصول الشاحنة للمخزن وإصدار إذن الاستلام GRN (TR-03)",
            stage_name="Phase 8 - Inland Transport & Warehouse Delivery",
            assigned_role="Warehouse Manager",
            status="PENDING",
            priority="HIGH",
            due_date=schema.expected_arrival_at,
            created_by=user,
        )
        db.add(downstream_task)
    except Exception:
        pass

    # Emit Central System Notification
    try:
        from modules.notifications.model import SystemNotification
        notification = SystemNotification(
            notification_code=f"NOTIF-TR01-{imp_file.import_file_id}",
            title="تأكيد حجز سيارات النقل الداخلي (TR-01)",
            message=f"تم تأكيد حجز الشاحنة ({schema.truck_plate_number}) لنقل الشحنة {imp_file.import_file_code} من {schema.pickup_port_location} إلى {schema.destination_warehouse}. السائق: {schema.driver_name} ({schema.driver_phone}).",
            category="STAGE_PROGRESSION",
            severity="INFO",
            target_role="ALL",
            import_file_id=imp_file.import_file_id,
            created_by=user,
        )
        db.add(notification)
    except Exception:
        pass

    db.commit()
    db.refresh(booking)
    return booking

def record_port_gate_out_service(
    db: Session,
    transport_id: int,
    payload: InlandTransportGateOutSubmit,
    user: str = "System",
) -> InlandTransportBooking:
    booking = get_transport_booking_by_id(db, transport_id)
    if not booking:
        raise HTTPException(status_code=404, detail="سجل النقل الداخلي غير موجود.")

    booking.actual_departure_at = payload.actual_departure_at
    booking.status = "In Transit"
    if payload.notes:
        booking.tracking_notes = (booking.tracking_notes or "") + f" | خروج البوابة: {payload.notes}"

    # Sync ImportFile
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == booking.import_file_id).first()
    if imp_file:
        imp_file.inland_transport_status = "IN_TRANSIT"
        imp_file.inland_departure_date = payload.actual_departure_at
        imp_file.current_stage = f"In Transit to Warehouse (الشحنة في الطريق للمخزن)"
        imp_file.next_action = "استقبال الشاحنة وتفريغ الحاويات وإصدار إذن الإضافة GRN (TR-03)"

    db.commit()
    db.refresh(booking)
    return booking

def record_warehouse_arrival_service(
    db: Session,
    transport_id: int,
    payload: InlandTransportArrivalSubmit,
    user: str = "System",
) -> InlandTransportBooking:
    booking = get_transport_booking_by_id(db, transport_id)
    if not booking:
        raise HTTPException(status_code=404, detail="سجل النقل الداخلي غير موجود.")

    booking.actual_arrival_at = payload.actual_arrival_at
    booking.status = "Arrived at Warehouse"
    if payload.notes:
        booking.tracking_notes = (booking.tracking_notes or "") + f" | وصول المخزن: {payload.notes}"

    # Sync ImportFile
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == booking.import_file_id).first()
    if imp_file:
        imp_file.inland_transport_status = "ARRIVED"
        imp_file.inland_actual_arrival_date = payload.actual_arrival_at
        imp_file.current_stage = f"Arrived at {booking.destination_warehouse} (وصلت للمخزن - بانتظار إذن الاستلام)"
        imp_file.next_action = "فحص سلامة الأختام وإصدار إذن الاستلام GRN (TR-03)"

    db.commit()
    db.refresh(booking)
    return booking

def get_transport_booking_service(db: Session, transport_id: int) -> InlandTransportBooking:
    booking = get_transport_booking_by_id(db, transport_id)
    if not booking:
        raise HTTPException(status_code=404, detail="سجل النقل الداخلي غير موجود.")
    return booking

def get_transport_booking_by_file_service(db: Session, import_file_id: int) -> Optional[InlandTransportBooking]:
    return get_transport_booking_by_file(db, import_file_id)

def list_transport_bookings_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[InlandTransportBooking]:
    return list_transport_bookings(db, include_inactive, import_file_id, status, search)

def update_transport_booking_service(
    db: Session,
    transport_id: int,
    schema: InlandTransportBookingUpdate,
    user: str = "System",
) -> InlandTransportBooking:
    booking = get_transport_booking_service(db, transport_id)
    if schema.truck_type is not None:
        schema = schema.model_copy(update={"truck_type": enum_codes.normalize(enum_codes.TRUCK_TYPE, schema.truck_type)})
    return update_transport_booking(db, booking, schema, user)

def soft_delete_transport_booking_service(
    db: Session,
    transport_id: int,
    user: str = "System",
) -> None:
    booking = get_transport_booking_service(db, transport_id)
    soft_delete_transport_booking(db, booking, user)
