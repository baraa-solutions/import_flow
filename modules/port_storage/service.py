from datetime import date, datetime, timezone
from typing import List, Optional, Tuple, Dict, Any, Union
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from .model import PortTerminalRate, PortStorageAccrual
from .schemas import (
    PortStorageBreakdown,
    TierDetail,
    PortTerminalRateCreate,
    PortTerminalRateUpdate,
    PortStorageAccrualCreate,
    PortStorageAccrualUpdate,
    PortStorageAccrualStatusUpdate,
    PortStorageSummaryResponse,
)
from .repository import PortStorageRepository
from .validators import (
    TERMINAL_NAMES,
    normalize_terminal_code,
    normalize_container_size,
    parse_date,
    validate_storage_dates,
    validate_accrual_status,
)


DEFAULT_TERMINAL_RATES: Dict[str, Dict[str, Dict[str, Any]]] = {
    "ACCHCO": {
        "20ft": {
            "tier1_rate": 120.0,
            "tier2_rate": 240.0,
            "penal_rate": 480.0,
            "reefer_plugging": 500.0,
            "xray_fee": 350.0,
            "scale_fee": 150.0,
        },
        "40ft": {
            "tier1_rate": 240.0,
            "tier2_rate": 480.0,
            "penal_rate": 960.0,
            "reefer_plugging": 800.0,
            "xray_fee": 500.0,
            "scale_fee": 200.0,
        },
    },
    "DP_WORLD_SOKHNA": {
        "20ft": {
            "tier1_rate": 150.0,
            "tier2_rate": 300.0,
            "penal_rate": 600.0,
            "reefer_plugging": 600.0,
            "xray_fee": 400.0,
            "scale_fee": 200.0,
        },
        "40ft": {
            "tier1_rate": 300.0,
            "tier2_rate": 600.0,
            "penal_rate": 1200.0,
            "reefer_plugging": 900.0,
            "xray_fee": 600.0,
            "scale_fee": 250.0,
        },
    },
    "DCHC": {
        "20ft": {
            "tier1_rate": 110.0,
            "tier2_rate": 220.0,
            "penal_rate": 450.0,
            "reefer_plugging": 450.0,
            "xray_fee": 350.0,
            "scale_fee": 150.0,
        },
        "40ft": {
            "tier1_rate": 220.0,
            "tier2_rate": 440.0,
            "penal_rate": 900.0,
            "reefer_plugging": 750.0,
            "xray_fee": 500.0,
            "scale_fee": 200.0,
        },
    },
    "SCCT": {
        "20ft": {
            "tier1_rate": 140.0,
            "tier2_rate": 280.0,
            "penal_rate": 550.0,
            "reefer_plugging": 550.0,
            "xray_fee": 400.0,
            "scale_fee": 180.0,
        },
        "40ft": {
            "tier1_rate": 280.0,
            "tier2_rate": 560.0,
            "penal_rate": 1100.0,
            "reefer_plugging": 850.0,
            "xray_fee": 550.0,
            "scale_fee": 220.0,
        },
    },
}


