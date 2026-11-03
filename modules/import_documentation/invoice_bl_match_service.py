"""
Commercial Invoice vs. Bill of Lading Cross-Matching Service (Phase 3 - BP-019).
"""

import logging
from datetime import date, datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Set, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

from modules.import_documentation.model import InvoiceBLMatchSession, POPackingReconciliationSession
from modules.suppliers.model import Supplier
from modules.cargo_shipping.model import CargoShippingRecord
from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.import_documentation.schemas import *
from modules.import_documentation.validators import validate_status, validate_currency_code
_validate_currency_code = validate_currency_code
import modules.import_documentation.repository as repo
from modules.common.system_messages import coded_text, msg, render_en
from modules.common.enum_codes import Placeholder, finalize_structured_values
from modules.common.file_tracking import set_file_tracking
from modules.common.errors import best_effort
from modules.common.validators import not_found, require_active
from modules.import_files.repository import codes_by_ids

from modules.import_documentation.ai_document_parser import (
    extract_commercial_invoice_data,
    _heuristic_multi_carrier_extractor as extract_draft_bl_data,
)
from modules.import_documentation.document_upload_ocr_service import (
    extract_text_and_boxes_from_uploaded_file,
    extract_text_from_uploaded_file,
)
from modules.import_documentation.draft_bl_service import _build_system_bl_snapshot
from modules.import_documentation.doc_common import (
    SYSTEM_ACTOR,
    LABEL_IMPORT_FILE,
    LABEL_INVOICE_BL_SESSION,
    _actor,
    _bad_request,
    _conflict,
    _active_import_file,
    _get_active_import_file,
    _commit_follow_up,
    _lifecycle_follow_up,
    _to_float,
    _validate_incoterm_code,
    _fuzzy_match,
    _numeric_match,
    _has_text,
)

def extract_and_match_invoice_bl_service(
    db: Session, request: InvoiceBLExtractAndMatchRequest
) -> InvoiceBLExtractAndMatchResponse:
    from modules.import_documentation.ai_document_parser import (
        extract_commercial_invoice_data,
        extract_packing_list_data,
        extract_draft_bl_with_ai,
        match_invoice_with_bl,
    )

    # 1. Parse Invoice
    invoice_data = dict(request.invoice_fields or {})
    if request.invoice_raw_text and request.invoice_raw_text.strip():
        extracted_inv = extract_commercial_invoice_data(request.invoice_raw_text)
        for k, v in extracted_inv.items():
            if k not in invoice_data or not invoice_data[k]:
                invoice_data[k] = v

    # 2. Parse Packing List (if provided as additional file / text)
    pl_data = dict(request.packing_list_fields or {})
    if request.packing_list_raw_text and request.packing_list_raw_text.strip():
        extracted_pl = extract_packing_list_data(request.packing_list_raw_text)
        for k, v in extracted_pl.items():
            if k not in pl_data or not pl_data[k]:
                pl_data[k] = v

    # Merge Packing List parameters into invoice_data to ensure complete cross-matching
    if pl_data:
        if not invoice_data.get("total_gross_weight_kg") and pl_data.get("total_gross_weight_kg"):
            invoice_data["total_gross_weight_kg"] = pl_data["total_gross_weight_kg"]
        if not invoice_data.get("total_net_weight_kg") and pl_data.get("total_net_weight_kg"):
            invoice_data["total_net_weight_kg"] = pl_data["total_net_weight_kg"]
        if not invoice_data.get("total_packages") and pl_data.get("total_packages"):
            invoice_data["total_packages"] = pl_data["total_packages"]
            invoice_data["qty_pkg"] = pl_data["total_packages"]
        if not invoice_data.get("cbm") and pl_data.get("total_cbm"):
            invoice_data["cbm"] = pl_data["total_cbm"]
        if not invoice_data.get("containers") and pl_data.get("containers"):
            invoice_data["containers"] = pl_data["containers"]
        if not invoice_data.get("acid_number") and pl_data.get("acid_number"):
            invoice_data["acid_number"] = pl_data["acid_number"]
        if not invoice_data.get("importer_tax_id") and pl_data.get("importer_tax_id"):
            invoice_data["importer_tax_id"] = pl_data["importer_tax_id"]
        if not invoice_data.get("shipper") and pl_data.get("shipper"):
            invoice_data["shipper"] = pl_data["shipper"]
        if not invoice_data.get("consignee") and pl_data.get("consignee"):
            invoice_data["consignee"] = pl_data["consignee"]


    # 3. Parse Bill of Lading
    bl_data = dict(request.bl_fields or {})
    if request.bl_raw_text and request.bl_raw_text.strip():
        extracted_bl = extract_draft_bl_with_ai(request.bl_raw_text)
        for k, v in extracted_bl.items():
            if k not in bl_data or not bl_data[k]:
                bl_data[k] = v

    # 4. System snapshot if import_file_id is provided
    sys_data = None
    imp_file_code = None
    if request.import_file_id:
        sys_data = _build_system_bl_snapshot(db, request.import_file_id)
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == request.import_file_id).first()
        if imp_file:
            imp_file_code = imp_file.import_file_code

    # 5. Execute Smart Cross-Matching
    match_result = match_invoice_with_bl(invoice_data, bl_data, sys_data, pl_data)

    return InvoiceBLExtractAndMatchResponse(
        import_file_id=request.import_file_id,
        import_file_code=imp_file_code,
        overall_status=match_result["overall_status"],
        is_safe_for_certification=match_result["is_safe_for_certification"],
        match_score_percentage=match_result["match_score_percentage"],
        critical_discrepancies_count=match_result["critical_discrepancies_count"],
        warning_discrepancies_count=match_result["warning_discrepancies_count"],
        comparison_matrix=match_result["comparison_matrix"],
        correction_letter=match_result["correction_letter"],
        invoice_data=match_result["invoice_data"],
        bl_data=match_result["bl_data"],
        packing_list_data=pl_data or None,
    )








