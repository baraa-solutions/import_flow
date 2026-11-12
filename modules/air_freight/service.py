"""
Air freight suite business logic (Trello 6wcX4CQ6):

1. Chargeable weight engine: volumetric kg = L x W x H (cm) / divisor per package line (units normalised first:
   mm / cm / m, kg / lb); chargeable = max(gross, volumetric). Divisors come from system parameters
   (AIR 6000, COURIER 5000 by default) and can be overridden per record.
2. Air shipment records (AWB): CRUD with soft delete / restore; weight components are recomputed on every save.
3. Airport storage counter: free-storage countdown from the storage start date (default 3 free days).
4. Draft AWB review engine: compares a draft AWB with the record + import file and builds a checklist; blocking
   mismatches send the draft back for revision and prevent approval.
"""
from __future__ import annotations

import difflib
import re
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

from fastapi import status
from sqlalchemy.orm import Session

from modules.common import cargo_math, shipment_modes
from modules.common import system_parameters as sp
from modules.common.errors import CodedHTTPException
from modules.common.sequence_generator import generate_reference_code

from . import repository, validators
from .model import AirShipmentRecord, DraftAwbReviewSession
from .schemas import (
    AirPackageLine,
    AirShipmentRecordCreate,
    AirShipmentRecordUpdate,
    ChargeableWeightLine,
    ChargeableWeightRequest,
    ChargeableWeightResult,
    DraftAwbInput,
    DraftAwbReviewCreate,
    DraftAwbReviewDecision,
    StorageStatus,
)

RECORD_CODE_PREFIX = "AWB"
REVIEW_CODE_PREFIX = "AWBR"
NAME_MATCH_RATIO = 0.85

STATUS_REVISION_REQUIRED = "REVISION_REQUIRED"
STATUS_REVIEWED = "REVIEWED"
STATUS_APPROVED = "APPROVED"
STATUS_REJECTED = "REJECTED"


# ==================================================
# Configuration (system parameters, never hard-coded)
# ==================================================

def volumetric_divisor(db: Session, mode: Optional[str]) -> float:
    """Configured divisor for the mode: COURIER -> COURIER_VOLUMETRIC_DIVISOR, anything else -> AIR."""
    if shipment_modes.normalize_mode(mode) == shipment_modes.COURIER:
        return sp.get_float_parameter(
            db, sp.COURIER_VOLUMETRIC_DIVISOR, sp.DEFAULT_COURIER_VOLUMETRIC_DIVISOR, min_value=1
        )
    return sp.get_float_parameter(db, sp.AIR_VOLUMETRIC_DIVISOR, sp.DEFAULT_AIR_VOLUMETRIC_DIVISOR, min_value=1)


def free_storage_days(db: Session) -> int:
    return int(sp.get_float_parameter(db, sp.AIR_FREE_STORAGE_DAYS, sp.DEFAULT_AIR_FREE_STORAGE_DAYS, min_value=0))


def weight_tolerance_pct(db: Session) -> float:
    return sp.get_float_parameter(
        db, sp.AIR_AWB_WEIGHT_TOLERANCE_PCT, sp.DEFAULT_AIR_AWB_WEIGHT_TOLERANCE_PCT, min_value=0, max_value=100
    )


# ==================================================
# 1. Chargeable weight engine (pure)
# ==================================================

