"""
FastAPI Router for Import Documentation & ACI (Phase 3 - BP-014 to BP-019)

HTTP only (Phase 3a, DOC-01 / DOC-12 / DOC-14 / DOC-16 / DOC-17):
- every route declares ``require_permission``: ``import_documentation.view`` for reads and pure compare / parse /
  template routes, ``import_documentation.upload`` for every write and every upload / extract route (OCR and
  optional external LLMs), ``import_documentation.approve`` for the draft B/L approval routes;
- the acting user is always the authenticated user (``user=current_user.username``); client identity fields
  (``approved_by``, ``reviewer_name``, ``reviewed_by``, ``certified_by``) are ignored;
- uploads are size / extension checked (``validators.validate_upload``) and read in the threadpool (plain ``def``);
- status fields are validated in the service layer (``validators.validate_status``).
"""

from typing import Any, Dict, List, Optional, Tuple

from fastapi import APIRouter, Depends, File, Form, Query, Response, UploadFile, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.import_documentation import validators
from modules.import_documentation.schemas import (
    AcidComparisonRequest,
    AcidRegistrationCreate,
    AcidRegistrationResponse,
    AcidRegistrationUpdate,
    AcidRequestTemplateResponse,
    AcidTextParseRequest,
    AcidTextParseResponse,
    AcidTrackerSummary,
    BankingDocumentCreate,
    BankingDocumentReceive,
    BankingDocumentResponse,
    BankingDocumentUpdate,
    TaxCodingSheetPullRequest,
    TaxCodingSheetUploadRequest,
    ItemsVerificationConfirmRequest,
    NafezaBankLinkConfirmRequest,
    CentralArchiveResponse,
    CertificateOfOriginReviewCreate,
    CertificateOfOriginReviewResponse,
    CertificateOfOriginReviewUpdate,
    COOComparisonRequest,
    COODraftTemplateResponse,
    CustomsDeclarationCreate,
    CustomsDeclarationResponse,
    DocumentExtractRequest,
    DocumentExtractResponse,
    DraftBLChecklistItem,
    DraftBLComparisonRequest,
    DraftBLReviewCreate,
    DraftBLReviewResponse,
    DraftBLReviewUpdate,
    DualApprovalRequest,
    InspectionCertificateReviewCreate,
    InspectionCertificateReviewResponse,
    InspectionCertificateReviewUpdate,
    InspectionComparisonRequest,
    InspectionDraftTemplateResponse,
    InvoiceBLExtractAndMatchRequest,
    InvoiceBLExtractAndMatchResponse,
    InvoiceBLMatchSessionCreate,
    InvoiceBLMatchSessionResponse,
    InvoiceBLSyncRequest,
    LegalDocsExpiryComplianceResponse,
    NewDraftVersionRequest,
    POExtractAndCompareRequest,
    POExtractAndCompareResponse,
    POFinalAdjustmentRequest,
    POReconciliationSessionCreate,
    POReconciliationSessionResponse,
    POReconciliationSessionUpdate,
    ShipmentDocumentCreate,
    ShipmentDocumentResponse,
    ThreeWayCrossMatchRequest,
    ThreeWayCrossMatchResponse,
)
from modules.users.model import User
import modules.import_documentation.service as service

router = APIRouter(prefix="/api/v1/import-documentation", tags=["Import Documentation"], dependencies=[Depends(get_current_user)])

PERM_VIEW = "import_documentation.view"
PERM_UPLOAD = "import_documentation.upload"
PERM_APPROVE = "import_documentation.approve"

can_view = require_permission(PERM_VIEW)
can_upload = require_permission(PERM_UPLOAD)
can_approve = require_permission(PERM_APPROVE)

UploadedFile = Tuple[str, bytes]


def _read_upload(file: UploadFile) -> UploadedFile:
    """(filename, bytes) of a validated upload. Reads at most MAX_UPLOAD_BYTES + 1 bytes, so an oversized file
    is rejected (413) without being loaded whole."""
    content = file.file.read(validators.MAX_UPLOAD_BYTES + 1)
    return validators.validate_upload(file.filename, content), content


