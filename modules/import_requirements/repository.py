from datetime import datetime, timezone
from typing import Iterable, List, Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code
from modules.import_requirements.model import ImportRequirementAssessment
from modules.purchase_orders.model import PurchaseOrder

ASSESSMENT_CODE_PREFIX = "BP011"


def generate_assessment_code(db: Session) -> str:
    """BP011-YYYY-NNNN: continues from the highest suffix used this year (deleted rows never reuse a number)."""
    return next_yearly_code(db, ImportRequirementAssessment.assessment_code, ASSESSMENT_CODE_PREFIX, pad=4)


def get_all_assessments(
    db: Session,
    import_file_id: Optional[int] = None,
    overall_status: Optional[str] = None,
    risk_level: Optional[str] = None,
    search: Optional[str] = None,
    include_inactive: bool = False,
) -> List[ImportRequirementAssessment]:
    query = db.query(ImportRequirementAssessment)
    if not include_inactive:
        query = query.filter(ImportRequirementAssessment.is_active == True)
    if import_file_id:
        query = query.filter(ImportRequirementAssessment.import_file_id == import_file_id)
    if overall_status and overall_status != "All":
        query = query.filter(ImportRequirementAssessment.overall_status == overall_status)
    if risk_level and risk_level != "All":
        query = query.filter(ImportRequirementAssessment.risk_level == risk_level)
    if search and search.strip():
        term = f"%{search.strip()}%"
        query = query.filter(
            or_(
                ImportRequirementAssessment.assessment_code.ilike(term),
                ImportRequirementAssessment.import_file_code.ilike(term),
                ImportRequirementAssessment.hs_code.ilike(term),
                ImportRequirementAssessment.commodity_description.ilike(term),
                ImportRequirementAssessment.country_of_origin.ilike(term),
            )
        )
    return query.order_by(ImportRequirementAssessment.assessment_id.desc()).all()


def get_assessment_by_id(db: Session, assessment_id: int) -> Optional[ImportRequirementAssessment]:
    return db.query(ImportRequirementAssessment).filter(
        ImportRequirementAssessment.assessment_id == assessment_id,
        ImportRequirementAssessment.is_active == True
    ).first()


def get_assessment_by_id_include_inactive(db: Session, assessment_id: int) -> Optional[ImportRequirementAssessment]:
    return db.query(ImportRequirementAssessment).filter(
        ImportRequirementAssessment.assessment_id == assessment_id
    ).first()


def get_assessment_by_import_file(db: Session, import_file_id: int) -> Optional[ImportRequirementAssessment]:
    return db.query(ImportRequirementAssessment).filter(
        ImportRequirementAssessment.import_file_id == import_file_id,
        ImportRequirementAssessment.is_active == True
    ).first()


def create_assessment(db: Session, obj_data: dict) -> ImportRequirementAssessment:
    obj = ImportRequirementAssessment(**obj_data)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


def update_assessment(db: Session, obj: ImportRequirementAssessment, update_data: dict) -> ImportRequirementAssessment:
    for key, value in update_data.items():
        if hasattr(obj, key):
            setattr(obj, key, value)
    obj.is_active = True  # an update reactivates a soft-deleted assessment
    db.commit()
    db.refresh(obj)
    return obj


def restore_assessment(db: Session, obj: ImportRequirementAssessment, user: str) -> ImportRequirementAssessment:
    obj.is_active = True
    obj.updated_at = datetime.now(timezone.utc)
    obj.updated_by = user
    db.commit()
    db.refresh(obj)
    return obj


def soft_delete_assessment(db: Session, obj: ImportRequirementAssessment, user: str) -> None:
    obj.is_active = False
    obj.updated_at = datetime.now(timezone.utc)
    obj.updated_by = user
    db.commit()


# ── Prefill reads ────────────────────────────────────────────────────────────────

def active_pos_for_file(db: Session, import_file_id: int) -> List[PurchaseOrder]:
    return (
        db.query(PurchaseOrder)
        .filter(PurchaseOrder.import_file_id == import_file_id, PurchaseOrder.is_active == True)
        .all()
    )


def active_pos_by_ids(db: Session, po_ids: Iterable[int]) -> List[PurchaseOrder]:
    return (
        db.query(PurchaseOrder)
        .filter(PurchaseOrder.po_id.in_(list(po_ids)), PurchaseOrder.is_active == True)
        .all()
    )


def active_pos_by_number(db: Session, po_number: str) -> List[PurchaseOrder]:
    po = (
        db.query(PurchaseOrder)
        .filter(PurchaseOrder.po_number == po_number, PurchaseOrder.is_active == True)
        .first()
    )
    return [po] if po else []
