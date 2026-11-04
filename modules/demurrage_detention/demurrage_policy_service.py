from .demurrage_calculation_service import (
    AGREED_DEMURRAGE_KEY,
    AGREED_DETENTION_KEY,
    AGREED_STORAGE_KEY,
    _apply_totals,
    _recalculate_containers,
    _recalculate_settlement_follow_up,
    _repush_recalculated,
    _tracking_rate,
    _tracking_tariff,
    default_tariff,
)
from .demurrage_tracking_service import _require_settlement_permission
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



def create_demurrage_policy_service(db: Session, req: DemurragePolicyCreate, user: str = "System") -> DemurragePolicy:
    validate_tier_rates(req.demurrage_tiers, "شرائح غرامة الأرضيات")
    validate_tier_rates(req.detention_tiers, "شرائح غرامة تأخير الفارغ")

    data = req.model_dump()
    fallback = default_tariff(db)
    if data.get("demurrage_free_days") is None:
        data["demurrage_free_days"] = fallback.demurrage_free_days
    if data.get("detention_free_days") is None:
        data["detention_free_days"] = fallback.detention_free_days
    if data.get("port_storage_free_days") is None:
        data["port_storage_free_days"] = fallback.storage_free_days
    if data.get("port_storage_daily_rate_egp") is None:
        data["port_storage_daily_rate_egp"] = fallback.storage_rate_egp
    if not data.get("demurrage_tiers"):
        data["demurrage_tiers"] = fallback.demurrage_tiers
    if not data.get("detention_tiers"):
        data["detention_tiers"] = fallback.detention_tiers

    policy = repository.create_policy(db, data, user=user)
    db.commit()
    db.refresh(policy)
    return policy


def get_demurrage_policies_service(
    db: Session,
    carrier_name: Optional[str] = None,
    container_type: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[DemurragePolicy], int]:
    return repository.get_policies(db, carrier_name=carrier_name, container_type=container_type, skip=skip, limit=limit)


def get_demurrage_policy_by_id_service(db: Session, policy_id: int) -> DemurragePolicy:
    policy = repository.get_policy_by_id(db, policy_id)
    if not policy:
        raise not_found("سياسة غرامات الخط الملاحي", policy_id)
    return policy


def update_demurrage_policy_service(
    db: Session, policy_id: int, req: DemurragePolicyUpdate, user: str = "System"
) -> DemurragePolicy:
    policy = get_demurrage_policy_by_id_service(db, policy_id)
    if req.demurrage_tiers:
        validate_tier_rates(req.demurrage_tiers, "شرائح غرامة الأرضيات")
    if req.detention_tiers:
        validate_tier_rates(req.detention_tiers, "شرائح غرامة تأخير الفارغ")

    repository.update_policy(db, policy, req.model_dump(exclude_unset=True), user=user)
    db.commit()
    db.refresh(policy)
    return policy


def delete_demurrage_policy_service(db: Session, policy_id: int, user: str = "System") -> DemurragePolicy:
    policy = get_demurrage_policy_by_id_service(db, policy_id)
    repository.delete_policy(db, policy, user=user)
    db.commit()
    db.refresh(policy)
    return policy


# ----------------------------------------------------
# Tracking Service Operations
# ----------------------------------------------------


def _standard_free_days(db: Session) -> int:
    return int(get_float_parameter(db, DD_STANDARD_FREE_DAYS, DEFAULT_STANDARD_FREE_DAYS))


def _cost_avoidance(db: Session, additional_days: int, booking: Any) -> float:
    containers_count = 1
    if booking and booking.containers_data:
        containers_count = sum(c.get("quantity", 1) if isinstance(c, dict) else getattr(c, "quantity", 1) for c in booking.containers_data)
    rate = get_float_parameter(db, DD_AVOIDANCE_RATE_USD, DEFAULT_AVOIDANCE_RATE_USD)
    return round(additional_days * rate * containers_count, 2)


