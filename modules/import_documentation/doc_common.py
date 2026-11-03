"""
Common definitions, constants, and helper utilities for Import Documentation services.
"""

import difflib
import logging
import re
from typing import Any, Dict, List, Optional, Set, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from modules.common.errors import best_effort
from modules.common.validators import not_found, require_active
from modules.import_files.model import ImportFile
from modules.import_documentation.validators import validate_currency_code

logger = logging.getLogger(__name__)

_validate_currency_code = validate_currency_code

# Day thresholds (DOC-21): module constants now, system_parameters later (Q9).
ACID_DEFAULT_VALIDITY_DAYS = 90
ACID_EXPIRING_SOON_DAYS = 14
DEFAULT_ETA_DAYS = 21
ETA_SAFETY_MARGIN_DAYS = 30
COMPANY_DOC_EXPIRING_SOON_DAYS = 60

# Actor recorded when a service runs without a logged-in user (internal call / job).
SYSTEM_ACTOR = "system"

LABEL_IMPORT_FILE = "ملف الاستيراد"
LABEL_PURCHASE_ORDER = "أمر الشراء"
LABEL_ACID_SESSION = "جلسة تسجيل ACID"
LABEL_BANKING_DOC = "المستند البنكي"
LABEL_SHIPMENT_DOC = "مستند الشحن"
LABEL_DRAFT_BL_REVIEW = "مراجعة مسودة البوليصة"
LABEL_COO_REVIEW = "مراجعة شهادة المنشأ"
LABEL_INSPECTION_REVIEW = "مراجعة شهادة الفحص"
LABEL_PO_RECON_SESSION = "جلسة المطابقة"
LABEL_INVOICE_BL_SESSION = "جلسة مطابقة الفاتورة والبوليصة"

# Draft B/L review statuses that end the workflow (FINAL from approval, APPROVED from legacy certified saves).
DRAFT_BL_TERMINAL_STATUSES = frozenset({"FINAL", "APPROVED"})
DRAFT_BL_APPROVAL_ROLES = frozenset({"importer", "customs_broker"})
DRAFT_BL_APPROVAL_ACTIONS = frozenset({"Approved", "Rejected"})
# Client-sent fields the server owns on a draft B/L review (DOC-04 / C2 / BE03-T07).
_DRAFT_BL_SERVER_OWNED = (
    "status", "stage",
    "has_blocking_mismatch", "open_discrepancies_count", "revision_report_data",
    "importer_approval_status", "importer_approved_by", "importer_approval_date", "importer_approval_notes",
    "broker_approval_status", "broker_approved_by", "broker_approval_date", "broker_approval_notes",
    "approved_by", "approved_at", "reviewed_by", "reviewed_at",
)
PO_FINAL_STATUSES = frozenset({"CLOSED", "CANCELLED"})


def _actor(user: Optional[str], legacy: Optional[str] = None) -> str:
    """The acting user name: the logged-in ``user`` passed by the router. ``legacy`` (a client-sent identity field)
    is used only by internal callers that pass no user; HTTP routes always pass ``user`` (contract C3)."""
    return (user or "").strip() or (legacy or "").strip() or SYSTEM_ACTOR


def _bad_request(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def _conflict(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


def _active_import_file(db: Session, import_file_id: Any, status_code: int = status.HTTP_400_BAD_REQUEST) -> ImportFile:
    """Active import file or HTTPException (DOC-18): writes use 400, reads of a path id use 404."""
    if import_file_id is None:
        raise HTTPException(status_code=status_code, detail=f"{LABEL_IMPORT_FILE} مطلوب.")
    return require_active(db, ImportFile, import_file_id, LABEL_IMPORT_FILE, status_code=status_code)


def _get_active_import_file(db: Session, import_file_id: Any) -> Optional[ImportFile]:
    """Active import file or None (read paths that tolerate a missing file)."""
    if not import_file_id:
        return None
    return db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id, ImportFile.is_active == True).first()


def _check_acid_conflict(db: Session, import_file_id: Optional[int], acid_number: Optional[str]) -> None:
    """Rejects linking or updating an ACID session with a different 19-digit number than the file has (BE03-T06)."""
    if not import_file_id or not acid_number:
        return
    acid_clean = acid_number.strip()
    if len(acid_clean) != 19 or not acid_clean.isdigit():
        return
    imp = _get_active_import_file(db, import_file_id)
    if not imp:
        return
    current_acid = (imp.acid_number or "").strip()
    if len(current_acid) == 19 and current_acid.isdigit() and current_acid != acid_clean:
        file_code = imp.import_file_code or imp.custom_file_number or f"IMP-{imp.import_file_id}"
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "DOC_ACID_CONFLICT",
                "message": f"رقم الـ ACID ({acid_clean}) يختلف عن الرقم المسجل على الملف ({current_acid}).",
                "acid_number": acid_clean,
                "current_acid_number": current_acid,
                "import_file_code": file_code,
            },
        )


