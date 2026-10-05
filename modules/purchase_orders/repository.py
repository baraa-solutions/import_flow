from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Sequence, Set, Tuple, Type

from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload, selectinload

from modules.common.sequence_generator import next_yearly_code
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import POLineItem, POShipmentAllocation, PackingListItem, PurchaseOrder

PO_NUMBER_PREFIX = "PO"

# (existing row id or None, column values) for one child row of a PO.
ChildRow = Tuple[Optional[int], Dict[str, Any]]


class PurchaseOrderRepository:
    """Queries and persistence only. Methods flush; the service owns the single commit per operation."""

    def __init__(self, db: Session):
        self.db = db

    # ── reads ──

    def next_po_number(self) -> str:
        return next_yearly_code(self.db, PurchaseOrder.po_number, PO_NUMBER_PREFIX)

    def get_by_id(self, po_id: int, active_only: bool = False) -> Optional[PurchaseOrder]:
        query = self.db.query(PurchaseOrder).filter(PurchaseOrder.po_id == po_id)
        if active_only:
            query = query.filter(PurchaseOrder.is_active.is_(True))
        return query.first()

    def po_number_exists(self, po_number: str, exclude_id: Optional[int] = None) -> bool:
        query = self.db.query(PurchaseOrder.po_id).filter(PurchaseOrder.po_number == po_number)
        if exclude_id:
            query = query.filter(PurchaseOrder.po_id != exclude_id)
        return query.first() is not None

    def version_info(self, po_id: int) -> Tuple[Optional[int], Optional[datetime], Optional[str]]:
        """Persisted (version, updated_at, updated_by), read fresh from the database."""
        row = (
            self.db.query(PurchaseOrder.version, PurchaseOrder.updated_at, PurchaseOrder.updated_by)
            .filter(PurchaseOrder.po_id == po_id)
            .first()
        )
        return (row[0], row[1], row[2]) if row else (None, None, None)

    def get_all(
        self,
        include_inactive: bool = False,
        status_values: Optional[Sequence[str]] = None,
        project_id: Optional[int] = None,
        company_id: Optional[int] = None,
        supplier_id: Optional[int] = None,
        search: Optional[str] = None,
    ) -> List[PurchaseOrder]:
        query = (
            self.db.query(PurchaseOrder)
            .options(
                joinedload(PurchaseOrder.project),
                joinedload(PurchaseOrder.company),
                joinedload(PurchaseOrder.supplier),
                joinedload(PurchaseOrder.incoterm),
                joinedload(PurchaseOrder.currency),
                selectinload(PurchaseOrder.line_items),
                selectinload(PurchaseOrder.packing_list_items),
            )
        )
        if not include_inactive:
            query = query.filter(PurchaseOrder.is_active.is_(True))
        if status_values:
            query = query.filter(PurchaseOrder.status.in_(list(status_values)))
        if project_id:
            query = query.filter(PurchaseOrder.project_id == project_id)
        if company_id:
            query = query.filter(PurchaseOrder.company_id == company_id)
        if supplier_id:
            query = query.filter(PurchaseOrder.supplier_id == supplier_id)
        if search:
            pattern = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    PurchaseOrder.po_number.ilike(pattern),
                    PurchaseOrder.po_reference.ilike(pattern),
                    PurchaseOrder.proforma_invoice_number.ilike(pattern),
                    PurchaseOrder.notes.ilike(pattern),
                )
            )
        return query.order_by(PurchaseOrder.created_at.desc()).all()

    def get_import_file(self, import_file_id: int) -> Optional[ImportFile]:
        return self.db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()

    def list_allocations(self, po_id: int, newest_first: bool = False) -> List[POShipmentAllocation]:
        query = self.db.query(POShipmentAllocation).filter(POShipmentAllocation.po_id == po_id)
        if newest_first:
            query = query.order_by(POShipmentAllocation.shipping_date.desc())
        return query.all()

    def allocated_item_ids(self, po_id: int) -> Set[int]:
        rows = (
            self.db.query(POShipmentAllocation.po_item_id)
            .filter(POShipmentAllocation.po_id == po_id, POShipmentAllocation.po_item_id.isnot(None))
            .distinct()
            .all()
        )
        return {r[0] for r in rows}

    # ── writes (flush only) ──

    def add(self, po: PurchaseOrder) -> PurchaseOrder:
        self.db.add(po)
        self.db.flush()
        return po

    def add_allocation(self, allocation: POShipmentAllocation) -> POShipmentAllocation:
        self.db.add(allocation)
        self.db.flush()
        return allocation

    @staticmethod
    def _sync_children(collection: List[Any], id_attr: str, model: Type, rows: Sequence[ChildRow]) -> List[Any]:
        """Upsert ``rows`` into ``collection`` by id: rows with an id update that row in place (columns not in
        the values are left untouched), rows without an id are new, existing rows not sent are removed
        (delete-orphan). Callers validate the ids first. Returns the rows in payload order."""
        existing = {getattr(child, id_attr): child for child in collection}
        result = []
        for row_id, values in rows:
            child = existing.get(row_id) if row_id is not None else None
            if child is None:
                child = model(**values)
            else:
                for field, value in values.items():
                    setattr(child, field, value)
            result.append(child)
        collection[:] = result
        return result

    def upsert_line_items(self, po: PurchaseOrder, rows: Sequence[ChildRow]) -> List[POLineItem]:
        return self._sync_children(po.line_items, "item_id", POLineItem, rows)

    def upsert_packing_items(self, po: PurchaseOrder, rows: Sequence[ChildRow]) -> List[PackingListItem]:
        return self._sync_children(po.packing_list_items, "packing_item_id", PackingListItem, rows)

    def set_active(self, po: PurchaseOrder, is_active: bool) -> PurchaseOrder:
        po.is_active = is_active
        self.db.flush()
        return po
