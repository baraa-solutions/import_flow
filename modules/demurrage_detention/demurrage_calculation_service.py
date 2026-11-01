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



def _today() -> date:
    import sys
    svc = sys.modules.get('modules.demurrage_detention.service')
    if svc is not None and '_today' in svc.__dict__:
        fn = svc.__dict__['_today']
        if fn is not _today:
            return fn()
    return date.today()



@dataclass(frozen=True)
class Tariff:
    demurrage_free_days: int
    detention_free_days: int
    storage_free_days: int
    storage_rate_egp: float
    demurrage_tiers: List[Dict[str, Any]]
    detention_tiers: List[Dict[str, Any]]
    storage_tiers: Optional[List[Dict[str, Any]]] = None
    currency: str = "USD"
    storage_currency: str = "USD"
    imo_free_days: int = 0
    imo_rate_multiplier: float = 2.0


def _tiers_parameter(db: Session, key: str, default: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    raw = get_parameter(db, key)
    if raw is None:
        return [dict(t) for t in default]
    try:
        tiers = json.loads(raw)
        if isinstance(tiers, list) and tiers and all(isinstance(t, dict) and "from_day" in t for t in tiers):
            return tiers
    except (TypeError, ValueError):
        pass
    logger.warning("System parameter %s is not a valid tier list; using the default tiers", key)
    return [dict(t) for t in default]


def default_tariff(db: Session) -> Tariff:
    """Carrier tariff used when no policy matches (system parameters, defaults = today's values)."""
    return Tariff(
        demurrage_free_days=int(get_float_parameter(db, DD_DEFAULT_FREE_DAYS_DEMURRAGE, DEFAULT_FREE_DAYS_DEMURRAGE)),
        detention_free_days=int(get_float_parameter(db, DD_DEFAULT_FREE_DAYS_DETENTION, DEFAULT_FREE_DAYS_DETENTION)),
        storage_free_days=int(get_float_parameter(db, DD_DEFAULT_STORAGE_FREE_DAYS, DEFAULT_STORAGE_FREE_DAYS)),
        storage_rate_egp=get_float_parameter(db, DD_DEFAULT_STORAGE_RATE_EGP, DEFAULT_STORAGE_RATE_EGP),
        demurrage_tiers=_tiers_parameter(db, DD_DEFAULT_DEMURRAGE_TIERS, DEFAULT_DEMURRAGE_TIERS),
        detention_tiers=_tiers_parameter(db, DD_DEFAULT_DETENTION_TIERS, DEFAULT_DETENTION_TIERS),
        storage_tiers=None,
        currency=get_parameter(db, DD_DEFAULT_TARIFF_CURRENCY) or DEFAULT_TARIFF_CURRENCY,
        storage_currency="USD",
        imo_free_days=0,
        imo_rate_multiplier=2.0,
    )


def _resolve_tariff(
    db: Session,
    policy: Optional[DemurragePolicy] = None,
    fallback: Optional[Tariff] = None,
    carrier_id: Optional[int] = None,
    carrier_name: Optional[str] = None,
    terminal_id: Optional[int] = None,
    port_name: Optional[str] = None,
    container_type: Optional[str] = None,
    discharge_date: Optional[date] = None,
) -> Tariff:
    """The policy's tariff, or resolved historical rate cards, or the configured default tariff."""
    if fallback is None:
        fallback = default_tariff(db)

    # 1. Start with policy or fallback
    c_free = policy.demurrage_free_days if policy else fallback.demurrage_free_days
    det_free = policy.detention_free_days if policy else fallback.detention_free_days
    s_free = policy.port_storage_free_days if policy else fallback.storage_free_days
    s_rate_egp = policy.port_storage_daily_rate_egp if policy else fallback.storage_rate_egp
    dem_tiers = policy.demurrage_tiers if policy and policy.demurrage_tiers else fallback.demurrage_tiers
    det_tiers = policy.detention_tiers if policy and policy.detention_tiers else fallback.detention_tiers
    stor_tiers = None
    curr = policy.currency if policy and policy.currency else fallback.currency
    stor_curr = "USD"
    imo_free = 0
    imo_mult = 2.0

    target_d = discharge_date or _today()
    c_type = container_type or "40ft High Cube"

    # 2. Check Carrier Historical Rate Card
    c_rec = None
    if carrier_id:
        c_rec = repository.get_effective_demurrage_rate(db, carrier_id, c_type, target_d)
    elif carrier_name:
        carrier = repository.find_carrier_by_name(db, carrier_name)
        if carrier:
            c_rec = repository.get_effective_demurrage_rate(db, carrier.carrier_id, c_type, target_d)

    if c_rec:
        c_free = c_rec.demurrage_free_days_standard
        det_free = c_rec.detention_free_days_standard
        dem_tiers = c_rec.demurrage_tiers
        det_tiers = c_rec.detention_tiers
        curr = c_rec.currency

    # 3. Check Terminal Historical Storage Rate Card
    s_rec = None
    if terminal_id:
        s_rec = repository.get_effective_storage_rate(db, terminal_id, c_type, target_d)
    elif port_name:
        terminal = repository.find_terminal_for_port(db, port_name)
        if terminal:
            s_rec = repository.get_effective_storage_rate(db, terminal.terminal_id, c_type, target_d)

    if s_rec:
        s_free = s_rec.free_days
        stor_tiers = s_rec.storage_tiers
        stor_curr = s_rec.currency
        imo_free = s_rec.imo_free_days
        imo_mult = s_rec.imo_rate_multiplier

    return Tariff(
        demurrage_free_days=c_free,
        detention_free_days=det_free,
        storage_free_days=s_free,
        storage_rate_egp=s_rate_egp,
        demurrage_tiers=dem_tiers,
        detention_tiers=det_tiers,
        storage_tiers=stor_tiers,
        currency=curr,
        storage_currency=stor_curr,
        imo_free_days=imo_free,
        imo_rate_multiplier=imo_mult,
    )


# BK-02 agreement keys recorded on every container of a tracking (no tracking column for them yet: deferred
# schema change). Demurrage agreed days live on the file's active booking (booking.free_demurrage_days).
AGREED_DEMURRAGE_KEY = "agreed_demurrage_free_days"  # used when the file has no active booking
AGREED_DETENTION_KEY = "agreed_detention_free_days"
AGREED_STORAGE_KEY = "agreed_storage_free_days"
_UNSET: Any = object()


def _booking_free_days(db: Session, import_file_id: Optional[int]) -> Optional[int]:
    """Demurrage free days of the file's active booking (BK-01 confirmation / BK-02 agreement)."""
    if not import_file_id:
        return None
    from modules.freight_booking.model import ShipmentBooking
    row = db.query(ShipmentBooking.free_demurrage_days).filter(
        ShipmentBooking.import_file_id == import_file_id,
        ShipmentBooking.is_active == True,
    ).first()
    return row[0] if row else None


def _agreed_tariff(tariff: Tariff, booking_free_days: Optional[int], containers: Optional[List[Dict[str, Any]]]) -> Tariff:
    """The policy tariff with the free-days agreement on top: the booking's demurrage free days (as tracking
    create always applied them) and the detention / storage free days BK-02 recorded on the containers."""
    if booking_free_days is not None:
        tariff = replace(tariff, demurrage_free_days=booking_free_days)
    keys = (AGREED_DEMURRAGE_KEY, AGREED_DETENTION_KEY, AGREED_STORAGE_KEY)
    for c in containers or []:
        if all(c.get(k) is None for k in keys):
            continue
        if booking_free_days is None and c.get(AGREED_DEMURRAGE_KEY) is not None:
            tariff = replace(tariff, demurrage_free_days=int(c[AGREED_DEMURRAGE_KEY]))
        if c.get(AGREED_DETENTION_KEY) is not None:
            tariff = replace(tariff, detention_free_days=int(c[AGREED_DETENTION_KEY]))
        if c.get(AGREED_STORAGE_KEY) is not None:
            tariff = replace(tariff, storage_free_days=int(c[AGREED_STORAGE_KEY]))
        break
    return tariff


def _tracking_tariff(db: Session, tracking: DemurrageTracking, booking_free_days: Any = _UNSET, fallback: Optional[Tariff] = None) -> Tariff:
    """The one tariff of a tracking for every recalculation (PUT, single container, EIR, BK-02, dual clock,
    radar): policy (or configured default) + the file's free-days agreement."""
    if booking_free_days is _UNSET:
        booking_free_days = _booking_free_days(db, tracking.import_file_id)
    first_c_type = None
    if tracking.containers and isinstance(tracking.containers, list) and len(tracking.containers) > 0:
        first_c_type = tracking.containers[0].get("container_type")
    base_tariff = _resolve_tariff(
        db,
        tracking.policy,
        fallback=fallback,
        carrier_id=tracking.carrier_id,
        carrier_name=tracking.carrier_name,
        terminal_id=tracking.terminal_id,
        port_name=tracking.port_name,
        container_type=first_c_type,
        discharge_date=tracking.discharge_date,
    )
    if tracking.currency and base_tariff.currency and tracking.currency.upper() != base_tariff.currency.upper():
        logger.warning(
            "Tracking %s has currency %s, but resolved policy currency is now %s. Keeping tracking currency.",
            tracking.tracking_code,
            tracking.currency,
            base_tariff.currency,
        )
    tariff = _agreed_tariff(base_tariff, booking_free_days, tracking.containers)
    if tracking.currency and tariff.currency != tracking.currency:
        tariff = replace(tariff, currency=tracking.currency)
    return tariff


# ----------------------------------------------------
# Settlement rows of a tracking (push / re-push)
# ----------------------------------------------------

SETTLEMENT_STALE_CODE = "DD_SETTLEMENT_STALE"
PUSHED_STATUS = "Pushed to Settlement"


def _settlement_invoice_nos(tracking: DemurrageTracking) -> Tuple[str, str, str]:
    return (
        f"INV-DND-{tracking.tracking_code}",
        f"INV-STO-{tracking.tracking_code}",
        f"INV-ANC-{tracking.tracking_code}",
    )


def _settlement_rows(tracking: DemurrageTracking) -> List[Dict[str, Any]]:
    """Expense rows, each with amount_fx x exchange_rate == amount_egp:
    1. Carrier charges (demurrage + detention, tracking currency)
    2. Port storage (EGP, rate 1.0, only when there is storage)
    3. Terminal ancillary fees (inspection, weighing, etc., in USD or EGP)
    """
    carrier_no, storage_no, anc_no = _settlement_invoice_nos(tracking)
    rate = float(tracking.exchange_rate)
    carrier_fx = round((tracking.total_demurrage_fx or 0.0) + (tracking.total_detention_fx or 0.0), 2)
    storage_egp = round(tracking.total_storage_egp or 0.0, 2)
    rows = [{
        "invoice_no": carrier_no,
        "category": "Demurrage & Storage",
        "provider_name": tracking.carrier_name,
        "currency": tracking.currency,
        "amount_fx": carrier_fx,
        "exchange_rate": rate,
        "amount_egp": round(carrier_fx * rate, 2),
        "allocation_rule": "Volume-Based",
        "notes": f"Automated Demurrage & Detention fee for B/L: {tracking.bill_of_lading_no} (Tracking: {tracking.tracking_code})",
    }]
    if storage_egp > 0:
        rows.append({
            "invoice_no": storage_no,
            "category": "Demurrage & Storage",
            "provider_name": tracking.port_name,
            "currency": "EGP",
            "amount_fx": storage_egp,
            "exchange_rate": 1.0,
            "amount_egp": storage_egp,
            "allocation_rule": "Volume-Based",
            "notes": f"Automated port storage fee for B/L: {tracking.bill_of_lading_no} (Tracking: {tracking.tracking_code})",
        })

    # Ancillary terminal fees (Inspection, Weighing, Reefer electricity)
    ancillary = tracking.ancillary_fees or []
    if ancillary:
        total_anc_usd = sum(float(f.get("amount_usd", 0.0)) for f in ancillary if isinstance(f, dict))
        total_anc_egp = sum(float(f.get("amount_egp", 0.0)) for f in ancillary if isinstance(f, dict))
        if total_anc_usd > 0 or total_anc_egp > 0:
            if total_anc_usd > 0 and total_anc_egp == 0:
                total_anc_egp = round(total_anc_usd * rate, 2)
            elif total_anc_egp > 0 and total_anc_usd == 0:
                total_anc_usd = round(total_anc_egp / rate, 2)

            rows.append({
                "invoice_no": anc_no,
                "category": "Port Charges",
                "provider_name": tracking.port_name,
                "currency": tracking.currency or "USD",
                "amount_fx": round(total_anc_usd, 2),
                "exchange_rate": rate,
                "amount_egp": round(total_anc_egp, 2),
                "allocation_rule": "Volume-Based",
                "notes": f"Automated terminal ancillary fees (Inspection/Weighing) for B/L: {tracking.bill_of_lading_no} (Tracking: {tracking.tracking_code})",
            })
    return rows


def _write_settlement_rows(settlement: Any, tracking: DemurrageTracking, user: str) -> List[Dict[str, Any]]:
    """Replaces the tracking's rows (by invoice number) in the settlement; totals are left to the settlement
    recalculation. No commit."""
    own = set(_settlement_invoice_nos(tracking))
    invoices = [i for i in (settlement.expense_invoices or []) if i.get("invoice_no") not in own]
    rows = _settlement_rows(tracking)
    invoices.extend(rows)
    settlement.expense_invoices = invoices
    flag_modified(settlement, "expense_invoices")
    settlement.updated_by = user
    return rows


def _repush_recalculated(db: Session, tracking: DemurrageTracking, user: str) -> Tuple[Optional[int], Optional[str]]:
    """A pushed tracking that was recalculated keeps its pushed flag and status, and its settlement rows follow
    (no commit). Returns (settlement id to recalculate after the commit, warning code). A locked or missing
    settlement is not touched: the tracking is still updated and DD_SETTLEMENT_STALE is returned."""
    if not tracking.is_pushed_to_settlement:
        return None, None
    tracking.status = PUSHED_STATUS
    from modules.financial_settlement.repository import get_settlement_by_id
    from modules.financial_settlement.validators import LOCKED_SETTLEMENT_STATUSES
    settlement = get_settlement_by_id(db, tracking.settlement_record_id) if tracking.settlement_record_id else None
    if settlement is None or (settlement.status or "") in LOCKED_SETTLEMENT_STATUSES:
        logger.warning("Tracking %s recalculated but its settlement is locked or missing: not re-pushed", tracking.tracking_code)
        return None, SETTLEMENT_STALE_CODE
    _write_settlement_rows(settlement, tracking, user)
    return settlement.settlement_id, None


def _recalculate_settlement_follow_up(db: Session, settlement_id: Optional[int], user: str) -> bool:
    """Landed-cost totals of the settlement after the commit (best effort: never undoes the saved tracking)."""
    if not settlement_id:
        return False

    def _run() -> bool:
        from modules.financial_settlement.service import recalculate_settlement_service
        recalculate_settlement_service(db, settlement_id, actor=user)
        return True

    return best_effort(db, _run, f"Settlement {settlement_id} recalculation after demurrage push") is True


def _tracking_rate(tracking: DemurrageTracking) -> float:
    """The stored FX rate of a tracking; no invented fallback."""
    rate = tracking.exchange_rate
    if not rate or rate <= 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"سعر الصرف غير مسجل لجلسة التتبع {tracking.tracking_code}. يرجى تحديث سعر الصرف أولاً.",
        )
    return float(rate)


