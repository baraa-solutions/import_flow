import logging
from datetime import datetime, timezone, date, timedelta
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from .model import DemurragePolicy, DemurrageTracking
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
)
from .validators import validate_tier_rates, validate_demurrage_dates, validate_positive_amount
from . import repository
from modules.common import enum_codes
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking

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


def calculate_tiered_fee(overdue_days: int, tiers: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Calculates the accumulated fee over overdue days based on tiered rate brackets.
    Returns total fee and tier breakdown.
    """
    if overdue_days <= 0 or not tiers:
        return {"total_fee": 0.0, "tier_breakdown": []}

    total_fee = 0.0
    tier_breakdown = []
    
    # Sort tiers by starting day
    sorted_tiers = sorted(tiers, key=lambda t: t.get("from_day", 1))

    for day in range(1, overdue_days + 1):
        matching_rate = 0.0
        applied_tier_name = "Base Tier"
        for t in sorted_tiers:
            from_d = t.get("from_day", 1)
            to_d = t.get("to_day")
            if from_d <= day and (to_d is None or day <= to_d):
                matching_rate = float(t.get("rate_per_day", 0.0))
                applied_tier_name = f"Day {from_d} to {to_d or '∞'}"
                break
        total_fee += matching_rate

    # Generate summary per tier
    for t in sorted_tiers:
        from_d = t.get("from_day", 1)
        to_d = t.get("to_day")
        rate = float(t.get("rate_per_day", 0.0))
        if overdue_days >= from_d:
            days_in_this_tier = min(overdue_days, to_d) - from_d + 1 if to_d else overdue_days - from_d + 1
            days_in_this_tier = max(0, days_in_this_tier)
            cost_in_tier = days_in_this_tier * rate
            tier_breakdown.append({
                "tier_name": f"الأيام {from_d} - {to_d or 'ما بعدها'}",
                "rate_per_day": rate,
                "days_applied": days_in_this_tier,
                "tier_cost": round(cost_in_tier, 2),
            })

    return {"total_fee": round(total_fee, 2), "tier_breakdown": tier_breakdown}


def simulate_demurrage_and_detention(req: DemurrageSimulationRequest) -> DemurrageSimulationResponse:
    """
    Simulates Demurrage, Detention, and Port Storage calculations with full breakdowns.
    """
    validate_demurrage_dates(req.discharge_date, req.gate_out_date, req.empty_return_date)

    calc_date = req.calculation_date or date.today()
    dem_tiers = [t.model_dump() if hasattr(t, 'model_dump') else t for t in (req.demurrage_tiers or DEFAULT_DEMURRAGE_TIERS)]
    det_tiers = [t.model_dump() if hasattr(t, 'model_dump') else t for t in (req.detention_tiers or DEFAULT_DETENTION_TIERS)]

    # 1. Demurrage calculation (Discharge to Gate-Out / Calc Date)
    demurrage_end_date = req.gate_out_date or calc_date
    demurrage_days_consumed = max(0, (demurrage_end_date - req.discharge_date).days)
    demurrage_days_overdue = max(0, demurrage_days_consumed - req.demurrage_free_days)
    demurrage_expiry_date = req.discharge_date + timedelta(days=req.demurrage_free_days)

    dem_calc = calculate_tiered_fee(demurrage_days_overdue, dem_tiers)
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
    storage_end_date = req.gate_out_date or calc_date
    storage_days_consumed = max(0, (storage_end_date - req.discharge_date).days)
    storage_days_overdue = max(0, storage_days_consumed - req.port_storage_free_days)
    storage_fee_egp = round(storage_days_overdue * req.port_storage_daily_rate_egp * req.containers_count, 2)

    # 4. Totals and Currency Conversions
    total_fee_fx = round(total_demurrage_fx + total_detention_fx, 2)
    total_cost_egp = round((total_fee_fx * req.exchange_rate) + storage_fee_egp, 2)

    # 5. Status & Countdown Summary
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
            "free_days": req.port_storage_free_days,
            "days_overdue": storage_days_overdue,
            "fee_egp": storage_fee_egp,
            "currency": "EGP",
        }
    ]

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
        storage_free_days=req.port_storage_free_days,
        storage_days_overdue=storage_days_overdue,
        storage_fee_egp=storage_fee_egp,
        total_fee_fx=total_fee_fx,
        total_cost_egp=total_cost_egp,
        status_badge=status_badge,
        countdown_summary_ar=countdown_summary,
        breakdown_details=breakdown_details,
    )


# ----------------------------------------------------
# Policy Service Operations
# ----------------------------------------------------

def create_demurrage_policy_service(db: Session, req: DemurragePolicyCreate, user: str = "System") -> DemurragePolicy:
    validate_tier_rates(req.demurrage_tiers, "Demurrage Tiers")
    validate_tier_rates(req.detention_tiers, "Detention Tiers")

    data = req.model_dump()
    if not data.get("demurrage_tiers"):
        data["demurrage_tiers"] = DEFAULT_DEMURRAGE_TIERS
    if not data.get("detention_tiers"):
        data["detention_tiers"] = DEFAULT_DETENTION_TIERS

    return repository.create_policy(db, data, user=user)


def get_demurrage_policies_service(
    db: Session, carrier_name: Optional[str] = None, container_type: Optional[str] = None
) -> List[DemurragePolicy]:
    return repository.get_policies(db, carrier_name=carrier_name, container_type=container_type)


def get_demurrage_policy_by_id_service(db: Session, policy_id: int) -> DemurragePolicy:
    policy = repository.get_policy_by_id(db, policy_id)
    if not policy:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Demurrage policy #{policy_id} not found.")
    return policy


def update_demurrage_policy_service(
    db: Session, policy_id: int, req: DemurragePolicyUpdate, user: str = "System"
) -> DemurragePolicy:
    policy = get_demurrage_policy_by_id_service(db, policy_id)
    if req.demurrage_tiers:
        validate_tier_rates(req.demurrage_tiers, "Demurrage Tiers")
    if req.detention_tiers:
        validate_tier_rates(req.detention_tiers, "Detention Tiers")

    return repository.update_policy(db, policy, req.model_dump(exclude_unset=True), user=user)


def delete_demurrage_policy_service(db: Session, policy_id: int, user: str = "System") -> DemurragePolicy:
    policy = get_demurrage_policy_by_id_service(db, policy_id)
    return repository.delete_policy(db, policy, user=user)


# ----------------------------------------------------
# Tracking Service Operations
# ----------------------------------------------------

def create_demurrage_tracking_service(
    db: Session, req: DemurrageTrackingCreate, user: str = "System"
) -> DemurrageTracking:
    validate_demurrage_dates(req.discharge_date, req.gate_out_date, req.empty_return_date)
    validate_positive_amount(req.exchange_rate, "exchange_rate")

    # Fetch policy if provided or search matching policy
    policy = None
    if req.policy_id:
        policy = repository.get_policy_by_id(db, req.policy_id)
    if not policy and req.carrier_name:
        first_container_type = req.containers[0].container_type if req.containers else "40ft High Cube"
        policy = repository.get_policy_for_carrier_container(db, req.carrier_name, first_container_type)

    dem_free = policy.demurrage_free_days if policy else 14
    det_free = policy.detention_free_days if policy else 7
    if req.import_file_id:
        from modules.freight_booking.model import ShipmentBooking
        booking = db.query(ShipmentBooking).filter(
            ShipmentBooking.import_file_id == req.import_file_id,
            ShipmentBooking.is_active == True,
        ).first()
        if booking and booking.free_demurrage_days:
            dem_free = booking.free_demurrage_days
    storage_free = policy.port_storage_free_days if policy else 5
    storage_rate = policy.port_storage_daily_rate_egp if policy else 250.0
    dem_tiers = policy.demurrage_tiers if policy else DEFAULT_DEMURRAGE_TIERS
    det_tiers = policy.detention_tiers if policy else DEFAULT_DETENTION_TIERS

    # Calculate per container
    calculated_containers = []
    total_dem_fx = 0.0
    total_det_fx = 0.0
    total_stor_egp = 0.0

    for c in req.containers:
        sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
            carrier_name=req.carrier_name,
            container_type=c.container_type,
            containers_count=1,
            demurrage_free_days=dem_free,
            detention_free_days=det_free,
            port_storage_free_days=storage_free,
            port_storage_daily_rate_egp=storage_rate,
            demurrage_tiers=dem_tiers,
            detention_tiers=det_tiers,
            discharge_date=req.discharge_date,
            gate_out_date=req.gate_out_date,
            empty_return_date=req.empty_return_date,
            currency=req.currency,
            exchange_rate=req.exchange_rate,
        ))

        c_item = {
            "container_no": c.container_no,
            "container_type": c.container_type,
            "demurrage_days": sim.demurrage_days_overdue,
            "detention_days": sim.detention_days_overdue,
            "storage_days": sim.storage_days_overdue,
            "demurrage_fx": sim.demurrage_fee_fx,
            "detention_fx": sim.detention_fee_fx,
            "storage_egp": sim.storage_fee_egp,
            "total_egp": sim.total_cost_egp,
            "status": sim.status_badge,
        }
        calculated_containers.append(c_item)
        total_dem_fx += sim.demurrage_fee_fx
        total_det_fx += sim.detention_fee_fx
        total_stor_egp += sim.storage_fee_egp

    total_cost_egp = round(((total_dem_fx + total_det_fx) * req.exchange_rate) + total_stor_egp, 2)

    # Determine overall status
    if total_dem_fx > 0 and total_det_fx > 0:
        overall_status = "Demurrage & Detention Incurred"
    elif total_dem_fx > 0:
        overall_status = "Demurrage Incurred"
    elif total_det_fx > 0:
        overall_status = "Detention Incurred"
    else:
        overall_status = "Free Time Active"

    tracking_data = {
        "tracking_code": repository.generate_tracking_code(db),
        "import_file_id": req.import_file_id,
        "import_file_code": req.import_file_code,
        "policy_id": policy.policy_id if policy else None,
        "carrier_name": req.carrier_name,
        "bill_of_lading_no": req.bill_of_lading_no,
        "port_name": req.port_name,
        "discharge_date": req.discharge_date,
        "gate_out_date": req.gate_out_date,
        "empty_return_date": req.empty_return_date,
        "containers": calculated_containers,
        "total_demurrage_fx": round(total_dem_fx, 2),
        "total_detention_fx": round(total_det_fx, 2),
        "total_storage_egp": round(total_stor_egp, 2),
        "currency": req.currency,
        "exchange_rate": req.exchange_rate,
        "total_cost_egp": total_cost_egp,
        "status": overall_status,
        "notes": req.notes,
    }

    return repository.create_tracking(db, tracking_data, user=user)


def get_demurrage_trackings_service(
    db: Session,
    import_file_id: Optional[int] = None,
    carrier_name: Optional[str] = None,
    status_filter: Optional[str] = None,
) -> List[DemurrageTracking]:
    return repository.get_trackings(db, import_file_id=import_file_id, carrier_name=carrier_name, status_filter=status_filter)


def get_demurrage_tracking_by_id_service(db: Session, tracking_id: int) -> DemurrageTracking:
    tracking = repository.get_tracking_by_id(db, tracking_id)
    if not tracking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Demurrage tracking #{tracking_id} not found.")
    return tracking


def recalculate_and_update_tracking_service(
    db: Session, tracking_id: int, req: DemurrageTrackingUpdate, user: str = "System"
) -> DemurrageTracking:
    tracking = get_demurrage_tracking_by_id_service(db, tracking_id)
    
    gate_out = req.gate_out_date or tracking.gate_out_date
    empty_return = req.empty_return_date or tracking.empty_return_date
    rate = req.exchange_rate or tracking.exchange_rate
    validate_demurrage_dates(tracking.discharge_date, gate_out, empty_return)

    policy = tracking.policy
    dem_free = policy.demurrage_free_days if policy else 14
    det_free = policy.detention_free_days if policy else 7
    storage_free = policy.port_storage_free_days if policy else 5
    storage_rate = policy.port_storage_daily_rate_egp if policy else 250.0
    dem_tiers = policy.demurrage_tiers if policy else DEFAULT_DEMURRAGE_TIERS
    det_tiers = policy.detention_tiers if policy else DEFAULT_DETENTION_TIERS

    recalculated_containers = []
    total_dem_fx = 0.0
    total_det_fx = 0.0
    total_stor_egp = 0.0

    for c in (tracking.containers or []):
        c_no = c.get("container_no", "")
        c_type = c.get("container_type", "40ft High Cube")
        sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
            carrier_name=tracking.carrier_name,
            container_type=c_type,
            containers_count=1,
            demurrage_free_days=dem_free,
            detention_free_days=det_free,
            port_storage_free_days=storage_free,
            port_storage_daily_rate_egp=storage_rate,
            demurrage_tiers=dem_tiers,
            detention_tiers=det_tiers,
            discharge_date=tracking.discharge_date,
            gate_out_date=gate_out,
            empty_return_date=empty_return,
            currency=tracking.currency,
            exchange_rate=rate,
        ))
        recalculated_containers.append({
            "container_no": c_no,
            "container_type": c_type,
            "demurrage_days": sim.demurrage_days_overdue,
            "detention_days": sim.detention_days_overdue,
            "storage_days": sim.storage_days_overdue,
            "demurrage_fx": sim.demurrage_fee_fx,
            "detention_fx": sim.detention_fee_fx,
            "storage_egp": sim.storage_fee_egp,
            "total_egp": sim.total_cost_egp,
            "status": sim.status_badge,
        })
        total_dem_fx += sim.demurrage_fee_fx
        total_det_fx += sim.detention_fee_fx
        total_stor_egp += sim.storage_fee_egp

    total_cost_egp = round(((total_dem_fx + total_det_fx) * rate) + total_stor_egp, 2)
    
    if total_dem_fx > 0 and total_det_fx > 0:
        overall_status = "Demurrage & Detention Incurred"
    elif total_dem_fx > 0:
        overall_status = "Demurrage Incurred"
    elif total_det_fx > 0:
        overall_status = "Detention Incurred"
    else:
        overall_status = "Free Time Active"

    data = {
        "gate_out_date": gate_out,
        "empty_return_date": empty_return,
        "exchange_rate": rate,
        "containers": recalculated_containers,
        "total_demurrage_fx": round(total_dem_fx, 2),
        "total_detention_fx": round(total_det_fx, 2),
        "total_storage_egp": round(total_stor_egp, 2),
        "total_cost_egp": total_cost_egp,
        "status": req.status or overall_status,
        "notes": req.notes or tracking.notes,
    }

    return repository.update_tracking(db, tracking, data, user=user)


def push_demurrage_to_financial_settlement_service(
    db: Session, req: PushToSettlementRequest, user: str = "System"
) -> Dict[str, Any]:
    """
    Pushes calculated Demurrage, Detention, and Storage expenses directly into Phase 9 Financial Settlement record.
    """
    tracking = get_demurrage_tracking_by_id_service(db, req.tracking_id)
    file_id = req.import_file_id or tracking.import_file_id

    if not file_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يمكن ترحيل الغرامات بدون ربط جلسة التتبع برقم ملف استيراد (Import File ID).",
        )

    from modules.financial_settlement.model import LandedCostSettlementRecord

    settlement = db.query(LandedCostSettlementRecord).filter(
        LandedCostSettlementRecord.import_file_id == file_id,
        LandedCostSettlementRecord.is_active == True,
    ).first()

    if not settlement:
        # Create a new settlement record
        count = db.query(LandedCostSettlementRecord).count()
        settlement = LandedCostSettlementRecord(
            settlement_code=f"LCS-2026-{count + 1:04d}",
            import_file_id=file_id,
            accountant_name=req.accountant_name or "Sorour Logistics Accountant",
            expense_invoices=[],
            created_by=user,
            updated_by=user,
        )
        db.add(settlement)
        db.commit()
        db.refresh(settlement)

    invoices = list(settlement.expense_invoices or [])
    
    # Check if demurrage invoice already added for this tracking
    inv_no = f"INV-DND-{tracking.tracking_code}"
    existing_inv = next((inv for inv in invoices if inv.get("invoice_no") == inv_no), None)

    invoice_entry = {
        "invoice_no": inv_no,
        "category": "Demurrage & Storage",
        "provider_name": tracking.carrier_name,
        "currency": tracking.currency,
        "amount_fx": round(tracking.total_demurrage_fx + tracking.total_detention_fx, 2),
        "exchange_rate": tracking.exchange_rate,
        "amount_egp": tracking.total_cost_egp,
        "allocation_rule": "Volume-Based",
        "notes": f"Automated Demurrage & Detention fee for B/L: {tracking.bill_of_lading_no} (Tracking: {tracking.tracking_code})",
    }

    if existing_inv:
        invoices.remove(existing_inv)
    invoices.append(invoice_entry)

    settlement.expense_invoices = invoices
    settlement.total_expenses_egp = round(sum(float(i.get("amount_egp", 0.0)) for i in invoices), 2)
    settlement.updated_by = user
    
    tracking.is_pushed_to_settlement = True
    tracking.settlement_record_id = settlement.settlement_id
    tracking.status = "Pushed to Settlement"
    tracking.updated_by = user

    db.commit()
    db.refresh(settlement)
    db.refresh(tracking)

    # Lifecycle advance: STEP_18 → STEP_19 (Demurrage finalized & pushed → Warehouse Receiving)
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=file_id,
            completed_step_code="STEP_18",
            target_step_codes=["STEP_19"],
            notes_msg=msg("DD_CHARGES_POSTED", tracking_code=tracking.tracking_code),
            assigned_user=user,
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance STEP_18->STEP_19 failed: %s", e)

    return {
        "success": True,
        "message": f"تم ترحيل غرامات الحاويات بقيمة {tracking.total_cost_egp:,.2f} جنيه إلى التسوية المالية لملف الاستيراد بنجاح.",
        "settlement_id": settlement.settlement_id,
        "settlement_code": settlement.settlement_code,
        "invoice_entry": invoice_entry,
    }



# =========================================================================
# LOG-DUAL-001: Dual Clock Radar Service
# =========================================================================

def get_dual_clock_status_service(db: Session, tracking_id: int) -> DualClockResponse:
    tracking = get_demurrage_tracking_by_id_service(db, tracking_id)
    policy = tracking.policy
    
    # 1. Carrier Demurrage Clock (USD)
    carrier_free = policy.demurrage_free_days if policy else 14
    demurrage_expiry = tracking.discharge_date + timedelta(days=carrier_free)
    
    today = date.today()
    ref_date = tracking.gate_out_date or today
    carrier_days_consumed = max(0, (ref_date - tracking.discharge_date).days)
    carrier_days_remaining = max(0, carrier_free - carrier_days_consumed)
    
    if tracking.gate_out_date:
        carrier_status = "GATED_OUT_SAFE" if carrier_days_consumed <= carrier_free else "OVERDUE_DEMURRAGE"
    elif carrier_days_remaining == 0:
        carrier_status = "OVERDUE_DEMURRAGE"
    elif carrier_days_remaining <= 3:
        carrier_status = "WARNING_LAST_3_DAYS"
    else:
        carrier_status = "SAFE"

    carrier_clock = CarrierDemurrageClock(
        carrier_name=tracking.carrier_name,
        free_days_allowed=carrier_free,
        days_consumed=carrier_days_consumed,
        days_remaining=carrier_days_remaining,
        expiry_date=demurrage_expiry,
        accrued_demurrage_fx=tracking.total_demurrage_fx,
        currency=tracking.currency or "USD",
        status=carrier_status,
    )

    # 2. Port Storage Clock (EGP)
    storage_free = policy.port_storage_free_days if policy else 5
    storage_rate = policy.port_storage_daily_rate_egp if policy else 250.0
    storage_days_consumed = max(0, (ref_date - tracking.discharge_date).days)
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
        accrued_storage_egp=tracking.total_storage_egp,
        is_critical_72h_warning=is_critical_72h,
        status=storage_status,
    )

    # Overall Alert
    if storage_status == "OVERDUE_STORAGE" or carrier_status == "OVERDUE_DEMURRAGE":
        overall_alert = "ACTION_REQUIRED"
        summary_ar = f"تنبيه: تراكم غرامات تأخير بقيمة {tracking.total_cost_egp:,.2f} جنيه على البوليصة {tracking.bill_of_lading_no}."
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

def update_single_container_service(
    db: Session,
    tracking_id: int,
    container_no: str,
    req: ContainerIndividualUpdate,
    user: str = "System",
) -> DemurrageTracking:
    tracking = get_demurrage_tracking_by_id_service(db, tracking_id)
    policy = tracking.policy

    dem_free = policy.demurrage_free_days if policy else 14
    det_free = policy.detention_free_days if policy else 7
    storage_free = policy.port_storage_free_days if policy else 5
    storage_rate = policy.port_storage_daily_rate_egp if policy else 250.0
    dem_tiers = policy.demurrage_tiers if policy else DEFAULT_DEMURRAGE_TIERS
    det_tiers = policy.detention_tiers if policy else DEFAULT_DETENTION_TIERS
    rate = tracking.exchange_rate or 50.0

    containers = list(tracking.containers or [])
    found = False
    recalculated_containers = []
    total_dem_fx = 0.0
    total_det_fx = 0.0
    total_stor_egp = 0.0

    for c in containers:
        c_no = c.get("container_no", "")
        if c_no.strip().upper() == container_no.strip().upper():
            found = True
            # Update container-specific fields
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

        # Resolve container dates
        c_gate_out = date.fromisoformat(c["gate_out_date"]) if c.get("gate_out_date") else tracking.gate_out_date
        c_empty_return = date.fromisoformat(c["empty_return_date"]) if c.get("empty_return_date") else tracking.empty_return_date
        c_type = c.get("container_type", "40ft High Cube")

        # Simulate for this specific container
        sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
            carrier_name=tracking.carrier_name,
            container_type=c_type,
            containers_count=1,
            demurrage_free_days=dem_free,
            detention_free_days=det_free,
            port_storage_free_days=storage_free,
            port_storage_daily_rate_egp=storage_rate,
            demurrage_tiers=dem_tiers,
            detention_tiers=det_tiers,
            discharge_date=tracking.discharge_date,
            gate_out_date=c_gate_out,
            empty_return_date=c_empty_return,
            currency=tracking.currency,
            exchange_rate=rate,
        ))

        status_label = req.status if (c_no.strip().upper() == container_no.strip().upper() and req.status) else sim.status_badge
        if c_empty_return:
            status_label = "Empty-Returned"
        elif c_gate_out:
            status_label = "Gated-Out"
        elif sim.demurrage_days_overdue > 0:
            status_label = "Demurrage Incurred"
        else:
            status_label = "On-Port"

        c_data = {
            "container_no": c_no,
            "container_type": c_type,
            "seal_no": c.get("seal_no"),
            "gate_out_date": c.get("gate_out_date"),
            "empty_return_date": c.get("empty_return_date"),
            "eir_number": c.get("eir_number"),
            "demurrage_days": sim.demurrage_days_overdue,
            "detention_days": sim.detention_days_overdue,
            "storage_days": sim.storage_days_overdue,
            "demurrage_fx": sim.demurrage_fee_fx,
            "detention_fx": sim.detention_fee_fx,
            "storage_egp": sim.storage_fee_egp,
            "total_egp": sim.total_cost_egp,
            "status": status_label,
            "notes": c.get("notes"),
        }
        recalculated_containers.append(c_data)
        total_dem_fx += sim.demurrage_fee_fx
        total_det_fx += sim.detention_fee_fx
        total_stor_egp += sim.storage_fee_egp

    if not found:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"الحاوية رقم {container_no} غير موجودة في تتبع البوليصة #{tracking.tracking_code}.",
        )

    total_cost_egp = round(((total_dem_fx + total_det_fx) * rate) + total_stor_egp, 2)
    
    # Check overall tracking status
    all_returned = all(c.get("empty_return_date") for c in recalculated_containers)
    all_gated_out = all(c.get("gate_out_date") for c in recalculated_containers)
    
    if all_returned:
        overall_status = "All Containers Returned"
    elif all_gated_out:
        overall_status = "All Containers Gated Out"
    elif total_dem_fx > 0 or total_det_fx > 0 or total_stor_egp > 0:
        overall_status = "Demurrage & Storage Incurred"
    else:
        overall_status = "Free Time Active"

    tracking.containers = recalculated_containers
    tracking.total_demurrage_fx = round(total_dem_fx, 2)
    tracking.total_detention_fx = round(total_det_fx, 2)
    tracking.total_storage_egp = round(total_stor_egp, 2)
    tracking.total_cost_egp = total_cost_egp
    tracking.status = overall_status
    tracking.updated_by = user

    db.commit()
    db.refresh(tracking)
    return tracking


# =========================================================================
# BK-02: Free Days Agreement Registration & Demurrage Radar Integration
# =========================================================================

def register_free_days_agreement_service(
    db: Session,
    payload: FreeDaysAgreementRegister,
    user: str = "Logistics Officer",
) -> FreeDaysAgreementResponse:
    """
    Central operational engine for BK-02: Free Days Agreement Registration.
    - Synchronizes agreed free days with ImportFile.target_free_days
    - Updates linked ShipmentBooking.free_demurrage_days
    - Recalculates any active DemurrageTracking sessions with newly agreed free days
    - Calculates cost avoidance / savings achieved vs standard 14-day policy
    - Completes pending BK-02 SmartTasks automatically
    - Dispatches high-priority SystemNotification alerting operations
    """
    from modules.import_files.model import ImportFile
    from modules.freight_booking.model import ShipmentBooking
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification

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

    # 1. Update ImportFile
    file_rec.target_free_days = payload.agreed_demurrage_free_days
    if payload.agreement_reference:
        ref_note = f"{FREE_DAYS_NOTE_PREFIX}{payload.agreement_reference} ({payload.agreed_demurrage_free_days}D DEM / {payload.agreed_detention_free_days}D DET)"
        if file_rec.shipping_instructions_notes:
            if ref_note not in file_rec.shipping_instructions_notes:
                file_rec.shipping_instructions_notes += f" | {ref_note}"
        else:
            file_rec.shipping_instructions_notes = ref_note
    db.commit()
    db.refresh(file_rec)

    # 2. Update linked ShipmentBooking
    booking = db.query(ShipmentBooking).filter(
        ShipmentBooking.import_file_id == payload.import_file_id,
        ShipmentBooking.is_active == True,
    ).first()
    if booking:
        booking.free_demurrage_days = payload.agreed_demurrage_free_days
        db.commit()
        db.refresh(booking)

    # 3. Synchronize existing tracking sessions if any
    carrier = payload.carrier_name or (booking.shipping_line_name if booking else None) or "Carrier"
    trackings = db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == payload.import_file_id,
        DemurrageTracking.is_active == True,
    ).all()
    for trk in trackings:
        recalc_containers = []
        total_dem_fx = 0.0
        total_det_fx = 0.0
        total_stor_egp = 0.0
        for c in (trk.containers or []):
            sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
                carrier_name=trk.carrier_name,
                container_type=c.get("container_type", "40ft High Cube"),
                containers_count=1,
                demurrage_free_days=payload.agreed_demurrage_free_days,
                detention_free_days=payload.agreed_detention_free_days,
                port_storage_free_days=payload.port_storage_free_days,
                discharge_date=trk.discharge_date,
                gate_out_date=trk.gate_out_date,
                empty_return_date=trk.empty_return_date,
                currency=trk.currency,
                exchange_rate=trk.exchange_rate,
            ))
            c_data = {
                "container_no": c.get("container_no"),
                "container_type": c.get("container_type"),
                "demurrage_days": sim.demurrage_days_overdue,
                "detention_days": sim.detention_days_overdue,
                "storage_days": sim.storage_days_overdue,
                "demurrage_fx": sim.demurrage_fee_fx,
                "detention_fx": sim.detention_fee_fx,
                "storage_egp": sim.storage_fee_egp,
                "total_egp": sim.total_cost_egp,
                "status": sim.status_badge,
            }
            recalc_containers.append(c_data)
            total_dem_fx += sim.demurrage_fee_fx
            total_det_fx += sim.detention_fee_fx
            total_stor_egp += sim.storage_fee_egp
        trk.containers = recalc_containers
        trk.total_demurrage_fx = round(total_dem_fx, 2)
        trk.total_detention_fx = round(total_det_fx, 2)
        trk.total_storage_egp = round(total_stor_egp, 2)
        trk.total_cost_egp = round(((total_dem_fx + total_det_fx) * trk.exchange_rate) + total_stor_egp, 2)
        db.commit()

    # 4. Calculate cost avoidance
    standard_free_days = 14
    additional_days = max(0, payload.agreed_demurrage_free_days - standard_free_days)
    containers_count = 1
    if booking and booking.containers_data:
        containers_count = sum(c.get("quantity", 1) if isinstance(c, dict) else getattr(c, "quantity", 1) for c in booking.containers_data)
    estimated_cost_avoidance = round(additional_days * 70.0 * containers_count, 2)

    # 5. Complete pending BK-02 smart tasks
    try:
        prior_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == payload.import_file_id,
            SmartTask.status.in_(["Pending", "In Progress"]),
            SmartTask.is_active == True,
        ).all()
        for pt in prior_tasks:
            title_lower = (pt.title or "").lower()
            if "bk-02" in title_lower or "سماح" in title_lower or "free days" in title_lower:
                pt.status = "Completed"
                pt.is_auto_closed = True
        db.commit()
    except Exception as e:
        logger.warning("Failed to auto-complete BK-02 smart tasks: %s", e)

    # 6. Dispatch SystemNotification
    try:
        notif_msg = msg(
            "DD_FREE_DAYS_RECORDED",
            demurrage_free_days=payload.agreed_demurrage_free_days,
            import_file_code=file_code,
            detention_free_days=payload.agreed_detention_free_days,
            agreement_reference=payload.agreement_reference or "N/A",
            estimated_saving_amount=round(float(estimated_cost_avoidance), 2),
        )
        notif = SystemNotification(
            title=render_en(notif_msg.code, notif_msg.params, "title"),
            message=render_en(notif_msg.code, notif_msg.params, "body"),
            msg_code=notif_msg.code,
            msg_params=notif_msg.params,
            severity="INFO",
            category="FREE_DAYS_AGREEMENT_REGISTERED",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="LOGISTICS_OFFICER",
        )
        db.add(notif)
        db.commit()
    except Exception as e:
        logger.warning("Failed to dispatch free days notification: %s", e)

    radar_status = "Safe" if payload.agreed_demurrage_free_days >= 14 else "Warning"

    return FreeDaysAgreementResponse(
        import_file_id=payload.import_file_id,
        import_file_code=file_code,
        carrier_name=carrier,
        booking_code=booking.booking_code if booking else None,
        booking_confirmation_no=booking.booking_confirmation_no if booking else None,
        standard_policy_demurrage_days=standard_free_days,
        agreed_demurrage_free_days=payload.agreed_demurrage_free_days,
        agreed_detention_free_days=payload.agreed_detention_free_days,
        port_storage_free_days=payload.port_storage_free_days,
        additional_free_days_gained=additional_days,
        estimated_cost_avoidance_usd=estimated_cost_avoidance,
        agreement_reference=payload.agreement_reference,
        agreement_date=payload.agreement_date,
        radar_status=radar_status,
        notes=payload.notes,
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

    file_code = file_rec.custom_file_number or file_rec.import_file_code or f"IMP-{file_rec.import_file_id}"
    carrier = (booking.shipping_line_name if booking else None) or "Carrier"
    agreed_dem = file_rec.target_free_days or (booking.free_demurrage_days if booking else 14) or 14
    standard_free_days = 14
    additional_days = max(0, agreed_dem - standard_free_days)
    containers_count = 1
    if booking and booking.containers_data:
        containers_count = sum(c.get("quantity", 1) if isinstance(c, dict) else getattr(c, "quantity", 1) for c in booking.containers_data)
    estimated_cost_avoidance = round(additional_days * 70.0 * containers_count, 2)

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

    return FreeDaysAgreementResponse(
        import_file_id=import_file_id,
        import_file_code=file_code,
        carrier_name=carrier,
        booking_code=booking.booking_code if booking else None,
        booking_confirmation_no=booking.booking_confirmation_no if booking else None,
        standard_policy_demurrage_days=standard_free_days,
        agreed_demurrage_free_days=agreed_dem,
        agreed_detention_free_days=7,
        port_storage_free_days=5,
        additional_free_days_gained=additional_days,
        estimated_cost_avoidance_usd=estimated_cost_avoidance,
        agreement_reference=agreement_reference,
        agreement_date=None,
        radar_status="Safe" if agreed_dem >= 14 else "Warning",
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
      - SAFE (Green #27AE60): > 4 days remaining before penalties begin
      - WARNING (Yellow #E67E22): 1 to 4 days remaining before penalties begin
      - CRITICAL_OVERDUE (Red #C0392B): 0 or negative days remaining, penalty actively accruing
      - RETURNED_SAFE (Grey #7F8C8D): Container already returned safely
    """
    trackings = db.query(DemurrageTracking).filter(
        DemurrageTracking.is_active == True,
        DemurrageTracking.status != "Completed",
    ).all()

    today = date.today()
    radar_items: List[ContainerRadarItem] = []
    safe_count = 0
    warning_count = 0
    critical_count = 0
    returned_count = 0
    total_accrued_demurrage_usd = 0.0
    total_accrued_storage_egp = 0.0
    total_estimated_exposure_egp = 0.0

    for t in trackings:
        policy = t.policy
        dem_free = policy.demurrage_free_days if policy else 14
        storage_free = policy.port_storage_free_days if policy else 5
        exchange_rate = t.exchange_rate or 50.0

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

            c_gate_out_raw = c.get("gate_out_date")
            c_empty_ret_raw = c.get("empty_return_date")
            c_gate_out = date.fromisoformat(c_gate_out_raw.split("T")[0]) if c_gate_out_raw else t.gate_out_date
            c_empty_ret = date.fromisoformat(c_empty_ret_raw.split("T")[0]) if c_empty_ret_raw else t.empty_return_date

            c_ref_gate_out = c_gate_out or today
            c_dem_consumed = max(0, (c_ref_gate_out - t.discharge_date).days)
            c_dem_remaining = max(0, dem_free - c_dem_consumed)

            c_storage_consumed = max(0, (c_ref_gate_out - t.discharge_date).days)
            c_storage_remaining = max(0, storage_free - c_storage_consumed)

            if c_empty_ret:
                radar_status = "RETURNED_SAFE"
                color_code = "#7F8C8D"
                status_label_ar = "تم إرجاع الحاوية فارغة"
                returned_count += 1
                alert_msg = f"تم إرجاع الحاوية {c_no} بسلام للخط الملاحي بدون غرامات جارية."
                item_dem_usd = 0.0
                item_stor_egp = 0.0
                item_tot_egp = 0.0
            elif (not c_gate_out and c_storage_remaining == 0) or c_dem_remaining == 0:
                radar_status = "CRITICAL_OVERDUE"
                color_code = "#C0392B"
                status_label_ar = "حرج - سريان غرامات يومية"
                critical_count += 1

                overdue_dem = max(0, c_dem_consumed - dem_free)
                overdue_stor = max(0, c_storage_consumed - storage_free) if not c_gate_out else 0
                item_dem_usd = overdue_dem * 70.0
                item_stor_egp = overdue_stor * 250.0
                item_tot_egp = (item_dem_usd * exchange_rate) + item_stor_egp

                alert_msg = f"خطر غرامات: تجاوز فترة السماح بـ {max(overdue_dem, overdue_stor)} أيام! مطلوب سرعة التعتيق والإرجاع."
            elif (not c_gate_out and c_storage_remaining <= 2) or c_dem_remaining <= 4:
                radar_status = "WARNING"
                color_code = "#E67E22"
                status_label_ar = "تحذير - اقتراب انتهاء السماح"
                warning_count += 1
                item_dem_usd = 0.0
                item_stor_egp = 0.0
                item_tot_egp = 0.0
                alert_msg = f"تحذير: متبقي {min(c_dem_remaining, c_storage_remaining)} أيام فقط قبل بدء سريان غرامات التأخير والأرضيات."
            else:
                radar_status = "SAFE"
                color_code = "#27AE60"
                status_label_ar = "آمن - داخل فترة السماح"
                safe_count += 1
                item_dem_usd = 0.0
                item_stor_egp = 0.0
                item_tot_egp = 0.0
                alert_msg = f"الحاوية داخل فترة السماح المعتمدة (متبقي {c_dem_remaining} يوماً للخط الملاحي)."

            total_accrued_demurrage_usd += item_dem_usd
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
                    accrued_demurrage_usd=item_dem_usd,
                    accrued_storage_egp=item_stor_egp,
                    total_accrued_egp=item_tot_egp,
                    alert_message_ar=alert_msg,
                )
            )

    return ContainerRadarOverviewResponse(
        total_containers_tracked=len(radar_items),
        safe_containers_count=safe_count,
        warning_containers_count=warning_count,
        critical_overdue_count=critical_count,
        returned_containers_count=returned_count,
        total_accrued_demurrage_usd=round(total_accrued_demurrage_usd, 2),
        total_accrued_storage_egp=round(total_accrued_storage_egp, 2),
        total_estimated_exposure_egp=round(total_estimated_exposure_egp, 2),
        radar_items=radar_items,
        generated_at=datetime.now(timezone.utc),
    )


