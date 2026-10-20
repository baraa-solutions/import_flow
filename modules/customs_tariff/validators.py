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