def register_free_days_agreement_service(
    db: Session,
    payload: FreeDaysAgreementRegister,
    user: str = "Logistics Officer",
    actor: Any = None,
) -> FreeDaysAgreementResponse:
    """
    BK-02: Free Days Agreement Registration (one transaction).
    - Synchronizes agreed free days with ImportFile.target_free_days and the active ShipmentBooking
    - Recalculates the file's active trackings with the agreed free days, keeping the policy tiers, the storage
      rate and every per-container key (EIR, dates, seal). Trackings already pushed to settlement are skipped
      and reported (Q9 safe default).
    - Follow-ups: completes pending BK-02 SmartTasks and dispatches a SystemNotification
    """
    from modules.import_files.model import ImportFile
    from modules.freight_booking.model import ShipmentBooking

    if actor is not None:
        has_pushed = db.query(DemurrageTracking).filter(
            DemurrageTracking.import_file_id == payload.import_file_id,
            DemurrageTracking.is_active == True,
            DemurrageTracking.is_pushed_to_settlement == True,
        ).first() is not None
        if has_pushed:
            _require_settlement_permission(db, actor)

    file_rec = db.query(ImportFile).filter(
        ImportFile.import_file_id == payload.import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not file_rec:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد رقم {payload.import_file_id} غير موجود.",
        )

    file_code = file_rec.custom_file_number or file_rec.import_file_code or f"IMP-{file_rec.import_file_id}"

    # Effective agreed days: null detention / storage = keep the policy (or configured default) value
    fallback = default_tariff(db)
    effective_detention = payload.agreed_detention_free_days if payload.agreed_detention_free_days is not None else fallback.detention_free_days
    effective_storage = payload.port_storage_free_days if payload.port_storage_free_days is not None else fallback.storage_free_days

    # 1. Update ImportFile
    file_rec.target_free_days = payload.agreed_demurrage_free_days
    if payload.agreement_reference:
        ref_note = f"{FREE_DAYS_NOTE_PREFIX}{payload.agreement_reference} ({payload.agreed_demurrage_free_days}D DEM / {effective_detention}D DET)"
        if file_rec.shipping_instructions_notes:
            if ref_note not in file_rec.shipping_instructions_notes:
                file_rec.shipping_instructions_notes += f" | {ref_note}"
        else:
            file_rec.shipping_instructions_notes = ref_note

    # 2. Update linked ShipmentBooking
    booking = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == payload.import_file_id,
        ShipmentBooking.is_active == True,
    ).first()
    if booking:
        booking.free_demurrage_days = payload.agreed_demurrage_free_days

    # 3. Recalculate the file's active trackings
    carrier = payload.carrier_name or (booking.shipping_line_name if booking else None) or None
    trackings = db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == payload.import_file_id,
        DemurrageTracking.is_active == True,
    ).all()
    # The agreement is recorded on the containers (detention / storage, demurrage when there is no booking) so
    # every later recalculation applies it; pushed trackings are re-pushed (lead decision, replaces Q9 skip).
    stale_codes: List[str] = []
    repush_ids: List[int] = []
    for trk in trackings:
        rate = _tracking_rate(trk)
        containers = []
        for c in (trk.containers or []):
            item = dict(c)
            item[AGREED_DEMURRAGE_KEY] = payload.agreed_demurrage_free_days
            if payload.agreed_detention_free_days is not None:
                item[AGREED_DETENTION_KEY] = payload.agreed_detention_free_days
            if payload.port_storage_free_days is not None:
                item[AGREED_STORAGE_KEY] = payload.port_storage_free_days
            containers.append(item)
        trk.containers = containers
        tariff = _tracking_tariff(db, trk, booking_free_days=payload.agreed_demurrage_free_days)
        recalculated, dem, det, stor = _recalculate_containers(trk, tariff, rate, trk.gate_out_date, trk.empty_return_date)
        _apply_totals(trk, recalculated, dem, det, stor, rate)
        settlement_id, warning = _repush_recalculated(db, trk, user)
        if settlement_id and settlement_id not in repush_ids:
            repush_ids.append(settlement_id)
        if warning:
            stale_codes.append(trk.tracking_code)
        trk.updated_by = user

    # 4. Cost avoidance against the standard free days (system parameters)
    standard_free_days = _standard_free_days(db)
    additional_days = max(0, payload.agreed_demurrage_free_days - standard_free_days)
    estimated_cost_avoidance = _cost_avoidance(db, additional_days, booking)

    db.commit()
    for settlement_id in repush_ids:
        _recalculate_settlement_follow_up(db, settlement_id, user)

    # 5. Follow-ups: complete pending BK-02 smart tasks, notification
    def _close_tasks() -> None:
        from modules.smart_tasks.model import SmartTask
        prior_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == payload.import_file_id,
            SmartTask.status.in_(["Pending", "In Progress"]),
            SmartTask.is_active == True,
        ).all()
        for pt in prior_tasks:
            title_lower = (pt.title or "").lower()
            if pt.msg_code == "FB_TASK_FREE_DAYS" or "bk-02" in title_lower or "سماح" in title_lower or "free days" in title_lower:
                pt.status = "Completed"
                pt.is_auto_closed = True
        db.commit()

    def _notify() -> None:
        from modules.notifications.model import SystemNotification
        notif_msg = msg(
            "DD_FREE_DAYS_RECORDED",
            demurrage_free_days=payload.agreed_demurrage_free_days,
            import_file_code=file_code,
            detention_free_days=effective_detention,
            agreement_reference=payload.agreement_reference or "N/A",
            estimated_saving_amount=round(float(estimated_cost_avoidance), 2),
        )
        db.add(SystemNotification(
            title=render_en(notif_msg.code, notif_msg.params, "title"),
            message=render_en(notif_msg.code, notif_msg.params, "body"),
            msg_code=notif_msg.code,
            msg_params=notif_msg.params,
            severity="INFO",
            category="FREE_DAYS_AGREEMENT_REGISTERED",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="LOGISTICS_OFFICER",
        ))
        db.commit()

    best_effort(db, _close_tasks, "Auto-complete BK-02 smart tasks")
    best_effort(db, _notify, "Free days notification")

    return FreeDaysAgreementResponse(
        import_file_id=payload.import_file_id,
        import_file_code=file_code,
        carrier_name=carrier,
        booking_code=booking.booking_code if booking else None,
        booking_confirmation_no=booking.booking_confirmation_no if booking else None,
        standard_policy_demurrage_days=standard_free_days,
        agreed_demurrage_free_days=payload.agreed_demurrage_free_days,
        agreed_detention_free_days=effective_detention,
        port_storage_free_days=effective_storage,
        additional_free_days_gained=additional_days,
        estimated_cost_avoidance_usd=estimated_cost_avoidance,
        agreement_reference=payload.agreement_reference,
        agreement_date=payload.agreement_date,
        radar_status="Safe" if payload.agreed_demurrage_free_days >= standard_free_days else "Warning",
        notes=payload.notes,
        stale_settlement_tracking_codes=stale_codes,
        updated_at=datetime.now(timezone.utc),
    )


