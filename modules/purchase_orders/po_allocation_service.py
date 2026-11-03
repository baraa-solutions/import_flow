"""Service for partial shipment allocation and linking PO line items to shipments and import files."""

from datetime import datetime, timezone
from typing import Any, List, Optional
from fastapi import status
from sqlalchemy.orm import Session

from modules.common.errors import CodedHTTPException
from modules.common.system_messages import SystemMessageItem, to_item
from modules.common.validators import not_found
from modules.purchase_orders.model import POShipmentAllocation, PurchaseOrder
from modules.purchase_orders.po_fulfillment_engine import (
    POFulfillmentEngine,
    QTY_EPSILON,
    _status_code,
)
from modules.purchase_orders.repository import PurchaseOrderRepository
from modules.purchase_orders.schemas import (
    POShipmentAllocationCreate,
    POShipmentAllocationResponse,
)
from modules.purchase_orders.validators import FINAL_STATUSES, PurchaseOrderValidator


class POAllocationService:
    """Handles partial shipment allocations, ledger entry creation, and PO fulfillment triggers."""

    def __init__(
        self,
        db: Session,
        repo: Optional[PurchaseOrderRepository] = None,
        validator: Optional[PurchaseOrderValidator] = None,
        fulfillment_engine: Optional[POFulfillmentEngine] = None,
    ):
        self.db = db
        self.repo = repo or PurchaseOrderRepository(db)
        self.validator = validator or PurchaseOrderValidator(db)
        self.fulfillment_engine = fulfillment_engine or POFulfillmentEngine(db, repo=self.repo)

    def _get_or_404(self, po_id: int, active_only: bool = False, label_ar: str = "أمر الشراء") -> PurchaseOrder:
        po = self.repo.get_by_id(po_id, active_only=active_only)
        if po is None:
            raise not_found(label_ar, po_id)
        return po

    def _touch(self, po: PurchaseOrder, user: Optional[str], current_version: Optional[int] = None) -> None:
        po.version = (current_version if current_version is not None else (po.version or 1)) + 1
        po.updated_at = datetime.now(timezone.utc)
        po.updated_by = user

    def _commit(self, *instances: Any) -> None:
        self.db.commit()
        for instance in instances:
            self.db.refresh(instance)

    def allocate_shipment(
        self, po_id: int, data: POShipmentAllocationCreate, current_user_name: Optional[str] = None
    ) -> POShipmentAllocationResponse:
        """Record a (partial) shipment against an active PO and update its fulfillment status in one commit.
        Over-allocation is allowed; the response then carries an OVER_SHIPPED warning."""
        po = self._get_or_404(po_id, active_only=True)
        current_status = _status_code(po.status) or po.status
        if current_status in FINAL_STATUSES:
            raise CodedHTTPException(
                status.HTTP_409_CONFLICT,
                "PO_NOT_EDITABLE",
                f"لا يمكن تسجيل شحنات لأمر الشراء في حالة '{current_status}'.",
                status=current_status,
            )
        item = self.validator.validate_allocation(po, data)
        alloc_status = self.validator.normalize_allocation_status(data.status)

        allocation = POShipmentAllocation(
            po_id=po.po_id,
            po_line_item_id=getattr(data, "po_line_item_id", None) or getattr(data, "po_item_id", None),
            po_item_id=getattr(data, "po_line_item_id", None) or getattr(data, "po_item_id", None),
            import_file_id=data.import_file_id,
            shipment_batch_no=getattr(data, "shipment_batch_no", None) or data.shipment_ref,
            shipment_ref=(data.shipment_ref or getattr(data, "shipment_batch_no", None) or "BATCH-01").strip(),
            allocated_quantity=getattr(data, "allocated_quantity", None) or data.shipped_quantity or 0.0,
            shipped_quantity=data.shipped_quantity or getattr(data, "allocated_quantity", None) or 0.0,
            allocated_fob_amount=getattr(data, "allocated_fob_amount", None) or data.shipped_amount_fob or 0.0,
            shipped_amount_fob=data.shipped_amount_fob or getattr(data, "allocated_fob_amount", None) or 0.0,
            shipping_date=data.shipping_date or datetime.now(timezone.utc),
            status=alloc_status,
            notes=data.notes,
            created_by=current_user_name,
            updated_by=current_user_name,
        )
        self.repo.add_allocation(allocation)
        allocations = self.repo.list_allocations(po.po_id)

        messages: List[SystemMessageItem] = []
        if item is not None:
            item_shipped, _ = self.fulfillment_engine.shipped_totals([a for a in allocations if a.po_item_id == item.item_id])
            item_ordered = float(item.quantity or 0.0)
            if item_shipped > item_ordered + QTY_EPSILON:
                messages.append(to_item("OVER_SHIPPED", "warning", shipped_qty=round(item_shipped, 2), ordered_qty=round(item_ordered, 2),
                                         po_number=po.po_number, item_code=item.item_code))
        if not messages:
            ordered = self.fulfillment_engine.ordered_qty(po)
            shipped, _ = self.fulfillment_engine.shipped_totals(allocations)
            if ordered > 0 and shipped > ordered + QTY_EPSILON:
                messages.append(to_item("OVER_SHIPPED", "warning", shipped_qty=round(shipped, 2), ordered_qty=round(ordered, 2),
                                         po_number=po.po_number, item_code=None))

        total_ord_q = self.fulfillment_engine.ordered_qty(po)
        total_ship_q, _ = self.fulfillment_engine.shipped_totals(allocations)
        po.total_shipped_quantity = round(total_ship_q, 2)
        po.remaining_balance_quantity = max(0.0, round(total_ord_q - total_ship_q, 2))
        if total_ship_q <= 0:
            po.fulfillment_status = "OPEN"
        elif total_ship_q >= total_ord_q - QTY_EPSILON:
            po.fulfillment_status = "FULLY_SHIPPED"
        else:
            po.fulfillment_status = "PARTIALLY_SHIPPED"

        if self.fulfillment_engine.sync_po_fulfillment_status(po, allocations):
            self._touch(po, current_user_name)
        self._commit(allocation)

        response = POShipmentAllocationResponse.model_validate(allocation)
        response.messages = messages
        return response
