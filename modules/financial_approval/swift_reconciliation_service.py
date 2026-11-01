"""
Service Layer & Business Engine for Financial Approval (BP-012 & BP-013)

Transactions: every request commits its core state once (row, status, logs, notification). Follow-ups that
must never undo that state (lifecycle advance, smart tasks, lifecycle stage sync) run AFTER the commit
through ``errors.best_effort`` (it rolls back on failure, so it must never run before the core commit).
Status transitions are server-owned (validators); coded errors use plain ``{code, message, **params}`` dicts.
"""

import base64
import binascii
import logging
import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Any, Callable, Dict, Iterable, List, Optional, Tuple, TypeVar

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

import modules.financial_approval.repository as repo
from modules.auth.permissions import is_admin_user
from modules.common.errors import best_effort
from modules.common.system_messages import msg, render_en
from modules.common.validators import not_found, not_null_columns, require_active
from modules.financial_approval.model import (
    BudgetVarianceLog,
    BudgetVarianceSetting,
    ImportBudgetApproval,
    PaymentRequestSession,
    SwiftExtractionBatch,
)
from modules.financial_approval.schemas import (
    BudgetPrefillResponse,
    BudgetSyncResultResponse,
    BudgetVarianceLogResponse,
    BudgetVarianceSettingResponse,
    CloneImportBudgetRequest,
    ClonePaymentRequestRequest,
    ImportBudgetCreate,
    ImportBudgetResponse,
    ImportBudgetUpdate,
    LinkedPOItemSchema,
    PaymentRequestCreate,
    PaymentRequestUpdate,
    SmartSwiftExtractRequest,
    SmartSwiftExtractResponse,
    SmartSwiftFileExtractRequest,
    SmartSwiftReconcileRequest,
    SwiftBatchConfirmRequest,
    SwiftBatchConfirmResponse,
    SwiftBatchMatchResponse,
    SwiftBatchReconcileRequest,
    SwiftBatchResponse,
    SwiftFieldResponse,
    SwiftFieldUpdateRequest,
    SwiftReconciliationRequest,
)
from modules.financial_approval.validators import (
    BATCH_CONFIRMED,
    BATCH_PENDING,
    BATCH_RECONCILED,
    BATCH_REJECTED,
    BUDGET_APPROVED,
    BUDGET_DRAFT,
    BUDGET_LOCKED,
    BUDGET_PENDING,
    BUDGET_REVALIDATION,
    BUDGET_SUPERSEDED,
    PAYMENT_APPROVE_FROM,
    PAYMENT_APPROVED,
    PAYMENT_CREATE_STATUSES,
    PAYMENT_DELETE_LOCKED,
    PAYMENT_DRAFT,
    PAYMENT_OPEN_STATUSES,
    PAYMENT_PAID,
    PAYMENT_PAY_FROM,
    PAYMENT_PENDING,
    PAYMENT_REJECTED,
    batch_status_error,
    budget_locked_error,
    fa_error,
    is_advance_payment,
    normalize_payment_type,
    require_budget_approvable,
    require_known_currency,
    require_payment_status,
    require_same_currency,
    validate_payment_rate,
    validate_payment_request_inputs,
    validate_payment_update,
    validate_po_ceiling,
)
from modules.notifications.model import SystemNotification
from modules.users.model import User

logger = logging.getLogger(__name__)

T = TypeVar("T")

CODE_ATTEMPTS = 3
MAX_SWIFT_FILE_MB = 10  # Q6
MAX_SWIFT_FILE_BYTES = MAX_SWIFT_FILE_MB * 1024 * 1024
VARIANCE_MIN_DIFF_EGP = 1.0
DEFAULT_VARIANCE_THRESHOLD = 5.0
VARIANCE_THRESHOLD_KEY = "variance_threshold_percentage"