def _resolve_exchange_rate(db: Session, currency: str, on_date: date) -> float:
    """Commercial (bank) rate to EGP effective at ``on_date`` (Q12 safe default). No hard-coded fallback."""
    code = (currency or "").upper().strip()
    if code == "EGP":
        return 1.0
    from modules.currencies.repository import CurrencyRepository
    repo = CurrencyRepository(db)
    currency_row = repo.get_currency_by_code(code)
    rate_row = repo.get_latest_rate(currency_row.currency_id, target_date=on_date) if currency_row else None
    if not rate_row or not rate_row.commercial_rate or rate_row.commercial_rate <= 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"لا يوجد سعر صرف مسجل للعملة {code} بتاريخ {on_date}. أدخل سعر الصرف يدويًا أو سجّل السعر في شاشة العملات.",
        )
    return float(rate_row.commercial_rate)


def _parse_date(value: Any) -> Optional[date]:
    if not value:
        return None
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value).split("T")[0])


def _recalculate_containers(
    tracking: DemurrageTracking,
    tariff: Tariff,
    rate: float,
    gate_out: Optional[date],
    empty_return: Optional[date],
    status_fn: Optional[Callable[[Dict[str, Any], Any, Optional[date], Optional[date]], str]] = None,
    calc_date: Optional[date] = None,
) -> Tuple[List[Dict[str, Any]], float, float, float]:
    """Recalculates every container of the tracking with ``tariff``. Only COMPUTED_CONTAINER_KEYS change;
    a container's own gate-out / return dates win over the tracking-level dates. Returns
    (containers, demurrage_fx, detention_fx, storage_egp) with unrounded sums."""
    out: List[Dict[str, Any]] = []
    total_dem = total_det = total_stor = 0.0
    container_count = len(tracking.containers or [])
    for c in (tracking.containers or []):
        item = dict(c)
        c_gate_out = _parse_date(item.get("gate_out_timestamp")) or _parse_date(item.get("gate_out_date")) or gate_out
        
        # Cease penalty accrual for any container with established eir_timestamp or empty_return_date
        c_eir_ts = item.get("eir_timestamp")
        c_ret_date = item.get("empty_return_date")
        if c_eir_ts or c_ret_date:
            c_return = _parse_date(c_eir_ts) or _parse_date(c_ret_date)
        elif container_count > 1:
            c_return = None
        else:
            c_return = empty_return

        sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
            carrier_name=tracking.carrier_name,
            container_type=item.get("container_type") or "40ft High Cube",
            containers_count=1,
            demurrage_free_days=tariff.demurrage_free_days,
            detention_free_days=tariff.detention_free_days,
            port_storage_free_days=tariff.storage_free_days,
            port_storage_daily_rate_egp=tariff.storage_rate_egp,
            demurrage_tiers=tariff.demurrage_tiers,
            detention_tiers=tariff.detention_tiers,
            storage_tiers=tariff.storage_tiers,
            storage_currency=tariff.storage_currency,
            port_name=tracking.port_name,
            carrier_id=tracking.carrier_id,
            terminal_id=tracking.terminal_id,
            discharge_date=tracking.discharge_date,
            gate_out_date=c_gate_out,
            empty_return_date=c_return,
            calculation_date=calc_date or _today(),
            currency=tracking.currency or "USD",
            exchange_rate=rate,
        ))
        item.update({
            "demurrage_days": sim.demurrage_days_overdue,
            "detention_days": sim.detention_days_overdue,
            "storage_days": sim.storage_days_overdue,
            "demurrage_fx": sim.demurrage_fee_fx,
            "detention_fx": sim.detention_fee_fx,
            "storage_egp": sim.storage_fee_egp,
            "storage_fx": sim.storage_fee_fx,
            "total_egp": sim.total_cost_egp,
            "individual_demurrage_cost": round(sim.demurrage_fee_fx + sim.detention_fee_fx, 2),
            "status": status_fn(item, sim, c_gate_out, c_return) if status_fn else sim.status_badge,
        })
        out.append(item)
        total_dem += sim.demurrage_fee_fx
        total_det += sim.detention_fee_fx
        total_stor += sim.storage_fee_egp
    return out, total_dem, total_det, total_stor


