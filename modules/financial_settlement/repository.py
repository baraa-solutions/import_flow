from datetime import date, datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc, or_

from .model import LandedCostSettlementRecord, TaxRate
from .schemas import FinancialSettlementCreate, FinancialSettlementUpdate

def generate_settlement_code(db: Session) -> str:
    """Generates unique Landed Cost Settlement Code in format LCS-YYYY-XXXX."""
    current_year = datetime.now(timezone.utc).year
    prefix = f"LCS-{current_year}-"
    
    last_record = (
        db.query(LandedCostSettlementRecord)
        .filter(LandedCostSettlementRecord.settlement_code.like(f"{prefix}%"))
        .order_by(desc(LandedCostSettlementRecord.settlement_id))
        .first()
    )
    
    if last_record:
        try:
            last_seq = int(last_record.settlement_code.split("-")[-1])
            new_seq = last_seq + 1
        except ValueError:
            new_seq = 1
    else:
        new_seq = 1
        
    return f"{prefix}{new_seq:04d}"

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
    return query.order_by(desc(LandedCostSettlementRecord.settlement_id)).all()

def create_settlement(db: Session, schema: FinancialSettlementCreate, code: str) -> LandedCostSettlementRecord:
    expenses = [e.model_dump() if hasattr(e, "model_dump") else e for e in schema.expense_invoices]
    for e in expenses:
        if not e.get("amount_egp") or e.get("amount_egp") == 0:
            e["amount_egp"] = e.get("amount_fx", 0.0) * e.get("exchange_rate", 1.0)

    items = [i.model_dump() if hasattr(i, "model_dump") else i for i in schema.item_landed_costs]

    db_obj = LandedCostSettlementRecord(
        settlement_code=code,
        import_file_id=schema.import_file_id,
        expense_invoices=expenses,
        item_landed_costs=items,
        accountant_name=schema.accountant_name,
        notes=schema.notes,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj

def update_settlement(db: Session, settlement_id: int, schema: FinancialSettlementUpdate) -> Optional[LandedCostSettlementRecord]:
    db_obj = get_settlement_by_id(db, settlement_id, include_inactive=True)
    if not db_obj:
        return None

    update_data = schema.model_dump(exclude_unset=True)
    if "expense_invoices" in update_data and update_data["expense_invoices"] is not None:
        expenses = [e.model_dump() if hasattr(e, 'model_dump') else e for e in schema.expense_invoices]
        for e in expenses:
            if not e.get("amount_egp") or e.get("amount_egp") == 0:
                e["amount_egp"] = e.get("amount_fx", 0.0) * e.get("exchange_rate", 1.0)
        db_obj.expense_invoices = expenses
        del update_data["expense_invoices"]

    if "item_landed_costs" in update_data and update_data["item_landed_costs"] is not None:
        items = [i.model_dump() if hasattr(i, 'model_dump') else i for i in schema.item_landed_costs]
        db_obj.item_landed_costs = items
        del update_data["item_landed_costs"]

    for key, value in update_data.items():
        setattr(db_obj, key, value)

    db_obj.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(db_obj)
    return db_obj

def soft_delete_settlement(db: Session, settlement_id: int) -> bool:
    db_obj = get_settlement_by_id(db, settlement_id, include_inactive=False)
    if not db_obj:
        return False
    db_obj.is_active = False
    db_obj.updated_at = datetime.now(timezone.utc)
    db.commit()
    return True

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

def restore_settlement(db: Session, settlement_id: int) -> Optional[LandedCostSettlementRecord]:
    db_obj = get_settlement_by_id(db, settlement_id, include_inactive=True)
    if not db_obj:
        return None
    db_obj.is_active = True
    db_obj.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(db_obj)
    return db_obj