def _apply_invoice_bl_sync(
    db: Session, imp_file: ImportFile, inv: Dict[str, Any], bl: Dict[str, Any], sync_to_shipping: bool, actor: str
) -> bool:
    """Validated invoice / B/L values onto the import file and the cargo shipping record. No commit: the caller
    commits them together with its own entity (DOC-13). Every value is checked before anything is written.
    Returns True when invoice currency differs from the file's estimated_cost_currency."""
    # ImportFile has no amount column: the invoice amount stays in the session's invoice_data (deferred: column +
    # migration). Incoterm -> incoterm_code. Currency is validated; estimated_cost_currency is NEVER overwritten (BE03-T02).
    incoterm = _validate_incoterm_code(db, inv["incoterm"]) if inv.get("incoterm") else None
    currency = _validate_currency_code(db, inv["currency"]) if inv.get("currency") else None
    if bl.get("total_gross_weight_kg"):
        _to_float(bl["total_gross_weight_kg"], "total_gross_weight_kg")  # still rejected when not a number

    # Sync Invoice fields
    if inv.get("invoice_number"):
        imp_file.pi_number = str(inv["invoice_number"])
    if incoterm:
        imp_file.incoterm_code = incoterm

    # Sync B/L fields
    if bl.get("draft_bl_number"):
        imp_file.bl_number = str(bl["draft_bl_number"])
    if bl.get("booking_no"):
        imp_file.booking_no = str(bl["booking_no"])
    if bl.get("vessel_name"):
        imp_file.vessel_name = str(bl["vessel_name"])
    imp_file.updated_by = actor

    # Sync to Cargo Shipping Record if requested
    if sync_to_shipping:
        cargo_shp = db.query(CargoShippingRecord).filter(
            CargoShippingRecord.import_file_id == imp_file.import_file_id,
            CargoShippingRecord.is_active == True
        ).first()
        # Only containers_loading_data is a real column; B/L number, vessel and gross weight have no cargo column
        if cargo_shp and bl.get("containers"):
            raw_containers = bl["containers"]
            merged = [dict(c) for c in (cargo_shp.containers_loading_data or []) if isinstance(c, dict)]
            index = {str(c.get("container_no") or "").strip().upper(): c for c in merged if c.get("container_no")}
            for item in raw_containers:
                if isinstance(item, dict):
                    key = str(item.get("container_no") or "").strip().upper()
                    item_dict = dict(item)
                elif hasattr(item, "model_dump"):
                    item_dict = item.model_dump()
                    key = str(item_dict.get("container_no") or "").strip().upper()
                elif hasattr(item, "__dict__"):
                    item_dict = dict(item.__dict__)
                    key = str(item_dict.get("container_no") or "").strip().upper()
                else:
                    continue
                if not key:
                    continue
                row = index.get(key)
                if row is None:
                    new_row = dict(item_dict)
                    new_row["container_no"] = key
                    merged.append(new_row)
                    index[key] = new_row
                else:
                    for k, v in item_dict.items():
                        if k in ("vgm_status", "tracking_status"):
                            if v is not None:
                                row[k] = v
                        elif v is not None:
                            row[k] = v
            cargo_shp.containers_loading_data = list(merged)
            cargo_shp.updated_by = actor

    currency_mismatch = currency is not None and currency != imp_file.estimated_cost_currency
    return currency_mismatch


