"""
Business Validation Rules for Financial Approval (BP-012 & BP-013)

Status sets, server-owned transitions, payment type codes and the coded error helper.
Coded errors use structured ``{"code", "message", **params}`` dicts (``fa_error``), with codes
registered in ``modules/common/system_messages.py``.
"""

import re
from typing import Any, Dict, FrozenSet, Iterable, Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common import enum_codes
from modules.common.validators import require_active
from modules.purchase_orders.model import PurchaseOrder
from modules.suppliers.model import Supplier

# --- Status sets (English labels; conversion to T3 codes is deferred: plan D3) ---
PAYMENT_DRAFT = "Draft"
PAYMENT_PENDING = "Pending Approval"
PAYMENT_APPROVED = "Approved"
PAYMENT_PAID = "Paid"
PAYMENT_REJECTED = "Rejected"
PAYMENT_STATUSES: FrozenSet[str] = frozenset(
    {PAYMENT_DRAFT, PAYMENT_PENDING, PAYMENT_APPROVED, PAYMENT_PAID, PAYMENT_REJECTED}
)
# Statuses an active request blocks a second request of the same type for the same file.
PAYMENT_OPEN_STATUSES: FrozenSet[str] = frozenset({PAYMENT_DRAFT, PAYMENT_PENDING, PAYMENT_APPROVED})
# Statuses a client may store on create (Draft -> Pending Approval is a user transition anyway).
PAYMENT_CREATE_STATUSES: FrozenSet[str] = frozenset({PAYMENT_DRAFT, PAYMENT_PENDING})

BUDGET_DRAFT = "Draft"
BUDGET_PENDING = "Pending Review"
BUDGET_REVALIDATION = "Needs Revalidation"
BUDGET_APPROVED = "Budget Approved"
BUDGET_SUPERSEDED = "Superseded"
BUDGET_STATUSES: FrozenSet[str] = frozenset(
    {BUDGET_DRAFT, BUDGET_PENDING, BUDGET_REVALIDATION, BUDGET_APPROVED, BUDGET_SUPERSEDED, "Budget Exceeded", "Rejected"}
)
BUDGET_APPROVABLE: FrozenSet[str] = frozenset({BUDGET_DRAFT, BUDGET_PENDING, BUDGET_REVALIDATION})
BUDGET_LOCKED: FrozenSet[str] = frozenset({BUDGET_APPROVED, BUDGET_SUPERSEDED})

BATCH_PENDING = "EXTRACTED_PENDING_REVIEW"
BATCH_CONFIRMED = "REVIEWED_CONFIRMED"
BATCH_RECONCILED = "RECONCILED"
BATCH_REJECTED = "REJECTED"

# Transitions a user may make through PUT. Approved and Paid are reached only through /approve, /pay and the
# reconcile endpoints.
PAYMENT_USER_TRANSITIONS: Dict[str, FrozenSet[str]] = {
    PAYMENT_DRAFT: frozenset({PAYMENT_PENDING, PAYMENT_REJECTED}),
    PAYMENT_PENDING: frozenset({PAYMENT_DRAFT, PAYMENT_REJECTED}),
    PAYMENT_APPROVED: frozenset({PAYMENT_REJECTED}),
    PAYMENT_PAID: frozenset(),
    PAYMENT_REJECTED: frozenset({PAYMENT_DRAFT}),
}
PAYMENT_APPROVE_FROM: FrozenSet[str] = frozenset({PAYMENT_DRAFT, PAYMENT_PENDING})
PAYMENT_PAY_FROM: FrozenSet[str] = frozenset({PAYMENT_APPROVED})
PAYMENT_DELETE_LOCKED: FrozenSet[str] = frozenset({PAYMENT_APPROVED, PAYMENT_PAID})

