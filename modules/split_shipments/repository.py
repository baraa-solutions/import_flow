"""
Repository for Split Shipments & Multi-PO Allocations
"""

from typing import Dict, List, Optional, Tuple
from sqlalchemy import func, or_
from sqlalchemy.orm import Session
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import POLineItem, POShipmentAllocation, PurchaseOrder
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

    def get_import_file(self, shipment_id: int) -> Optional[ImportFile]:
        return (
            self.db.query(ImportFile)
            .filter(ImportFile.import_file_id == shipment_id)
            .first()
        )

    def list_po_lines_for_shipment(
        self, shipment_id: int, linked_po_ids: List[int]
    ) -> List[Tuple[POLineItem, PurchaseOrder]]:
        """PO lines of active POs linked to the import file (direct FK, the file's
        po_ids list, or a PO shipment allocation on that file)."""
        allocated_po_ids = self.db.query(POShipmentAllocation.po_id).filter(
            POShipmentAllocation.import_file_id == shipment_id
        )
        link_filters = [
            PurchaseOrder.import_file_id == shipment_id,
            PurchaseOrder.po_id.in_(allocated_po_ids),
        ]
        if linked_po_ids:
            link_filters.append(PurchaseOrder.po_id.in_(linked_po_ids))
        return (
            self.db.query(POLineItem, PurchaseOrder)
            .join(PurchaseOrder, POLineItem.po_id == PurchaseOrder.po_id)
            .filter(PurchaseOrder.is_active.is_(True), or_(*link_filters))
            .order_by(PurchaseOrder.po_number.asc(), POLineItem.item_id.asc())
            .all()
        )

    def get_allocated_quantity_by_po_item(self, shipment_id: int) -> Dict[int, float]:
        rows = (
            self.db.query(
                SplitShipmentAllocation.po_item_id,
                func.sum(SplitShipmentAllocation.allocated_quantity),
            )
            .filter(
                SplitShipmentAllocation.shipment_id == shipment_id,
                SplitShipmentAllocation.po_item_id.isnot(None),
                SplitShipmentAllocation.is_deleted.is_(False),
            )
            .group_by(SplitShipmentAllocation.po_item_id)
            .all()
        )
        return {po_item_id: float(total or 0.0) for po_item_id, total in rows}

    def create(self, allocation: SplitShipmentAllocation) -> SplitShipmentAllocation:
        self.db.add(allocation)
        self.db.flush()
        return allocation

    def save(self, allocation: SplitShipmentAllocation) -> SplitShipmentAllocation:
        self.db.flush()
        self.db.refresh(allocation)
        return allocation
