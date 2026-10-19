from datetime import datetime, timezone, date
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import func
from .model import (
    DemurragePolicy,
    DemurrageTracking,
    Terminal,
    TerminalStorageRate,
    Carrier,
    CarrierDemurrageRate,
)
from modules.common.sequence_generator import next_yearly_code


def get_policy_by_id(db: Session, policy_id: int) -> Optional[DemurragePolicy]:
    return db.query(DemurragePolicy).filter(
        DemurragePolicy.policy_id == policy_id,
        DemurragePolicy.is_active == True,
    ).first()


def get_policy_for_carrier_container(
    db: Session, carrier_name: str, container_type: str
) -> Optional[DemurragePolicy]:
    return db.query(DemurragePolicy).filter(
        func.lower(DemurragePolicy.carrier_name) == carrier_name.strip().lower(),
        func.lower(DemurragePolicy.container_type) == container_type.strip().lower(),
        DemurragePolicy.is_active == True,
    ).first()


def get_policies(
    db: Session,
    carrier_name: Optional[str] = None,
    container_type: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[DemurragePolicy], int]:
    q = db.query(DemurragePolicy).filter(DemurragePolicy.is_active == True)
    if carrier_name:
        q = q.filter(DemurragePolicy.carrier_name.ilike(f"%{carrier_name}%"))
    if container_type:
        q = q.filter(DemurragePolicy.container_type.ilike(f"%{container_type}%"))
    total = q.count()
    items = q.offset(skip).limit(limit).all()
    return items, total


def create_policy(db: Session, data: dict, user: str = "System") -> DemurragePolicy:
    """Adds and flushes (the service commits)."""
    policy = DemurragePolicy(**data)
    policy.created_by = user
    policy.updated_by = user
    db.add(policy)
    db.flush()
    return policy


def update_policy(db: Session, policy: DemurragePolicy, data: dict, user: str = "System") -> DemurragePolicy:
    for key, val in data.items():
        if val is not None:
            setattr(policy, key, val)
    policy.updated_by = user
    policy.updated_at = datetime.now(timezone.utc)
    return policy


def delete_policy(db: Session, policy: DemurragePolicy, user: str = "System") -> DemurragePolicy:
    policy.is_active = False
    policy.updated_by = user
    policy.updated_at = datetime.now(timezone.utc)
    return policy


def generate_tracking_code(db: Session) -> str:
    """Next ``DND-YYYY-NNNN`` of the current year (the unique constraint stays the final guard)."""
    return next_yearly_code(db, DemurrageTracking.tracking_code, "DND", pad=4)


def get_tracking_by_id(db: Session, tracking_id: int) -> Optional[DemurrageTracking]:
    return db.query(DemurrageTracking).filter(
        DemurrageTracking.tracking_id == tracking_id,
        DemurrageTracking.is_active == True,
    ).first()


def get_tracking_by_code(db: Session, tracking_code: str) -> Optional[DemurrageTracking]:
    return db.query(DemurrageTracking).filter(
        DemurrageTracking.tracking_code == tracking_code.strip(),
        DemurrageTracking.is_active == True,
    ).first()


def get_active_tracking_for_file(db: Session, import_file_id: int) -> Optional[DemurrageTracking]:
    """Returns the single active demurrage tracking session for an import file."""
    return db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == import_file_id,
        DemurrageTracking.is_active == True,
    ).first()


def get_active_tracking_for_bl(db: Session, bill_of_lading_no: str) -> Optional[DemurrageTracking]:
    """Returns the single active demurrage tracking session for a Bill of Lading."""
    if not bill_of_lading_no:
        return None
    return db.query(DemurrageTracking).filter(
        DemurrageTracking.bill_of_lading_no == bill_of_lading_no.strip(),
        DemurrageTracking.is_active == True,
    ).first()


def get_trackings(
    db: Session,
    import_file_id: Optional[int] = None,
    carrier_name: Optional[str] = None,
    status_filter: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[DemurrageTracking], int]:
    q = db.query(DemurrageTracking).filter(DemurrageTracking.is_active == True)
    if import_file_id:
        q = q.filter(DemurrageTracking.import_file_id == import_file_id)
    if carrier_name:
        q = q.filter(DemurrageTracking.carrier_name.ilike(f"%{carrier_name}%"))
    if status_filter:
        q = q.filter(DemurrageTracking.status == status_filter)
    total = q.count()
    items = q.order_by(DemurrageTracking.tracking_id.desc()).offset(skip).limit(limit).all()
    return items, total


