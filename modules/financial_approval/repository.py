"""
Database Repository for Financial & Management Approval (BP-012 & BP-013)

Queries and row writes only. Every write ``flush``es; the service commits once per request.
"""

from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import or_
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code
from modules.financial_approval.model import (
    BudgetVarianceLog,
    BudgetVarianceSetting,
    ImportBudgetApproval,
    OcrCorrectionsLog,
    PaymentRequestSession,
    SwiftExtractionBatch,
    SwiftExtractionField,
)
from modules.financial_approval.schemas import ImportBudgetCreate, PaymentRequestCreate
from modules.financial_approval.validators import (
    BATCH_PENDING,
    BUDGET_SUPERSEDED,
    PAYMENT_APPROVED,
    normalize_payment_type,
)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _file_ids_matching(db: Session, pattern: str):
    """Sub-select of import file ids whose business code matches ``pattern`` (search by file code)."""
    from modules.import_files.model import ImportFile

    return db.query(ImportFile.import_file_id).filter(
        or_(ImportFile.import_file_code.ilike(pattern), ImportFile.custom_file_number.ilike(pattern))
    )


def check_version(db: Session, item: Any, entity: str, record_id: int, code: str,
                  submitted_version: Optional[int], current_user_name: Optional[str]) -> int:
    """Optimistic concurrency check. Returns the current version or raises ``ConcurrencyConflictException``
    (the conflict log entry is committed by ``log_concurrency_conflict``)."""
    current_version = getattr(item, "version", 1) or 1
    if submitted_version is not None and submitted_version != current_version:
        from modules.common.concurrency import ConcurrencyConflictException, log_concurrency_conflict

        log_concurrency_conflict(
            db=db,
            entity_name=entity,
            record_id=record_id,
            current_version=current_version,
            submitted_version=submitted_version,
            attempted_by=current_user_name,
            details=f"Conflict detected while updating {entity} #{code}",
        )
        raise ConcurrencyConflictException(
            entity=entity,
            record_id=record_id,
            current_version=current_version,
            submitted_version=submitted_version,
            updated_at=item.updated_at,
        )
    return current_version


# --- PAYMENT REQUEST REPOSITORY ---
def next_payment_code(db: Session) -> str:
    """Next PAY-YYYY-NNN (highest numeric suffix of the year + 1)."""
    return next_yearly_code(db, PaymentRequestSession.payment_code, "PAY")


def payment_code_exists(db: Session, code: str) -> bool:
    return db.query(PaymentRequestSession.payment_id).filter(PaymentRequestSession.payment_code == code).first() is not None


def add_payment_request(
    db: Session, schema: PaymentRequestCreate, code: str, status: str, created_by: Optional[str] = None
) -> PaymentRequestSession:
    db_item = PaymentRequestSession(
        payment_code=code,
        title=schema.title,
        import_file_id=schema.import_file_id,
        po_id=schema.po_id,
        supplier_id=schema.supplier_id,
        supplier_name=schema.supplier_name,
        project_id=schema.project_id,
        payment_type=schema.payment_type,
        requested_amount=schema.requested_amount,
        advance_percentage=schema.advance_percentage,
        currency_code=schema.currency_code,
        exchange_rate=schema.exchange_rate,
        requested_amount_egp=schema.requested_amount * schema.exchange_rate,
        due_date=schema.due_date,
        request_date=schema.request_date or date.today(),
        status=status,
        beneficiary_name=schema.beneficiary_name,
        bank_name=schema.bank_name,
        swift_code=schema.swift_code,
        iban_account_no=schema.iban_account_no,
        bank_country=schema.bank_country,
        notes=schema.notes,
        is_active=True,
        created_by=created_by,
    )
    db.add(db_item)
    db.flush()
    return db_item


def add_row(db: Session, row: Any) -> Any:
    db.add(row)
    db.flush()
    return row


def get_payment_request_by_id(db: Session, payment_id: int) -> Optional[PaymentRequestSession]:
    return (
        db.query(PaymentRequestSession)
        .filter(PaymentRequestSession.payment_id == payment_id, PaymentRequestSession.is_active == True)
        .first()
    )


