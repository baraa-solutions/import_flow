"""
Smart Document Upload — FastAPI Router
Universal file upload & AI extraction endpoint for all ImportFlow modules.
"""

from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.smart_document_upload.schemas import SmartUploadResponse, UploadSessionResponse
from modules.smart_document_upload.validators import (
    validate_module_name,
    validate_upload_file,
    validate_file_size,
    SUPPORTED_MODULES,
)
import modules.smart_document_upload.service as service

router = APIRouter(
    prefix="/api/v1/smart-upload",
    tags=["Smart Document Upload"],
    dependencies=[Depends(get_current_user)],
)


@router.post(
    "/upload",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Upload a document and extract fields (module_name passed in form data)",
)
async def upload_document_form(
    file: UploadFile = File(..., description="PDF, Word, or image file"),
    module_name: str = Form("clearance-quotation", description="Module name"),
    save_session: bool = Form(True, description="Save session record"),
    db: Session = Depends(get_db),
):
    validate_module_name(module_name)
    file_type = validate_upload_file(file)
    content_bytes = await file.read()
    validate_file_size(content_bytes, file.filename or "unknown")
    result = service.parse_uploaded_document(
        db=db,
        module_name=module_name,
        filename=file.filename or "unknown",
        file_type=file_type,
        content_bytes=content_bytes,
        save_session=save_session,
    )
    return SmartUploadResponse(**result)


@router.post(
    "/upload/{module}",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Upload a document with module in path",
)
async def upload_document_path(
    module: str,
    file: UploadFile = File(..., description="PDF, Word, or image file"),
    save_session: bool = Form(True, description="Save session record"),
    db: Session = Depends(get_db),
):
    validate_module_name(module)
    file_type = validate_upload_file(file)
    content_bytes = await file.read()
    validate_file_size(content_bytes, file.filename or "unknown")
    result = service.parse_uploaded_document(
        db=db,
        module_name=module,
        filename=file.filename or "unknown",
        file_type=file_type,
        content_bytes=content_bytes,
        save_session=save_session,
    )
    return SmartUploadResponse(**result)


@router.post(
    "/parse/{module}",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Upload a document and extract fields for a specific module",
)
async def parse_document_for_module(
    module: str,
    file: UploadFile = File(..., description="PDF, Word (.docx), or Excel (.xlsx) file"),
    save_session: bool = Form(True, description="Save this upload as a session record"),
    db: Session = Depends(get_db),
):
    """
    Universal smart document upload endpoint.

    Accepts a PDF, Word, or Excel file and extracts structured data for the specified module.

    **Supported modules:**
    - `purchase-order` — Commercial Invoice / PO document
    - `import-file` — Commercial Invoice to pre-fill Import File
    - `cargo-shipping` — Bill of Lading (B/L)
    - `customs-clearance` — Customs Declaration / Bayaan
    - `freight-quotation` — Freight Rate Quote
    - `freight-booking` — Booking Confirmation
    - `customs-consultation` — Invoice for HS code consultation
    - `coo-certificate` — Certificate of Origin
    - `inspection-certificate` — Inspection / Quality Certificate
    - `financial-document` — Financial Invoice / Payment document
    - `warehouse-receiving` — Delivery Note
    - `demurrage` — Demurrage / Detention Invoice
    """
    # Validate module
    validate_module_name(module)

    # Validate file type
    file_type = validate_upload_file(file)

    # Read file content
    content_bytes = await file.read()

    # Validate file size
    validate_file_size(content_bytes, file.filename or "unknown")

    # Parse & extract
    result = service.parse_uploaded_document(
        db=db,
        module_name=module,
        filename=file.filename or "unknown",
        file_type=file_type,
        content_bytes=content_bytes,
        save_session=save_session,
    )

    return SmartUploadResponse(**result)