def _invoice_bl_sync_follow_ups(db: Session, file_id: int, inv: Dict[str, Any], bl: Dict[str, Any], actor: str) -> None:
    """Customs document approvals, lifecycle STEP_08_MATCH -> STEP_08_COO and file tracking, after the main commit."""

    def _sync_approvals() -> None:
        from modules.docs_customs_approval.model import CustomsDocumentApproval
        approvals = db.query(CustomsDocumentApproval).filter(
            CustomsDocumentApproval.import_file_id == file_id,
            CustomsDocumentApproval.is_active == True,
        ).all()
        app_by_type = {a.document_type: a for a in approvals}
        now = datetime.now(timezone.utc)

        def _approve(app: Any, ref: Any, note: str, set_overall: bool = True) -> None:
            app.document_reference_no = str(ref)
            app.commercial_status = "Approved"
            app.commercial_reviewed_by = actor
            app.commercial_reviewed_at = now
            app.commercial_notes = note
            if set_overall:
                app.overall_status = "Approved for Clearance" if app.customs_status == "Approved" else "Under Review"

        if inv.get("invoice_number") and app_by_type.get("Commercial Invoice"):
            _approve(app_by_type["Commercial Invoice"], inv["invoice_number"],
                     "Smart match with the B/L completed and approved (STEP_08_MATCH).")
        if bl.get("draft_bl_number") and app_by_type.get("Bill of Lading"):
            _approve(app_by_type["Bill of Lading"], bl["draft_bl_number"],
                     "Smart match with the commercial invoice completed and approved (STEP_08_MATCH).")
        pl_ref = bl.get("packing_list_number") or inv.get("packing_list_number")
        if pl_ref and app_by_type.get("Packing List"):
            _approve(app_by_type["Packing List"], pl_ref,
                     "Packing list measurements matched and approved (STEP_08_MATCH).", set_overall=False)

    _commit_follow_up(db, _sync_approvals, "Invoice/B-L customs document approval sync")

    _lifecycle_follow_up(
        db, "Lifecycle advance STEP_08_MATCH->STEP_08_COO",
        import_file_id=file_id,
        completed_step_code="STEP_08_MATCH",
        target_step_codes=["STEP_08_COO"],
        notes=render_en(
            "DOC_INVOICE_BL_MATCH_DONE",
            {"invoice_number": inv.get("invoice_number", "N/A"), "draft_bl_number": bl.get("draft_bl_number", "N/A")},
            "note",
        ),
        assigned_user="Compliance Officer",
    )

    def _track() -> None:
        imp = _get_active_import_file(db, file_id)
        if imp:
            set_file_tracking(imp, step_code="STEP_08_COO", next_action=msg("NA_STEP08COO_REVIEW_COO"))
            if (imp.progress_percent or 0.0) < 54.0:
                imp.progress_percent = 54.0

    _commit_follow_up(db, _track, "Invoice/B-L file tracking")


def _attach_session_currency_mismatch(
    db: Session, session: InvoiceBLMatchSession, file_currency: Optional[str] = None
) -> None:
    if session and session.import_file_id:
        if file_currency is None:
            f = db.query(ImportFile.estimated_cost_currency).filter(ImportFile.import_file_id == session.import_file_id).first()
            file_currency = f[0] if f else None
        inv_c = (session.invoice_data or {}).get("currency") if isinstance(session.invoice_data, dict) else None
        from modules.common import enum_codes
        code = str(enum_codes.normalize_currency(inv_c) or "").strip().upper()
        session.currency_mismatch = bool(code) and code != (file_currency or "").upper()


