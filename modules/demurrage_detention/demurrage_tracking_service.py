import json
import logging
import re
from dataclasses import dataclass, replace
from datetime import datetime, timezone, date, timedelta
from typing import Callable, List, Dict, Any, Optional, Tuple
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.orm.attributes import flag_modified
from fastapi import HTTPException, status

from modules.common.errors import best_effort
from modules.common.system_parameters import get_float_parameter, get_parameter
from modules.common.validators import not_found, require_active
from modules.import_files.model import ImportFile

from .model import DemurragePolicy, DemurrageTracking, Terminal, TerminalStorageRate, Carrier, CarrierDemurrageRate
from .schemas import (
    DemurragePolicyCreate,
    DemurragePolicyUpdate,
    DemurrageTrackingCreate,
    DemurrageTrackingUpdate,
    DemurrageSimulationRequest,
    DemurrageSimulationResponse,
    PushToSettlementRequest,
    TierRateItem,
    CarrierDemurrageClock,
    PortStorageClock,
    DualClockResponse,
    ContainerIndividualUpdate,
    FreeDaysAgreementRegister,
    FreeDaysAgreementResponse,
    ContainerRadarItem,
    ContainerRadarOverviewResponse,
    EmptyContainerReturnSubmit,
    EmptyContainerReturnResponse,
    TerminalCreate,
    TerminalUpdate,
    TerminalResponse,
    TerminalStorageRateCreate,
    TerminalStorageRateResponse,
    CarrierCreate,
    CarrierUpdate,
    CarrierResponse,
    CarrierDemurrageRateCreate,
    CarrierDemurrageRateResponse,
)
from .validators import (
    validate_tier_rates,
    validate_demurrage_dates,
    validate_positive_amount,
    validate_no_active_tracking_for_file,
    validate_no_active_tracking_for_bl,
)
from . import repository
from modules.common import enum_codes
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking, _file_past_step
from modules.common.clock import cairo_today

# Prefix of the free-days agreement note kept in ImportFile.shipping_instructions_notes.
FREE_DAYS_NOTE_PREFIX = "Free days agreement: "
LEGACY_FREE_DAYS_NOTE_PREFIX = "اتفاقية فترات السماح: "

logger = logging.getLogger(__name__)


DEFAULT_DEMURRAGE_TIERS = [
    {"from_day": 1, "to_day": 7, "rate_per_day": 40.0},
    {"from_day": 8, "to_day": 14, "rate_per_day": 70.0},
    {"from_day": 15, "to_day": None, "rate_per_day": 120.0},
]

DEFAULT_DETENTION_TIERS = [
    {"from_day": 1, "to_day": 7, "rate_per_day": 35.0},
    {"from_day": 8, "to_day": 14, "rate_per_day": 65.0},
    {"from_day": 15, "to_day": None, "rate_per_day": 110.0},
]

# System parameter keys (seeded by the lead). The module constants hold today's values and are only used when
# a key is missing or invalid, so the numbers stay identical.
DD_DEFAULT_DEMURRAGE_TIERS = "DD_DEFAULT_DEMURRAGE_TIERS"
DD_DEFAULT_DETENTION_TIERS = "DD_DEFAULT_DETENTION_TIERS"
DD_DEFAULT_FREE_DAYS_DEMURRAGE = "DD_DEFAULT_FREE_DAYS_DEMURRAGE"
DD_DEFAULT_FREE_DAYS_DETENTION = "DD_DEFAULT_FREE_DAYS_DETENTION"
DD_DEFAULT_STORAGE_FREE_DAYS = "DD_DEFAULT_STORAGE_FREE_DAYS"
DD_DEFAULT_STORAGE_RATE_EGP = "DD_DEFAULT_STORAGE_RATE_EGP"
DD_DEFAULT_TARIFF_CURRENCY = "DD_DEFAULT_TARIFF_CURRENCY"
DD_STANDARD_FREE_DAYS = "DD_STANDARD_FREE_DAYS"
DD_DEFAULT_NEGOTIATED_FREE_DAYS = "DD_DEFAULT_NEGOTIATED_FREE_DAYS"
DD_AVOIDANCE_RATE_USD = "DD_AVOIDANCE_RATE_USD"
DEFAULT_FREE_DAYS_DEMURRAGE = 5
DEFAULT_FREE_DAYS_DETENTION = 7
DEFAULT_STORAGE_FREE_DAYS = 7
DEFAULT_STORAGE_RATE_EGP = 250.0
DEFAULT_TARIFF_CURRENCY = "USD"
DEFAULT_STANDARD_FREE_DAYS = 5
DEFAULT_NEGOTIATED_DEMURRAGE_DAYS = 21
DEFAULT_AVOIDANCE_RATE_USD = 70.0

# Keys of a tracking container written by the calculation; every other key (EIR, seal, per-container dates,
# condition, damage, depot, notes) is kept on recalculation.
COMPUTED_CONTAINER_KEYS = ("demurrage_days", "detention_days", "storage_days", "demurrage_fx", "detention_fx", "storage_egp", "total_egp", "status")



from .demurrage_calculation_service import (
    _today,
    Tariff, default_tariff, _resolve_tariff, _booking_free_days, _agreed_tariff,
    _tracking_tariff, _settlement_invoice_nos, _settlement_rows, _write_settlement_rows,
    _repush_recalculated, _recalculate_settlement_follow_up, _tracking_rate,
    _resolve_exchange_rate, _parse_date, _recalculate_containers, _apply_totals,
    _incurred_status, calculate_tiered_fee, simulate_demurrage_and_detention,
    calculate_demurrage_detention_service, simulate_with_defaults,
    PUSHED_STATUS
)