# SWIFT / reconciliation data written only by pay / reconcile (ignored on PUT, C4). ``swift_code`` (the
# beneficiary BIC) is a normal editable field and is NOT in this set.
SERVER_OWNED_PAYMENT_FIELDS = frozenset({
    "swift_reference_no", "swift_receipt_date", "swift_transferred_amount", "swift_transferred_currency",
    "swift_variance_amount", "swift_variance_status", "swift_processing_days", "swift_reconciliation_notes",
})

L_PAYMENT = "طلب الصرف"
L_BUDGET = "الميزانية"
L_BATCH = "دفعة السويفت"
L_FILE = "ملف الاستيراد"

_COST_FIELDS: Tuple[Tuple[str, str, str], ...] = (
    # (budget column, prefill attribute, label used in the English audit notes)
    ("invoice_amount_egp", "total_invoice_amount_egp", "Invoice"),
    ("freight_cost_egp", "estimated_freight_cost_egp", "Freight"),
    ("customs_duties_egp", "estimated_customs_duties_egp", "Customs"),
    ("clearance_inland_egp", "estimated_clearance_fees_egp", "Clearance"),
)


# ==============================================================================
# SHARED HELPERS
# ==============================================================================


from .payment_request_service import (
    _get_payment, _get_budget, _get_batch, _file_codes, _attach_file_codes, _with_file_code,
    _now, _append_note, _insert_with_unique_code, _notify, _commercial_rate_to_egp,
    reconcile_swift_service, _ensure_swift_ref_unused, _apply_swift_receipt,
    _mark_paid, _after_paid, _finish_paid
)


# ==============================================================================
# SMART SWIFT MT103 EXTRACTION REVIEW LAYER
# ==============================================================================

_MANDATORY_SWIFT_FIELDS = (
    ("amount", "المبلغ المحول / Transferred Amount"),
    ("currency", "العملة / Currency"),
    ("beneficiary_name", "اسم المستفيد / Beneficiary Name"),
    ("beneficiary_account_or_iban", "رقم حساب أو آيبان المستفيد / Account or IBAN"),
    ("transaction_reference", "الرقم المرجعي للسويفت / SWIFT Reference"),
)



def _build_batch_response(batch: SwiftExtractionBatch) -> SwiftBatchResponse:
    """Batch with its fields and the mandatory-field validation."""
    field_map = {f.field_key: f for f in batch.fields}
    missing_mandatory = []
    for key, label in _MANDATORY_SWIFT_FIELDS:
        fld = field_map.get(key)
        val = (fld.final_value or "").strip() if fld else ""
        if not val:
            missing_mandatory.append(label)
        elif key == "amount":
            try:
                if float(val) <= 0:
                    missing_mandatory.append(label)
            except ValueError:
                missing_mandatory.append(label)

    return SwiftBatchResponse(
        batch_id=batch.batch_id,
        batch_code=batch.batch_code,
        source_filename=batch.source_filename,
        source_file_type=batch.source_file_type,
        raw_source_text=batch.raw_source_text,
        normalized_text=batch.normalized_text,
        status=batch.status,
        reviewed_by=batch.reviewed_by,
        reviewed_at=batch.reviewed_at,
        matched_payment_id=batch.matched_payment_id,
        reconciled_at=batch.reconciled_at,
        fields=[SwiftFieldResponse.model_validate(f) for f in batch.fields],
        all_mandatory_valid=not missing_mandatory,
        missing_mandatory_fields=missing_mandatory,
        created_at=batch.created_at,
        updated_at=batch.updated_at,
    )


def _rank_candidates(requests: List[PaymentRequestSession], parsed: Dict[str, Any],
                     target_payment_id: Optional[int]) -> Tuple[Optional[dict], List[dict]]:
    """Scores every request against the SWIFT data. The target request always wins; else the highest score.
    Returns (best match, top 10 by score)."""
    from modules.financial_approval.swift_mt103_parser import match_swift_against_payment_request

    candidates: List[dict] = []
    best_match = None
    highest_score = -1
    for req in requests:
        info = match_swift_against_payment_request(parsed, req)
        candidates.append(info)
        if target_payment_id and req.payment_id == target_payment_id:
            best_match, highest_score = info, 999
        elif info["confidence_score"] > highest_score:
            best_match, highest_score = info, info["confidence_score"]
    candidates.sort(key=lambda x: x["confidence_score"], reverse=True)
    return best_match, candidates[:10]


