"""
Business Validation Rules for Import Documentation & ACI (Phase 3 - BP-014 to BP-019)
"""

import os
from datetime import date
from typing import Dict, FrozenSet, Optional

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