def create_demurrage_tracking_service(
    db: Session, req: DemurrageTrackingCreate, user: str = "System"
) -> DemurrageTracking:
    file_code = None
    if req.import_file_id:
        imp_file = require_active(db, ImportFile, req.import_file_id, "ملف الاستيراد", status_code=status.HTTP_404_NOT_FOUND)
        file_code = imp_file.custom_file_number or imp_file.import_file_code
        existing = repository.get_active_tracking_for_file(db, req.import_file_id)
        validate_no_active_tracking_for_file(existing)
    else:
        existing = repository.get_active_tracking_for_bl(db, req.bill_of_lading_no)
        validate_no_active_tracking_for_bl(existing, req.bill_of_lading_no)

    validate_demurrage_dates(req.discharge_date, req.gate_out_date, req.empty_return_date, today=cairo_today())

    # Fetch policy if provided or search matching policy (DD-10: first container type, pinned until Q13)
    policy = None
    # Auto-resolve carrier and terminal IDs if not explicitly passed
    carrier_id = req.carrier_id
    if not carrier_id and req.carrier_name:
        carrier_obj = repository.find_carrier_by_name(db, req.carrier_name)
        if carrier_obj:
            carrier_id = carrier_obj.carrier_id

    terminal_id = req.terminal_id
    if not terminal_id and req.port_name:
        terminal_obj = repository.find_terminal_for_port(db, req.port_name)
        if terminal_obj:
            terminal_id = terminal_obj.terminal_id

    # Fetch policy if provided or search matching policy (DD-10: first container type, pinned until Q13)
    policy = None
    first_container_type = req.containers[0].container_type if req.containers else "40ft High Cube"
    if req.policy_id:
        policy = repository.get_policy_by_id(db, req.policy_id)
    if not policy and req.carrier_name:
        policy = repository.get_policy_for_carrier_container(db, req.carrier_name, first_container_type)

    resolved_tariff = _resolve_tariff(
        db,
        policy,
        carrier_id=carrier_id,
        carrier_name=req.carrier_name,
        terminal_id=terminal_id,
        port_name=req.port_name,
        container_type=first_container_type,
        discharge_date=req.discharge_date,
    )
    tariff = _agreed_tariff(resolved_tariff, _booking_free_days(db, req.import_file_id), None)
    tracking_currency = tariff.currency

    if req.currency and req.currency.strip().upper() != tracking_currency.strip().upper():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"عملة جلسة التتبع ({req.currency}) تختلف عن عملة سياسة الخط الملاحي ({tracking_currency}).",
        )

    if req.exchange_rate is not None:
        validate_positive_amount(req.exchange_rate, "exchange_rate")
        rate = float(req.exchange_rate)
    else:
        # DD-09: no client default of 50 any more; the bank rate at the discharge date is used
        rate = _resolve_exchange_rate(db, tracking_currency, req.discharge_date)

    tracking = DemurrageTracking(
        import_file_id=req.import_file_id,
        import_file_code=file_code,
        policy_id=policy.policy_id if policy else None,
        carrier_id=carrier_id,
        terminal_id=terminal_id,
        carrier_name=req.carrier_name,
        bill_of_lading_no=req.bill_of_lading_no,
        port_name=req.port_name,
        discharge_date=req.discharge_date,
        gate_out_date=req.gate_out_date,
        empty_return_date=req.empty_return_date,
        containers=[{"container_no": c.container_no, "container_type": c.container_type} for c in req.containers],
        ancillary_fees=req.ancillary_fees or [],
        currency=tracking_currency,
        exchange_rate=rate,
        notes=req.notes,
    )
    containers, dem, det, stor = _recalculate_containers(tracking, tariff, rate, req.gate_out_date, req.empty_return_date)
    _apply_totals(tracking, containers, dem, det, stor, rate)
    tracking.status = _incurred_status(dem, det)

    try:
        repository.add_tracking(db, tracking, user=user)
        db.commit()
    except IntegrityError:
        # a concurrent create took the same DND code: retry once with the next one
        db.rollback()
        db.expunge_all()
        tracking = DemurrageTracking(**{c: getattr(tracking, c) for c in (
            "import_file_id", "import_file_code", "policy_id", "carrier_id", "terminal_id",
            "carrier_name", "bill_of_lading_no", "port_name", "discharge_date", "gate_out_date",
            "empty_return_date", "containers", "ancillary_fees", "total_demurrage_fx",
            "total_detention_fx", "total_storage_egp", "currency", "exchange_rate", "total_cost_egp", "status", "notes",
        )})
        repository.add_tracking(db, tracking, user=user)
        db.commit()
    db.refresh(tracking)
    return tracking


def get_demurrage_trackings_service(
    db: Session,
    import_file_id: Optional[int] = None,
    carrier_name: Optional[str] = None,
    status_filter: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[DemurrageTracking], int]:
    return repository.get_trackings(db, import_file_id=import_file_id, carrier_name=carrier_name, status_filter=status_filter, skip=skip, limit=limit)


def get_demurrage_tracking_by_id_service(db: Session, tracking_id: int) -> DemurrageTracking:
    tracking = repository.get_tracking_by_id(db, tracking_id)
    if not tracking:
        raise not_found("جلسة تتبع الحاويات", tracking_id)
    return tracking


def delete_demurrage_tracking_service(db: Session, tracking_id: int, user: str = "System") -> DemurrageTracking:
    tracking = repository.get_tracking_by_id(db, tracking_id)
    if not tracking:
        raise not_found("جلسة تتبع الحاويات", tracking_id)
    if tracking.is_pushed_to_settlement:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="لا يمكن حذف جلسة تتبع الحاويات بعد ترحيلها للتسوية المالية.",
        )
    repository.delete_tracking(db, tracking, user=user)
    db.commit()
    db.refresh(tracking)
    return tracking


def restore_demurrage_tracking_service(db: Session, tracking_id: int, user: str = "System") -> DemurrageTracking:
    tracking = repository.get_tracking_by_id(db, tracking_id, include_inactive=True)
    if not tracking:
        raise not_found("جلسة تتبع الحاويات", tracking_id)
    if tracking.is_active:
        return tracking

    if tracking.import_file_id:
        existing_file = repository.get_active_tracking_for_file(db, tracking.import_file_id)
        if existing_file and existing_file.tracking_id != tracking.tracking_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"يوجد بالفعل جلسة تتبع حاويات نشطة لهذا الملف ({existing_file.tracking_code}).",
            )

    if tracking.bill_of_lading_no:
        existing_bl = repository.get_active_tracking_for_bl(db, tracking.bill_of_lading_no)
        if existing_bl and existing_bl.tracking_id != tracking.tracking_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"يوجد بالفعل جلسة تتبع حاويات نشطة لبوليصة الشحن رقم {tracking.bill_of_lading_no} ({existing_bl.tracking_code}).",
            )

    tracking.is_active = True
    tracking.updated_by = user
    tracking.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(tracking)
    return tracking



def _require_settlement_permission(db: Session, actor: Any) -> None:
    if actor is not None:
        from modules.auth.permissions import has_user_permission
        if not has_user_permission(db, actor, "financial_settlement.calculate"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="ترحيل الغرامات إلى التسوية المالية يتطلب صلاحية حساب تكلفة الوصول (financial_settlement.calculate).",
            )


