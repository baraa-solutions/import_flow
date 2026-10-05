from datetime import datetime, timezone
from typing import Any, Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session
from modules.import_files.model import ImportFile
from .schemas import InlandTransportBookingCreate

# Legacy booking status labels (T3 enum codes come in a later wave: docs/plans/phase-08-10-quality-plan.md section 5).
STATUS_BOOKED = "Booking Confirmed"
STATUS_DISPATCHED = "Dispatched"
STATUS_IN_TRANSIT = "In Transit"
STATUS_ARRIVED = "Arrived at Warehouse"
STATUS_DELIVERED = "Delivered"
IT_STATUS_LABELS = frozenset({STATUS_BOOKED, STATUS_DISPATCHED, STATUS_IN_TRANSIT, STATUS_ARRIVED, STATUS_DELIVERED})

ACTION_GATE_OUT = "gate_out"
ACTION_WAREHOUSE_ARRIVAL = "warehouse_arrival"
# Statuses from which each tracking event may be recorded; anything else (a repeat included) is a 409.
ALLOWED_FROM = {
    ACTION_GATE_OUT: frozenset({STATUS_BOOKED, STATUS_DISPATCHED}),
    ACTION_WAREHOUSE_ARRIVAL: frozenset({STATUS_BOOKED, STATUS_DISPATCHED, STATUS_IN_TRANSIT}),
}


def coded_error(status_code: int, code: str, message_ar: str, **params: Any) -> HTTPException:
    """Error with a language-neutral code (codes listed in docs/plans/review-shared-needs.md, not yet registered in
    system_messages): ``detail = {code, message, **params}``."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


def _aware(value: datetime) -> datetime:
    """SQLite returns naive datetimes (stored as UTC): compare everything as aware UTC."""
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def validate_schedule(planned_departure_at: Optional[datetime], expected_arrival_at: Optional[datetime]) -> None:
    if planned_departure_at and expected_arrival_at and _aware(expected_arrival_at) < _aware(planned_departure_at):
        raise HTTPException(
            status_code=400,
            detail="تاريخ وموعد الوصول المتوقع لا يمكن أن يسبق موعد التحميل والمغادرة المخطط.",
        )


def validate_actual_times(actual_departure_at: Optional[datetime], actual_arrival_at: Optional[datetime]) -> None:
    if actual_departure_at and actual_arrival_at and _aware(actual_arrival_at) < _aware(actual_departure_at):
        raise HTTPException(
            status_code=400,
            detail="موعد الوصول الفعلي للمخزن لا يمكن أن يسبق موعد الخروج الفعلي من الميناء.",
        )


def validate_text_fields(
    truck_plate_number: Optional[str],
    driver_name: Optional[str],
    driver_phone: Optional[str],
    waybill_number: Optional[str],
) -> None:
    if not truck_plate_number or len(truck_plate_number.strip()) < 2:
        raise HTTPException(
            status_code=400,
            detail="رقم لوحة الشاحنة مطلوب ويجب ألا يقل عن حرفين/رقمين.",
        )
    if not driver_name or len(driver_name.strip()) < 2:
        raise HTTPException(
            status_code=400,
            detail="اسم السائق مطلوب ويجب ألا يقل عن حرفين.",
        )
    if not driver_phone or len(driver_phone.strip()) < 5:
        raise HTTPException(
            status_code=400,
            detail="رقم هاتف السائق غير صالح.",
        )
    if not waybill_number or len(waybill_number.strip()) < 2:
        raise HTTPException(
            status_code=400,
            detail="رقم بوليصة النقل البري / إذن التحميل مطلوب.",
        )


def validate_transport_booking_input(schema: InlandTransportBookingCreate):
    validate_text_fields(schema.truck_plate_number, schema.driver_name, schema.driver_phone, schema.waybill_number)
    validate_schedule(schema.planned_departure_at, schema.expected_arrival_at)
    validate_status_label(schema.status)


def validate_status_label(status: Optional[str]) -> None:
    if status is not None and status not in IT_STATUS_LABELS:
        raise coded_error(400, "IT_STATUS_INVALID", f"حالة النقل '{status}' غير معروفة.", status=status)


def validate_transition(current_status: Optional[str], action: str) -> None:
    """Gate-out only before the truck left; arrival only before it arrived. A repeat is a 409 (plan IT-05)."""
    if current_status not in ALLOWED_FROM[action]:
        raise coded_error(
            409,
            "IT_TRANSITION_NOT_ALLOWED",
            f"لا يمكن تسجيل هذا الحدث على حجز النقل وهو في الحالة '{current_status}'.",
            current_status=current_status or "",
            action=action,
        )


# Status changes a PUT may make; gate-out / arrival go through their own endpoints (file sync + checks).
PUT_STATUS_CHANGES = frozenset({(STATUS_BOOKED, STATUS_DISPATCHED), (STATUS_ARRIVED, STATUS_DELIVERED)})
ACTION_STATUS_CHANGE = "status_change"


def validate_status_change(current_status: Optional[str], target_status: Optional[str]) -> None:
    if target_status is None or target_status == current_status:
        return
    if (current_status, target_status) not in PUT_STATUS_CHANGES:
        raise coded_error(
            409,
            "IT_TRANSITION_NOT_ALLOWED",
            f"لا يمكن تغيير حالة حجز النقل من {current_status} إلى {target_status} من شاشة التعديل.",
            current_status=current_status or "",
            action=ACTION_STATUS_CHANGE,
            target_status=target_status,
        )


def normalize_waybill(waybill_number: Optional[str]) -> str:
    return (waybill_number or "").strip().lower()


def validate_import_file_for_transport(db: Session, import_file_id: int) -> ImportFile:
    imp_file = (
        db.query(ImportFile)
        .filter(ImportFile.import_file_id == import_file_id, ImportFile.is_active == True)
        .first()
    )
    if not imp_file:
        raise HTTPException(
            status_code=404,
            detail=f"ملف الشحنة رقم {import_file_id} غير موجود أو غير نشط.",
        )
    return imp_file
