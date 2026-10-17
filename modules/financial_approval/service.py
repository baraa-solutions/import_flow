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
    validate_payment_request_inputs,
    validate_payment_update,
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
    updates: Dict[str, Any] = {"currency_code": norm_currency}
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

    initial_status = schema.status if schema.status in PAYMENT_CREATE_STATUSES else PAYMENT_DRAFT
    file_code = "No File"
    if schema.import_file_id:
        file_code = _file_codes(db, [schema.import_file_id]).get(schema.import_file_id) or f"IMP-{schema.import_file_id}"
    is_advance = is_advance_payment(schema.payment_type)

    def build(code: str) -> PaymentRequestSession:
        item = repo.add_payment_request(db, schema, code, initial_status)
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

    repo.apply_payment_changes(db, db_item, changes, current_version)
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


def approve_payment_request_service(db: Session, payment_id: int) -> PaymentRequestSession:
    """Draft / Pending Approval -> Approved, with a notification to the Finance Officer."""
    db_item = _get_payment(db, payment_id)
    require_payment_status(db_item, PAYMENT_APPROVE_FROM, "approve")

    db_item.status = PAYMENT_APPROVED
    db_item.version = (db_item.version or 1) + 1
    db_item.updated_at = _now()

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
               transferred_amount: Optional[float], currency_code: Optional[str]) -> _PaidEvent:
    """Core of the Paid transition (same transaction as the caller): status, SWIFT reference, the import
    file's ``swift_no`` and the LOGISTICS_OFFICER notification. Follow-ups: ``_after_paid``."""
    swift_ref = swift_reference_no or item.swift_reference_no or f"SWF-{item.payment_id}"
    amount = float(transferred_amount or item.swift_transferred_amount or item.requested_amount or 0.0)
    currency = currency_code or item.swift_transferred_currency or item.currency_code or "USD"

    item.status = PAYMENT_PAID
    item.swift_reference_no = swift_ref
    item.version = (item.version or 1) + 1
    item.updated_at = _now()

    file_code = None
    if item.import_file_id:
        from modules.import_files.model import ImportFile

        imp = db.query(ImportFile).filter(ImportFile.import_file_id == item.import_file_id).first()
        if imp is not None:
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


def execute_payment_service(db: Session, payment_id: int, swift_reference_no: Optional[str] = None) -> PaymentRequestSession:
    """Approved -> Paid once the SWIFT transfer copy exists."""
    db_item = _get_payment(db, payment_id)
    require_payment_status(db_item, PAYMENT_PAY_FROM, "pay")
    _ensure_swift_ref_unused(db, swift_reference_no, db_item)

    event = _mark_paid(
        db, db_item,
        swift_reference_no=swift_reference_no or db_item.swift_reference_no,
        transferred_amount=float(db_item.swift_transferred_amount or db_item.requested_amount or 0.0),
        currency_code=db_item.swift_transferred_currency or db_item.currency_code,
    )
    db.commit()
    return _finish_paid(db, event)


def reconcile_swift_service(db: Session, payment_id: int, payload: SwiftReconciliationRequest) -> PaymentRequestSession:
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
                       payload.swift_transferred_currency)
    db.commit()
    return _finish_paid(db, event)


def smart_reconcile_swift_service(db: Session, payload: SmartSwiftReconcileRequest) -> PaymentRequestSession:
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
                           payload.swift_transferred_currency)
    else:
        _set_file_swift_no(db, db_item.import_file_id, payload.swift_reference_no)
        db_item.version = (db_item.version or 1) + 1
        db_item.updated_at = _now()
    db.commit()
    if event is not None:
        return _finish_paid(db, event)
    db.refresh(db_item)
    return _with_file_code(db, db_item)


def _set_file_swift_no(db: Session, import_file_id: Optional[int], swift_ref: str) -> None:
    if not import_file_id:
        return
    from modules.import_files.model import ImportFile

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if imp is not None:
        imp.swift_no = swift_ref


def clone_payment_request_service(db: Session, payment_id: int, schema: ClonePaymentRequestRequest) -> PaymentRequestSession:
    """Clones a request into a new Draft: new code, SWIFT fields cleared, request_date today, due today + 12,
    title "<title> (Copy)" unless given, optional supplier switch / import file unlink. Keeps the original rate
    (FA_FX_RATE_MISSING when it has none) and the one-open-request-per-type rule."""
    orig = _get_payment(db, payment_id)

    rate = orig.exchange_rate
    if not rate or rate <= 0:
        raise _fx_missing(orig.currency_code)

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
    payment_type = normalize_payment_type(orig.payment_type)
    if import_file_id:
        _ensure_no_open_payment_of_type(db, import_file_id, payment_type)

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
            currency_code=orig.currency_code,
            exchange_rate=rate,
            requested_amount_egp=amount * rate,
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


def soft_delete_payment_request_service(db: Session, payment_id: int) -> bool:
    item = _get_payment(db, payment_id)
    if item.status in PAYMENT_DELETE_LOCKED:  # Q7: 409 for everyone
        raise fa_error(
            status.HTTP_409_CONFLICT,
            "FA_PAYMENT_LOCKED",
            "لا يمكن حذف طلب صرف معتمد أو مدفوع.",
            payment_code=item.payment_code,
            status=item.status,
        )
    repo.set_payment_active(db, item, False)
    db.commit()
    return True


def restore_payment_request_service(db: Session, payment_id: int) -> bool:
    item = repo.get_inactive_payment_request(db, payment_id)
    if item is None:
        raise not_found(L_PAYMENT, payment_id)
    if item.import_file_id and item.status in PAYMENT_OPEN_STATUSES:
        _ensure_no_open_payment_of_type(db, item.import_file_id, item.payment_type, exclude_id=item.payment_id)
    repo.set_payment_active(db, item, True)
    db.commit()
    return True


# ==============================================================================
# IMPORT BUDGETS (BP-013)
# ==============================================================================