def add_tracking(db: Session, tracking: DemurrageTracking, user: str = "System") -> DemurrageTracking:
    """Assigns the next code when missing, adds and flushes (the service commits)."""
    if not tracking.tracking_code:
        tracking.tracking_code = generate_tracking_code(db)
    tracking.created_by = user
    tracking.updated_by = user
    db.add(tracking)
    db.flush()
    return tracking


def create_tracking(db: Session, data: dict, user: str = "System") -> DemurrageTracking:
    """Legacy helper: builds and flushes a tracking from a dict (the caller commits)."""
    return add_tracking(db, DemurrageTracking(**data), user=user)


def delete_tracking(db: Session, tracking: DemurrageTracking, user: str = "System") -> DemurrageTracking:
    tracking.is_active = False
    tracking.updated_by = user
    tracking.updated_at = datetime.now(timezone.utc)
    return tracking


# ----------------------------------------------------
# Terminal & Terminal Storage Rates Repository
# ----------------------------------------------------

def get_terminal_by_id(db: Session, terminal_id: int) -> Optional[Terminal]:
    return db.query(Terminal).filter(Terminal.terminal_id == terminal_id, Terminal.is_active == True).first()


def get_terminal_by_code(db: Session, terminal_code: str) -> Optional[Terminal]:
    return db.query(Terminal).filter(func.lower(Terminal.terminal_code) == terminal_code.strip().lower(), Terminal.is_active == True).first()


def find_terminal_for_port(db: Session, port_name: str) -> Optional[Terminal]:
    """Finds the primary terminal for a port name (e.g. Alexandria -> AICTC-ALEX, Dekheila -> AICTC-DKH)."""
    if not port_name:
        return None
    p = port_name.strip().lower()
    # Try exact match or contains
    return db.query(Terminal).filter(
        func.lower(Terminal.port_name) == p,
        Terminal.is_active == True,
    ).order_by(Terminal.terminal_id.asc()).first() or db.query(Terminal).filter(
        func.lower(Terminal.terminal_code).ilike(f"%{p}%"),
        Terminal.is_active == True,
    ).order_by(Terminal.terminal_id.asc()).first()


def get_terminals(
    db: Session,
    port_name: Optional[str] = None,
    is_active: Optional[bool] = True,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[Terminal], int]:
    q = db.query(Terminal)
    if is_active is not None:
        q = q.filter(Terminal.is_active == is_active)
    if port_name:
        q = q.filter(Terminal.port_name.ilike(f"%{port_name}%"))
    total = q.count()
    items = q.order_by(Terminal.terminal_id.asc()).offset(skip).limit(limit).all()
    return items, total


def create_terminal(db: Session, data: dict, user: str = "System") -> Terminal:
    terminal = Terminal(**data)
    terminal.created_by = user
    terminal.updated_by = user
    db.add(terminal)
    db.flush()
    return terminal


def get_effective_storage_rate(
    db: Session,
    terminal_id: int,
    container_type: str,
    target_date: Optional[date] = None,
) -> Optional[TerminalStorageRate]:
    ref_date = target_date or date.today()
    # Normalize 40ft High Cube to 40ft DRY if not explicitly defined
    rate = (
        db.query(TerminalStorageRate)
        .filter(
            TerminalStorageRate.terminal_id == terminal_id,
            func.lower(TerminalStorageRate.container_type) == container_type.strip().lower(),
            TerminalStorageRate.effective_date <= ref_date,
            TerminalStorageRate.is_active == True,
        )
        .order_by(TerminalStorageRate.effective_date.desc(), TerminalStorageRate.rate_id.desc())
        .first()
    )
    if not rate and "40" in container_type:
        rate = (
            db.query(TerminalStorageRate)
            .filter(
                TerminalStorageRate.terminal_id == terminal_id,
                TerminalStorageRate.container_type.ilike("%40%"),
                TerminalStorageRate.effective_date <= ref_date,
                TerminalStorageRate.is_active == True,
            )
            .order_by(TerminalStorageRate.effective_date.desc(), TerminalStorageRate.rate_id.desc())
            .first()
        )
    return rate


