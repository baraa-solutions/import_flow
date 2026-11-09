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
from modules.trade_finance.payment_pathway import ensure_payment_type_allowed

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


def _get_payment(db: Session, payment_id: int) -> PaymentRequestSession:
    item = repo.get_payment_request_by_id(db, payment_id)
    if item is None:
        raise not_found(L_PAYMENT, payment_id)
    return item


def _get_budget(db: Session, budget_id: int) -> ImportBudgetApproval:
    item = repo.get_import_budget_by_id(db, budget_id)
    if item is None:
        raise not_found(L_BUDGET, budget_id)
    return item


def _get_batch(db: Session, batch_id: int) -> SwiftExtractionBatch:
    batch = repo.get_swift_extraction_batch(db, batch_id)
    if batch is None:
        raise not_found(L_BATCH, batch_id)
    return batch


def _file_codes(db: Session, ids: Iterable[Optional[int]]) -> Dict[int, str]:
    from modules.import_files.repository import codes_by_ids

    return codes_by_ids(db, ids)


def _attach_file_codes(db: Session, items: List[T]) -> List[T]:
    """Fills the response-only ``import_file_code`` attribute (one query for the whole list)."""
    codes = _file_codes(db, [getattr(i, "import_file_id", None) for i in items])
    for item in items:
        setattr(item, "import_file_code", codes.get(getattr(item, "import_file_id", None)))
    return items


def _with_file_code(db: Session, item: T) -> T:
    return _attach_file_codes(db, [item])[0]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _append_note(current: Optional[str], note: str) -> str:
    return f"{current}\n{note}".strip() if current else note


def _insert_with_unique_code(
    db: Session,
    next_code: Callable[[], str],
    code_exists: Callable[[str], bool],
    build: Callable[[str], T],
) -> T:
    """Runs ``build(code)`` (adds the core rows) and commits. A code taken concurrently (IntegrityError on the
    unique column) is retried with the next code; the unique constraint stays the final guard."""
    for attempt in range(1, CODE_ATTEMPTS + 1):
        code = next_code()
        try:
            row = build(code)
            db.commit()
        except IntegrityError:
            db.rollback()
            if not code_exists(code):
                raise
            if attempt == CODE_ATTEMPTS:
                raise fa_error(
                    status.HTTP_409_CONFLICT,
                    "FA_CODE_GENERATION_CONFLICT",
                    f"الرقم المرجعي {code} مستخدم بالفعل، يرجى إعادة المحاولة.",
                    reference_code=code,
                )
            logger.info("Financial approval code %s was taken concurrently; retrying (%s/%s)", code, attempt, CODE_ATTEMPTS)
            continue
        db.refresh(row)
        return row
    raise AssertionError("unreachable")  # pragma: no cover


def _notify(db: Session, message: Any, severity: str, category: str, entity_type: str, entity_id: int, target_role: str) -> None:
    db.add(SystemNotification(
        title=render_en(message.code, message.params, "title"),
        message=render_en(message.code, message.params, "body"),
        msg_code=message.code,
        msg_params=message.params,
        severity=severity,
        category=category,
        entity_type=entity_type,
        entity_id=entity_id,
        target_role=target_role,
    ))


def _ref_pattern(token: str) -> "re.Pattern[str]":
    """``token`` as a whole reference: "PayId: 1" never matches "PayId: 12", "PAY-2026-100" never "PAY-2026-1000"."""
    return re.compile(rf"(?<![\w-]){re.escape(token)}(?![\w])")


# ==============================================================================
# FX RATES (no hard-coded fallback: FA-04)
# ==============================================================================

def _commercial_rate_to_egp(db: Session, currency_code: Optional[str]) -> Optional[float]:
    """Latest commercial rate of ``currency_code`` to EGP (1.0 for EGP / the base currency), or None."""
    from modules.common.enum_codes import normalize_currency
    from modules.currencies.repository import CurrencyRepository

    code = normalize_currency(currency_code or "USD")
    if not isinstance(code, str) or not code.strip():
        return None
    if code.strip().upper() == "EGP":
        return 1.0
    curr_repo = CurrencyRepository(db)
    currency = curr_repo.get_currency_by_code(code)
    if currency is None:
        return None
    if currency.is_base_currency:
        return 1.0
    latest = curr_repo.get_latest_rate(currency.currency_id, target_date=date.today())
    if latest is not None and latest.commercial_rate:
        return float(latest.commercial_rate)
    return None


def file_code_or_id(imp: Any) -> str:
    return imp.import_file_code or imp.custom_file_number or f"IMP-{imp.import_file_id}"


