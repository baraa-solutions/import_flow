"""
Business Validation Rules for Import Documentation & ACI (Phase 3 - BP-014 to BP-019)
"""

import os
from datetime import date
from typing import Any, Dict, FrozenSet, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session


def validate_acid_number(acid_number: str | None, allow_pending: bool = True):
    """
    Validates Egyptian Nafeza ACID Number structure:
    Must be exactly 19 numeric digits when issued, or PENDING during initial request stage.
    """
    if not acid_number:
        if allow_pending:
            return
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="ACID Number is required.",
        )
    cleaned = acid_number.strip()
    if allow_pending and cleaned.upper() in ["PENDING", "REQUESTED", "DRAFT", ""]:
        return
    if len(cleaned) != 19 or not cleaned.isdigit():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid ACID Number '{acid_number}'. Egyptian Nafeza ACID must be exactly 19 numeric digits.",
        )


def validate_acid_expiry(expiry_date: date | None, issue_date: date | None = None):
    """
    Validates that ACID expiry date is in the future.
    """
    if not expiry_date:
        return
    ref_date = issue_date or date.today()
    if expiry_date <= ref_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"ACID Expiry Date ({expiry_date}) must be after Issue/Requested Date ({ref_date}).",
        )


def acid_flags(
    discrepancies_data: Optional[Any],
) -> Tuple[bool, bool, bool, bool, bool]:
    """
    Derives (importer_matched, exporter_matched, invoice_matched, ports_matched, has_discrepancies)
    from discrepancies_data (BE03-T06).
    A key counts as a mismatch when its entry has match False / is_matched False / status not "MATCH".
    """
    importer_matched = True
    exporter_matched = True
    invoice_matched = True
    ports_matched = True
    has_discrepancies = False

    if not discrepancies_data:
        return importer_matched, exporter_matched, invoice_matched, ports_matched, has_discrepancies

    def _is_mismatch(val: Any) -> bool:
        if isinstance(val, bool):
            return not val
        if isinstance(val, dict):
            if "match" in val and val["match"] is False:
                return True
            if "is_matched" in val and val["is_matched"] is False:
                return True
            if "is_match" in val and val["is_match"] is False:
                return True
            if "status" in val and val["status"] is not None:
                s = str(val["status"]).strip().upper()
                if s not in ("MATCH", "MATCHED", "OK", "CORRECT"):
                    return True
            if val.get("severity") in ("error", "critical") and val.get("match") is not True and val.get("is_matched") is not True:
                return True
            return False
        if isinstance(val, str):
            s = val.strip().upper()
            return s in ("MISMATCH", "ERROR", "CRITICAL", "FAILED", "FALSE")
        return False

    raw_items: List[Any] = []
    if isinstance(discrepancies_data, dict):
        if "all_matched" in discrepancies_data and discrepancies_data["all_matched"] is False:
            has_discrepancies = True
        if discrepancies_data.get("has_critical_error") is True:
            has_discrepancies = True
        if (discrepancies_data.get("discrepant_count") or 0) > 0:
            has_discrepancies = True

        if "items" in discrepancies_data and isinstance(discrepancies_data["items"], list):
            raw_items = discrepancies_data["items"]
        else:
            summary_keys = {"all_matched", "has_critical_error", "discrepant_count"}
            raw_items = [
                {"field": k, "entry": v} for k, v in discrepancies_data.items() if k not in summary_keys
            ]
    elif isinstance(discrepancies_data, list):
        raw_items = discrepancies_data

    for item in raw_items:
        if isinstance(item, dict):
            field = item.get("field") or item.get("key") or item.get("field_key")
            val = item.get("entry") if "entry" in item else item
            if _is_mismatch(val):
                has_discrepancies = True
                k = str(field or "").lower()
                if "importer" in k:
                    importer_matched = False
                elif any(w in k for w in ("exporter", "supplier", "cargox")):
                    exporter_matched = False
                elif any(w in k for w in ("invoice", "proforma")):
                    invoice_matched = False
                elif any(w in k for w in ("port", "pol", "pod")):
                    ports_matched = False
        elif _is_mismatch(item):
            has_discrepancies = True

    if not (importer_matched and exporter_matched and invoice_matched and ports_matched):
        has_discrepancies = True

    return importer_matched, exporter_matched, invoice_matched, ports_matched, has_discrepancies