def calculate_terminal_storage(
    terminal_code: str,
    container_size: str,
    is_reefer: bool,
    gate_in: Union[date, datetime, str],
    current_or_gate_out: Union[date, datetime, str],
    db: Optional[Session] = None,
    include_xray: bool = True,
    include_scale: bool = True,
) -> PortStorageBreakdown:
    """
    Core Terminal Storage & Accrual Calculation Engine
    Computes storage charges across statutory tiers per Egyptian Port Tariffs:
      - Days 1-3: Free days (0 EGP)
      - Days 4-8: Tier 1 (5 days max)
      - Days 9-15: Tier 2 (7 days max)
      - Days 16+: Penal Tier
    Also adds reefer daily electricity/plugging fees, and fixed terminal inspection/scale fees.
    """
    norm_terminal = normalize_terminal_code(terminal_code)
    norm_size = normalize_container_size(container_size)
    
    start_date = parse_date(gate_in)
    end_date = parse_date(current_or_gate_out)
    if not start_date or not end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Valid gate_in_date and current_or_gate_out_date are required.",
        )
    validate_storage_dates(start_date, end_date)

    # In Egyptian port storage, elapsed days are counted inclusively: arrival day is Day 1
    total_days = (end_date - start_date).days + 1
    if total_days < 1:
        total_days = 1

    # Lookup rate card from DB if session provided, else use defaults
    rate_card: Optional[PortTerminalRate] = None
    if db is not None:
        rate_card = PortStorageRepository.find_terminal_rate(
            db=db,
            terminal_code=norm_terminal,
            container_size=norm_size,
            is_reefer=is_reefer,
            effective_date=end_date,
        )

    # Extract rates
    free_days_allowed = rate_card.free_days if rate_card else 3
    if rate_card:
        tier1_rate = rate_card.tier1_rate_per_day
        tier2_rate = rate_card.tier2_rate_per_day
        penal_rate = rate_card.penal_rate_per_day
        reefer_plug_fee = rate_card.reefer_plugging_daily_fee
        xray_fee = rate_card.xray_scan_fee
        scale_fee = rate_card.scale_fee
    else:
        fallback = DEFAULT_TERMINAL_RATES.get(norm_terminal, DEFAULT_TERMINAL_RATES["ACCHCO"])
        size_rates = fallback.get(norm_size, fallback["20ft"])
        tier1_rate = size_rates["tier1_rate"]
        tier2_rate = size_rates["tier2_rate"]
        penal_rate = size_rates["penal_rate"]
        reefer_plug_fee = size_rates["reefer_plugging"] if is_reefer else 0.0
        xray_fee = size_rates["xray_fee"]
        scale_fee = size_rates["scale_fee"]

    # Calculate Tier Distribution:
    # Days 1 to 3: Free
    # Days 4 to 8: Tier 1 (up to 5 days)
    # Days 9 to 15: Tier 2 (up to 7 days)
    # Days 16+: Penal Tier
    chargeable_days = max(0, total_days - free_days_allowed)
    tier1_days = min(max(0, total_days - 3), 5)
    tier2_days = min(max(0, total_days - 8), 7)
    penal_days = max(0, total_days - 15)

    tier1_amount = round(tier1_days * tier1_rate, 2)
    tier2_amount = round(tier2_days * tier2_rate, 2)
    penal_amount = round(penal_days * penal_rate, 2)
    storage_charges = round(tier1_amount + tier2_amount + penal_amount, 2)

    reefer_plugging_charges = round(total_days * reefer_plug_fee, 2) if is_reefer else 0.0
    xray_charge = round(xray_fee, 2) if include_xray else 0.0
    scale_charge = round(scale_fee, 2) if include_scale else 0.0
    total_port_storage = round(storage_charges + reefer_plugging_charges + xray_charge + scale_charge, 2)

    tier_details = [
        TierDetail(tier_name="Free Days (1-3)", days=min(total_days, free_days_allowed), rate_per_day=0.0, total_amount=0.0),
        TierDetail(tier_name="Tier 1 (Days 4-8)", days=tier1_days, rate_per_day=tier1_rate, total_amount=tier1_amount),
        TierDetail(tier_name="Tier 2 (Days 9-15)", days=tier2_days, rate_per_day=tier2_rate, total_amount=tier2_amount),
        TierDetail(tier_name="Penal Tier (Days 16+)", days=penal_days, rate_per_day=penal_rate, total_amount=penal_amount),
    ]

    return PortStorageBreakdown(
        terminal_code=norm_terminal,
        terminal_name=TERMINAL_NAMES.get(norm_terminal, norm_terminal),
        container_size=norm_size,
        is_reefer=is_reefer,
        gate_in_date=start_date,
        end_date=end_date,
        total_days=total_days,
        free_days_allowed=free_days_allowed,
        chargeable_days=chargeable_days,
        tier1_days=tier1_days,
        tier1_rate=tier1_rate,
        tier1_amount=tier1_amount,
        tier2_days=tier2_days,
        tier2_rate=tier2_rate,
        tier2_amount=tier2_amount,
        penal_days=penal_days,
        penal_rate=penal_rate,
        penal_amount=penal_amount,
        storage_charges_egp=storage_charges,
        reefer_plugging_charges_egp=reefer_plugging_charges,
        xray_scan_fee_egp=xray_charge,
        scale_fee_egp=scale_charge,
        total_port_storage_egp=total_port_storage,
        currency="EGP",
        tier_details=tier_details,
    )