# --- PAYMENT_TYPE codes (T3). Mirrors the set the lead registers in modules/common/enum_codes.py. ---
PAYMENT_TYPE = "PAYMENT_TYPE"
PAYMENT_TYPE_ADVANCE = "ADVANCE_PAYMENT"
PAYMENT_TYPE_LABELS_EN: Dict[str, str] = {
    "ADVANCE_PAYMENT": "Advance Payment",
    "AGAINST_BL": "Against B/L",
    "LETTER_OF_CREDIT": "Letter of Credit (L/C)",
    "DOCUMENTARY_COLLECTION": "Documentary Collection (CAD)",
    "FINAL_SETTLEMENT": "Final Settlement",
}
_PAYMENT_TYPE_ALIASES: Dict[str, str] = {
    "advance payment": "ADVANCE_PAYMENT",
    "advance": "ADVANCE_PAYMENT",
    "against b/l": "AGAINST_BL",
    "against bl": "AGAINST_BL",
    "letter of credit (l/c)": "LETTER_OF_CREDIT",
    "letter of credit": "LETTER_OF_CREDIT",
    "l/c": "LETTER_OF_CREDIT",
    "lc": "LETTER_OF_CREDIT",
    "documentary collection (cad)": "DOCUMENTARY_COLLECTION",
    "documentary collection": "DOCUMENTARY_COLLECTION",
    "cad": "DOCUMENTARY_COLLECTION",
    "final settlement": "FINAL_SETTLEMENT",
}


def normalize_payment_type(value: Any) -> Any:
    """PAYMENT_TYPE code for a code or legacy label; anything else comes back unchanged.
    Delegates to ``enum_codes`` once the lead has registered the type there."""
    if PAYMENT_TYPE in enum_codes.LABELS_EN:
        return enum_codes.normalize(PAYMENT_TYPE, value)
    if not isinstance(value, str):
        return value
    text = value.strip()
    if text.upper() in PAYMENT_TYPE_LABELS_EN:
        return text.upper()
    return _PAYMENT_TYPE_ALIASES.get(re.sub(r"\s+", " ", text).casefold(), value)


def require_payment_type(value: Any) -> str:
    """Normalized PAYMENT_TYPE code, or ``ValueError`` (pydantic turns it into a 422)."""
    code = normalize_payment_type(value)
    if code not in PAYMENT_TYPE_LABELS_EN:
        raise ValueError(f"Unknown payment_type '{value}'. Allowed: {', '.join(PAYMENT_TYPE_LABELS_EN)}")
    return code


def same_payment_type(a: Any, b: Any) -> bool:
    return normalize_payment_type(a) == normalize_payment_type(b)


def is_advance_payment(payment_type: Any) -> bool:
    return normalize_payment_type(payment_type) == PAYMENT_TYPE_ADVANCE