def _read_uploads(*groups: Optional[Any]) -> List[UploadedFile]:
    """Validated uploads of single-file and multi-file form fields, in order, each file once."""
    files: List[UploadFile] = []
    for group in groups:
        for f in (group if isinstance(group, list) else [group]):
            if f is not None and not any(f is seen for seen in files):
                files.append(f)
    return [_read_upload(f) for f in files]


# --- ACID REGISTRATION & TRACKER ENDPOINTS (BP-014) ---
@router.get(
    "/acid/tracker",
    response_model=AcidTrackerSummary,
    status_code=status.HTTP_200_OK,
)
def get_acid_tracker(db: Session = Depends(get_db), current_user: User = Depends(can_view)):
    """
    ACID Expiry Tracker: Lists all active ACID registrations and import files with
    calculated days remaining, validity %, and customs release status (alerts removed once customs released).
    """
    return service.get_acid_tracker_service(db)


@router.post(
    "/acid/parse-text",
    response_model=AcidTextParseResponse,
    status_code=status.HTTP_200_OK,
)
def parse_acid_text(
    payload: AcidTextParseRequest, db: Session = Depends(get_db), current_user: User = Depends(can_view)
):
    """
    Smart Nafeza Text Parser: Extracts structured ACID fields from raw MTS text notifications
    and optionally computes live discrepancy comparison against the selected import file.
    """
    return service.parse_acid_text_service(db, payload.raw_text, payload.import_file_id)


@router.post(
    "/acid/compare",
    status_code=status.HTTP_200_OK,
)
def compare_acid_data(payload: AcidComparisonRequest, current_user: User = Depends(can_view)):
    """
    Compares requested shipment parameters with generated ACID data and returns a discrepancy matrix.
    """
    return service.compare_acid_datasets_service(payload.requested, payload.generated)


@router.post(
    "/acid/templates",
    response_model=AcidRequestTemplateResponse,
    status_code=status.HTTP_200_OK,
)
def generate_acid_templates(payload: Dict[str, Any], current_user: User = Depends(can_view)):
    """
    Generates ready-to-use WhatsApp and Email templates for customs broker communication.
    """
    return service.generate_acid_templates_service(payload)


