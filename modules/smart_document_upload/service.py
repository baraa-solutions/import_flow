"""
Smart Document Upload — Service
Orchestrates file parsing + field extraction for all ImportFlow modules.
Routes uploaded file to the correct extractor based on module_name.
"""

from __future__ import annotations

import io
import logging
import re
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException, status as http_status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from modules.common.enum_codes import normalize_currency
from modules.common.errors import best_effort
from modules.common.regex_patterns import ACID_PATTERN
from modules.common.validators import get_or_404
from modules.smart_document_upload.schemas import ApplyBLRequest, ApplyInvoiceRequest, UploadSessionResponse

from modules.smart_document_upload.extractors.purchase_order import PurchaseOrderExtractor
from modules.smart_document_upload.extractors.import_file import ImportFileExtractor
from modules.smart_document_upload.extractors.cargo_shipping import CargoShippingExtractor
from modules.smart_document_upload.extractors.commercial_invoice import CommercialInvoiceExtractor
from modules.smart_document_upload.extractors.customs_clearance import CustomsClearanceExtractor
from modules.smart_document_upload.cross_checker import cross_check_invoice_vs_bl

from modules.smart_document_upload.extractors.customs_broker_quotation import CustomsBrokerQuotationExtractor
from modules.smart_document_upload.extractors.freight_quotation import FreightQuotationExtractor
from modules.smart_document_upload.extractors.freight_booking import FreightBookingExtractor
from modules.smart_document_upload.extractors.other_extractors import (
    COOCertificateExtractor,
    InspectionCertificateExtractor,
    FinancialDocumentExtractor,
)
from modules.smart_document_upload.extractors.master_data_entity import MasterDataEntityExtractor
from modules.smart_document_upload.extractors.base_extractor import BaseExtractor
import modules.smart_document_upload.repository as repo
import modules.smart_document_upload.validators as validators

# Entity verification imports
from modules.suppliers.model import Supplier
from modules.import_companies.model import ImportCompany


logger = logging.getLogger(__name__)

# ─── Extractor Registry ───────────────────────────────────────────────────────

_EXTRACTOR_MAP: Dict[str, BaseExtractor] = {
    "purchase-order": PurchaseOrderExtractor(),
    "import-file": ImportFileExtractor(),
    "cargo-shipping": CargoShippingExtractor(),
    "customs-clearance": CustomsClearanceExtractor(),
    "clearance-quotation": CustomsBrokerQuotationExtractor(),
    "customs-broker-quotation": CustomsBrokerQuotationExtractor(),
    "customs-clearance-quotation": CustomsBrokerQuotationExtractor(),
    "freight-quotation": FreightQuotationExtractor(),
    "freight-booking": FreightBookingExtractor(),
    "coo-certificate": COOCertificateExtractor(),
    "inspection-certificate": InspectionCertificateExtractor(),
    "financial-document": FinancialDocumentExtractor(),
    "commercial-invoice": CommercialInvoiceExtractor(),
    "commercial_invoice": CommercialInvoiceExtractor(),
    "invoice": CommercialInvoiceExtractor(),
    "bill-of-lading": CargoShippingExtractor(),
    "bill_of_lading": CargoShippingExtractor(),
    "bl": CargoShippingExtractor(),
    "awb": CargoShippingExtractor(),
    "master-data-entity": MasterDataEntityExtractor(),

    "supplier-entity": MasterDataEntityExtractor(),
    "importer-entity": MasterDataEntityExtractor(),
    "partner-entity": MasterDataEntityExtractor(),
    "bank-entity": MasterDataEntityExtractor(),
    "shipping-line-entity": MasterDataEntityExtractor(),
    "customs-broker-entity": MasterDataEntityExtractor(),
    "freight-forwarder-entity": MasterDataEntityExtractor(),
    "inland-transport-entity": MasterDataEntityExtractor(),
    "inspection-agency-entity": MasterDataEntityExtractor(),
    "insurance-company-entity": MasterDataEntityExtractor(),
    # Aliases
    "customs-consultation": ImportFileExtractor(),   # extracts invoice fields
    "warehouse-receiving": ImportFileExtractor(),    # same as invoice extraction
    "demurrage": FinancialDocumentExtractor(),       # demurrage is a financial doc
}


# ─── Text Extraction ──────────────────────────────────────────────────────────

