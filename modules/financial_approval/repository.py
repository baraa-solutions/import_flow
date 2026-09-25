"""
Database Repository for Financial & Management Approval (BP-012 & BP-013)
"""

from typing import Optional
from datetime import datetime, date, timezone
from sqlalchemy.orm import Session
from sqlalchemy import func
from modules.financial_approval.model import (
    PaymentRequestSession,
    ImportBudgetApproval,
    SwiftExtractionBatch,
    SwiftExtractionField,
    OcrCorrectionsLog,
)
from modules.financial_approval.schemas import (
    PaymentRequestCreate,
    PaymentRequestUpdate,
    ImportBudgetCreate,
    ImportBudgetUpdate,
)


# --- PAYMENT REQUEST REPOSITORY ---
def generate_payment_code(db: Session) -> str:
    """Generates unique Payment Request Code in format PAY-YYYY-XXX."""
    current_year = datetime.now(timezone.utc).year
    prefix = f"PAY-{current_year}-"

    last_record = (
        db.query(PaymentRequestSession)
        .filter(PaymentRequestSession.payment_code.like(f"{prefix}%"))
        .order_by(PaymentRequestSession.payment_id.desc())
        .first()
    )

    if not last_record:
        return f"{prefix}001"

    last_code = last_record.payment_code
    try:
        sequence_num = int(last_code.split("-")[-1])
        new_seq = sequence_num + 1
    except (ValueError, IndexError):
        new_seq = 1

    return f"{prefix}{new_seq:03d}"


def create_payment_request(db: Session, schema: PaymentRequestCreate) -> PaymentRequestSession:
    code = generate_payment_code(db)
    req_date = schema.request_date or date.today()
    egp_amount = schema.requested_amount * schema.exchange_rate

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
        requested_amount_egp=egp_amount,
        due_date=schema.due_date,
        request_date=req_date,
        status=schema.status or "Draft",
        beneficiary_name=schema.beneficiary_name,
        bank_name=schema.bank_name,
        swift_code=schema.swift_code,
        iban_account_no=schema.iban_account_no,
        bank_country=schema.bank_country,
        notes=schema.notes,
        is_active=True,
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item


def get_payment_request_by_id(db: Session, payment_id: int) -> PaymentRequestSession | None:
    return (
        db.query(PaymentRequestSession)
        .filter(PaymentRequestSession.payment_id == payment_id, PaymentRequestSession.is_active == True)
        .first()
    )


def get_all_payment_requests(
    db: Session,
    include_inactive: bool = False,
    search: str | None = None,
    import_file_id: int | None = None,
    po_id: int | None = None,
    supplier_id: int | None = None,
    status: str | None = None,
) -> list[PaymentRequestSession]:
    query = db.query(PaymentRequestSession)
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
        search_pattern = f"%{search}%"
        query = query.filter(
            PaymentRequestSession.payment_code.ilike(search_pattern)
            | PaymentRequestSession.title.ilike(search_pattern)
            | PaymentRequestSession.supplier_name.ilike(search_pattern)
        )

    return query.order_by(PaymentRequestSession.payment_id.desc()).all()


def update_payment_request(
    db: Session, db_item: PaymentRequestSession, schema: PaymentRequestUpdate, current_user_name: Optional[str] = None
) -> PaymentRequestSession:
    submitted_version = getattr(schema, "version", None)
    current_version = getattr(db_item, "version", 1) or 1
    if submitted_version is not None and submitted_version != current_version:
        from modules.common.concurrency import ConcurrencyConflictException, log_concurrency_conflict
        log_concurrency_conflict(
            db=db,
            entity_name="PaymentRequestSession",
            record_id=db_item.payment_id,
            current_version=current_version,
            submitted_version=submitted_version,
            attempted_by=current_user_name,
            details=f"Conflict detected while updating Payment Request #{db_item.payment_code}",
        )
        raise ConcurrencyConflictException(
            entity="PaymentRequestSession",
            record_id=db_item.payment_id,
            current_version=current_version,
            submitted_version=submitted_version,
            updated_at=db_item.updated_at,
        )

    update_data = schema.model_dump(exclude_unset=True)
    update_data.pop("version", None)
    for field, value in update_data.items():
        setattr(db_item, field, value)

    # Recalculate EGP if amount or rate changed
    db_item.requested_amount_egp = db_item.requested_amount * db_item.exchange_rate
    db_item.version = current_version + 1
    db_item.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(db_item)
    return db_item


