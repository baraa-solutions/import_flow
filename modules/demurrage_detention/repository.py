from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func
from .model import DemurragePolicy, DemurrageTracking
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
    limit: int = 100,
) -> List[DemurragePolicy]:
    q = db.query(DemurragePolicy).filter(DemurragePolicy.is_active == True)
    if carrier_name:
        q = q.filter(DemurragePolicy.carrier_name.ilike(f"%{carrier_name}%"))
    if container_type:
        q = q.filter(DemurragePolicy.container_type.ilike(f"%{container_type}%"))
    return q.offset(skip).limit(limit).all()


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
    """Returns the active demurrage tracking linked to this import file (BE45-T06)."""
    return db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == import_file_id,
        DemurrageTracking.is_active == True,
    ).first()


def get_active_trackings_for_file(db: Session, import_file_id: int) -> List[DemurrageTracking]:
    """Returns all active demurrage trackings linked to this import file (BE45-T06)."""
    return db.query(DemurrageTracking).filter(
        DemurrageTracking.import_file_id == import_file_id,
        DemurrageTracking.is_active == True,
    ).all()


def get_active_tracking_for_bl(db: Session, bill_of_lading_no: str) -> Optional[DemurrageTracking]:
    """Returns the active demurrage tracking with this B/L number (BE45-T06)."""
    if not bill_of_lading_no or not bill_of_lading_no.strip():
        return None
    return db.query(DemurrageTracking).filter(
        func.lower(DemurrageTracking.bill_of_lading_no) == bill_of_lading_no.strip().lower(),
        DemurrageTracking.is_active == True,
    ).first()


def get_trackings(
    db: Session,
    import_file_id: Optional[int] = None,
    carrier_name: Optional[str] = None,
    status_filter: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
) -> List[DemurrageTracking]:
    q = db.query(DemurrageTracking).filter(DemurrageTracking.is_active == True)
    if import_file_id:
        q = q.filter(DemurrageTracking.import_file_id == import_file_id)
    if carrier_name:
        q = q.filter(DemurrageTracking.carrier_name.ilike(f"%{carrier_name}%"))
    if status_filter:
        q = q.filter(DemurrageTracking.status == status_filter)
    return q.order_by(DemurrageTracking.tracking_id.desc()).offset(skip).limit(limit).all()


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