def extract_raw_text_and_boxes(filename: str, content_bytes: bytes) -> Tuple[str, dict]:
    """
    Reuses the existing extraction engine from import_documentation.
    Supports PDF (spatial), Word, Excel, and text files.
    """
    try:
        from modules.import_documentation.service import (
            extract_text_and_boxes_from_uploaded_file,
        )
        return extract_text_and_boxes_from_uploaded_file(filename, content_bytes)
    except Exception as e:
        logger.warning(f"Primary extractor failed for '{filename}': {e}. Using fallback.")
        return _fallback_text_extraction(filename, content_bytes), {}


def _fallback_text_extraction(filename: str, content_bytes: bytes) -> str:
    """Minimal text extraction fallback."""
    lower = filename.lower()
    try:
        if lower.endswith(".pdf"):
            try:
                import fitz
                doc = fitz.open(stream=content_bytes, filetype="pdf")
                parts = []
                for p in doc:
                    txt = p.get_text("text", sort=True) or p.get_text("text") or ""
                    if txt.strip():
                        parts.append(txt.strip())
                if parts:
                    return "\n\n".join(parts)
            except Exception as exc:  # PyMuPDF failed on this PDF: fall through to pypdf
                logger.warning("PyMuPDF text extraction failed (%s); trying pypdf", type(exc).__name__)
            import pypdf
            reader = pypdf.PdfReader(io.BytesIO(content_bytes))
            return "\n".join(p.extract_text() or "" for p in reader.pages)
        elif lower.endswith((".docx", ".doc")):
            import docx
            doc = docx.Document(io.BytesIO(content_bytes))
            parts = [p.text.strip() for p in doc.paragraphs if p.text.strip()]
            for tbl in doc.tables:
                for row in tbl.rows:
                    row_vals = [cell.text.strip().replace("\n", " ") for cell in row.cells if cell.text.strip()]
                    if row_vals:
                        parts.append(" | ".join(row_vals))
            return "\n".join(parts)
        elif lower.endswith((".xlsx", ".xls")):
            import openpyxl
            wb = openpyxl.load_workbook(io.BytesIO(content_bytes), data_only=True)
            parts = []
            for sheet in wb.sheetnames:
                ws = wb[sheet]
                for row in ws.iter_rows(values_only=True):
                    row_vals = [str(v).strip() for v in row if v is not None and str(v).strip()]
                    if row_vals:
                        parts.append(" | ".join(row_vals))
            return "\n".join(parts)
        else:
            return content_bytes.decode("utf-8", errors="ignore")
    except Exception:
        # Logged with the traceback; the client only sees an empty text (no library / path details echoed).
        logger.exception("Fallback text extraction failed")
        return ""


# ─── Entity Verification ──────────────────────────────────────────────────────

def verify_extracted_entities(db: Session, extracted_fields: Dict[str, Any]) -> Dict[str, Any]:
    """
    After field extraction, checks whether the identified supplier_name and
    importer_name (consignee) exist in the database.

    Returns a dict with verification results:
    {
        supplier_verified: bool | None,
        supplier_id: int | None,
        supplier_code: str | None,
        importer_verified: bool | None,
        importer_id: int | None,
        importer_code: str | None,
    }
    Uses case-insensitive LIKE search to handle minor name differences.
    """
    result: Dict[str, Any] = {
        "supplier_verified": None,
        "supplier_id": None,
        "supplier_code": None,
        "importer_verified": None,
        "importer_id": None,
        "importer_code": None,
    }

    # ── Supplier verification ────────────────────────────────────────────────
    supplier_name: Optional[str] = extracted_fields.get("supplier_name") or extracted_fields.get("shipper")
    if supplier_name and supplier_name.strip():
        name_clean = supplier_name.strip()
        try:
            from sqlalchemy import func as sa_func
            matched_supplier = (
                db.query(Supplier)
                .filter(
                    Supplier.is_active == True,
                    sa_func.lower(Supplier.company_name).contains(name_clean.lower()[:40])
                )
                .first()
            )
            if matched_supplier:
                result["supplier_verified"] = True
                result["supplier_id"] = matched_supplier.supplier_id
                result["supplier_code"] = matched_supplier.supplier_code
            else:
                result["supplier_verified"] = False
        except Exception as e:
            logger.warning(f"Supplier verification query failed: {e}")
            result["supplier_verified"] = False

    # ── Importer / Consignee verification ────────────────────────────────────
    importer_name: Optional[str] = (
        extracted_fields.get("importer_name")
        or extracted_fields.get("consignee")
        or extracted_fields.get("company_name")
    )
    if importer_name and importer_name.strip():
        name_clean = importer_name.strip()
        try:
            from sqlalchemy import func as sa_func
            matched_company = (
                db.query(ImportCompany)
                .filter(
                    ImportCompany.is_active == True,
                    sa_func.lower(ImportCompany.importer_name).contains(name_clean.lower()[:40])
                )
                .first()
            )
            if matched_company:
                result["importer_verified"] = True
                result["importer_id"] = matched_company.company_id
                result["importer_code"] = matched_company.importer_id  # business code field
            else:
                result["importer_verified"] = False
        except Exception as e:
            logger.warning(f"Importer verification query failed: {e}")
            result["importer_verified"] = False

    return result