def validate_no_duplicate_acid_session(
    db: Session,
    import_file_id: int | None,
    current_acid_id: int | None = None,
):
    """
    Prevents creating duplicate active ACID registration sessions for the same Import File.
    Directs user to edit the existing session instead of creating a new one.
    """
    if not import_file_id:
        return

    from modules.import_documentation.model import AcidRegistrationSession

    query = db.query(AcidRegistrationSession).filter(
        AcidRegistrationSession.import_file_id == import_file_id,
        AcidRegistrationSession.is_active == True,
    )
    if current_acid_id is not None:
        query = query.filter(AcidRegistrationSession.acid_id != current_acid_id)

    existing = query.first()
    if existing:
        ref_display = f" - رقم ACID: {existing.acid_number}" if existing.acid_number and existing.acid_number != "PENDING" else ""
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"لا يمكن حفظ طلب ACID جديد لأن ملف الشحنة مرتبط بالفعل بجلسة مسجلة ومحفوظة "
                f"في سجل الطلبات (كود الجلسة: {existing.acid_code}{ref_display}). "
                f"يرجى التوجه إلى سجل الطلبات والإصدار للتعديل على الجلسة الحالية بدلاً من إنشاء طلب جديد."
            ),
        )


def validate_no_duplicate_form4_session(
    db: Session,
    import_file_id: int | None,
    current_doc_id: int | None = None,
):
    """
    Prevents creating duplicate active Form 4 requests for the same Import File.
    Directs user to edit the existing session instead of creating a new one.
    """
    if not import_file_id:
        return

    from modules.import_documentation.model import BankingDocumentSession

    query = db.query(BankingDocumentSession).filter(
        BankingDocumentSession.import_file_id == import_file_id,
        BankingDocumentSession.doc_type == "Form 4",
        BankingDocumentSession.is_active == True,
    )
    if current_doc_id is not None:
        query = query.filter(BankingDocumentSession.bank_doc_id != current_doc_id)

    existing = query.first()
    if existing:
        ref_display = f" - رقم النموذج: {existing.doc_reference_number}" if existing.doc_reference_number and existing.doc_reference_number != "PENDING" else ""
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"لا يمكن حفظ طلب نموذج 4 جديد لأن ملف الشحنة مرتبط بالفعل بجلسة مسجلة ومحفوظة "
                f"في سجل النماذج (كود الطلب: {existing.bank_doc_code}{ref_display}). "
                f"يرجى التوجه إلى سجل النماذج للتعديل على الطلب الحالي بدلاً من إنشاء طلب جديد."
            ),
        )


def validate_no_duplicate_declaration_draft(
    db: Session,
    import_file_id: int | None,
    current_declaration_id: int | None = None,
) -> None:
    """
    Prevents creating duplicate active Customs Declaration 46 drafts for the same Import File (BE03-F14).
    """
    if not import_file_id:
        return

    from modules.import_documentation.model import CustomsDeclarationDraft

    query = db.query(CustomsDeclarationDraft).filter(
        CustomsDeclarationDraft.import_file_id == import_file_id,
        CustomsDeclarationDraft.is_active == True,
    )
    if current_declaration_id is not None:
        query = query.filter(CustomsDeclarationDraft.declaration_id != current_declaration_id)

    existing = query.first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"يوجد بالفعل مسودة إقرار جمركي (شهادة 46) نشطة لهذا الملف ({existing.declaration_code}). "
                f"لا يمكن إنشاء أكثر من مسودة نشطة لنفس الملف."
            ),
        )


# --- BE03-F15: Allowed Banking Document Types ---
BANKING_DOC_TYPES: FrozenSet[str] = frozenset({"Form 4", "Form 9", "Letter of Credit (L/C)"})


def validate_currency_code(db: Session, value: Any) -> str:
    """Active ISO currency code or 400 (DOC-13 / BE03-F15)."""
    from modules.currencies.model import Currency
    from modules.common import enum_codes

    code = str(enum_codes.normalize_currency(value) or "").strip().upper()
    found = (
        db.query(Currency.currency_id)
        .filter(Currency.currency_code == code, Currency.is_active == True)
        .first()
        if code
        else None
    )
    if not found:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"رمز العملة '{value}' غير معروف أو غير نشط في جدول العملات.",
        )
    return code