def sync_certified_invoice_bl_to_file_service(
    db: Session, request: InvoiceBLSyncRequest, user: Optional[str] = None
) -> dict:
    imp_file = _active_import_file(db, request.import_file_id, status_code=status.HTTP_404_NOT_FOUND)
    actor = _actor(user)

    session = repo.get_invoice_bl_match_session_by_file_id(db, request.import_file_id, include_drafts=False)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DOC_INVOICE_BL_NOT_CERTIFIED",
                "message": f"لا توجد جلسة مطابقة معتمدة للفاتورة والبوليصة لملف الاستيراد {imp_file.import_file_code}: يجب اعتماد جلسة المطابقة أولاً قبل المزامنة.",
                "import_file_id": imp_file.import_file_id,
            },
        )

    # Use certified session's invoice_data and bl_data (ignoring client request body)
    inv = session.invoice_data or {}
    bl = session.bl_data or {}

    currency_mismatch = _apply_invoice_bl_sync(db, imp_file, inv, bl, request.sync_to_shipping, actor)
    db.commit()
    _invoice_bl_sync_follow_ups(db, imp_file.import_file_id, inv, bl, actor)
    imp_file = _get_active_import_file(db, request.import_file_id) or imp_file

    invoice_number = inv.get('invoice_number', 'N/A')
    draft_bl_number = bl.get('draft_bl_number', 'N/A')
    validated_currency = _validate_currency_code(db, inv["currency"]) if inv.get("currency") else None
    return {
        "status": "success",
        "message": f"تمت مطابقة واعتماد الفاتورة ({invoice_number}) والبوليصة ({draft_bl_number}) ومزامنة بياناتهما مع ملف الشحنة والموافقة الجمركية بنجاح.",
        # DOC-19 / C6: language-neutral twin of message (code registered centrally, see review-shared-needs.md).
        "message_code": "DOC_INVOICE_BL_SYNCED",
        "message_params": {"invoice_number": str(invoice_number), "draft_bl_number": str(draft_bl_number)},
        "import_file_id": imp_file.import_file_id,
        "import_file_code": imp_file.import_file_code,
        "synced_invoice_number": imp_file.pi_number,
        "synced_bl_number": imp_file.bl_number,
        "synced_incoterm_code": imp_file.incoterm_code,
        # Kept for old clients: the file has no amount column (deferred), the currency is the invoice currency as sent.
        "total_amount": None,
        "currency": validated_currency or imp_file.estimated_cost_currency,
        "currency_mismatch": currency_mismatch,
        "session_code": session.session_code,
    }