# =========================================================================
# TR-05: Empty Container Return (EIR) & Demurrage Radar De-escalation
# =========================================================================

def record_empty_container_return_service(
    db: Session,
    payload: EmptyContainerReturnSubmit,
    user: str = "Logistics Coordinator",
) -> EmptyContainerReturnResponse:
    """
    Central operational engine for TR-05: Empty Container Return (EIR).
    - Records EIR number and empty container return date.
    - Halts detention penalties permanently for returned containers.
    - Recalculates final accrued demurrage/detention and locks them.
    - Transitions container radar status to 'RETURNED_SAFE' (grey).
    - Synchronizes ImportFile with EIR receipt data, updates inland transport status to COMPLETED.
    - Advances shipment to Phase 9 (Financial Settlement & Landed Cost Closure) with progress >= 98.0%.
    - Synchronizes LifecycleBoard from STEP_19 to STEP_20.
    - Closes pending TR-05 SmartTasks automatically.
    - Dispatches downstream TSK-0901 SmartTask (CLO-01 Final Settlement) to Finance Specialist.
    - Emits system-wide notification.
    """
    # A depot picked from the popular list is stored as its code; free text stays as typed.
    payload = payload.model_copy(
        update={"depot_name": enum_codes.normalize(enum_codes.EMPTY_CONTAINER_DEPOT, payload.depot_name)}
    )
    from modules.import_files.model import ImportFile
    from modules.inland_transport.model import InlandTransportBooking
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification

    # 1. Validate Import File
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == payload.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الاستيراد برقم #{payload.import_file_id} غير موجود أو تم حذفه.",
        )

    # 2. Locate active DemurrageTracking session for this import file
    tracking = db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == payload.import_file_id,
        DemurrageTracking.is_active == True,
    ).first()

    returned_container_numbers = []
    total_containers_count = 0
    all_returned = True
    final_dem_fx = 0.0
    final_det_fx = 0.0
    final_stor_egp = 0.0
    final_total_egp = 0.0
    tracking_status = "All Containers Returned"

    if tracking:
        policy = tracking.policy
        dem_free = policy.demurrage_free_days if policy else 14
        det_free = policy.detention_free_days if policy else 7
        storage_free = policy.port_storage_free_days if policy else 5
        storage_rate = policy.port_storage_daily_rate_egp if policy else 250.0
        dem_tiers = policy.demurrage_tiers if policy else DEFAULT_DEMURRAGE_TIERS
        det_tiers = policy.detention_tiers if policy else DEFAULT_DETENTION_TIERS
        rate = tracking.exchange_rate or 50.0

        containers = list(tracking.containers or [])
        total_containers_count = len(containers)
        recalculated_containers = []

        # Determine target container numbers
        target_c_nos = [c.strip().upper() for c in payload.returned_containers] if payload.returned_containers else None

        for c in containers:
            c_no = c.get("container_no", "").strip().upper()
            is_target = (target_c_nos is None) or (c_no in target_c_nos)

            if is_target:
                c["empty_return_date"] = payload.empty_return_date.isoformat()
                c["eir_number"] = payload.eir_number
                c["condition"] = payload.container_condition
                if payload.damage_notes:
                    c["damage_notes"] = payload.damage_notes
                if payload.damage_fee_estimated:
                    c["damage_fee"] = payload.damage_fee_estimated
                if payload.depot_name:
                    c["depot_name"] = payload.depot_name
                returned_container_numbers.append(c_no)

            c_gate_out = date.fromisoformat(c["gate_out_date"]) if c.get("gate_out_date") else tracking.gate_out_date
            c_empty_ret = date.fromisoformat(c["empty_return_date"]) if c.get("empty_return_date") else (payload.empty_return_date if is_target else tracking.empty_return_date)
            c_type = c.get("container_type", "40ft High Cube")

            # Simulate exact final charges up to return date
            sim = simulate_demurrage_and_detention(DemurrageSimulationRequest(
                carrier_name=tracking.carrier_name,
                container_type=c_type,
                containers_count=1,
                demurrage_free_days=dem_free,
                detention_free_days=det_free,
                port_storage_free_days=storage_free,
                port_storage_daily_rate_egp=storage_rate,
                demurrage_tiers=dem_tiers,
                detention_tiers=det_tiers,
                discharge_date=tracking.discharge_date,
                gate_out_date=c_gate_out,
                empty_return_date=c_empty_ret,
                currency=tracking.currency,
                exchange_rate=rate,
            ))

            c_status = "Empty-Returned" if c_empty_ret else ("Gated-Out" if c_gate_out else "On-Port")
            if not c_empty_ret:
                all_returned = False

            c_data = {
                "container_no": c_no,
                "container_type": c_type,
                "seal_no": c.get("seal_no"),
                "gate_out_date": c.get("gate_out_date"),
                "empty_return_date": c.get("empty_return_date"),
                "eir_number": c.get("eir_number"),
                "condition": c.get("condition", "SOUND_CLEAN"),
                "damage_notes": c.get("damage_notes"),
                "damage_fee": c.get("damage_fee", 0.0),
                "depot_name": c.get("depot_name"),
                "demurrage_days": sim.demurrage_days_overdue,
                "detention_days": sim.detention_days_overdue,
                "storage_days": sim.storage_days_overdue,
                "demurrage_fx": sim.demurrage_fee_fx,
                "detention_fx": sim.detention_fee_fx,
                "storage_egp": sim.storage_fee_egp,
                "total_egp": sim.total_cost_egp,
                "status": c_status,
                "notes": c.get("notes"),
            }
            recalculated_containers.append(c_data)
            final_dem_fx += sim.demurrage_fee_fx
            final_det_fx += sim.detention_fee_fx
            final_stor_egp += sim.storage_fee_egp

        final_total_egp = round(((final_dem_fx + final_det_fx) * rate) + final_stor_egp, 2)
        tracking.containers = recalculated_containers
        tracking.total_demurrage_fx = round(final_dem_fx, 2)
        tracking.total_detention_fx = round(final_det_fx, 2)
        tracking.total_storage_egp = round(final_stor_egp, 2)
        tracking.total_cost_egp = final_total_egp
        tracking.empty_return_date = payload.empty_return_date
        tracking.status = "All Containers Returned" if all_returned else "Partially Returned"
        tracking_status = tracking.status
        tracking.updated_by = user
    else:
        returned_container_numbers = payload.returned_containers or ["CONTAINER-01"]
        total_containers_count = len(returned_container_numbers)
        all_returned = True
        tracking_status = "All Containers Returned"

    # 3. Update Inland Transport Booking if active
    transport_bookings = db.query(InlandTransportBooking).filter(
        InlandTransportBooking.import_file_id == payload.import_file_id,
        InlandTransportBooking.is_active == True,
    ).all()
    for tb in transport_bookings:
        tb.status = "Completed"
        tb.tracking_notes = f"{tb.tracking_notes or ''}\n[TR-05] Empty containers returned to the carrier under EIR #{payload.eir_number}".strip()

    # 4. Synchronize Import File
    return_status_code = "ALL_RETURNED" if all_returned else "PARTIALLY_RETURNED"
    imp_file.empty_containers_returned_at = datetime.now(timezone.utc)
    imp_file.empty_containers_return_status = return_status_code
    imp_file.empty_containers_eir_numbers = payload.eir_number
    imp_file.empty_containers_depot_name = payload.depot_name or "Carrier Depot"
    imp_file.inland_transport_status = "COMPLETED"

    if all_returned:
        imp_file.progress_percent = max(float(imp_file.progress_percent or 0.0), 98.0)
        set_file_tracking(imp_file, step_code="STEP_20", next_action=msg("NA_CLO_SETTLE_FINAL_INVOICES"))

    # 5. Synchronize LifecycleBoard
    try:
        from modules.lifecycle_board.service import transition_stage_service
        transition_stage_service(
            db=db,
            import_file_id=payload.import_file_id,
            to_step="STEP_20_SETTLEMENT",
            user=user,
            notes=render_en("DD_EMPTY_CONTAINERS_RETURNED", {"eir_number": payload.eir_number}, "note"),
        )
    except Exception as e:
        logger.warning(f"LifecycleBoard transition skipped or already aligned: {e}")
    if all_returned:
        # Re-apply after the board transition, which writes its own generic next action.
        set_file_tracking(imp_file, step_code="STEP_20", next_action=msg("NA_CLO_SETTLE_FINAL_INVOICES"))

    # 6. Auto-close pending TR-05 SmartTasks
    try:
        pending_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == payload.import_file_id,
            SmartTask.status.in_(["Pending", "In Progress"]),
        ).all()
        for tsk in pending_tasks:
            title_lower = (tsk.title or "").lower()
            code_lower = (tsk.task_code or "").lower()
            if "tr-05" in title_lower or "tr-05" in code_lower or "eir" in title_lower or "إرجاع" in title_lower or "حاويات" in title_lower:
                tsk.status = "Completed"
                tsk.is_auto_closed = True
                tsk.notes = f"{tsk.notes or ''}\n[TR-05] Auto-closed on EIR #{payload.eir_number}".strip()
    except Exception as e:
        logger.warning(f"SmartTasks auto-closure skipped: {e}")

    # 7. Auto-generate downstream SmartTask for Phase 9 (CLO-01 Final Settlement)
    try:
        task_msg = msg("DD_TASK_SETTLE_FINAL_INVOICES", eir_number=payload.eir_number)
        clo01_task = SmartTask(
            task_code=f"TSK-0901-{payload.import_file_id}",
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
        )
        db.add(clo01_task)
    except Exception as e:
        logger.warning(f"Downstream SmartTask creation skipped: {e}")

    # 8. Dispatch Central SystemNotification
    try:
        notif_msg = msg(
            "DD_EMPTY_CONTAINERS_RETURNED",
            import_file_code=imp_file.import_file_code,
            container_count=len(returned_container_numbers),
            eir_number=payload.eir_number,
            depot_enum_empty_container_depot=payload.depot_name or "Carrier Depot",
        )
        notif = SystemNotification(
            title=render_en(notif_msg.code, notif_msg.params, "title"),
            message=render_en(notif_msg.code, notif_msg.params, "body"),
            msg_code=notif_msg.code,
            msg_params=notif_msg.params,
            category="STAGE_PROGRESSION",
            severity="SUCCESS",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="ALL",
        )
        db.add(notif)
    except Exception as e:
        logger.warning(f"SystemNotification dispatch skipped: {e}")

    db.commit()

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
        message_ar=f"تم توثيق إرجاع الحاويات بنجاح بموجب إيصال EIR #{payload.eir_number} وإيقاف عدادات الغرامات بالكامل.",
        returned_at=datetime.now(timezone.utc),
    )


