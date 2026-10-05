"""
Database Repository for Docs Customs Approval Hub (DCA-001)
Queries only: writes flush, the service owns the transaction and commits once (DCA-06).
"""

from datetime import datetime, timezone
from typing import Iterable, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc, func

from modules.common.sequence_generator import next_yearly_code
from modules.docs_customs_approval.model import (
    CustomsDocumentApproval,
    DiscrepancyRectificationTicket,
    DocsCustomsApprovalSession,
)


# --- Approval Queries ---

def generate_approval_code(db: Session) -> str:
    """``CDA-<year>-NNNN`` (DCA-05). The unique constraint stays the guard."""
    return next_yearly_code(db, CustomsDocumentApproval.approval_code, "CDA", pad=4)


def get_approval_by_id(db: Session, approval_id: int) -> Optional[CustomsDocumentApproval]:
    return db.query(CustomsDocumentApproval).filter(
        CustomsDocumentApproval.approval_id == approval_id,
        CustomsDocumentApproval.is_active == True
    ).first()


def get_approval_by_code(db: Session, approval_code: str) -> Optional[CustomsDocumentApproval]:
    return db.query(CustomsDocumentApproval).filter(
        CustomsDocumentApproval.approval_code == approval_code,
        CustomsDocumentApproval.is_active == True
    ).first()


def get_approval_by_type(
    db: Session, import_file_id: int, document_types: Iterable[str]
) -> Optional[CustomsDocumentApproval]:
    return (
        db.query(CustomsDocumentApproval)
        .filter(
            CustomsDocumentApproval.import_file_id == import_file_id,
            CustomsDocumentApproval.document_type.in_(list(document_types)),
            CustomsDocumentApproval.is_active == True,
        )
        .order_by(desc(CustomsDocumentApproval.approval_id))
        .first()
    )