# ─── Session persistence ─────────────────────────────────────────────────────

SESSION_REF_ATTEMPTS = 2


def _save_upload_session(db: Session, **fields: Any):
    """Insert the upload session and commit. ``UPLOAD-<year>-NNNNN`` comes from the highest suffix; a reference
    taken concurrently (IntegrityError) is retried once with a fresh one (SDU-05). Callers wrap this in
    ``best_effort``: a failed save is rolled back and logged, the extraction result is still returned."""
    for attempt in range(1, SESSION_REF_ATTEMPTS + 1):
        try:
            record = repo.create_upload_session(db=db, **fields)
            db.commit()
            db.refresh(record)
            return record
        except IntegrityError:
            db.rollback()
            if attempt == SESSION_REF_ATTEMPTS:
                raise


# ─── Main Service Function ────────────────────────────────────────────────────

def parse_uploaded_document(
    db: Session,
    module_name: str,
    filename: str,
    file_type: str,
    content_bytes: bytes,
    save_session: bool = True,
    created_by: Optional[int] = None,
) -> Dict[str, Any]:
    """
    Main orchestrator:
    1. Extracts raw text from uploaded file (PDF/Excel/Word)
    2. Routes to the appropriate module extractor
    3. Computes confidence score and missing fields
    4. Saves an upload session record
    5. Returns a structured response dict
    """
    file_size = len(content_bytes)

    # Step 1 — Extract raw text
    raw_text, spatial_boxes = extract_raw_text_and_boxes(filename, content_bytes)

    # Step 2 — Route to extractor
    extractor = _EXTRACTOR_MAP.get(module_name)
    if extractor is None:
        logger.warning(f"No extractor for module '{module_name}'. Using ImportFileExtractor as default.")
        extractor = ImportFileExtractor()

    # Step 3 — Extract fields
    try:
        if isinstance(extractor, MasterDataEntityExtractor):
            extracted_fields = extractor.extract(raw_text, spatial_boxes, module_name=module_name)
        else:
            extracted_fields = extractor.extract(raw_text, spatial_boxes)
    except Exception as e:
        logger.error(f"Extractor error for '{module_name}': {e}")
        extracted_fields = {}

    # Step 4 — Compute quality metrics
    confidence = extractor.compute_confidence(extracted_fields)
    missing = extractor.missing_required(extracted_fields)

    if confidence >= 0.8:
        status = "SUCCESS"
    elif confidence >= 0.4:
        status = "PARTIAL"
    else:
        status = "FAILED"

    notes = (
        f"Extracted {len([v for v in extracted_fields.values() if v is not None])} fields. "
        f"Confidence: {confidence:.0%}. "
        + (f"Missing: {', '.join(missing)}." if missing else "All required fields found.")
    )

    # Step 5 — Verify extracted entities against DB (supplier + importer)
    entity_verification = verify_extracted_entities(db, extracted_fields)

    # Step 6 — Save session
    session_id = None
    session_ref = None
    if save_session:
        session = best_effort(
            db, _save_upload_session, "smart upload session save", db,
            module_name=module_name,
            filename=filename,
            file_type=file_type,
            file_size_bytes=file_size,
            extraction_status=status,
            confidence_score=confidence,
            extracted_fields=extracted_fields,
            missing_fields=missing,
            extraction_notes=notes,
            created_by=created_by,
        )
        if session is not None:
            session_id = session.id
            session_ref = session.session_ref

    return {
        "session_id": session_id,
        "session_ref": session_ref,
        "module_name": module_name,
        "filename": filename,
        "file_type": file_type,
        "file_size_bytes": file_size,
        "extraction_status": status,
        "confidence_score": confidence,
        "extracted_fields": extracted_fields,
        "missing_fields": missing,
        "extraction_notes": notes,
        "raw_text_preview": raw_text[:500] if raw_text else None,
        "validation_report": extracted_fields.get("validation_report") if isinstance(extracted_fields, dict) else None,
        **entity_verification,
    }


