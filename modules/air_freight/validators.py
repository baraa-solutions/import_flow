"""
Business validation of the air freight suite. Every failure is a ``CodedHTTPException`` (system message code +
params) so Flutter renders it in Arabic or English.
"""
import re
from datetime import date
from typing import Optional, Tuple

from fastapi import status
from sqlalchemy.orm import Session

from modules.common import shipment_modes
from modules.common.errors import CodedHTTPException

from . import repository

AIR_MODULE_MODES = (shipment_modes.AIR, shipment_modes.COURIER)
AWB_DIGITS = 11
UNPROCESSABLE = 422  # literal: the Starlette constant name changed between versions
_NON_DIGIT_RE = re.compile(r"[\s\-./]")


# ==================================================
# Air Waybill number (IATA Resolution 600a)
# ==================================================

def parse_awb_number(value: Optional[str]) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """``(normalized_11_digits, airline_prefix, error_code)``. Separators (space, dash, dot, slash) are ignored.

    Rule: 3-digit airline prefix + 7-digit serial + 1 check digit, where check digit = serial mod 7.
    Blank -> ``(None, None, None)`` (not entered yet)."""
    raw = (value or "").strip()
    if not raw:
        return None, None, None
    digits = _NON_DIGIT_RE.sub("", raw)
    if len(digits) != AWB_DIGITS or not digits.isdigit():
        return None, None, "AIR_AWB_FORMAT_INVALID"
    serial, check = int(digits[3:10]), int(digits[10])
    if serial % 7 != check:
        return None, None, "AIR_AWB_CHECK_DIGIT_INVALID"
    return digits, digits[:3], None


def format_awb_number(digits: Optional[str]) -> Optional[str]:
    """Display form ``176-12345675`` of a normalised 11-digit AWB."""
    return f"{digits[:3]}-{digits[3:]}" if digits and len(digits) == AWB_DIGITS else digits


def validate_awb_number(value: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
    """Normalised AWB + airline prefix; raises 422 for a malformed number. Blank -> ``(None, None)``."""
    digits, prefix, error = parse_awb_number(value)
    if error:
        message = (
            "رقم بوليصة الشحن الجوي يجب أن يتكون من 11 رقماً (3 أرقام كود الناقل + 8 أرقام)."
            if error == "AIR_AWB_FORMAT_INVALID"
            else "رقم التحقق (الخانة الأخيرة) في بوليصة الشحن الجوي غير صحيح."
        )
        raise CodedHTTPException(UNPROCESSABLE, error, message, awb_number=str(value))
    return digits, prefix


# ==================================================
# Mode / sub-mode
# ==================================================

def validate_air_mode(mode: Optional[str], sub_mode: Optional[str]) -> Tuple[str, Optional[str]]:
    """``(mode, sub_mode)`` codes for an air record: mode must resolve to AIR or COURIER and the sub-mode, when
    given, must belong to it."""
    try:
        code = shipment_modes.normalize_mode(mode)
    except ValueError:
        code = None
    if code not in AIR_MODULE_MODES:
        raise CodedHTTPException(
            UNPROCESSABLE, "AIR_MODE_INVALID",
            "نمط الشحن لسجل البوليصة الجوية يجب أن يكون جوي (AIR) أو بريد سريع (COURIER).",
            shipment_mode=str(mode or ""),
        )
    try:
        return shipment_modes.validate_mode_pair(code, sub_mode)
    except ValueError:
        raise CodedHTTPException(
            UNPROCESSABLE, "AIR_SUB_MODE_INVALID",
            f"النمط الفرعي '{sub_mode}' لا يتبع نمط الشحن {code}.",
            shipment_sub_mode=str(sub_mode), shipment_mode=code,
        )


# ==================================================
# References (GP-003: master data by FK)
# ==================================================

def validate_import_file(db: Session, import_file_id: int):
    import_file = repository.get_import_file(db, import_file_id)
    if import_file is None:
        raise CodedHTTPException(
            status.HTTP_404_NOT_FOUND, "AIR_IMPORT_FILE_NOT_FOUND",
            f"ملف الاستيراد رقم {import_file_id} غير موجود.", import_file_id=import_file_id,
        )
    return import_file


def validate_airport(db: Session, location_id: Optional[int]):
    if location_id is None:
        return None
    location = repository.get_location(db, location_id)
    if location is None or not location.is_active:
        raise CodedHTTPException(
            UNPROCESSABLE, "AIR_AIRPORT_NOT_FOUND",
            f"المطار رقم {location_id} غير موجود أو غير مفعل.", location_id=location_id,
        )
    if "air" not in (location.location_type or "").lower():
        raise CodedHTTPException(
            UNPROCESSABLE, "AIR_LOCATION_NOT_AIRPORT",
            f"الموقع '{location.location_name}' ليس مطاراً.", location_name=location.location_name,
        )
    return location


def validate_route(origin_airport_id: Optional[int], destination_airport_id: Optional[int]) -> None:
    if origin_airport_id is not None and origin_airport_id == destination_airport_id:
        raise CodedHTTPException(
            UNPROCESSABLE, "AIR_SAME_AIRPORTS",
            "مطار القيام ومطار الوصول لا يمكن أن يكونا نفس المطار.",
        )


def validate_airline(db: Session, provider_id: Optional[int]):
    if provider_id is None:
        return None
    provider = repository.get_provider(db, provider_id)
    if provider is None or not getattr(provider, "is_active", True):
        raise CodedHTTPException(
            UNPROCESSABLE, "AIR_AIRLINE_NOT_FOUND",
            f"شركة الطيران / الناقل رقم {provider_id} غير موجود أو غير مفعل.", provider_id=provider_id,
        )
    return provider


def validate_flight_dates(flight_date: Optional[date], arrival_date: Optional[date]) -> None:
    if flight_date and arrival_date and arrival_date < flight_date:
        raise CodedHTTPException(
            UNPROCESSABLE, "AIR_DATES_INVALID",
            "تاريخ الوصول لا يمكن أن يسبق تاريخ الرحلة.",
            flight_date=flight_date.isoformat(), arrival_date=arrival_date.isoformat(),
        )


def validate_no_duplicate_awb(
    db: Session, mawb_number: Optional[str], hawb_number: Optional[str], exclude_id: Optional[int] = None
) -> None:
    """Application twin of ``uq_air_shipment_records_mawb_hawb`` that also catches a repeated MAWB without a
    house number (NULLs never collide in a UNIQUE constraint) and soft-deleted rows (restore them instead)."""
    if not mawb_number:
        return
    existing = repository.find_by_awb(db, mawb_number, hawb_number, exclude_id=exclude_id)
    if existing is not None:
        raise CodedHTTPException(
            status.HTTP_409_CONFLICT, "AIR_AWB_DUPLICATE",
            f"البوليصة الجوية {format_awb_number(mawb_number)} مسجلة بالفعل في السجل {existing.air_record_code}.",
            awb_number=format_awb_number(mawb_number), air_record_code=existing.air_record_code,
        )