def create_invoice_bl_match_session_service(
    db: Session, payload: InvoiceBLMatchSessionCreate, user: Optional[str] = None
) -> InvoiceBLMatchSession:
    validate_status("invoice_bl", payload.overall_status)
    imp_file = _active_import_file(db, payload.import_file_id)
    actor = _actor(user, payload.certified_by)
    if not payload.import_file_code:
        payload.import_file_code = imp_file.custom_file_number or imp_file.import_file_code

    # Server-owned gate fields (BE03-T05)
    if payload.invoice_data and payload.bl_data:
        from modules.import_documentation.ai_document_parser import match_invoice_with_bl
        sys_snap = _build_system_bl_snapshot(db, payload.import_file_id)
        match_result = match_invoice_with_bl(
            payload.invoice_data,
            payload.bl_data,
            sys_snap,
            payload.packing_list_data,
        )
        payload.overall_status = match_result["overall_status"]
        payload.is_safe_for_certification = match_result["is_safe_for_certification"]
        payload.match_score_percentage = match_result["match_score_percentage"]
        payload.critical_discrepancies_count = match_result["critical_discrepancies_count"]
        payload.warning_discrepancies_count = match_result["warning_discrepancies_count"]
        payload.comparison_matrix = match_result["comparison_matrix"]
        if match_result.get("correction_letter") and not payload.correction_letter:
            payload.correction_letter = match_result["correction_letter"]
    else:
        payload.is_safe_for_certification = False
        payload.overall_status = "DISCREPANCY_DETECTED"
        payload.match_score_percentage = 0.0
        payload.critical_discrepancies_count = 0
        payload.warning_discrepancies_count = 0

    existing = repo.get_invoice_bl_match_session_by_file_id(db, payload.import_file_id, include_drafts=True)
    certify = not payload.is_draft
    existing_certified = repo.get_invoice_bl_match_session_by_file_id(db, payload.import_file_id, include_drafts=False)
    if not certify and existing_certified:
        raise _conflict(
            f"يوجد بالفعل جلسة مطابقة معتمدة للفاتورة والبوليصة لهذا الملف ({existing_certified.session_code}): "
            f"لا يمكن حفظ مسودة فوقها."
        )
    currency_mismatch: Optional[bool] = None
    if certify:
        if existing_certified:
            raise _conflict(
                f"يوجد بالفعل جلسة مطابقة معتمدة للفاتورة والبوليصة لهذا الملف ({existing_certified.session_code})."
            )
        # Q6: certifying with critical discrepancies is allowed only with a written justification in notes.
        if ((payload.critical_discrepancies_count or 0) > 0 or not payload.is_safe_for_certification) and not _has_text(payload.notes):
            raise _bad_request("يوجد اختلافات حرجة بين الفاتورة والبوليصة: يجب كتابة مبرر الاعتماد في الملاحظات قبل الاعتماد.")
        payload.certified_by = actor
        if payload.invoice_data and payload.bl_data:
            # Validated and applied before the session save: one commit for session + file sync (DOC-13).
            currency_mismatch = _apply_invoice_bl_sync(db, imp_file, payload.invoice_data, payload.bl_data, True, actor)

    if existing and (existing.is_draft or payload.is_draft):
        update_schema = InvoiceBLMatchSessionUpdate(**payload.model_dump())
        session_res = repo.update_invoice_bl_match_session(db, existing.session_id, update_schema, user=actor)
    else:
        session_res = repo.create_invoice_bl_match_session(db, payload, user=actor)

    if certify and payload.invoice_data and payload.bl_data:
        _invoice_bl_sync_follow_ups(db, payload.import_file_id, payload.invoice_data, payload.bl_data, actor)
        db.refresh(session_res)

    if currency_mismatch is not None:
        session_res.currency_mismatch = currency_mismatch
    else:
        _attach_session_currency_mismatch(db, session_res, file_currency=imp_file.estimated_cost_currency)
    return session_res


def list_invoice_bl_match_sessions_service(
    db: Session,
    import_file_id: Optional[int] = None,
    is_draft: Optional[bool] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
    return_total: bool = False,
) -> Union[List[InvoiceBLMatchSession], Tuple[List[InvoiceBLMatchSession], int]]:
    res = repo.list_invoice_bl_match_sessions(
        db,
        import_file_id=import_file_id,
        is_draft=is_draft,
        search=search,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )
    sessions, total = res if return_total else (res, None)
    for s in sessions:
        _attach_session_currency_mismatch(db, s)
    return (sessions, total) if return_total else sessions


def get_invoice_bl_match_session_service(
    db: Session, session_id: int
) -> InvoiceBLMatchSession:
    session = repo.get_invoice_bl_match_session_by_id(db, session_id)
    if not session:
        raise not_found(LABEL_INVOICE_BL_SESSION, session_id)
    _attach_session_currency_mismatch(db, session)
    return session



def _merge_uploaded_texts(label: str, files: List[Tuple[str, bytes]], seed_text: Optional[str]) -> str:
    parts = [seed_text] if seed_text else []
    for idx, (filename, content) in enumerate(files):
        extracted, _ = extract_text_and_boxes_from_uploaded_file(filename, content)
        if extracted:
            parts.append(f"--- {label} FILE {idx+1}: {filename} ---\n{extracted}")
    return "\n\n".join(parts)


def extract_invoice_bl_files_and_match_service(
    db: Session,
    invoices: List[Tuple[str, bytes]],
    bls: List[Tuple[str, bytes]],
    packings: List[Tuple[str, bytes]],
    import_file_id: Optional[int],
    invoice_text: Optional[str] = None,
    bl_text: Optional[str] = None,
    packing_list_text: Optional[str] = None,
) -> InvoiceBLExtractAndMatchResponse:
    req = InvoiceBLExtractAndMatchRequest(
        import_file_id=import_file_id,
        invoice_raw_text=_merge_uploaded_texts("INVOICE", invoices, invoice_text),
        bl_raw_text=_merge_uploaded_texts("BL", bls, bl_text),
        packing_list_raw_text=_merge_uploaded_texts("PACKING LIST", packings, packing_list_text),
    )
    return extract_and_match_invoice_bl_service(db, req)