def _require_currency(currency_code: Optional[str], source: str) -> str:
    """ISO code of an amount's currency; 400 FA_CURRENCY_MISSING when none is recorded (never a silent USD)."""
    from modules.common.enum_codes import normalize_currency

    code = normalize_currency(currency_code) if currency_code else None
    if not isinstance(code, str) or not code.strip():
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_CURRENCY_MISSING",
            f"لم يتم تحديد عملة المبلغ في {source}. يرجى تحديد العملة أولاً.",
            source=source,
        )
    return code.strip().upper()


def _fx_missing(currency_code: Optional[str]) -> HTTPException:
    return fa_error(
        status.HTTP_400_BAD_REQUEST,
        "FA_FX_RATE_MISSING",
        f"لا يوجد سعر صرف مسجل للعملة {currency_code}. يرجى إضافته من شاشة العملات.",
        currency_code=currency_code,
    )


def _require_rate(db: Session, currency_code: Optional[str], cache: Optional[Dict[str, float]] = None) -> float:
    if not currency_code or not str(currency_code).strip():
        raise _fx_missing(currency_code)
    key = currency_code.strip().upper()
    if cache is not None and key in cache:
        return cache[key]
    rate = _commercial_rate_to_egp(db, currency_code)
    if rate is None or rate <= 0:
        raise _fx_missing(currency_code)
    if cache is not None:
        cache[key] = rate
    return rate


def _budget_egp_amounts(
    db: Session,
    invoice_foreign: float,
    invoice_currency: Optional[str],
    freight_foreign: float,
    freight_currency: Optional[str],
    invoice_rate: float,
) -> Tuple[float, float]:
    """Derive invoice and freight EGP amounts for an import budget.
    Freight converts with invoice_rate when same currency, 1.0 for EGP, or its own commercial rate."""
    from modules.common.enum_codes import normalize_currency

    inv_egp = (invoice_foreign or 0.0) * invoice_rate
    if (freight_foreign or 0.0) <= 0:
        return (inv_egp, 0.0)

    inv_c_norm = normalize_currency(invoice_currency) if invoice_currency else None
    frt_c_norm = normalize_currency(freight_currency) if freight_currency else None

    if frt_c_norm == "EGP":
        freight_rate = 1.0
    elif frt_c_norm and frt_c_norm == inv_c_norm:
        freight_rate = invoice_rate
    else:
        freight_rate = _require_rate(db, freight_currency)

    frt_egp = (freight_foreign or 0.0) * freight_rate
    return (inv_egp, frt_egp)


# ==============================================================================
# PAYMENT REQUESTS (BP-012)
# ==============================================================================

def _ensure_no_open_payment_of_type(db: Session, import_file_id: int, payment_type: str, exclude_id: Optional[int] = None) -> None:
    existing = repo.find_open_payment_of_type(db, import_file_id, payment_type, PAYMENT_OPEN_STATUSES, exclude_id=exclude_id)
    if existing is not None:
        code = normalize_payment_type(payment_type)
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_PAYMENT_DUPLICATE_TYPE",
            f"يوجد بالفعل طلب سداد مالي قيد الإجراء من نوع '{code}' محفوظ لهذا الملف ({existing.payment_code}). "
            "يرجى الذهاب لتعديله أو استخدام نوع سداد آخر.",
            payment_type=code,
            payment_code=existing.payment_code,
        )


def _ensure_swift_ref_unused(db: Session, swift_reference_no: Optional[str], item: PaymentRequestSession) -> None:
    """FA-06(d): one SWIFT reference settles one active request (app-level until the unique index D4)."""
    if not swift_reference_no:
        return
    other = repo.find_active_payment_by_swift_ref(db, swift_reference_no, exclude_id=item.payment_id)
    if other is not None:
        raise fa_error(
            status.HTTP_409_CONFLICT,
            "FA_SWIFT_REF_ALREADY_USED",
            f"مرجع السويفت {swift_reference_no} مستخدم بالفعل في طلب الصرف {other.payment_code}.",
            swift_ref=swift_reference_no,
            payment_code=other.payment_code,
        )


def _payment_params(item: PaymentRequestSession, file_code: str) -> Dict[str, Any]:
    return dict(
        payment_code=item.payment_code,
        supplier_name=item.supplier_name,
        requested_amount=round(float(item.requested_amount or 0.0), 2),
        currency_code=item.currency_code,
        requested_egp_amount=round(float(item.requested_amount_egp or 0.0), 2),
        due_date=str(item.due_date),
        import_file_code=file_code,
    )


