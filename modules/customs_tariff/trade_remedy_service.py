"""
Trade remedies (MD-008C): anti-dumping, safeguard and countervailing duties.

Rates come only from registered, effective measures (decree reference + effective dates). The engine
never assumes a rate: when an item needs data it does not have (origin, exporter, weight, quantity or a
customs exchange rate) it refuses with a coded error instead of computing a partial figure.
"""
from datetime import date, datetime, timezone
from decimal import ROUND_HALF_UP, Decimal
from typing import Any, Dict, List, Optional, Tuple

from fastapi import status
from sqlalchemy.orm import Session

from modules.common.errors import CodedHTTPException
from modules.common.sequence_generator import generate_reference_code

from . import repository, validators
from .model import TradeRemedyMeasure
from .schemas import TradeRemedyLineDuty, TradeRemedyMeasureCreate, TradeRemedyMeasureUpdate

MEASURE_CODE_PREFIX = "TRM"
KG_PER_TON = Decimal("1000")


def _round(value: Any) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


# ==================================================
# CRUD
# ==================================================

def _not_found(measure_id: int) -> CodedHTTPException:
    return CodedHTTPException(
        status.HTTP_404_NOT_FOUND, "TRM_NOT_FOUND",
        f"تدبير الحماية التجارية رقم {measure_id} غير موجود.", measure_id=measure_id,
    )


def list_trade_remedy_measures(
    db: Session,
    hs_code: Optional[str] = None,
    origin_country: Optional[str] = None,
    measure_type: Optional[str] = None,
    include_inactive: bool = False,
) -> List[TradeRemedyMeasure]:
    return repository.list_trade_remedy_measures(db, hs_code, origin_country, measure_type, include_inactive)


def create_trade_remedy_measure(db: Session, payload: TradeRemedyMeasureCreate, user: str) -> TradeRemedyMeasure:
    data = validators.validate_trade_remedy_fields(payload.model_dump())
    validators.validate_no_overlapping_trade_remedy(db, data)
    measure = TradeRemedyMeasure(**data, created_by=user, updated_by=user)
    measure.measure_code = generate_reference_code(db, TradeRemedyMeasure, MEASURE_CODE_PREFIX, id_field="measure_id")
    db.add(measure)
    db.commit()
    db.refresh(measure)
    return measure


def update_trade_remedy_measure(
    db: Session, measure_id: int, payload: TradeRemedyMeasureUpdate, user: str
) -> TradeRemedyMeasure:
    measure = repository.get_trade_remedy_measure(db, measure_id)
    if measure is None:
        raise _not_found(measure_id)
    current = {
        field: getattr(measure, field)
        for field in TradeRemedyMeasureCreate.model_fields
    }
    current.update(payload.model_dump(exclude_unset=True))
    data = validators.validate_trade_remedy_fields(current)
    validators.validate_no_overlapping_trade_remedy(db, data, exclude_id=measure_id)
    for field, value in data.items():
        setattr(measure, field, value)
    measure.updated_by = user
    db.commit()
    db.refresh(measure)
    return measure


def soft_delete_trade_remedy_measure(db: Session, measure_id: int, user: str) -> TradeRemedyMeasure:
    measure = repository.get_trade_remedy_measure(db, measure_id)
    if measure is None:
        raise _not_found(measure_id)
    measure.is_active = False
    measure.deleted_at = datetime.now(timezone.utc)
    measure.deleted_by = user
    measure.updated_by = user
    db.commit()
    db.refresh(measure)
    return measure


def restore_trade_remedy_measure(db: Session, measure_id: int, user: str) -> TradeRemedyMeasure:
    measure = repository.get_trade_remedy_measure(db, measure_id, include_inactive=True)
    if measure is None:
        raise _not_found(measure_id)
    data = {field: getattr(measure, field) for field in TradeRemedyMeasureCreate.model_fields}
    validators.validate_no_overlapping_trade_remedy(db, data, exclude_id=measure_id)
    measure.is_active = True
    measure.deleted_at = None
    measure.deleted_by = None
    measure.updated_by = user
    db.commit()
    db.refresh(measure)
    return measure


# ==================================================
# Duty resolution used by the customs calculation engine
# ==================================================

def _specificity(measure: TradeRemedyMeasure) -> Tuple[int, int, int]:
    return (
        1 if measure.exporter_name else 0,
        1 if measure.origin_country else 0,
        len(measure.hs_code or ""),
    )


