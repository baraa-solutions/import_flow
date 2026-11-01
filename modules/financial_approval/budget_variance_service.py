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
    _now, _append_note, _insert_with_unique_code, _notify, _ref_pattern, _commercial_rate_to_egp,
    file_code_or_id, _require_currency, _fx_missing, _require_rate, _budget_egp_amounts
)

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

    inv_foreign = schema.invoice_amount_foreign or 0.0
    frt_foreign = schema.freight_cost_foreign or 0.0
    if inv_foreign > 0 or frt_foreign > 0:
        calc_inv_egp, calc_frt_egp = _budget_egp_amounts(
            db,
            inv_foreign,
            schema.invoice_currency,
            frt_foreign,
            schema.freight_currency,
            schema.exchange_rate,
        )
        inv_egp = calc_inv_egp if inv_foreign > 0 else (schema.invoice_amount_egp or 0.0)
        frt_egp = calc_frt_egp if frt_foreign > 0 else (schema.freight_cost_egp or 0.0)
    else:
        inv_egp = schema.invoice_amount_egp or 0.0
        frt_egp = schema.freight_cost_egp or 0.0

    created = _insert_with_unique_code(
        db, lambda: repo.next_budget_code(db), lambda c: repo.budget_code_exists(db, c),
        lambda code: repo.add_import_budget(db, schema, code, inv_egp, frt_egp, created_by=current_user_name),
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
        if by_code is not None and by_code.search(notes + " " + (task.title or "")):
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
    db_item.updated_by = approved_by

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


def clone_import_budget_service(
    db: Session, budget_id: int, schema: CloneImportBudgetRequest,
    current_user_name: Optional[str] = None,
) -> ImportBudgetApproval:
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
            created_by=current_user_name,
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

    inv_foreign = changes.get("invoice_amount_foreign", db_item.invoice_amount_foreign) or 0.0
    inv_currency = changes.get("invoice_currency", db_item.invoice_currency)
    frt_foreign = changes.get("freight_cost_foreign", db_item.freight_cost_foreign) or 0.0
    frt_currency = changes.get("freight_currency", db_item.freight_currency)
    rate = changes.get("exchange_rate", db_item.exchange_rate) or 1.0

    if inv_foreign > 0 or frt_foreign > 0:
        calc_inv_egp, calc_frt_egp = _budget_egp_amounts(
            db, inv_foreign, inv_currency, frt_foreign, frt_currency, rate
        )
        if inv_foreign > 0:
            changes["invoice_amount_egp"] = calc_inv_egp
        if frt_foreign > 0:
            changes["freight_cost_egp"] = calc_frt_egp

    repo.apply_budget_changes(db, db_item, changes, current_version, updated_by=current_user_name)
    db.commit()
    import_file_id = db_item.import_file_id
    _sync_budget_stage(db, import_file_id, is_approved=False, approved_by=None)
    return _with_file_code(db, _get_budget(db, budget_id))


def soft_delete_import_budget_service(
    db: Session, budget_id: int, current_user_name: Optional[str] = None
) -> bool:
    item = _get_budget(db, budget_id)
    if item.budget_status in BUDGET_LOCKED:
        raise budget_locked_error(item)
    repo.set_budget_active(db, item, False, updated_by=current_user_name)
    db.commit()
    return True


def restore_import_budget_service(
    db: Session, budget_id: int, current_user_name: Optional[str] = None
) -> bool:
    item = repo.get_inactive_import_budget(db, budget_id)
    if item is None:
        raise not_found(L_BUDGET, budget_id)
    if item.import_file_id and repo.find_active_budget_for_file(db, item.import_file_id, exclude_id=item.budget_id):
        raise _budget_duplicate_error(db, item.import_file_id)
    repo.set_budget_active(db, item, True, updated_by=current_user_name)
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
        p_term = po.payment_terms
        if p_term:
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
        payment_terms_summary = None

    # 2. Supplier and banking info
    sup = None
    if imp.supplier_id:
        sup = db.query(Supplier).filter(Supplier.supplier_id == imp.supplier_id).first()
    elif pos and pos[0].supplier_id:
        sup = db.query(Supplier).filter(Supplier.supplier_id == pos[0].supplier_id).first()
    elif imp.supplier_name:
        # Legacy files without supplier_id: best-effort match on the stored name text (FA-21 MINOR, kept).
        sup = db.query(Supplier).filter(Supplier.company_name == imp.supplier_name).first()
    supplier_name = sup.company_name if sup else imp.supplier_name

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
    freight_currency: Optional[str] = None
    for s in shipping_sessions:
        s_date = s.created_at.date() if getattr(s, "created_at", None) else date.today()
        for itm in s.items:
            from modules.shipping_scenarios.service import scenario_item_totals
            _, f_amt = scenario_item_totals(db, itm, s_date)
            if f_amt <= 0:
                continue
            source = f"freight quotation ({s.session_code})" if getattr(s, "session_code", None) else "freight quotation"
            curr = _require_currency(getattr(itm, "quotation_currency", None), source)
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
        incoterm=imp.incoterm_code,
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
    if prefill.freight_currency is not None:
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
        next_rev = (budget.revision_number or 1) + 1
        rev_code = f"{budget.budget_code.split('-REV')[0]}-REV{next_rev}"
        if repo.budget_code_exists(db, rev_code):
            raise fa_error(status.HTTP_409_CONFLICT, "FA_CODE_GENERATION_CONFLICT",
                           f"الرقم المرجعي {rev_code} مستخدم بالفعل، يرجى إعادة المحاولة.", reference_code=rev_code)

        budget.budget_status = BUDGET_SUPERSEDED
        budget.has_unresolved_variance = False
        budget.version = (budget.version or 1) + 1
        budget.updated_at = now
        budget.updated_by = username
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
            created_by=username,
            updated_by=username,
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
        budget.updated_at = now
        budget.updated_by = username
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
    budget.updated_at = _now()
    budget.updated_by = username
    budget.notes = _append_note(
        budget.notes,
        f"[Financial block override {date.today()}]: cost variance block overridden by {username}. Justification: {note}.",
    )
    _resolve_pending_logs(db, budget.budget_id, username, note, _now(), resolution="overridden")
    db.commit()
    db.refresh(budget)
    return _with_file_code(db, budget)

