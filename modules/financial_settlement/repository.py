from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy import desc, or_

from modules.common.sequence_generator import next_yearly_code
from .model import LandedCostSettlementRecord, TaxRate

# Queries only. Nothing here commits: the service owns the transaction (FS-13).

_CODE_ATTEMPTS = 5


def generate_settlement_code(db: Session) -> str:
    """Next Landed Cost Settlement Code ``LCS-YYYY-NNNN`` (highest numeric suffix of the year + 1)."""
    return next_yearly_code(db, LandedCostSettlementRecord.settlement_code, "LCS", pad=4)


def add_with_new_code(db: Session, record: LandedCostSettlementRecord) -> LandedCostSettlementRecord:
    """Assign the next settlement code and flush; a code taken concurrently (unique constraint) is retried
    inside a savepoint so the caller's transaction survives."""
    for attempt in range(_CODE_ATTEMPTS):
        record.settlement_code = generate_settlement_code(db)
        try:
            with db.begin_nested():
                db.add(record)
                db.flush()
            return record
        except IntegrityError:
            if attempt == _CODE_ATTEMPTS - 1:
                raise
    return record


def get_settlement_by_id(db: Session, settlement_id: int, include_inactive: bool = False) -> Optional[LandedCostSettlementRecord]:
    query = db.query(LandedCostSettlementRecord).filter(LandedCostSettlementRecord.settlement_id == settlement_id)
    if not include_inactive:
        query = query.filter(LandedCostSettlementRecord.is_active == True)
    return query.first()

def get_settlement_by_import_file_id(db: Session, import_file_id: int) -> Optional[LandedCostSettlementRecord]:
    return db.query(LandedCostSettlementRecord).filter(
        LandedCostSettlementRecord.import_file_id == import_file_id,
        LandedCostSettlementRecord.is_active == True
    ).first()

def list_settlements(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> List[LandedCostSettlementRecord]:
    query = db.query(LandedCostSettlementRecord)
    if not include_inactive:
        query = query.filter(LandedCostSettlementRecord.is_active == True)
    if import_file_id:
        query = query.filter(LandedCostSettlementRecord.import_file_id == import_file_id)
    if status:
        query = query.filter(LandedCostSettlementRecord.status == status)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (LandedCostSettlementRecord.settlement_code.ilike(pattern)) |
            (LandedCostSettlementRecord.accountant_name.ilike(pattern))
        )
    query = query.order_by(desc(LandedCostSettlementRecord.settlement_id))
    if skip:
        query = query.offset(skip)
    if limit is not None:
        query = query.limit(limit)
    return query.all()


def _with_amount_egp(expenses: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Stored rows carry EGP cents: the header totals are sums of these rounded rows, so the Odoo journal built
    from the same rows balances within its 0.01 tolerance (review 2 #9)."""
    for e in expenses:
        if not e.get("amount_egp") or e.get("amount_egp") == 0:
            e["amount_egp"] = (e.get("amount_fx") or 0.0) * (e.get("exchange_rate") or 1.0)
        e["amount_egp"] = round(float(e["amount_egp"]), 2)
    return expenses


def build_settlement(
    import_file_id: int,
    expense_invoices: List[Any],
    item_landed_costs: List[Any],
    accountant_name: str,
    notes: Optional[str],
    actor: str,
) -> LandedCostSettlementRecord:
    expenses = _with_amount_egp([e.model_dump() if hasattr(e, "model_dump") else dict(e) for e in expense_invoices])
    items = [i.model_dump() if hasattr(i, "model_dump") else dict(i) for i in item_landed_costs]
    now = datetime.now(timezone.utc)
    return LandedCostSettlementRecord(
        import_file_id=import_file_id,
        expense_invoices=expenses,
        item_landed_costs=items,
        accountant_name=accountant_name,
        notes=notes,
        created_at=now,
        created_by=actor,
        updated_at=now,
        updated_by=actor,
    )


def apply_settlement_update(db: Session, db_obj: LandedCostSettlementRecord, update_data: Dict[str, Any], actor: str) -> LandedCostSettlementRecord:
    """Copy validated update fields onto the record (no commit)."""
    data = dict(update_data)
    if data.get("expense_invoices") is not None:
        db_obj.expense_invoices = _with_amount_egp([dict(e) for e in data.pop("expense_invoices")])
    data.pop("expense_invoices", None)
    if data.get("item_landed_costs") is not None:
        db_obj.item_landed_costs = [dict(i) for i in data.pop("item_landed_costs")]
    data.pop("item_landed_costs", None)
    for key, value in data.items():
        setattr(db_obj, key, value)
    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = actor
    db.flush()
    return db_obj


def soft_delete_settlement(db: Session, db_obj: LandedCostSettlementRecord, actor: str) -> None:
    db_obj.is_active = False
    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = actor
    db.flush()


def restore_settlement(db: Session, db_obj: LandedCostSettlementRecord, actor: str) -> None:
    db_obj.is_active = True
    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = actor
    db.flush()


def get_effective_tax_rate(db: Session, tax_code: str, on_date: date) -> Optional[TaxRate]:
    """The active, non-deleted rate of ``tax_code`` valid on ``on_date`` (latest effective_from wins)."""
    return (
        db.query(TaxRate)
        .filter(
            TaxRate.tax_code == tax_code,
            TaxRate.is_active == True,
            TaxRate.deleted_at == None,
            TaxRate.effective_from <= on_date,
            or_(TaxRate.effective_to == None, TaxRate.effective_to >= on_date),
        )
        .order_by(TaxRate.effective_from.desc())
        .first()
    )