def _sync_containers_from_tracking(db: Session, tracking: DemurrageTracking, user: str) -> None:
    """DEV-OPS-01: Synchronize demurrage calculation outputs to independent ShipmentContainer entities."""
    try:
        from modules.containers.model import ShipmentContainer
        if not tracking.import_file_id or not isinstance(tracking.containers, list):
            return
        containers = db.query(ShipmentContainer).filter(
            ShipmentContainer.import_file_id == tracking.import_file_id,
            ShipmentContainer.is_active == True,
        ).all()
        if not containers:
            return
        c_map = {str(c.get("container_no", "")).strip().upper(): c for c in tracking.containers}
        for sc in containers:
            c_data = c_map.get(sc.container_number)
            if c_data:
                sc.demurrage_tracking_id = tracking.tracking_id
                gate_out = c_data.get("gate_out_date") or tracking.gate_out_date
                if gate_out:
                    if isinstance(gate_out, str):
                        try:
                            gate_out = date.fromisoformat(gate_out[:10])
                        except ValueError:
                            gate_out = None
                    if gate_out:
                        sc.gate_out_date = gate_out
                empty_ret = c_data.get("empty_return_date") or tracking.empty_return_date
                if empty_ret:
                    if isinstance(empty_ret, str):
                        try:
                            empty_ret = date.fromisoformat(empty_ret[:10])
                        except ValueError:
                            empty_ret = None
                    if empty_ret:
                        sc.empty_return_date = empty_ret
                sc.demurrage_days = int(c_data.get("demurrage_days") or 0)
                sc.detention_days = int(c_data.get("detention_days") or 0)
                sc.storage_days = int(c_data.get("storage_days") or 0)
                sc.demurrage_cost_fx = float(c_data.get("demurrage_fx") or 0.0)
                sc.detention_cost_fx = float(c_data.get("detention_fx") or 0.0)
                sc.storage_cost_egp = float(c_data.get("storage_egp") or 0.0)
                sc.total_cost_egp = float(c_data.get("total_egp") or 0.0)
                sc.individual_demurrage_cost = round(sc.demurrage_cost_fx + sc.detention_cost_fx, 2)
                if c_data.get("eir_timestamp") and not sc.eir_timestamp:
                    try:
                        sc.eir_timestamp = datetime.fromisoformat(str(c_data["eir_timestamp"]))
                    except Exception:
                        pass
                if c_data.get("gate_out_timestamp") and not sc.gate_out_timestamp:
                    try:
                        sc.gate_out_timestamp = datetime.fromisoformat(str(c_data["gate_out_timestamp"]))
                    except Exception:
                        pass
                if c_data.get("status"):
                    sc.status = c_data["status"]
                sc.updated_by = user
    except Exception as exc:
        logger.warning("Failed to sync containers from tracking: %s", exc)


def recalculate_and_update_tracking_service(
    db: Session, tracking_id: int, req: DemurrageTrackingUpdate, user: str = "System", actor: Any = None
) -> DemurrageTracking:
    tracking = get_demurrage_tracking_by_id_service(db, tracking_id)
    if actor is not None and tracking.is_pushed_to_settlement:
        _require_settlement_permission(db, actor)
    sent = req.model_fields_set

    # explicit null clears a date; an omitted field keeps the stored value
    gate_out = req.gate_out_date if "gate_out_date" in sent else tracking.gate_out_date
    empty_return = req.empty_return_date if "empty_return_date" in sent else tracking.empty_return_date
    if req.exchange_rate is not None:
        validate_positive_amount(req.exchange_rate, "exchange_rate")
        rate = float(req.exchange_rate)
    else:
        rate = _tracking_rate(tracking)
    validate_demurrage_dates(tracking.discharge_date, gate_out, empty_return, today=cairo_today())

    tariff = _tracking_tariff(db, tracking)
    containers, dem, det, stor = _recalculate_containers(tracking, tariff, rate, gate_out, empty_return)

    tracking.gate_out_date = gate_out
    tracking.empty_return_date = empty_return
    tracking.exchange_rate = rate
    if "ancillary_fees" in sent and req.ancillary_fees is not None:
        tracking.ancillary_fees = req.ancillary_fees
        flag_modified(tracking, "ancillary_fees")
    _apply_totals(tracking, containers, dem, det, stor, rate)
    # status: computed, or "Closed" when the user closes the session (other free text is ignored);
    # a pushed tracking keeps "Pushed to Settlement" and its settlement rows follow the new totals
    tracking.status = "Closed" if req.status == "Closed" else _incurred_status(dem, det)
    settlement_id, warning = _repush_recalculated(db, tracking, user)
    if "notes" in sent:
        tracking.notes = req.notes
    tracking.updated_by = user
    tracking.updated_at = datetime.now(timezone.utc)
    _sync_containers_from_tracking(db, tracking, user)
    db.commit()
    _recalculate_settlement_follow_up(db, settlement_id, user)
    db.refresh(tracking)
    tracking.settlement_warning_code = warning
    return tracking


def push_demurrage_to_financial_settlement_service(
    db: Session,
    req: PushToSettlementRequest,
    user: str = "System",
    actor: Any = None,
    calc_date: Optional[date] = None,
) -> Dict[str, Any]:
    """
    Pushes calculated Demurrage, Detention, and Storage expenses into the Phase 9 settlement record of the file
    (two rows: carrier charges and port storage), then recalculates the landed-cost totals through the
    settlement engine. ``actor`` (the logged-in User, passed by the router) must also hold
    ``financial_settlement.calculate``: the push writes settlement rows.
    """
    _require_settlement_permission(db, actor)
    tracking = get_demurrage_tracking_by_id_service(db, req.tracking_id)
    file_id = tracking.import_file_id
    if req.import_file_id and file_id and req.import_file_id != file_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"جلسة التتبع {tracking.tracking_code} مرتبطة بملف استيراد آخر (#{file_id}) وليس الملف #{req.import_file_id}.",
        )
    file_id = file_id or req.import_file_id

    if not file_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يمكن ترحيل الغرامات بدون ربط جلسة التتبع برقم ملف استيراد (Import File ID).",
        )
    rate = _tracking_rate(tracking)  # 409 when the stored rate is not usable

    # Recalculate before pushing demurrage (BE45-T02)
    tariff = _tracking_tariff(db, tracking)
    containers, dem, det, stor = _recalculate_containers(
        tracking, tariff, rate, tracking.gate_out_date, tracking.empty_return_date, calc_date=calc_date
    )
    _apply_totals(tracking, containers, dem, det, stor, rate)

    from modules.financial_settlement.model import LandedCostSettlementRecord
    from modules.financial_settlement.repository import add_with_new_code, get_settlement_by_import_file_id
    from modules.financial_settlement.validators import ensure_settlement_editable

    settlement = get_settlement_by_import_file_id(db, file_id)
    if settlement:
        # an Approved / Closed settlement is frozen: no new expense rows behind the accountant's back (409)
        ensure_settlement_editable(settlement)
    else:
        from modules.financial_settlement.service import build_initial_settlement
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == file_id).first()
        initial = build_initial_settlement(db, imp_file, actor=user)
        settlement = add_with_new_code(db, initial)

    # rows replaced by invoice number; the settlement totals come from its own recalculation only
    rows = _write_settlement_rows(settlement, tracking, user)

    is_provisional = bool(
        not tracking.containers
        or not all(bool(c.get("empty_return_date") or tracking.empty_return_date) for c in tracking.containers)
    )

    tracking.is_pushed_to_settlement = True
    tracking.settlement_record_id = settlement.settlement_id
    tracking.status = PUSHED_STATUS
    tracking.updated_by = user

    db.commit()
    settlement_id = settlement.settlement_id
    settlement_code = settlement.settlement_code
    tracking_code = tracking.tracking_code
    total_cost_egp = tracking.total_cost_egp

    # Follow-ups: landed-cost totals of the settlement, then lifecycle STEP_18 -> STEP_19
    recalculated = _recalculate_settlement_follow_up(db, settlement_id, user)

    def _advance() -> None:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=file_id,
            completed_step_code="STEP_18",
            target_step_codes=["STEP_19"],
            notes_msg=msg("DD_CHARGES_POSTED", tracking_code=tracking_code),
            assigned_user=user,
        )
        db.commit()

    best_effort(db, _advance, "Lifecycle advance STEP_18->STEP_19")

    return {
        "success": True,
        "message": f"تم ترحيل غرامات الحاويات بقيمة {total_cost_egp:,.2f} جنيه إلى التسوية المالية لملف الاستيراد بنجاح.",
        "settlement_id": settlement_id,
        "settlement_code": settlement_code,
        "settlement_recalculated": recalculated,
        "is_provisional": is_provisional,
        "invoice_entry": rows[0],
        "invoice_entries": rows,
    }