def parse_multiple_uploaded_documents(
    db: Session,
    module_name: str,
    files_data: List[Tuple[str, str, bytes]],
    save_session: bool = True,
    created_by: Optional[int] = None,
) -> Dict[str, Any]:
    """
    Parses multiple documents (e.g. Commercial Invoice + Packing List) concurrently,
    extracts raw text from each file, combines the raw text and spatial boxes,
    runs the module extractor, and returns a unified combined response.
    """
    combined_texts = []
    combined_boxes = {}
    combined_filenames = []
    total_size = 0

    for filename, file_type, content_bytes in files_data:
        raw_text, spatial_boxes = extract_raw_text_and_boxes(filename, content_bytes)
        combined_texts.append(f"=== DOCUMENT: {filename} ===\n{raw_text}")
        combined_boxes.update(spatial_boxes)
        combined_filenames.append(filename)
        total_size += len(content_bytes)

    full_text = "\n\n".join(combined_texts)
    unified_filename = " + ".join(combined_filenames)
    primary_file_type = files_data[0][1] if files_data else "pdf"

    extractor = _EXTRACTOR_MAP.get(module_name)
    if extractor is None:
        extractor = ImportFileExtractor()

    try:
        if isinstance(extractor, MasterDataEntityExtractor):
            extracted_fields = extractor.extract(full_text, combined_boxes, module_name=module_name)
        else:
            extracted_fields = extractor.extract(full_text, combined_boxes)
    except Exception as e:
        logger.error(f"Multi-document extractor error for '{module_name}': {e}")
        extracted_fields = {}

    confidence = extractor.compute_confidence(extracted_fields)
    missing = extractor.missing_required(extracted_fields)

    status = "SUCCESS" if confidence >= 0.8 else ("PARTIAL" if confidence >= 0.4 else "FAILED")
    notes = (
        f"Extracted {len([v for v in extracted_fields.values() if v is not None])} fields from {len(files_data)} documents ({unified_filename}). "
        f"Confidence: {confidence:.0%}. "
        + (f"Missing: {', '.join(missing)}." if missing else "All required fields found.")
    )

    # Verify extracted entities against DB (supplier + importer)
    entity_verification = verify_extracted_entities(db, extracted_fields)

    session_id = None
    session_ref = None
    if save_session:
        session = best_effort(
            db, _save_upload_session, "smart upload session save", db,
            module_name=module_name,
            filename=unified_filename,
            file_type=primary_file_type,
            file_size_bytes=total_size,
            extraction_status=status,
            confidence_score=confidence,
            extracted_fields=extracted_fields,
            missing_fields=missing,
            extraction_notes=notes,
            created_by=created_by,
        )
        if session is not None:
            session_id = session.id
            session_ref = session.session_ref

    return {
        "session_id": session_id,
        "session_ref": session_ref,
        "module_name": module_name,
        "filename": unified_filename,
        "file_type": primary_file_type,
        "file_size_bytes": total_size,
        "extraction_status": status,
        "confidence_score": confidence,
        "extracted_fields": extracted_fields,
        "missing_fields": missing,
        "extraction_notes": notes,
        "raw_text_preview": full_text[:500] if full_text else None,
        **entity_verification,
    }


