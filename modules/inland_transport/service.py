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
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking

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
    set_file_tracking(
        imp_file,
        stage_code="INLAND_TRANSPORT_BOOKED",
        next_action=msg("NA_TR_FOLLOW_DISPATCH_FREE_TIME_RECEIVING"),
    )
    if (imp_file.progress_percent or 0.0) < 97.0:
        imp_file.progress_percent = 97.0

    from modules.smart_tasks.model import SmartTask
    from modules.smart_tasks.repository import create_task as create_smart_task
    from modules.smart_tasks.schemas import SmartTaskCreate

    # Auto-complete pending TR-01 (inland transport booking) smart tasks
    pending_tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == imp_file.import_file_id,
        SmartTask.is_active == True,
        SmartTask.status.in_(["Pending", "In Progress"]),
        SmartTask.title.ilike("%TR-01%")
        | SmartTask.title.ilike("%نقل%")
        | (SmartTask.msg_code == "CC_TASK_INLAND_TRANSPORT"),
    ).all()
    for t in pending_tasks:
        t.status = "Completed"
        t.is_auto_closed = True
        t.updated_by = user

    # Create the downstream TR-03 smart task (truck arrival & GRN), once per file
    task_msg = msg("TR_TASK_TRACK_ARRIVAL_GRN")
    already_open = db.query(SmartTask).filter(
        SmartTask.import_file_id == imp_file.import_file_id,
        SmartTask.is_active == True,
        SmartTask.msg_code == task_msg.code,
        SmartTask.status.in_(["Pending", "In Progress"]),
    ).first()
    if already_open is None:
        create_smart_task(
            db,
            SmartTaskCreate(
                title=render_en(task_msg.code, task_msg.params, "title"),
                task_type="System Generated",
                import_file_id=imp_file.import_file_id,
                import_file_code=imp_file.import_file_code,
                phase_name="Phase 6: Inbound & Final Closure",
                assigned_user="Warehouse Manager",
                priority="High",
                reminder_type="Warehouse Receiving",
                due_date=schema.expected_arrival_at.date().isoformat() if schema.expected_arrival_at else None,
                status="Pending",
                notes=f"ACTION:WAREHOUSE_GRN | Waybill: {schema.waybill_number}",
            ),
            created_by=user,
            msg_code=task_msg.code,
            msg_params=task_msg.params,
            step_code="STEP_19",
            commit=False,  # the booking commit below writes the task too (no half-saved booking on failure)
        )

    # Emit Central System Notification
    try:
        from modules.notifications.model import SystemNotification
        notif_msg = msg(
            "TR_BOOKING_CONFIRMED",
            truck_plate_number=schema.truck_plate_number,
            import_file_code=imp_file.import_file_code,
            pickup_location=schema.pickup_port_location,
            destination_warehouse=schema.destination_warehouse,
            driver_name=schema.driver_name,
            driver_phone=schema.driver_phone,
        )
        notification = SystemNotification(
            notification_code=f"NOTIF-TR01-{imp_file.import_file_id}",
            title=render_en(notif_msg.code, notif_msg.params, "title"),
            message=render_en(notif_msg.code, notif_msg.params, "body"),
            msg_code=notif_msg.code,
            msg_params=notif_msg.params,
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
        booking.tracking_notes = (booking.tracking_notes or "") + f" | Gate-out: {payload.notes}"

    # Sync ImportFile
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == booking.import_file_id).first()
    if imp_file:
        imp_file.inland_transport_status = "IN_TRANSIT"
        imp_file.inland_departure_date = payload.actual_departure_at
        set_file_tracking(
            imp_file,
            stage_code="IN_TRANSIT_TO_WAREHOUSE",
            next_action=msg("NA_TR_RECEIVE_TRUCK_ISSUE_GRN"),
        )

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
        booking.tracking_notes = (booking.tracking_notes or "") + f" | Warehouse arrival: {payload.notes}"

    # Sync ImportFile
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == booking.import_file_id).first()
    if imp_file:
        imp_file.inland_transport_status = "ARRIVED"
        imp_file.inland_actual_arrival_date = payload.actual_arrival_at
        set_file_tracking(
            imp_file,
            stage_code="ARRIVED_AT_WAREHOUSE",
            next_action=msg("NA_TR_CHECK_SEALS_ISSUE_GRN"),
        )

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