# =========================================================================
# LOG-DUAL-001: Dual Clock Radar Service
# =========================================================================

def get_dual_clock_status_service(
    db: Session, tracking_id: int, calc_date: Optional[date] = None
) -> DualClockResponse:
    tracking = get_demurrage_tracking_by_id_service(db, tracking_id)
    tariff = _tracking_tariff(db, tracking)
    rate = _tracking_rate(tracking)

    # 1. Carrier Demurrage Clock (USD)
    carrier_free = tariff.demurrage_free_days
    demurrage_expiry = tracking.discharge_date + timedelta(days=carrier_free)

    today = calc_date or _today()
    # Carrier clock: demurrage stops at gate-out (or empty return if gate-out omitted)
    carrier_ref_date = tracking.gate_out_date or tracking.empty_return_date or today
    carrier_days_consumed = max(0, (carrier_ref_date - tracking.discharge_date).days)
    carrier_days_remaining = max(0, carrier_free - carrier_days_consumed)

    # DD-08 / Q11: the last free day (remaining == 0) is flagged OVERDUE; pinned until the CTO decides
    if tracking.gate_out_date:
        carrier_status = "GATED_OUT_SAFE" if carrier_days_consumed <= carrier_free else "OVERDUE_DEMURRAGE"
    elif carrier_days_remaining == 0:
        carrier_status = "OVERDUE_DEMURRAGE"
    elif carrier_days_remaining <= 3:
        carrier_status = "WARNING_LAST_3_DAYS"
    else:
        carrier_status = "SAFE"

    # Live recalculation for dual clock (BE45-T02): no write, no commit
    containers, dem, det, stor = _recalculate_containers(
        tracking, tariff, rate, tracking.gate_out_date, tracking.empty_return_date, calc_date=calc_date
    )
    live_demurrage_fx = round(dem, 2)
    live_storage_egp = round(stor, 2)
    live_total_cost_egp = round(((dem + det) * rate) + stor, 2)

    carrier_clock = CarrierDemurrageClock(
        carrier_name=tracking.carrier_name,
        free_days_allowed=carrier_free,
        days_consumed=carrier_days_consumed,
        days_remaining=carrier_days_remaining,
        expiry_date=demurrage_expiry,
        accrued_demurrage_fx=live_demurrage_fx,
        currency=tracking.currency or "USD",
        status=carrier_status,
    )

    # 2. Port Storage Clock (EGP)
    # Port storage strictly ceases the moment container leaves port gates (gate_out_date)
    storage_free = tariff.storage_free_days
    storage_rate = tariff.storage_rate_egp
    storage_ref_date = tracking.gate_out_date or tracking.empty_return_date or today
    storage_days_consumed = max(0, (storage_ref_date - tracking.discharge_date).days)
    storage_days_remaining = max(0, storage_free - storage_days_consumed)
    hours_until_penalties = max(0, storage_days_remaining * 24)

    # Critical 72h alert if consumed >= 3 days or remaining <= 2 days while container still in port
    is_critical_72h = (not tracking.gate_out_date) and (storage_days_consumed >= 3 or storage_days_remaining <= 2)

    if tracking.gate_out_date:
        storage_status = "CLEARED_SAFE" if storage_days_consumed <= storage_free else "OVERDUE_STORAGE"
    elif storage_days_remaining == 0:
        storage_status = "OVERDUE_STORAGE"
    elif is_critical_72h:
        storage_status = "CRITICAL_72H_ALERT"
    else:
        storage_status = "SAFE"

    port_clock = PortStorageClock(
        port_name=tracking.port_name or "Egyptian Port",
        storage_free_days=storage_free,
        days_consumed=storage_days_consumed,
        days_remaining=storage_days_remaining,
        hours_until_penalties=hours_until_penalties,
        daily_rate_egp=storage_rate,
        accrued_storage_egp=live_storage_egp,
        is_critical_72h_warning=is_critical_72h,
        status=storage_status,
    )

    # Overall Alert (summary_ar is deprecated: Flutter renders from overall_alert_level and the numbers)
    if carrier_status == "OVERDUE_DEMURRAGE" and storage_status == "OVERDUE_STORAGE":
        overall_alert = "ACTION_REQUIRED"
        summary_ar = f"خطر مضاعف: تراكم غرامات خط ملاحي وأرضيات ميناء بقيمة إجمالية {live_total_cost_egp:,.2f} جنيه على البوليصة {tracking.bill_of_lading_no}."
    elif storage_status == "OVERDUE_STORAGE" and carrier_status != "OVERDUE_DEMURRAGE":
        overall_alert = "STORAGE_OVERDUE_CARRIER_SAFE"
        summary_ar = f"تنبيه هام: سريان أرضيات الميناء بقيمة {live_storage_egp:,.2f} ج.م رغم أن سماح الخط الملاحي ما زال سارياً (متبقي {carrier_days_remaining} يوم)."
    elif storage_status == "OVERDUE_STORAGE" or carrier_status == "OVERDUE_DEMURRAGE":
        overall_alert = "ACTION_REQUIRED"
        summary_ar = f"تنبيه: تراكم غرامات تأخير بقيمة {live_total_cost_egp:,.2f} جنيه على البوليصة {tracking.bill_of_lading_no}."
    elif is_critical_72h:
        overall_alert = "URGENT_STORAGE_72H"
        summary_ar = f"تحذير عاجل (72 ساعة): متبقي {storage_days_remaining} أيام فقط قبل سريان غرامات أرضيات الميناء بالجنيه المصري."
    else:
        overall_alert = "NORMAL"
        summary_ar = f"فترات السماح سارية: متبقي {carrier_days_remaining} يوماً للخط الملاحي و {storage_days_remaining} أيام لأرضيات الميناء."

    return DualClockResponse(
        tracking_id=tracking.tracking_id,
        tracking_code=tracking.tracking_code,
        bill_of_lading_no=tracking.bill_of_lading_no,
        discharge_date=tracking.discharge_date,
        carrier_clock=carrier_clock,
        port_storage_clock=port_clock,
        overall_alert_level=overall_alert,
        summary_ar=summary_ar,
    )


