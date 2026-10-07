from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy import desc
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code

from .model import ImportFileClosureRecord


def generate_closure_code(db: Session) -> str:
    """Next closure certificate code CLR-YYYY-NNNN (highest numeric suffix of the year + 1). Read-only: the precheck
    preview and the close use the same value."""
    return next_yearly_code(db, ImportFileClosureRecord.closure_code, "CLR", pad=4)


def get_closure_by_id(db: Session, closure_id: int, include_inactive: bool = False) -> Optional[ImportFileClosureRecord]:
    query = db.query(ImportFileClosureRecord).filter(ImportFileClosureRecord.closure_id == closure_id)
    if not include_inactive:
        query = query.filter(ImportFileClosureRecord.is_active == True)
    return query.first()


def get_closure_by_import_file_id(
    db: Session, import_file_id: int, exclude_id: Optional[int] = None
) -> Optional[ImportFileClosureRecord]:
    query = db.query(ImportFileClosureRecord).filter(
        ImportFileClosureRecord.import_file_id == import_file_id,
        ImportFileClosureRecord.is_active == True,
    )
    if exclude_id is not None:
        query = query.filter(ImportFileClosureRecord.closure_id != exclude_id)
    return query.order_by(desc(ImportFileClosureRecord.closure_id)).first()


def list_closures(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    search: Optional[str] = None,
) -> List[ImportFileClosureRecord]:
    query = db.query(ImportFileClosureRecord)
    if not include_inactive:
        query = query.filter(ImportFileClosureRecord.is_active == True)
    if import_file_id:
        query = query.filter(ImportFileClosureRecord.import_file_id == import_file_id)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (ImportFileClosureRecord.closure_code.ilike(pattern)) |
            (ImportFileClosureRecord.auditor_name.ilike(pattern))
        )
    return query.order_by(desc(ImportFileClosureRecord.closure_id)).all()


def add_closure(db: Session, values: Dict[str, Any]) -> ImportFileClosureRecord:
    """Insert + flush (the service commits once). ``values`` carries the final status (BE810-F30)."""
    now = datetime.now(timezone.utc)
    status = values.get("status")
    closed_at = values.get("closed_at")
    if closed_at is None and status == "Closed":
        closed_at = now
    elif status != "Closed":
        closed_at = None
    db_obj = ImportFileClosureRecord(created_at=now, updated_at=now, closed_at=closed_at, **values)
    db.add(db_obj)
    db.flush()
    return db_obj


def apply_changes(db_obj: ImportFileClosureRecord, values: Dict[str, Any], user: str) -> ImportFileClosureRecord:
    """Set already-validated fields (no commit)."""
    for key, value in values.items():
        setattr(db_obj, key, value)
    db_obj.updated_at = datetime.now(timezone.utc)
    db_obj.updated_by = user
    return db_obj


# ── Closure gate facts (read-only queries over the other phases) ───────────────────────────────────────────────

def has_final_release_clearance(db: Session, import_file_id: int) -> bool:
    from modules.customs_clearance.model import CustomsClearanceRecord
    return db.query(CustomsClearanceRecord.customs_clearance_id).filter(
        CustomsClearanceRecord.import_file_id == import_file_id,
        CustomsClearanceRecord.is_active == True,
        (CustomsClearanceRecord.status == "Final Release Granted")
        | (CustomsClearanceRecord.release_permit_no.isnot(None) & (CustomsClearanceRecord.release_permit_no != "")),
    ).first() is not None


def latest_active_clearance(db: Session, import_file_id: int):
    from modules.customs_clearance.model import CustomsClearanceRecord
    return (
        db.query(CustomsClearanceRecord)
        .filter(CustomsClearanceRecord.import_file_id == import_file_id, CustomsClearanceRecord.is_active == True)
        .order_by(CustomsClearanceRecord.customs_clearance_id.desc())
        .first()
    )


def active_grns(db: Session, import_file_id: int) -> list:
    from modules.warehouse_receiving.model import WarehouseReceivingRecord
    return (
        db.query(WarehouseReceivingRecord)
        .filter(WarehouseReceivingRecord.import_file_id == import_file_id, WarehouseReceivingRecord.is_active == True)
        .order_by(WarehouseReceivingRecord.receiving_id.desc())
        .all()
    )


def latest_active_settlement(db: Session, import_file_id: int, statuses: Optional[tuple] = None):
    from modules.financial_settlement.model import LandedCostSettlementRecord
    query = db.query(LandedCostSettlementRecord).filter(
        LandedCostSettlementRecord.import_file_id == import_file_id,
        LandedCostSettlementRecord.is_active == True,
    )
    if statuses:
        query = query.filter(LandedCostSettlementRecord.status.in_(statuses))
    return query.order_by(LandedCostSettlementRecord.settlement_id.desc()).first()


def latest_active_inland_booking(db: Session, import_file_id: int):
    from modules.inland_transport.model import InlandTransportBooking
    return (
        db.query(InlandTransportBooking)
        .filter(InlandTransportBooking.import_file_id == import_file_id, InlandTransportBooking.is_active == True)
        .order_by(InlandTransportBooking.transport_id.desc())
        .first()
    )


def active_purchase_orders(db: Session, import_file_id: int) -> list:
    from sqlalchemy.orm import selectinload
    from modules.purchase_orders.model import PurchaseOrder, POLineItem

    return (
        db.query(PurchaseOrder)
        .options(
            selectinload(PurchaseOrder.currency),
            selectinload(PurchaseOrder.line_items).selectinload(POLineItem.tariff),
        )
        .filter(
            PurchaseOrder.import_file_id == import_file_id,
            PurchaseOrder.is_active == True,
        )
        .all()
    )


def open_tasks(db: Session, import_file_id: int, statuses: tuple) -> list:
    from modules.smart_tasks.model import SmartTask
    return db.query(SmartTask).filter(
        SmartTask.import_file_id == import_file_id,
        SmartTask.is_active == True,
        SmartTask.status.in_(statuses),
    ).all()


def customs_rate_to_egp(db: Session, currency_code: Optional[str], on_date: date) -> Optional[float]:
    """Customs exchange rate (EGP per unit) from the rate table valid on ``on_date``; None when the currency or a
    rate row is missing. Never a built-in fallback number (DOMAIN_RULES: no hard-coded rates)."""
    from modules.currencies.repository import CurrencyRepository

    code = (currency_code or "").strip().upper()
    if not code:
        return None
    if code == "EGP":
        return 1.0
    repo = CurrencyRepository(db)
    currency = repo.get_currency_by_code(code)
    if currency is None:
        return None
    rate = repo.get_latest_rate(currency.currency_id, target_date=on_date)
    if rate is None or not rate.customs_rate or float(rate.customs_rate) <= 0:
        return None
    return float(rate.customs_rate)