# --- Coded errors ---
def fa_error(status_code: int, code: str, message_ar: str, **params: Any) -> HTTPException:
    """``HTTPException`` whose detail is ``{"code", "message" (Arabic), **params}``."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message_ar, **params})


def require_payment_status(item: Any, allowed: Iterable[str], action: str) -> None:
    """400 ``FA_PAYMENT_STATUS_INVALID`` unless the request is in one of ``allowed``."""
    if item.status not in set(allowed):
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_PAYMENT_STATUS_INVALID",
            f"لا يمكن تنفيذ الإجراء ({action}) على طلب الصرف {item.payment_code} وهو بحالة '{item.status}'.",
            payment_code=item.payment_code,
            status=item.status,
            action=action,
        )


def payment_locked_error(item: Any) -> HTTPException:
    return fa_error(
        status.HTTP_409_CONFLICT,
        "FA_PAYMENT_LOCKED",
        "لا يمكن تعديل طلب صرف معتمد أو مدفوع.",
        payment_code=item.payment_code,
        status=item.status,
    )


def validate_payment_update(item: Any, changes: Dict[str, Any]) -> None:
    """Guards a payment PUT (``changes`` = submitted fields after the server-owned ones were dropped).

    Paid: always 409. Approved: only a move to Rejected (with optional notes) is accepted, anything else 409.
    Status changes must follow ``PAYMENT_USER_TRANSITIONS`` (400 otherwise)."""
    new_status = changes.get("status")
    status_change = new_status is not None and new_status != item.status
    if item.status == PAYMENT_PAID:
        raise payment_locked_error(item)
    if item.status == PAYMENT_APPROVED:
        if not (status_change and new_status == PAYMENT_REJECTED and set(changes) <= {"status", "notes"}):
            raise payment_locked_error(item)
    if status_change:
        allowed = PAYMENT_USER_TRANSITIONS.get(item.status, frozenset())
        if new_status not in allowed:
            raise fa_error(
                status.HTTP_400_BAD_REQUEST,
                "FA_PAYMENT_STATUS_INVALID",
                f"لا يمكن نقل طلب الصرف {item.payment_code} من الحالة '{item.status}' إلى '{new_status}'.",
                payment_code=item.payment_code,
                status=item.status,
                action=f"status:{new_status}",
            )
    if "currency_code" in changes and changes["currency_code"] is not None:
        norm_new = enum_codes.normalize_currency(changes["currency_code"])
        norm_old = enum_codes.normalize_currency(item.currency_code)
        if norm_new != norm_old and ("exchange_rate" not in changes or changes.get("exchange_rate") is None):
            raise fa_error(
                status.HTTP_400_BAD_REQUEST,
                "FA_PAYMENT_RATE_REQUIRED",
                "عند تغيير عملة طلب الصرف يجب إدخال سعر الصرف الجديد.",
                payment_code=item.payment_code,
                currency_code=norm_new,
            )


def budget_locked_error(item: Any) -> HTTPException:
    return fa_error(
        status.HTTP_409_CONFLICT,
        "FA_BUDGET_LOCKED",
        "لا يمكن تعديل ميزانية معتمدة أو مؤرشفة. استخدم المزامنة لإنشاء إصدار مراجعة جديد.",
        budget_code=item.budget_code,
        status=item.budget_status,
    )


def require_budget_approvable(item: Any) -> None:
    if item.budget_status not in BUDGET_APPROVABLE:
        raise fa_error(
            status.HTTP_409_CONFLICT,
            "FA_BUDGET_STATUS_INVALID",
            f"لا يمكن اعتماد الميزانية {item.budget_code} وهي بحالة '{item.budget_status}'.",
            budget_code=item.budget_code,
            status=item.budget_status,
        )


def batch_status_error(batch: Any, status_code: int = status.HTTP_409_CONFLICT) -> HTTPException:
    return fa_error(
        status_code,
        "FA_SWIFT_BATCH_STATUS_INVALID",
        f"لا يمكن تنفيذ هذا الإجراء على دفعة السويفت {batch.batch_code} وهي بحالة '{batch.status}'.",
        batch_code=batch.batch_code,
        status=batch.status,
    )


def require_same_currency(swift_currency: Optional[str], currency_code: Optional[str]) -> None:
    """400 ``FA_SWIFT_CURRENCY_MISMATCH`` when the SWIFT currency differs from the request currency (Q3)."""
    swift_norm = enum_codes.normalize_currency(swift_currency)
    req_norm = enum_codes.normalize_currency(currency_code)
    if swift_norm and req_norm and swift_norm != req_norm:
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_SWIFT_CURRENCY_MISMATCH",
            f"عملة السويفت {swift_currency} لا تطابق عملة طلب الصرف {currency_code}.",
            swift_currency=swift_currency,
            currency_code=currency_code,
        )


def validate_payment_request_inputs(
    db: Session,
    requested_amount: float,
    po_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    import_file_id: Optional[int] = None,
) -> None:
    """requested_amount > 0; supplier, purchase order and import file must exist and be active."""
    if requested_amount is None or requested_amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يجب أن يكون المبلغ المطلوب أكبر من صفر.",
        )
    require_active(db, Supplier, supplier_id, "المورد", status_code=status.HTTP_404_NOT_FOUND)
    require_active(db, PurchaseOrder, po_id, "أمر الشراء", status_code=status.HTTP_404_NOT_FOUND)
    if import_file_id is not None:
        from modules.import_files.model import ImportFile

        require_active(db, ImportFile, import_file_id, "ملف الاستيراد")