# --- DOC-14: status whitelists (today's exact stored values; no recoding in this wave) ---------------------
# Each set holds every value the server writes, the workflow trigger lists react to, and the Flutter client sends.
STATUS_WHITELISTS: Dict[str, FrozenSet[str]] = {
    "acid": frozenset({
        "Requested", "Pending Issue", "DRAFT", "Generated", "Issued", "ACID Issued", "Verified",
        "Discrepancy_Accepted",
    }),
    "banking": frozenset({
        "Requested", "Received", "Approved by Bank", "Form Issued", "Verified", "Endorsed",
    }),
    "shipment_doc": frozenset({"Approved", "Endorsed"}),
    "draft_bl": frozenset({
        "DRAFT", "AUTO_COMPARISON_RUN", "REVISION_REQUIRED", "REVIEWED_PENDING_APPROVAL", "APPROVED", "FINAL",
    }),
    "coo": frozenset({
        "Draft Generated", "Verified", "Discrepancy_Accepted", "Correction Requested", "Approved",
    }),
    "inspection": frozenset({
        "Required_Draft_Generated", "Draft Generated", "Verified", "Discrepancy_Accepted", "Correction Requested",
        "Approved",
    }),
    "reconciliation": frozenset({
        "FULLY_MATCHED", "ACCEPTED_WITH_WARNINGS", "CRITICAL_VARIANCE", "CRITICAL_DISCREPANCY", "DRAFT",
        "MATCHED", "APPROVED", "CERTIFIED", "PASS", "CONFORMING",
    }),
    "invoice_bl": frozenset({
        "FULLY_MATCHED", "ACCEPTED_WITH_WARNINGS", "DISCREPANCY_DETECTED", "DRAFT_SAVED", "CERTIFIED_SAVED",
    }),
}

_STATUS_KIND_LABELS_AR: Dict[str, str] = {
    "acid": "جلسة ACID",
    "banking": "المستند البنكي",
    "shipment_doc": "مستند الشحنة",
    "draft_bl": "مراجعة مسودة البوليصة",
    "coo": "مراجعة شهادة المنشأ",
    "inspection": "مراجعة شهادة الفحص",
    "reconciliation": "جلسة مطابقة الفاتورة وقائمة التعبئة",
    "invoice_bl": "جلسة مطابقة الفاتورة والبوليصة",
}


def validate_status(kind: str, value: Optional[str]) -> Optional[str]:
    """Return ``value`` when it is None or one of today's values for ``kind``; otherwise 400 (Arabic).
    "All" is never a stored status (it is only a list filter), so it is rejected too."""
    if value is None:
        return None
    allowed = STATUS_WHITELISTS[kind]
    if value not in allowed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"قيمة الحالة '{value}' غير مسموح بها في {_STATUS_KIND_LABELS_AR[kind]}. "
                f"القيم المسموح بها: {', '.join(sorted(allowed))}."
            ),
        )
    return value


# --- DOC-16: uploaded files ------------------------------------------------------------------------------------
MAX_UPLOAD_BYTES = 20 * 1024 * 1024  # same limit as modules/smart_document_upload/validators.py
ALLOWED_UPLOAD_EXTENSIONS: FrozenSet[str] = frozenset({
    ".pdf", ".docx", ".doc", ".xlsx", ".xls", ".txt", ".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp",
})


def validate_upload(filename: Optional[str], content: bytes) -> str:
    """Return the stripped filename of an acceptable upload: a name with an allowed extension (400 otherwise)
    and at most ``MAX_UPLOAD_BYTES`` bytes (413 otherwise). Nothing is written to disk."""
    name = (filename or "").strip()
    if not name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="يجب أن يكون للملف المرفوع اسم.")
    ext = os.path.splitext(name)[1].lower()
    if ext not in ALLOWED_UPLOAD_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"صيغة الملف '{ext or name}' غير مدعومة. الصيغ المسموح بها: "
                f"{', '.join(sorted(e.lstrip('.') for e in ALLOWED_UPLOAD_EXTENSIONS))}."
            ),
        )
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"حجم الملف '{name}' يتجاوز الحد الأقصى المسموح به ({MAX_UPLOAD_BYTES // (1024 * 1024)} ميجابايت).",
        )
    return name


def validate_unique_po_lines(line_items: list) -> None:
    """Each PO line must be adjusted at most once per request (BE03-T01). Duplicate -> 400."""
    seen_po_item_ids = set()
    for itm in line_items:
        po_item_id = getattr(itm, "po_item_id", None)
        if po_item_id is not None:
            if po_item_id in seen_po_item_ids:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"بند أمر الشراء رقم {po_item_id} مكرر في طلب المطابقة.",
                )
            seen_po_item_ids.add(po_item_id)


# --- BE03-T14: raw text limits ---------------------------------------------------------------------------------
MAX_RAW_TEXT_CHARS = 200_000


def validate_raw_text_length(text: Optional[str], field_name: str = "raw_text") -> Optional[str]:
    """Ensures raw text does not exceed MAX_RAW_TEXT_CHARS (422 otherwise)."""
    if text and len(text) > MAX_RAW_TEXT_CHARS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"النص المدخل في الحقل '{field_name}' يتجاوز الحد الأقصى المسموح به ({MAX_RAW_TEXT_CHARS:,} حرف).",
        )
    return text

