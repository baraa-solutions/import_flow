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
DD_AVOIDANCE_RATE_USD = "DD_AVOIDANCE_RATE_USD"
DEFAULT_FREE_DAYS_DEMURRAGE = 14
DEFAULT_FREE_DAYS_DETENTION = 7
DEFAULT_STORAGE_FREE_DAYS = 5
DEFAULT_STORAGE_RATE_EGP = 250.0
DEFAULT_TARIFF_CURRENCY = "USD"
DEFAULT_STANDARD_FREE_DAYS = 14
DEFAULT_AVOIDANCE_RATE_USD = 70.0

# Keys of a tracking container written by the calculation; every other key (EIR, seal, per-container dates,
# condition, damage, depot, notes) is kept on recalculation.
COMPUTED_CONTAINER_KEYS = ("demurrage_days", "detention_days", "storage_days", "demurrage_fx", "detention_fx", "storage_egp", "total_egp", "status")


def _today() -> date:
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
    for c in (tracking.containers or []):
        item = dict(c)
        c_gate_out = _parse_date(item.get("gate_out_date")) or gate_out
        c_return = _parse_date(item.get("empty_return_date")) or empty_return
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
        countdown_summary = f"⚠️ تم تجاوز فترة السماح: تأخير أرضيات {demurrage_days_overdue} يوم + تأخير فارغ {detention_days_overdue} يوم."
    elif demurrage_days_overdue > 0:
        status_badge = "DEMURRAGE_INCURRED"
        countdown_summary = f"🚨 غرامة أرضيات سارية بمقدار {demurrage_days_overdue} يوم تأخير."
    elif detention_days_overdue > 0:
        status_badge = "DETENTION_INCURRED"
        countdown_summary = f"🚨 غرامة تأخير فارغ سارية بمقدار {detention_days_overdue} يوم تأخير."
    else:
        days_left_demurrage = max(0, req.demurrage_free_days - demurrage_days_consumed)
        if days_left_demurrage <= 3:
            status_badge = "WARNING"
            countdown_summary = f"⚠️ تحذير: متبقي {days_left_demurrage} أيام فقط على انتهاء سماح الأرضيات ({demurrage_expiry_date.strftime('%Y-%m-%d')})."
        else:
            status_badge = "SAFE"
            countdown_summary = f"✅ فترة السماح سارية: متبقي {days_left_demurrage} يوم بدون أي غرامات (حتى {demurrage_expiry_date.strftime('%Y-%m-%d')})."

    breakdown_details = [
        {
            "category": "Demurrage (أرضيات الميناء)",
            "days_consumed": demurrage_days_consumed,
            "free_days": req.demurrage_free_days,
            "days_overdue": demurrage_days_overdue,
            "fee_fx": total_demurrage_fx,
            "currency": req.currency,
            "expiry_date": str(demurrage_expiry_date),
            "tiers_applied": dem_calc.get("tier_breakdown", []),
        },
        {
            "category": "Detention (تأخير الحاوية الفارغة)",
            "days_consumed": detention_days_consumed,
            "free_days": req.detention_free_days,
            "days_overdue": detention_days_overdue,
            "fee_fx": total_detention_fx,
            "currency": req.currency,
            "expiry_date": str(detention_expiry_date) if detention_expiry_date else None,
            "tiers_applied": det_calc.get("tier_breakdown", []),
        },
        {
            "category": "Port Storage (تخزين ساحات الميناء)",
            "days_consumed": storage_days_consumed,
            "free_days": effective_storage_free_days,
            "days_overdue": storage_days_overdue,
            "fee_fx": storage_fee_fx,
            "fee_egp": storage_fee_egp,
            "currency": req.storage_currency,
            "tiers_applied": storage_tier_breakdown,
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
    if storage_status == "OVERDUE_STORAGE" or carrier_status == "OVERDUE_DEMURRAGE":
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
            c_empty_ret = _parse_date(c.get("empty_return_date")) or t.empty_return_date

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
            imp_file.progress_percent = max(float(imp_file.progress_percent or 0.0), 98.0)
            set_file_tracking(imp_file, step_code="STEP_20", next_action=msg("NA_CLO_SETTLE_FINAL_INVOICES"))

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


