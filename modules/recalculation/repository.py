"""
Repository for Centralized Recalculation Engine (CRE-001)

Responsibility: Database reads/writes ONLY.
No business logic here — all logic lives in service.py.
"""
import json
from typing import List, Optional
from sqlalchemy.orm import Session
from modules.recalculation.model import RecalculationDependencyMap, RecalculationLog


# ─── Dependency Map ──────────────────────────────────────────────────────────

def get_active_dependencies_for_target(
    db: Session,
    target_entity_type: str,
) -> List[RecalculationDependencyMap]:
    """
    Returns all active dependency rows where the given entity type is the TARGET.
    Used by service.preview() and service.apply() to discover what to fetch.
    """
    return (
        db.query(RecalculationDependencyMap)
        .filter(
            RecalculationDependencyMap.target_entity_type == target_entity_type,
            RecalculationDependencyMap.is_active == True,
        )
        .order_by(RecalculationDependencyMap.display_order)
        .all()
    )


def get_all_dependencies(
    db: Session,
    include_inactive: bool = False,
) -> List[RecalculationDependencyMap]:
    q = db.query(RecalculationDependencyMap)
    if not include_inactive:
        q = q.filter(RecalculationDependencyMap.is_active == True)
    return q.order_by(RecalculationDependencyMap.target_entity_type, RecalculationDependencyMap.display_order).all()


def get_dependency_by_id(db: Session, dep_id: int) -> Optional[RecalculationDependencyMap]:
    return db.query(RecalculationDependencyMap).filter(RecalculationDependencyMap.id == dep_id).first()


def upsert_dependency(
    db: Session,
    target_entity_type: str,
    target_field: str,
    source_entity_type: str,
    source_field: str,
    join_key: str = "import_file_id",
    aggregation_function: str = "max",
    blocked_statuses: Optional[list] = None,
    required_permission: Optional[str] = None,
    label_ar: Optional[str] = None,
    label_en: Optional[str] = None,
    display_order: int = 0,
) -> RecalculationDependencyMap:
    """
    Create or update a dependency row.
    Idempotent: matches on (target_entity_type, target_field, source_entity_type, source_field).
    Used by seed_dependencies.py (flush only: the caller commits).
    """
    valid_aggregations = ("max", "min", "sum", "latest")
    if aggregation_function not in valid_aggregations:
        raise ValueError(
            f"Invalid aggregation function '{aggregation_function}'. Must be one of {valid_aggregations}."
        )
    dep = (
        db.query(RecalculationDependencyMap)
        .filter(
            RecalculationDependencyMap.target_entity_type == target_entity_type,
            RecalculationDependencyMap.target_field == target_field,
            RecalculationDependencyMap.source_entity_type == source_entity_type,
            RecalculationDependencyMap.source_field == source_field,
        )
        .first()
    )
    blocked_json = json.dumps(blocked_statuses or [])
    if dep is None:
        dep = RecalculationDependencyMap(
            target_entity_type=target_entity_type,
            target_field=target_field,
            source_entity_type=source_entity_type,
            source_field=source_field,
            join_key=join_key,
            aggregation_function=aggregation_function,
            blocked_statuses=blocked_json,
            required_permission=required_permission,
            label_ar=label_ar,
            label_en=label_en,
            display_order=display_order,
            is_active=True,
        )
        db.add(dep)
    else:
        dep.join_key = join_key
        dep.aggregation_function = aggregation_function
        dep.blocked_statuses = blocked_json
        dep.required_permission = required_permission
        dep.label_ar = label_ar
        dep.label_en = label_en
        dep.display_order = display_order
        dep.is_active = True
    db.flush()
    return dep


def deactivate_dependency(
    db: Session,
    target_entity_type: str,
    target_field: str,
    source_entity_type: str,
    source_field: str,
) -> Optional[RecalculationDependencyMap]:
    """
    Deactivates a dependency row by setting is_active = False.
    Idempotent: matches on (target_entity_type, target_field, source_entity_type, source_field).
    Used by seed_dependencies.py (flush only: the caller commits).
    """
    dep = (
        db.query(RecalculationDependencyMap)
        .filter(
            RecalculationDependencyMap.target_entity_type == target_entity_type,
            RecalculationDependencyMap.target_field == target_field,
            RecalculationDependencyMap.source_entity_type == source_entity_type,
            RecalculationDependencyMap.source_field == source_field,
        )
        .first()
    )
    if dep is not None:
        dep.is_active = False
        db.flush()
    return dep



# ─── Recalculation Logs ──────────────────────────────────────────────────────

def create_log(
    db: Session,
    target_entity_type: str,
    target_entity_id: int,
    action: str,
    performed_by: Optional[str],
    source_page: Optional[str],
    preview_data: Optional[list] = None,
    changes_applied: Optional[list] = None,
    justification: Optional[str] = None,
    result_status: Optional[str] = None,
    action_taken: Optional[str] = None,
    new_entity_id: Optional[int] = None,
) -> RecalculationLog:
    """Creates a unified audit log entry (flush only: the service commits it with the change, RC-04)."""
    log = RecalculationLog(
        target_entity_type=target_entity_type,
        target_entity_id=target_entity_id,
        action=action,
        performed_by=performed_by,
        source_page=source_page,
        preview_data=json.dumps(preview_data or []),
        changes_applied=json.dumps(changes_applied or []),
        justification=justification,
        result_status=result_status,
        action_taken=action_taken,
        new_entity_id=new_entity_id,
    )
    db.add(log)
    db.flush()
    return log


def get_logs_for_entity(
    db: Session,
    target_entity_type: str,
    target_entity_id: int,
    limit: int = 50,
) -> List[RecalculationLog]:
    return (
        db.query(RecalculationLog)
        .filter(
            RecalculationLog.target_entity_type == target_entity_type,
            RecalculationLog.target_entity_id == target_entity_id,
        )
        .order_by(RecalculationLog.created_at.desc())
        .limit(limit)
        .all()
    )