def extract_swift_for_review_service(
    db: Session, raw_text: str, filename: Optional[str] = None, file_type: Optional[str] = None,
) -> SwiftBatchResponse:
    """Extracts SWIFT fields and stores a batch in EXTRACTED_PENDING_REVIEW."""
    from modules.financial_approval.swift_file_extractor import normalize_swift_ocr_text
    from modules.financial_approval.swift_mt103_parser import extract_swift_fields_breakdown

    normalized = normalize_swift_ocr_text(raw_text)
    breakdown = extract_swift_fields_breakdown(normalized if normalized.strip() else raw_text)
    fields_data = breakdown.get("fields", [])

    batch = _insert_with_unique_code(
        db,
        lambda: repo.next_swift_batch_code(db),
        lambda c: repo.swift_batch_code_exists(db, c),
        lambda code: repo.add_swift_extraction_batch(db, code, raw_text, normalized, filename, file_type, fields_data),
    )
    return _build_batch_response(batch)


def get_swift_batch_review_service(db: Session, batch_id: int) -> SwiftBatchResponse:
    return _build_batch_response(_get_batch(db, batch_id))


def _require_batch_editable(batch: SwiftExtractionBatch) -> None:
    if batch.status in (BATCH_RECONCILED, BATCH_REJECTED):
        raise batch_status_error(batch, status.HTTP_400_BAD_REQUEST)


def update_swift_batch_field_service(
    db: Session, batch_id: int, field_key: str, payload: SwiftFieldUpdateRequest, acting_user: str = "System",
) -> SwiftBatchResponse:
    """Stores a user edit (OCR correction log by ``acting_user``; ``payload.user_name`` is ignored). An edit of a
    confirmed batch sends it back to review (FA-06c)."""
    batch = _get_batch(db, batch_id)
    _require_batch_editable(batch)
    updated = repo.update_swift_batch_field(db, batch_id, field_key, payload.value, user_name=acting_user)
    if updated is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail=f"الحقل '{field_key}' غير موجود في دفعة السويفت رقم {batch_id}.")
    if batch.status == BATCH_CONFIRMED:
        repo.reopen_swift_batch_review(db, batch)
    else:
        batch.updated_at = _now()
    db.commit()
    db.refresh(batch)
    return _build_batch_response(batch)


def re_extract_single_field_service(db: Session, batch_id: int, field_key: str) -> SwiftBatchResponse:
    """Re-runs the parser for one field from the source text (a confirmed batch goes back to review)."""
    from modules.financial_approval.swift_mt103_parser import extract_swift_fields_breakdown

    batch = _get_batch(db, batch_id)
    _require_batch_editable(batch)
    text_to_parse = batch.normalized_text if batch.normalized_text and batch.normalized_text.strip() else batch.raw_source_text
    breakdown = extract_swift_fields_breakdown(text_to_parse)
    field_item = next((f for f in breakdown.get("fields", []) if f["field_key"] == field_key), None)
    if not field_item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail=f"تعذر إعادة استخراج الحقل '{field_key}'.")

    p_val = field_item.get("parsed_value")
    p_val_str = str(p_val) if p_val is not None else ""
    fld = next((f for f in batch.fields if f.field_key == field_key), None)
    if fld:
        fld.parsed_value = p_val_str
        fld.final_value = p_val_str
        fld.confidence_score = float(field_item.get("confidence_score", 0.0))
        fld.raw_ocr_text = field_item.get("raw_ocr_text")
        fld.is_edited_by_user = False
        fld.edited_value = None
        fld.is_empty = not bool(p_val_str.strip())
        fld.updated_at = _now()
        if batch.status == BATCH_CONFIRMED:
            repo.reopen_swift_batch_review(db, batch)
        db.commit()
        db.refresh(batch)
    return _build_batch_response(batch)