def _select_measure(
    candidates: List[TradeRemedyMeasure], hs_code: str, origin: Optional[str], exporter: Optional[str]
) -> Optional[TradeRemedyMeasure]:
    """Most specific measure of one type that applies to this origin / exporter, or a coded refusal."""
    if any(m.origin_country for m in candidates) and not origin:
        raise CodedHTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "CT_TRADE_REMEDY_ORIGIN_MISSING",
            f"البند {hs_code} عليه تدبير حماية تجارية حسب بلد المنشأ؛ حدّد بلد المنشأ لحساب الرسم.",
            hs_code=hs_code, measure_type=candidates[0].measure_type,
        )
    by_origin = [m for m in candidates if m.origin_country in (None, origin)]
    if not by_origin:
        return None
    exporter_key = (exporter or "").strip().casefold()
    matched = [m for m in by_origin if m.exporter_name and m.exporter_name.strip().casefold() == exporter_key]
    if matched:
        return max(matched, key=_specificity)
    residual = [m for m in by_origin if not m.exporter_name]
    if residual:
        return max(residual, key=_specificity)
    raise CodedHTTPException(
        status.HTTP_422_UNPROCESSABLE_CONTENT, "CT_TRADE_REMEDY_EXPORTER_MISSING",
        f"تدبير الحماية على البند {hs_code} محدد لمصدّرين بعينهم؛ حدّد اسم المصدّر لحساب الرسم.",
        hs_code=hs_code, measure_type=by_origin[0].measure_type,
    )


def _measure_amount_egp(
    db: Session, measure: TradeRemedyMeasure, hs_code: str, cif_egp: Decimal,
    weight_kg: Decimal, qty: Decimal, on_date: date,
) -> TradeRemedyLineDuty:
    if measure.duty_basis == "PERCENT_OF_CIF":
        rate = Decimal(str(measure.rate_percent))
        return TradeRemedyLineDuty(
            measure_code=measure.measure_code, measure_type=measure.measure_type,
            duty_basis=measure.duty_basis, decree_ref=measure.decree_ref, rate_percent=rate,
            amount_egp=_round(cif_egp * rate / Decimal("100")),
        )

    if measure.duty_basis == "FIXED_PER_TON":
        units = Decimal(str(weight_kg or 0)) / KG_PER_TON
    else:
        units = Decimal(str(qty or 0))
    if units <= 0:
        raise CodedHTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "CT_TRADE_REMEDY_QTY_MISSING",
            f"رسم الحماية على البند {hs_code} محسوب {'بالطن' if measure.duty_basis == 'FIXED_PER_TON' else 'بالوحدة'}؛ "
            "أدخل الوزن أو الكمية الفعلية للصنف.",
            hs_code=hs_code, duty_basis=measure.duty_basis,
        )
    from .tariff_calculation_service import _customs_rate  # local import: the engine imports this module

    fx, _, _ = _customs_rate(db, measure.fixed_currency, on_date)
    amount = Decimal(str(measure.fixed_amount))
    return TradeRemedyLineDuty(
        measure_code=measure.measure_code, measure_type=measure.measure_type,
        duty_basis=measure.duty_basis, decree_ref=measure.decree_ref,
        fixed_amount=amount, fixed_currency=measure.fixed_currency, exchange_rate=fx,
        amount_egp=_round(units * amount * fx),
    )


def resolve_trade_remedy_duties(
    db: Session,
    hs_code: str,
    origin_country: Optional[str],
    exporter_name: Optional[str],
    cif_egp: Decimal,
    weight_kg: Decimal,
    qty: Decimal,
    on_date: date,
) -> Tuple[Decimal, List[TradeRemedyLineDuty]]:
    """Total trade-remedy duty (EGP) on one item and the measures it came from; (0, []) when none applies."""
    measures = repository.find_effective_trade_remedy_measures(db, hs_code, on_date)
    if not measures:
        return Decimal("0.00"), []
    origin = (origin_country or "").strip().upper() or None
    by_type: Dict[str, List[TradeRemedyMeasure]] = {}
    for measure in measures:
        by_type.setdefault(measure.measure_type, []).append(measure)

    applied: List[TradeRemedyLineDuty] = []
    for measure_type in sorted(by_type):
        chosen = _select_measure(by_type[measure_type], hs_code, origin, exporter_name)
        if chosen is not None:
            applied.append(_measure_amount_egp(db, chosen, hs_code, cif_egp, weight_kg, qty, on_date))
    total = sum((duty.amount_egp for duty in applied), Decimal("0.00"))
    return _round(total), applied


def trade_remedy_notice(
    flagged_hs_codes: List[str], applied: List[TradeRemedyLineDuty]
) -> Tuple[Optional[str], Optional[dict]]:
    """Coded notice for the breakdown (rendered from the message catalog, never stored as text).

    CT_TRADE_REMEDY_DEPOSIT     a measure was applied: its proceeds go to the special deposit account.
    CT_TRADE_REMEDY_RATE_MISSING the tariff item is flagged (e.g. Nafeza 'غ' line) but no effective measure
                                 is registered, so no trade-remedy duty is included in the total.
    """
    if applied:
        decrees = sorted({duty.decree_ref for duty in applied})
        return "CT_TRADE_REMEDY_DEPOSIT", {"decree_refs": ", ".join(decrees)}
    if flagged_hs_codes:
        return "CT_TRADE_REMEDY_RATE_MISSING", {"hs_codes": ", ".join(sorted(set(flagged_hs_codes)))}
    return None, None