def list_approvals(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    document_type: Optional[str] = None,
    overall_status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[CustomsDocumentApproval]:
    query = db.query(CustomsDocumentApproval)
    if not include_inactive:
        query = query.filter(CustomsDocumentApproval.is_active == True)
    if import_file_id is not None:
        query = query.filter(CustomsDocumentApproval.import_file_id == import_file_id)
    if document_type:
        query = query.filter(CustomsDocumentApproval.document_type == document_type)
    if overall_status and overall_status != "All":
        query = query.filter(CustomsDocumentApproval.overall_status == overall_status)
    if search:
        s = f"%{search}%"
        query = query.filter(
            or_(
                CustomsDocumentApproval.approval_code.ilike(s),
                CustomsDocumentApproval.document_reference_no.ilike(s),
                CustomsDocumentApproval.import_file_code.ilike(s),
                CustomsDocumentApproval.customs_broker_name.ilike(s),
            )
        )
    return query.order_by(desc(CustomsDocumentApproval.approval_id)).all()


def create_approval(db: Session, approval: CustomsDocumentApproval) -> CustomsDocumentApproval:
    db.add(approval)
    db.flush()
    return approval


def update_approval(db: Session, approval: CustomsDocumentApproval) -> CustomsDocumentApproval:
    current_version = getattr(approval, "version", 1) or 1
    approval.version = current_version + 1
    approval.updated_at = datetime.now(timezone.utc)
    db.flush()
    return approval


def soft_delete_approval(db: Session, approval_id: int) -> bool:
    approval = get_approval_by_id(db, approval_id)
    if not approval:
        return False
    approval.is_active = False
    approval.updated_at = datetime.now(timezone.utc)
    db.flush()
    return True


# --- Discrepancy Ticket Queries ---

def generate_ticket_code(db: Session) -> str:
    """``RECT-<year>-NNNN`` (DCA-05)."""
    return next_yearly_code(db, DiscrepancyRectificationTicket.ticket_code, "RECT", pad=4)


def get_ticket_by_id(db: Session, ticket_id: int) -> Optional[DiscrepancyRectificationTicket]:
    return db.query(DiscrepancyRectificationTicket).filter(
        DiscrepancyRectificationTicket.ticket_id == ticket_id,
        DiscrepancyRectificationTicket.is_active == True
    ).first()


def count_tickets_with_status(db: Session, import_file_id: int, statuses: Iterable[str]) -> int:
    return (
        db.query(func.count(DiscrepancyRectificationTicket.ticket_id))
        .filter(
            DiscrepancyRectificationTicket.import_file_id == import_file_id,
            DiscrepancyRectificationTicket.is_active == True,
            DiscrepancyRectificationTicket.status.in_(list(statuses)),
        )
        .scalar()
        or 0
    )


def list_tickets(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    approval_id: Optional[int] = None,
    status: Optional[str] = None,
    severity: Optional[str] = None,
    search: Optional[str] = None,
) -> List[DiscrepancyRectificationTicket]:
    query = db.query(DiscrepancyRectificationTicket)
    if not include_inactive:
        query = query.filter(DiscrepancyRectificationTicket.is_active == True)
    if import_file_id is not None:
        query = query.filter(DiscrepancyRectificationTicket.import_file_id == import_file_id)
    if approval_id is not None:
        query = query.filter(DiscrepancyRectificationTicket.approval_id == approval_id)
    if status and status != "All":
        query = query.filter(DiscrepancyRectificationTicket.status == status)
    if severity and severity != "All":
        query = query.filter(DiscrepancyRectificationTicket.severity == severity)
    if search:
        s = f"%{search}%"
        query = query.filter(
            or_(
                DiscrepancyRectificationTicket.ticket_code.ilike(s),
                DiscrepancyRectificationTicket.description.ilike(s),
                DiscrepancyRectificationTicket.issue_category.ilike(s),
            )
        )
    return query.order_by(desc(DiscrepancyRectificationTicket.ticket_id)).all()


def create_ticket(db: Session, ticket: DiscrepancyRectificationTicket) -> DiscrepancyRectificationTicket:
    db.add(ticket)
    db.flush()
    return ticket


def update_ticket(db: Session, ticket: DiscrepancyRectificationTicket) -> DiscrepancyRectificationTicket:
    ticket.updated_at = datetime.now(timezone.utc)
    db.flush()
    return ticket


# --- Customs Approval Session Queries (STEP-09) ---

def generate_session_code(db: Session) -> str:
    """``DOCAPPR-<year>-NNNN`` (DCA-05)."""
    return next_yearly_code(db, DocsCustomsApprovalSession.session_code, "DOCAPPR", pad=4)


def get_session_by_id(db: Session, session_id: int) -> Optional[DocsCustomsApprovalSession]:
    return db.query(DocsCustomsApprovalSession).filter(
        DocsCustomsApprovalSession.session_id == session_id,
        DocsCustomsApprovalSession.is_active == True,
    ).first()


def get_session_by_file_id(db: Session, import_file_id: int, include_drafts: bool = True) -> Optional[DocsCustomsApprovalSession]:
    query = db.query(DocsCustomsApprovalSession).filter(
        DocsCustomsApprovalSession.import_file_id == import_file_id,
        DocsCustomsApprovalSession.is_active == True,
    )
    if not include_drafts:
        query = query.filter(DocsCustomsApprovalSession.is_draft == False)
    return query.order_by(desc(DocsCustomsApprovalSession.session_id)).first()


def list_sessions(
    db: Session,
    import_file_id: Optional[int] = None,
    is_draft: Optional[bool] = None,
    search: Optional[str] = None,
) -> List[DocsCustomsApprovalSession]:
    query = db.query(DocsCustomsApprovalSession).filter(DocsCustomsApprovalSession.is_active == True)
    if import_file_id is not None:
        query = query.filter(DocsCustomsApprovalSession.import_file_id == import_file_id)
    if is_draft is not None:
        query = query.filter(DocsCustomsApprovalSession.is_draft == is_draft)
    if search:
        s = f"%{search}%"
        query = query.filter(
            or_(
                DocsCustomsApprovalSession.session_code.ilike(s),
                DocsCustomsApprovalSession.import_file_code.ilike(s),
                DocsCustomsApprovalSession.customs_broker_name.ilike(s),
            )
        )
    return query.order_by(desc(DocsCustomsApprovalSession.session_id)).all()


def create_session(db: Session, session_obj: DocsCustomsApprovalSession) -> DocsCustomsApprovalSession:
    db.add(session_obj)
    db.flush()
    return session_obj


def update_session(db: Session, session_obj: DocsCustomsApprovalSession) -> DocsCustomsApprovalSession:
    current_version = getattr(session_obj, "version", 1) or 1
    session_obj.version = current_version + 1
    session_obj.updated_at = datetime.now(timezone.utc)
    db.flush()
    return session_obj
