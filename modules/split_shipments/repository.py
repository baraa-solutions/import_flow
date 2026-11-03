"""
Repository for Split Shipments & Multi-PO Allocations
"""

from typing import List, Optional, Tuple
from sqlalchemy import func
from sqlalchemy.orm import Session
from modules.split_shipments.model import SplitShipmentAllocation


class SplitShipmentRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, allocation_id: int) -> Optional[SplitShipmentAllocation]:
        return (
            self.db.query(SplitShipmentAllocation)
            .filter(
                SplitShipmentAllocation.id == allocation_id,
                SplitShipmentAllocation.is_deleted.is_(False),
            )
            .first()
        )

    def list_by_shipment(
        self,
        shipment_id: int,
        split_bl_number: Optional[str] = None,
        parent_bl_number: Optional[str] = None,
        po_id: Optional[int] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[SplitShipmentAllocation], int]:
        query = self.db.query(SplitShipmentAllocation).filter(
            SplitShipmentAllocation.shipment_id == shipment_id,
            SplitShipmentAllocation.is_deleted.is_(False),
        )

        if split_bl_number:
            query = query.filter(SplitShipmentAllocation.split_bl_number == split_bl_number)
        if parent_bl_number:
            query = query.filter(SplitShipmentAllocation.parent_bl_number == parent_bl_number)
        if po_id:
            query = query.filter(SplitShipmentAllocation.po_id == po_id)

        total = query.count()
        items = (
            query.order_by(SplitShipmentAllocation.split_bl_number.asc(), SplitShipmentAllocation.id.asc())
            .offset(skip)
            .limit(limit)
            .all()
        )
        return items, total

    def get_existing_allocations_for_item(
        self,
        shipment_id: int,
        po_item_id: Optional[int],
        item_sku: str,
        exclude_id: Optional[int] = None,
    ) -> List[SplitShipmentAllocation]:
        query = self.db.query(SplitShipmentAllocation).filter(
            SplitShipmentAllocation.shipment_id == shipment_id,
            SplitShipmentAllocation.item_sku == item_sku,
            SplitShipmentAllocation.is_deleted.is_(False),
        )
        if po_item_id is not None:
            query = query.filter(SplitShipmentAllocation.po_item_id == po_item_id)
        if exclude_id is not None:
            query = query.filter(SplitShipmentAllocation.id != exclude_id)
        return query.all()

    def get_unique_split_bls(self, shipment_id: int) -> List[str]:
        rows = (
            self.db.query(SplitShipmentAllocation.split_bl_number)
            .filter(
                SplitShipmentAllocation.shipment_id == shipment_id,
                SplitShipmentAllocation.is_deleted.is_(False),
            )
            .distinct()
            .all()
        )
        return [r[0] for r in rows]

    def create(self, allocation: SplitShipmentAllocation) -> SplitShipmentAllocation:
        self.db.add(allocation)
        self.db.flush()
        return allocation

    def save(self, allocation: SplitShipmentAllocation) -> SplitShipmentAllocation:
        self.db.flush()
        self.db.refresh(allocation)
        return allocation