def _apply_totals(tracking: DemurrageTracking, containers: List[Dict[str, Any]], dem: float, det: float, stor: float, rate: float) -> None:
    tracking.containers = containers
    flag_modified(tracking, "containers")
    tracking.total_demurrage_fx = round(dem, 2)
    tracking.total_detention_fx = round(det, 2)
    tracking.total_storage_egp = round(stor, 2)
    tracking.total_cost_egp = round(((dem + det) * rate) + stor, 2)


def _incurred_status(dem: float, det: float) -> str:
    if dem > 0 and det > 0:
        return "Demurrage & Detention Incurred"
    if dem > 0:
        return "Demurrage Incurred"
    if det > 0:
        return "Detention Incurred"
    return "Free Time Active"


def calculate_tiered_fee(
    overdue_days: int,
    tiers: List[Dict[str, Any]],
    day_offset: int = 0,
) -> Dict[str, Any]:
    """
    Calculates the accumulated fee over overdue days based on tiered rate brackets.
    Supports day_offset for calendar-anchored tiers or concession free-time offsets.
    Returns total fee and tier breakdown.
    """
    if overdue_days <= 0 or not tiers:
        return {"total_fee": 0.0, "tier_breakdown": []}

    sorted_tiers = sorted(tiers, key=lambda t: t.get("from_day", 1))
    min_from = sorted_tiers[0].get("from_day", 1)

    effective_offset = day_offset
    if effective_offset == 0 and min_from > 1:
        # If tiers start beyond day 1 (e.g. from_day: 8), auto-anchor to calendar days
        effective_offset = min_from - 1

    total_fee = 0.0
    tier_counts: Dict[int, int] = {i: 0 for i in range(len(sorted_tiers))}

    for day in range(1, overdue_days + 1):
        actual_day = day + effective_offset
        matched = False
        for idx, t in enumerate(sorted_tiers):
            from_d = t.get("from_day", 1)
            to_d = t.get("to_day")
            if from_d <= actual_day and (to_d is None or actual_day <= to_d):
                matching_rate = float(t.get("rate_per_day", 0.0))
                total_fee += matching_rate
                tier_counts[idx] += 1
                matched = True
                break
        if not matched and sorted_tiers:
            last_idx = len(sorted_tiers) - 1
            total_fee += float(sorted_tiers[last_idx].get("rate_per_day", 0.0))
            tier_counts[last_idx] += 1

    tier_breakdown = []
    for idx, t in enumerate(sorted_tiers):
        count = tier_counts[idx]
        if count > 0:
            from_d = t.get("from_day", 1)
            to_d = t.get("to_day")
            rate = float(t.get("rate_per_day", 0.0))
            tier_breakdown.append({
                "tier_name": f"الأيام {from_d} - {to_d or 'ما بعدها'}",
                "rate_per_day": rate,
                "days_applied": count,
                "tier_cost": round(count * rate, 2),
            })

    return {"total_fee": round(total_fee, 2), "tier_breakdown": tier_breakdown}