@router.post(
    "/parse-multi/{module}",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Upload multiple documents (e.g., Commercial Invoice + Packing List) and merge extracted fields",
)
async def parse_multiple_documents_for_module(
    module: str,
    files: List[UploadFile] = File(..., description="List of PDF, Word (.docx), or Excel (.xlsx) files"),
    save_session: bool = Form(True, description="Save this multi-upload as a session record"),
    db: Session = Depends(get_db),
):
    """
    Multi-document smart upload endpoint.
    Accepts multiple files (e.g. Commercial Invoice + Packing List) and combines extracted text into a unified model.
    """
    validate_module_name(module)
    files_data = []

    for f in files:
        file_type = validate_upload_file(f)
        content_bytes = await f.read()
        validate_file_size(content_bytes, f.filename or "unknown")
        files_data.append((f.filename or "unknown", file_type, content_bytes))

    result = service.parse_multiple_uploaded_documents(
        db=db,
        module_name=module,
        files_data=files_data,
        save_session=save_session,
    )
    return SmartUploadResponse(**result)


# ─────────────────────────────────────────────────────────────────────────────
# Raw Text Parse Endpoint — Universal
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/parse-text/{module}",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Parse raw text directly to extract structured entity or document fields",
)
async def parse_text_for_module(
    module: str,
    raw_text: str = Form(..., description="Raw text block pasted by the user"),
    save_session: bool = Form(False, description="Save parse session"),
    db: Session = Depends(get_db),
):
    """
    Direct raw text parsing endpoint.
    Accepts pasted contact info, business cards, email signatures, or address blocks
    and extracts structured entity fields (Company, Supplier, Partner, Bank).
    """
    validate_module_name(module)
    result = service.parse_raw_text_directly(
        db=db,
        module_name=module,
        raw_text=raw_text,
        save_session=save_session,
    )
    return SmartUploadResponse(**result)


# ─────────────────────────────────────────────────────────────────────────────
# Convenience Module-Specific Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/parse/purchase-order",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Extract Purchase Order fields from uploaded document",
)
async def parse_purchase_order(
    file: UploadFile = File(...),
    save_session: bool = Form(True),
    db: Session = Depends(get_db),
):
    """Upload a Commercial Invoice or PO document to auto-fill Purchase Order form."""
    file_type = validate_upload_file(file)
    content_bytes = await file.read()
    validate_file_size(content_bytes, file.filename or "unknown")
    result = service.parse_uploaded_document(
        db=db, module_name="purchase-order", filename=file.filename or "unknown",
        file_type=file_type, content_bytes=content_bytes, save_session=save_session,
    )
    return SmartUploadResponse(**result)


@router.post(
    "/parse/cargo-shipping",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Extract Bill of Lading fields from uploaded document",
)
async def parse_cargo_shipping(
    file: UploadFile = File(...),
    save_session: bool = Form(True),
    db: Session = Depends(get_db),
):
    """Upload a Bill of Lading PDF to auto-fill Cargo Shipping record."""
    file_type = validate_upload_file(file)
    content_bytes = await file.read()
    validate_file_size(content_bytes, file.filename or "unknown")
    result = service.parse_uploaded_document(
        db=db, module_name="cargo-shipping", filename=file.filename or "unknown",
        file_type=file_type, content_bytes=content_bytes, save_session=save_session,
    )
    return SmartUploadResponse(**result)


@router.post(
    "/parse/customs-clearance",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Extract Customs Declaration fields from uploaded document",
)
async def parse_customs_clearance(
    file: UploadFile = File(...),
    save_session: bool = Form(True),
    db: Session = Depends(get_db),
):
    """Upload a Customs Declaration (بيان جمركي) PDF to auto-fill Customs Clearance record."""
    file_type = validate_upload_file(file)
    content_bytes = await file.read()
    validate_file_size(content_bytes, file.filename or "unknown")
    result = service.parse_uploaded_document(
        db=db, module_name="customs-clearance", filename=file.filename or "unknown",
        file_type=file_type, content_bytes=content_bytes, save_session=save_session,
    )
    return SmartUploadResponse(**result)


@router.post(
    "/parse/import-file",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Extract Import File fields from Commercial Invoice",
)
async def parse_import_file(
    file: UploadFile = File(...),
    save_session: bool = Form(True),
    db: Session = Depends(get_db),
):
    """Upload a Commercial Invoice to auto-fill Import File record."""
    file_type = validate_upload_file(file)
    content_bytes = await file.read()
    validate_file_size(content_bytes, file.filename or "unknown")
    result = service.parse_uploaded_document(
        db=db, module_name="import-file", filename=file.filename or "unknown",
        file_type=file_type, content_bytes=content_bytes, save_session=save_session,
    )
    return SmartUploadResponse(**result)