# --- Rate Management Services ---

def create_terminal_rate_service(db: Session, payload: PortTerminalRateCreate, user: str = "System") -> PortTerminalRate:
    norm_terminal = normalize_terminal_code(payload.terminal_code)
    norm_size = normalize_container_size(payload.container_size)
    
    rate_obj = PortTerminalRate(
        terminal_code=norm_terminal,
        terminal_name=payload.terminal_name or TERMINAL_NAMES.get(norm_terminal, norm_terminal),
        container_size=norm_size,
        is_reefer=payload.is_reefer,
        free_days=payload.free_days,
        tier1_rate_per_day=payload.tier1_rate_per_day,
        tier2_rate_per_day=payload.tier2_rate_per_day,
        penal_rate_per_day=payload.penal_rate_per_day,
        reefer_plugging_daily_fee=payload.reefer_plugging_daily_fee,
        xray_scan_fee=payload.xray_scan_fee,
        scale_fee=payload.scale_fee,
        currency=payload.currency or "EGP",
        effective_date=payload.effective_date or date.today(),
        notes=payload.notes,
        is_active=payload.is_active,
        created_by=user,
        updated_by=user,
    )
    return PortStorageRepository.create_terminal_rate(db, rate_obj)


def list_terminal_rates_service(
    db: Session,
    terminal_code: Optional[str] = None,
    container_size: Optional[str] = None,
    is_reefer: Optional[bool] = None,
    is_active: bool = True,
    skip: int = 0,
    limit: int = 100,
) -> Tuple[List[PortTerminalRate], int]:
    if terminal_code:
        terminal_code = normalize_terminal_code(terminal_code)
    if container_size:
        container_size = normalize_container_size(container_size)
    return PortStorageRepository.list_terminal_rates(
        db, terminal_code=terminal_code, container_size=container_size, is_reefer=is_reefer, is_active=is_active, skip=skip, limit=limit
    )


def get_terminal_rate_by_id_service(db: Session, rate_id: int) -> PortTerminalRate:
    rate = PortStorageRepository.get_terminal_rate(db, rate_id)
    if not rate:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Terminal rate not found.")
    return rate


def update_terminal_rate_service(db: Session, rate_id: int, payload: PortTerminalRateUpdate, user: str = "System") -> PortTerminalRate:
    updates = payload.model_dump(exclude_unset=True)
    updates["updated_by"] = user
    rate = PortStorageRepository.update_terminal_rate(db, rate_id, updates)
    if not rate:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Terminal rate not found.")
    return rate


def delete_terminal_rate_service(db: Session, rate_id: int, user: str = "System") -> bool:
    success = PortStorageRepository.delete_terminal_rate(db, rate_id, user)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Terminal rate not found.")
    return True


# --- Accrual Services ---

def create_storage_accrual_service(db: Session, payload: PortStorageAccrualCreate, user: str = "System") -> PortStorageAccrual:
    norm_terminal = normalize_terminal_code(payload.terminal_code)
    norm_size = normalize_container_size(payload.container_size_type)
    
    # Calculate end date: gate_out if present, else customs_release if present, else today
    end_date = payload.gate_out_date or payload.customs_release_date or date.today()
    
    # If auto-calculate requested, run the calculation engine
    if payload.auto_calculate:
        calc = calculate_terminal_storage(
            terminal_code=norm_terminal,
            container_size=norm_size,
            is_reefer=payload.is_reefer,
            gate_in=payload.gate_in_date,
            current_or_gate_out=end_date,
            db=db,
        )
        free_days = calc.free_days_allowed
        chargeable_days = calc.chargeable_days
        storage_charges = calc.storage_charges_egp
        reefer_charges = calc.reefer_plugging_charges_egp
        xray_fee = calc.xray_scan_fee_egp
        scale_fee = calc.scale_fee_egp
        total_egp = calc.total_port_storage_egp
    else:
        free_days = payload.free_days_allowed if payload.free_days_allowed is not None else 3
        chargeable_days = payload.chargeable_days or 0
        storage_charges = payload.storage_charges_egp or 0.0
        reefer_charges = payload.reefer_plugging_charges_egp or 0.0
        xray_fee = payload.xray_scan_fee_egp or 0.0
        scale_fee = payload.scale_fee_egp or 0.0
        total_egp = payload.total_port_storage_egp or (storage_charges + reefer_charges + xray_fee + scale_fee)

    accrual_status = validate_accrual_status(payload.status or "ESTIMATED")

    accrual_obj = PortStorageAccrual(
        import_file_id=payload.import_file_id,
        terminal_code=norm_terminal,
        container_number=payload.container_number.strip().upper(),
        container_size_type=norm_size,
        is_reefer=payload.is_reefer,
        gate_in_date=payload.gate_in_date,
        customs_release_date=payload.customs_release_date,
        gate_out_date=payload.gate_out_date,
        free_days_allowed=free_days,
        chargeable_days=chargeable_days,
        storage_charges_egp=storage_charges,
        reefer_plugging_charges_egp=reefer_charges,
        xray_scan_fee_egp=xray_fee,
        scale_fee_egp=scale_fee,
        total_port_storage_egp=total_egp,
        status=accrual_status,
        notes=payload.notes,
        created_by=user,
        updated_by=user,
    )
    return PortStorageRepository.create_storage_accrual(db, accrual_obj)


