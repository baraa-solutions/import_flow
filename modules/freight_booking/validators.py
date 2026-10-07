from datetime import datetime
from typing import Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from modules.freight_booking.model import ShipmentBooking

# Booking status labels (legacy labels, validated as a whitelist; T3 codes are deferred).
STATUS_DRAFT = "Draft"
STATUS_REQUESTED = "Booking Requested"
STATUS_CONFIRMED = "Confirmed"
STATUS_AMENDED = "Amended"
STATUS_CANCELLED = "Cancelled"
STATUS_SAILED = "Sailed"

BOOKING_STATUSES = frozenset({STATUS_DRAFT, STATUS_REQUESTED, STATUS_CONFIRMED, STATUS_AMENDED, STATUS_CANCELLED, STATUS_SAILED})
# Statuses a user may set by hand on create / PUT. Confirmed and Sailed only come from /confirm and /depart.
MANUAL_STATUSES = frozenset({STATUS_DRAFT, STATUS_REQUESTED, STATUS_AMENDED, STATUS_CANCELLED})
CONFIRMABLE_STATUSES = frozenset({STATUS_DRAFT, STATUS_REQUESTED, STATUS_AMENDED, STATUS_CONFIRMED})
DEPARTABLE_STATUSES = frozenset({STATUS_CONFIRMED, STATUS_AMENDED})
COMMITTED_STATUSES = frozenset({STATUS_CONFIRMED, STATUS_AMENDED, STATUS_SAILED})

BOOKING_LABEL_AR = "حجز الشحن"


def validate_booking_dates(etd: datetime, eta: datetime):
    if etd and eta:
        etd_comp = etd.replace(tzinfo=None) if hasattr(etd, "tzinfo") and etd.tzinfo else etd
        eta_comp = eta.replace(tzinfo=None) if hasattr(eta, "tzinfo") and eta.tzinfo else eta
        if eta_comp < etd_comp:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="تاريخ الوصول المتوقع (ETA) لا يمكن أن يكون قبل تاريخ الإبحار المتوقع (ETD).",
            )


def validate_container_allocation(shipment_type: str, containers_data: list):
    if shipment_type == "Ocean FCL" and not containers_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="شحنات الحاويات الكاملة (Ocean FCL) تتطلب تخصيص حاوية واحدة على الأقل.",
        )


def validate_manual_status(new_status: Optional[str], current_status: Optional[str] = None) -> None:
    """A status sent on create / PUT: unchanged values pass (the screen re-sends the status on every save);
    otherwise only the manual statuses are accepted, Confirmed / Sailed need their dedicated endpoints."""
    if new_status is None or new_status == current_status:
        return
    if new_status not in MANUAL_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تغيير حالة الحجز يدويًا إلى {new_status}",
        )
    # A confirmed / amended / sailed booking never goes back to Draft or Booking Requested: it can only be
    # cancelled, or amended from Confirmed.
    if current_status in COMMITTED_STATUSES and not (
        new_status == STATUS_CANCELLED or (new_status == STATUS_AMENDED and current_status == STATUS_CONFIRMED)
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تغيير حالة الحجز من {current_status} إلى {new_status}",
        )


def validate_deletable(booking: ShipmentBooking) -> None:
    if booking.status in COMMITTED_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن حذف حجز الشحن {booking.booking_code} وهو في حالة {booking.status}. يمكن إلغاؤه بدلاً من الحذف.",
        )


def validate_can_confirm(booking: ShipmentBooking) -> None:
    if booking.status not in CONFIRMABLE_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تأكيد حجز الشحن {booking.booking_code} وهو في حالة {booking.status}.",
        )


def validate_can_depart(booking: ShipmentBooking) -> None:
    if booking.status not in DEPARTABLE_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يمكن تسجيل إبحار حجز الشحن {booking.booking_code} قبل تأكيده (الحالة الحالية: {booking.status}).",
        )


def validate_no_duplicate_booking_for_file(
    db: Session, import_file_id: Optional[int], current_booking_id: Optional[int] = None
):
    if not import_file_id:
        return
    query = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True,
    )
    if current_booking_id:
        query = query.filter(ShipmentBooking.booking_id != current_booking_id)
    existing = query.first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"يوجد بالفعل حجز شحن مسجل لهذا الملف الاستيرادي (كود الحجز: {existing.booking_code}). يرجى الذهاب لتعديل الحجز الحالي بدلاً من إنشاء حجز جديد.",
        )


def validate_charge_currencies(db: Session, charges: list) -> None:
    if not charges:
        return
    from modules.currencies.repository import CurrencyRepository

    repo = CurrencyRepository(db)
    for c in charges:
        c_dict = c if isinstance(c, dict) else (c.model_dump() if hasattr(c, "model_dump") else getattr(c, "__dict__", {}))
        raw_cur = c_dict.get("currency")
        ccy = str(raw_cur or "USD").strip().upper()
        if not repo.get_currency_by_code(ccy):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"عملة البند غير معروفة: {ccy}",
            )