@router.post(
    "/acid-sessions",
    response_model=AcidRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_acid_session(
    payload: AcidRegistrationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.create_acid_session_service(db, payload, user=current_user.username)


@router.get("/acid-sessions", response_model=List[AcidRegistrationResponse])
def list_acid_sessions(
    response: Response,
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    res = service.list_acid_sessions_service(
        db,
        include_inactive=include_inactive,
        search=search,
        import_file_id=import_file_id,
        status=status,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.get("/acid-sessions/{acid_id}", response_model=AcidRegistrationResponse)
def get_acid_session(acid_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_view)):
    return service.get_acid_session_service(db, acid_id)


@router.put("/acid-sessions/{acid_id}", response_model=AcidRegistrationResponse)
def update_acid_session(
    acid_id: int,
    payload: AcidRegistrationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.update_acid_session_service(db, acid_id, payload, user=current_user.username)


@router.delete("/acid-sessions/{acid_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_acid_session(acid_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_upload)):
    service.soft_delete_acid_session_service(db, acid_id, user=current_user.username)


@router.patch("/acid-sessions/{acid_id}/restore", response_model=AcidRegistrationResponse)
def restore_acid_session(acid_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_upload)):
    return service.restore_acid_session_service(db, acid_id, user=current_user.username)


# --- BANKING DOCUMENTS ENDPOINTS (BP-015) ---
@router.post(
    "/banking-documents",
    response_model=BankingDocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_banking_document(
    payload: BankingDocumentCreate, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    return service.create_banking_document_service(db, payload, user=current_user.username)


@router.get("/banking-documents", response_model=List[BankingDocumentResponse])
def list_banking_documents(
    response: Response,
    import_file_id: Optional[int] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    res = service.list_banking_documents_service(
        db, import_file_id=import_file_id, skip=skip, limit=limit, return_total=True
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.get("/banking-documents/{bank_doc_id}", response_model=BankingDocumentResponse)
def get_banking_document(bank_doc_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_view)):
    return service.get_banking_document_service(db, bank_doc_id)


@router.put("/banking-documents/{bank_doc_id}", response_model=BankingDocumentResponse)
def update_banking_document(
    bank_doc_id: int,
    payload: BankingDocumentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.update_banking_document_service(db, bank_doc_id, payload, user=current_user.username)


@router.post(
    "/banking-documents/{bank_doc_id}/receive",
    response_model=BankingDocumentResponse,
)
def receive_banking_document(
    bank_doc_id: int,
    payload: BankingDocumentReceive,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.receive_banking_document_service(
        db,
        bank_doc_id,
        form4_number=payload.form4_number,
        received_date=payload.received_date,
        notes=payload.notes,
        user=current_user.username,
    )


@router.post(
    "/banking-documents/{bank_doc_id}/tax-coding-sheet/pull",
    response_model=BankingDocumentResponse,
)
def record_tax_coding_sheet_pull(
    bank_doc_id: int,
    payload: TaxCodingSheetPullRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.record_tax_coding_sheet_pull_service(
        db, bank_doc_id, payload, user=current_user.username
    )


@router.post(
    "/banking-documents/{bank_doc_id}/tax-coding-sheet/upload",
    response_model=BankingDocumentResponse,
)
def record_tax_coding_sheet_upload(
    bank_doc_id: int,
    payload: TaxCodingSheetUploadRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.record_tax_coding_sheet_upload_service(
        db, bank_doc_id, payload, user=current_user.username
    )


@router.post(
    "/banking-documents/{bank_doc_id}/items/verify",
    response_model=BankingDocumentResponse,
)
def record_items_verification(
    bank_doc_id: int,
    payload: ItemsVerificationConfirmRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.record_items_verification_service(
        db, bank_doc_id, payload, user=current_user.username
    )


@router.post(
    "/banking-documents/{bank_doc_id}/nafeza-bank-link",
    response_model=BankingDocumentResponse,
)
def record_nafeza_bank_link(
    bank_doc_id: int,
    payload: NafezaBankLinkConfirmRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.record_nafeza_bank_link_service(
        db, bank_doc_id, payload, user=current_user.username
    )


@router.delete("/banking-documents/{bank_doc_id}")
def delete_banking_document(bank_doc_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_upload)):
    return service.delete_banking_document_service(db, bank_doc_id, user=current_user.username)


# --- SHIPMENT DOCUMENTS & CARGOX ENDPOINTS (BP-016, BP-017, BP-018) ---
@router.post(
    "/shipment-documents",
    response_model=ShipmentDocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_shipment_document(
    payload: ShipmentDocumentCreate, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    return service.create_shipment_document_service(db, payload, user=current_user.username)


@router.get("/shipment-documents", response_model=List[ShipmentDocumentResponse])
def list_shipment_documents(
    response: Response,
    import_file_id: Optional[int] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    res = service.list_shipment_documents_service(
        db, import_file_id=import_file_id, skip=skip, limit=limit, return_total=True
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.post(
    "/shipment-documents/{doc_id}/cargox-bl",
    response_model=ShipmentDocumentResponse,
)
def update_cargox_and_bl_endorsement(
    doc_id: int,
    cargox_envelope_id: Optional[str] = None,
    endorsement_number: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.update_cargox_and_bl_endorsement_service(
        db, doc_id, cargox_envelope_id, endorsement_number, user=current_user.username
    )


# --- CUSTOMS DECLARATION 46 ENDPOINTS (BP-019) ---
@router.post(
    "/customs-declarations",
    response_model=CustomsDeclarationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_customs_declaration(
    payload: CustomsDeclarationCreate, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    return service.create_customs_declaration_service(db, payload, user=current_user.username)


# ==============================================================================
# PHASE 6: INTELLIGENT DOCUMENT VERIFICATION & COMPARISON ENDPOINTS
# ==============================================================================

# --- 1. PO FINAL RECONCILIATION ---
@router.post("/po-reconciliation", status_code=status.HTTP_200_OK)
def reconcile_po_final_adjustments(
    payload: POFinalAdjustmentRequest, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    return service.reconcile_po_final_adjustments_service(db, payload, user=current_user.username)


@router.post(
    "/po-reconciliation/extract-and-compare",
    response_model=POExtractAndCompareResponse,
    status_code=status.HTTP_200_OK,
)
def extract_and_compare_po_documents(
    payload: POExtractAndCompareRequest, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    """
    Intelligently extracts Commercial Invoice and Final Packing List data,
    executes 3-way reconciliation against System PO, and returns discrepancy variances.
    """
    return service.extract_and_compare_po_documents_service(db, payload)


@router.post(
    "/po-reconciliation/extract-files-and-compare",
    response_model=POExtractAndCompareResponse,
    status_code=status.HTTP_200_OK,
)
def extract_po_reconciliation_files_and_compare(
    invoice_file: Optional[UploadFile] = File(None),
    packing_file: Optional[UploadFile] = File(None),
    import_file_id: Optional[int] = Form(None),
    invoice_text: Optional[str] = Form(None),
    packing_text: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    """
    Accepts uploaded Commercial Invoice and/or Packing List files (PDF, Word, Excel, Text)
    and executes 3-way reconciliation against System PO data.
    """
    validators.validate_raw_text_length(invoice_text, "invoice_text")
    validators.validate_raw_text_length(packing_text, "packing_text")
    return service.extract_po_files_and_compare_service(
        db,
        invoice=_read_upload(invoice_file) if invoice_file else None,
        packing=_read_upload(packing_file) if packing_file else None,
        import_file_id=import_file_id,
        invoice_text=invoice_text,
        packing_text=packing_text,
    )


# --- PO & PACKING RECONCILIATION SESSIONS ENDPOINTS (BP-016) ---
@router.post(
    "/po-reconciliation/sessions",
    response_model=POReconciliationSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_po_reconciliation_session(
    payload: POReconciliationSessionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    """
    Creates a new PO & Packing List final reconciliation session.
    Strictly prevents duplicate sessions for the same import file.
    """
    return service.create_po_reconciliation_session_service(db, payload, user=current_user.username)


@router.get(
    "/po-reconciliation/sessions",
    response_model=List[POReconciliationSessionResponse],
    status_code=status.HTTP_200_OK,
)
def get_po_reconciliation_sessions(
    response: Response,
    import_file_id: Optional[int] = None,
    overall_status: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    """
    Lists saved PO & Packing List final reconciliation sessions with optional filters.
    """
    res = service.get_po_reconciliation_sessions_service(
        db,
        import_file_id=import_file_id,
        overall_status=overall_status,
        search=search,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.get(
    "/po-reconciliation/sessions/{session_id}",
    response_model=POReconciliationSessionResponse,
    status_code=status.HTTP_200_OK,
)
def get_po_reconciliation_session_by_id(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    """
    Retrieves a single PO & Packing List final reconciliation session by ID.
    """
    return service.get_po_reconciliation_session_by_id_service(db, session_id)


@router.put(
    "/po-reconciliation/sessions/{session_id}",
    response_model=POReconciliationSessionResponse,
    status_code=status.HTTP_200_OK,
)
def update_po_reconciliation_session(
    session_id: int,
    payload: POReconciliationSessionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    """
    Updates an existing PO & Packing List final reconciliation session.
    """
    return service.update_po_reconciliation_session_service(db, session_id, payload, user=current_user.username)


@router.delete(
    "/po-reconciliation/sessions/{session_id}",
    status_code=status.HTTP_200_OK,
)
def delete_po_reconciliation_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    """
    Soft-deletes a PO & Packing List final reconciliation session.
    """
    return service.delete_po_reconciliation_session_service(db, session_id, user=current_user.username)


# --- 2. DRAFT BILL OF LADING (B/L) ENDPOINTS ---
@router.post("/draft-bl/extract-file", status_code=status.HTTP_200_OK)
def extract_draft_bl_from_file(
    file: UploadFile = File(...),
    import_file_id: Optional[int] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    """
    Extracts raw text from uploaded PDF, Word, Excel, or Text file, extracts B/L fields,
    and optionally executes comparison against the active import file.
    """
    filename, content = _read_upload(file)
    return service.extract_draft_bl_file_service(
        db, filename=filename, content=content, import_file_id=import_file_id
    )


@router.post("/draft-bl/compare", status_code=status.HTTP_200_OK)
def compare_draft_bl(
    payload: DraftBLComparisonRequest, db: Session = Depends(get_db), current_user: User = Depends(can_view)
):
    return service.compare_draft_bl_service(db, payload)


@router.post(
    "/draft-bl",
    response_model=DraftBLReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_draft_bl_review(
    payload: DraftBLReviewCreate, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    # status / stage / approval fields of the payload are server-owned (C2): the service ignores them.
    return service.create_draft_bl_review_service(db, payload, user=current_user.username)


@router.get("/draft-bl", response_model=List[DraftBLReviewResponse])
def list_draft_bl_reviews(
    response: Response,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    is_draft: Optional[bool] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    res = service.get_draft_bl_reviews_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        is_draft=is_draft,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.get("/draft-bl/{review_id}", response_model=DraftBLReviewResponse)
def get_draft_bl_review(review_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_view)):
    return service.get_draft_bl_review_service(db, review_id)


@router.delete("/draft-bl/{review_id}", status_code=status.HTTP_200_OK)
def delete_draft_bl_review(review_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_upload)):
    return service.delete_draft_bl_review_service(db, review_id, user=current_user.username)


@router.put("/draft-bl/{review_id}", response_model=DraftBLReviewResponse)
def update_draft_bl_review(
    review_id: int,
    payload: DraftBLReviewUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.update_draft_bl_review_service(db, review_id, payload, user=current_user.username)


@router.put("/draft-bl/{review_id}/checklist", response_model=DraftBLReviewResponse)
def update_draft_bl_checklist(
    review_id: int,
    checklist_items: List[DraftBLChecklistItem],
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    # The former ?reviewer_name= query param is ignored (C3): the reviewer is the logged-in user.
    return service.update_draft_bl_checklist_service(db, review_id, checklist_items, user=current_user.username)


@router.post("/draft-bl/dual-approval", response_model=DraftBLReviewResponse)
def process_draft_bl_dual_approval(
    payload: DualApprovalRequest, db: Session = Depends(get_db), current_user: User = Depends(can_approve)
):
    return service.process_dual_approval_service(db, payload, user=current_user.username)


@router.post("/draft-bl/new-version", response_model=DraftBLReviewResponse, status_code=status.HTTP_201_CREATED)
def create_new_draft_version(
    payload: NewDraftVersionRequest, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    return service.create_new_draft_version_service(db, payload, user=current_user.username)


@router.post("/draft-bl/{review_id}/approve", response_model=DraftBLReviewResponse)
def approve_draft_bl(review_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_approve)):
    # The former ?approved_by= query param is ignored (C3): the approver is the logged-in user. It only completes
    # the one missing role of a half-approved review (409 when none or both roles are open, or same approver).
    return service.approve_draft_bl_service(db, review_id, user=current_user.username)


# --- 3. CERTIFICATE OF ORIGIN (COO / EUR.1) ENDPOINTS ---
@router.post("/coo/compare", status_code=status.HTTP_200_OK)
def compare_coo(payload: COOComparisonRequest, db: Session = Depends(get_db), current_user: User = Depends(can_view)):
    return service.compare_coo_service(db, payload)


@router.post(
    "/coo",
    response_model=CertificateOfOriginReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_coo_review(
    payload: CertificateOfOriginReviewCreate, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    return service.create_coo_review_service(db, payload, user=current_user.username)


@router.get("/coo", response_model=List[CertificateOfOriginReviewResponse])
def list_coo_reviews(
    response: Response,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    is_draft: Optional[bool] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    res = service.get_coo_reviews_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        is_draft=is_draft,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.put("/coo/{review_id}", response_model=CertificateOfOriginReviewResponse)
def update_coo_review(
    review_id: int,
    payload: CertificateOfOriginReviewUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.update_coo_review_service(db, review_id, payload, user=current_user.username)


@router.delete("/coo/{review_id}", status_code=status.HTTP_200_OK)
def delete_coo_review(review_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_upload)):
    return service.delete_coo_review_service(db, review_id, user=current_user.username)


@router.get(
    "/coo/draft-template/{import_file_id}",
    response_model=COODraftTemplateResponse,
    status_code=status.HTTP_200_OK,
)
def get_coo_draft_template(
    import_file_id: int,
    cert_type: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    """
    Generates a pre-filled, official draft template for China CCPIT COO or EUR.1 Movement Certificate
    from Import File, Final Invoice, Packing List, and B/L snapshots.
    """
    return service.generate_coo_draft_template_service(db, import_file_id, cert_type)


# --- 4. INSPECTION CERTIFICATE ENDPOINTS ---
@router.post("/inspection/compare", status_code=status.HTTP_200_OK)
def compare_inspection(
    payload: InspectionComparisonRequest, db: Session = Depends(get_db), current_user: User = Depends(can_view)
):
    return service.compare_inspection_cert_service(db, payload)


@router.post(
    "/inspection",
    response_model=InspectionCertificateReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_inspection_review(
    payload: InspectionCertificateReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.create_inspection_review_service(db, payload, user=current_user.username)


@router.get("/inspection", response_model=List[InspectionCertificateReviewResponse])
def list_inspection_reviews(
    response: Response,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    res = service.get_inspection_reviews_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        skip=skip,
        limit=limit,
        return_total=True,
    )
    items, total = res if isinstance(res, tuple) else (res, len(res))
    response.headers["X-Total-Count"] = str(total)
    return items


@router.put("/inspection/{review_id}", response_model=InspectionCertificateReviewResponse)
def update_inspection_review(
    review_id: int,
    payload: InspectionCertificateReviewUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    return service.update_inspection_review_service(db, review_id, payload, user=current_user.username)


@router.delete("/inspection/{review_id}", status_code=status.HTTP_200_OK)
def delete_inspection_review(review_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_upload)):
    return service.delete_inspection_review_service(db, review_id, user=current_user.username)


@router.get(
    "/inspection/draft-template/{import_file_id}",
    response_model=InspectionDraftTemplateResponse,
    status_code=status.HTTP_200_OK,
)
def get_inspection_draft_template(
    import_file_id: int,
    agency: str = "COTECNA",
    cert_type: str = "COC (Certificate of Conformity)",
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    """
    Generates a pre-filled, official draft template for COTECNA / TÜV Rheinland / SGS VoC
    with Egyptian standard specifications and multi-invoice item breakdown.
    """
    return service.generate_inspection_draft_template_service(db, import_file_id, agency, cert_type)


# --- 4.1 DOCUMENT EXTRACTION & 3-WAY RECONCILIATION ENDPOINTS ---
@router.post(
    "/extract-certificate",
    response_model=DocumentExtractResponse,
    status_code=status.HTTP_200_OK,
)
def extract_certificate_data(payload: DocumentExtractRequest, current_user: User = Depends(can_upload)):
    """
    Intelligently extracts fields from China COO, EUR.1, VoC Inspection, Draft B/L, or Invoice.
    """
    return service.extract_document_service(payload)


@router.post(
    "/extract-certificate-file",
    response_model=DocumentExtractResponse,
    status_code=status.HTTP_200_OK,
)
def extract_certificate_file(
    document_type: str = Form(...),
    file: UploadFile = File(...),
    import_file_id: Optional[int] = Form(None),
    current_user: User = Depends(can_upload),
):
    """
    Uploads a certificate file (PDF, Word, TXT) and parses its fields automatically.
    """
    filename, content = _read_upload(file)
    return service.extract_certificate_file_service(
        document_type=document_type, filename=filename, content=content, import_file_id=import_file_id
    )


@router.post(
    "/cross-match-certificates",
    response_model=ThreeWayCrossMatchResponse,
    status_code=status.HTTP_200_OK,
)
def cross_match_certificates(
    payload: ThreeWayCrossMatchRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    """
    Executes deep cross-document reconciliation between COO/EUR.1, Inspection VoC,
    Final Commercial Invoice, Packing List, and Draft B/L.
    """
    return service.cross_match_certificates_service(db, payload)


# --- 5. LEGAL DOCUMENTS & ACID EXPIRY COMPLIANCE (+30 DAYS SAFETY MARGIN) ---
@router.get(
    "/legal-compliance/{import_file_id}",
    response_model=LegalDocsExpiryComplianceResponse,
    status_code=status.HTTP_200_OK,
)
def get_legal_compliance(import_file_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_view)):
    return service.check_acid_and_company_docs_validity_service(db, import_file_id)


# --- 6. COMMERCIAL INVOICE VS. BILL OF LADING CROSS-MATCHING & RECONCILIATION ---
@router.post(
    "/invoice-bl/extract-and-match",
    response_model=InvoiceBLExtractAndMatchResponse,
    status_code=status.HTTP_200_OK,
)
def extract_and_match_invoice_bl(
    payload: InvoiceBLExtractAndMatchRequest, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    """
    Intelligently extracts Commercial Invoice and Draft B/L data,
    executes 10-point cross-comparison matrix, and generates a formal discrepancy/correction report.
    """
    return service.extract_and_match_invoice_bl_service(db, payload)


@router.post(
    "/invoice-bl/extract-files-and-match",
    response_model=InvoiceBLExtractAndMatchResponse,
    status_code=status.HTTP_200_OK,
)
def extract_invoice_bl_files_and_match(
    invoice_file: Optional[UploadFile] = File(None),
    invoice_files: Optional[List[UploadFile]] = File(None),
    bl_file: Optional[UploadFile] = File(None),
    bl_files: Optional[List[UploadFile]] = File(None),
    packing_list_file: Optional[UploadFile] = File(None),
    packing_list_files: Optional[List[UploadFile]] = File(None),
    import_file_id: Optional[int] = Form(None),
    invoice_text: Optional[str] = Form(None),
    bl_text: Optional[str] = Form(None),
    packing_list_text: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_upload),
):
    """
    Accepts uploaded Invoice, Packing List, and/or B/L files (Single or Multi-Page / Multi-File)
    and executes automated multi-page extraction and cross-matching.
    """
    validators.validate_raw_text_length(invoice_text, "invoice_text")
    validators.validate_raw_text_length(bl_text, "bl_text")
    validators.validate_raw_text_length(packing_list_text, "packing_list_text")
    return service.extract_invoice_bl_files_and_match_service(
        db,
        invoices=_read_uploads(invoice_files, invoice_file),
        bls=_read_uploads(bl_files, bl_file),
        packings=_read_uploads(packing_list_files, packing_list_file),
        import_file_id=import_file_id,
        invoice_text=invoice_text,
        bl_text=bl_text,
        packing_list_text=packing_list_text,
    )


@router.post(
    "/invoice-bl/certify-and-sync",
    status_code=status.HTTP_200_OK,
)
def certify_and_sync_invoice_bl(
    payload: InvoiceBLSyncRequest, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    """
    Certifies reconciled invoice and B/L parameters and synchronizes them with the Import File and Downstream Records.
    """
    return service.sync_certified_invoice_bl_to_file_service(db, payload, user=current_user.username)


@router.post(
    "/invoice-bl/sessions",
    response_model=InvoiceBLMatchSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create or update an Invoice vs B/L Match Session (supports Draft or Certified Save)",
)
def create_invoice_bl_session(
    payload: InvoiceBLMatchSessionCreate, db: Session = Depends(get_db), current_user: User = Depends(can_upload)
):
    return service.create_invoice_bl_match_session_service(db, payload, user=current_user.username)


@router.get(
    "/invoice-bl/sessions",
    response_model=List[InvoiceBLMatchSessionResponse],
    summary="List all Invoice vs B/L Match Sessions with optional filters",
)
def list_invoice_bl_sessions(
    response: Response,
    import_file_id: Optional[int] = None,
    is_draft: Optional[bool] = None,
    search: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: Optional[int] = Query(None, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    res = service.list_invoice_bl_match_sessions_service(
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
    "/invoice-bl/sessions/{session_id}",
    response_model=InvoiceBLMatchSessionResponse,
    summary="Get single Invoice vs B/L Match Session by ID",
)
def get_invoice_bl_session(session_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_view)):
    return service.get_invoice_bl_match_session_service(db, session_id)


# --- 7. CENTRAL SHIPMENT DOCUMENTS ARCHIVE & DISCREPANCIES SUMMARY ---
@router.get(
    "/central-archive/{import_file_id}",
    response_model=CentralArchiveResponse,
    status_code=status.HTTP_200_OK,
)
def get_central_archive(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    """
    Retrieves the comprehensive central archive for an Import File:
    approved final invoice, approved final packing list, draft B/L, draft COO/EUR.1,
    draft VoC inspection certificate, all open discrepancies & explicit rectifications,
    and ready-to-send supplier email/WhatsApp notice.
    """
    return service.get_central_archive_service(db, import_file_id)
