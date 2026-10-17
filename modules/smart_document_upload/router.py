"""
Smart Document Upload — FastAPI Router
Universal file upload & AI extraction endpoint for all ImportFlow modules.
"""

from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from modules.auth.permissions import has_user_permission, require_permission
from modules.auth.router import get_current_user
from modules.users.model import User
from sqlalchemy.orm import Session

from database.database import get_db
from modules.smart_document_upload.schemas import (
    ApplyBLRequest,
    ApplyInvoiceRequest,
    CrossCheckRequest,
    SmartUploadResponse,
    UploadSessionResponse,
)
from modules.smart_document_upload.validators import (
    read_validated_upload_sync,
    stored_filename,
    validate_files_count,
    validate_module_name,
    validate_raw_text,
    SUPPORTED_MODULES,
)

# Lead decision (03b review): smart upload is used from several screens, so extraction / cross-check accept ANY of
# the write codes of those screens; the session history also accepts import_documentation.view. /apply/* keep the
# target module's write code, session delete needs import_documentation.upload.
UPLOAD = "import_documentation.upload"
VIEW = "import_documentation.view"
MASTER_DATA_EDIT = "master_data.edit"

OPERATIONAL_EXTRACT_CODES = (
    UPLOAD,
    "quotations.manage",
    "customs_consultation.manage",
    "shipping_scenarios.manage",
    "purchase_orders.edit",
)

ALL_EXTRACT_CODES = (
    *OPERATIONAL_EXTRACT_CODES,
    MASTER_DATA_EDIT,
)

MASTER_DATA_MODULES = {
    "master-data-entity",
    "supplier-entity",
    "importer-entity",
    "import-company-entity",
    "company-entity",
    "partner-entity",
    "bank-entity",
    "shipping-line-entity",
    "customs-broker-entity",
    "freight-forwarder-entity",
    "inland-transport-entity",
    "inspection-agency-entity",
    "insurance-company-entity",
    "supplier",
    "importer",
    "import-company",
    "partner",
    "bank",
    "shipping-line",
    "customs-broker",
    "freight-forwarder",
    "inland-transport",
    "inspection-agency",
    "insurance-company",
}


def require_any_permission(*codes: str):
    """Dependency: the authenticated user (``get_current_user``: token / dev bypass + forced password change)
    must hold at least one of ``codes``; 403 otherwise."""
    def dependency(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> User:
        if getattr(current_user, "is_admin", False):
            return current_user
        if not any(has_user_permission(db, current_user, code) for code in codes):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. One of the permissions {', '.join(codes)} is required.",
            )
        return current_user

    return dependency


def check_module_extract_permission(db: Session, current_user: User, module_name: str) -> None:
    """Enforces that master data entities require 'master_data.edit', while
    operational documents (invoices, B/L, etc.) require operational upload permissions."""
    if getattr(current_user, "is_admin", False):
        return
    norm = module_name.strip().lower()
    if norm in MASTER_DATA_MODULES:
        if not has_user_permission(db, current_user, MASTER_DATA_EDIT):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Permission '{MASTER_DATA_EDIT}' is required to extract master data entities.",
            )
    else:
        if not any(has_user_permission(db, current_user, code) for code in OPERATIONAL_EXTRACT_CODES):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. One of the permissions {', '.join(OPERATIONAL_EXTRACT_CODES)} is required for module '{module_name}'.",
            )


