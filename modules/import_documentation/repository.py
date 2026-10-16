"""
Database Repository for Import Documentation & ACI (Phase 3 - BP-014 to BP-019)

Rules (Phase 3a, DOC-07 / DOC-08 / DOC-10 / DOC-22):
- Lookups and updates by id see ACTIVE rows only and return ``None`` / ``False`` when the row is missing or
  soft-deleted; the service turns that into a 404 (``validators.not_found``). Nothing here raises ``ValueError``.
- ``update_*`` never touches ``is_active``: restoring is explicit (``restore_acid_session``,
  ``reactivate_po_reconciliation_session``).
- Business codes come from ``sequence_generator.next_yearly_code`` (max numeric suffix of the year + 1; non-digit
  suffixes such as ``-v2`` are ignored). The unique constraint on each code column stays the final guard.
- ``commit=False`` flushes only, so a service can save several rows in one transaction.
"""

from datetime import datetime, date, timedelta, timezone
from typing import List, Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code
from modules.common.validators import not_null_columns
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    ShipmentDocumentItem,
    CustomsDeclarationDraft,
    DraftBLReviewSession,
    CertificateOfOriginReviewSession,
    InspectionCertificateReviewSession,
    POPackingReconciliationSession,
    InvoiceBLMatchSession,
)
from modules.import_documentation.schemas import (
    AcidRegistrationCreate,
    AcidRegistrationUpdate,
    BankingDocumentCreate,
    BankingDocumentUpdate,
    ShipmentDocumentCreate,
    ShipmentDocumentUpdate,
    CustomsDeclarationCreate,
    POReconciliationSessionCreate,
    POReconciliationSessionUpdate,
    InvoiceBLMatchSessionCreate,
    InvoiceBLMatchSessionUpdate,
    DraftBLReviewCreate,
    DraftBLReviewUpdate,
    CertificateOfOriginReviewCreate,
    CertificateOfOriginReviewUpdate,
    InspectionCertificateReviewCreate,
    InspectionCertificateReviewUpdate,
)
from modules.purchase_orders.model import PurchaseOrder

# ACID validity used when the request carries no expiry date (same default as the ACID tracker, DOC-15/DOC-21).
ACID_DEFAULT_VALIDITY_DAYS = 90
ACID_PLACEHOLDER_NUMBERS = frozenset({"PENDING", "REQUESTED", "DRAFT", ""})


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _save(db: Session, item, commit: bool):
    """Commit + refresh, or flush only (``commit=False``) so the caller owns the transaction."""
    if commit:
        db.commit()
        db.refresh(item)
    else:
        db.flush()
    return item


def _apply(item, data: dict) -> None:
    for field, value in data.items():
        setattr(item, field, value)


def _active_by_id(db: Session, model, id_column, entity_id: int):
    return db.query(model).filter(id_column == entity_id, model.is_active == True).first()


def _soft_delete(db: Session, item) -> bool:
    if item is None:
        return False
    item.is_active = False
    item.updated_at = _now()
    db.flush()
    return True


# --- ACID REPOSITORY (BP-014) ---
def generate_acid_code(db: Session) -> str:
    return next_yearly_code(db, AcidRegistrationSession.acid_code, "ACID", pad=3)


