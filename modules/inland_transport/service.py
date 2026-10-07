from typing import List, Optional
from sqlalchemy.exc import IntegrityError
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
    list_active_bookings_for_file,
    find_active_booking_by_waybill,
    list_transport_bookings,
    apply_changes,
)
from .validators import (
    ACTION_GATE_OUT,
    ACTION_WAREHOUSE_ARRIVAL,
    STATUS_ARRIVED,
    STATUS_IN_TRANSIT,
    coded_error,
    normalize_waybill,
    validate_actual_times,
    validate_schedule,
    validate_status_label,
    validate_status_change,
    validate_text_fields,
    validate_transition,
    validate_transport_booking_input,
    validate_import_file_for_transport,
    validate_truck_type,
    validate_carrier,
)
from modules.import_files.model import ImportFile
from modules.common import enum_codes
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking


def sync_file_inland_fields(db: Session, imp_file: ImportFile) -> None:
    """Resync the import file's inland transport fields from all active bookings (BE810-T01).

    Total cost = sum of active fares.
    Header / driver / truck fields = newest active booking, or None when no active booking exists.
    Status and stage are NOT altered here.
    """
    bookings = list_active_bookings_for_file(db, imp_file.import_file_id)
    if not bookings:
        imp_file.inland_transport_cost_egp = 0.0
        imp_file.inland_transport_booking_no = None
        imp_file.inland_carrier_name = None
        imp_file.inland_truck_plate_no = None
        imp_file.inland_driver_name = None
        imp_file.inland_driver_phone = None
        imp_file.inland_departure_date = None
        imp_file.inland_expected_arrival_date = None
    else:
        imp_file.inland_transport_cost_egp = round(
            sum(float(b.transport_fare_egp or 0.0) for b in bookings), 2
        )
        newest = bookings[0]
        imp_file.inland_transport_booking_no = newest.waybill_number
        imp_file.inland_carrier_name = newest.carrier_name
        imp_file.inland_truck_plate_no = newest.truck_plate_number
        imp_file.inland_driver_name = newest.driver_name
        imp_file.inland_driver_phone = newest.driver_phone
        imp_file.inland_departure_date = newest.actual_departure_at or newest.planned_departure_at
        imp_file.inland_expected_arrival_date = newest.expected_arrival_at


_sync_file_inland_fields = sync_file_inland_fields


def _insert_booking(db: Session, schema: InlandTransportBookingCreate, user: str) -> InlandTransportBooking:
    """Insert with a fresh TR code; one retry when a concurrent insert took the same code (unique constraint).
    The booking is the first write of the request, so the rollback before the retry loses nothing."""
    try:
        return create_transport_booking(db, schema, generate_transport_code(db), user)
    except IntegrityError:
        db.rollback()
        return create_transport_booking(db, schema, generate_transport_code(db), user)


def create_transport_booking_service(
    db: Session,
    schema: InlandTransportBookingCreate,
    user: str = "System",
) -> InlandTransportBooking:
    validate_transport_booking_input(schema)
    validate_import_file_for_transport(db, schema.import_file_id)
    norm_truck_type = validate_truck_type(schema.truck_type)
    updates = {"truck_type": norm_truck_type}

    if schema.carrier_id is not None:
        carrier = validate_carrier(db, schema.carrier_id)
        updates["carrier_name"] = carrier.partner_name
    elif not schema.carrier_name or len(schema.carrier_name.strip()) < 2:
        raise HTTPException(
            status_code=400,
            detail="اسم شركة النقل مطلوب عند عدم تحديد معرّف الشركة.",
        )

    schema = schema.model_copy(update=updates)

    # IT-02: a retried request (double click, timeout) must not create a second booking for the same waybill.
    duplicate = find_active_booking_by_waybill(db, schema.import_file_id, normalize_waybill(schema.waybill_number))
    if duplicate is not None:
        raise coded_error(
            409,
            "IT_BOOKING_EXISTS",
            (
                f"يوجد بالفعل حجز نقل نشط لنفس بوليصة النقل ({duplicate.waybill_number}) على هذا الملف "
                f"(رقم الحجز: {duplicate.transport_code})."
            ),
            transport_code=duplicate.transport_code,
            waybill_number=duplicate.waybill_number,
        )

    booking = _insert_booking(db, schema, user)
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id).first()

    # Synchronize ImportFile
    status_str = "IN_TRANSIT" if schema.actual_departure_at else "BOOKED"
    imp_file.inland_transport_status = status_str
    sync_file_inland_fields(db, imp_file)

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
        (SmartTask.msg_code == "CC_TASK_INLAND_TRANSPORT")
        | (SmartTask.task_type == "TR-01")
        # legacy rows without a code: title match only
        | (SmartTask.msg_code.is_(None) & (SmartTask.title.ilike("%TR-01%") | SmartTask.title.ilike("%نقل%"))),
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

    # Central system notification (same transaction: one commit for booking, file sync, task and notification)
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
    db.add(SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        category="STAGE_PROGRESSION",
        severity="INFO",
        target_role="ALL",
        entity_type="ImportFile",
        entity_id=imp_file.import_file_id,
        is_read=False,
    ))

    db.commit()
    db.refresh(booking)
    return booking