# =========================================================================
# LOG-CONT-002: Container-Level Individual Update Service
# =========================================================================

def _lifecycle_container_status(item: Dict[str, Any], sim: Any, gate_out: Optional[date], empty_return: Optional[date]) -> str:
    if empty_return:
        return "Empty-Returned"
    if gate_out:
        return "Gated-Out"
    if sim.demurrage_days_overdue > 0:
        return "Demurrage Incurred"
    return "On-Port"


def update_single_container_service(
    db: Session,
    tracking_id: int,
    container_no: str,
    req: ContainerIndividualUpdate,
    user: str = "System",
    actor: Any = None,
) -> DemurrageTracking:
    tracking = get_demurrage_tracking_by_id_service(db, tracking_id)
    if actor is not None and tracking.is_pushed_to_settlement:
        _require_settlement_permission(db, actor)
    rate = _tracking_rate(tracking)
    tariff = _tracking_tariff(db, tracking)

    target = container_no.strip().upper()
    containers = [dict(c) for c in (tracking.containers or [])]
    found = False
    for c in containers:
        if (c.get("container_no") or "").strip().upper() == target:
            found = True
            if req.gate_out_date is not None:
                c["gate_out_date"] = req.gate_out_date.isoformat()
            if req.empty_return_date is not None:
                c["empty_return_date"] = req.empty_return_date.isoformat()
            if req.eir_number is not None:
                c["eir_number"] = req.eir_number
            if req.seal_no is not None:
                c["seal_no"] = req.seal_no
            if req.notes is not None:
                c["notes"] = req.notes
            validate_demurrage_dates(
                tracking.discharge_date,
                _parse_date(c.get("gate_out_date")) or tracking.gate_out_date,
                _parse_date(c.get("empty_return_date")) or tracking.empty_return_date,
                today=cairo_today(),
            )

    if not found:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"الحاوية رقم {container_no} غير موجودة في تتبع البوليصة #{tracking.tracking_code}.",
        )

    tracking.containers = containers
    recalculated, dem, det, stor = _recalculate_containers(
        tracking, tariff, rate, tracking.gate_out_date, tracking.empty_return_date, status_fn=_lifecycle_container_status
    )
    _apply_totals(tracking, recalculated, dem, det, stor, rate)

    all_returned = all(c.get("empty_return_date") for c in recalculated)
    all_gated_out = all(c.get("gate_out_date") for c in recalculated)
    if all_returned:
        tracking.status = "All Containers Returned"
    elif all_gated_out:
        tracking.status = "All Containers Gated Out"
    elif dem > 0 or det > 0 or stor > 0:
        tracking.status = "Demurrage & Storage Incurred"
    else:
        tracking.status = "Free Time Active"
    settlement_id, warning = _repush_recalculated(db, tracking, user)
    tracking.updated_by = user
    tracking.updated_at = datetime.now(timezone.utc)

    db.commit()
    _recalculate_settlement_follow_up(db, settlement_id, user)
    db.refresh(tracking)
    tracking.settlement_warning_code = warning
    return tracking


# =========================================================================
# BK-02: Free Days Agreement Registration & Demurrage Radar Integration
# =========================================================================