def _create_payment_task(db: Session, payment_id: int, file_code: Optional[str], is_advance: bool,
                         params: Dict[str, Any]) -> str:
    from modules.smart_tasks.repository import create_task as create_smart_task
    from modules.smart_tasks.schemas import SmartTaskCreate

    item = _get_payment(db, payment_id)
    task_msg = msg("FA_TASK_SUPPLIER_PAYMENT" if is_advance else "FA_TASK_SUPPLIER_PAYMENT_GENERIC", **params)
    task_schema = SmartTaskCreate(
        title=render_en(task_msg.code, task_msg.params, "title"),
        description=render_en(task_msg.code, task_msg.params, "body"),
        task_type="System Generated",
        import_file_id=item.import_file_id,
        import_file_code=file_code,
        phase_name="Phase 2: Shipment Initiation",
        assigned_user="Finance Officer",
        priority="High",
        reminder_type="Advance Payment" if is_advance else "Payment Request",
        due_date=str(item.due_date),
        status="Pending",
        notes=f"REQ_TYPE:ADVANCE_PAYMENT | Code: {item.payment_code} | PayId: {item.payment_id}",
    )
    task = create_smart_task(
        db, task_schema, created_by="Financial Approval Engine", msg_code=task_msg.code, msg_params=task_msg.params,
    )
    return task.task_code


def _advance_after_payment_request(db: Session, import_file_id: int, payment_code: str, amount: float, currency: str) -> None:
    from modules.lifecycle_board.service import advance_lifecycle_step_service

    advance_lifecycle_step_service(
        db=db,
        completed_step_code="STEP_03",
        import_file_id=import_file_id,
        target_step_codes=["STEP_04"],
        auto_complete_prior=True,
        assigned_user="Finance Officer",
        notes_msg=msg(
            "FA_ADVANCE_PAYMENT_REQUESTED",
            payment_code=payment_code,
            requested_amount=round(float(amount or 0.0), 2),
            currency_code=currency,
        ),
        next_action_msg=msg("NA_STEP04_APPROVE_ADVANCE_PAYMENT"),
        source_module="Financial Approval Lifecycle",
        min_progress_percent=30.0,
    )


def create_payment_request_service(
    db: Session, schema: PaymentRequestCreate, current_user_name: Optional[str] = None
) -> PaymentRequestSession:
    """Validates and creates a payment request (one open request per payment type and import file).
    ``status`` is server-owned: Draft, or Pending Approval when the client submits it directly (C4)."""
    validate_payment_request_inputs(
        db=db,
        requested_amount=schema.requested_amount,
        po_id=schema.po_id,
        supplier_id=schema.supplier_id,
        import_file_id=schema.import_file_id,
        currency_code=schema.currency_code,
        project_id=schema.project_id,
    )
    norm_currency = require_known_currency(db, schema.currency_code)
    validate_payment_rate(norm_currency, schema.exchange_rate)
    updates: Dict[str, Any] = {"currency_code": norm_currency}
    if schema.po_id:
        adv_pct = validate_po_ceiling(db, schema.po_id, norm_currency, schema.requested_amount)
        updates["advance_percentage"] = adv_pct
    if schema.supplier_id:
        from modules.suppliers.model import Supplier

        sup = db.query(Supplier).filter(Supplier.supplier_id == schema.supplier_id).first()
        if sup:
            updates["supplier_name"] = sup.company_name
            if not schema.beneficiary_name:
                updates["beneficiary_name"] = sup.company_name
    schema = schema.model_copy(update=updates)

    if schema.import_file_id:
        _ensure_no_open_payment_of_type(db, schema.import_file_id, schema.payment_type)
        ensure_payment_type_allowed(db, schema.import_file_id, schema.payment_type, actor=current_user_name or "system")

    initial_status = schema.status if schema.status in PAYMENT_CREATE_STATUSES else PAYMENT_DRAFT
    file_code = "No File"
    if schema.import_file_id:
        file_code = _file_codes(db, [schema.import_file_id]).get(schema.import_file_id) or f"IMP-{schema.import_file_id}"
    is_advance = is_advance_payment(schema.payment_type)

    def build(code: str) -> PaymentRequestSession:
        item = repo.add_payment_request(db, schema, code, initial_status, created_by=current_user_name)
        created_msg = msg(
            "FA_PAYMENT_REQUEST_CREATED" if is_advance else "FA_PAYMENT_REQUEST_CREATED_GENERIC",
            **_payment_params(item, file_code),
        )
        _notify(db, created_msg, "WARNING" if is_advance else "INFO", "PAYMENT_REQUEST", "PaymentRequest",
                item.payment_id, "FINANCE_OFFICER")
        return item

    db_item = _insert_with_unique_code(
        db, lambda: repo.next_payment_code(db), lambda c: repo.payment_code_exists(db, c), build
    )
    payment_id = db_item.payment_id
    params = _payment_params(db_item, file_code)

    task_code = best_effort(
        db, _create_payment_task, f"Smart task for payment request {payment_id}",
        db, payment_id, file_code if schema.import_file_id else None, is_advance, params,
    )
    if schema.import_file_id:
        best_effort(
            db, _advance_after_payment_request, f"Lifecycle STEP_04 for import file {schema.import_file_id}",
            db, schema.import_file_id, params["payment_code"], params["requested_amount"], params["currency_code"],
        )

    db_item = _get_payment(db, payment_id)
    setattr(db_item, "smart_task_code", task_code)
    return _with_file_code(db, db_item)


