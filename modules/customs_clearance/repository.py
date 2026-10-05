"""
Customs clearance queries. Writes only add / flush: the service owns the single commit per request.
"""
from typing import List, Optional

from sqlalchemy import desc
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code
from .model import ClearanceExpenseInvoice, CustomsClearanceRecord


def generate_customs_clearance_code(db: Session) -> str:
    """Next ``CLR-YYYY-NNNN`` code (highest numeric suffix of the year + 1; the unique column is the final guard)."""
    return next_yearly_code(db, CustomsClearanceRecord.clearance_code, "CLR", pad=4)


def generate_clearance_invoice_code(db: Session) -> str:
    """Next ``CLI-YYYY-NNNN`` code, restarting every year."""
    return next_yearly_code(db, ClearanceExpenseInvoice.invoice_code, "CLI", pad=4)


def get_customs_clearance_by_id(db: Session, record_id: int, include_inactive: bool = False) -> Optional[CustomsClearanceRecord]:
    query = db.query(CustomsClearanceRecord).filter(CustomsClearanceRecord.customs_clearance_id == record_id)
    if not include_inactive:
        query = query.filter(CustomsClearanceRecord.is_active == True)  # noqa: E712
    return query.first()


def get_active_clearance_for_file(
    db: Session, import_file_id: int, exclude_record_id: Optional[int] = None
) -> Optional[CustomsClearanceRecord]:
    query = db.query(CustomsClearanceRecord).filter(
        CustomsClearanceRecord.import_file_id == import_file_id,
        CustomsClearanceRecord.is_active == True,  # noqa: E712
    )
    if exclude_record_id is not None:
        query = query.filter(CustomsClearanceRecord.customs_clearance_id != exclude_record_id)
    return query.order_by(CustomsClearanceRecord.customs_clearance_id).first()


def get_latest_clearance_for_file(db: Session, import_file_id: int) -> Optional[CustomsClearanceRecord]:
    return (
        db.query(CustomsClearanceRecord)
        .filter(CustomsClearanceRecord.import_file_id == import_file_id)
        .order_by(CustomsClearanceRecord.customs_clearance_id.desc())
        .first()
    )


def get_customs_clearance_list(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[CustomsClearanceRecord]:
    query = db.query(CustomsClearanceRecord)
    if not include_inactive:
        query = query.filter(CustomsClearanceRecord.is_active == True)  # noqa: E712
    if import_file_id:
        query = query.filter(CustomsClearanceRecord.import_file_id == import_file_id)
    if status:
        query = query.filter(CustomsClearanceRecord.status == status)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (CustomsClearanceRecord.clearance_code.ilike(pattern)) |
            (CustomsClearanceRecord.declaration_46_no.ilike(pattern)) |
            (CustomsClearanceRecord.release_permit_no.ilike(pattern)) |
            (CustomsClearanceRecord.delivery_order_number.ilike(pattern)) |
            (CustomsClearanceRecord.owner.ilike(pattern))
        )
    return query.order_by(desc(CustomsClearanceRecord.customs_clearance_id)).all()


def add(db: Session, obj) -> None:
    db.add(obj)
    db.flush()


def get_invoice_by_id(db: Session, invoice_id: int, include_inactive: bool = False) -> Optional[ClearanceExpenseInvoice]:
    query = db.query(ClearanceExpenseInvoice).filter(ClearanceExpenseInvoice.invoice_id == invoice_id)
    if not include_inactive:
        query = query.filter(ClearanceExpenseInvoice.is_active == True)  # noqa: E712
    return query.first()


def get_active_invoices_for_file(db: Session, import_file_id: int, newest_first: bool = False) -> List[ClearanceExpenseInvoice]:
    query = db.query(ClearanceExpenseInvoice).filter(
        ClearanceExpenseInvoice.import_file_id == import_file_id,
        ClearanceExpenseInvoice.is_active == True,  # noqa: E712
    )
    order = ClearanceExpenseInvoice.invoice_id.desc() if newest_first else ClearanceExpenseInvoice.invoice_id
    return query.order_by(order).all()