def get_containers_radar_overview_service(db: Session) -> ContainerRadarOverviewResponse:
    """
    TR-02: Aggregated Demurrage & Detention Radar across all active container shipments.
    Categorizes containers into:
      - SAFE (Green): > 4 days remaining before penalties begin
      - WARNING (Yellow): 1 to 4 days remaining before penalties begin
      - CRITICAL_OVERDUE (Red): 0 or negative days remaining, penalty actively accruing (Q11 pin: last free day)
      - RETURNED_SAFE (Grey): Container already returned
    Money (DD-03): every non-returned container is priced through the simulator with the tracking's tariff
    (policy tiers / configured defaults) and the tracking's FX rate, so it matches the tracking engine.
    """
    trackings = (
        db.query(DemurrageTracking)
        .options(joinedload(DemurrageTracking.policy), joinedload(DemurrageTracking.import_file))
        .filter(
            DemurrageTracking.is_active == True,
            or_(
                DemurrageTracking.status.notin_(["All Containers Returned", "Closed"]),
                DemurrageTracking.status.is_(None),
            ),
        )
        .all()
    )

    today = date.today()
    radar_items: List[ContainerRadarItem] = []
    safe_count = 0
    warning_count = 0
    critical_count = 0
    returned_count = 0
    carrier_fx_by_currency: Dict[str, float] = {}
    total_accrued_storage_egp = 0.0
    total_estimated_exposure_egp = 0.0
    skipped_codes: List[str] = []

    # one query for the free-days agreements of every file on the radar
    from modules.freight_booking.model import ShipmentBooking
    file_ids = {t.import_file_id for t in trackings if t.import_file_id}
    booking_days: Dict[int, Optional[int]] = {}
    if file_ids:
        for file_id, days in db.query(ShipmentBooking.import_file_id, ShipmentBooking.free_demurrage_days).filter(
            ShipmentBooking.import_file_id.in_(file_ids), ShipmentBooking.is_active == True,
        ).all():
            booking_days.setdefault(file_id, days)

    fallback = default_tariff(db)
    for t in trackings:
        if not t.exchange_rate or t.exchange_rate <= 0:
            # a tracking without a usable rate is flagged, not a failure of the whole radar
            logger.warning("Radar: tracking %s has no valid exchange rate; skipped", t.tracking_code)
            skipped_codes.append(t.tracking_code)
            continue
        tariff = _tracking_tariff(db, t, booking_free_days=booking_days.get(t.import_file_id), fallback=fallback)
        dem_free = tariff.demurrage_free_days
        storage_free = tariff.storage_free_days
        exchange_rate = float(t.exchange_rate)
        currency = (t.currency or "USD").upper()

        containers_list = t.containers or []
        if not containers_list:
            containers_list = [{
                "container_no": t.bill_of_lading_no,
                "container_type": "40ft High Cube",
                "gate_out_date": t.gate_out_date.isoformat() if t.gate_out_date else None,
                "empty_return_date": t.empty_return_date.isoformat() if t.empty_return_date else None,
            }]

        file_code = t.import_file.import_file_code if t.import_file else f"IMP-{t.import_file_id}"

        for c in containers_list:
            c_no = c.get("container_no") or t.bill_of_lading_no
            c_type = c.get("container_type") or "40ft High Cube"

            c_gate_out = _parse_date(c.get("gate_out_date")) or t.gate_out_date
            c_empty_ret = _parse_date(c.get("eir_timestamp")) or _parse_date(c.get("empty_return_date")) or t.empty_return_date

            c_ref_gate_out = c_gate_out or today
            c_dem_consumed = max(0, (c_ref_gate_out - t.discharge_date).days)
            c_dem_remaining = max(0, dem_free - c_dem_consumed)

            c_storage_consumed = max(0, (c_ref_gate_out - t.discharge_date).days)
            c_storage_remaining = max(0, storage_free - c_storage_consumed)

            item_dem_usd = 0.0
            item_stor_egp = 0.0
            item_tot_egp = 0.0
            if not c_empty_ret:
                sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
                    carrier_name=t.carrier_name,
                    container_type=c_type,
                    containers_count=1,
                    demurrage_free_days=tariff.demurrage_free_days,
                    detention_free_days=tariff.detention_free_days,
                    port_storage_free_days=tariff.storage_free_days,
                    port_storage_daily_rate_egp=tariff.storage_rate_egp,
                    demurrage_tiers=tariff.demurrage_tiers,
                    detention_tiers=tariff.detention_tiers,
                    discharge_date=t.discharge_date,
                    gate_out_date=c_gate_out,
                    empty_return_date=None,
                    calculation_date=today,
                    currency=t.currency or "USD",
                    exchange_rate=exchange_rate,
                ))
                item_dem_usd = sim.total_fee_fx  # carrier charges (demurrage + detention) in the tracking currency
                item_stor_egp = sim.storage_fee_egp
                item_tot_egp = sim.total_cost_egp

            # status_label_ar / alert_message_ar / color_code are deprecated (Flutter renders from radar_status)
            if c_empty_ret:
                radar_status = "RETURNED_SAFE"
                color_code = "#7F8C8D"
                status_label_ar = "تم إرجاع الحاوية فارغة"
                returned_count += 1
                alert_msg = f"تم إرجاع الحاوية {c_no} بسلام للخط الملاحي بدون غرامات جارية."
            elif (not c_gate_out and c_storage_remaining == 0) or c_dem_remaining == 0:
                radar_status = "CRITICAL_OVERDUE"
                color_code = "#C0392B"
                status_label_ar = "حرج - سريان غرامات يومية"
                critical_count += 1
                overdue_dem = max(0, c_dem_consumed - dem_free)
                overdue_stor = max(0, c_storage_consumed - storage_free) if not c_gate_out else 0
                alert_msg = f"خطر غرامات: تجاوز فترة السماح بـ {max(overdue_dem, overdue_stor)} أيام! مطلوب سرعة التعتيق والإرجاع."
            elif (not c_gate_out and c_storage_remaining <= 2) or c_dem_remaining <= 4:
                radar_status = "WARNING"
                color_code = "#E67E22"
                status_label_ar = "تحذير - اقتراب انتهاء السماح"
                warning_count += 1
                alert_msg = f"تحذير: متبقي {min(c_dem_remaining, c_storage_remaining)} أيام فقط قبل بدء سريان غرامات التأخير والأرضيات."
            else:
                radar_status = "SAFE"
                color_code = "#27AE60"
                status_label_ar = "آمن - داخل فترة السماح"
                safe_count += 1
                alert_msg = f"الحاوية داخل فترة السماح المعتمدة (متبقي {c_dem_remaining} يوماً للخط الملاحي)."

            carrier_fx_by_currency[currency] = carrier_fx_by_currency.get(currency, 0.0) + item_dem_usd
            total_accrued_storage_egp += item_stor_egp
            total_estimated_exposure_egp += item_tot_egp

            radar_items.append(
                ContainerRadarItem(
                    tracking_id=t.tracking_id,
                    import_file_id=t.import_file_id,
                    import_file_code=file_code,
                    bill_of_lading_no=t.bill_of_lading_no,
                    carrier_name=t.carrier_name,
                    container_number=c_no,
                    container_type=c_type,
                    currency=currency,
                    discharge_date=t.discharge_date,
                    gate_out_date=c_gate_out,
                    empty_return_date=c_empty_ret,
                    radar_status=radar_status,
                    color_code=color_code,
                    status_label_ar=status_label_ar,
                    demurrage_days_consumed=c_dem_consumed,
                    demurrage_free_days=dem_free,
                    demurrage_days_remaining=c_dem_remaining,
                    storage_days_consumed=c_storage_consumed,
                    storage_free_days=storage_free,
                    storage_days_remaining=c_storage_remaining,
                    accrued_demurrage_usd=round(item_dem_usd, 2),
                    accrued_storage_egp=round(item_stor_egp, 2),
                    total_accrued_egp=round(item_tot_egp, 2),
                    alert_message_ar=alert_msg,
                )
            )

    return ContainerRadarOverviewResponse(
        total_containers_tracked=len(radar_items),
        safe_containers_count=safe_count,
        warning_containers_count=warning_count,
        critical_overdue_count=critical_count,
        returned_containers_count=returned_count,
        total_accrued_demurrage_usd=round(carrier_fx_by_currency.get("USD", 0.0), 2),
        total_accrued_carrier_fx_by_currency={k: round(v, 2) for k, v in carrier_fx_by_currency.items()},
        skipped_tracking_codes=skipped_codes,
        total_accrued_storage_egp=round(total_accrued_storage_egp, 2),
        total_estimated_exposure_egp=round(total_estimated_exposure_egp, 2),
        radar_items=radar_items,
        generated_at=datetime.now(timezone.utc),
    )


# =========================================================================
# TR-05: Empty Container Return (EIR) & Demurrage Radar De-escalation
# =========================================================================

# No coded TR-05 task exists yet: matched on whole words of the title / task code ("their" is not "EIR").
TR05_TASK_RE = re.compile(r"\b(?:tr-?05|eir)\b", re.IGNORECASE)
SETTLEMENT_TASK_CODE = "TSK-0901-{file_id}"