def soft_delete_payment_request(db: Session, payment_id: int) -> bool:
    item = get_payment_request_by_id(db, payment_id)
    if not item:
        return False
    item.is_active = False
    item.updated_at = datetime.now(timezone.utc)
    db.commit()
    return True


def restore_payment_request(db: Session, payment_id: int) -> bool:
    item = (
        db.query(PaymentRequestSession)
        .filter(PaymentRequestSession.payment_id == payment_id, PaymentRequestSession.is_active == False)
        .first()
    )
    if not item:
        return False
    item.is_active = True
    item.updated_at = datetime.now(timezone.utc)
    db.commit()
    return True


# --- IMPORT BUDGET REPOSITORY ---
def generate_budget_code(db: Session) -> str:
    """Generates unique Budget Code in format BGT-YYYY-XXX."""
    current_year = datetime.now(timezone.utc).year
    prefix = f"BGT-{current_year}-"

    last_record = (
        db.query(ImportBudgetApproval)
        .filter(ImportBudgetApproval.budget_code.like(f"{prefix}%"))
        .order_by(ImportBudgetApproval.budget_id.desc())
        .first()
    )

    if not last_record:
        return f"{prefix}001"

    last_code = last_record.budget_code
    try:
        sequence_num = int(last_code.split("-")[-1])
        new_seq = sequence_num + 1
    except (ValueError, IndexError):
        new_seq = 1

    return f"{prefix}{new_seq:03d}"