def _budget_duplicate_error(db: Session, import_file_id: int) -> HTTPException:
    file_code = _file_codes(db, [import_file_id]).get(import_file_id) or str(import_file_id)
    return fa_error(
        status.HTTP_400_BAD_REQUEST,
        "FA_BUDGET_DUPLICATE_FILE",
        f"يوجد بالفعل اعتماد ميزانية محفوظ لهذا الملف ({file_code}). يرجى الذهاب لتعديل الميزانية الحالية بدلاً من إنشاء اعتماد جديد.",
        import_file_code=file_code,
    )


def _sync_budget_stage(db: Session, import_file_id: Optional[int], is_approved: bool, approved_by: Optional[str]) -> None:
    if not import_file_id:
        return
    from modules.lifecycle_board.service import sync_budget_lifecycle_stage

    best_effort(db, sync_budget_lifecycle_stage, f"Budget lifecycle stage for import file {import_file_id}",
                db, import_file_id, is_approved=is_approved, approved_by=approved_by)


def create_import_budget_service(
    db: Session, schema: ImportBudgetCreate, current_user_name: Optional[str] = None
) -> ImportBudgetApproval:
    """Creates an import budget in Pending Review (one active budget per import file)."""
    if schema.po_id:
        from modules.purchase_orders.model import PurchaseOrder

        require_active(db, PurchaseOrder, schema.po_id, "أمر الشراء", status_code=status.HTTP_404_NOT_FOUND)
    if schema.project_id:
        from modules.projects.model import Project

        require_active(db, Project, schema.project_id, "المشروع", status_code=status.HTTP_404_NOT_FOUND)

    budget_updates: Dict[str, Any] = {}
    if (schema.invoice_amount_foreign or 0.0) > 0 and schema.invoice_currency:
        budget_updates["invoice_currency"] = require_known_currency(db, schema.invoice_currency)
    if (schema.freight_cost_foreign or 0.0) > 0 and schema.freight_currency:
        budget_updates["freight_currency"] = require_known_currency(db, schema.freight_currency)
    if budget_updates:
        schema = schema.model_copy(update=budget_updates)

    if schema.import_file_id:
        from modules.import_files.model import ImportFile

        require_active(db, ImportFile, schema.import_file_id, L_FILE)
        if repo.find_active_budget_for_file(db, schema.import_file_id) is not None:
            raise _budget_duplicate_error(db, schema.import_file_id)

    created = _insert_with_unique_code(
        db, lambda: repo.next_budget_code(db), lambda c: repo.budget_code_exists(db, c),
        lambda code: repo.add_import_budget(db, schema, code),
    )
    budget_id = created.budget_id
    _sync_budget_stage(db, schema.import_file_id, is_approved=False, approved_by=None)  # FA-24: never approved here
    return _with_file_code(db, _get_budget(db, budget_id))


def _close_budget_tasks(db: Session, import_file_id: int, budget_code: Optional[str]) -> None:
    from modules.smart_tasks.model import SmartTask

    by_code = _ref_pattern(budget_code) if budget_code else None
    tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == import_file_id,
        SmartTask.status.in_(["Pending", "In Progress"]),
        SmartTask.is_active == True,
    ).all()
    for task in tasks:
        notes = task.notes or ""
        if "BUDGET" in notes or (by_code is not None and by_code.search(notes + " " + (task.title or ""))):
            task.status = "Completed"
            task.is_auto_closed = True
    db.commit()


def approve_import_budget_service(db: Session, budget_id: int, approved_by: str = "Finance Manager") -> ImportBudgetApproval:
    """Draft / Pending Review / Needs Revalidation -> Budget Approved, unless an unresolved hard block exists.
    ``approved_by`` is the authenticated user (the router never takes it from the client)."""
    db_item = _get_budget(db, budget_id)
    require_budget_approvable(db_item)

    hard = repo.first_pending_hard_block(db, budget_id)
    if hard is not None:
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_BUDGET_HARD_BLOCK",
            f"لا يمكن اعتماد الميزانية لوجود فارق تكاليف غير مسوى يتجاوز العتبة المحددة "
            f"({hard.variance_percentage:.1f}% في {hard.field_name} - Hard Block). يجب مزامنة التكاليف أولاً "
            "أو تقديم مبرر مكتوب إجباري لتجاوز الحظر.",
            variance_percentage=round(float(hard.variance_percentage or 0.0), 2),
            field_name=hard.field_name,
        )

    db_item.budget_status = BUDGET_APPROVED
    db_item.approved_by = approved_by
    db_item.approved_date = date.today()
    db_item.version = (db_item.version or 1) + 1
    db_item.updated_at = _now()

    file_code = _file_codes(db, [db_item.import_file_id]).get(db_item.import_file_id) if db_item.import_file_id else None
    budget_msg = msg(
        "FA_BUDGET_APPROVED_FILE" if file_code else "FA_BUDGET_APPROVED",
        budget_code=db_item.budget_code,
        **({"import_file_code": file_code} if file_code else {}),
        total_amount=round(float(db_item.total_budget_egp or 0.0), 2),
        approved_by=approved_by,
    )
    _notify(db, budget_msg, "INFO", "DUTY_PAYMENT", "ImportBudget", db_item.budget_id, "FINANCE_OFFICER")
    db.commit()

    import_file_id, budget_code = db_item.import_file_id, db_item.budget_code
    if import_file_id:
        best_effort(db, _close_budget_tasks, f"Close budget tasks of {budget_code}", db, import_file_id, budget_code)
    _sync_budget_stage(db, import_file_id, is_approved=True, approved_by=approved_by)
    return _with_file_code(db, _get_budget(db, budget_id))


