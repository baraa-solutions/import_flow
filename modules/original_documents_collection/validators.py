"""
Business validation for the Original Documents Collection module (SH-04 / BP-026).

Status values are checked against fixed code sets (ODC-08). The stored form stays the one the client uses
today (session status codes, document status labels, courier status codes); case and code/label variants are
normalized. The T3 enum types ``ODC_STATUS`` / ``ORIGINAL_DOC_STATUS`` / ``COURIER_STATUS`` are a shared need
(docs/plans/review-shared-needs.md, "03b shared needs"): until they are registered in
``modules/common/enum_codes.py`` the sets live here.
"""
import re
from datetime import datetime
from typing import Any, Dict, List, Optional, Sequence

from fastapi import HTTPException, status

# Courier SLA (business days counted on the Cairo date). Alerts: WARNING from COURIER_WARN_DAYS,
# CRITICAL / flat DELAYED from COURIER_SLA_DAYS (Q4: both views use the same SLA).
COURIER_WARN_DAYS = 3
COURIER_SLA_DAYS = 5

# Session status codes. The first four are recomputed from the document counters on every save.
SESSION_STATUSES = ("DRAFT", "IN_TRANSIT", "PARTIALLY_RECEIVED", "FULLY_RECEIVED", "FULLY_VERIFIED", "DISCREPANCY_NOTED")
AUTO_SESSION_STATUSES = ("DRAFT", "PARTIALLY_RECEIVED", "FULLY_RECEIVED", "FULLY_VERIFIED")
FULLY_STATUSES = ("FULLY_RECEIVED", "FULLY_VERIFIED")

# Document status: stored label -> accepted spellings (label or UPPER_SNAKE code).
DOCUMENT_STATUSES = ("Pending", "In Transit", "Received", "Verified", "Discrepant", "Not Required")
REQUIRED_FLAGS = ("Yes", "No", "Conditional")
COURIER_STATUSES = ("DISPATCHED", "IN_TRANSIT", "DELIVERED", "DELAYED")

_DATE_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})(?:[T ].*)?$")


def _key(value: str) -> str:
    return re.sub(r"[\s_\-]+", "", value).lower()


def _lookup(allowed: Sequence[str]) -> Dict[str, str]:
    return {_key(v): v for v in allowed}


_SESSION_LOOKUP = _lookup(SESSION_STATUSES)
_DOCUMENT_LOOKUP = _lookup(DOCUMENT_STATUSES)
_REQUIRED_LOOKUP = _lookup(REQUIRED_FLAGS)
_COURIER_LOOKUP = _lookup(COURIER_STATUSES)


def _invalid(field_label_ar: str, value: Any, allowed: Sequence[str]) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        detail=f"قيمة غير صالحة لـ {field_label_ar}: '{value}'. القيم المسموح بها: {', '.join(allowed)}.",
    )


def _normalize(value: Any, lookup: Dict[str, str], allowed: Sequence[str], label_ar: str) -> str:
    text = str(value).strip() if value is not None else ""
    canonical = lookup.get(_key(text)) if text else None
    if canonical is None:
        raise _invalid(label_ar, value, allowed)
    return canonical


def normalize_session_status(value: Any) -> str:
    return _normalize(value, _SESSION_LOOKUP, SESSION_STATUSES, "حالة جلسة تحصيل المستندات")


def normalize_date(value: Any, label_ar: str) -> Optional[str]:
    """``YYYY-MM-DD`` (an ISO date-time is cut to its date); empty -> None; anything else -> 422."""
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    match = _DATE_RE.match(text)
    if match:
        try:
            datetime.strptime(match.group(1), "%Y-%m-%d")
            return match.group(1)
        except ValueError:
            pass
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        detail=f"تاريخ غير صالح في {label_ar}: '{value}'. الصيغة المطلوبة YYYY-MM-DD.",
    )


def normalize_document(doc: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(doc)
    out["status"] = _normalize(out.get("status") or "Pending", _DOCUMENT_LOOKUP, DOCUMENT_STATUSES, "حالة المستند")
    out["is_required"] = _normalize(out.get("is_required") or "Yes", _REQUIRED_LOOKUP, REQUIRED_FLAGS, "إلزامية المستند")
    out["received_date"] = normalize_date(out.get("received_date"), "تاريخ استلام المستند")
    out["verification_date"] = normalize_date(out.get("verification_date"), "تاريخ مطابقة المستند")
    if isinstance(out.get("courier_no"), str):
        out["courier_no"] = out["courier_no"].strip() or None
    return out


def normalize_courier(courier: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(courier)
    out["status"] = _normalize(out.get("status") or "DISPATCHED", _COURIER_LOOKUP, COURIER_STATUSES, "حالة الطرد")
    out["dispatch_date"] = normalize_date(out.get("dispatch_date"), "تاريخ إرسال الطرد")
    out["received_date"] = normalize_date(out.get("received_date"), "تاريخ استلام الطرد")
    if isinstance(out.get("courier_no"), str):
        out["courier_no"] = out["courier_no"].strip()
    return out


def normalize_documents(docs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [normalize_document(d) for d in docs]


def normalize_couriers(couriers: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [normalize_courier(c) for c in couriers]


def awb_key(value: Optional[str]) -> str:
    """Comparison key of a courier AWB: exact match after strip + upper (ODC-03, no substring matching)."""
    return (value or "").strip().upper()
