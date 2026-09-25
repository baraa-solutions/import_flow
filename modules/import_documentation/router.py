"""
FastAPI Router for Import Documentation & ACI (Phase 3 - BP-014 to BP-019)
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.import_documentation.schemas import *
import modules.import_documentation.service as service

router = APIRouter(prefix="/api/v1/import-documentation", tags=["Import Documentation"], dependencies=[Depends(get_current_user)])


# --- ACID REGISTRATION & TRACKER ENDPOINTS (BP-014) ---
@router.get(
    "/acid/tracker",
    response_model=AcidTrackerSummary,
    status_code=status.HTTP_200_OK,
)
def get_acid_tracker(db: Session = Depends(get_db)):
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
def parse_acid_text(payload: AcidTextParseRequest, db: Session = Depends(get_db)):
    """
    Smart Nafeza Text Parser: Extracts structured ACID fields from raw MTS text notifications
    and optionally computes live discrepancy comparison against the selected import file.
    """
    res = service.parse_acid_text_service(db, payload.raw_text, payload.import_file_id)
    return res


@router.post(
    "/acid/compare",
    status_code=status.HTTP_200_OK,
)
def compare_acid_data(payload: AcidComparisonRequest):
    """
    Compares requested shipment parameters with generated ACID data and returns a discrepancy matrix.
    """
    return service.compare_acid_datasets_service(payload.requested, payload.generated)


@router.post(
    "/acid/templates",
    response_model=AcidRequestTemplateResponse,
    status_code=status.HTTP_200_OK,
)
def generate_acid_templates(payload: dict):
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
    payload: AcidRegistrationCreate, db: Session = Depends(get_db)
):
    return service.create_acid_session_service(db, payload)


@router.get("/acid-sessions", response_model=List[AcidRegistrationResponse])
def list_acid_sessions(
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
):
    items = service.get_all_acid_sessions_service(
        db, include_inactive=include_inactive, search=search, import_file_id=import_file_id, status=status
    )
    if not items:
        return []
    import_files_map = service.get_import_files_map(db, [item.import_file_id for item in items])
    return [service.enrich_acid_response(db, item, import_files_map=import_files_map) for item in items]


@router.get(
    "/acid-sessions/{acid_id}", response_model=AcidRegistrationResponse
)
def get_acid_session(acid_id: int, db: Session = Depends(get_db)):
    item = service.get_acid_session_by_id_service(db, acid_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ACID Registration Session ID {acid_id} not found.",
        )
    return service.enrich_acid_response(db, item)


@router.put(
    "/acid-sessions/{acid_id}", response_model=AcidRegistrationResponse
)
def update_acid_session(
    acid_id: int,
    payload: AcidRegistrationUpdate,
    db: Session = Depends(get_db),
):
    return service.update_acid_session_service(db, acid_id, payload)


@router.delete("/acid-sessions/{acid_id}", status_code=status.HTTP_204_NO_CONTENT)
def soft_delete_acid_session(acid_id: int, db: Session = Depends(get_db)):
    success = service.soft_delete_acid_session_service(db, acid_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ACID Registration Session ID {acid_id} not found.",
        )


@router.patch("/acid-sessions/{acid_id}/restore", response_model=AcidRegistrationResponse)
def restore_acid_session(acid_id: int, db: Session = Depends(get_db)):
    return service.restore_acid_session_service(db, acid_id)


# --- BANKING DOCUMENTS ENDPOINTS (BP-015) ---
@router.post(
    "/banking-documents",
    response_model=BankingDocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_banking_document(
    payload: BankingDocumentCreate, db: Session = Depends(get_db)
):
    return service.create_banking_document_service(db, payload)


@router.get("/banking-documents", response_model=List[BankingDocumentResponse])
def list_banking_documents(import_file_id: Optional[int] = None, db: Session = Depends(get_db)):
    items = service.get_all_banking_documents_service(db, import_file_id=import_file_id)
    import_files_map = service.get_import_files_map(db, [item.import_file_id for item in items])
    return [service.enrich_banking_response(db, item, import_file=import_files_map.get(item.import_file_id)) for item in items]


@router.get("/banking-documents/{bank_doc_id}", response_model=BankingDocumentResponse)
def get_banking_document(bank_doc_id: int, db: Session = Depends(get_db)):
    item = service.get_banking_document_by_id_service(db, bank_doc_id)
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Banking Document ID {bank_doc_id} not found.",
        )
    return service.enrich_banking_response(db, item)


@router.put("/banking-documents/{bank_doc_id}", response_model=BankingDocumentResponse)
def update_banking_document(
    bank_doc_id: int, payload: BankingDocumentUpdate, db: Session = Depends(get_db)
):
    return service.update_banking_document_service(db, bank_doc_id, payload)


@router.post(
    "/banking-documents/{bank_doc_id}/receive",
    response_model=BankingDocumentResponse,
)
def receive_banking_document(
    bank_doc_id: int, payload: BankingDocumentReceive, db: Session = Depends(get_db)
):
    return service.receive_banking_document_service(
        db,
        bank_doc_id,
        form4_number=payload.form4_number,
        received_date=payload.received_date,
        notes=payload.notes,
    )


@router.delete("/banking-documents/{bank_doc_id}")
def delete_banking_document(bank_doc_id: int, db: Session = Depends(get_db)):
    return service.delete_banking_document_service(db, bank_doc_id)


# --- SHIPMENT DOCUMENTS & CARGOX ENDPOINTS (BP-016, BP-017, BP-018) ---
@router.post(
    "/shipment-documents",
    response_model=ShipmentDocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_shipment_document(
    payload: ShipmentDocumentCreate, db: Session = Depends(get_db)
):
    return service.create_shipment_document_service(db, payload)


@router.get("/shipment-documents", response_model=List[ShipmentDocumentResponse])
def list_shipment_documents(import_file_id: Optional[int] = None, db: Session = Depends(get_db)):
    items = service.get_all_shipment_documents_service(db, import_file_id=import_file_id)
    import_files_map = service.get_import_files_map(db, [item.import_file_id for item in items])
    return [service.enrich_shipment_doc_response(db, item, import_file=import_files_map.get(item.import_file_id)) for item in items]


@router.post(
    "/shipment-documents/{doc_id}/cargox-bl",
    response_model=ShipmentDocumentResponse,
)
def update_cargox_and_bl_endorsement(
    doc_id: int,
    cargox_envelope_id: Optional[str] = None,
    endorsement_number: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return service.update_cargox_and_bl_endorsement_service(
        db, doc_id, cargox_envelope_id, endorsement_number
    )


# --- CUSTOMS DECLARATION 46 ENDPOINTS (BP-019) ---
@router.post(
    "/customs-declarations",
    response_model=CustomsDeclarationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_customs_declaration(
    payload: CustomsDeclarationCreate, db: Session = Depends(get_db)
):
    return service.create_customs_declaration_service(db, payload)


# ==============================================================================
# PHASE 6: INTELLIGENT DOCUMENT VERIFICATION & COMPARISON ENDPOINTS
# ==============================================================================
from modules.import_documentation.schemas import (
    POFinalAdjustmentRequest,
    POExtractAndCompareRequest,
    POExtractAndCompareResponse,
    InvoiceBLSyncRequest,
    POReconciliationSessionCreate,
    POReconciliationSessionUpdate,
    POReconciliationSessionResponse,
    DraftBLComparisonRequest,
    DraftBLReviewCreate,
    DraftBLReviewUpdate,
    DraftBLReviewResponse,
    COOComparisonRequest,
    CertificateOfOriginReviewCreate,
    CertificateOfOriginReviewUpdate,
    CertificateOfOriginReviewResponse,
    InspectionComparisonRequest,
    InspectionCertificateReviewCreate,
    InspectionCertificateReviewUpdate,
    InspectionCertificateReviewResponse,
    LegalDocsExpiryComplianceResponse,
)


# --- 1. PO FINAL RECONCILIATION ---
@router.post("/po-reconciliation", status_code=status.HTTP_200_OK)
def reconcile_po_final_adjustments(
    payload: POFinalAdjustmentRequest, db: Session = Depends(get_db)
):
    return service.reconcile_po_final_adjustments_service(db, payload)


@router.post(
    "/po-reconciliation/extract-and-compare",
    response_model=POExtractAndCompareResponse,
    status_code=status.HTTP_200_OK,
)
def extract_and_compare_po_documents(
    payload: POExtractAndCompareRequest, db: Session = Depends(get_db)
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
async def extract_po_reconciliation_files_and_compare(
    invoice_file: Optional[UploadFile] = File(None),
    packing_file: Optional[UploadFile] = File(None),
    import_file_id: Optional[int] = Form(None),
    invoice_text: Optional[str] = Form(None),
    packing_text: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    """
    Accepts uploaded Commercial Invoice and/or Packing List files (PDF, Word, Excel, Text)
    and executes 3-way reconciliation against System PO data.
    """
    inv_raw = invoice_text or ""
    pl_raw = packing_text or ""

    if invoice_file:
        content = await invoice_file.read()
        inv_raw = service.extract_text_from_uploaded_file(invoice_file.filename, content)

    if packing_file:
        content = await packing_file.read()
        pl_raw = service.extract_text_from_uploaded_file(packing_file.filename, content)

    req = POExtractAndCompareRequest(
        import_file_id=import_file_id,
        invoice_raw_text=inv_raw,
        packing_list_raw_text=pl_raw,
    )
    return service.extract_and_compare_po_documents_service(db, req)


# --- PO & PACKING RECONCILIATION SESSIONS ENDPOINTS (BP-016) ---
@router.post(
    "/po-reconciliation/sessions",
    response_model=POReconciliationSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_po_reconciliation_session(
    payload: POReconciliationSessionCreate,
    db: Session = Depends(get_db),
):
    """
    Creates a new PO & Packing List final reconciliation session.
    Strictly prevents duplicate sessions for the same import file.
    """
    return service.create_po_reconciliation_session_service(db, payload)


@router.get(
    "/po-reconciliation/sessions",
    response_model=List[POReconciliationSessionResponse],
    status_code=status.HTTP_200_OK,
)
def get_po_reconciliation_sessions(
    import_file_id: Optional[int] = None,
    overall_status: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """
    Lists saved PO & Packing List final reconciliation sessions with optional filters.
    """
    return service.get_po_reconciliation_sessions_service(
        db, import_file_id=import_file_id, overall_status=overall_status, search=search
    )


@router.get(
    "/po-reconciliation/sessions/{session_id}",
    response_model=POReconciliationSessionResponse,
    status_code=status.HTTP_200_OK,
)
def get_po_reconciliation_session_by_id(
    session_id: int,
    db: Session = Depends(get_db),
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
):
    """
    Updates an existing PO & Packing List final reconciliation session.
    """
    return service.update_po_reconciliation_session_service(db, session_id, payload)


@router.delete(
    "/po-reconciliation/sessions/{session_id}",
    status_code=status.HTTP_200_OK,
)
def delete_po_reconciliation_session(
    session_id: int,
    db: Session = Depends(get_db),
):
    """
    Soft-deletes a PO & Packing List final reconciliation session.
    """
    return service.delete_po_reconciliation_session_service(db, session_id)




# --- 2. DRAFT BILL OF LADING (B/L) ENDPOINTS ---
@router.post("/draft-bl/extract-file", status_code=status.HTTP_200_OK)
async def extract_draft_bl_from_file(
    file: UploadFile = File(...),
    import_file_id: Optional[int] = Form(None),
    db: Session = Depends(get_db),
):
    """
    Extracts raw text from uploaded PDF, Word, Excel, or Text file, extracts B/L fields,
    and optionally executes comparison against the active import file.
    """
    content_bytes = await file.read()
    raw_text, spatial_boxes = service.extract_text_and_boxes_from_uploaded_file(file.filename, content_bytes)
    extracted_fields = service.parse_draft_bl_raw_text(raw_text, spatial_boxes=spatial_boxes)


    comp_result = None
    if import_file_id:
        comp_req = DraftBLComparisonRequest(
            import_file_id=import_file_id,
            draft_source="FILE_UPLOAD",
            raw_draft_text=raw_text,
            draft_fields=extracted_fields,
        )
        comp_result = service.compare_draft_bl_service(db, comp_req)
    guardrails = extracted_fields.get("_guardrails", {})
    return {
        "filename": file.filename,
        "raw_text": raw_text,
        "extracted_fields": extracted_fields,
        "extraction_status": guardrails.get("extraction_status", "EXTRACTION_COMPLETE"),
        "missing_critical_fields": guardrails.get("missing_critical_fields", []),
        "safety_warning": guardrails.get("safety_warning"),
        "comparison_result": comp_result,
    }


@router.post("/draft-bl/compare", status_code=status.HTTP_200_OK)
def compare_draft_bl(
    payload: DraftBLComparisonRequest, db: Session = Depends(get_db)
):
    return service.compare_draft_bl_service(db, payload)


@router.post(
    "/draft-bl",
    response_model=DraftBLReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_draft_bl_review(
    payload: DraftBLReviewCreate, db: Session = Depends(get_db)
):
    return service.create_draft_bl_review_service(db, payload)


@router.get("/draft-bl", response_model=List[DraftBLReviewResponse])
def list_draft_bl_reviews(
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    is_draft: Optional[bool] = None,
    db: Session = Depends(get_db),
):
    return service.get_draft_bl_reviews_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        is_draft=is_draft,
    )


@router.get("/draft-bl/{review_id}", response_model=DraftBLReviewResponse)
def get_draft_bl_review(review_id: int, db: Session = Depends(get_db)):
    item = service.get_draft_bl_review_by_id_service(db, review_id, include_inactive=True)
    if not item:
        raise HTTPException(status_code=404, detail="Draft B/L Review not found")
    return item


@router.delete("/draft-bl/{review_id}", status_code=status.HTTP_200_OK)
def delete_draft_bl_review(review_id: int, db: Session = Depends(get_db)):
    return service.delete_draft_bl_review_service(db, review_id)


@router.put("/draft-bl/{review_id}", response_model=DraftBLReviewResponse)
def update_draft_bl_review(
    review_id: int, payload: DraftBLReviewUpdate, db: Session = Depends(get_db)
):
    return service.update_draft_bl_review_service(db, review_id, payload)


@router.put("/draft-bl/{review_id}/checklist", response_model=DraftBLReviewResponse)
def update_draft_bl_checklist(
    review_id: int,
    checklist_items: List[DraftBLChecklistItem],
    reviewer_name: str = "Kamal",
    db: Session = Depends(get_db),
):
    return service.update_draft_bl_checklist_service(
        db, review_id, checklist_items, reviewer_name=reviewer_name
    )


@router.post("/draft-bl/dual-approval", response_model=DraftBLReviewResponse)
def process_draft_bl_dual_approval(
    payload: DualApprovalRequest, db: Session = Depends(get_db)
):
    return service.process_dual_approval_service(db, payload)


@router.post("/draft-bl/new-version", response_model=DraftBLReviewResponse, status_code=status.HTTP_201_CREATED)
def create_new_draft_version(
    payload: NewDraftVersionRequest, db: Session = Depends(get_db)
):
    return service.create_new_draft_version_service(db, payload)


@router.post("/draft-bl/{review_id}/approve", response_model=DraftBLReviewResponse)
def approve_draft_bl(
    review_id: int, approved_by: str = "Kamal", db: Session = Depends(get_db)
):
    return service.approve_draft_bl_service(db, review_id, approved_by=approved_by)


# --- 3. CERTIFICATE OF ORIGIN (COO / EUR.1) ENDPOINTS ---
@router.post("/coo/compare", status_code=status.HTTP_200_OK)
def compare_coo(payload: COOComparisonRequest, db: Session = Depends(get_db)):
    return service.compare_coo_service(db, payload)


@router.post(
    "/coo",
    response_model=CertificateOfOriginReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_coo_review(
    payload: CertificateOfOriginReviewCreate, db: Session = Depends(get_db)
):
    return service.create_coo_review_service(db, payload)


@router.get("/coo", response_model=List[CertificateOfOriginReviewResponse])
def list_coo_reviews(
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    is_draft: Optional[bool] = None,
    db: Session = Depends(get_db),
):
    return service.get_coo_reviews_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
        is_draft=is_draft,
    )


@router.put("/coo/{review_id}", response_model=CertificateOfOriginReviewResponse)
def update_coo_review(
    review_id: int, payload: CertificateOfOriginReviewUpdate, db: Session = Depends(get_db)
):
    return service.update_coo_review_service(db, review_id, payload)


@router.delete("/coo/{review_id}", status_code=status.HTTP_200_OK)
def delete_coo_review(review_id: int, db: Session = Depends(get_db)):
    return service.delete_coo_review_service(db, review_id)


@router.get(
    "/coo/draft-template/{import_file_id}",
    response_model=COODraftTemplateResponse,
    status_code=status.HTTP_200_OK,
)
def get_coo_draft_template(
    import_file_id: int,
    cert_type: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """
    Generates a pre-filled, official draft template for China CCPIT COO or EUR.1 Movement Certificate
    from Import File, Final Invoice, Packing List, and B/L snapshots.
    """
    return service.generate_coo_draft_template_service(db, import_file_id, cert_type)


# --- 4. INSPECTION CERTIFICATE ENDPOINTS ---
@router.post("/inspection/compare", status_code=status.HTTP_200_OK)
def compare_inspection(
    payload: InspectionComparisonRequest, db: Session = Depends(get_db)
):
    return service.compare_inspection_cert_service(db, payload)


@router.post(
    "/inspection",
    response_model=InspectionCertificateReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_inspection_review(
    payload: InspectionCertificateReviewCreate, db: Session = Depends(get_db)
):
    return service.create_inspection_review_service(db, payload)


@router.get("/inspection", response_model=List[InspectionCertificateReviewResponse])
def list_inspection_reviews(
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return service.get_inspection_reviews_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status=status,
        search=search,
    )


@router.put("/inspection/{review_id}", response_model=InspectionCertificateReviewResponse)
def update_inspection_review(
    review_id: int, payload: InspectionCertificateReviewUpdate, db: Session = Depends(get_db)
):
    return service.update_inspection_review_service(db, review_id, payload)


@router.delete("/inspection/{review_id}", status_code=status.HTTP_200_OK)
def delete_inspection_review(review_id: int, db: Session = Depends(get_db)):
    return service.delete_inspection_review_service(db, review_id)


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
def extract_certificate_data(
    payload: DocumentExtractRequest,
):
    """
    Intelligently extracts fields from China COO, EUR.1, VoC Inspection, Draft B/L, or Invoice.
    """
    return service.extract_document_service(payload)


@router.post(
    "/extract-certificate-file",
    response_model=DocumentExtractResponse,
    status_code=status.HTTP_200_OK,
)
async def extract_certificate_file(
    document_type: str = Form(...),
    file: UploadFile = File(...),
    import_file_id: Optional[int] = Form(None),
):
    """
    Uploads a certificate file (PDF, Word, TXT) and parses its fields automatically.
    """
    content = await file.read()
    raw_text = service.extract_text_from_uploaded_file(file.filename, content)
    req = DocumentExtractRequest(
        document_type=document_type,
        raw_text=raw_text,
        import_file_id=import_file_id,
    )
    return service.extract_document_service(req)


@router.post(
    "/cross-match-certificates",
    response_model=ThreeWayCrossMatchResponse,
    status_code=status.HTTP_200_OK,
)
def cross_match_certificates(
    payload: ThreeWayCrossMatchRequest,
    db: Session = Depends(get_db),
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
def get_legal_compliance(import_file_id: int, db: Session = Depends(get_db)):
    return service.check_acid_and_company_docs_validity_service(db, import_file_id)


# --- 6. COMMERCIAL INVOICE VS. BILL OF LADING CROSS-MATCHING & RECONCILIATION ---
@router.post(
    "/invoice-bl/extract-and-match",
    response_model=InvoiceBLExtractAndMatchResponse,
    status_code=status.HTTP_200_OK,
)
def extract_and_match_invoice_bl(
    payload: InvoiceBLExtractAndMatchRequest, db: Session = Depends(get_db)
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
async def extract_invoice_bl_files_and_match(
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
):
    """
    Accepts uploaded Invoice, Packing List, and/or B/L files (Single or Multi-Page / Multi-File)
    and executes automated multi-page extraction and cross-matching.
    """
    inv_raw_parts = [invoice_text] if invoice_text else []
    bl_raw_parts = [bl_text] if bl_text else []
    pl_raw_parts = [packing_list_text] if packing_list_text else []

    all_inv_files = []
    if invoice_files:
        all_inv_files.extend(invoice_files)
    if invoice_file and invoice_file not in all_inv_files:
        all_inv_files.append(invoice_file)

    for idx, f in enumerate(all_inv_files):
        content = await f.read()
        extracted, _ = service.extract_text_and_boxes_from_uploaded_file(f.filename, content)
        if extracted:
            inv_raw_parts.append(f"--- INVOICE FILE {idx+1}: {f.filename} ---\n{extracted}")

    all_bl_files = []
    if bl_files:
        all_bl_files.extend(bl_files)
    if bl_file and bl_file not in all_bl_files:
        all_bl_files.append(bl_file)

    for idx, f in enumerate(all_bl_files):
        content = await f.read()
        extracted, _ = service.extract_text_and_boxes_from_uploaded_file(f.filename, content)
        if extracted:
            bl_raw_parts.append(f"--- BL FILE {idx+1}: {f.filename} ---\n{extracted}")

    all_pl_files = []
    if packing_list_files:
        all_pl_files.extend(packing_list_files)
    if packing_list_file and packing_list_file not in all_pl_files:
        all_pl_files.append(packing_list_file)

    for idx, f in enumerate(all_pl_files):
        content = await f.read()
        extracted, _ = service.extract_text_and_boxes_from_uploaded_file(f.filename, content)
        if extracted:
            pl_raw_parts.append(f"--- PACKING LIST FILE {idx+1}: {f.filename} ---\n{extracted}")

    inv_raw = "\n\n".join(inv_raw_parts)
    bl_raw = "\n\n".join(bl_raw_parts)
    pl_raw = "\n\n".join(pl_raw_parts)

    req = InvoiceBLExtractAndMatchRequest(
        import_file_id=import_file_id,
        invoice_raw_text=inv_raw,
        bl_raw_text=bl_raw,
        packing_list_raw_text=pl_raw,
    )
    return service.extract_and_match_invoice_bl_service(db, req)



@router.post(
    "/invoice-bl/certify-and-sync",
    status_code=status.HTTP_200_OK,
)
def certify_and_sync_invoice_bl(
    payload: InvoiceBLSyncRequest, db: Session = Depends(get_db)
):
    """
    Certifies reconciled invoice and B/L parameters and synchronizes them with the Import File and Downstream Records.
    """
    return service.sync_certified_invoice_bl_to_file_service(db, payload)


@router.post(
    "/invoice-bl/sessions",
    response_model=InvoiceBLMatchSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create or update an Invoice vs B/L Match Session (supports Draft or Certified Save)",
)
def create_invoice_bl_session(
    payload: InvoiceBLMatchSessionCreate, db: Session = Depends(get_db)
):
    return service.create_invoice_bl_match_session_service(db, payload)


@router.get(
    "/invoice-bl/sessions",
    response_model=List[InvoiceBLMatchSessionResponse],
    summary="List all Invoice vs B/L Match Sessions with optional filters",
)
def list_invoice_bl_sessions(
    import_file_id: Optional[int] = None,
    is_draft: Optional[bool] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
):
    return service.list_invoice_bl_match_sessions_service(
        db, import_file_id=import_file_id, is_draft=is_draft, search=search
    )


@router.get(
    "/invoice-bl/sessions/{session_id}",
    response_model=InvoiceBLMatchSessionResponse,
    summary="Get single Invoice vs B/L Match Session by ID",
)
def get_invoice_bl_session(session_id: int, db: Session = Depends(get_db)):
    session = service.get_invoice_bl_match_session_service(db, session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invoice B/L Match Session not found.",
        )
    return session



# --- 7. CENTRAL SHIPMENT DOCUMENTS ARCHIVE & DISCREPANCIES SUMMARY ---
@router.get(
    "/central-archive/{import_file_id}",
    response_model=CentralArchiveResponse,
    status_code=status.HTTP_200_OK,
)
def get_central_archive(
    import_file_id: int,
    db: Session = Depends(get_db),
):
    """
    Retrieves the comprehensive central archive for an Import File:
    approved final invoice, approved final packing list, draft B/L, draft COO/EUR.1,
    draft VoC inspection certificate, all open discrepancies & explicit rectifications,
    and ready-to-send supplier email/WhatsApp notice.
    """
    return service.get_central_archive_service(db, import_file_id)