def list_storage_accruals_service(
    db: Session,
    import_file_id: Optional[int] = None,
    terminal_code: Optional[str] = None,
    container_number: Optional[str] = None,
    status: Optional[str] = None,
    is_active: bool = True,
    skip: int = 0,
    limit: int = 100,
) -> Tuple[List[PortStorageAccrual], int]:
    if terminal_code:
        terminal_code = normalize_terminal_code(terminal_code)
    if status:
        status = validate_accrual_status(status)
    return PortStorageRepository.list_storage_accruals(
        db,
        import_file_id=import_file_id,
        terminal_code=terminal_code,
        container_number=container_number,
        status=status,
        is_active=is_active,
        skip=skip,
        limit=limit,
    )


def get_storage_accrual_by_id_service(db: Session, accrual_id: int) -> PortStorageAccrual:
    accrual = PortStorageRepository.get_storage_accrual(db, accrual_id)
    if not accrual:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Storage accrual record not found.")
    return accrual


def update_storage_accrual_service(
    db: Session,
    accrual_id: int,
    payload: PortStorageAccrualUpdate,
    user: str = "System",
) -> PortStorageAccrual:
    updates = payload.model_dump(exclude_unset=True)
    if "status" in updates and updates["status"]:
        updates["status"] = validate_accrual_status(updates["status"])
    if "terminal_code" in updates and updates["terminal_code"]:
        updates["terminal_code"] = normalize_terminal_code(updates["terminal_code"])
    if "container_size_type" in updates and updates["container_size_type"]:
        updates["container_size_type"] = normalize_container_size(updates["container_size_type"])
        
    updates["updated_by"] = user
    accrual = PortStorageRepository.update_storage_accrual(db, accrual_id, updates)
    if not accrual:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Storage accrual record not found.")
    return accrual


def update_storage_accrual_status_service(
    db: Session,
    accrual_id: int,
    payload: PortStorageAccrualStatusUpdate,
    user: str = "System",
) -> PortStorageAccrual:
    validated_status = validate_accrual_status(payload.status)
    updates = {
        "status": validated_status,
        "invoice_number": payload.invoice_number,
        "invoice_date": payload.invoice_date,
        "paid_amount_egp": payload.paid_amount_egp,
        "payment_reference": payload.payment_reference,
        "notes": payload.notes,
        "updated_by": user,
    }
    accrual = PortStorageRepository.update_storage_accrual(db, accrual_id, updates)
    if not accrual:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Storage accrual record not found.")
    return accrual


def delete_storage_accrual_service(db: Session, accrual_id: int, user: str = "System") -> bool:
    success = PortStorageRepository.delete_storage_accrual(db, accrual_id, user)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Storage accrual record not found.")
    return True


def get_port_storage_summary_service(db: Session, import_file_id: Optional[int] = None) -> PortStorageSummaryResponse:
    summary = PortStorageRepository.get_summary(db, import_file_id)
    return PortStorageSummaryResponse(**summary)