def create_import_budget(db: Session, schema: ImportBudgetCreate) -> ImportBudgetApproval:
    code = generate_budget_code(db)
    total_budget = (
        schema.invoice_amount_egp
        + schema.freight_cost_egp
        + schema.customs_duties_egp
        + schema.clearance_inland_egp
    )

    db_item = ImportBudgetApproval(
        budget_code=code,
        title=schema.title,
        import_file_id=schema.import_file_id,
        po_id=schema.po_id,
        project_id=schema.project_id,
        invoice_amount_foreign=schema.invoice_amount_foreign,
        invoice_currency=schema.invoice_currency,
        invoice_amount_egp=schema.invoice_amount_egp,
        freight_cost_foreign=schema.freight_cost_foreign,
        freight_currency=schema.freight_currency,
        freight_cost_egp=schema.freight_cost_egp,
        customs_duties_egp=schema.customs_duties_egp,
        clearance_inland_egp=schema.clearance_inland_egp,
        exchange_rate=schema.exchange_rate,
        total_budget_egp=total_budget,
        budget_status="Pending Review",
        notes=schema.notes,
        is_active=True,
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item


def get_import_budget_by_id(db: Session, budget_id: int) -> ImportBudgetApproval | None:
    return (
        db.query(ImportBudgetApproval)
        .filter(ImportBudgetApproval.budget_id == budget_id, ImportBudgetApproval.is_active == True)
        .first()
    )


def get_all_import_budgets(
    db: Session,
    include_inactive: bool = False,
    search: str | None = None,
    import_file_id: int | None = None,
    po_id: int | None = None,
    budget_status: str | None = None,
) -> list[ImportBudgetApproval]:
    query = db.query(ImportBudgetApproval)
    if not include_inactive:
        query = query.filter(ImportBudgetApproval.is_active == True)

    if import_file_id:
        query = query.filter(ImportBudgetApproval.import_file_id == import_file_id)

    if po_id:
        query = query.filter(ImportBudgetApproval.po_id == po_id)
    if budget_status and budget_status != "All":
        query = query.filter(ImportBudgetApproval.budget_status == budget_status)

    if search:
        search_pattern = f"%{search}%"
        query = query.filter(
            ImportBudgetApproval.budget_code.ilike(search_pattern)
            | ImportBudgetApproval.title.ilike(search_pattern)
        )

    return query.order_by(ImportBudgetApproval.budget_id.desc()).all()


def update_import_budget(
    db: Session, db_item: ImportBudgetApproval, schema: ImportBudgetUpdate, current_user_name: Optional[str] = None
) -> ImportBudgetApproval:
    submitted_version = getattr(schema, "version", None)
    current_version = getattr(db_item, "version", 1) or 1
    if submitted_version is not None and submitted_version != current_version:
        from modules.common.concurrency import ConcurrencyConflictException, log_concurrency_conflict
        log_concurrency_conflict(
            db=db,
            entity_name="ImportBudgetApproval",
            record_id=db_item.budget_id,
            current_version=current_version,
            submitted_version=submitted_version,
            attempted_by=current_user_name,
            details=f"Conflict detected while updating Budget #{db_item.budget_code}",
        )
        raise ConcurrencyConflictException(
            entity="ImportBudgetApproval",
            record_id=db_item.budget_id,
            current_version=current_version,
            submitted_version=submitted_version,
            updated_at=db_item.updated_at,
        )

    update_data = schema.model_dump(exclude_unset=True)
    update_data.pop("version", None)
    for field, value in update_data.items():
        setattr(db_item, field, value)

    db_item.total_budget_egp = (
        db_item.invoice_amount_egp
        + db_item.freight_cost_egp
        + db_item.customs_duties_egp
        + db_item.clearance_inland_egp
    )

    if schema.budget_status == "Budget Approved" and not db_item.approved_date:
        db_item.approved_date = date.today()

    db_item.version = current_version + 1
    db_item.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(db_item)
    return db_item


def soft_delete_import_budget(db: Session, budget_id: int) -> bool:
    item = get_import_budget_by_id(db, budget_id)
    if not item:
        return False
    item.is_active = False
    item.updated_at = datetime.now(timezone.utc)
    db.commit()
    return True


def restore_import_budget(db: Session, budget_id: int) -> bool:
    item = (
        db.query(ImportBudgetApproval)
        .filter(ImportBudgetApproval.budget_id == budget_id, ImportBudgetApproval.is_active == False)
        .first()
    )
    if not item:
        return False
    item.is_active = True
    item.updated_at = datetime.now(timezone.utc)
    db.commit()
    return True


# --- SWIFT EXTRACTION BATCH REPOSITORY ---
def generate_swift_batch_code(db: Session) -> str:
    """Generates unique SWIFT Batch Code in format SWF-YYYYMMDD-XXX."""
    date_str = datetime.now(timezone.utc).strftime("%Y%m%d")
    prefix = f"SWF-{date_str}-"

    last_record = (
        db.query(SwiftExtractionBatch)
        .filter(SwiftExtractionBatch.batch_code.like(f"{prefix}%"))
        .order_by(SwiftExtractionBatch.batch_id.desc())
        .first()
    )

    if not last_record:
        return f"{prefix}001"

    last_code = last_record.batch_code
    try:
        sequence_num = int(last_code.split("-")[-1])
        new_seq = sequence_num + 1
    except (ValueError, IndexError):
        new_seq = 1

    return f"{prefix}{new_seq:03d}"


def create_swift_extraction_batch(
    db: Session,
    raw_source_text: str,
    normalized_text: str | None,
    source_filename: str | None,
    source_file_type: str | None,
    fields_breakdown: list[dict],
) -> SwiftExtractionBatch:
    """
    Creates a new SWIFT Extraction Batch in status 'EXTRACTED_PENDING_REVIEW'
    and populates all extracted field rows.
    """
    batch_code = generate_swift_batch_code(db)
    batch = SwiftExtractionBatch(
        batch_code=batch_code,
        source_filename=source_filename,
        source_file_type=source_file_type,
        raw_source_text=raw_source_text,
        normalized_text=normalized_text,
        status="EXTRACTED_PENDING_REVIEW",
    )
    db.add(batch)
    db.flush()

    for item in fields_breakdown:
        p_val = item.get("parsed_value")
        # Ensure string representation
        if p_val is not None:
            p_val_str = str(p_val)
        else:
            p_val_str = ""

        is_empty = not bool(p_val_str.strip())
        field = SwiftExtractionField(
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
            is_empty=is_empty,
        )
        db.add(field)

    db.commit()
    db.refresh(batch)
    return batch


def get_swift_extraction_batch(db: Session, batch_id: int) -> SwiftExtractionBatch | None:
    """Retrieves a batch by batch_id with all its fields."""
    return (
        db.query(SwiftExtractionBatch)
        .filter(SwiftExtractionBatch.batch_id == batch_id)
        .first()
    )


def update_swift_batch_field(
    db: Session,
    batch_id: int,
    field_key: str,
    new_value: str,
    user_name: str = "admin",
) -> SwiftExtractionField | None:
    """
    Updates an individual field in a batch:
    - Sets is_edited_by_user = True
    - Sets edited_value and final_value
    - Updates confidence_score to 1.0 (since human reviewed/provided it)
    - Records an entry in ocr_corrections_log
    """
    field = (
        db.query(SwiftExtractionField)
        .filter(
            SwiftExtractionField.batch_id == batch_id,
            SwiftExtractionField.field_key == field_key,
        )
        .first()
    )
    if not field:
        return None

    cleaned_val = new_value.strip()
    orig_val = field.final_value or field.parsed_value or ""

    # Log the correction if changed
    if orig_val != cleaned_val:
        log_entry = OcrCorrectionsLog(
            batch_id=batch_id,
            field_key=field_key,
            original_value=orig_val,
            corrected_value=cleaned_val,
            corrected_by=user_name,
            corrected_at=datetime.now(timezone.utc),
        )
        db.add(log_entry)

    field.edited_value = cleaned_val
    field.final_value = cleaned_val
    field.is_edited_by_user = True
    field.is_empty = not bool(cleaned_val)
    field.confidence_score = 1.0
    field.updated_at = datetime.now(timezone.utc)

    # Also touch batch updated_at
    batch = db.query(SwiftExtractionBatch).filter(SwiftExtractionBatch.batch_id == batch_id).first()
    if batch:
        batch.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(field)
    return field


def confirm_swift_batch_review(
    db: Session,
    batch_id: int,
    user_name: str = "admin",
) -> SwiftExtractionBatch | None:
    """
    Marks a batch as 'REVIEWED_CONFIRMED' with reviewer info and timestamp.
    """
    batch = get_swift_extraction_batch(db, batch_id)
    if not batch:
        return None

    batch.status = "REVIEWED_CONFIRMED"
    batch.reviewed_by = user_name
    batch.reviewed_at = datetime.now(timezone.utc)
    batch.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(batch)
    return batch


def update_swift_batch_status(
    db: Session,
    batch_id: int,
    status: str,
    matched_payment_id: int | None = None,
) -> SwiftExtractionBatch | None:
    """Updates batch status and optional matched payment ID."""
    batch = get_swift_extraction_batch(db, batch_id)
    if not batch:
        return None

    batch.status = status
    if matched_payment_id:
        batch.matched_payment_id = matched_payment_id
    if status == "RECONCILED":
        batch.reconciled_at = datetime.now(timezone.utc)
    batch.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(batch)
    return batch