def simulate_demurrage_and_detention(req: DemurrageSimulationRequest) -> DemurrageSimulationResponse:
    """
    Simulates Demurrage, Detention, and Port Storage calculations with full breakdowns.
    """
    validate_demurrage_dates(
        req.discharge_date,
        req.gate_out_date,
        req.empty_return_date,
        today=None,
        require_gate_out_for_empty_return=False,
    )

    calc_date = req.calculation_date or _today()
    dem_tiers = [t.model_dump() if hasattr(t, 'model_dump') else t for t in (req.demurrage_tiers or DEFAULT_DEMURRAGE_TIERS)]
    det_tiers = [t.model_dump() if hasattr(t, 'model_dump') else t for t in (req.detention_tiers or DEFAULT_DETENTION_TIERS)]

    # 1. Demurrage calculation (Discharge to Gate-Out / Calc Date)
    demurrage_end_date = req.gate_out_date or calc_date
    if req.empty_return_date and req.empty_return_date < demurrage_end_date:
        demurrage_end_date = req.empty_return_date
    demurrage_days_consumed = max(0, (demurrage_end_date - req.discharge_date).days)
    demurrage_days_overdue = max(0, demurrage_days_consumed - req.demurrage_free_days)
    demurrage_expiry_date = req.discharge_date + timedelta(days=req.demurrage_free_days)

    # Determine demurrage day offset (tier anchor logic)
    dem_day_offset = 0
    if dem_tiers:
        min_dem_from = min(t.get("from_day", 1) for t in dem_tiers)
        max_dem_to = max(t.get("to_day") or 9999 for t in dem_tiers)
        if min_dem_from == 1 and req.demurrage_free_days > 14 and max_dem_to > req.demurrage_free_days:
            dem_day_offset = req.demurrage_free_days

    dem_calc = calculate_tiered_fee(demurrage_days_overdue, dem_tiers, day_offset=dem_day_offset)
    single_container_dem_fx = dem_calc["total_fee"]
    total_demurrage_fx = round(single_container_dem_fx * req.containers_count, 2)

    # 2. Detention calculation (Gate-Out to Empty Return / Calc Date)
    detention_days_consumed = 0
    detention_days_overdue = 0
    total_detention_fx = 0.0
    detention_expiry_date = None
    det_calc = {"total_fee": 0.0, "tier_breakdown": []}

    if req.gate_out_date:
        detention_expiry_date = req.gate_out_date + timedelta(days=req.detention_free_days)
        detention_end_date = req.empty_return_date or calc_date
        detention_days_consumed = max(0, (detention_end_date - req.gate_out_date).days)
        detention_days_overdue = max(0, detention_days_consumed - req.detention_free_days)
        det_calc = calculate_tiered_fee(detention_days_overdue, det_tiers)
        total_detention_fx = round(det_calc["total_fee"] * req.containers_count, 2)

    # 3. Port Storage calculation
    # Decouple storage end date: port storage stops strictly at gate-out.
    # If gate_out_date is not set, empty_return_date implies it already gated out.
    storage_end_date = req.gate_out_date or req.empty_return_date or calc_date
    storage_days_consumed = max(0, (storage_end_date - req.discharge_date).days)

    # IMO adjustments if is_imo is True
    effective_storage_free_days = req.port_storage_free_days
    imo_multiplier = 1.0
    if req.is_imo:
        effective_storage_free_days = min(effective_storage_free_days, 1)
        imo_multiplier = 2.0

    storage_days_overdue = max(0, storage_days_consumed - effective_storage_free_days)

    storage_tier_breakdown = []
    storage_fee_fx = 0.0
    storage_fee_egp = 0.0

    if req.storage_tiers:
        stor_tiers = [t.model_dump() if hasattr(t, 'model_dump') else t for t in req.storage_tiers]
        stor_calc = calculate_tiered_fee(storage_days_overdue, stor_tiers, day_offset=effective_storage_free_days)
        base_storage_fee = stor_calc["total_fee"] * imo_multiplier
        storage_tier_breakdown = stor_calc.get("tier_breakdown", [])

        if (req.storage_currency or "USD").upper() == "USD":
            storage_fee_fx = round(base_storage_fee * req.containers_count, 2)
            storage_fee_egp = round(storage_fee_fx * req.exchange_rate, 2)
        else:
            storage_fee_egp = round(base_storage_fee * req.containers_count, 2)
            storage_fee_fx = round(storage_fee_egp / req.exchange_rate, 2) if req.exchange_rate else 0.0
    else:
        # Legacy daily rate fallback
        storage_fee_egp = round(storage_days_overdue * req.port_storage_daily_rate_egp * req.containers_count * imo_multiplier, 2)
        storage_fee_fx = round(storage_fee_egp / req.exchange_rate, 2) if req.exchange_rate else 0.0

    # 4. Ancillary fees calculation (Inspection, Weighing, Reefer Monitoring)
    ancillary_fee_fx = 0.0
    ancillary_fee_egp = 0.0
    ancillary_items = []
    if req.ancillary_fees:
        for f in req.ancillary_fees:
            if isinstance(f, dict):
                usd = float(f.get("amount_usd", 0.0))
                egp = float(f.get("amount_egp", 0.0))
                if usd > 0:
                    ancillary_fee_fx += usd
                    ancillary_fee_egp += usd * req.exchange_rate
                elif egp > 0:
                    ancillary_fee_egp += egp
                    ancillary_fee_fx += (egp / req.exchange_rate) if req.exchange_rate else 0.0
                ancillary_items.append(f)
        ancillary_fee_fx = round(ancillary_fee_fx * req.containers_count, 2)
        ancillary_fee_egp = round(ancillary_fee_egp * req.containers_count, 2)

    # 5. Totals and Currency Conversions
    total_fee_fx = round(total_demurrage_fx + total_detention_fx, 2)
    total_cost_egp = round((total_fee_fx * req.exchange_rate) + storage_fee_egp + ancillary_fee_egp, 2)

    # 6. Status & Countdown Summary
    if demurrage_days_overdue > 0 and detention_days_overdue > 0:
        status_badge = "DEMURRAGE_AND_DETENTION_INCURRED"
        countdown_summary = f"⚠️ تم تجاوز فترة السماح: تأخير غرامات الخط {demurrage_days_overdue} يوم + تأخير فارغ {detention_days_overdue} يوم."
    elif demurrage_days_overdue > 0:
        status_badge = "DEMURRAGE_INCURRED"
        countdown_summary = f"🚨 غرامة تأخير الحاوية للخط الملاحي سارية بمقدار {demurrage_days_overdue} يوم تأخير."
    elif detention_days_overdue > 0:
        status_badge = "DETENTION_INCURRED"
        countdown_summary = f"🚨 غرامة تأخير إعادة الحاوية الفارغة سارية بمقدار {detention_days_overdue} يوم تأخير."
    elif storage_days_overdue > 0:
        # Crucial distinction: Port Storage is running in EGP even though Shipping Line Demurrage is SAFE!
        status_badge = "STORAGE_INCURRED"
        days_left_dem = max(0, req.demurrage_free_days - demurrage_days_consumed)
        countdown_summary = (
            f"⚠️ سريان أرضيات ساحات الميناء بمقدار {storage_days_overdue} يوم تأخير ({storage_fee_egp:,.2f} ج.م) "
            f"رغم سريان سماح الخط الملاحي (متبقي {days_left_dem} يوم بدون غرامات خط)."
        )
    else:
        days_left_demurrage = max(0, req.demurrage_free_days - demurrage_days_consumed)
        days_left_storage = max(0, req.port_storage_free_days - storage_days_consumed)
        if days_left_demurrage <= 3:
            status_badge = "WARNING"
            countdown_summary = f"⚠️ تحذير: متبقي {days_left_demurrage} أيام فقط على انتهاء سماح غرامات الحاوية للخط ({demurrage_expiry_date.strftime('%Y-%m-%d')})."
        elif days_left_storage <= 1 and not req.gate_out_date:
            status_badge = "STORAGE_WARNING_48H"
            countdown_summary = (
                f"⚠️ تحذير حرج: متبقي {days_left_storage} أيام فقط على بدء أرضيات ساحات الميناء بالجنيه "
                f"(سماح الخط الملاحي: متبقي {days_left_demurrage} يوم)."
            )
        else:
            status_badge = "SAFE"
            countdown_summary = f"✅ فترة السماح سارية: متبقي {days_left_demurrage} يوم بدون أي غرامات (حتى {demurrage_expiry_date.strftime('%Y-%m-%d')})."

    breakdown_details = [
        {
            "category": "Demurrage (غرامات تأخير الحاوية للخط الملاحي)",
            "days_consumed": demurrage_days_consumed,
            "free_days": req.demurrage_free_days,
            "days_overdue": demurrage_days_overdue,
            "fee_fx": total_demurrage_fx,
            "currency": req.currency,
            "expiry_date": str(demurrage_expiry_date),
            "tiers_applied": dem_calc.get("tier_breakdown", []),
            "scope": "Shipping Line Demurrage (تتأثر باتفاقية الـ 21 يوماً)",
        },
        {
            "category": "Detention (تأخير إعادة الحاوية الفارغة)",
            "days_consumed": detention_days_consumed,
            "free_days": req.detention_free_days,
            "days_overdue": detention_days_overdue,
            "fee_fx": total_detention_fx,
            "currency": req.currency,
            "expiry_date": str(detention_expiry_date) if detention_expiry_date else None,
            "tiers_applied": det_calc.get("tier_breakdown", []),
        },
        {
            "category": "Port Storage (أرضيات وساحات هيئة الميناء)",
            "days_consumed": storage_days_consumed,
            "free_days": effective_storage_free_days,
            "days_overdue": storage_days_overdue,
            "fee_fx": storage_fee_fx,
            "fee_egp": storage_fee_egp,
            "currency": req.storage_currency,
            "tiers_applied": storage_tier_breakdown,
            "scope": "Port Terminal Storage (تخضع لتعريفة الميناء ولا تمتد باتفاقية الخط)",
        }
    ]

    if ancillary_items:
        breakdown_details.append({
            "category": "Terminal Ancillary Fees (مصاريف المحطة الملحقة: كشف/وزن)",
            "fee_fx": ancillary_fee_fx,
            "fee_egp": ancillary_fee_egp,
            "currency": req.currency,
            "items": ancillary_items,
        })

    return DemurrageSimulationResponse(
        demurrage_days_consumed=demurrage_days_consumed,
        demurrage_free_days=req.demurrage_free_days,
        demurrage_days_overdue=demurrage_days_overdue,
        demurrage_fee_fx=total_demurrage_fx,
        demurrage_expiry_date=demurrage_expiry_date,
        detention_days_consumed=detention_days_consumed,
        detention_free_days=req.detention_free_days,
        detention_days_overdue=detention_days_overdue,
        detention_fee_fx=total_detention_fx,
        detention_expiry_date=detention_expiry_date,
        storage_days_consumed=storage_days_consumed,
        storage_free_days=effective_storage_free_days,
        storage_days_overdue=storage_days_overdue,
        storage_fee_fx=storage_fee_fx,
        storage_fee_egp=storage_fee_egp,
        storage_currency=req.storage_currency,
        storage_tier_breakdown=storage_tier_breakdown,
        ancillary_fee_fx=ancillary_fee_fx,
        ancillary_fee_egp=ancillary_fee_egp,
        total_fee_fx=total_fee_fx,
        total_cost_egp=total_cost_egp,
        status_badge=status_badge,
        countdown_summary_ar=countdown_summary,
        breakdown_details=breakdown_details,
    )


