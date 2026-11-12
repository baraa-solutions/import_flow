from datetime import date
from typing import Optional

from sqlalchemy.orm import Session

from . import repository


# ==================================================
# Validators (MD-008)
# ==================================================

def validate_no_overlapping_hs_code_dates(
    db: Session,
    hs_code: str,
    effective_from: date,
    effective_to: Optional[date] = None,
    exclude_id: Optional[int] = None,
) -> None:
    """
    Validates that a new or updated HS code tariff version does not have an overlapping
    effective date range with existing versions of the same HS code.
    Allows multiple chronological versions of the same HS code across different time periods.
    """
    clean_hs = hs_code.strip()
    nodots = clean_hs.replace(".", "")
    from sqlalchemy import func
    from .model import CustomsTariff

    records = (
        db.query(CustomsTariff)
        .filter(func.replace(CustomsTariff.hs_code, '.', '') == nodots)
        .all()
    )

    for rec in records:
        if exclude_id is not None and rec.tariff_id == exclude_id:
            continue
        rec_start = rec.effective_from
        rec_end = rec.effective_to

        # Check overlap:
        # Non-overlapping if (effective_to is not None and rec_start > effective_to)
        # or (rec_end is not None and effective_from > rec_end)
        if effective_to is not None and rec_start > effective_to:
            continue
        if rec_end is not None and effective_from > rec_end:
            continue

        end_desc = f"حتى {rec_end}" if rec_end else "مستمر (ساري)"
        raise ValueError(
            f"فترة سريان البند الجمركي '{hs_code}' (من {effective_from} إلى {effective_to or 'مستمر'}) "
            f"تتداخل مع مرحلة سارية موجودة (Tariff ID: {rec.tariff_id}، من {rec_start} {end_desc}). "
            "يجب أن تكون الفترات الزمنية للتعريفة الجمركية متعاقبة زمنيًا دون تداخل."
        )


def validate_no_duplicate_hs_code(
    db: Session,
    hs_code: str,
    exclude_id: Optional[int] = None,
    effective_from: Optional[date] = None,
    effective_to: Optional[date] = None,
) -> None:
    """
    Validate that the HS code does not overlap with existing versions.
    If effective_from is provided, enforces non-overlapping date ranges.
    If effective_from is None, defaults to checking against date.today() / open-ended.
    """
    eff_from = effective_from or date.today()
    validate_no_overlapping_hs_code_dates(
        db,
        hs_code=hs_code,
        effective_from=eff_from,
        effective_to=effective_to,
        exclude_id=exclude_id,
    )


def validate_tariff_exists(db: Session, tariff_id: int) -> None:
    """Raise ValueError if tariff_id does not exist."""
    tariff = repository.get_tariff_by_id(db, tariff_id)
    if not tariff:
        raise ValueError(f"Tariff ID {tariff_id} not found.")


def validate_effective_date_range(
    effective_from: date, effective_to: date = None
) -> None:
    """
    Raise ValueError if effective_to is not after effective_from.
    None effective_to means open-ended (still active) — always valid.
    """
    if effective_to and effective_to <= effective_from:
        raise ValueError("تاريخ انتهاء السريان يجب أن يكون بعد تاريخ البداية.")


def resolve_rate_change_effective_date(
    current_effective_from: date,
    requested_effective_from: Optional[date],
    today: date,
) -> date:
    """
    Start date of the tariff version that a rate/requirement change produces (AGENTS.md 7.2:
    rates keep their effective_from/effective_to history and are never overwritten in place).

    - No date sent, or the current version's own start re-sent unchanged: the change starts today.
    - A later date: the change starts on that date. A later date that is still in the past is
      allowed on purpose: decrees are often published after the date they take effect, so a
      retroactive correction is an explicit user choice. History stays split into versions
      (the old version is closed the day before), it is never overwritten in place.
    - An earlier date while the current version is already in force: rejected, since rewriting
      the rate from a past date would silently rewrite history that cost snapshots relied on.
      (A version that has not started yet may still move its start earlier.)

    The caller versions when the result is after current_effective_from and edits in place
    otherwise (the version starts today or later, so no past day depends on it).
    """
    if requested_effective_from is None or requested_effective_from == current_effective_from:
        return today
    if requested_effective_from < current_effective_from and current_effective_from <= today:
        raise ValueError(
            "لا يمكن تعديل نسب أو متطلبات البند الجمركي بتاريخ سريان سابق لبداية الإصدار الحالي "
            f"({current_effective_from}). اختر تاريخ سريان لاحقاً لإنشاء إصدار جديد مع الحفاظ على السجل التاريخي."
        )
    return requested_effective_from