def get_free_days_agreement_service(
    db: Session,
    import_file_id: int,
) -> FreeDaysAgreementResponse:
    from modules.import_files.model import ImportFile
    from modules.freight_booking.model import ShipmentBooking

    file_rec = db.query(ImportFile).filter(
        ImportFile.import_file_id == import_file_id,
        ImportFile.is_active == True,
    ).first()
    if not file_rec:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد رقم {import_file_id} غير موجود.",
        )

    booking = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True,
    ).first()

    standard_free_days = _standard_free_days(db)
    fallback = default_tariff(db)
    file_code = file_rec.custom_file_number or file_rec.import_file_code or f"IMP-{file_rec.import_file_id}"
    carrier = (booking.shipping_line_name if booking else None) or None
    if file_rec.target_free_days is not None:
        agreed_dem = file_rec.target_free_days
    elif booking and booking.free_demurrage_days is not None:
        agreed_dem = booking.free_demurrage_days
    else:
        agreed_dem = standard_free_days
    additional_days = max(0, agreed_dem - standard_free_days)
    estimated_cost_avoidance = _cost_avoidance(db, additional_days, booking)

    agreement_reference = None
    notes_text = file_rec.shipping_instructions_notes or ""
    for prefix in (FREE_DAYS_NOTE_PREFIX, LEGACY_FREE_DAYS_NOTE_PREFIX):
        if agreement_reference is not None or prefix not in notes_text:
            continue
        for part in notes_text.split("|"):
            part = part.strip()
            if prefix in part:
                after = part.split(prefix)[1].strip()
                if " (" in after:
                    agreement_reference = after.split(" (")[0].strip()
                else:
                    agreement_reference = after

    # Detention / storage free days are not stored yet (deferred, needs a schema change): configured defaults
    return FreeDaysAgreementResponse(
        import_file_id=import_file_id,
        import_file_code=file_code,
        carrier_name=carrier,
        booking_code=booking.booking_code if booking else None,
        booking_confirmation_no=booking.booking_confirmation_no if booking else None,
        standard_policy_demurrage_days=standard_free_days,
        agreed_demurrage_free_days=agreed_dem,
        agreed_detention_free_days=fallback.detention_free_days,
        port_storage_free_days=fallback.storage_free_days,
        additional_free_days_gained=additional_days,
        estimated_cost_avoidance_usd=estimated_cost_avoidance,
        agreement_reference=agreement_reference,
        agreement_date=None,
        radar_status="Safe" if agreed_dem >= standard_free_days else "Warning",
        notes=file_rec.shipping_instructions_notes,
        updated_at=datetime.now(timezone.utc),
    )