EXTRACT = require_any_permission(*ALL_EXTRACT_CODES)
OPERATIONAL_EXTRACT = require_any_permission(*OPERATIONAL_EXTRACT_CODES)
SESSIONS_READ = require_any_permission(VIEW, *OPERATIONAL_EXTRACT_CODES)

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
def upload_document_form(
    file: UploadFile = File(..., description="PDF, Word, or image file"),
    module_name: str = Form("clearance-quotation", description="Module name"),
    save_session: bool = Form(True, description="Save session record"),
    db: Session = Depends(get_db),
    current_user: User = Depends(EXTRACT),
):
    validate_module_name(module_name)
    check_module_extract_permission(db, current_user, module_name)
    file_type, content_bytes = read_validated_upload_sync(file)
    result = service.parse_uploaded_document(
        db=db,
        module_name=module_name,
        filename=stored_filename(file.filename),
        created_by=current_user.user_id,
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
def upload_document_path(
    module: str,
    file: UploadFile = File(..., description="PDF, Word, or image file"),
    save_session: bool = Form(True, description="Save session record"),
    db: Session = Depends(get_db),
    current_user: User = Depends(EXTRACT),
):
    validate_module_name(module)
    check_module_extract_permission(db, current_user, module)
    file_type, content_bytes = read_validated_upload_sync(file)
    result = service.parse_uploaded_document(
        db=db,
        module_name=module,
        filename=stored_filename(file.filename),
        created_by=current_user.user_id,
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
def parse_document_for_module(
    module: str,
    file: UploadFile = File(..., description="PDF, Word (.docx), or Excel (.xlsx) file"),
    save_session: bool = Form(True, description="Save this upload as a session record"),
    db: Session = Depends(get_db),
    current_user: User = Depends(EXTRACT),
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
    check_module_extract_permission(db, current_user, module)

    # Validate type, bounded read (413 above 20 MB), size + magic bytes
    file_type, content_bytes = read_validated_upload_sync(file)

    # Parse & extract
    result = service.parse_uploaded_document(
        db=db,
        module_name=module,
        filename=stored_filename(file.filename),
        created_by=current_user.user_id,
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
def parse_multiple_documents_for_module(
    module: str,
    files: List[UploadFile] = File(..., description="List of PDF, Word (.docx), or Excel (.xlsx) files"),
    save_session: bool = Form(True, description="Save this multi-upload as a session record"),
    db: Session = Depends(get_db),
    current_user: User = Depends(EXTRACT),
):
    """
    Multi-document smart upload endpoint.
    Accepts multiple files (e.g. Commercial Invoice + Packing List) and combines extracted text into a unified model.
    """
    validate_module_name(module)
    check_module_extract_permission(db, current_user, module)
    validate_files_count(files)
    files_data = []

    for f in files:
        file_type, content_bytes = read_validated_upload_sync(f)
        files_data.append((stored_filename(f.filename), file_type, content_bytes))

    result = service.parse_multiple_uploaded_documents(
        db=db,
        module_name=module,
        files_data=files_data,
        save_session=save_session,
        created_by=current_user.user_id,
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
def parse_text_for_module(
    module: str,
    raw_text: str = Form(..., description="Raw text block pasted by the user"),
    save_session: bool = Form(False, description="Save parse session"),
    db: Session = Depends(get_db),
    current_user: User = Depends(EXTRACT),
):
    """
    Direct raw text parsing endpoint.
    Accepts pasted contact info, business cards, email signatures, or address blocks
    and extracts structured entity fields (Company, Supplier, Partner, Bank).
    """
    validate_module_name(module)
    check_module_extract_permission(db, current_user, module)
    validate_raw_text(raw_text)
    result = service.parse_raw_text_directly(
        db=db,
        module_name=module,
        raw_text=raw_text,
        save_session=save_session,
        created_by=current_user.user_id,
    )
    return SmartUploadResponse(**result)


# The former /parse/purchase-order, /parse/cargo-shipping ... routes were unreachable (``/parse/{module}`` is
# registered first and serves the same URLs) and have been removed (SDU-07).


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
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(SESSIONS_READ),
):
    """List smart upload sessions, optionally filtered by module name."""
    return service.get_upload_sessions_service(db, module_name=module_name, skip=skip, limit=limit)


@router.get(
    "/sessions/{session_id}",
    response_model=UploadSessionResponse,
    status_code=status.HTTP_200_OK,
    summary="Get a specific upload session by ID",
)
def get_upload_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(SESSIONS_READ),
):
    s = service.get_upload_session_by_id_service(db, session_id)
    if not s:
        raise HTTPException(status_code=404, detail=f"جلسة الرفع رقم {session_id} غير موجودة.")
    return s


@router.delete(
    "/sessions/{session_id}",
    status_code=status.HTTP_200_OK,
    summary="Soft-delete an upload session",
)
def delete_upload_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(UPLOAD)),
):
    deleted = service.soft_delete_upload_session_service(db, session_id)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"جلسة الرفع رقم {session_id} غير موجودة.")
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
def extract_commercial_invoice_endpoint(
    file: Optional[UploadFile] = File(None, description="Invoice file (PDF, Excel, Word)"),
    raw_text: Optional[str] = Form(None, description="Pasted invoice text"),
    db: Session = Depends(get_db),
    current_user: User = Depends(OPERATIONAL_EXTRACT),
):
    """Extracts structured commercial invoice data with line items from file or text."""
    filename = "invoice.txt"
    content_bytes = None
    validate_raw_text(raw_text)
    if file:
        filename = stored_filename(file.filename or "invoice.pdf")
        # Same chain as /parse (SDU-02): extension whitelist, bounded read, 20 MB, magic bytes.
        _, content_bytes = read_validated_upload_sync(file)

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
def extract_bill_of_lading_endpoint(
    file: Optional[UploadFile] = File(None, description="Bill of Lading or AWB file"),
    raw_text: Optional[str] = Form(None, description="Pasted B/L text"),
    db: Session = Depends(get_db),
    current_user: User = Depends(OPERATIONAL_EXTRACT),
):
    """Extracts structured Bill of Lading / Air Waybill data with container details."""
    filename = "bill_of_lading.txt"
    content_bytes = None
    validate_raw_text(raw_text)
    if file:
        filename = stored_filename(file.filename or "bill_of_lading.pdf")
        # Same chain as /parse (SDU-02): extension whitelist, bounded read, 20 MB, magic bytes.
        _, content_bytes = read_validated_upload_sync(file)

    return service.extract_bill_of_lading_service(
        filename=filename,
        content_bytes=content_bytes,
        raw_text=raw_text,
        db=db,
    )