def update_payment_request_service(
    db: Session, payment_id: int, schema: PaymentRequestUpdate, current_user_name: Optional[str] = None,
    current_user: Optional[User] = None,
) -> PaymentRequestSession:
    db_item = _get_payment(db, payment_id)
    submitted = schema.model_dump(exclude_unset=True)
    current_version = repo.check_version(
        db, db_item, "PaymentRequestSession", db_item.payment_id, db_item.payment_code,
        submitted.pop("version", None), current_user_name,
    )

    not_null = not_null_columns(PaymentRequestSession)
    changes = {
        k: v for k, v in submitted.items()
        if k not in SERVER_OWNED_PAYMENT_FIELDS and not (v is None and k in not_null)  # C4 + FA-12
    }
    validate_payment_update(db_item, changes)
    if "currency_code" in changes and changes["currency_code"] is not None:
        changes["currency_code"] = require_known_currency(db, changes["currency_code"])
    _require_reject_permission(db, db_item, changes, current_user)

    target_po_id = changes.get("po_id", db_item.po_id)
    target_curr = changes.get("currency_code", db_item.currency_code)
    target_amount = changes.get("requested_amount", db_item.requested_amount)
    target_rate = changes.get("exchange_rate", db_item.exchange_rate)
    validate_payment_rate(target_curr, target_rate)

    if target_po_id and ("po_id" in changes or "requested_amount" in changes or "currency_code" in changes
                         or (changes.get("status") == PAYMENT_DRAFT and db_item.status == PAYMENT_REJECTED)):
        new_adv_pct = validate_po_ceiling(
            db, target_po_id, target_curr, target_amount, exclude_id=db_item.payment_id
        )
        changes["advance_percentage"] = new_adv_pct

    if changes.get("import_file_id") is not None:
        from modules.import_files.model import ImportFile

        require_active(db, ImportFile, changes["import_file_id"], L_FILE)
    target_file = changes.get("import_file_id", db_item.import_file_id)
    target_status = changes.get("status", db_item.status)
    if target_file and target_status in PAYMENT_OPEN_STATUSES and ("import_file_id" in changes or "payment_type" in changes
                                                                    or target_status != db_item.status):
        _ensure_no_open_payment_of_type(
            db, target_file, changes.get("payment_type", db_item.payment_type), exclude_id=db_item.payment_id
        )
    if target_file and ("import_file_id" in changes or "payment_type" in changes):
        ensure_payment_type_allowed(
            db, target_file, changes.get("payment_type", db_item.payment_type),
            actor=current_user_name or "system", exclude_id=db_item.payment_id,
        )

    repo.apply_payment_changes(db, db_item, changes, current_version, updated_by=current_user_name)
    db.commit()
    db.refresh(db_item)
    return _with_file_code(db, db_item)


def _require_reject_permission(db: Session, item: PaymentRequestSession, changes: Dict[str, Any],
                               current_user: Optional[User]) -> None:
    """Rejecting a Pending Approval or Approved request is an approval decision: it needs
    ``financial_approval.approve`` on top of the route's ``.manage`` (the router always passes the user)."""
    from modules.auth.permissions import has_user_permission

    if (current_user is not None and changes.get("status") == PAYMENT_REJECTED
            and item.status in (PAYMENT_PENDING, PAYMENT_APPROVED)
            and not has_user_permission(db, current_user, "financial_approval.approve")):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="تم رفض الوصول. الصلاحية 'financial_approval.approve' مطلوبة.",
        )