# =========================================================================
# TR-02: Demurrage & Detention Radar Overview Service
# =========================================================================


def create_terminal_service(db: Session, req: TerminalCreate, user: str = "System") -> Terminal:
    existing = repository.get_terminal_by_code(db, req.terminal_code)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"كود المحطة '{req.terminal_code}' مسجل مسبقاً لمشغل محطة آخر.",
        )
    terminal = repository.create_terminal(db, req.model_dump(), user=user)
    db.commit()
    db.refresh(terminal)
    return terminal


def get_terminals_service(
    db: Session,
    port_name: Optional[str] = None,
    is_active: Optional[bool] = True,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[Terminal], int]:
    return repository.get_terminals(db, port_name=port_name, is_active=is_active, skip=skip, limit=limit)


def get_terminal_by_id_service(db: Session, terminal_id: int) -> Terminal:
    terminal = repository.get_terminal_by_id(db, terminal_id)
    if not terminal:
        raise not_found("المحطة البحرية", terminal_id)
    return terminal


def update_terminal_service(db: Session, terminal_id: int, req: TerminalUpdate, user: str = "System") -> Terminal:
    terminal = get_terminal_by_id_service(db, terminal_id)
    update_data = req.model_dump(exclude_unset=True)
    if "terminal_code" in update_data and update_data["terminal_code"] != terminal.terminal_code:
        dup = repository.get_terminal_by_code(db, update_data["terminal_code"])
        if dup and dup.terminal_id != terminal_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"كود المحطة '{update_data['terminal_code']}' مسجل مسبقاً.",
            )
    for k, v in update_data.items():
        setattr(terminal, k, v)
    terminal.updated_by = user
    terminal.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(terminal)
    return terminal