def get_inactive_payment_request(db: Session, payment_id: int) -> Optional[PaymentRequestSession]:
    return (
        db.query(PaymentRequestSession)
        .filter(PaymentRequestSession.payment_id == payment_id, PaymentRequestSession.is_active == False)
        .first()
    )


def _apply_payment_request_filters(
    db: Session,
    query,
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    po_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
):
    if not include_inactive:
        query = query.filter(PaymentRequestSession.is_active == True)

    if import_file_id:
        query = query.filter(PaymentRequestSession.import_file_id == import_file_id)
    if po_id:
        query = query.filter(PaymentRequestSession.po_id == po_id)
    if supplier_id:
        query = query.filter(PaymentRequestSession.supplier_id == supplier_id)
    if status and status != "All":
        query = query.filter(PaymentRequestSession.status == status)

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            PaymentRequestSession.payment_code.ilike(pattern)
            | PaymentRequestSession.title.ilike(pattern)
            | PaymentRequestSession.supplier_name.ilike(pattern)
            | PaymentRequestSession.import_file_id.in_(_file_ids_matching(db, pattern))
        )

    return query


def get_all_payment_requests(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    po_id: Optional[int] = None,
    supplier_id: Optional[int] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> Tuple[List[PaymentRequestSession], int]:
    query = db.query(PaymentRequestSession)
    query = _apply_payment_request_filters(
        db,
        query,
        include_inactive=include_inactive,
        search=search,
        import_file_id=import_file_id,
        po_id=po_id,
        supplier_id=supplier_id,
        status=status,
    )
    total = query.order_by(None).count()
    query = query.order_by(PaymentRequestSession.payment_id.desc())
    if skip:
        query = query.offset(skip)
    if limit is not None:
        query = query.limit(limit)
    return query.all(), total


def find_open_payment_of_type(
    db: Session, import_file_id: int, payment_type: str, open_statuses, exclude_id: Optional[int] = None
) -> Optional[PaymentRequestSession]:
    """First active request of the file with the same PAYMENT_TYPE (legacy labels included) in an open status."""
    code = normalize_payment_type(payment_type)
    rows = (
        db.query(PaymentRequestSession)
        .filter(
            PaymentRequestSession.import_file_id == import_file_id,
            PaymentRequestSession.is_active == True,
            PaymentRequestSession.status.in_(list(open_statuses)),
        )
        .order_by(PaymentRequestSession.payment_id.asc())
        .all()
    )
    for row in rows:
        if row.payment_id != exclude_id and normalize_payment_type(row.payment_type) == code:
            return row
    return None


def find_active_payment_by_swift_ref(
    db: Session, swift_reference_no: str, exclude_id: Optional[int] = None
) -> Optional[PaymentRequestSession]:
    query = db.query(PaymentRequestSession).filter(
        PaymentRequestSession.swift_reference_no == swift_reference_no,
        PaymentRequestSession.is_active == True,
    )
    if exclude_id is not None:
        query = query.filter(PaymentRequestSession.payment_id != exclude_id)
    return query.first()


def get_matchable_payment_requests(db: Session, target_payment_id: Optional[int] = None) -> List[PaymentRequestSession]:
    """SWIFT matching candidates: active Approved requests without a SWIFT reference, plus the target request."""
    cond = (PaymentRequestSession.status == PAYMENT_APPROVED) & (PaymentRequestSession.swift_reference_no.is_(None))
    if target_payment_id is not None:
        cond = cond | (PaymentRequestSession.payment_id == target_payment_id)
    return (
        db.query(PaymentRequestSession)
        .filter(PaymentRequestSession.is_active == True, cond)
        .order_by(PaymentRequestSession.payment_id.desc())
        .all()
    )


def apply_payment_changes(
    db: Session, db_item: PaymentRequestSession, changes: Dict[str, Any], current_version: int,
    updated_by: Optional[str] = None,
) -> PaymentRequestSession:
    for field, value in changes.items():
        setattr(db_item, field, value)
    db_item.requested_amount_egp = db_item.requested_amount * db_item.exchange_rate
    db_item.version = current_version + 1
    db_item.updated_at = _now()
    if updated_by is not None:
        db_item.updated_by = updated_by
    db.flush()
    return db_item


def set_payment_active(
    db: Session, db_item: PaymentRequestSession, active: bool, updated_by: Optional[str] = None
) -> None:
    db_item.is_active = active
    db_item.updated_at = _now()
    if updated_by is not None:
        db_item.updated_by = updated_by
    db.flush()


# --- IMPORT BUDGET REPOSITORY ---
def next_budget_code(db: Session) -> str:
    """Next BGT-YYYY-NNN (revision codes "-REV2" are skipped by the digits-only rule)."""
    return next_yearly_code(db, ImportBudgetApproval.budget_code, "BGT")


def budget_code_exists(db: Session, code: str) -> bool:
    return db.query(ImportBudgetApproval.budget_id).filter(ImportBudgetApproval.budget_code == code).first() is not None


def add_import_budget(
    db: Session,
    schema: ImportBudgetCreate,
    code: str,
    invoice_amount_egp: float,
    freight_cost_egp: float,
    created_by: Optional[str] = None,
) -> ImportBudgetApproval:
    db_item = ImportBudgetApproval(
        budget_code=code,
        title=schema.title,
        import_file_id=schema.import_file_id,
        po_id=schema.po_id,
        project_id=schema.project_id,
        invoice_amount_foreign=schema.invoice_amount_foreign,
        invoice_currency=schema.invoice_currency or "USD",
        invoice_amount_egp=invoice_amount_egp,
        freight_cost_foreign=schema.freight_cost_foreign,
        freight_currency=schema.freight_currency or "USD",
        freight_cost_egp=freight_cost_egp,
        customs_duties_egp=schema.customs_duties_egp,
        clearance_inland_egp=schema.clearance_inland_egp,
        exchange_rate=schema.exchange_rate,
        total_budget_egp=(
            (invoice_amount_egp or 0.0)
            + (freight_cost_egp or 0.0)
            + (schema.customs_duties_egp or 0.0)
            + (schema.clearance_inland_egp or 0.0)
        ),
        budget_status="Pending Review",
        notes=schema.notes,
        is_active=True,
        created_by=created_by,
    )
    db.add(db_item)
    db.flush()
    return db_item


def get_import_budget_by_id(db: Session, budget_id: int) -> Optional[ImportBudgetApproval]:
    return (
        db.query(ImportBudgetApproval)
        .filter(ImportBudgetApproval.budget_id == budget_id, ImportBudgetApproval.is_active == True)
        .first()
    )


def get_inactive_import_budget(db: Session, budget_id: int) -> Optional[ImportBudgetApproval]:
    return (
        db.query(ImportBudgetApproval)
        .filter(ImportBudgetApproval.budget_id == budget_id, ImportBudgetApproval.is_active == False)
        .first()
    )


def _apply_import_budget_filters(
    db: Session,
    query,
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    po_id: Optional[int] = None,
    budget_status: Optional[str] = None,
):
    if not include_inactive:
        query = query.filter(ImportBudgetApproval.is_active == True)

    if import_file_id:
        query = query.filter(ImportBudgetApproval.import_file_id == import_file_id)
    if po_id:
        query = query.filter(ImportBudgetApproval.po_id == po_id)
    if budget_status and budget_status != "All":
        query = query.filter(ImportBudgetApproval.budget_status == budget_status)

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            ImportBudgetApproval.budget_code.ilike(pattern)
            | ImportBudgetApproval.title.ilike(pattern)
            | ImportBudgetApproval.import_file_id.in_(_file_ids_matching(db, pattern))
        )

    return query