def calculate_demurrage_detention_service(
    db: Session, req: DemurrageSimulationRequest
) -> DemurrageSimulationResponse:
    """
    Core Demurrage & Detention Calculation Service (MD-TERM-CARR-001).
    1. Automatically resolves effective Carrier Demurrage and Terminal Storage rate cards
       using (effective_date <= discharge_date) rather than fixed policies.
    2. Overrides default tiers/free days with effective historical rate cards when not explicitly supplied.
    3. Calculates tiered demurrage, detention, and terminal storage (with IMO support).
    4. Calculates terminal ancillary fees (ancillary_fees: inspection, weighing, reefer).
    """
    first_c_type = req.container_type or "40ft High Cube"
    resolved_tariff = _resolve_tariff(
        db,
        policy=None,
        carrier_id=req.carrier_id,
        carrier_name=req.carrier_name,
        terminal_id=req.terminal_id,
        port_name=req.port_name,
        container_type=first_c_type,
        discharge_date=req.discharge_date,
    )

    sent = req.model_fields_set
    update_dict: Dict[str, Any] = {}

    if "demurrage_free_days" not in sent or req.demurrage_free_days is None:
        update_dict["demurrage_free_days"] = resolved_tariff.demurrage_free_days
    if "detention_free_days" not in sent or req.detention_free_days is None:
        update_dict["detention_free_days"] = resolved_tariff.detention_free_days
    if "port_storage_free_days" not in sent or req.port_storage_free_days is None:
        update_dict["port_storage_free_days"] = resolved_tariff.storage_free_days
    if "port_storage_daily_rate_egp" not in sent or req.port_storage_daily_rate_egp is None:
        update_dict["port_storage_daily_rate_egp"] = resolved_tariff.storage_rate_egp
    if ("demurrage_tiers" not in sent or not req.demurrage_tiers) and resolved_tariff.demurrage_tiers:
        update_dict["demurrage_tiers"] = [TierRateItem(**t) for t in resolved_tariff.demurrage_tiers]
    if ("detention_tiers" not in sent or not req.detention_tiers) and resolved_tariff.detention_tiers:
        update_dict["detention_tiers"] = [TierRateItem(**t) for t in resolved_tariff.detention_tiers]
    if ("storage_tiers" not in sent or not req.storage_tiers) and resolved_tariff.storage_tiers:
        update_dict["storage_tiers"] = [TierRateItem(**t) for t in resolved_tariff.storage_tiers]
    if "storage_currency" not in sent or not req.storage_currency:
        update_dict["storage_currency"] = resolved_tariff.storage_currency

    filled = req.model_copy(update=update_dict)
    return simulate_demurrage_and_detention(filled)


def simulate_with_defaults(db: Session, req: DemurrageSimulationRequest) -> DemurrageSimulationResponse:
    """/simulate: resolves historical rate cards for carrier & terminal and calculates charges."""
    return calculate_demurrage_detention_service(db, req)


# ----------------------------------------------------
# Policy Service Operations
# ----------------------------------------------------