def create_terminal_storage_rate_service(
    db: Session, terminal_id: int, req: TerminalStorageRateCreate, user: str = "System"
) -> TerminalStorageRate:
    terminal = get_terminal_by_id_service(db, terminal_id)
    validate_tier_rates(req.storage_tiers, "شرائح رسوم أرضيات المحطة")
    data = req.model_dump()
    data["terminal_id"] = terminal.terminal_id
    rate = repository.add_terminal_storage_rate(db, data, user=user)
    db.commit()
    db.refresh(rate)
    return rate


def get_terminal_storage_rates_service(
    db: Session, terminal_id: int, container_type: Optional[str] = None
) -> List[TerminalStorageRate]:
    get_terminal_by_id_service(db, terminal_id)
    return repository.get_storage_rates_history(db, terminal_id, container_type=container_type)


# =========================================================================
# Carrier & Carrier Demurrage Rate Services
# =========================================================================

def create_carrier_service(db: Session, req: CarrierCreate, user: str = "System") -> Carrier:
    existing = repository.get_carrier_by_code(db, req.carrier_code)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"كود الخط الملاحي '{req.carrier_code}' مسجل مسبقاً.",
        )
    carrier = repository.create_carrier(db, req.model_dump(), user=user)
    db.commit()
    db.refresh(carrier)
    return carrier


def get_carriers_service(
    db: Session,
    is_active: Optional[bool] = True,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[Carrier], int]:
    return repository.get_carriers(db, is_active=is_active, skip=skip, limit=limit)


def get_carrier_by_id_service(db: Session, carrier_id: int) -> Carrier:
    carrier = repository.get_carrier_by_id(db, carrier_id)
    if not carrier:
        raise not_found("الخط الملاحي", carrier_id)
    return carrier


def update_carrier_service(db: Session, carrier_id: int, req: CarrierUpdate, user: str = "System") -> Carrier:
    carrier = get_carrier_by_id_service(db, carrier_id)
    update_data = req.model_dump(exclude_unset=True)
    if "carrier_code" in update_data and update_data["carrier_code"] != carrier.carrier_code:
        dup = repository.get_carrier_by_code(db, update_data["carrier_code"])
        if dup and dup.carrier_id != carrier_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"كود الخط الملاحي '{update_data['carrier_code']}' مسجل مسبقاً.",
            )
    for k, v in update_data.items():
        setattr(carrier, k, v)
    carrier.updated_by = user
    carrier.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(carrier)
    return carrier


def create_carrier_demurrage_rate_service(
    db: Session, carrier_id: int, req: CarrierDemurrageRateCreate, user: str = "System"
) -> CarrierDemurrageRate:
    carrier = get_carrier_by_id_service(db, carrier_id)
    validate_tier_rates(req.demurrage_tiers, "شرائح غرامة الأرضيات للخط الملاحي")
    validate_tier_rates(req.detention_tiers, "شرائح غرامة تأخير الفارغ للخط الملاحي")
    data = req.model_dump()
    data["carrier_id"] = carrier.carrier_id
    rate = repository.add_carrier_demurrage_rate(db, data, user=user)
    db.commit()
    db.refresh(rate)
    return rate


def get_carrier_demurrage_rates_service(
    db: Session, carrier_id: int, container_type: Optional[str] = None
) -> List[CarrierDemurrageRate]:
    get_carrier_by_id_service(db, carrier_id)
    return repository.get_demurrage_rates_history(db, carrier_id, container_type=container_type)


def get_rates_history_service(
    db: Session,
    terminal_id: Optional[int] = None,
    carrier_id: Optional[int] = None,
    container_type: Optional[str] = None,
) -> Dict[str, Any]:
    terminal_rates = []
    carrier_rates = []
    if terminal_id or not carrier_id:
        terminal_rates = repository.get_storage_rates_history(
            db, terminal_id=terminal_id, container_type=container_type
        )
    if carrier_id or not terminal_id:
        carrier_rates = repository.get_demurrage_rates_history(
            db, carrier_id=carrier_id, container_type=container_type
        )
    return {
        "terminal_rates": terminal_rates,
        "carrier_rates": carrier_rates,
    }