def get_all_import_budgets(
    db: Session,
    include_inactive: bool = False,
    search: Optional[str] = None,
    import_file_id: Optional[int] = None,
    po_id: Optional[int] = None,
    budget_status: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> Tuple[List[ImportBudgetApproval], int]:
    query = db.query(ImportBudgetApproval)
    query = _apply_import_budget_filters(
        db,
        query,
        include_inactive=include_inactive,
        search=search,
        import_file_id=import_file_id,
        po_id=po_id,
        budget_status=budget_status,
    )
    total = query.order_by(None).count()
    query = query.order_by(ImportBudgetApproval.budget_id.desc())
    if skip:
        query = query.offset(skip)
    if limit is not None:
        query = query.limit(limit)
    return query.all(), total


def find_active_budget_for_file(
    db: Session, import_file_id: int, exclude_id: Optional[int] = None
) -> Optional[ImportBudgetApproval]:
    query = db.query(ImportBudgetApproval).filter(
        ImportBudgetApproval.import_file_id == import_file_id,
        ImportBudgetApproval.is_active == True,
    )
    if exclude_id is not None:
        query = query.filter(ImportBudgetApproval.budget_id != exclude_id)
    return query.order_by(ImportBudgetApproval.budget_id.asc()).first()


def apply_budget_changes(
    db: Session, db_item: ImportBudgetApproval, changes: Dict[str, Any], current_version: int,
    updated_by: Optional[str] = None,
) -> ImportBudgetApproval:
    for field, value in changes.items():
        setattr(db_item, field, value)
    db_item.total_budget_egp = (
        (db_item.invoice_amount_egp or 0.0)
        + (db_item.freight_cost_egp or 0.0)
        + (db_item.customs_duties_egp or 0.0)
        + (db_item.clearance_inland_egp or 0.0)
    )
    db_item.version = current_version + 1
    db_item.updated_at = _now()
    if updated_by is not None:
        db_item.updated_by = updated_by
    db.flush()
    return db_item


def set_budget_active(
    db: Session, db_item: ImportBudgetApproval, active: bool, updated_by: Optional[str] = None
) -> None:
    db_item.is_active = active
    db_item.updated_at = _now()
    if updated_by is not None:
        db_item.updated_by = updated_by
    db.flush()


def pending_variance_logs(db: Session, budget_id: int):
    from modules.financial_approval.model import BudgetVarianceLog

    return db.query(BudgetVarianceLog).filter(
        BudgetVarianceLog.budget_id == budget_id,
        BudgetVarianceLog.resolution_type == "pending",
    ).all()


def first_pending_hard_block(db: Session, budget_id: int):
    from modules.financial_approval.model import BudgetVarianceLog

    return db.query(BudgetVarianceLog).filter(
        BudgetVarianceLog.budget_id == budget_id,
        BudgetVarianceLog.resolution_type == "pending",
        BudgetVarianceLog.is_hard_block == True,
    ).first()


# --- SWIFT EXTRACTION BATCH REPOSITORY ---
def next_swift_batch_code(db: Session) -> str:
    """Next SWF-YYYYMMDD-NNN: the yearly generator with the day stamp in the "year" slot (sequence per day)."""
    return next_yearly_code(db, SwiftExtractionBatch.batch_code, "SWF", year=int(_now().strftime("%Y%m%d")))


def swift_batch_code_exists(db: Session, code: str) -> bool:
    return db.query(SwiftExtractionBatch.batch_id).filter(SwiftExtractionBatch.batch_code == code).first() is not None


def add_swift_extraction_batch(
    db: Session,
    batch_code: str,
    raw_source_text: str,
    normalized_text: Optional[str],
    source_filename: Optional[str],
    source_file_type: Optional[str],
    fields_breakdown: List[dict],
) -> SwiftExtractionBatch:
    """Adds a batch in EXTRACTED_PENDING_REVIEW with one row per extracted field (flush only)."""
    batch = SwiftExtractionBatch(
        batch_code=batch_code,
        source_filename=source_filename,
        source_file_type=source_file_type,
        raw_source_text=raw_source_text,
        normalized_text=normalized_text,
        status=BATCH_PENDING,
    )
    db.add(batch)
    db.flush()

    for item in fields_breakdown:
        p_val = item.get("parsed_value")
        p_val_str = str(p_val) if p_val is not None else ""
        db.add(SwiftExtractionField(
            batch_id=batch.batch_id,
            field_key=item.get("field_key", ""),
            swift_field_code=item.get("swift_field_code"),
            field_label=item.get("field_label", ""),
            raw_ocr_text=item.get("raw_ocr_text"),
            parsed_value=p_val_str,
            confidence_score=float(item.get("confidence_score", 0.0)),
            is_edited_by_user=False,
            edited_value=None,
            final_value=p_val_str,
            is_mandatory=bool(item.get("is_mandatory", False)),
            is_empty=not bool(p_val_str.strip()),
        ))
    db.flush()
    return batch


def get_swift_extraction_batch(db: Session, batch_id: int) -> Optional[SwiftExtractionBatch]:
    return db.query(SwiftExtractionBatch).filter(SwiftExtractionBatch.batch_id == batch_id).first()


def update_swift_batch_field(
    db: Session,
    batch_id: int,
    field_key: str,
    new_value: str,
    user_name: str,
) -> Optional[SwiftExtractionField]:
    """Stores a user edit (confidence 1.0) and an ``ocr_corrections_log`` row when the value changed. Flush only."""
    field = (
        db.query(SwiftExtractionField)
        .filter(SwiftExtractionField.batch_id == batch_id, SwiftExtractionField.field_key == field_key)
        .first()
    )
    if not field:
        return None

    cleaned_val = new_value.strip()
    orig_val = field.final_value or field.parsed_value or ""
    now = _now()
    if orig_val != cleaned_val:
        db.add(OcrCorrectionsLog(
            batch_id=batch_id,
            field_key=field_key,
            original_value=orig_val,
            corrected_value=cleaned_val,
            corrected_by=user_name,
            corrected_at=now,
        ))

    field.edited_value = cleaned_val
    field.final_value = cleaned_val
    field.is_edited_by_user = True
    field.is_empty = not bool(cleaned_val)
    field.confidence_score = 1.0
    field.updated_at = now
    db.flush()
    return field


def mark_swift_batch_reviewed(db: Session, batch: SwiftExtractionBatch, user_name: str) -> SwiftExtractionBatch:
    now = _now()
    batch.status = "REVIEWED_CONFIRMED"
    batch.reviewed_by = user_name
    batch.reviewed_at = now
    batch.updated_at = now
    db.flush()
    return batch


def reopen_swift_batch_review(db: Session, batch: SwiftExtractionBatch) -> None:
    """A confirmed batch whose fields change goes back to review (the confirmation no longer covers them)."""
    batch.status = BATCH_PENDING
    batch.reviewed_by = None
    batch.reviewed_at = None
    batch.updated_at = _now()
    db.flush()


def mark_swift_batch_reconciled(db: Session, batch: SwiftExtractionBatch, payment_id: int) -> SwiftExtractionBatch:
    now = _now()
    batch.status = "RECONCILED"
    batch.matched_payment_id = payment_id
    batch.reconciled_at = now
    batch.updated_at = now
    db.flush()
    return batch


def variance_logs_for_budget(db: Session, budget_id: int) -> List[BudgetVarianceLog]:
    return (
        db.query(BudgetVarianceLog)
        .filter(BudgetVarianceLog.budget_id == budget_id)
        .order_by(BudgetVarianceLog.detected_at.desc())
        .all()
    )


def get_setting(db: Session, key: str) -> Optional[BudgetVarianceSetting]:
    return db.query(BudgetVarianceSetting).filter(BudgetVarianceSetting.setting_key == key).first()


def active_budgets_for_file(db: Session, import_file_id: int) -> List[ImportBudgetApproval]:
    return (
        db.query(ImportBudgetApproval)
        .filter(
            ImportBudgetApproval.import_file_id == import_file_id,
            ImportBudgetApproval.is_active == True,
            ImportBudgetApproval.budget_status != BUDGET_SUPERSEDED,
        )
        .all()
    )