def clone_import_budget_service(db: Session, budget_id: int, schema: CloneImportBudgetRequest) -> ImportBudgetApproval:
    """Clones a budget into Pending Review: approval cleared, new code, optional new rate (EGP amounts recomputed
    from the foreign amounts), unlinked when the target file is the source file."""
    orig = _get_budget(db, budget_id)

    target_file_id = None
    if not schema.unlink_import_file:
        target_file_id = schema.target_import_file_id or orig.import_file_id
    if target_file_id:
        if target_file_id == orig.import_file_id:
            # Same file: unlink to keep one active budget per file.
            target_file_id = None
        else:
            from modules.import_files.model import ImportFile

            require_active(db, ImportFile, target_file_id, L_FILE)
            if repo.find_active_budget_for_file(db, target_file_id) is not None:
                raise _budget_duplicate_error(db, target_file_id)

    rate = schema.new_exchange_rate if (schema.new_exchange_rate and schema.new_exchange_rate > 0) else orig.exchange_rate
    if not rate or rate <= 0:
        raise _fx_missing(orig.invoice_currency)

    inv_foreign = orig.invoice_amount_foreign or 0.0
    frt_foreign = orig.freight_cost_foreign or 0.0
    if inv_foreign > 0 or frt_foreign > 0:
        calc_inv_egp, calc_frt_egp = _budget_egp_amounts(
            db, inv_foreign, orig.invoice_currency, frt_foreign, orig.freight_currency, rate
        )
        inv_egp = calc_inv_egp if inv_foreign > 0 else (orig.invoice_amount_egp or 0.0)
        frt_egp = calc_frt_egp if frt_foreign > 0 else (orig.freight_cost_egp or 0.0)
    else:
        inv_egp = orig.invoice_amount_egp or 0.0
        frt_egp = orig.freight_cost_egp or 0.0
    cust_egp = orig.customs_duties_egp or 0.0
    clr_egp = orig.clearance_inland_egp or 0.0
    notes = _append_note(orig.notes, schema.remarks) if schema.remarks else orig.notes

    def build(code: str) -> ImportBudgetApproval:
        return repo.add_row(db, ImportBudgetApproval(
            budget_code=code,
            title=schema.new_title or f"{orig.title} (Copy)",
            import_file_id=target_file_id,
            po_id=None if schema.unlink_import_file else orig.po_id,
            project_id=orig.project_id,
            invoice_amount_foreign=inv_foreign,
            invoice_currency=orig.invoice_currency,
            invoice_amount_egp=inv_egp,
            freight_cost_foreign=frt_foreign,
            freight_currency=orig.freight_currency,
            freight_cost_egp=frt_egp,
            customs_duties_egp=cust_egp,
            clearance_inland_egp=clr_egp,
            exchange_rate=rate,
            total_budget_egp=inv_egp + frt_egp + cust_egp + clr_egp,
            budget_status=BUDGET_PENDING,
            approved_by=None,
            approved_date=None,
            notes=notes,
            is_active=True,
        ))

    cloned = _insert_with_unique_code(db, lambda: repo.next_budget_code(db), lambda c: repo.budget_code_exists(db, c), build)
    return _with_file_code(db, cloned)