def confirm_swift_batch_review_service(
    db: Session, batch_id: int, payload: SwiftBatchConfirmRequest, acting_user: str = "System",
) -> SwiftBatchConfirmResponse:
    """EXTRACTED_PENDING_REVIEW -> REVIEWED_CONFIRMED when every mandatory field is valid (400 otherwise).
    The reviewer is ``acting_user`` (``payload.user_name`` is ignored)."""
    batch = _get_batch(db, batch_id)
    if batch.status != BATCH_PENDING:
        raise batch_status_error(batch)

    batch_resp = _build_batch_response(batch)
    if not batch_resp.all_mandatory_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"تعذر تأكيد مراجعة السويفت: حقول إجبارية مفقودة أو غير صالحة: {', '.join(batch_resp.missing_mandatory_fields)}",
        )

    repo.mark_swift_batch_reviewed(db, batch, acting_user)
    db.commit()
    db.refresh(batch)
    return SwiftBatchConfirmResponse(
        success=True,
        batch_id=batch.batch_id,
        batch_code=batch.batch_code,
        status=batch.status,
        message="تم تأكيد صحة بيانات السويفت بنجاح وتم فتح مصفوفة المطابقة المالية.",
        message_code="FA_SWIFT_BATCH_CONFIRMED",
        message_params={"batch_code": batch.batch_code},
        confirmed_fields={f.field_key: f.final_value for f in batch.fields},
        batch=_build_batch_response(batch),
    )


def match_reviewed_batch_service(db: Session, batch_id: int, target_payment_id: Optional[int] = None) -> SwiftBatchMatchResponse:
    """Matches a confirmed batch (``final_value`` only) against Approved requests without a SWIFT reference
    (plus the target request). 409 before the review is confirmed."""
    batch = _get_batch(db, batch_id)
    if batch.status not in (BATCH_CONFIRMED, BATCH_RECONCILED):
        raise batch_status_error(batch)

    confirmed = {f.field_key: f.final_value for f in batch.fields}
    parsed = dict(confirmed)
    try:
        parsed["amount"] = float(confirmed.get("amount") or 0.0)
    except (TypeError, ValueError):
        parsed["amount"] = 0.0

    best_match, top = _rank_candidates(repo.get_matchable_payment_requests(db, target_payment_id), parsed, target_payment_id)
    return SwiftBatchMatchResponse(
        success=True,
        batch_id=batch.batch_id,
        status=batch.status,
        matched_payment_request=best_match,
        candidate_matches=top,
        confirmed_fields=confirmed,
    )