def create_acid_session(db: Session, schema: AcidRegistrationCreate, commit: bool = True) -> AcidRegistrationSession:
    code = generate_acid_code(db)
    req_date = schema.requested_date or date.today()
    gen_date = schema.generated_date
    acid_number = (schema.acid_number or "PENDING").strip()
    # expiry_date is NOT NULL: without an explicit expiry use issue (or request) date + the default validity,
    # never "today" (which made every new session show EXPIRED at once).
    exp_date = schema.expiry_date or ((gen_date or req_date) + timedelta(days=ACID_DEFAULT_VALIDITY_DAYS))
    is_placeholder = acid_number.upper() in ACID_PLACEHOLDER_NUMBERS

    db_item = AcidRegistrationSession(
        acid_code=code,
        acid_number=acid_number,
        import_file_id=schema.import_file_id,
        po_id=schema.po_id,
        po_number=schema.po_number,
        po_date=schema.po_date,
        importer_id=schema.importer_id,
        importer_name=schema.importer_name,
        importer_tax_id=schema.importer_tax_id,
        importer_address=schema.importer_address,
        supplier_id=schema.supplier_id,
        exporter_name=schema.exporter_name,
        exporter_reg_type=schema.exporter_reg_type or "VAT Number",
        exporter_reg_id=schema.exporter_reg_id,
        exporter_country=schema.exporter_country,
        exporter_country_code=schema.exporter_country_code,
        exporter_address=schema.exporter_address,
        exporter_phone=schema.exporter_phone,
        cargox_id=schema.cargox_id,
        proforma_invoice_no=schema.proforma_invoice_no,
        proforma_invoice_date=schema.proforma_invoice_date,
        invoice_date=schema.invoice_date,
        invoice_type=schema.invoice_type or "Proforma Invoice",
        invoice_attachment_name=schema.invoice_attachment_name,
        pol_name=schema.pol_name,
        pod_name=schema.pod_name,
        customs_broker_id=schema.customs_broker_id,
        customs_broker_name=schema.customs_broker_name,
        customs_broker_phone=schema.customs_broker_phone,
        requested_date=req_date,
        generated_date=gen_date,
        expiry_date=exp_date,
        raw_nafeza_text=schema.raw_nafeza_text,
        requested_data=schema.requested_data,
        generated_data=schema.generated_data,
        discrepancies_data=schema.discrepancies_data,
        discrepancy_override_reason=schema.discrepancy_override_reason,
        is_importer_matched=True,
        is_exporter_matched=True,
        is_invoice_matched=True,
        is_ports_matched=True,
        has_discrepancies=False,
        verification_notes=schema.verification_notes,
        status="Requested" if (is_placeholder or not gen_date) else "Verified",
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def get_acid_session_by_id(db: Session, acid_id: int, include_inactive: bool = False) -> AcidRegistrationSession | None:
    query = db.query(AcidRegistrationSession).filter(AcidRegistrationSession.acid_id == acid_id)
    if not include_inactive:
        query = query.filter(AcidRegistrationSession.is_active == True)
    return query.first()


def get_acid_session_active(db: Session, acid_id: int) -> AcidRegistrationSession | None:
    return get_acid_session_by_id(db, acid_id)


def get_acid_session_by_file_id(db: Session, import_file_id: int, include_inactive: bool = False) -> AcidRegistrationSession | None:
    query = db.query(AcidRegistrationSession).filter(AcidRegistrationSession.import_file_id == import_file_id)
    if not include_inactive:
        query = query.filter(AcidRegistrationSession.is_active == True)
    return query.first()


def restore_acid_session(db: Session, acid_id: int) -> AcidRegistrationSession | None:
    item = get_acid_session_by_id(db, acid_id, include_inactive=True)
    if not item:
        return None
    item.is_active = True
    item.updated_at = _now()
    db.flush()
    return item


def get_all_acid_sessions(
    db: Session,
    include_inactive: bool = False,
    search: str | None = None,
    import_file_id: int | None = None,
    status: str | None = None,
) -> list[AcidRegistrationSession]:
    query = db.query(AcidRegistrationSession)
    if not include_inactive:
        query = query.filter(AcidRegistrationSession.is_active == True)

    if import_file_id:
        query = query.filter(AcidRegistrationSession.import_file_id == import_file_id)

    if status and status != "All":
        query = query.filter(AcidRegistrationSession.status == status)

    if search:
        p = f"%{search}%"
        query = query.filter(
            AcidRegistrationSession.acid_code.ilike(p)
            | AcidRegistrationSession.acid_number.ilike(p)
            | AcidRegistrationSession.importer_name.ilike(p)
            | AcidRegistrationSession.exporter_name.ilike(p)
        )

    return query.order_by(AcidRegistrationSession.acid_id.desc()).all()


def update_acid_session(
    db: Session, db_item: AcidRegistrationSession, schema: AcidRegistrationUpdate, commit: bool = True
) -> AcidRegistrationSession:
    """``db_item`` must be an active row loaded by the service (``get_acid_session_active``)."""
    _apply(db_item, schema.model_dump(exclude_unset=True))
    db_item.updated_at = _now()
    return _save(db, db_item, commit)


def soft_delete_acid_session(db: Session, acid_id: int) -> bool:
    return _soft_delete(db, get_acid_session_by_id(db, acid_id))


# --- BANKING DOCUMENTS REPOSITORY (BP-015) ---
def generate_bank_doc_code(db: Session) -> str:
    return next_yearly_code(db, BankingDocumentSession.bank_doc_code, "FORM4", pad=3)


def create_banking_document(db: Session, schema: BankingDocumentCreate, commit: bool = True) -> BankingDocumentSession:
    code = generate_bank_doc_code(db)
    req_date = schema.request_date or schema.issue_date or date.today()
    iss_date = schema.issue_date or req_date
    rec_date = schema.received_date
    exec_days = schema.execution_days or 0
    if rec_date and req_date:
        exec_days = max(0, (rec_date - req_date).days)

    ref_num = schema.doc_reference_number or "PENDING"
    initial_status = "Received" if rec_date or (ref_num != "PENDING" and ref_num.strip()) else "Requested"

    db_item = BankingDocumentSession(
        bank_doc_code=code,
        doc_type=schema.doc_type,
        import_file_id=schema.import_file_id,
        po_id=schema.po_id,
        bank_id=schema.bank_id,
        bank_name=schema.bank_name,
        doc_reference_number=ref_num,
        amount=schema.amount,
        currency_code=schema.currency_code,
        request_date=req_date,
        received_date=rec_date,
        execution_days=exec_days,
        issue_date=iss_date,
        expiry_date=schema.expiry_date,
        status=initial_status,
        notes=schema.notes,
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def get_banking_document_by_id(db: Session, bank_doc_id: int) -> BankingDocumentSession | None:
    return _active_by_id(db, BankingDocumentSession, BankingDocumentSession.bank_doc_id, bank_doc_id)


get_banking_document_active = get_banking_document_by_id


def update_banking_document(
    db: Session, db_item: BankingDocumentSession, schema: BankingDocumentUpdate, commit: bool = True
) -> BankingDocumentSession:
    """Sent fields are applied as-is; an explicit ``null`` clears a nullable column and is ignored for a
    NOT NULL one (DOC-25)."""
    required = not_null_columns(BankingDocumentSession)
    for field, value in schema.model_dump(exclude_unset=True).items():
        if not hasattr(db_item, field) or (value is None and field in required):
            continue
        setattr(db_item, field, value)

    # Recalculate execution days if dates changed
    if db_item.received_date and db_item.request_date:
        db_item.execution_days = max(0, (db_item.received_date - db_item.request_date).days)
        if db_item.doc_reference_number and db_item.doc_reference_number != "PENDING":
            db_item.status = "Received"

    db_item.updated_at = _now()
    return _save(db, db_item, commit)


def delete_banking_document(db: Session, db_item: BankingDocumentSession) -> bool:
    return _soft_delete(db, db_item if db_item is not None and db_item.is_active else None)


def get_all_banking_documents(db: Session, import_file_id: int | None = None) -> list[BankingDocumentSession]:
    query = db.query(BankingDocumentSession).filter(BankingDocumentSession.is_active == True)
    if import_file_id:
        query = query.filter(BankingDocumentSession.import_file_id == import_file_id)
    return query.order_by(BankingDocumentSession.bank_doc_id.desc()).all()


# --- SHIPMENT DOCUMENT ITEMS REPOSITORY (BP-016 to BP-018) ---
def generate_shipment_doc_code(db: Session) -> str:
    return next_yearly_code(db, ShipmentDocumentItem.document_code, "DOC", pad=3)


def create_shipment_document(db: Session, schema: ShipmentDocumentCreate, commit: bool = True) -> ShipmentDocumentItem:
    code = generate_shipment_doc_code(db)
    iss_date = schema.issue_date or date.today()
    rec_date = schema.received_date or date.today()

    db_item = ShipmentDocumentItem(
        document_code=code,
        import_file_id=schema.import_file_id,
        po_id=schema.po_id,
        doc_name=schema.doc_name,
        doc_number=schema.doc_number,
        issue_date=iss_date,
        received_date=rec_date,
        status="Approved",
        is_cargox_uploaded=False,
        is_bl_endorsed=False,
        notes=schema.notes,
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def get_shipment_document_active(db: Session, doc_id: int) -> ShipmentDocumentItem | None:
    return _active_by_id(db, ShipmentDocumentItem, ShipmentDocumentItem.document_id, doc_id)


def get_all_shipment_documents(db: Session, import_file_id: int | None = None) -> list[ShipmentDocumentItem]:
    query = db.query(ShipmentDocumentItem).filter(ShipmentDocumentItem.is_active == True)
    if import_file_id:
        query = query.filter(ShipmentDocumentItem.import_file_id == import_file_id)
    return query.order_by(ShipmentDocumentItem.document_id.desc()).all()


def update_shipment_document(
    db: Session, doc_id: int, schema: ShipmentDocumentUpdate, commit: bool = True
) -> ShipmentDocumentItem | None:
    item = get_shipment_document_active(db, doc_id)
    if not item:
        return None
    _apply(item, schema.model_dump(exclude_unset=True))
    item.updated_at = _now()
    return _save(db, item, commit)


# --- CUSTOMS DECLARATION 46 REPOSITORY (BP-019) ---
def generate_customs_declaration_code(db: Session) -> str:
    return next_yearly_code(db, CustomsDeclarationDraft.declaration_code, "DEC46", pad=3)


def create_customs_declaration(
    db: Session, schema: CustomsDeclarationCreate, commit: bool = True
) -> CustomsDeclarationDraft:
    db_item = CustomsDeclarationDraft(
        declaration_code=generate_customs_declaration_code(db),
        import_file_id=schema.import_file_id,
        po_id=schema.po_id,
        acid_number=schema.acid_number,
        form4_number=schema.form4_number,
        bl_number=schema.bl_number,
        total_cif_val_egp=schema.total_cif_val_egp if schema.total_cif_val_egp is not None else 0.0,
        total_customs_duties_egp=schema.total_customs_duties_egp if schema.total_customs_duties_egp is not None else 0.0,
        total_vat_egp=schema.total_vat_egp if schema.total_vat_egp is not None else 0.0,
        declaration_status="Draft Prepared",
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def get_customs_declaration_active(db: Session, declaration_id: int) -> CustomsDeclarationDraft | None:
    return _active_by_id(db, CustomsDeclarationDraft, CustomsDeclarationDraft.declaration_id, declaration_id)


# --- PHASE 6: DRAFT BILL OF LADING (B/L) REPOSITORY ---
def generate_bl_review_code(db: Session) -> str:
    return next_yearly_code(db, DraftBLReviewSession.bl_review_code, "BL-REV", pad=4)


def get_draft_bl_reviews(
    db: Session,
    include_inactive: bool = False,
    import_file_id: int | None = None,
    status: str | None = None,
    search: str | None = None,
    is_draft: bool | None = None,
) -> list[DraftBLReviewSession]:
    query = db.query(DraftBLReviewSession)
    if not include_inactive:
        query = query.filter(DraftBLReviewSession.is_active == True)
    if import_file_id:
        query = query.filter(DraftBLReviewSession.import_file_id == import_file_id)
    if is_draft is not None:
        query = query.filter(DraftBLReviewSession.is_draft == is_draft)
    if status and status != "All":
        query = query.filter(DraftBLReviewSession.status == status)
    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            (DraftBLReviewSession.bl_review_code.ilike(s))
            | (DraftBLReviewSession.draft_bl_number.ilike(s))
            | (DraftBLReviewSession.shipping_line.ilike(s))
            | (DraftBLReviewSession.booking_no.ilike(s))
            | (DraftBLReviewSession.hbl_no.ilike(s))
            | (DraftBLReviewSession.mbl_no.ilike(s))
            | (DraftBLReviewSession.vessel_name.ilike(s))
        )
    return query.order_by(DraftBLReviewSession.bl_review_id.desc()).all()


def get_draft_bl_review_by_id(db: Session, review_id: int, include_inactive: bool = False) -> DraftBLReviewSession | None:
    query = db.query(DraftBLReviewSession).filter(DraftBLReviewSession.bl_review_id == review_id)
    if not include_inactive:
        query = query.filter(DraftBLReviewSession.is_active == True)
    return query.first()


def get_draft_bl_review_active(db: Session, review_id: int) -> DraftBLReviewSession | None:
    return get_draft_bl_review_by_id(db, review_id)


def get_draft_bl_review_by_file_id(
    db: Session,
    import_file_id: int,
    include_inactive: bool = False,
    include_drafts: bool = True,
) -> DraftBLReviewSession | None:
    query = db.query(DraftBLReviewSession).filter(DraftBLReviewSession.import_file_id == import_file_id)
    if not include_inactive:
        query = query.filter(DraftBLReviewSession.is_active == True)
    if not include_drafts:
        query = query.filter(DraftBLReviewSession.is_draft == False)
    return query.order_by(DraftBLReviewSession.bl_review_id.desc()).first()


def get_draft_bl_root(db: Session, review: DraftBLReviewSession) -> DraftBLReviewSession:
    """First session of a version chain (follows ``parent_session_id``, active or not; cycle-safe)."""
    current, seen = review, {review.bl_review_id}
    while current.parent_session_id and current.parent_session_id not in seen:
        parent = get_draft_bl_review_by_id(db, current.parent_session_id, include_inactive=True)
        if parent is None:
            break
        seen.add(parent.bl_review_id)
        current = parent
    return current


def get_draft_bl_versions(db: Session, root_code: str, include_inactive: bool = True) -> List[DraftBLReviewSession]:
    """Every version of the chain whose root code is ``root_code`` (``root_code`` itself and ``root_code-vN``),
    ordered by ``version_number`` then id."""
    query = db.query(DraftBLReviewSession).filter(
        or_(
            DraftBLReviewSession.bl_review_code == root_code,
            DraftBLReviewSession.bl_review_code.like(f"{root_code}-v%"),
        )
    )
    if not include_inactive:
        query = query.filter(DraftBLReviewSession.is_active == True)
    return query.order_by(DraftBLReviewSession.version_number, DraftBLReviewSession.bl_review_id).all()


def create_draft_bl_review(db: Session, schema: DraftBLReviewCreate, commit: bool = True) -> DraftBLReviewSession:
    code = generate_bl_review_code(db)
    data = schema.model_dump(exclude_unset=True)
    data.pop("is_active", None)
    db_item = DraftBLReviewSession(
        bl_review_code=code,
        **data,
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def add_draft_bl_review(db: Session, item: DraftBLReviewSession, commit: bool = True) -> DraftBLReviewSession:
    """Persist a session built by the service (new draft versions)."""
    db.add(item)
    return _save(db, item, commit)


def update_draft_bl_review(
    db: Session, review_id: int, schema: DraftBLReviewUpdate, commit: bool = True
) -> DraftBLReviewSession | None:
    item = get_draft_bl_review_active(db, review_id)
    if not item:
        return None
    _apply(item, schema.model_dump(exclude_unset=True))
    item.updated_at = _now()
    return _save(db, item, commit)


def delete_draft_bl_review(db: Session, review_id: int) -> bool:
    return _soft_delete(db, get_draft_bl_review_active(db, review_id))


# --- PHASE 6: CERTIFICATE OF ORIGIN (COO / EUR.1) REPOSITORY ---
def generate_coo_review_code(db: Session) -> str:
    return next_yearly_code(db, CertificateOfOriginReviewSession.coo_review_code, "COO", pad=4)


def get_coo_reviews(
    db: Session,
    include_inactive: bool = False,
    import_file_id: int | None = None,
    status: str | None = None,
    search: str | None = None,
    is_draft: bool | None = None,
) -> list[CertificateOfOriginReviewSession]:
    query = db.query(CertificateOfOriginReviewSession)
    if not include_inactive:
        query = query.filter(CertificateOfOriginReviewSession.is_active == True)
    if import_file_id:
        query = query.filter(CertificateOfOriginReviewSession.import_file_id == import_file_id)
    if is_draft is not None:
        query = query.filter(CertificateOfOriginReviewSession.is_draft == is_draft)
    if status and status != "All":
        query = query.filter(CertificateOfOriginReviewSession.status == status)
    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            (CertificateOfOriginReviewSession.coo_review_code.ilike(s))
            | (CertificateOfOriginReviewSession.certificate_number.ilike(s))
            | (CertificateOfOriginReviewSession.exporter_name.ilike(s))
            | (CertificateOfOriginReviewSession.importer_name.ilike(s))
            | (CertificateOfOriginReviewSession.invoice_number.ilike(s))
            | (CertificateOfOriginReviewSession.certificate_type.ilike(s))
        )
    return query.order_by(CertificateOfOriginReviewSession.coo_review_id.desc()).all()


def get_coo_review_by_id(db: Session, review_id: int, include_inactive: bool = False) -> CertificateOfOriginReviewSession | None:
    query = db.query(CertificateOfOriginReviewSession).filter(CertificateOfOriginReviewSession.coo_review_id == review_id)
    if not include_inactive:
        query = query.filter(CertificateOfOriginReviewSession.is_active == True)
    return query.first()


def get_coo_review_active(db: Session, review_id: int) -> CertificateOfOriginReviewSession | None:
    return get_coo_review_by_id(db, review_id)


def get_coo_review_by_file_id(
    db: Session,
    import_file_id: int,
    include_inactive: bool = False,
    include_drafts: bool = True,
) -> CertificateOfOriginReviewSession | None:
    query = db.query(CertificateOfOriginReviewSession).filter(CertificateOfOriginReviewSession.import_file_id == import_file_id)
    if not include_inactive:
        query = query.filter(CertificateOfOriginReviewSession.is_active == True)
    if not include_drafts:
        query = query.filter(CertificateOfOriginReviewSession.is_draft == False)
    return query.order_by(CertificateOfOriginReviewSession.coo_review_id.desc()).first()


def create_coo_review(
    db: Session, schema: CertificateOfOriginReviewCreate, commit: bool = True
) -> CertificateOfOriginReviewSession:
    code = generate_coo_review_code(db)
    data = schema.model_dump(exclude_unset=True)
    data.pop("is_active", None)
    db_item = CertificateOfOriginReviewSession(
        coo_review_code=code,
        **data,
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def update_coo_review(
    db: Session, review_id: int, schema: CertificateOfOriginReviewUpdate, commit: bool = True
) -> CertificateOfOriginReviewSession | None:
    item = get_coo_review_active(db, review_id)
    if not item:
        return None
    _apply(item, schema.model_dump(exclude_unset=True))
    item.updated_at = _now()
    return _save(db, item, commit)


def delete_coo_review(db: Session, review_id: int) -> bool:
    return _soft_delete(db, get_coo_review_active(db, review_id))


# --- PHASE 6: INSPECTION CERTIFICATE REPOSITORY ---
def generate_inspection_review_code(db: Session) -> str:
    return next_yearly_code(db, InspectionCertificateReviewSession.inspection_review_code, "INSP", pad=4)


def get_inspection_reviews(
    db: Session,
    include_inactive: bool = False,
    import_file_id: int | None = None,
    status: str | None = None,
    search: str | None = None,
) -> list[InspectionCertificateReviewSession]:
    query = db.query(InspectionCertificateReviewSession)
    if not include_inactive:
        query = query.filter(InspectionCertificateReviewSession.is_active == True)
    if import_file_id:
        query = query.filter(InspectionCertificateReviewSession.import_file_id == import_file_id)
    if status and status != "All":
        query = query.filter(InspectionCertificateReviewSession.status == status)
    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            (InspectionCertificateReviewSession.inspection_review_code.ilike(s))
            | (InspectionCertificateReviewSession.certificate_number.ilike(s))
            | (InspectionCertificateReviewSession.inspection_agency.ilike(s))
            | (InspectionCertificateReviewSession.inspection_type.ilike(s))
            | (InspectionCertificateReviewSession.regulatory_authority.ilike(s))
        )
    return query.order_by(InspectionCertificateReviewSession.inspection_review_id.desc()).all()


def get_inspection_review_by_id(db: Session, review_id: int, include_inactive: bool = False) -> InspectionCertificateReviewSession | None:
    query = db.query(InspectionCertificateReviewSession).filter(InspectionCertificateReviewSession.inspection_review_id == review_id)
    if not include_inactive:
        query = query.filter(InspectionCertificateReviewSession.is_active == True)
    return query.first()


def get_inspection_review_active(db: Session, review_id: int) -> InspectionCertificateReviewSession | None:
    return get_inspection_review_by_id(db, review_id)


def get_inspection_review_by_file_id(db: Session, import_file_id: int, include_inactive: bool = False) -> InspectionCertificateReviewSession | None:
    query = db.query(InspectionCertificateReviewSession).filter(InspectionCertificateReviewSession.import_file_id == import_file_id)
    if not include_inactive:
        query = query.filter(InspectionCertificateReviewSession.is_active == True)
    return query.order_by(InspectionCertificateReviewSession.inspection_review_id.desc()).first()


def create_inspection_review(
    db: Session, schema: InspectionCertificateReviewCreate, commit: bool = True
) -> InspectionCertificateReviewSession:
    code = generate_inspection_review_code(db)
    data = schema.model_dump(exclude_unset=True)
    data.pop("is_active", None)
    db_item = InspectionCertificateReviewSession(
        inspection_review_code=code,
        **data,
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def update_inspection_review(
    db: Session, review_id: int, schema: InspectionCertificateReviewUpdate, commit: bool = True
) -> InspectionCertificateReviewSession | None:
    item = get_inspection_review_active(db, review_id)
    if not item:
        return None
    _apply(item, schema.model_dump(exclude_unset=True))
    item.updated_at = _now()
    return _save(db, item, commit)


def delete_inspection_review(db: Session, review_id: int) -> bool:
    return _soft_delete(db, get_inspection_review_active(db, review_id))


# --- PO & PACKING FINAL RECONCILIATION SESSION REPOSITORY (BP-016) ---
def generate_po_reconciliation_session_code(db: Session) -> str:
    return next_yearly_code(db, POPackingReconciliationSession.session_code, "REC", pad=4)


def get_po_reconciliation_sessions(
    db: Session,
    include_inactive: bool = False,
    import_file_id: int | None = None,
    overall_status: str | None = None,
    search: str | None = None,
) -> list[POPackingReconciliationSession]:
    query = db.query(POPackingReconciliationSession)
    if not include_inactive:
        query = query.filter(POPackingReconciliationSession.is_active == True)
    if import_file_id:
        query = query.filter(POPackingReconciliationSession.import_file_id == import_file_id)
    if overall_status and overall_status != "All":
        query = query.filter(POPackingReconciliationSession.overall_status == overall_status)
    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            (POPackingReconciliationSession.session_code.ilike(s))
            | (POPackingReconciliationSession.final_invoice_number.ilike(s))
            | (POPackingReconciliationSession.final_packing_list_number.ilike(s))
            | (POPackingReconciliationSession.acid_number.ilike(s))
            | (POPackingReconciliationSession.shipper_name.ilike(s))
        )
    return query.order_by(POPackingReconciliationSession.session_id.desc()).all()


def get_po_reconciliation_session_by_id(
    db: Session, session_id: int, include_inactive: bool = False
) -> POPackingReconciliationSession | None:
    query = db.query(POPackingReconciliationSession).filter(
        POPackingReconciliationSession.session_id == session_id
    )
    if not include_inactive:
        query = query.filter(POPackingReconciliationSession.is_active == True)
    return query.first()


def get_po_reconciliation_session_active(db: Session, session_id: int) -> POPackingReconciliationSession | None:
    return get_po_reconciliation_session_by_id(db, session_id)


def get_po_reconciliation_session_by_file_id(
    db: Session, import_file_id: int, include_inactive: bool = False
) -> POPackingReconciliationSession | None:
    query = db.query(POPackingReconciliationSession).filter(
        POPackingReconciliationSession.import_file_id == import_file_id
    )
    if not include_inactive:
        query = query.filter(POPackingReconciliationSession.is_active == True)
    return query.order_by(POPackingReconciliationSession.session_id.desc()).first()


def get_inactive_po_reconciliation_by_file(
    db: Session, import_file_id: int
) -> POPackingReconciliationSession | None:
    """The soft-deleted session of a file (``import_file_id`` is unique on the table, so at most one row)."""
    return (
        db.query(POPackingReconciliationSession)
        .filter(
            POPackingReconciliationSession.import_file_id == import_file_id,
            POPackingReconciliationSession.is_active == False,
        )
        .order_by(POPackingReconciliationSession.session_id.desc())
        .first()
    )


def create_po_reconciliation_session(
    db: Session, schema: POReconciliationSessionCreate, commit: bool = True
) -> POPackingReconciliationSession:
    code = generate_po_reconciliation_session_code(db)
    data = schema.model_dump(exclude_unset=True)
    data.pop("is_active", None)
    db_item = POPackingReconciliationSession(
        session_code=code,
        **data,
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def reactivate_po_reconciliation_session(
    db: Session,
    item: POPackingReconciliationSession,
    schema: POReconciliationSessionCreate,
    commit: bool = True,
) -> POPackingReconciliationSession:
    """DOC-09 / Q5: overwrite a soft-deleted session of the same file with the new data (every schema field,
    defaults included, as a fresh create would store) and reactivate it. The session code is kept."""
    data = schema.model_dump()
    data.pop("is_active", None)
    _apply(item, data)
    item.is_active = True
    item.updated_at = _now()
    return _save(db, item, commit)


def update_po_reconciliation_session(
    db: Session, session_id: int, schema: POReconciliationSessionUpdate, commit: bool = True
) -> POPackingReconciliationSession | None:
    item = get_po_reconciliation_session_active(db, session_id)
    if not item:
        return None
    _apply(item, schema.model_dump(exclude_unset=True))
    item.updated_at = _now()
    return _save(db, item, commit)


def delete_po_reconciliation_session(db: Session, session_id: int) -> bool:
    return _soft_delete(db, get_po_reconciliation_session_active(db, session_id))


# --- SMART INVOICE VS B/L MATCH SESSIONS REPOSITORY (STEP_08_MATCH) ---
def generate_invoice_bl_match_session_code(db: Session) -> str:
    return next_yearly_code(db, InvoiceBLMatchSession.session_code, "MATCH", pad=4)


def get_invoice_bl_match_session_by_id(
    db: Session, session_id: int
) -> InvoiceBLMatchSession | None:
    return _active_by_id(db, InvoiceBLMatchSession, InvoiceBLMatchSession.session_id, session_id)


get_invoice_bl_match_session_active = get_invoice_bl_match_session_by_id


def get_invoice_bl_match_session_by_file_id(
    db: Session, import_file_id: int, include_drafts: bool = True
) -> InvoiceBLMatchSession | None:
    query = db.query(InvoiceBLMatchSession).filter(
        InvoiceBLMatchSession.import_file_id == import_file_id,
        InvoiceBLMatchSession.is_active == True,
    )
    if not include_drafts:
        query = query.filter(InvoiceBLMatchSession.is_draft == False)
    return query.order_by(InvoiceBLMatchSession.session_id.desc()).first()


def list_invoice_bl_match_sessions(
    db: Session,
    import_file_id: int | None = None,
    is_draft: bool | None = None,
    search: str | None = None,
) -> list[InvoiceBLMatchSession]:
    query = db.query(InvoiceBLMatchSession).filter(InvoiceBLMatchSession.is_active == True)
    if import_file_id is not None:
        query = query.filter(InvoiceBLMatchSession.import_file_id == import_file_id)
    if is_draft is not None:
        query = query.filter(InvoiceBLMatchSession.is_draft == is_draft)
    if search:
        s = f"%{search}%"
        query = query.filter(
            or_(
                InvoiceBLMatchSession.session_code.ilike(s),
                InvoiceBLMatchSession.invoice_number.ilike(s),
                InvoiceBLMatchSession.bl_number.ilike(s),
                InvoiceBLMatchSession.packing_list_number.ilike(s),
                InvoiceBLMatchSession.import_file_code.ilike(s),
            )
        )
    return query.order_by(InvoiceBLMatchSession.session_id.desc()).all()


def create_invoice_bl_match_session(
    db: Session, schema: InvoiceBLMatchSessionCreate, commit: bool = True
) -> InvoiceBLMatchSession:
    code = generate_invoice_bl_match_session_code(db)
    data = schema.model_dump(exclude_unset=True)
    data.pop("is_active", None)
    db_item = InvoiceBLMatchSession(
        session_code=code,
        **data,
        is_active=True,
    )
    db.add(db_item)
    return _save(db, db_item, commit)


def update_invoice_bl_match_session(
    db: Session, session_id: int, schema: InvoiceBLMatchSessionUpdate, commit: bool = True
) -> InvoiceBLMatchSession | None:
    item = get_invoice_bl_match_session_active(db, session_id)
    if not item:
        return None
    _apply(item, schema.model_dump(exclude_unset=True))
    item.updated_at = _now()
    return _save(db, item, commit)


def delete_invoice_bl_match_session(db: Session, session_id: int) -> bool:
    return _soft_delete(db, get_invoice_bl_match_session_active(db, session_id))


# --- PURCHASE ORDER LOOKUP FOR PO / PACKING RECONCILIATION (BP-016) ---
def get_active_purchase_orders_for_file(
    db: Session, import_file_id: int, po_number: Optional[str]
) -> List[PurchaseOrder]:
    """
    Active purchase orders backing an import file: every active PO linked through import_file_id,
    otherwise every active PO whose po_number equals the file's PO number. Returns [] when none is found.
    """
    pos = db.query(PurchaseOrder).filter(
        PurchaseOrder.import_file_id == import_file_id,
        PurchaseOrder.is_active == True,
    ).all()
    if not pos and po_number:
        pos = db.query(PurchaseOrder).filter(
            PurchaseOrder.po_number == po_number,
            PurchaseOrder.is_active == True,
        ).all()
    return pos