def compute_chargeable_weight(
    packages: Iterable[AirPackageLine],
    divisor: float,
    shipment_mode: str = shipment_modes.AIR,
    total_gross_weight_kg: Optional[float] = None,
) -> ChargeableWeightResult:
    """Totals over package lines. ``total_gross_weight_kg`` (already in kg) replaces the package gross sum when
    the packages carry no weight. Volumetric weights are rounded to 2 decimals, CBM to 4."""
    if divisor is None or divisor <= 0:
        raise ValueError("Volumetric divisor must be positive")
    lines: List[ChargeableWeightLine] = []
    pieces = 0
    gross = 0.0
    volume = 0.0
    volumetric = 0.0
    for pkg in packages:
        l_cm, w_cm, h_cm = cargo_math.to_cm(pkg.length, pkg.width, pkg.height, pkg.dimension_unit)
        line_gross = cargo_math.to_kg(pkg.gross_weight, pkg.weight_unit) * pkg.quantity
        line_volume = (l_cm * w_cm * h_cm) / cargo_math.CM3_PER_M3 * pkg.quantity
        line_volumetric = cargo_math.divisor_volumetric_weight_kg(
            pkg.length, pkg.width, pkg.height, pkg.dimension_unit, pkg.quantity, divisor
        )
        lines.append(ChargeableWeightLine(
            quantity=pkg.quantity, length_cm=round(l_cm, 2), width_cm=round(w_cm, 2), height_cm=round(h_cm, 2),
            gross_weight_kg=round(line_gross, 2), volume_cbm=round(line_volume, 4),
            volumetric_weight_kg=round(line_volumetric, 2),
        ))
        pieces += pkg.quantity
        gross += line_gross
        volume += line_volume
        volumetric += line_volumetric
    if gross <= 0 and total_gross_weight_kg:
        gross = float(total_gross_weight_kg)
    gross_r, volumetric_r = round(gross, 2), round(volumetric, 2)
    chargeable = max(gross_r, volumetric_r)
    return ChargeableWeightResult(
        shipment_mode=shipment_mode,
        divisor=float(divisor),
        pieces_count=pieces,
        gross_weight_kg=gross_r,
        volume_cbm=round(volume, 4),
        volumetric_weight_kg=volumetric_r,
        chargeable_weight_kg=chargeable,
        basis="VOLUMETRIC" if volumetric_r > gross_r else "GROSS",
        lines=lines,
    )


def calculate_chargeable_weight(db: Session, request: ChargeableWeightRequest) -> ChargeableWeightResult:
    mode, _ = validators.validate_air_mode(request.shipment_mode, None)
    divisor = request.divisor or volumetric_divisor(db, mode)
    total_gross = (
        cargo_math.to_kg(request.total_gross_weight, request.total_gross_weight_unit)
        if request.total_gross_weight is not None else None
    )
    return compute_chargeable_weight(request.packages, divisor, mode, total_gross)


# ==================================================
# 3. Airport storage counter (pure)
# ==================================================

def compute_storage_status(start_date: Optional[date], free_days: int, on_date: date) -> StorageStatus:
    """Day 1 of free storage is the start date: ``free_until = start + free_days - 1``.
    Before the start (or without one) the counter has not started."""
    free_days = max(int(free_days or 0), 0)
    if start_date is None or on_date < start_date:
        return StorageStatus(start_date=start_date, free_days=free_days, status="NOT_STARTED")
    free_until = start_date + timedelta(days=free_days - 1) if free_days > 0 else start_date - timedelta(days=1)
    remaining = (free_until - on_date).days
    if remaining > 0:
        state = "FREE"
    elif remaining == 0:
        state = "LAST_DAY"
    else:
        state = "CHARGEABLE"
    return StorageStatus(
        start_date=start_date, free_days=free_days, free_until=free_until, days_remaining=remaining,
        chargeable_days=max(-remaining, 0), status=state,
    )


def storage_status_of(db: Session, record: AirShipmentRecord, on_date: Optional[date] = None) -> StorageStatus:
    days = record.free_storage_days if record.free_storage_days is not None else free_storage_days(db)
    return compute_storage_status(record.airport_storage_start_date, days, on_date or date.today())


# ==================================================
# 2. Air shipment records
# ==================================================

def _record_not_found(air_record_id: int) -> CodedHTTPException:
    return CodedHTTPException(
        status.HTTP_404_NOT_FOUND, "AIR_RECORD_NOT_FOUND",
        f"سجل البوليصة الجوية رقم {air_record_id} غير موجود.", air_record_id=air_record_id,
    )


def get_air_record(db: Session, air_record_id: int) -> AirShipmentRecord:
    record = repository.get_air_record(db, air_record_id)
    if record is None:
        raise _record_not_found(air_record_id)
    return record


