"""
FastAPI Router for Docs Customs Approval Hub (DCA-001)

Permissions (DCA-02): reads need ``import_documentation.view``; writes ``import_documentation.upload``; the
customs-broker sign-off ``customs_clearance.update`` (a final session save checks that code in the service).
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.users.model import User
from sqlalchemy.orm import Session

from database.database import get_db
from modules.common.validators import not_found
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

VIEW = "import_documentation.view"
UPLOAD = "import_documentation.upload"
CUSTOMS_SIGNOFF = "customs_clearance.update"

APPROVAL_LABEL_AR = "اعتماد المستند"
TICKET_LABEL_AR = "تذكرة الاستدراك"
SESSION_LABEL_AR = "جلسة الموافقة الجمركية"

router = APIRouter(prefix="/api/v1/docs-customs-approval", tags=["Docs Customs Approval Hub (DCA-001)"], dependencies=[Depends(get_current_user)])


@router.post(
    "",
    response_model=CustomsDocumentApprovalResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a document approval entry",
    dependencies=[Depends(require_permission(UPLOAD))],
)
def create_approval(payload: CustomsDocumentApprovalCreate, db: Session = Depends(get_db)):
    return service.create_approval_service(db, payload)


@router.get(
    "",
    response_model=List[CustomsDocumentApprovalResponse],
    summary="List document approvals with filters",
    dependencies=[Depends(require_permission(VIEW))],
)
def list_approvals(
    response: Response,
    include_inactive: bool = False,
    import_file_id: Optional[int] = Query(None),
    document_type: Optional[str] = Query(None),
    overall_status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    res = service.list_approvals_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        document_type=document_type,
        overall_status=overall_status,
        search=search,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.post(
    "/auto-generate/{import_file_id}",
    response_model=List[CustomsDocumentApprovalResponse],
    summary="Auto-populate standard pre-clearance checklist for import file",
    dependencies=[Depends(require_permission(UPLOAD))],
)
def auto_generate_approvals(import_file_id: int, db: Session = Depends(get_db)):
    return service.auto_generate_approvals_for_import_file_service(db, import_file_id)


@router.post(
    "/matrix-check/{import_file_id}",
    response_model=CrossDocumentMatrixCheckResponse,
    summary="Run AI Cross-Document Matrix Audit for import file",
    dependencies=[Depends(require_permission(UPLOAD))],
)
def run_matrix_check(import_file_id: int, db: Session = Depends(get_db)):
    return service.run_cross_document_matrix_check_service(db, import_file_id)


@router.get(
    "/tickets/list",
    response_model=List[DiscrepancyTicketResponse],
    summary="List discrepancy rectification tickets",
    dependencies=[Depends(require_permission(VIEW))],
)
def list_tickets(
    response: Response,
    include_inactive: bool = False,
    import_file_id: Optional[int] = Query(None),
    approval_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    res = service.list_rectification_tickets_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        approval_id=approval_id,
        status=status,
        severity=severity,
        search=search,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.post(
    "/tickets",
    response_model=DiscrepancyTicketResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new discrepancy rectification ticket for supplier",
    dependencies=[Depends(require_permission(UPLOAD))],
)
def create_ticket(payload: DiscrepancyTicketCreate, db: Session = Depends(get_db)):
    return service.create_rectification_ticket_service(db, payload)


@router.put(
    "/tickets/{ticket_id}",
    response_model=DiscrepancyTicketResponse,
    summary="Update discrepancy ticket",
    dependencies=[Depends(require_permission(UPLOAD))],
)
def update_ticket(ticket_id: int, payload: DiscrepancyTicketUpdate, db: Session = Depends(get_db)):
    ticket = service.update_rectification_ticket_service(db, ticket_id, payload)
    if not ticket:
        raise not_found(TICKET_LABEL_AR, ticket_id)
    return ticket


@router.post(
    "/tickets/{ticket_id}/resolve",
    response_model=DiscrepancyTicketResponse,
    summary="Resolve and close discrepancy ticket",
)
def resolve_ticket(
    ticket_id: int,
    payload: DiscrepancyTicketResolve,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPLOAD)),
):
    ticket = service.resolve_rectification_ticket_service(db, ticket_id, payload, current_user_name=current_user.username)
    if not ticket:
        raise not_found(TICKET_LABEL_AR, ticket_id)
    return ticket


# --- Docs Customs Approval Sessions Endpoints (STEP-09) ---

@router.post(
    "/sessions",
    response_model=DocsCustomsApprovalSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create or update Docs Customs Approval Session (Save or Draft Save)",
)
def create_customs_approval_session(
    payload: DocsCustomsApprovalSessionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPLOAD)),
):
    return service.create_customs_approval_session_service(db, payload, current_user=current_user)


@router.get(
    "/sessions",
    response_model=List[DocsCustomsApprovalSessionResponse],
    summary="List all Docs Customs Approval Sessions",
    dependencies=[Depends(require_permission(VIEW))],
)
def list_customs_approval_sessions(
    response: Response,
    import_file_id: Optional[int] = Query(None),
    is_draft: Optional[bool] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    res = service.list_customs_approval_sessions_service(
        db,
        import_file_id=import_file_id,
        is_draft=is_draft,
        search=search,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.get(
    "/sessions/{session_id}",
    response_model=DocsCustomsApprovalSessionResponse,
    summary="Get single Docs Customs Approval Session by ID",
    dependencies=[Depends(require_permission(VIEW))],
)
def get_customs_approval_session(session_id: int, db: Session = Depends(get_db)):
    session = service.get_customs_approval_session_service(db, session_id)
    if not session:
        raise not_found(SESSION_LABEL_AR, session_id)
    return session


@router.get(
    "/{approval_id}",
    response_model=CustomsDocumentApprovalResponse,
    summary="Get single approval record by ID",
    dependencies=[Depends(require_permission(VIEW))],
)
def get_approval(approval_id: int, db: Session = Depends(get_db)):
    approval = service.get_approval_service(db, approval_id)
    if not approval:
        raise not_found(APPROVAL_LABEL_AR, approval_id)
    return approval


@router.put(
    "/{approval_id}",
    response_model=CustomsDocumentApprovalResponse,
    summary="Update document approval record (statuses are ignored: use the review endpoints)",
)
def update_approval(
    approval_id: int,
    payload: CustomsDocumentApprovalUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPLOAD)),
):
    approval = service.update_approval_service(db, approval_id, payload, current_user_name=current_user.username)
    if not approval:
        raise not_found(APPROVAL_LABEL_AR, approval_id)
    return approval


@router.post(
    "/{approval_id}/commercial-review",
    response_model=CustomsDocumentApprovalResponse,
    summary="Submit Tier 1 Commercial / Operations review",
)
def submit_commercial_review(
    approval_id: int,
    payload: CommercialReviewPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPLOAD)),
):
    approval = service.submit_commercial_review_service(db, approval_id, payload, current_user_name=current_user.username)
    if not approval:
        raise not_found(APPROVAL_LABEL_AR, approval_id)
    return approval


@router.post(
    "/{approval_id}/customs-review",
    response_model=CustomsDocumentApprovalResponse,
    summary="Submit Tier 2 Customs Broker compliance sign-off",
)
def submit_customs_review(
    approval_id: int,
    payload: CustomsBrokerReviewPayload,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(CUSTOMS_SIGNOFF)),
):
    approval = service.submit_customs_broker_review_service(db, approval_id, payload, current_user_name=current_user.username)
    if not approval:
        raise not_found(APPROVAL_LABEL_AR, approval_id)
    return approval


@router.delete(
    "/{approval_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete a document approval",
    dependencies=[Depends(require_permission(UPLOAD))],
)
def delete_approval(approval_id: int, db: Session = Depends(get_db)):
    success = service.soft_delete_approval_service(db, approval_id)
    if not success:
        raise not_found(APPROVAL_LABEL_AR, approval_id)
    return None