def record_empty_container_return_service(
    db: Session,
    payload: EmptyContainerReturnSubmit,
    user: str = "Logistics Coordinator",
    actor: Any = None,
) -> EmptyContainerReturnResponse:
    """
    TR-05: Empty Container Return (EIR), one transaction.
    - Records the EIR and the return date on the target containers (unknown numbers -> 400), validates the
      return date against discharge / gate-out per container, recalculates the final charges.
    - Appends the EIR to the import file's EIR list.
    - Only when ALL containers are returned: inland bookings Completed, file at STEP_20, lifecycle STEP_19 -> STEP_20.
    - Creates the CLO-01 settlement task once (skipped when it already exists).
    - Without a tracking session the containers must be listed (404 otherwise, Q10).
    """
    # A depot picked from the popular list is stored as its code; free text stays as typed.
    payload = payload.model_copy(
        update={"depot_name": enum_codes.normalize(enum_codes.EMPTY_CONTAINER_DEPOT, payload.depot_name)}
    )
    from modules.import_files.model import ImportFile
    from modules.inland_transport.model import InlandTransportBooking
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification

    if actor is not None:
        has_pushed = db.query(DemurrageTracking).filter(
            DemurrageTracking.import_file_id == payload.import_file_id,
            DemurrageTracking.is_active == True,
            DemurrageTracking.is_pushed_to_settlement == True,
        ).first() is not None
        if has_pushed:
            _require_settlement_permission(db, actor)

    # 1. Validate Import File
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == payload.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد برقم #{payload.import_file_id} غير موجود أو تم حذفه.",
        )

    # 2. Locate active DemurrageTracking session for this import file
    today = cairo_today()
    if payload.empty_return_date > today:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="تاريخ إعادة الحاوية الفارغة لا يمكن أن يكون في المستقبل.",
        )

    active_trackings = db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == payload.import_file_id,
        DemurrageTracking.is_active == True,
    ).all()
    if len(active_trackings) > 1:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"يوجد أكثر من جلسة تتبع نشطة لملف الاستيراد رقم {payload.import_file_id}. يرجى معالجة التكرار أولاً.",
        )
    tracking = active_trackings[0] if active_trackings else None

    requested = [c.strip().upper() for c in (payload.returned_containers or []) if c and c.strip()]
    final_dem_fx = 0.0
    final_det_fx = 0.0
    final_stor_egp = 0.0
    final_total_egp = 0.0

    if tracking:
        rate = _tracking_rate(tracking)
        tariff = _tracking_tariff(db, tracking)
        containers = [dict(c) for c in (tracking.containers or [])]
        if not containers and not requested:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"لا توجد حاويات مسجلة في جلسة التتبع {tracking.tracking_code}. حدد أرقام الحاويات المرتجعة أو أضفها لجلسة التتبع أولاً.",
            )
        known = {(c.get("container_no") or "").strip().upper() for c in containers}
        unknown = sorted(set(requested) - known)
        if unknown:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"أرقام حاويات غير موجودة في جلسة التتبع {tracking.tracking_code}: {', '.join(unknown)}",
            )
        # No list = every container still out; containers returned under an earlier EIR keep their EIR and date.
        targets = set(requested) if requested else {
            (c.get("container_no") or "").strip().upper() for c in containers if not c.get("empty_return_date")
        }
        if containers and not targets:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"تم تسجيل إرجاع جميع حاويات جلسة التتبع {tracking.tracking_code} بالفعل.",
            )

        missing_gate_out = []
        for c in containers:
            c_no = (c.get("container_no") or "").strip().upper()
            if c_no in targets:
                g_out = _parse_date(c.get("gate_out_date")) or tracking.gate_out_date
                if not g_out:
                    missing_gate_out.append(c_no)

        if missing_gate_out:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"لا يمكن تسجيل إعادة الحاويات الفارغة بدون تاريخ خروجها من الميناء (Gate-Out) للحاويات: {', '.join(sorted(missing_gate_out))}.",
            )

        returned_container_numbers: List[str] = []
        for c in containers:
            c_no = (c.get("container_no") or "").strip().upper()
            if c_no not in targets:
                continue
            validate_demurrage_dates(
                tracking.discharge_date,
                _parse_date(c.get("gate_out_date")) or tracking.gate_out_date,
                payload.empty_return_date,
                today=today,
            )
            c["container_no"] = c_no
            c["empty_return_date"] = payload.empty_return_date.isoformat()
            c["eir_number"] = payload.eir_number
            c["condition"] = payload.container_condition
            c.setdefault("damage_fee", 0.0)
            if payload.damage_notes:
                c["damage_notes"] = payload.damage_notes
            if payload.damage_fee_estimated:
                c["damage_fee"] = payload.damage_fee_estimated
            if payload.depot_name:
                c["depot_name"] = payload.depot_name
            returned_container_numbers.append(c_no)

        tracking.containers = containers
        recalculated, final_dem_fx, final_det_fx, final_stor_egp = _recalculate_containers(
            tracking, tariff, rate, tracking.gate_out_date, tracking.empty_return_date,
            status_fn=lambda item, sim, g, r: "Empty-Returned" if r else ("Gated-Out" if g else "On-Port"),
        )
        _apply_totals(tracking, recalculated, final_dem_fx, final_det_fx, final_stor_egp, rate)
        final_total_egp = tracking.total_cost_egp
        total_containers_count = len(recalculated)
        all_returned = all(c.get("empty_return_date") for c in recalculated)
        if all_returned:
            tracking.empty_return_date = payload.empty_return_date
        tracking.status = "All Containers Returned" if all_returned else "Partially Returned"
        # a pushed tracking keeps "Pushed to Settlement" and its settlement rows follow the final charges
        repush_settlement_id, settlement_warning = _repush_recalculated(db, tracking, user)
        tracking_status = tracking.status
        tracking.updated_by = user
    else:
        if not requested:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="لا توجد جلسة تتبع حاويات لهذا الملف",
            )
        returned_container_numbers = requested
        repush_settlement_id, settlement_warning = None, None
        total_containers_count = len(requested)
        all_returned = True
        tracking_status = "All Containers Returned"

    # 3. Synchronize Import File (EIR numbers are appended, never overwritten)
    imp_file.empty_containers_returned_at = datetime.now(timezone.utc)
    imp_file.empty_containers_return_status = "ALL_RETURNED" if all_returned else "PARTIALLY_RETURNED"
    existing_eirs = [e.strip() for e in (imp_file.empty_containers_eir_numbers or "").split(",") if e.strip()]
    if payload.eir_number not in existing_eirs:
        existing_eirs.append(payload.eir_number)
    imp_file.empty_containers_eir_numbers = ", ".join(existing_eirs)
    imp_file.empty_containers_depot_name = payload.depot_name

    # DEV-OPS-01: Update empty return info on ShipmentContainer entities
    try:
        from modules.containers.model import ShipmentContainer
        sc_list = db.query(ShipmentContainer).filter(
            ShipmentContainer.import_file_id == payload.import_file_id,
            ShipmentContainer.is_active == True,
        ).all()
        for sc in sc_list:
            if not returned_container_numbers or sc.container_number in returned_container_numbers:
                sc.empty_return_date = payload.empty_return_date
                sc.eir_number = payload.eir_number
                if payload.depot_name:
                    sc.depot_name = payload.depot_name
                if payload.condition_at_return:
                    sc.condition_at_return = payload.condition_at_return
                sc.status = "Returned Empty"
                sc.updated_by = user
    except Exception as exc:
        logger.warning("Failed to sync return empty to ShipmentContainer: %s", exc)

    if all_returned:
        # 4. Inland transport bookings complete only when every container is back
        transport_bookings = db.query(InlandTransportBooking).filter(
            InlandTransportBooking.import_file_id == payload.import_file_id,
            InlandTransportBooking.is_active == True,
        ).all()
        for tb in transport_bookings:
            tb.status = "Completed"
            tb.tracking_notes = f"{tb.tracking_notes or ''}\n[TR-05] Empty containers returned to the carrier under EIR #{payload.eir_number}".strip()
        imp_file.inland_transport_status = "COMPLETED"
        if not _file_past_step(imp_file, "STEP_20"):
            from modules.import_files.import_file_payment_pathway_service import advance_tracking_or_hold

            if advance_tracking_or_hold(
                db, imp_file, step_code="STEP_20", next_action=msg("NA_CLO_SETTLE_FINAL_INVOICES")
            ):
                imp_file.progress_percent = max(float(imp_file.progress_percent or 0.0), 98.0)

    # 5. Auto-close pending TR-05 SmartTasks once every container is back (a partial return leaves them open)
    if all_returned:
        pending_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == payload.import_file_id,
            SmartTask.status.in_(["Pending", "In Progress"]),
            SmartTask.is_active == True,
        ).all()
        for tsk in pending_tasks:
            if TR05_TASK_RE.search(tsk.title or "") or TR05_TASK_RE.search(tsk.task_code or ""):
                tsk.status = "Completed"
                tsk.is_auto_closed = True
                tsk.notes = f"{tsk.notes or ''}\n[TR-05] Auto-closed on EIR #{payload.eir_number}".strip()

    # 6. Downstream SmartTask for Phase 9 (CLO-01 Final Settlement): created once
    task_code = SETTLEMENT_TASK_CODE.format(file_id=payload.import_file_id)
    if not db.query(SmartTask.task_id).filter(SmartTask.task_code == task_code).first():
        task_msg = msg("DD_TASK_SETTLE_FINAL_INVOICES", eir_number=payload.eir_number)
        db.add(SmartTask(
            task_code=task_code,
            import_file_id=payload.import_file_id,
            import_file_code=imp_file.import_file_code,
            title=render_en(task_msg.code, task_msg.params, "title"),
            description=render_en(task_msg.code, task_msg.params, "body"),
            msg_code=task_msg.code,
            msg_params=task_msg.params,
            step_code="STEP_20",
            task_type="FINANCIAL_SETTLEMENT",
            phase_name="Phase 9 - Financial Settlement & File Closure",
            assigned_user="Finance Team",
            priority="High",
            status="Pending",
            due_date=(date.today() + timedelta(days=3)).isoformat(),
            created_by=user,
        ))

    # 7. Central SystemNotification
    notif_msg = msg(
        "DD_EMPTY_CONTAINERS_RETURNED",
        import_file_code=imp_file.import_file_code,
        container_count=len(returned_container_numbers),
        eir_number=payload.eir_number,
        depot_enum_empty_container_depot=payload.depot_name or "",
    )
    db.add(SystemNotification(
        title=render_en(notif_msg.code, notif_msg.params, "title"),
        message=render_en(notif_msg.code, notif_msg.params, "body"),
        msg_code=notif_msg.code,
        msg_params=notif_msg.params,
        category="STAGE_PROGRESSION",
        severity="SUCCESS",
        entity_type="ImportFile",
        entity_id=payload.import_file_id,
        target_role="ALL",
    ))

    db.commit()
    _recalculate_settlement_follow_up(db, repush_settlement_id, user)

    # 8. Follow-up: lifecycle board STEP_19 -> STEP_20, only when every container is returned
    if all_returned and not _file_past_step(imp_file, "STEP_20"):
        def _advance_board() -> None:
            from modules.lifecycle_board.service import advance_lifecycle_step_service
            advance_lifecycle_step_service(
                db=db,
                import_file_id=payload.import_file_id,
                completed_step_code="STEP_19",
                target_step_codes=["STEP_20"],
                notes_msg=msg("DD_EMPTY_CONTAINERS_RETURNED", eir_number=payload.eir_number),
                assigned_user=user,
            )
            # Re-apply after the board transition, which writes its own generic next action.
            file_row = db.query(ImportFile).filter(ImportFile.import_file_id == payload.import_file_id).first()
            if file_row and not _file_past_step(file_row, "STEP_20"):
                set_file_tracking(file_row, step_code="STEP_20", next_action=msg("NA_CLO_SETTLE_FINAL_INVOICES"))
                db.commit()

        best_effort(db, _advance_board, "Lifecycle advance STEP_19->STEP_20 on empty return")
    db.refresh(imp_file)

    return EmptyContainerReturnResponse(
        import_file_id=imp_file.import_file_id,
        import_file_code=imp_file.import_file_code,
        tracking_id=tracking.tracking_id if tracking else None,
        tracking_code=tracking.tracking_code if tracking else None,
        eir_number=payload.eir_number,
        empty_return_date=payload.empty_return_date,
        depot_name=payload.depot_name,
        returned_containers=returned_container_numbers,
        containers_returned_count=len(returned_container_numbers),
        total_containers_count=total_containers_count,
        all_containers_returned=all_returned,
        container_condition=payload.container_condition,
        damage_fee_estimated=payload.damage_fee_estimated or 0.0,
        demurrage_final_fx=round(final_dem_fx, 2),
        detention_final_fx=round(final_det_fx, 2),
        storage_final_egp=round(final_stor_egp, 2),
        total_exposure_egp=round(final_total_egp, 2),
        tracking_status=tracking_status,
        next_action=imp_file.next_action,
        current_stage=imp_file.current_stage,
        progress_percent=imp_file.progress_percent,
        settlement_warning_code=settlement_warning,
        message_ar=f"تم توثيق إرجاع الحاويات بنجاح بموجب إيصال EIR #{payload.eir_number} وإيقاف عدادات الغرامات بالكامل.",
        returned_at=datetime.now(timezone.utc),
    )


# =========================================================================
# Terminal & Terminal Storage Rate Services
# =========================================================================