def list_air_records(db: Session, import_file_id: Optional[int] = None, include_inactive: bool = False) -> List[AirShipmentRecord]:
    return repository.list_air_records(db, import_file_id, include_inactive)


def _validated_fields(db: Session, data: Dict[str, Any], exclude_id: Optional[int] = None) -> Dict[str, Any]:
    """All validation + derived fields for a create / full update payload (dict of model fields)."""
    data["shipment_mode"], data["shipment_sub_mode"] = validators.validate_air_mode(
        data.get("shipment_mode"), data.get("shipment_sub_mode")
    )
    data["mawb_number"], data["airline_prefix"] = validators.validate_awb_number(data.get("mawb_number"))
    data["hawb_number"] = (data.get("hawb_number") or "").strip() or None
    validators.validate_airline(db, data.get("airline_id"))
    validators.validate_airport(db, data.get("origin_airport_id"))
    validators.validate_airport(db, data.get("destination_airport_id"))
    validators.validate_route(data.get("origin_airport_id"), data.get("destination_airport_id"))
    validators.validate_flight_dates(data.get("flight_date"), data.get("arrival_date"))
    validators.validate_no_duplicate_awb(db, data["mawb_number"], data["hawb_number"], exclude_id=exclude_id)
    _apply_weights(db, data)
    return data


def _apply_weights(db: Session, data: Dict[str, Any]) -> None:
    """Recompute volume / volumetric / chargeable from the package lines (or gross only).
    With package lines: pieces = sum of quantities; gross = package gross sum, or the entered gross when the
    packages carry no weight."""
    lines = [AirPackageLine.model_validate(line) for line in (data.get("package_lines") or [])]
    divisor = data.get("volumetric_divisor") or volumetric_divisor(db, data["shipment_mode"])
    data["volumetric_divisor"] = divisor
    data["package_lines"] = [line.model_dump() for line in lines] or None
    if lines:
        # Package lines are the more precise source: their pieces always win, their gross wins when weighed.
        result = compute_chargeable_weight(lines, divisor, data["shipment_mode"], data.get("gross_weight_kg"))
        data["gross_weight_kg"] = result.gross_weight_kg
        data["pieces_count"] = result.pieces_count
        data["volume_cbm"] = result.volume_cbm
        data["volumetric_weight_kg"] = result.volumetric_weight_kg
        data["chargeable_weight_kg"] = max(float(data["gross_weight_kg"] or 0.0), result.volumetric_weight_kg)
    else:
        data["volume_cbm"] = None
        data["volumetric_weight_kg"] = None
        gross = data.get("gross_weight_kg")
        data["chargeable_weight_kg"] = round(float(gross), 2) if gross is not None else None


def create_air_record(db: Session, payload: AirShipmentRecordCreate, user: str) -> AirShipmentRecord:
    validators.validate_import_file(db, payload.import_file_id)
    data = _validated_fields(db, payload.model_dump())
    record = AirShipmentRecord(**data, created_by=user, updated_by=user)
    record.air_record_code = generate_reference_code(db, AirShipmentRecord, RECORD_CODE_PREFIX, id_field="air_record_id")
    repository.add(db, record)
    db.commit()
    db.refresh(record)
    return record


_EDITABLE_FIELDS = tuple(AirShipmentRecordUpdate.model_fields)


def update_air_record(db: Session, air_record_id: int, payload: AirShipmentRecordUpdate, user: str) -> AirShipmentRecord:
    record = get_air_record(db, air_record_id)
    current = {field: getattr(record, field) for field in _EDITABLE_FIELDS}
    changes = payload.model_dump(exclude_unset=True)
    if "shipment_mode" in changes and "volumetric_divisor" not in changes:
        current["volumetric_divisor"] = None  # a new mode takes its own configured divisor
    current.update(changes)
    data = _validated_fields(db, current, exclude_id=air_record_id)
    for field, value in data.items():
        setattr(record, field, value)
    record.updated_by = user
    db.commit()
    db.refresh(record)
    return record