def approve_payment_request_service(
    db: Session, payment_id: int, current_user_name: Optional[str] = None
) -> PaymentRequestSession:
    """Draft / Pending Approval -> Approved, with a notification to the Finance Officer."""
    db_item = _get_payment(db, payment_id)
    require_payment_status(db_item, PAYMENT_APPROVE_FROM, "approve")

    db_item.status = PAYMENT_APPROVED
    db_item.version = (db_item.version or 1) + 1
    db_item.updated_at = _now()
    if current_user_name:
        db_item.updated_by = current_user_name

    file_code = _file_codes(db, [db_item.import_file_id]).get(db_item.import_file_id) if db_item.import_file_id else None
    approved_msg = msg(
        "FA_PAYMENT_REQUEST_APPROVED_FILE" if file_code else "FA_PAYMENT_REQUEST_APPROVED",
        payment_code=db_item.payment_code,
        **({"import_file_code": file_code} if file_code else {}),
        requested_amount=round(float(db_item.requested_amount or 0.0), 2),
        currency_code=db_item.currency_code,
        supplier_name=db_item.supplier_name,
    )
    _notify(db, approved_msg, "INFO", "DUTY_PAYMENT", "PaymentRequest", db_item.payment_id, "FINANCE_OFFICER")
    db.commit()
    db.refresh(db_item)
    return _with_file_code(db, db_item)


def _apply_swift_receipt(item: PaymentRequestSession, transferred_amount: float, currency: Optional[str],
                         receipt_date: date) -> None:
    """Variance = round(transferred - requested, 2): Matched when |v| < 0.01, Deficit < 0, Surplus > 0.
    processing_days = max(0, receipt - request_date)."""
    variance = round(float(transferred_amount) - float(item.requested_amount), 2)
    if abs(variance) < 0.01:
        variance_status = "Matched"
    elif variance < 0:
        variance_status = "Deficit"
    else:
        variance_status = "Surplus"
    item.swift_receipt_date = receipt_date
    item.swift_transferred_amount = transferred_amount
    item.swift_transferred_currency = currency
    item.swift_variance_amount = variance
    item.swift_variance_status = variance_status
    item.swift_processing_days = max(0, (receipt_date - (item.request_date or date.today())).days)


@dataclass
class _PaidEvent:
    payment_id: int
    payment_code: str
    import_file_id: Optional[int]
    file_code: Optional[str]
    swift_ref: str
    amount: float
    currency: str


def _mark_paid(db: Session, item: PaymentRequestSession, swift_reference_no: Optional[str],
               transferred_amount: Optional[float], currency_code: Optional[str],
               swift_debit_amount_egp: Optional[float] = None,
               receipt_date: Optional[date] = None,
               updated_by: Optional[str] = None) -> _PaidEvent:
    """Core of the Paid transition (same transaction as the caller): status, SWIFT reference, the import
    file's ``swift_no`` and the LOGISTICS_OFFICER notification. Follow-ups: ``_after_paid``."""
    old_swift_ref = item.swift_reference_no
    swift_ref = (swift_reference_no or item.swift_reference_no or "").strip()
    assert swift_ref, "swift_reference_no must be non-empty when marking Paid"
    amount = float(transferred_amount or item.swift_transferred_amount or item.requested_amount or 0.0)
    currency = currency_code or item.swift_transferred_currency or item.currency_code
    r_date = receipt_date or item.swift_receipt_date

    item.status = PAYMENT_PAID
    item.swift_reference_no = swift_ref

    # Realised payment in EGP and exchange rate (ACC2-T07)
    if swift_debit_amount_egp is not None and float(swift_debit_amount_egp) > 0 and amount > 0:
        paid_rate = float(swift_debit_amount_egp) / amount
        paid_egp = round(float(swift_debit_amount_egp), 2)
    elif currency.upper().strip() == "EGP":
        paid_rate = 1.0
        paid_egp = round(amount, 2)
    else:
        from modules.financial_settlement.service import SettlementFx
        fx = SettlementFx(db, "commercial")
        paid_rate = fx.rate(currency, r_date)
        paid_egp = round(amount * paid_rate, 2)

    item.paid_exchange_rate = paid_rate
    item.paid_amount_egp = paid_egp

    item.version = (item.version or 1) + 1
    item.updated_at = _now()
    if updated_by:
        item.updated_by = updated_by

    file_code = None
    if item.import_file_id:
        from modules.import_files.model import ImportFile

        imp = db.query(ImportFile).filter(ImportFile.import_file_id == item.import_file_id).first()
        if imp is not None:
            if not (imp.swift_no and imp.swift_no.strip()) or (old_swift_ref and imp.swift_no == old_swift_ref):
                imp.swift_no = swift_ref
            file_code = imp.import_file_code or f"IMP-{imp.import_file_id}"
            swift_msg = msg("FA_SWIFT_PAID", import_file_code=file_code, swift_ref=swift_ref,
                            paid_amount=round(amount, 2), currency_code=currency)
            _notify(db, swift_msg, "INFO", "DUTY_PAYMENT", "PaymentRequest", item.payment_id, "LOGISTICS_OFFICER")
    return _PaidEvent(item.payment_id, item.payment_code, item.import_file_id if file_code else None,
                      file_code, swift_ref, amount, currency)


