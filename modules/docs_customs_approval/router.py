"""
FastAPI Router for Docs Customs Approval Hub (DCA-001)
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from modules.auth.router import get_current_user
from modules.users.model import User
from sqlalchemy.orm import Session

from database.database import get_db
from modules.docs_customs_approval.schemas import (
    CustomsDocumentApprovalCreate,
    CustomsDocumentApprovalUpdate,
    CustomsDocumentApprovalResponse,
    CommercialReviewPayload,
    CustomsBrokerReviewPayload,
    CrossDocumentMatrixCheckResponse,
    DiscrepancyTicketCreate,
    DiscrepancyTicketUpdate,
    DiscrepancyTicketResolve,
    DiscrepancyTicketResponse,
    DocsCustomsApprovalSessionCreate,
    DocsCustomsApprovalSessionResponse,
)
import modules.docs_customs_approval.service as service

router = APIRouter(prefix="/api/v1/docs-customs-approval", tags=["Docs Customs Approval Hub (DCA-001)"], dependencies=[Depends(get_current_user)])


@router.post(
    "",
    response_model=CustomsDocumentApprovalResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a document approval entry",
)
def create_approval(payload: CustomsDocumentApprovalCreate, db: Session = Depends(get_db)):
    return service.create_approval_service(db, payload)


@router.get(
    "",
    response_model=List[CustomsDocumentApprovalResponse],
    summary="List document approvals with filters",
)
def list_approvals(
    include_inactive: bool = False,
    import_file_id: Optional[int] = Query(None),
    document_type: Optional[str] = Query(None),
    overall_status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    return service.list_approvals_service(db, include_inactive, import_file_id, document_type, overall_status, search)


@router.post(
    "/auto-generate/{import_file_id}",
    response_model=List[CustomsDocumentApprovalResponse],
    summary="Auto-populate standard pre-clearance checklist for import file",
)
def auto_generate_approvals(import_file_id: int, db: Session = Depends(get_db)):
    return service.auto_generate_approvals_for_import_file_service(db, import_file_id)


@router.post(
    "/matrix-check/{import_file_id}",
    response_model=CrossDocumentMatrixCheckResponse,
    summary="Run AI Cross-Document Matrix Audit for import file",
)
def run_matrix_check(import_file_id: int, db: Session = Depends(get_db)):
    return service.run_cross_document_matrix_check_service(db, import_file_id)


@router.get(
    "/tickets/list",
    response_model=List[DiscrepancyTicketResponse],
    summary="List discrepancy rectification tickets",
)
def list_tickets(
    include_inactive: bool = False,
    import_file_id: Optional[int] = Query(None),
    approval_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    return service.list_rectification_tickets_service(db, include_inactive, import_file_id, approval_id, status, severity, search)


@router.post(
    "/tickets",
    response_model=DiscrepancyTicketResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new discrepancy rectification ticket for supplier",
)
def create_ticket(payload: DiscrepancyTicketCreate, db: Session = Depends(get_db)):
    return service.create_rectification_ticket_service(db, payload)


@router.put(
    "/tickets/{ticket_id}",
    response_model=DiscrepancyTicketResponse,
    summary="Update discrepancy ticket",
)
def update_ticket(ticket_id: int, payload: DiscrepancyTicketUpdate, db: Session = Depends(get_db)):
    ticket = service.update_rectification_ticket_service(db, ticket_id, payload)
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rectification ticket not found.")
    return ticket


@router.post(
    "/tickets/{ticket_id}/resolve",
    response_model=DiscrepancyTicketResponse,
    summary="Resolve and close discrepancy ticket",
)
def resolve_ticket(ticket_id: int, payload: DiscrepancyTicketResolve, db: Session = Depends(get_db)):
    ticket = service.resolve_rectification_ticket_service(db, ticket_id, payload)
    if not ticket:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rectification ticket not found.")
    return ticket


# --- Docs Customs Approval Sessions Endpoints (STEP-09) ---

@router.post(
    "/sessions",
    response_model=DocsCustomsApprovalSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create or update Docs Customs Approval Session (Save or Draft Save)",
)
def create_customs_approval_session(
    payload: DocsCustomsApprovalSessionCreate, db: Session = Depends(get_db)
):
    return service.create_customs_approval_session_service(db, payload)


@router.get(
    "/sessions",
    response_model=List[DocsCustomsApprovalSessionResponse],
    summary="List all Docs Customs Approval Sessions",
)
def list_customs_approval_sessions(
    import_file_id: Optional[int] = Query(None),
    is_draft: Optional[bool] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    return service.list_customs_approval_sessions_service(
        db, import_file_id=import_file_id, is_draft=is_draft, search=search
    )


@router.get(
    "/sessions/{session_id}",
    response_model=DocsCustomsApprovalSessionResponse,
    summary="Get single Docs Customs Approval Session by ID",
)
def get_customs_approval_session(session_id: int, db: Session = Depends(get_db)):
    session = service.get_customs_approval_session_service(db, session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Docs Customs Approval Session not found.",
        )
    return session


@router.get(
    "/{approval_id}",
    response_model=CustomsDocumentApprovalResponse,
    summary="Get single approval record by ID",
)

def get_approval(approval_id: int, db: Session = Depends(get_db)):
    approval = service.get_approval_service(db, approval_id)
    if not approval:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document approval not found.")
    return approval


@router.put(
    "/{approval_id}",
    response_model=CustomsDocumentApprovalResponse,
    summary="Update document approval record",
)
def update_approval(
    approval_id: int,
    payload: CustomsDocumentApprovalUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    approval = service.update_approval_service(db, approval_id, payload, current_user_name=current_user.username)
    if not approval:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document approval not found.")
    return approval


@router.post(
    "/{approval_id}/commercial-review",
    response_model=CustomsDocumentApprovalResponse,
    summary="Submit Tier 1 Commercial / Operations review",
)
def submit_commercial_review(approval_id: int, payload: CommercialReviewPayload, db: Session = Depends(get_db)):
    approval = service.submit_commercial_review_service(db, approval_id, payload)
    if not approval:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document approval not found.")
    return approval


@router.post(
    "/{approval_id}/customs-review",
    response_model=CustomsDocumentApprovalResponse,
    summary="Submit Tier 2 Customs Broker compliance sign-off",
)
def submit_customs_review(approval_id: int, payload: CustomsBrokerReviewPayload, db: Session = Depends(get_db)):
    approval = service.submit_customs_broker_review_service(db, approval_id, payload)
    if not approval:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document approval not found.")
    return approval


@router.delete(
    "/{approval_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete a document approval",
)
def delete_approval(approval_id: int, db: Session = Depends(get_db)):
    success = service.soft_delete_approval_service(db, approval_id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document approval not found.")
    return None