# ==================================================
# Trade remedy measures (anti-dumping / safeguard / countervailing)
# ==================================================

def normalize_trade_remedy_hs(hs_code: str) -> str:
    return (hs_code or "").strip().replace(".", "").replace(" ", "")


def validate_trade_remedy_fields(data: dict) -> dict:
    """Checks one complete measure (after merging an update) and returns it normalised."""
    from fastapi import status
    from modules.common.errors import CodedHTTPException

    hs = normalize_trade_remedy_hs(data.get("hs_code") or "")
    if not hs.isdigit() or len(hs) < 4:
        raise CodedHTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "TRM_INVALID_HS",
            f"البند الجمركي '{data.get('hs_code')}' غير صالح: لازم 4 أرقام على الأقل.",
            hs_code=data.get("hs_code") or "",
        )
    data["hs_code"] = hs

    origin = (data.get("origin_country") or "").strip().upper() or None
    if origin is not None and not (len(origin) == 2 and origin.isalpha()):
        raise CodedHTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "TRM_INVALID_ORIGIN",
            f"بلد المنشأ '{origin}' لازم يكون رمز ISO من حرفين.", origin_country=origin,
        )
    data["origin_country"] = origin
    data["exporter_name"] = (data.get("exporter_name") or "").strip() or None

    basis = data.get("duty_basis")
    if basis == "PERCENT_OF_CIF":
        if data.get("rate_percent") is None:
            raise CodedHTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT, "TRM_BASIS_FIELDS_MISSING",
                "النسبة المئوية مطلوبة لتدبير محسوب كنسبة من CIF.", duty_basis=basis,
            )
        data["fixed_amount"] = None
        data["fixed_currency"] = None
    else:
        currency = (data.get("fixed_currency") or "").strip().upper()
        if data.get("fixed_amount") is None or len(currency) != 3:
            raise CodedHTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT, "TRM_BASIS_FIELDS_MISSING",
                "المبلغ الثابت وعملته مطلوبين لتدبير محسوب بمبلغ ثابت.", duty_basis=basis,
            )
        data["fixed_currency"] = currency
        data["rate_percent"] = None

    if data.get("effective_to") is not None and data["effective_to"] < data["effective_from"]:
        raise CodedHTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "TRM_INVALID_DATES",
            "تاريخ نهاية السريان قبل تاريخ بدايته.",
            effective_from=data["effective_from"].isoformat(), effective_to=data["effective_to"].isoformat(),
        )
    return data


def validate_no_overlapping_trade_remedy(db: Session, data: dict, exclude_id: Optional[int] = None) -> None:
    """Same measure type, HS code, origin and exporter may not be in force twice on the same day."""
    from fastapi import status
    from modules.common.errors import CodedHTTPException

    new_start = data["effective_from"]
    new_end = data.get("effective_to")
    for rec in repository.list_trade_remedy_measures_for_key(
        db, data["measure_type"], data["hs_code"], data.get("origin_country"), data.get("exporter_name")
    ):
        if exclude_id is not None and rec.measure_id == exclude_id:
            continue
        starts_before_other_ends = rec.effective_to is None or new_start <= rec.effective_to
        ends_after_other_starts = new_end is None or new_end >= rec.effective_from
        if starts_before_other_ends and ends_after_other_starts:
            raise CodedHTTPException(
                status.HTTP_409_CONFLICT, "TRM_OVERLAP",
                f"يوجد تدبير مسجل ({rec.measure_code}) لنفس البند وبلد المنشأ والمصدّر في نفس الفترة.",
                measure_code=rec.measure_code,
            )