def reconcile_reviewed_batch_service(
    db: Session, batch_id: int, payload: SwiftBatchReconcileRequest, acting_user: str = "System",
) -> PaymentRequestSession:
    """Reconciles a confirmed batch (``final_value`` only) against an Approved request.
    403 before the review is confirmed; a RECONCILED batch is accepted again only for the same request
    (idempotent), else 409 FA_SWIFT_BATCH_ALREADY_RECONCILED."""
    batch = _get_batch(db, batch_id)
    if batch.status == BATCH_RECONCILED:
        if batch.matched_payment_id == payload.payment_id:
            return _with_file_code(db, _get_payment(db, payload.payment_id))
        matched = db.query(PaymentRequestSession).filter(PaymentRequestSession.payment_id == batch.matched_payment_id).first()
        matched_code = matched.payment_code if matched else None
        raise fa_error(
            status.HTTP_409_CONFLICT,
            "FA_SWIFT_BATCH_ALREADY_RECONCILED",
            f"دفعة السويفت {batch.batch_code} مطابقة بالفعل مع طلب الصرف {matched_code}.",
            batch_code=batch.batch_code,
            payment_code=matched_code,
        )
    if batch.status != BATCH_CONFIRMED:
        raise batch_status_error(batch)

    db_item = _get_payment(db, payload.payment_id)
    require_payment_status(db_item, PAYMENT_PAY_FROM, "reconcile")

    field_map = {f.field_key: f.final_value for f in batch.fields}
    swift_ref = (field_map.get("transaction_reference") or "").strip()
    if not swift_ref:
        raise batch_status_error(batch, status.HTTP_400_BAD_REQUEST)
    raw_date = field_map.get("value_date")
    raw_date_str = str(raw_date).strip() if raw_date is not None else ""
    if not raw_date_str:
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_SWIFT_VALUE_DATE_INVALID",
            f"تاريخ القيمة '{raw_date_str}' في دفعة السويفت {batch.batch_code} غير صالح أو غير مدخل بصيغة YYYY-MM-DD.",
            batch_code=batch.batch_code,
            value=raw_date_str,
        )
    try:
        receipt_date = datetime.strptime(raw_date_str, "%Y-%m-%d").date()
    except ValueError:
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_SWIFT_VALUE_DATE_INVALID",
            f"تاريخ القيمة '{raw_date_str}' في دفعة السويفت {batch.batch_code} غير صالح أو غير مدخل بصيغة YYYY-MM-DD.",
            batch_code=batch.batch_code,
            value=raw_date_str,
        )
    try:
        amount = float(field_map.get("amount") or db_item.requested_amount)
    except (TypeError, ValueError):
        amount = float(db_item.requested_amount)
    currency = field_map.get("currency") or db_item.currency_code
    require_same_currency(currency, db_item.currency_code)
    _ensure_swift_ref_unused(db, swift_ref, db_item)

    db_item.swift_reference_no = swift_ref
    _apply_swift_receipt(db_item, amount, currency, receipt_date)
    # The request stores the BENEFICIARY bank SWIFT (:57A), never the sender / issuing bank.
    if field_map.get("beneficiary_bank_swift"):
        db_item.swift_code = field_map["beneficiary_bank_swift"]
    if field_map.get("beneficiary_account_or_iban"):
        db_item.iban_account_no = field_map["beneficiary_account_or_iban"]

    recon_notes = []
    if payload.notes:
        recon_notes.append(payload.notes)
    sender_swift, sender_bank = field_map.get("sender_bank_swift"), field_map.get("sender_bank_name")
    if sender_swift or sender_bank:
        recon_notes.append(f"Executing bank in Egypt: {sender_bank or ''} ({sender_swift or ''})".strip())
    if recon_notes:
        db_item.swift_reconciliation_notes = " | ".join(recon_notes)

    event = None
    if payload.auto_execute:
        event = _mark_paid(db, db_item, swift_ref, amount, currency, receipt_date=receipt_date)
    else:
        db_item.version = (db_item.version or 1) + 1
        db_item.updated_at = _now()
    repo.mark_swift_batch_reconciled(db, batch, db_item.payment_id)
    db.commit()
    if event is not None:
        return _finish_paid(db, event)
    db.refresh(db_item)
    return _with_file_code(db, db_item)


def smart_extract_swift_service(db: Session, payload: SmartSwiftExtractRequest) -> SmartSwiftExtractResponse:
    """Parses pasted MT103 text, stores a review batch and ranks the candidate requests."""
    from modules.financial_approval.swift_mt103_parser import parse_swift_mt103_text

    parsed = parse_swift_mt103_text(payload.raw_text)
    if not parsed.get("success"):
        return SmartSwiftExtractResponse(
            success=False, parsed_swift={}, matched_payment_request=None, candidate_matches=[],
            error=parsed.get("error", "Failed to parse SWIFT MT103 text"),
        )

    batch_resp = extract_swift_for_review_service(db, payload.raw_text, "pasted_swift_text.txt", "Text Input")
    best_match, top = _rank_candidates(
        repo.get_matchable_payment_requests(db, payload.target_payment_id), parsed, payload.target_payment_id
    )
    return SmartSwiftExtractResponse(
        success=True,
        parsed_swift=parsed,
        matched_payment_request=best_match,
        candidate_matches=top,
        raw_text=payload.raw_text,
        batch_id=batch_resp.batch_id,
        batch=batch_resp,
    )