def get_all_import_budgets_service(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    po_id: Optional[int] = None,
    budget_status: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> Tuple[List[ImportBudgetApproval], int]:
    items, total = repo.get_all_import_budgets(
        db,
        include_inactive=include_inactive,
        search=search,
        import_file_id=import_file_id,
        po_id=po_id,
        budget_status=budget_status,
        skip=skip,
        limit=limit,
    )
    return _attach_file_codes(db, items), total


def get_import_budget_by_id_service(db: Session, budget_id: int) -> ImportBudgetApproval:
    return _with_file_code(db, _get_budget(db, budget_id))


_BUDGET_NOT_NULL_FIELDS = frozenset({
    "title", "invoice_amount_egp", "invoice_amount_foreign", "invoice_currency", "freight_cost_egp",
    "freight_cost_foreign", "freight_currency", "customs_duties_egp", "clearance_inland_egp", "exchange_rate",
}) | not_null_columns(ImportBudgetApproval)


def update_import_budget_service(
    db: Session, budget_id: int, schema: ImportBudgetUpdate, current_user_name: Optional[str] = None
) -> ImportBudgetApproval:
    """Edits a budget that is not approved / superseded (409 otherwise). Status and approver are server-owned."""
    db_item = _get_budget(db, budget_id)
    submitted = schema.model_dump(exclude_unset=True)
    current_version = repo.check_version(
        db, db_item, "ImportBudgetApproval", db_item.budget_id, db_item.budget_code,
        submitted.pop("version", None), current_user_name,
    )
    if db_item.budget_status in BUDGET_LOCKED:
        raise budget_locked_error(db_item)

    submitted.pop("budget_status", None)  # C4
    submitted.pop("approved_by", None)
    changes = {k: v for k, v in submitted.items() if not (v is None and k in _BUDGET_NOT_NULL_FIELDS)}

    if changes.get("po_id") is not None:
        from modules.purchase_orders.model import PurchaseOrder

        require_active(db, PurchaseOrder, changes["po_id"], "أمر الشراء", status_code=status.HTTP_404_NOT_FOUND)
    if changes.get("project_id") is not None:
        from modules.projects.model import Project

        require_active(db, Project, changes["project_id"], "المشروع", status_code=status.HTTP_404_NOT_FOUND)

    target_inv_foreign = changes.get("invoice_amount_foreign", db_item.invoice_amount_foreign) or 0.0
    if target_inv_foreign > 0 and ("invoice_currency" in changes or "invoice_amount_foreign" in changes):
        inv_curr = changes.get("invoice_currency", db_item.invoice_currency)
        norm_inv = require_known_currency(db, inv_curr)
        if "invoice_currency" in changes:
            changes["invoice_currency"] = norm_inv

    target_frt_foreign = changes.get("freight_cost_foreign", db_item.freight_cost_foreign) or 0.0
    if target_frt_foreign > 0 and ("freight_currency" in changes or "freight_cost_foreign" in changes):
        frt_curr = changes.get("freight_currency", db_item.freight_currency)
        norm_frt = require_known_currency(db, frt_curr)
        if "freight_currency" in changes:
            changes["freight_currency"] = norm_frt

    new_file = changes.get("import_file_id")
    if new_file is not None and new_file != db_item.import_file_id:
        from modules.import_files.model import ImportFile

        require_active(db, ImportFile, new_file, L_FILE)
        if repo.find_active_budget_for_file(db, new_file, exclude_id=db_item.budget_id) is not None:
            raise _budget_duplicate_error(db, new_file)

    repo.apply_budget_changes(db, db_item, changes, current_version)
    db.commit()
    import_file_id = db_item.import_file_id
    _sync_budget_stage(db, import_file_id, is_approved=False, approved_by=None)
    return _with_file_code(db, _get_budget(db, budget_id))


def soft_delete_import_budget_service(db: Session, budget_id: int) -> bool:
    item = _get_budget(db, budget_id)
    if item.budget_status in BUDGET_LOCKED:
        raise budget_locked_error(item)
    repo.set_budget_active(db, item, False)
    db.commit()
    return True


def restore_import_budget_service(db: Session, budget_id: int) -> bool:
    item = repo.get_inactive_import_budget(db, budget_id)
    if item is None:
        raise not_found(L_BUDGET, budget_id)
    if item.import_file_id and repo.find_active_budget_for_file(db, item.import_file_id, exclude_id=item.budget_id):
        raise _budget_duplicate_error(db, item.import_file_id)
    repo.set_budget_active(db, item, True)
    db.commit()
    return True


# ==============================================================================
# CROSS-MODULE PREFILL & AGGREGATOR ENGINE
# ==============================================================================

def get_budget_prefill_service(db: Session, import_file_id: int) -> BudgetPrefillResponse:
    """
    Cross-module aggregation for payment requests and budgets:
    1. Linked purchase orders (FOB total, else qty x price), else ``invoices_data``, else ``estimated_cost``.
    2. Supplier bank details.
    3. Highest freight quotation, compared in EGP (keeps the winner's own amount and currency).
    4. Customs: the maximum duties over the sessions; the broker of the maximum-fee session.
    Rates are the latest commercial rates: a currency without one gives 400 FA_FX_RATE_MISSING.
    """
    from modules.currencies.model import Currency
    from modules.customs_consultation.model import CustomsConsultationSession
    from modules.import_files.model import ImportFile
    from modules.projects.model import Project
    from modules.purchase_orders.model import PurchaseOrder
    from modules.shipping_scenarios.model import ShippingEvaluationSession
    from modules.suppliers.model import Supplier

    imp = (
        db.query(ImportFile)
        .filter(ImportFile.import_file_id == import_file_id, ImportFile.is_active == True)
        .first()
    )
    if not imp:
        raise not_found(L_FILE, import_file_id)

    # 1. Linked purchase orders
    po_query = db.query(PurchaseOrder).filter(PurchaseOrder.is_active == True)
    if imp.po_ids and isinstance(imp.po_ids, list):
        pos = po_query.filter(
            (PurchaseOrder.import_file_id == import_file_id) | (PurchaseOrder.po_id.in_(imp.po_ids))
        ).all()
    else:
        pos = po_query.filter(PurchaseOrder.import_file_id == import_file_id).all()

    linked_pos_schemas: List[LinkedPOItemSchema] = []
    invoice_parts: List[Tuple[float, str]] = []  # (amount, currency) per PO / invoice: converted one by one
    payment_terms_set = set()
    terms_list_str = []

    project_ids = [po.project_id for po in pos if po.project_id]
    prj_map = (
        {p.project_id: p.project_name for p in db.query(Project).filter(Project.project_id.in_(project_ids)).all()}
        if project_ids else {}
    )
    currency_ids = [po.currency_id for po in pos if po.currency_id]
    curr_map = (
        {c.currency_id: c.currency_code for c in db.query(Currency).filter(Currency.currency_id.in_(currency_ids)).all()}
        if currency_ids else {}
    )

    for po in pos:
        p_term = po.payment_terms or "Standard Payment"
        payment_terms_set.add(p_term)
        terms_list_str.append(f"{po.po_number} ({p_term})")

        curr_code = curr_map.get(po.currency_id) or ""
        po_amt = float(po.total_amount_fob or 0.0)
        if po_amt == 0.0 and po.line_items:  # FA-26: was `po.items` (AttributeError -> 500)
            po_amt = sum(float(it.quantity or 0.0) * float(it.unit_price or 0.0) for it in po.line_items)
        if po_amt > 0:
            invoice_parts.append((po_amt, _require_currency(curr_code, po.po_number)))

        linked_pos_schemas.append(LinkedPOItemSchema(
            po_id=po.po_id,
            po_number=po.po_number,
            pi_number=po.proforma_invoice_number,
            project_id=po.project_id,
            project_name=prj_map.get(po.project_id),
            payment_terms=p_term,
            currency=curr_code,
            total_amount=po_amt,
            status=po.status,
        ))

    if not invoice_parts and imp.invoices_data and isinstance(imp.invoices_data, list):
        for inv in imp.invoices_data:
            if isinstance(inv, dict):
                amt = float(inv.get("amount", 0.0) or 0.0)
                if amt > 0:
                    source = inv.get("invoice_no") or "invoices_data"
                    invoice_parts.append((amt, _require_currency(inv.get("currency"), source)))

    if not invoice_parts and imp.estimated_cost:
        invoice_parts.append((float(imp.estimated_cost or 0.0),
                              _require_currency(imp.estimated_cost_currency, file_code_or_id(imp))))

    if len(payment_terms_set) == 1:
        payment_terms_summary = next(iter(payment_terms_set))
    elif len(payment_terms_set) > 1:
        payment_terms_summary = f"Multiple ({', '.join(terms_list_str)})"  # C2: English, never stored Arabic
    else:
        payment_terms_summary = "Advance Payment"

    # 2. Supplier and banking info
    sup = None
    if imp.supplier_id:
        sup = db.query(Supplier).filter(Supplier.supplier_id == imp.supplier_id).first()
    elif pos and pos[0].supplier_id:
        sup = db.query(Supplier).filter(Supplier.supplier_id == pos[0].supplier_id).first()
    elif imp.supplier_name:
        # Legacy files without supplier_id: best-effort match on the stored name text (FA-21 MINOR, kept).
        sup = db.query(Supplier).filter(Supplier.company_name == imp.supplier_name).first()
    supplier_name = sup.company_name if sup else (imp.supplier_name or "Foreign Exporter")

    # 3. Highest freight quotation, compared in EGP
    rate_cache: Dict[str, float] = {}
    po_ids = [p.po_id for p in pos]
    shipping_sessions = db.query(ShippingEvaluationSession).filter(
        (ShippingEvaluationSession.import_file_id == import_file_id)
        | (ShippingEvaluationSession.po_id.in_(po_ids) if po_ids else False),
        ShippingEvaluationSession.is_active == True,
    ).all()

    highest_freight = 0.0
    highest_freight_egp = 0.0
    freight_currency = "USD"
    for s in shipping_sessions:
        for itm in s.items:
            f_amt = float(getattr(itm, "total_quotation_amount", 0.0) or 0.0)
            if f_amt == 0.0:
                c40 = (itm.container_40ft_price or 0.0) * (itm.container_40ft_qty or 1) if itm.container_40ft_applicable else 0.0
                c20 = (itm.container_20ft_price or 0.0) * (itm.container_20ft_qty or 1) if itm.container_20ft_applicable else 0.0
                lcl = (itm.lcl_cbm_price or 0.0) * (itm.lcl_cbm_qty or 1) if itm.lcl_cbm_applicable else 0.0
                f_amt = c40 + c20 + lcl
            if f_amt <= 0:
                continue
            curr = getattr(itm, "quotation_currency", None) or "USD"
            f_egp = f_amt * _require_rate(db, curr, rate_cache)
            if f_egp > highest_freight_egp:
                highest_freight, highest_freight_egp, freight_currency = f_amt, f_egp, curr

    # 4. Customs duties and broker clearance
    customs_query = db.query(CustomsConsultationSession).filter(CustomsConsultationSession.is_active == True)
    if po_ids:
        customs_sessions = customs_query.filter(
            (CustomsConsultationSession.import_file_id == import_file_id)
            | (CustomsConsultationSession.po_id.in_(po_ids))
        ).all()
    else:
        customs_sessions = customs_query.filter(CustomsConsultationSession.import_file_id == import_file_id).all()

    estimated_duties_egp = 0.0
    estimated_clearance_fees_egp = 0.0
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    for cs in customs_sessions:
        d_amt = float(cs.estimated_duties_egp or 0.0)
        c_amt = float(cs.total_broker_fees_egp or 0.0)
        if d_amt > 0:
            estimated_duties_egp = max(estimated_duties_egp, d_amt)
        if c_amt > 0:
            if c_amt >= estimated_clearance_fees_egp:
                estimated_clearance_fees_egp = c_amt
                if cs.broker_id:
                    broker_id = cs.broker_id
                if cs.broker_name:
                    broker_name = cs.broker_name
        elif not broker_name and cs.broker_name:
            broker_id = cs.broker_id
            broker_name = cs.broker_name

    # 5. Invoice in EGP (FA-04: no fallback rate). Each part is converted at its own currency's rate.
    # One currency: amount / currency / rate as recorded. Mixed currencies: the foreign total has no meaning, so the
    # invoice is reported in EGP (amount = EGP total, rate 1.0). An empty file needs no rate: the recorded USD rate
    # is reported, or None when there is none.
    exchange_rate: Optional[float]
    currencies = {c for _, c in invoice_parts}
    if not invoice_parts:
        total_invoice, invoice_curr = 0.0, "USD"
        exchange_rate = _commercial_rate_to_egp(db, invoice_curr)
        total_invoice_egp = 0.0
    elif len(currencies) == 1:
        invoice_curr = currencies.pop()
        total_invoice = sum(a for a, _ in invoice_parts)
        exchange_rate = _require_rate(db, invoice_curr, rate_cache)
        total_invoice_egp = total_invoice * exchange_rate
    else:
        total_invoice_egp = sum(a * _require_rate(db, c, rate_cache) for a, c in invoice_parts)
        total_invoice, invoice_curr, exchange_rate = total_invoice_egp, "EGP", 1.0
    grand_total_egp = total_invoice_egp + highest_freight_egp + estimated_duties_egp + estimated_clearance_fees_egp

    file_code_str = file_code_or_id(imp)
    return BudgetPrefillResponse(
        import_file_id=imp.import_file_id,
        import_file_code=file_code_str,
        import_file_title=f"Shipment {file_code_str}",
        incoterm=imp.incoterm_code or "FOB",
        supplier_id=sup.supplier_id if sup else None,
        supplier_name=supplier_name,
        beneficiary_name=supplier_name,
        bank_name=sup.bank_name if sup else None,
        swift_code=sup.swift_code if sup else None,
        account_number=sup.account_number if sup else None,
        iban=sup.iban if sup else None,
        payment_terms_summary=payment_terms_summary,
        linked_pos=linked_pos_schemas,
        total_invoice_amount=total_invoice,
        invoice_currency=invoice_curr,
        total_invoice_amount_egp=total_invoice_egp,
        estimated_freight_cost=highest_freight,
        freight_currency=freight_currency,
        estimated_freight_cost_egp=highest_freight_egp,
        estimated_customs_duties_egp=estimated_duties_egp,
        estimated_clearance_fees_egp=estimated_clearance_fees_egp,
        broker_id=broker_id,
        broker_name=broker_name,
        estimated_grand_total_egp=grand_total_egp,
        exchange_rate=exchange_rate,
    )


# ==============================================================================
# BUDGET VARIANCE THRESHOLD & CONFIGURATION
# ==============================================================================

def _threshold_setting(db: Session) -> Optional[BudgetVarianceSetting]:
    return repo.get_setting(db, VARIANCE_THRESHOLD_KEY)


def get_variance_threshold_service(db: Session) -> float:
    """Configured variance threshold percentage (5.0 when missing or invalid)."""
    setting = _threshold_setting(db)
    if setting and setting.setting_value:
        try:
            return float(setting.setting_value)
        except ValueError:
            return DEFAULT_VARIANCE_THRESHOLD
    return DEFAULT_VARIANCE_THRESHOLD


def get_variance_threshold_setting_service(db: Session) -> Any:
    """The stored setting row, or the (unsaved) default when none was configured yet."""
    setting = _threshold_setting(db)
    if setting is not None:
        return setting
    return BudgetVarianceSettingResponse(
        setting_id=0,
        setting_key=VARIANCE_THRESHOLD_KEY,
        setting_value=str(DEFAULT_VARIANCE_THRESHOLD),
        description="Maximum allowed cost variance percentage before triggering Hard Block",
        updated_by=None,
        updated_at=_now(),
    )


def update_variance_threshold_service(db: Session, threshold_percentage: float, updated_by: Optional[str] = "Admin") -> BudgetVarianceSetting:
    setting = _threshold_setting(db)
    now = _now()
    val_str = str(round(threshold_percentage, 2))
    if not setting:
        setting = BudgetVarianceSetting(
            setting_key=VARIANCE_THRESHOLD_KEY,
            setting_value=val_str,
            description="Maximum allowed cost variance percentage before triggering Hard Block",
            updated_by=updated_by,
            updated_at=now,
        )
        db.add(setting)
    else:
        setting.setting_value = val_str
        setting.updated_by = updated_by
        setting.updated_at = now
    db.commit()
    db.refresh(setting)
    return setting


def get_budget_variance_logs_service(db: Session, budget_id: int) -> List[BudgetVarianceLog]:
    _get_budget(db, budget_id)
    return repo.variance_logs_for_budget(db, budget_id)


# ==============================================================================
# VARIANCE ENGINE HELPERS
# ==============================================================================

@dataclass
class _CostDiff:
    field_name: str
    label: str
    old: float
    new: float
    diff: float
    pct: float
    is_hard: bool


def _cost_diffs(budget: ImportBudgetApproval, prefill: BudgetPrefillResponse, threshold: float) -> List[_CostDiff]:
    """Fields whose |live - budget| > 1.0 EGP. pct = 100 when the budget value is 0, else round(|diff|/old*100, 2);
    hard block when pct > threshold."""
    diffs: List[_CostDiff] = []
    for column, prefill_attr, label in _COST_FIELDS:
        old = getattr(budget, column)
        old_val = float(old) if old is not None else 0.0
        new = getattr(prefill, prefill_attr)
        new_val = float(new) if new is not None else 0.0
        diff = new_val - old_val
        if abs(diff) > VARIANCE_MIN_DIFF_EGP:
            pct = 100.0 if old_val == 0.0 else round((abs(diff) / old_val) * 100.0, 2)
            diffs.append(_CostDiff(column, label, old_val, new_val, diff, pct, pct > threshold))
    return diffs


def _apply_prefill(budget: ImportBudgetApproval, prefill: BudgetPrefillResponse) -> None:
    budget.invoice_amount_foreign = prefill.total_invoice_amount
    budget.invoice_currency = prefill.invoice_currency
    budget.invoice_amount_egp = prefill.total_invoice_amount_egp
    budget.freight_cost_foreign = prefill.estimated_freight_cost
    budget.freight_currency = prefill.freight_currency
    budget.freight_cost_egp = prefill.estimated_freight_cost_egp
    budget.customs_duties_egp = prefill.estimated_customs_duties_egp
    budget.clearance_inland_egp = prefill.estimated_clearance_fees_egp
    if prefill.exchange_rate is not None:  # empty file without a recorded rate: keep the budget rate
        budget.exchange_rate = prefill.exchange_rate
    budget.total_budget_egp = (
        prefill.total_invoice_amount_egp
        + prefill.estimated_freight_cost_egp
        + prefill.estimated_customs_duties_egp
        + prefill.estimated_clearance_fees_egp
    )


def _resolve_pending_logs(db: Session, budget_id: int, resolved_by: str, justification: Optional[str],
                          now: datetime, resolution: Optional[str] = None) -> List[BudgetVarianceLog]:
    logs = repo.pending_variance_logs(db, budget_id)
    for log in logs:
        log.resolved_at = now
        log.resolved_by = resolved_by
        log.resolution_type = resolution or ("overridden" if justification else "synced")
        log.justification_note = justification
    return logs


# ==============================================================================
# EVENT-DRIVEN SCOPED VARIANCE EVALUATION ENGINE
# ==============================================================================

def evaluate_and_record_budget_variance_service(
    db: Session, import_file_id: int, modified_by: Optional[str] = "System"
) -> List[BudgetVarianceLog]:
    """
    Event-driven variance evaluator, called after upstream costing changes (customs_consultation calls it through
    ``best_effort`` after its own commit: keep this signature and the commit below).
    - Draft: numbers auto-updated, logs resolved as auto_updated.
    - Pending Review / Needs Revalidation: Needs Revalidation, approval cleared, notification.
    - Budget Approved: numbers untouched, flagged, CRITICAL notification.
    A missing FX rate raises FA_FX_RATE_MISSING before any change (the caller's best_effort leaves budgets as they are).
    """
    active_budgets = repo.active_budgets_for_file(db, import_file_id)
    if not active_budgets:
        return []

    prefill = get_budget_prefill_service(db, import_file_id)
    threshold = get_variance_threshold_service(db)
    now = _now()
    recorded_logs: List[BudgetVarianceLog] = []
    file_code = prefill.import_file_code

    for budget in active_budgets:
        diffs = _cost_diffs(budget, prefill, threshold)
        if not diffs:
            continue
        has_hard_block = any(d.is_hard for d in diffs)
        item_logs: List[BudgetVarianceLog] = []
        for d in diffs:
            v_log = BudgetVarianceLog(
                budget_id=budget.budget_id,
                import_file_id=import_file_id,
                field_name=d.field_name,
                old_value=d.old,
                new_value=d.new,
                variance_amount=d.diff,
                variance_percentage=d.pct,
                threshold_percentage=threshold,
                is_hard_block=d.is_hard,
                detected_at=now,
                modified_by=modified_by,
                resolution_type="pending",
            )
            db.add(v_log)
            item_logs.append(v_log)
            recorded_logs.append(v_log)

        current_status = budget.budget_status
        if current_status == BUDGET_DRAFT:
            _apply_prefill(budget, prefill)
            budget.has_unresolved_variance = False
            budget.last_variance_check = now
            budget.upstream_modified_by = modified_by
            for v in item_logs:
                v.resolution_type = "auto_updated"
                v.resolved_at = now
                v.resolved_by = "System"
            budget.notes = _append_note(
                budget.notes,
                f"[Auto update {date.today()}]: live costs of the draft budget updated automatically by {modified_by}.",
            )

        elif current_status in (BUDGET_PENDING, BUDGET_REVALIDATION):
            budget.budget_status = BUDGET_REVALIDATION
            budget.has_unresolved_variance = True
            budget.upstream_modified_by = modified_by
            budget.last_variance_check = now
            budget.approved_by = None
            budget.approved_date = None
            budget.variance_override_reason = None
            budget.variance_overridden_by = None
            budget.notes = _append_note(
                budget.notes,
                f"[Source change {date.today()}]: cost variance detected by {modified_by}. Status changed to 'Needs Revalidation'.",
            )
            reval_msg = msg("FA_BUDGET_NEEDS_REVALIDATION", import_file_code=file_code, modified_by=modified_by,
                            budget_code=budget.budget_code)
            _notify(db, reval_msg, "CRITICAL" if has_hard_block else "WARNING", "BUDGET_VARIANCE", "ImportBudget",
                    budget.budget_id, "FINANCE_OFFICER")

        elif current_status == BUDGET_APPROVED:
            budget.has_unresolved_variance = True
            budget.upstream_modified_by = modified_by
            budget.last_variance_check = now
            budget.notes = _append_note(
                budget.notes,
                f"[Financial variance alert {date.today()}]: cost variance detected by {modified_by} on an approved "
                "budget. A new budget revision is required.",
            )
            variance_msg = msg("FA_APPROVED_BUDGET_VARIANCE", import_file_code=file_code, modified_by=modified_by,
                               budget_code=budget.budget_code)
            _notify(db, variance_msg, "CRITICAL", "BUDGET_VARIANCE", "ImportBudget", budget.budget_id, "FINANCE_OFFICER")

    db.commit()
    for log in recorded_logs:
        db.refresh(log)
    return recorded_logs


# ==============================================================================
# ENTERPRISE BUDGET SYNCHRONIZATION (SoD, REVISIONS & HARD BLOCK)
# ==============================================================================

def _require_sod(budget: ImportBudgetApproval, current_user: User) -> None:
    """Segregation of duties: the upstream modifier may not sync an approved budget (ADMIN exempt)."""
    if budget.budget_status not in BUDGET_LOCKED or not budget.upstream_modified_by:
        return
    if budget.upstream_modified_by.strip().lower() == (current_user.username or "").strip().lower() \
            and not is_admin_user(current_user):
        raise fa_error(
            status.HTTP_403_FORBIDDEN,
            "FA_BUDGET_SOD_DENIED",
            "مبدأ الفصل بين المهام (Segregation of Duties): بصفتك المستخدم الذي قام بتعديل التكاليف في المصدر، "
            "لا يجوز لك مزامنة أو اعتماد الميزانية المعتمدة بنفسك. يجب أن يتولى المراجعة والاعتماد مسؤول مالي آخر.",
        )


def sync_budget_with_upstream_service(
    db: Session,
    budget_id: int,
    current_user: User,
    override_justification: Optional[str] = None,
) -> BudgetSyncResultResponse:
    """
    Synchronizes a budget with live upstream costs (permission ``budget.sync_variance`` checked by the router):
    - SoD: the upstream modifier cannot sync an approved budget (ADMIN exempt).
    - Budget Approved: immutable; a new ``{base}-REV{n+1}`` revision in Pending Review, the original Superseded.
    - Draft stays Draft; Pending Review / Needs Revalidation are updated in place to Pending Review.
    - Superseded: 409 (its revision already replaced it).
    - A hard block without a justification gives 400, except in Draft.
    """
    budget = _get_budget(db, budget_id)
    if not budget.import_file_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يمكن مزامنة هذه الميزانية لعدم وجود ملف استيراد مرتبط بها.",
        )
    _require_sod(budget, current_user)
    if budget.budget_status == BUDGET_SUPERSEDED:
        raise budget_locked_error(budget)

    prefill = get_budget_prefill_service(db, budget.import_file_id)
    threshold = get_variance_threshold_service(db)
    diffs = _cost_diffs(budget, prefill, threshold)
    hard = [d for d in diffs if d.is_hard]
    if hard and not override_justification and budget.budget_status != BUDGET_DRAFT:
        worst = max(hard, key=lambda d: d.pct)
        raise fa_error(
            status.HTTP_400_BAD_REQUEST,
            "FA_BUDGET_HARD_BLOCK",
            f"فارق التكاليف يتجاوز العتبة المحددة ({threshold}% - Hard Block). يتطلب إدخال مبرر مكتوب إجباري "
            "(Justification Note) لتنفيذ المزامنة وتجاوز الحظر.",
            variance_percentage=worst.pct,
            field_name=worst.field_name,
        )

    now = _now()
    username = current_user.username
    changes_desc = ", ".join(f"{d.label}: {d.old:.2f} -> {d.new:.2f} EGP" for d in diffs) or "no variance"
    justification_suffix = f" Override justification: {override_justification}" if override_justification else ""
    orig_status = budget.budget_status

    if orig_status == BUDGET_APPROVED:
        next_rev = budget.revision_number + 1
        rev_code = f"{budget.budget_code.split('-REV')[0]}-REV{next_rev}"
        if repo.budget_code_exists(db, rev_code):
            raise fa_error(status.HTTP_409_CONFLICT, "FA_CODE_GENERATION_CONFLICT",
                           f"الرقم المرجعي {rev_code} مستخدم بالفعل، يرجى إعادة المحاولة.", reference_code=rev_code)

        budget.budget_status = BUDGET_SUPERSEDED
        budget.has_unresolved_variance = False
        budget.version = (budget.version or 1) + 1
        budget.notes = _append_note(
            budget.notes,
            f"[Archived as superseded {date.today()}]: this approved version was replaced by revision REV{next_rev} by {username}.",
        )
        new_budget = ImportBudgetApproval(
            budget_code=rev_code,
            title=f"{budget.title} (Rev {next_rev})",
            import_file_id=budget.import_file_id,
            po_id=budget.po_id,
            project_id=budget.project_id,
            exchange_rate=budget.exchange_rate,  # kept when the prefill has no rate (empty file)
            budget_status=BUDGET_PENDING,
            approved_by=None,
            approved_date=None,
            parent_budget_id=budget.budget_id,
            revision_number=next_rev,
            has_unresolved_variance=False,
            variance_override_reason=override_justification,
            variance_overridden_by=username if override_justification else None,
            upstream_modified_by=budget.upstream_modified_by,
            notes=f"[New revision {date.today()}]: this budget was created from live costs to replace "
                  f"{budget.budget_code} ({changes_desc}). By: {username}.{justification_suffix}",
            is_active=True,
        )
        _apply_prefill(new_budget, prefill)
        repo.add_row(db, new_budget)
        open_logs = _resolve_pending_logs(db, budget.budget_id, username, override_justification, now)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            raise fa_error(
                status.HTTP_409_CONFLICT,
                "FA_CODE_GENERATION_CONFLICT",
                f"الرقم المرجعي {rev_code} مستخدم بالفعل، يرجى إعادة المحاولة.",
                reference_code=rev_code,
            )
        db.refresh(new_budget)
        result_budget = new_budget
        action, message_code = "revision_created", "FA_BUDGET_SYNC_REVISION_CREATED"
        message = (f"✅ تم إنشاء إصدار مراجعة جديد للميزانية ({new_budget.budget_code}) بنجاح، وأرشفة السجل المعتمد "
                   "السابق كـ Superseded حفاظاً على الرقابة والتقارير المالية.")
        message_params: Dict[str, Any] = {"budget_code": new_budget.budget_code}
    else:
        _apply_prefill(budget, prefill)
        budget.budget_status = BUDGET_DRAFT if orig_status == BUDGET_DRAFT else BUDGET_PENDING
        budget.has_unresolved_variance = False
        budget.variance_override_reason = override_justification
        budget.variance_overridden_by = username if override_justification else None
        budget.version = (budget.version or 1) + 1
        budget.notes = _append_note(
            budget.notes,
            f"[Live cost sync {date.today()}]: costs updated ({changes_desc}). By: {username}.{justification_suffix}",
        )
        open_logs = _resolve_pending_logs(db, budget.budget_id, username, override_justification, now)
        db.commit()
        db.refresh(budget)
        result_budget = budget
        action = "auto_updated" if orig_status == BUDGET_DRAFT else "revalidation_required"
        message_code = "FA_BUDGET_SYNC_DONE"
        message = f"✅ تمت مزامنة الميزانية ({budget.budget_code}) بالتكاليف الحية بنجاح وهي الآن بحالة '{budget.budget_status}'."
        message_params = {"budget_code": budget.budget_code, "status": budget.budget_status}

    budget_response = ImportBudgetResponse.model_validate(_with_file_code(db, result_budget))
    log_responses = [BudgetVarianceLogResponse.model_validate(log) for log in open_logs]
    _sync_budget_stage(db, budget_response.import_file_id, is_approved=False, approved_by=None)
    return BudgetSyncResultResponse(
        budget=budget_response,
        action_taken=action,
        revision_created=action == "revision_created",
        original_budget_status=orig_status,
        variance_logs=log_responses,
        message=message,
        message_code=message_code,
        message_params=message_params,
    )