def parse_raw_text_directly(
    db: Session,
    module_name: str,
    raw_text: str,
    save_session: bool = False,
    created_by: Optional[int] = None,
) -> dict:
    """
    Parses raw text directly without file upload (e.g. pasted contact info / address block)
    and returns structured extracted entity or document fields.
    """
    extractor = _EXTRACTOR_MAP.get(module_name)
    if extractor is None:
        extractor = MasterDataEntityExtractor()

    try:
        if isinstance(extractor, MasterDataEntityExtractor):
            extracted_fields = extractor.extract(raw_text, {}, module_name=module_name)
        else:
            extracted_fields = extractor.extract(raw_text, {})
    except Exception as e:
        logger.error(f"Direct raw text extractor error for '{module_name}': {e}")
        extracted_fields = {}

    confidence = extractor.compute_confidence(extracted_fields)
    missing = extractor.missing_required(extracted_fields)
    status = "SUCCESS" if confidence >= 0.8 else ("PARTIAL" if confidence >= 0.4 else "FAILED")

    notes = (
        f"Parsed raw text block ({len(raw_text)} chars). "
        f"Confidence: {confidence:.0%}. "
        + (f"Missing: {', '.join(missing)}." if missing else "All required fields found.")
    )

    # Verify extracted entities against DB (supplier + importer)
    entity_verification = verify_extracted_entities(db, extracted_fields)

    session_id = None
    session_ref = None
    if save_session:
        session = best_effort(
            db, _save_upload_session, "smart upload session save", db,
            module_name=module_name,
            filename="pasted_raw_text",
            file_type="text",
            file_size_bytes=len(raw_text.encode("utf-8")),
            extraction_status=status,
            confidence_score=confidence,
            extracted_fields=extracted_fields,
            missing_fields=missing,
            extraction_notes=notes,
            created_by=created_by,
        )
        if session is not None:
            session_id = session.id
            session_ref = session.session_ref

    return {
        "session_id": session_id,
        "session_ref": session_ref,
        "module_name": module_name,
        "filename": "pasted_raw_text",
        "file_type": "text",
        "file_size_bytes": len(raw_text.encode("utf-8")),
        "extraction_status": status,
        "confidence_score": confidence,
        "extracted_fields": extracted_fields,
        "missing_fields": missing,
        "extraction_notes": notes,
        "validation_report": extracted_fields.get("validation_report") if isinstance(extracted_fields, dict) else None,
        **entity_verification,
    }


def get_upload_sessions_service(
    db: Session, module_name: Optional[str] = None, skip: int = 0, limit: int = 50
) -> List[UploadSessionResponse]:
    return [
        UploadSessionResponse.from_model(s)
        for s in repo.get_upload_sessions(db, module_name=module_name, skip=skip, limit=limit)
    ]


def get_upload_session_by_id_service(db: Session, session_id: int) -> Optional[UploadSessionResponse]:
    s = repo.get_upload_session_by_id(db, session_id)
    return UploadSessionResponse.from_model(s) if s else None


# ─── AI Commercial Invoice & Bill of Lading Specialized Services ─────────────

def extract_commercial_invoice_service(
    filename: str = "invoice.pdf",
    content_bytes: Optional[bytes] = None,
    raw_text: Optional[str] = None,
    db: Optional[Session] = None,
    created_by: Optional[str] = "Admin",
) -> Dict[str, Any]:
    """Extracts commercial invoice data and itemized line items."""
    if not raw_text and content_bytes:
        raw_text, spatial_boxes = extract_raw_text_and_boxes(filename, content_bytes)
    else:
        spatial_boxes = {}
    extractor = CommercialInvoiceExtractor()
    extracted = extractor.extract(raw_text or "", spatial_boxes)
    return {
        "document_type": "Commercial Invoice",
        "filename": filename,
        "extracted_fields": extracted,
        "items": extracted.get("items", []),
        "items_count": len(extracted.get("items", [])),
    }


def extract_bill_of_lading_service(
    filename: str = "bill_of_lading.pdf",
    content_bytes: Optional[bytes] = None,
    raw_text: Optional[str] = None,
    db: Optional[Session] = None,
    created_by: Optional[str] = "Admin",
) -> Dict[str, Any]:
    """Extracts bill of lading / AWB data and container list."""
    if not raw_text and content_bytes:
        raw_text, spatial_boxes = extract_raw_text_and_boxes(filename, content_bytes)
    else:
        spatial_boxes = {}
    extractor = CargoShippingExtractor()
    extracted = extractor.extract(raw_text or "", spatial_boxes)
    return {
        "document_type": extracted.get("bl_type", "OCEAN_BL"),
        "filename": filename,
        "extracted_fields": extracted,
        "containers": extracted.get("containers", []),
        "containers_count": len(extracted.get("containers", [])),
    }