def _close_payment_tasks(db: Session, event: _PaidEvent) -> None:
    """FA-09: closes only the open tasks of THIS request (``PayId: <id>`` or its payment code in the notes)."""
    from modules.smart_tasks.model import SmartTask

    by_id = _ref_pattern(f"PayId: {event.payment_id}")
    by_code = _ref_pattern(event.payment_code) if event.payment_code else None
    open_tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == event.import_file_id,
        SmartTask.status.in_(["Pending", "In Progress"]),
        SmartTask.is_active == True,
    ).all()
    for task in open_tasks:
        notes = task.notes or ""
        if by_id.search(notes) or (by_code is not None and by_code.search(notes)):
            task.status = "Completed"
            task.is_auto_closed = True
    db.commit()


def _advance_after_paid(db: Session, event: _PaidEvent) -> None:
    from modules.lifecycle_board.service import advance_lifecycle_step_service

    advance_lifecycle_step_service(
        db=db,
        completed_step_code="STEP_04",
        import_file_id=event.import_file_id,
        target_step_codes=["STEP_05"],
        auto_complete_prior=True,
        assigned_user="Logistics Officer",
        notes_msg=msg("FA_SWIFT_PAID", swift_ref=event.swift_ref, paid_amount=round(event.amount, 2),
                      currency_code=event.currency),
        next_action_msg=msg("NA_STEP05_REQUEST_ACID"),
        source_module="Financial SWIFT Engine",
        min_progress_percent=35.0,
    )


def _create_acid_task(db: Session, event: _PaidEvent) -> None:
    from modules.smart_tasks.model import SmartTask
    from modules.smart_tasks.repository import create_task as create_smart_task
    from modules.smart_tasks.schemas import SmartTaskCreate

    exists = db.query(SmartTask).filter(
        SmartTask.import_file_id == event.import_file_id,
        SmartTask.title.ilike("%ACID%"),
        SmartTask.status.in_(["Pending", "In Progress"]),
        SmartTask.is_active == True,
    ).first()
    if exists is not None:
        return
    acid_msg = msg("FA_TASK_ISSUE_ACID", import_file_code=event.file_code, swift_ref=event.swift_ref)
    create_smart_task(
        db,
        SmartTaskCreate(
            title=render_en(acid_msg.code, acid_msg.params, "title"),
            description=render_en(acid_msg.code, acid_msg.params, "body"),
            task_type="System Generated",
            import_file_id=event.import_file_id,
            import_file_code=event.file_code,
            phase_name="Phase 2: Approvals & ACID",
            assigned_user="Logistics Officer",
            priority="High",
            reminder_type="ACID Operations",
            due_date=str(date.today() + timedelta(days=3)),
            status="Pending",
            notes=f"ACTION:ISSUE_ACID | SwiftRef: {event.swift_ref} | PayId: {event.payment_id}",
        ),
        created_by="Financial SWIFT Engine",
        msg_code=acid_msg.code,
        msg_params=acid_msg.params,
        step_code="STEP_05",
    )


def _after_paid(db: Session, event: _PaidEvent) -> None:
    """Post-commit follow-ups of a Paid request (each step best-effort and committed on its own)."""
    if not event.import_file_id:
        return
    best_effort(db, _close_payment_tasks, f"Close payment tasks of {event.payment_code}", db, event)
    best_effort(db, _advance_after_paid, f"Lifecycle STEP_05 for import file {event.import_file_id}", db, event)
    best_effort(db, _create_acid_task, f"ACID task for import file {event.import_file_id}", db, event)


def _finish_paid(db: Session, event: _PaidEvent) -> PaymentRequestSession:
    _after_paid(db, event)
    return _with_file_code(db, _get_payment(db, event.payment_id))