def override_budget_variance_service(
    db: Session,
    budget_id: int,
    current_user: User,
    justification_note: str = "",
) -> ImportBudgetApproval:
    """Overrides a hard block with a written justification (permission ``budget.sync_variance`` checked by the
    router). Numbers are not changed; pending logs are resolved as overridden."""
    budget = _get_budget(db, budget_id)
    note = (justification_note or "").strip()
    if len(note) < 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يجب كتابة مبرر تفصيلي لتجاوز حظر فارق الميزانية (لا يقل عن 5 أحرف).",
        )

    username = current_user.username
    budget.has_unresolved_variance = False
    budget.variance_override_reason = note
    budget.variance_overridden_by = username
    budget.version = (budget.version or 1) + 1
    budget.notes = _append_note(
        budget.notes,
        f"[Financial block override {date.today()}]: cost variance block overridden by {username}. Justification: {note}.",
    )
    _resolve_pending_logs(db, budget.budget_id, username, note, _now(), resolution="overridden")
    db.commit()
    db.refresh(budget)
    return _with_file_code(db, budget)


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
        raise batch_status_error(batch, status.HTTP_403_FORBIDDEN)

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
        event = _mark_paid(db, db_item, swift_ref, amount, currency)
    else:
        _set_file_swift_no(db, db_item.import_file_id, swift_ref)
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
    if size > MAX_SWIFT_FILE_BYTES:
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
