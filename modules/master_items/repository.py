"""
Master Items Repository (MD-ITEM-001)
Database operations and queries for Master Items, Supplier Catalogs, and Price History.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy import or_, desc
from sqlalchemy.orm import Session

from modules.master_items.model import (
    MasterItem,
    ItemSupplierCatalog,
    ItemPriceHistory,
)


class MasterItemRepository:

    @staticmethod
    def get_by_id(db: Session, item_id: int) -> Optional[MasterItem]:
        return db.query(MasterItem).filter(
            MasterItem.item_id == item_id,
            MasterItem.is_active == True,
        ).first()

    @staticmethod
    def get_by_code(db: Session, item_code: str) -> Optional[MasterItem]:
        return db.query(MasterItem).filter(
            MasterItem.item_code == item_code.strip(),
            MasterItem.is_active == True,
        ).first()

    @staticmethod
    def list_items(
        db: Session,
        search: Optional[str] = None,
        category: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[MasterItem], int]:
        query = db.query(MasterItem).filter(MasterItem.is_active == True)

        if category:
            query = query.filter(MasterItem.product_category == category)

        if search:
            term = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    MasterItem.item_code.ilike(term),
                    MasterItem.description_ar.ilike(term),
                    MasterItem.description_en.ilike(term),
                )
            )

        total = query.count()
        items = query.order_by(MasterItem.item_code.asc()).offset(skip).limit(limit).all()
        return items, total

    @staticmethod
    def create(db: Session, item: MasterItem) -> MasterItem:
        db.add(item)
        db.flush()
        return item

    @staticmethod
    def update(db: Session, item: MasterItem) -> MasterItem:
        db.flush()
        return item

    @staticmethod
    def soft_delete(db: Session, item: MasterItem, deleted_by: Optional[str] = None) -> MasterItem:
        item.is_active = False
        item.deleted_at = datetime.now(timezone.utc)
        item.deleted_by = deleted_by
        db.flush()
        return item


class ItemSupplierCatalogRepository:

    @staticmethod
    def get_by_id(db: Session, catalog_id: int) -> Optional[ItemSupplierCatalog]:
        return db.query(ItemSupplierCatalog).filter(
            ItemSupplierCatalog.catalog_id == catalog_id,
            ItemSupplierCatalog.is_active == True,
        ).first()

    @staticmethod
    def list_by_item(db: Session, item_id: int) -> List[ItemSupplierCatalog]:
        return db.query(ItemSupplierCatalog).filter(
            ItemSupplierCatalog.item_id == item_id,
            ItemSupplierCatalog.is_active == True,
        ).order_by(
            ItemSupplierCatalog.is_preferred_supplier.desc(),
            ItemSupplierCatalog.last_confirmed_price.asc(),
        ).all()

    @staticmethod
    def create(db: Session, catalog: ItemSupplierCatalog) -> ItemSupplierCatalog:
        db.add(catalog)
        db.flush()
        return catalog

    @staticmethod
    def update(db: Session, catalog: ItemSupplierCatalog) -> ItemSupplierCatalog:
        db.flush()
        return catalog

    @staticmethod
    def delete(db: Session, catalog: ItemSupplierCatalog) -> None:
        catalog.is_active = False
        db.flush()


class ItemPriceHistoryRepository:

    @staticmethod
    def record(db: Session, record: ItemPriceHistory) -> ItemPriceHistory:
        db.add(record)
        db.flush()
        return record

    @staticmethod
    def list_by_item(db: Session, item_id: int, limit: int = 50) -> List[ItemPriceHistory]:
        return db.query(ItemPriceHistory).filter(
            ItemPriceHistory.item_id == item_id,
        ).order_by(desc(ItemPriceHistory.recorded_at)).limit(limit).all()