def execute_payment_service(
    db: Session, payment_id: int, swift_reference_no: Optional[str] = None,
    current_user_name: Optional[str] = None,
) -> PaymentRequestSession:
    """Approved -> Paid once the SWIFT transfer copy exists."""
    db_item = _get_payment(db, payment_id)
    require_payment_status(db_item, PAYMENT_PAY_FROM, "pay")
    ref = (swift_reference_no or "").strip() or (db_item.swift_reference_no or "").strip()
    if not ref:
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_SWIFT_REF_REQUIRED",
            "يجب إدخال الرقم المرجعي للسويفت قبل تسجيل السداد.",
            payment_code=db_item.payment_code,
        )
    _ensure_swift_ref_unused(db, ref, db_item)

    event = _mark_paid(
        db, db_item,
        swift_reference_no=ref,
        transferred_amount=float(db_item.swift_transferred_amount or db_item.requested_amount or 0.0),
        currency_code=db_item.swift_transferred_currency or db_item.currency_code,
        updated_by=current_user_name,
    )
    db.commit()
    return _finish_paid(db, event)


def reconcile_swift_service(
    db: Session, payment_id: int, payload: SwiftReconciliationRequest,
    current_user_name: Optional[str] = None,
) -> PaymentRequestSession:
    """Reconciles a bank SWIFT confirmation against an Approved request and marks it Paid."""
    db_item = _get_payment(db, payment_id)
    require_payment_status(db_item, PAYMENT_PAY_FROM, "reconcile")
    require_same_currency(payload.swift_transferred_currency, db_item.currency_code)
    _ensure_swift_ref_unused(db, payload.swift_reference_no, db_item)

    _apply_swift_receipt(db_item, payload.swift_transferred_amount, payload.swift_transferred_currency,
                         payload.swift_receipt_date)
    db_item.swift_reference_no = payload.swift_reference_no
    db_item.swift_reconciliation_notes = payload.swift_reconciliation_notes

    event = _mark_paid(db, db_item, payload.swift_reference_no, payload.swift_transferred_amount,
                       payload.swift_transferred_currency,
                       swift_debit_amount_egp=payload.swift_debit_amount_egp,
                       receipt_date=payload.swift_receipt_date,
                       updated_by=current_user_name)
    db.commit()
    return _finish_paid(db, event)


def smart_reconcile_swift_service(
    db: Session, payload: SmartSwiftReconcileRequest, current_user_name: Optional[str] = None,
) -> PaymentRequestSession:
    """Writes confirmed SWIFT details onto an Approved request, confirms bank info and (auto_execute) marks it Paid."""
    db_item = _get_payment(db, payload.payment_id)
    require_payment_status(db_item, PAYMENT_PAY_FROM, "reconcile")
    require_same_currency(payload.swift_transferred_currency, db_item.currency_code)
    _ensure_swift_ref_unused(db, payload.swift_reference_no, db_item)

    db_item.swift_reference_no = payload.swift_reference_no
    if payload.bank_name:
        db_item.bank_name = payload.bank_name
    if payload.swift_code:
        db_item.swift_code = payload.swift_code
    if payload.iban_account_no:
        db_item.iban_account_no = payload.iban_account_no
    _apply_swift_receipt(db_item, payload.swift_transferred_amount, payload.swift_transferred_currency,
                         payload.swift_receipt_date)
    if payload.swift_reconciliation_notes:
        db_item.swift_reconciliation_notes = payload.swift_reconciliation_notes

    event = None
    if payload.auto_execute:
        event = _mark_paid(db, db_item, payload.swift_reference_no, payload.swift_transferred_amount,
                           payload.swift_transferred_currency,
                           swift_debit_amount_egp=payload.swift_debit_amount_egp,
                           receipt_date=payload.swift_receipt_date,
                           updated_by=current_user_name)
    else:
        db_item.version = (db_item.version or 1) + 1
        db_item.updated_at = _now()
        if current_user_name:
            db_item.updated_by = current_user_name
    db.commit()
    if event is not None:
        return _finish_paid(db, event)
    db.refresh(db_item)
    return _with_file_code(db, db_item)