@router.post(
    "/extract/packing-list",
    status_code=status.HTTP_200_OK,
    summary="Extract Packing List, weights, packages, dimensions, and line items",
)
async def extract_packing_list_endpoint(
    file: Optional[UploadFile] = File(None, description="Packing List or Weight List file"),
    raw_text: Optional[str] = Form(None, description="Pasted Packing List text"),
    db: Session = Depends(get_db),
    current_user: User = Depends(EXTRACT),
):
    """Extracts structured packing list data with packages, pallets, weights, and items."""
    filename = "packing_list.txt"
    content_bytes = None
    validate_raw_text(raw_text)
    if file:
        filename = stored_filename(file.filename or "packing_list.pdf")
        _, content_bytes = await read_validated_upload(file)

    return service.extract_packing_list_service(
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
    payload: CrossCheckRequest,
    current_user: User = Depends(OPERATIONAL_EXTRACT),
):
    """
    Compares commercial invoice data against B/L data.
    Validates ACID, Importer Tax ID, weight variance, Incoterms, and ports.
    """
    return service.cross_check_invoice_and_bl_service(
        invoice_data=payload.invoice_data or {},
        bl_data=payload.bl_data or {},
        weight_tolerance_pct=payload.weight_tolerance_pct,
        system_data=payload.system_data or {},
        packing_list_data=payload.packing_list_data or {},
    )


@router.post(
    "/apply/commercial-invoice",
    status_code=status.HTTP_200_OK,
    summary="Apply extracted invoice data to an ImportFile",
)
def apply_extracted_invoice_endpoint(
    payload: ApplyInvoiceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("import_files.edit")),
):
    return service.apply_extracted_invoice_service(db=db, payload=payload, user=current_user.username)


@router.post(
    "/apply/bill-of-lading",
    status_code=status.HTTP_200_OK,
    summary="Apply extracted B/L data and containers to CargoShipping",
)
def apply_extracted_bl_endpoint(
    payload: ApplyBLRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_shipping.update")),
):
    return service.apply_extracted_bl_service(db=db, payload=payload, user=current_user.username)