def _require_active_po(db: Session, po_id: Any) -> None:
    if po_id is not None:
        from modules.purchase_orders.model import PurchaseOrder as _PO
        require_active(db, _PO, po_id, LABEL_PURCHASE_ORDER)


def _to_float(value: Any, field_label: str) -> float:
    """``float(value)`` or 400 with an Arabic detail (DOC-07 / DOC-13 number guards)."""
    try:
        return float(value)
    except (TypeError, ValueError):
        raise _bad_request(f"قيمة غير صالحة للحقل '{field_label}': {value}")


def _field_accepts_none(model: Any, field: str) -> bool:
    info = model.model_fields.get(field)
    return info is not None and not info.is_required()


def _commit_follow_up(db: Session, fn: Any, label: str, *args: Any, **kwargs: Any) -> None:
    """``errors.best_effort`` for a follow-up step that commits its own work after the main commit (DOC-11)."""

    def _run() -> None:
        fn(*args, **kwargs)
        db.commit()

    best_effort(db, _run, label)


def _lifecycle_follow_up(db: Session, label: str, **kwargs: Any) -> None:
    """Best-effort lifecycle advance after the main commit (the lifecycle service commits its own work)."""
    from modules.lifecycle_board.service import advance_lifecycle_step_service
    best_effort(db, lambda: advance_lifecycle_step_service(db=db, **kwargs), label)


def get_import_files_map(db: Session, file_ids: Any) -> Dict[int, ImportFile]:
    """Efficient bulk retrieval of ImportFile instances indexed by import_file_id."""
    clean_ids = {fid for fid in file_ids if fid}
    if not clean_ids:
        return {}
    files = db.query(ImportFile).filter(ImportFile.import_file_id.in_(clean_ids)).all()
    return {f.import_file_id: f for f in files}


def _normalize_str(s: Any) -> str:
    if s is None:
        return ""
    st = str(s).strip()
    # Strip leading country-code + registration ID or numeric tax ID if present before company name
    st = re.sub(r'^[A-Z]{2}\d{6,15}[,\s]+|^\d{8,15}[,\s]+', '', st, flags=re.I)
    return " ".join(st.lower().split())


def _fuzzy_match(s1: Any, s2: Any, threshold: float = 0.70) -> tuple[bool, float]:
    n1 = _normalize_str(s1)
    n2 = _normalize_str(s2)
    if not n1 and not n2:
        return True, 1.0
    if not n1 or not n2:
        return False, 0.0
    if n1 == n2 or n1 in n2 or n2 in n1:
        return True, 1.0
    ratio = difflib.SequenceMatcher(None, n1, n2).ratio()
    w1 = set(n1.split())
    w2 = set(n2.split())
    if w1 and w2:
        overlap = len(w1.intersection(w2)) / max(len(w1), len(w2))
        if overlap >= 0.50:
            return True, max(ratio, overlap)
    return ratio >= threshold, ratio


def _numeric_match(val1: Any, val2: Any, tolerance_pct: float = 0.5) -> tuple[bool, float, float]:
    try:
        f1 = float(val1 or 0.0)
        f2 = float(val2 or 0.0)
    except (ValueError, TypeError):
        return False, 100.0, 0.0
    if f1 == 0.0 and f2 == 0.0:
        return True, 0.0, 0.0
    base = max(abs(f1), abs(f2))
    diff = abs(f1 - f2)
    pct = (diff / base) * 100.0 if base > 0 else 0.0
    return pct <= tolerance_pct, pct, diff


def _has_text(value: Optional[str]) -> bool:
    return bool(value and value.strip())


def _validate_incoterm_code(db: Session, value: Any) -> str:
    """Active Incoterm code or 400 (DOC-13). (D1 may later move this to validators.validate_incoterm_code.)"""
    from modules.incoterms.model import Incoterm
    code = str(value or "").strip().upper()
    found = db.query(Incoterm.incoterm_id).filter(Incoterm.incoterm_code == code, Incoterm.is_active == True).first() if code else None
    if not found:
        raise _bad_request(f"شرط التسليم '{value}' غير معروف أو غير نشط في جدول شروط التسليم (Incoterms).")
    return code