def clone_payment_request_service(
    db: Session, payment_id: int, schema: ClonePaymentRequestRequest,
    current_user_name: Optional[str] = None,
) -> PaymentRequestSession:
    """Clones a request into a new Draft: new code, SWIFT fields cleared, request_date today, due today + 12,
    title "<title> (Copy)" unless given, optional supplier switch / import file unlink. Keeps the original rate
    (FA_FX_RATE_MISSING when it has none) and the one-open-request-per-type rule."""
    orig = _get_payment(db, payment_id)

    rate = schema.new_exchange_rate if getattr(schema, "new_exchange_rate", None) is not None else orig.exchange_rate
    if not rate or rate <= 0:
        raise _fx_missing(orig.currency_code)
    validate_payment_rate(orig.currency_code, rate)

    supplier_id = schema.target_supplier_id or orig.supplier_id
    supplier_name = orig.supplier_name
    beneficiary_name = orig.beneficiary_name
    if schema.target_supplier_id and schema.target_supplier_id != orig.supplier_id:
        from modules.suppliers.model import Supplier

        sup = require_active(db, Supplier, schema.target_supplier_id, "المورد", status_code=status.HTTP_404_NOT_FOUND)
        supplier_name = sup.company_name
        beneficiary_name = sup.company_name

    amount = schema.new_requested_amount if schema.new_requested_amount is not None else orig.requested_amount
    if amount is None or amount <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="يجب أن يكون المبلغ المطلوب أكبر من صفر.")
    import_file_id = None if schema.unlink_import_file else orig.import_file_id
    po_id = None if schema.unlink_import_file else orig.po_id
    cloned_adv_pct = orig.advance_percentage
    if po_id:
        cloned_adv_pct = validate_po_ceiling(db, po_id, orig.currency_code, amount)
    payment_type = normalize_payment_type(orig.payment_type)
    if import_file_id:
        _ensure_no_open_payment_of_type(db, import_file_id, payment_type)
        ensure_payment_type_allowed(db, import_file_id, payment_type, actor=current_user_name or "system")

    notes = orig.notes
    if schema.remarks:
        notes = _append_note(notes, schema.remarks)

    def build(code: str) -> PaymentRequestSession:
        return repo.add_row(db, PaymentRequestSession(
            payment_code=code,
            title=schema.new_title or f"{orig.title} (Copy)",
            import_file_id=import_file_id,
            po_id=po_id,
            supplier_id=supplier_id,
            supplier_name=supplier_name,
            project_id=orig.project_id,
            payment_type=payment_type,
            requested_amount=amount,
            advance_percentage=cloned_adv_pct,
            currency_code=orig.currency_code,
            exchange_rate=rate,
            requested_amount_egp=round(amount * rate, 2),
            request_date=date.today(),
            due_date=date.today() + timedelta(days=12),
            status=PAYMENT_DRAFT,
            beneficiary_name=beneficiary_name,
            bank_name=orig.bank_name,
            swift_code=orig.swift_code,
            iban_account_no=orig.iban_account_no,
            bank_country=orig.bank_country,
            notes=notes,
            is_active=True,
            created_by=current_user_name,
        ))

    cloned = _insert_with_unique_code(db, lambda: repo.next_payment_code(db), lambda c: repo.payment_code_exists(db, c), build)
    return _with_file_code(db, cloned)


def get_all_payment_requests_service(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    po_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> Tuple[List[PaymentRequestSession], int]:
    items, total = repo.get_all_payment_requests(
        db,
        include_inactive=include_inactive,
        search=search,
        po_id=po_id,
        supplier_id=supplier_id,
        status=status,
        skip=skip,
        limit=limit,
    )
    return _attach_file_codes(db, items), total


def get_payment_request_by_id_service(db: Session, payment_id: int) -> PaymentRequestSession:
    return _with_file_code(db, _get_payment(db, payment_id))


def soft_delete_payment_request_service(
    db: Session, payment_id: int, current_user_name: Optional[str] = None
) -> bool:
    item = _get_payment(db, payment_id)
    if item.status in PAYMENT_DELETE_LOCKED:  # Q7: 409 for everyone
        raise fa_error(
            status.HTTP_409_CONFLICT,
            "FA_PAYMENT_LOCKED",
            "لا يمكن حذف طلب صرف معتمد أو مدفوع.",
            payment_code=item.payment_code,
            status=item.status,
        )
    repo.set_payment_active(db, item, False, updated_by=current_user_name)
    db.commit()
    return True


def restore_payment_request_service(
    db: Session, payment_id: int, current_user_name: Optional[str] = None
) -> bool:
    item = repo.get_inactive_payment_request(db, payment_id)
    if item is None:
        raise not_found(L_PAYMENT, payment_id)
    if item.import_file_id and item.status in PAYMENT_OPEN_STATUSES:
        _ensure_no_open_payment_of_type(db, item.import_file_id, item.payment_type, exclude_id=item.payment_id)
    repo.set_payment_active(db, item, True, updated_by=current_user_name)
    db.commit()
    return True


# ==============================================================================
# IMPORT BUDGETS (BP-013)
# ==============================================================================