@router.post(
    "/parse/coo-certificate",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Extract Certificate of Origin fields",
)
async def parse_coo_certificate(
    file: UploadFile = File(...),
    save_session: bool = Form(True),
    db: Session = Depends(get_db),
):
    """Upload a Certificate of Origin to auto-fill COO Review fields."""
    file_type = validate_upload_file(file)
    content_bytes = await file.read()
    validate_file_size(content_bytes, file.filename or "unknown")
    result = service.parse_uploaded_document(
        db=db, module_name="coo-certificate", filename=file.filename or "unknown",
        file_type=file_type, content_bytes=content_bytes, save_session=save_session,
    )
    return SmartUploadResponse(**result)


@router.post(
    "/parse/inspection-certificate",
    response_model=SmartUploadResponse,
    status_code=status.HTTP_200_OK,
    summary="Extract Inspection Certificate fields",
)
async def parse_inspection_certificate(
    file: UploadFile = File(...),
    save_session: bool = Form(True),
    db: Session = Depends(get_db),
):
    """Upload an Inspection Certificate to auto-fill Inspection Review fields."""
    file_type = validate_upload_file(file)
    content_bytes = await file.read()
    validate_file_size(content_bytes, file.filename or "unknown")
    result = service.parse_uploaded_document(
        db=db, module_name="inspection-certificate", filename=file.filename or "unknown",
        file_type=file_type, content_bytes=content_bytes, save_session=save_session,
    )
    return SmartUploadResponse(**result)


# ─────────────────────────────────────────────────────────────────────────────
# Session History Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@router.get(
    "/sessions",
    response_model=List[UploadSessionResponse],
    status_code=status.HTTP_200_OK,
    summary="List all upload sessions",
)
def list_upload_sessions(
    module_name: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    """List smart upload sessions, optionally filtered by module name."""
    sessions = service.get_upload_sessions_service(db, module_name=module_name, skip=skip, limit=limit)
    result = []
    for s in sessions:
        d = {
            "id": s.id,
            "session_ref": s.session_ref,
            "module_name": s.module_name,
            "filename": s.filename,
            "file_type": s.file_type,
            "file_size_bytes": s.file_size_bytes,
            "extraction_status": s.extraction_status,
            "confidence_score": s.confidence_score or 0.0,
            "extracted_fields": s.get_extracted_fields(),
            "missing_fields": s.get_missing_fields(),
            "extraction_notes": s.extraction_notes,
            "linked_record_id": s.linked_record_id,
            "linked_module": s.linked_module,
            "created_at": s.created_at,
        }
        result.append(UploadSessionResponse(**d))
    return result


@router.get(
    "/sessions/{session_id}",
    response_model=UploadSessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Get a specific upload session by ID",
)
def get_upload_session(session_id: int, db: Session = Depends(get_db)):
    s = service.get_upload_session_by_id_service(db, session_id)
    if not s:
        raise HTTPException(status_code=404, detail=f"Upload session {session_id} not found.")
    return UploadSessionResponse(
        id=s.id,
        session_ref=s.session_ref,
        module_name=s.module_name,
        filename=s.filename,
        file_type=s.file_type,
        file_size_bytes=s.file_size_bytes,
        extraction_status=s.extraction_status,
        confidence_score=s.confidence_score or 0.0,
        extracted_fields=s.get_extracted_fields(),
        missing_fields=s.get_missing_fields(),
        extraction_notes=s.extraction_notes,
        linked_record_id=s.linked_record_id,
        linked_module=s.linked_module,
        created_at=s.created_at,
    )


@router.delete(
    "/sessions/{session_id}",
    status_code=status.HTTP_200_OK,
    summary="Soft-delete an upload session",
)
def delete_upload_session(session_id: int, db: Session = Depends(get_db)):
    deleted = service.soft_delete_upload_session_service(db, session_id)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"Upload session {session_id} not found.")
    return {"message": f"Upload session {session_id} deleted successfully."}