def cross_check_invoice_and_bl_service(
    invoice_data: Dict[str, Any],
    bl_data: Dict[str, Any],
    weight_tolerance_pct: float = 3.0,
    system_data: Optional[Dict[str, Any]] = None,
    packing_list_data: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """10-point cross-comparison between Commercial Invoice, B/L, System, and Packing List."""
    return cross_check_invoice_vs_bl(
        invoice_data=invoice_data,
        bl_data=bl_data,
        weight_tolerance_pct=weight_tolerance_pct,
        system_data=system_data,
        packing_list_data=packing_list_data,
    )


def _acid_or_400(raw: Optional[str]) -> Optional[str]:
    if raw is None or not str(raw).strip():
        return None
    acid = str(raw).strip()
    if not ACID_PATTERN.fullmatch(acid):
        raise HTTPException(
            status_code=http_status.HTTP_400_BAD_REQUEST,
            detail={
                "code": "SDU_ACID_INVALID",
                "message": f"رقم الـ ACID المستخرج ({acid}) غير صالح: يجب أن يكون 19 رقماً.",
                "acid_number": acid,
            },
        )
    return acid


def _incoterm_or_400(db: Session, raw: Optional[str]) -> Optional[str]:
    if raw is None or not str(raw).strip():
        return None
    from modules.incoterms.model import Incoterm

    code = str(raw).strip().upper()
    found = db.query(Incoterm).filter(Incoterm.incoterm_code == code, Incoterm.is_active == True).first()
    if found is None:
        raise HTTPException(
            status_code=http_status.HTTP_400_BAD_REQUEST,
            detail=f"شرط التسليم '{raw}' غير مسجل في جدول شروط التسليم (Incoterms) أو غير نشط.",
        )
    return found.incoterm_code


def _currency_or_400(raw: Optional[str]) -> Optional[str]:
    if raw is None or not str(raw).strip():
        return None
    code = normalize_currency(str(raw))
    if not isinstance(code, str) or not re.fullmatch(r"[A-Z]{3}", code):
        raise HTTPException(
            status_code=http_status.HTTP_400_BAD_REQUEST,
            detail=f"العملة '{raw}' غير صالحة: المطلوب رمز ISO من 3 أحرف (مثل USD).",
        )
    return code


def apply_extracted_invoice_service(db: Session, payload: ApplyInvoiceRequest, user: str = "SYSTEM") -> Dict[str, Any]:
    """
    Apply validated invoice data to an active ImportFile (SDU-01): ACID must be 19 digits and never replaces a
    different ACID already on the file (409 ``SDU_ACID_CONFLICT``); the Incoterm must exist in the master table;
    the currency is an ISO code; the value is a positive number (schema). Without an import file the data is
    only returned for a new file (``SDU_EXTRACTED_ONLY``).
    """
    from modules.import_files.model import ImportFile

    data = payload.invoice_data
    if not payload.import_file_id:
        return {
            "applied": False,
            "import_file_id": None,
            "msg_code": "SDU_EXTRACTED_ONLY",
            "params": {},
            "message_ar": "تم استخراج البيانات وجاهزة للاستخدام بملف جديد",
        }
    file_record = get_or_404(db, ImportFile, payload.import_file_id, "ملف الاستيراد", active_only=True)
    validators.ensure_import_file_open(file_record)

    acid = _acid_or_400(data.acid_number)
    incoterm = _incoterm_or_400(db, data.incoterms)
    currency = _currency_or_400(data.currency)
    current_acid = (file_record.acid_number or "").strip()
    if acid and current_acid and current_acid != acid:
        raise HTTPException(
            status_code=http_status.HTTP_409_CONFLICT,
            detail={
                "code": "SDU_ACID_CONFLICT",
                "message": f"رقم الـ ACID المستخرج ({acid}) يختلف عن الرقم المسجل على الملف ({current_acid}).",
                "acid_number": acid,
                "current_acid_number": current_acid,
                "import_file_code": file_record.import_file_code,
            },
        )

    if acid:
        file_record.acid_number = acid
    if incoterm:
        file_record.incoterm_code = incoterm
    if data.loading_port and data.loading_port.strip():
        file_record.port_of_loading = data.loading_port.strip()
    if data.discharge_port and data.discharge_port.strip():
        file_record.port_of_discharge = data.discharge_port.strip()
    if data.invoice_value is not None:
        file_record.estimated_cost = data.invoice_value
    if currency:
        file_record.estimated_cost_currency = currency

    existing_invoices = list(file_record.invoices_data or [])
    inv_no = (data.invoice_number or "").strip() or f"INV-{len(existing_invoices) + 1}"
    existing_invoices.append({
        "invoice_no": inv_no,
        "date": data.invoice_date,
        "amount": data.invoice_value or 0.0,
        "currency": currency or file_record.estimated_cost_currency,  # no invented default currency
        "items_count": len(data.items),
    })
    file_record.invoices_data = existing_invoices
    file_record.invoices_count = len(existing_invoices)
    file_record.updated_by = user
    db.commit()
    db.refresh(file_record)
    return {
        "applied": True,
        "import_file_id": file_record.import_file_id,
        "import_file_code": file_record.import_file_code,
        "msg_code": "SDU_INVOICE_APPLIED",
        "params": {"import_file_code": file_record.import_file_code, "invoice_no": inv_no},
        "message_ar": f"تم ربط بيانات الفاتورة بنجاح مع الملف {file_record.import_file_code}",  # kept one release
    }


def apply_extracted_bl_service(db: Session, payload: ApplyBLRequest, user: str = "SYSTEM") -> Dict[str, Any]:
    """
    Merge extracted B/L containers into the file's CargoShippingRecord by ``container_no`` (SDU-01): existing
    rows keep their status fields (VGM, tracking) and only take extracted values that are present; new rows get
    null type / statuses when not extracted (no invented "40HC" / "Verified" / "Gate-In").
    """
    from modules.cargo_shipping.model import CargoShippingRecord
    from modules.import_files.model import ImportFile

    shipping_record = None
    if payload.import_file_id:
        file_record = get_or_404(db, ImportFile, payload.import_file_id, "ملف الاستيراد", active_only=True)
        validators.ensure_import_file_open(file_record)
        shipping_record = (
            db.query(CargoShippingRecord)
            .filter(CargoShippingRecord.import_file_id == payload.import_file_id, CargoShippingRecord.is_active == True)
            .first()
        )
        if not shipping_record:
            raise HTTPException(
                status_code=http_status.HTTP_409_CONFLICT,
                detail={
                    "code": "SDU_NO_SHIPPING_RECORD",
                    "message": f"لا يوجد سجل شحن نشط لملف الاستيراد {file_record.import_file_code}؛ "
                    "يجب إنشاء سجل الشحن أولاً قبل تطبيق بيانات البوليصة.",
                    "import_file_id": payload.import_file_id,
                    "import_file_code": file_record.import_file_code,
                },
            )
    if not shipping_record:
        return {
            "applied": False,
            "msg_code": "SDU_EXTRACTED_ONLY",
            "params": {},
            "message_ar": "تم استخراج بيانات البوليصة بنجاح",
        }

    merged = [dict(c) for c in (shipping_record.containers_loading_data or []) if isinstance(c, dict)]
    index = {str(c.get("container_no") or "").strip().upper(): c for c in merged if c.get("container_no")}
    applied = 0
    for item in payload.bl_data.containers:
        key = (item.container_no or "").strip().upper()
        if not key:
            continue  # nothing to merge on
        extracted = {
            "seal_no": item.seal_no,
            "container_type": item.container_type,
            "gross_weight_kg": item.gross_weight_kg,
            "cbm": item.cbm,
        }
        row = index.get(key)
        if row is None:
            row = {"container_no": key, "vgm_status": None, "tracking_status": None, **extracted}
            merged.append(row)
            index[key] = row
        else:
            row.update({k: v for k, v in extracted.items() if v is not None})
        applied += 1
    if applied:
        shipping_record.containers_loading_data = merged
        shipping_record.updated_by = user
    db.commit()
    db.refresh(shipping_record)
    return {
        "applied": True,
        "cargo_shipping_id": shipping_record.cargo_shipping_id,
        "cargo_shipping_code": shipping_record.cargo_shipping_code,
        "containers_applied": applied,
        "msg_code": "SDU_BL_APPLIED",
        "params": {"cargo_shipping_code": shipping_record.cargo_shipping_code, "containers_applied": applied},
        "message_ar": f"تم تطبيق بيانات البوليصة والحاويات على الشحنة {shipping_record.cargo_shipping_code}",
    }


def soft_delete_upload_session_service(db: Session, session_id: int) -> bool:
    deleted = repo.soft_delete_upload_session(db, session_id)
    if deleted:
        db.commit()
    return deleted