def _require_file_size(size: int) -> None:
    import sys
    svc = sys.modules.get("modules.financial_approval.service")
    max_bytes = getattr(svc, "MAX_SWIFT_FILE_BYTES", MAX_SWIFT_FILE_BYTES) if svc else MAX_SWIFT_FILE_BYTES
    if size > max_bytes:
        raise fa_error(
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            "FA_SWIFT_FILE_TOO_LARGE",
            f"حجم ملف السويفت يتجاوز الحد المسموح ({MAX_SWIFT_FILE_MB} ميجابايت).",
            max_mb=MAX_SWIFT_FILE_MB,
        )


def smart_extract_swift_from_file_service(
    db: Session, filename: str, content_bytes: bytes, target_payment_id: Optional[int] = None,
) -> SmartSwiftExtractResponse:
    """Extracts text from a Word, Excel, PDF or image file (413 above the size cap), stores a review batch and
    ranks the candidate requests."""
    from modules.financial_approval.swift_file_extractor import extract_text_from_swift_file
    from modules.financial_approval.swift_mt103_parser import parse_swift_mt103_text

    _require_file_size(len(content_bytes))
    raw_text, normalized_text = extract_text_from_swift_file(filename, content_bytes)
    if not normalized_text.strip() and not raw_text.strip():
        return SmartSwiftExtractResponse(
            success=False, parsed_swift={}, matched_payment_request=None, candidate_matches=[], raw_text="",
            detected_filename=filename,
            error=f"Could not extract readable text from file '{filename}'. Ensure the file is not empty or corrupted.",
        )

    parsed = parse_swift_mt103_text(normalized_text if normalized_text.strip() else raw_text)
    lower = filename.lower()
    if lower.endswith(".pdf"):
        f_type = "PDF Document"
    elif lower.endswith((".docx", ".doc")):
        f_type = "Word Document"
    elif lower.endswith((".xlsx", ".xls", ".csv")):
        f_type = "Excel Spreadsheet"
    elif lower.endswith((".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff", ".tif")):
        f_type = "Image / Scanned Slip (OCR)"
    else:
        f_type = "Text File"

    source_text = raw_text if raw_text.strip() else normalized_text
    batch_resp = extract_swift_for_review_service(db, source_text, filename, f_type)
    best_match, top = _rank_candidates(repo.get_matchable_payment_requests(db, target_payment_id), parsed, target_payment_id)
    return SmartSwiftExtractResponse(
        success=parsed.get("success", True),
        parsed_swift=parsed,
        matched_payment_request=best_match,
        candidate_matches=top,
        raw_text=source_text,
        detected_filename=filename,
        detected_file_type=f_type,
        batch_id=batch_resp.batch_id,
        batch=batch_resp,
    )


def smart_extract_swift_from_base64_service(db: Session, payload: SmartSwiftFileExtractRequest) -> SmartSwiftExtractResponse:
    """Base64 variant: 413 above the size cap (checked before decoding too), 400 FA_SWIFT_FILE_INVALID_BASE64."""
    encoded = payload.file_base64 or ""
    _require_file_size((len(encoded) * 3) // 4 - 2)
    try:
        content_bytes = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError):
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_SWIFT_FILE_INVALID_BASE64",
            "محتوى الملف المرسل ليس بصيغة Base64 صالحة.",
        )
    return smart_extract_swift_from_file_service(db, payload.filename, content_bytes, payload.target_payment_id)