def record_port_gate_out_service(
    db: Session,
    transport_id: int,
    payload: InlandTransportGateOutSubmit,
    user: str = "System",
) -> InlandTransportBooking:
    booking = get_transport_booking_service(db, transport_id)
    validate_transition(booking.status, ACTION_GATE_OUT)

    notes = booking.tracking_notes
    if payload.notes:
        notes = (notes or "") + f" | Gate-out: {payload.notes}"
    apply_changes(booking, {
        "actual_departure_at": payload.actual_departure_at,
        "status": STATUS_IN_TRANSIT,
        "tracking_notes": notes,
    }, user)
    db.flush()

    # Sync ImportFile
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == booking.import_file_id).first()
    if imp_file:
        imp_file.inland_transport_status = "IN_TRANSIT"
        sync_file_inland_fields(db, imp_file)
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
    booking = get_transport_booking_service(db, transport_id)
    validate_transition(booking.status, ACTION_WAREHOUSE_ARRIVAL)
    validate_actual_times(booking.actual_departure_at, payload.actual_arrival_at)

    notes = booking.tracking_notes
    if payload.notes:
        notes = (notes or "") + f" | Warehouse arrival: {payload.notes}"
    apply_changes(booking, {
        "actual_arrival_at": payload.actual_arrival_at,
        "status": STATUS_ARRIVED,
        "tracking_notes": notes,
    }, user)
    db.flush()

    # Sync ImportFile
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == booking.import_file_id).first()
    if imp_file:
        imp_file.inland_transport_status = "ARRIVED"
        imp_file.inland_actual_arrival_date = payload.actual_arrival_at
        sync_file_inland_fields(db, imp_file)
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
    data = schema.model_dump(exclude_unset=True)
    if "truck_type" in data and data["truck_type"] is not None:
        data["truck_type"] = validate_truck_type(data["truck_type"])
    if "carrier_id" in data and data["carrier_id"] is not None:
        carrier = validate_carrier(db, data["carrier_id"])
        data["carrier_name"] = carrier.partner_name
    # NOT NULL columns: an explicit null would only fail at commit (500).
    for field in ("waybill_number", "carrier_name", "truck_plate_number", "truck_type", "driver_name", "driver_phone",
                  "pickup_port_location", "destination_warehouse", "planned_departure_at", "expected_arrival_at",
                  "transport_fare_egp", "status"):
        if field in data and data[field] is None:
            del data[field]

    # Re-run the create checks on the merged values (plan IT-05).
    def merged(field: str):
        return data[field] if field in data else getattr(booking, field)

    validate_status_label(data.get("status"))
    validate_status_change(booking.status, data.get("status"))
    validate_text_fields(merged("truck_plate_number"), merged("driver_name"), merged("driver_phone"), merged("waybill_number"))
    validate_schedule(merged("planned_departure_at"), merged("expected_arrival_at"))
    validate_actual_times(merged("actual_departure_at"), merged("actual_arrival_at"))
    if "transport_fare_egp" in data and data["transport_fare_egp"] < 0:
        raise HTTPException(status_code=400, detail="أجرة النقل لا يمكن أن تكون قيمة سالبة.")
    if "waybill_number" in data:
        other = find_active_booking_by_waybill(db, booking.import_file_id, normalize_waybill(data["waybill_number"]))
        if other is not None and other.transport_id != booking.transport_id:
            raise coded_error(
                409,
                "IT_BOOKING_EXISTS",
                f"يوجد بالفعل حجز نقل نشط لنفس بوليصة النقل على هذا الملف (رقم الحجز: {other.transport_code}).",
                transport_code=other.transport_code,
                waybill_number=other.waybill_number,
            )

    apply_changes(booking, data, user)
    db.flush()
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == booking.import_file_id).first()
    if imp_file:
        sync_file_inland_fields(db, imp_file)
    db.commit()
    db.refresh(booking)
    return booking


def soft_delete_transport_booking_service(
    db: Session,
    transport_id: int,
    user: str = "System",
) -> None:
    booking = get_transport_booking_service(db, transport_id)
    apply_changes(booking, {"is_active": False}, user)
    db.flush()
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == booking.import_file_id).first()
    if imp_file:
        sync_file_inland_fields(db, imp_file)
    db.commit()