def soft_delete_air_record(db: Session, air_record_id: int, user: str) -> AirShipmentRecord:
    record = get_air_record(db, air_record_id)
    record.is_active = False
    record.deleted_at = datetime.now(timezone.utc)
    record.deleted_by = user
    record.updated_by = user
    db.commit()
    db.refresh(record)
    return record


def restore_air_record(db: Session, air_record_id: int, user: str) -> AirShipmentRecord:
    record = repository.get_air_record(db, air_record_id, include_inactive=True)
    if record is None:
        raise _record_not_found(air_record_id)
    validators.validate_no_duplicate_awb(db, record.mawb_number, record.hawb_number, exclude_id=air_record_id)
    record.is_active = True
    record.deleted_at = None
    record.deleted_by = None
    record.updated_by = user
    db.commit()
    db.refresh(record)
    return record


# ==================================================
# 4. Draft AWB review engine
# ==================================================

_NAME_CLEAN_RE = re.compile(r"[^A-Z0-9؀-ۿ]+")


def _clean_name(value: Optional[str]) -> str:
    return _NAME_CLEAN_RE.sub(" ", str(value or "").upper()).strip()


def names_match(draft: Optional[str], system: Optional[str], ratio: float = NAME_MATCH_RATIO) -> bool:
    a, b = _clean_name(draft), _clean_name(system)
    if not a or not b:
        return False
    return a == b or difflib.SequenceMatcher(None, a, b).ratio() >= ratio


def airport_code_matches(draft_code: Optional[str], un_locode: Optional[str]) -> bool:
    """Draft airport given as UN/LOCODE (``EGCAI``) or as the IATA-style last three letters (``CAI``)."""
    d = (draft_code or "").strip().upper().replace(" ", "")
    u = (un_locode or "").strip().upper().replace(" ", "")
    if not d or not u:
        return False
    return d == u or (len(d) == 3 and len(u) == 5 and u[2:] == d)


def _within_tolerance(draft: float, system: float, tolerance_pct: float) -> bool:
    if system == 0:
        return draft == 0
    return abs(draft - system) / system * 100.0 <= tolerance_pct + 1e-9


def build_reference_snapshot(record: AirShipmentRecord, import_file: Any, origin: Any, destination: Any) -> Dict[str, Any]:
    return {
        "awb_number": record.mawb_number,
        "consignee_name": getattr(import_file, "company_name", None),
        "shipper_name": getattr(import_file, "supplier_name", None),
        "origin_airport_code": getattr(origin, "un_locode", None),
        "destination_airport_code": getattr(destination, "un_locode", None),
        "pieces_count": record.pieces_count,
        "gross_weight_kg": record.gross_weight_kg,
        "chargeable_weight_kg": record.chargeable_weight_kg,
        "goods_description": record.goods_description,
    }