def get_storage_rates_history(
    db: Session,
    terminal_id: Optional[int] = None,
    container_type: Optional[str] = None,
) -> List[TerminalStorageRate]:
    q = db.query(TerminalStorageRate).filter(TerminalStorageRate.is_active == True)
    if terminal_id is not None:
        q = q.filter(TerminalStorageRate.terminal_id == terminal_id)
    if container_type:
        q = q.filter(func.lower(TerminalStorageRate.container_type) == container_type.strip().lower())
    return q.order_by(TerminalStorageRate.effective_date.desc()).all()


def add_terminal_storage_rate(db: Session, data: dict, user: str = "System") -> TerminalStorageRate:
    rate = TerminalStorageRate(**data)
    rate.created_by = user
    db.add(rate)
    db.flush()
    return rate


# ----------------------------------------------------
# Carrier & Carrier Demurrage Rates Repository
# ----------------------------------------------------

def get_carrier_by_id(db: Session, carrier_id: int) -> Optional[Carrier]:
    return db.query(Carrier).filter(Carrier.carrier_id == carrier_id, Carrier.is_active == True).first()


def get_carrier_by_code(db: Session, carrier_code: str) -> Optional[Carrier]:
    return db.query(Carrier).filter(func.lower(Carrier.carrier_code) == carrier_code.strip().lower(), Carrier.is_active == True).first()


def find_carrier_by_name(db: Session, carrier_name: str) -> Optional[Carrier]:
    if not carrier_name:
        return None
    name = carrier_name.strip().lower()
    return db.query(Carrier).filter(
        func.lower(Carrier.carrier_name) == name,
        Carrier.is_active == True
    ).first() or db.query(Carrier).filter(
        func.lower(Carrier.carrier_code) == name,
        Carrier.is_active == True
    ).first() or db.query(Carrier).filter(
        Carrier.carrier_name.ilike(f"%{name}%"),
        Carrier.is_active == True
    ).first()


def get_carriers(
    db: Session,
    is_active: Optional[bool] = True,
    skip: int = 0,
    limit: int = 200,
) -> Tuple[List[Carrier], int]:
    q = db.query(Carrier)
    if is_active is not None:
        q = q.filter(Carrier.is_active == is_active)
    total = q.count()
    items = q.order_by(Carrier.carrier_id.asc()).offset(skip).limit(limit).all()
    return items, total


def create_carrier(db: Session, data: dict, user: str = "System") -> Carrier:
    carrier = Carrier(**data)
    carrier.created_by = user
    carrier.updated_by = user
    db.add(carrier)
    db.flush()
    return carrier


def get_effective_demurrage_rate(
    db: Session,
    carrier_id: int,
    container_type: str,
    target_date: Optional[date] = None,
) -> Optional[CarrierDemurrageRate]:
    ref_date = target_date or date.today()
    rate = (
        db.query(CarrierDemurrageRate)
        .filter(
            CarrierDemurrageRate.carrier_id == carrier_id,
            func.lower(CarrierDemurrageRate.container_type) == container_type.strip().lower(),
            CarrierDemurrageRate.effective_date <= ref_date,
            CarrierDemurrageRate.is_active == True,
        )
        .order_by(CarrierDemurrageRate.effective_date.desc(), CarrierDemurrageRate.rate_id.desc())
        .first()
    )
    if not rate and "40" in container_type:
        rate = (
            db.query(CarrierDemurrageRate)
            .filter(
                CarrierDemurrageRate.carrier_id == carrier_id,
                CarrierDemurrageRate.container_type.ilike("%40%"),
                CarrierDemurrageRate.effective_date <= ref_date,
                CarrierDemurrageRate.is_active == True,
            )
            .order_by(CarrierDemurrageRate.effective_date.desc(), CarrierDemurrageRate.rate_id.desc())
            .first()
        )
    return rate


def get_demurrage_rates_history(
    db: Session,
    carrier_id: Optional[int] = None,
    container_type: Optional[str] = None,
) -> List[CarrierDemurrageRate]:
    q = db.query(CarrierDemurrageRate).filter(CarrierDemurrageRate.is_active == True)
    if carrier_id is not None:
        q = q.filter(CarrierDemurrageRate.carrier_id == carrier_id)
    if container_type:
        q = q.filter(func.lower(CarrierDemurrageRate.container_type) == container_type.strip().lower())
    return q.order_by(CarrierDemurrageRate.effective_date.desc()).all()


def add_carrier_demurrage_rate(db: Session, data: dict, user: str = "System") -> CarrierDemurrageRate:
    rate = CarrierDemurrageRate(**data)
    rate.created_by = user
    db.add(rate)
    db.flush()
    return rate

