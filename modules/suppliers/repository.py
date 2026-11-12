from typing import Any, Dict, List, Optional
from fastapi import Response
from sqlalchemy import exists, func, or_
from sqlalchemy.orm import Session

from modules.common.pagination import PageParams, like_term, paginate
from .model import Supplier
from .schemas import SupplierCreate, SupplierUpdate

SUPPLIER_SORT_MAP = {
    "supplier_id": Supplier.supplier_id,
    "supplier_code": Supplier.supplier_code,
    "company_name": Supplier.company_name,
    "supplier_type": Supplier.supplier_type,
    "foreign_exporter_country": Supplier.foreign_exporter_country,
    "foreign_exporter_id": Supplier.foreign_exporter_id,
    "created_at": Supplier.created_at,
    "updated_at": Supplier.updated_at,
}


def get_paginated_suppliers(
    db: Session,
    params: PageParams,
    response: Optional[Response] = None,
    supplier_type: Optional[str] = None,
    country: Optional[str] = None,
) -> Dict[str, Any]:
    query = db.query(Supplier)
    if not params.include_inactive:
        query = query.filter(Supplier.is_active.is_(True))
    if supplier_type:
        query = query.filter(Supplier.supplier_type == supplier_type)
    if country:
        query = query.filter(Supplier.foreign_exporter_country.ilike(f"%{country}%"))

    term = like_term(params.q)
    if term:
        query = query.filter(
            or_(
                Supplier.company_name.ilike(term, escape="\\"),
                Supplier.supplier_code.ilike(term, escape="\\"),
                Supplier.foreign_exporter_id.ilike(term, escape="\\"),
                Supplier.foreign_exporter_country.ilike(term, escape="\\"),
            )
        )
    return paginate(
        query,
        params,
        sort_map=SUPPLIER_SORT_MAP,
        default_sort=[Supplier.company_name.asc()],
        pk=Supplier.supplier_id,
        response=response,
    )



# ==================================================
# Create Supplier
# ==================================================

def create_supplier(db: Session, supplier_data: dict) -> Supplier:
    supplier = Supplier(**supplier_data)
    db.add(supplier)
    db.commit()
    db.refresh(supplier)

    return supplier


# ==================================================
# Get Active Suppliers
# ==================================================

def get_active_suppliers(db: Session) -> list[Supplier]:
    return (
        db.query(Supplier)
        .filter(Supplier.is_active == True)
        .order_by(Supplier.supplier_id)
        .all()
    )


# ==================================================
# Get All Suppliers (Admin)
# ==================================================

def get_all_suppliers_admin(db: Session) -> list[Supplier]:
    return (
        db.query(Supplier)
        .order_by(Supplier.supplier_id)
        .all()
    )


# ==================================================
# Get Supplier By ID
# ==================================================

def get_supplier_by_id(db: Session, supplier_id: int) -> Supplier | None:
    return (
        db.query(Supplier)
        .filter(Supplier.supplier_id == supplier_id)
        .first()
    )


# ==================================================
# Get Supplier By Exporter ID
# ==================================================

def get_supplier_by_exporter_id(db: Session, foreign_exporter_id: str) -> Supplier | None:
    return (
        db.query(Supplier)
        .filter(Supplier.foreign_exporter_id == foreign_exporter_id)
        .first()
    )


# ==================================================
# Check Foreign Exporter ID Exists (Optimized SQL)
# ==================================================

def foreign_exporter_id_exists(db: Session, foreign_exporter_id: str) -> bool:
    return db.query(
        exists().where(Supplier.foreign_exporter_id == foreign_exporter_id)
    ).scalar()


# ==================================================
# Count Total Suppliers for Code Generation
# ==================================================

def count_suppliers(db: Session) -> int:
    return db.query(func.count(Supplier.supplier_id)).scalar() or 0


# ==================================================
# Update Supplier Data
# ==================================================

def update_supplier(db: Session, supplier: Supplier, supplier_data: SupplierUpdate) -> Supplier:
    update_data = supplier_data.to_update_dict()
    old_data = {
        k: getattr(supplier, k, None)
        for k in update_data.keys()
    }

    for field, value in update_data.items():
        if field == "email" and value is not None:
            value = str(value)
        setattr(supplier, field, value)

    try:
        db.commit()
        db.refresh(supplier)
    except Exception:
        db.rollback()
        raise

    return supplier


# ==================================================
# Soft Delete Supplier
# ==================================================

def soft_delete_supplier(db: Session, supplier: Supplier) -> Supplier:
    supplier.is_active = False
    db.commit()
    db.refresh(supplier)

    return supplier


# ==================================================
# Restore Supplier
# ==================================================

def restore_supplier(db: Session, supplier: Supplier) -> Supplier:
    supplier.is_active = True
    db.commit()
    db.refresh(supplier)

    return supplier

# ==================================================
# Sub-Ledger & Credit Overrides (Trello GzFff0Pc)
# ==================================================

def list_supplier_ledger_entries(db: Session, supplier_id: int, include_inactive: bool = False) -> List[Any]:
    from .model import SupplierLedgerEntry

    query = db.query(SupplierLedgerEntry).filter(SupplierLedgerEntry.supplier_id == supplier_id)
    if not include_inactive:
        query = query.filter(SupplierLedgerEntry.is_active == True)  # noqa: E712
    return query.order_by(SupplierLedgerEntry.entry_date.asc(), SupplierLedgerEntry.entry_id.asc()).all()


def list_supplier_credit_overrides(db: Session, supplier_id: int) -> List[Any]:
    from .model import SupplierCreditOverride

    return (
        db.query(SupplierCreditOverride)
        .filter(SupplierCreditOverride.supplier_id == supplier_id, SupplierCreditOverride.is_active == True)  # noqa: E712
        .order_by(SupplierCreditOverride.created_at.desc(), SupplierCreditOverride.override_id.desc())
        .all()
    )


def list_suppliers_with_activity(db: Session) -> List[Supplier]:
    """Active suppliers that have at least one import file or payment request (candidates for the aging report)."""
    from modules.financial_approval.model import PaymentRequestSession
    from modules.import_files.model import ImportFile

    has_file = exists().where(ImportFile.supplier_id == Supplier.supplier_id)
    has_payment = exists().where(PaymentRequestSession.supplier_id == Supplier.supplier_id)
    return (
        db.query(Supplier)
        .filter(Supplier.is_active == True, or_(has_file, has_payment))  # noqa: E712
        .order_by(Supplier.company_name.asc())
        .all()
    )