# ─────────────────────────────────────────────────────────────────────────────
# Info Endpoint
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/modules", status_code=status.HTTP_200_OK, summary="List supported modules")
def list_supported_modules():
    """Returns list of all supported modules for smart document upload."""
    return {"supported_modules": sorted(SUPPORTED_MODULES)}


# ─────────────────────────────────────────────────────────────────────────────
# AI Commercial Invoice & Bill of Lading Specialized Endpoints (AI-INV-010)
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/extract/commercial-invoice",
    status_code=status.HTTP_200_OK,
    summary="Extract Commercial Invoice header, totals, and line items",
)
async def extract_commercial_invoice_endpoint(
    file: Optional[UploadFile] = File(None, description="Invoice file (PDF, Excel, Word)"),
    raw_text: Optional[str] = Form(None, description="Pasted invoice text"),
    db: Session = Depends(get_db),
):
    """Extracts structured commercial invoice data with line items from file or text."""
    filename = "invoice.txt"
    content_bytes = None
    if file:
        filename = file.filename or "invoice.pdf"
        content_bytes = await file.read()

    return service.extract_commercial_invoice_service(
        filename=filename,
        content_bytes=content_bytes,
        raw_text=raw_text,
        db=db,
    )


@router.post(
    "/extract/bill-of-lading",
    status_code=status.HTTP_200_OK,
    summary="Extract Bill of Lading (Ocean / Air) and containers list",
)
async def extract_bill_of_lading_endpoint(
    file: Optional[UploadFile] = File(None, description="Bill of Lading or AWB file"),
    raw_text: Optional[str] = Form(None, description="Pasted B/L text"),
    db: Session = Depends(get_db),
):
    """Extracts structured Bill of Lading / Air Waybill data with container details."""
    filename = "bill_of_lading.txt"
    content_bytes = None
    if file:
        filename = file.filename or "bill_of_lading.pdf"
        content_bytes = await file.read()

    return service.extract_bill_of_lading_service(
        filename=filename,
        content_bytes=content_bytes,
        raw_text=raw_text,
        db=db,
    )


@router.post(
    "/cross-check/invoice-vs-bl",
    status_code=status.HTTP_200_OK,
    summary="Run 10-point cross-comparison audit between Invoice and B/L",
)
def cross_check_invoice_vs_bl_endpoint(
    payload: dict,
):
    """
    Compares commercial invoice data against B/L data.
    Validates ACID, Importer Tax ID, weight variance, Incoterms, and ports.
    """
    invoice_data = payload.get("invoice_data") or {}
    bl_data = payload.get("bl_data") or {}
    system_data = payload.get("system_data") or {}
    packing_list_data = payload.get("packing_list_data") or {}
    tolerance = float(payload.get("weight_tolerance_pct", 3.0))

    return service.cross_check_invoice_and_bl_service(
        invoice_data=invoice_data,
        bl_data=bl_data,
        weight_tolerance_pct=tolerance,
        system_data=system_data,
        packing_list_data=packing_list_data,
    )


@router.post(
    "/apply/commercial-invoice",
    status_code=status.HTTP_200_OK,
    summary="Apply extracted invoice data to an ImportFile",
)
def apply_extracted_invoice_endpoint(
    payload: dict,
    db: Session = Depends(get_db),
):
    import_file_id = payload.get("import_file_id")
    invoice_data = payload.get("invoice_data") or {}
    return service.apply_extracted_invoice_service(
        db=db,
        import_file_id=import_file_id,
        invoice_data=invoice_data,
    )


@router.post(
    "/apply/bill-of-lading",
    status_code=status.HTTP_200_OK,
    summary="Apply extracted B/L data and containers to CargoShipping",
)
def apply_extracted_bl_endpoint(
    payload: dict,
    db: Session = Depends(get_db),
):
    import_file_id = payload.get("import_file_id")
    bl_data = payload.get("bl_data") or {}
    return service.apply_extracted_bl_service(
        db=db,
        import_file_id=import_file_id,
        bl_data=bl_data,
    )