def review_draft_awb(
    draft: DraftAwbInput, reference: Dict[str, Any], tolerance_pct: float
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """``(checklist, blocking_reasons_coded)``. Pure: compares the draft with the reference snapshot.

    Blocking checks: AWB number (format, check digit, equals the record), consignee, origin / destination
    airport, pieces, gross weight (within tolerance) and an over-declared chargeable weight. Shipper name,
    goods description and an under-declared chargeable weight are warnings. A reference value that is not
    known yet is not compared (WARNING, non-blocking) so a partially entered record can still be reviewed."""
    checklist: List[Dict[str, Any]] = []
    blocking: List[Dict[str, Any]] = []

    def add(check: str, state: str, is_blocking: bool, draft_value: Any, system_value: Any) -> None:
        blocks = is_blocking and state in ("MISMATCH", "MISSING")
        checklist.append({
            "check": check, "status": state, "blocking": blocks,
            "draft_value": draft_value, "system_value": system_value,
        })
        if blocks:
            if state == "MISSING":
                blocking.append({"code": "AIR_REVIEW_FIELD_MISSING", "params": {"field": check}})
            else:
                blocking.append({"code": "AIR_REVIEW_FIELD_MISMATCH", "params": {
                    "field": check, "draft_value": str(draft_value), "system_value": str(system_value),
                }})

    # AWB number
    digits, _, error = validators.parse_awb_number(draft.awb_number)
    system_awb = reference.get("awb_number")
    if not (draft.awb_number or "").strip():
        add("awb_number", "MISSING", True, None, system_awb)
    elif error:
        checklist.append({"check": "awb_number", "status": "MISMATCH", "blocking": True,
                          "draft_value": draft.awb_number, "system_value": system_awb})
        blocking.append({"code": error, "params": {"awb_number": str(draft.awb_number)}})
    elif system_awb is None:
        add("awb_number", "WARNING", False, digits, None)
    else:
        add("awb_number", "MATCH" if digits == system_awb else "MISMATCH", True, digits, system_awb)

    # Names
    for check, is_blocking in (("consignee_name", True), ("shipper_name", False)):
        draft_value, system_value = getattr(draft, check), reference.get(check)
        if not (draft_value or "").strip():
            add(check, "MISSING" if is_blocking else "WARNING", is_blocking, None, system_value)
        elif not system_value:
            add(check, "WARNING", False, draft_value, None)
        elif names_match(draft_value, system_value):
            add(check, "MATCH", is_blocking, draft_value, system_value)
        else:
            add(check, "MISMATCH" if is_blocking else "WARNING", is_blocking, draft_value, system_value)

    # Airports
    for check in ("origin_airport_code", "destination_airport_code"):
        draft_value, system_value = getattr(draft, check), reference.get(check)
        if not (draft_value or "").strip():
            add(check, "MISSING", True, None, system_value)
        elif not system_value:
            add(check, "WARNING", False, draft_value, None)
        else:
            state = "MATCH" if airport_code_matches(draft_value, system_value) else "MISMATCH"
            add(check, state, True, draft_value, system_value)

    # Pieces
    system_pieces = reference.get("pieces_count")
    if draft.pieces_count is None:
        add("pieces_count", "MISSING", True, None, system_pieces)
    elif system_pieces is None:
        add("pieces_count", "WARNING", False, draft.pieces_count, None)
    else:
        add("pieces_count", "MATCH" if draft.pieces_count == system_pieces else "MISMATCH", True,
            draft.pieces_count, system_pieces)

    # Gross weight (tolerance)
    system_gross = reference.get("gross_weight_kg")
    if draft.gross_weight_kg is None:
        add("gross_weight_kg", "MISSING", True, None, system_gross)
    elif system_gross is None:
        add("gross_weight_kg", "WARNING", False, draft.gross_weight_kg, None)
    elif _within_tolerance(draft.gross_weight_kg, float(system_gross), tolerance_pct):
        add("gross_weight_kg", "MATCH", True, draft.gross_weight_kg, system_gross)
    else:
        checklist.append({"check": "gross_weight_kg", "status": "MISMATCH", "blocking": True,
                          "draft_value": draft.gross_weight_kg, "system_value": system_gross})
        blocking.append({"code": "AIR_REVIEW_WEIGHT_OUT_OF_TOLERANCE", "params": {
            "field": "gross_weight_kg", "draft_value": str(draft.gross_weight_kg),
            "system_value": str(system_gross), "tolerance_pct": tolerance_pct,
        }})

    # Chargeable weight: billing basis. Over-declared blocks (overcharge), under-declared warns.
    system_chg = reference.get("chargeable_weight_kg")
    if draft.chargeable_weight_kg is None:
        add("chargeable_weight_kg", "WARNING", False, None, system_chg)
    elif system_chg is None:
        add("chargeable_weight_kg", "WARNING", False, draft.chargeable_weight_kg, None)
    elif _within_tolerance(draft.chargeable_weight_kg, float(system_chg), tolerance_pct):
        add("chargeable_weight_kg", "MATCH", True, draft.chargeable_weight_kg, system_chg)
    elif draft.chargeable_weight_kg > float(system_chg):
        checklist.append({"check": "chargeable_weight_kg", "status": "MISMATCH", "blocking": True,
                          "draft_value": draft.chargeable_weight_kg, "system_value": system_chg})
        blocking.append({"code": "AIR_REVIEW_WEIGHT_OUT_OF_TOLERANCE", "params": {
            "field": "chargeable_weight_kg", "draft_value": str(draft.chargeable_weight_kg),
            "system_value": str(system_chg), "tolerance_pct": tolerance_pct,
        }})
    else:
        add("chargeable_weight_kg", "WARNING", False, draft.chargeable_weight_kg, system_chg)

    # Goods description (warning only)
    system_desc = reference.get("goods_description")
    if draft.goods_description and system_desc:
        state = "MATCH" if names_match(draft.goods_description, system_desc, 0.6) else "WARNING"
        add("goods_description", state, False, draft.goods_description, system_desc)

    return checklist, blocking


def _review_not_found(awb_review_id: int) -> CodedHTTPException:
    return CodedHTTPException(
        status.HTTP_404_NOT_FOUND, "AIR_REVIEW_NOT_FOUND",
        f"جلسة مراجعة البوليصة الجوية رقم {awb_review_id} غير موجودة.", awb_review_id=awb_review_id,
    )


def create_review(db: Session, payload: DraftAwbReviewCreate, user: str) -> DraftAwbReviewSession:
    record = get_air_record(db, payload.air_record_id)
    import_file = repository.get_import_file(db, record.import_file_id)
    origin = repository.get_location(db, record.origin_airport_id) if record.origin_airport_id else None
    destination = repository.get_location(db, record.destination_airport_id) if record.destination_airport_id else None
    reference = build_reference_snapshot(record, import_file, origin, destination)
    checklist, blocking = review_draft_awb(payload.draft, reference, weight_tolerance_pct(db))
    now = datetime.now(timezone.utc)
    digits, _, _ = validators.parse_awb_number(payload.draft.awb_number)
    session = DraftAwbReviewSession(
        air_record_id=record.air_record_id,
        import_file_id=record.import_file_id,
        version_number=repository.latest_review_version(db, record.air_record_id) + 1,
        draft_awb_number=digits or (payload.draft.awb_number or None),
        draft_input_data=payload.draft.model_dump(),
        system_snapshot_data=reference,
        checklist_data=checklist,
        blocking_reasons_coded=blocking,
        has_blocking_mismatch=bool(blocking),
        open_discrepancies_count=len(blocking),
        status=STATUS_REVISION_REQUIRED if blocking else STATUS_REVIEWED,
        reviewed_by=user,
        reviewed_at=now,
        created_by=user,
        updated_by=user,
    )
    session.awb_review_code = generate_reference_code(db, DraftAwbReviewSession, REVIEW_CODE_PREFIX, id_field="awb_review_id")
    repository.add(db, session)
    db.commit()
    db.refresh(session)
    return session


def list_reviews(db: Session, air_record_id: int) -> List[DraftAwbReviewSession]:
    get_air_record(db, air_record_id)
    return repository.list_reviews(db, air_record_id)


def decide_review(db: Session, awb_review_id: int, payload: DraftAwbReviewDecision, user: str) -> DraftAwbReviewSession:
    session = repository.get_review(db, awb_review_id)
    if session is None:
        raise _review_not_found(awb_review_id)
    if session.status in (STATUS_APPROVED, STATUS_REJECTED):
        raise CodedHTTPException(
            status.HTTP_409_CONFLICT, "AIR_REVIEW_ALREADY_DECIDED",
            "تم اتخاذ قرار نهائي في هذه المراجعة بالفعل.", status=session.status,
        )
    if payload.decision == "APPROVE" and session.has_blocking_mismatch:
        raise CodedHTTPException(
            status.HTTP_409_CONFLICT, "AIR_REVIEW_BLOCKING_MISMATCH",
            f"لا يمكن اعتماد مسودة البوليصة الجوية مع وجود {session.open_discrepancies_count} اختلاف جوهري.",
            open_discrepancies_count=session.open_discrepancies_count,
        )
    session.status = STATUS_APPROVED if payload.decision == "APPROVE" else STATUS_REJECTED
    session.approved_by = user
    session.approved_at = datetime.now(timezone.utc)
    session.decision_notes = payload.notes
    session.updated_by = user
    db.commit()
    db.refresh(session)
    return session
