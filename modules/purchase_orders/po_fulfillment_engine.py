"""Engine for calculating Purchase Order balance, line item progress, and cumulative fulfillment metrics."""

from typing import Any, Dict, List, Optional, Sequence, Tuple
from sqlalchemy.orm import Session

from modules.common import enum_codes
from modules.common.validators import not_found
from modules.purchase_orders.model import POLineItem, POShipmentAllocation, PurchaseOrder
from modules.purchase_orders.repository import PurchaseOrderRepository
from modules.purchase_orders.schemas import (
    POBalanceSummaryResponse,
    POLineItemBalanceItem,
    POShipmentAllocationResponse,
)
from modules.purchase_orders.validators import FINAL_STATUSES

QTY_EPSILON = 1e-9

# Balance fulfillment labels (response-only, unchanged contract).
BALANCE_PENDING = "Pending"
BALANCE_PARTIAL = "Partially Shipped"
BALANCE_FULL = "Fully Shipped"
BALANCE_OVER = "Over-Shipped"


def _status_code(value: Optional[str]) -> Optional[str]:
    """Stored status as a PO_STATUS code (legacy label rows are normalized on read)."""
    return enum_codes.normalize(enum_codes.PO_STATUS, value)


class POFulfillmentEngine:
    """Calculates PO balance ledger, fulfillment states, and weighted completion metrics."""

    def __init__(self, db: Session, repo: Optional[PurchaseOrderRepository] = None):
        self.db = db
        self.repo = repo or PurchaseOrderRepository(db)

    @staticmethod
    def shipped_totals(allocations: Sequence[POShipmentAllocation]) -> Tuple[float, float]:
        """(shipped qty, shipped FOB) over EVERY allocation, item-level or PO-level. Single source of truth
        for the PO header status and the balance totals."""
        qty = sum(float(a.shipped_quantity or 0.0) for a in allocations)
        fob = sum(float(a.shipped_amount_fob or 0.0) for a in allocations)
        return qty, fob

    @staticmethod
    def ordered_qty(po: PurchaseOrder) -> float:
        return sum(float(it.quantity or 0.0) for it in (po.line_items or []))

    @staticmethod
    def line_progress(
        po: PurchaseOrder, allocations: Sequence[POShipmentAllocation]
    ) -> Tuple[List[Tuple[POLineItem, float, float]], List[POShipmentAllocation]]:
        """Per line (item, shipped qty, shipped FOB) plus the PO-level allocations no line can take: a PO-level
        allocation belongs to the line only when the PO has exactly one line. An allocation whose po_item_id is not a
        current line (rows left by the old delete-and-recreate edits) counts as PO-level."""
        lines = list(po.line_items or [])
        line_ids = {it.item_id for it in lines}
        po_level = [a for a in allocations if a.po_item_id not in line_ids]
        progress = []
        unattributed = po_level if len(lines) != 1 else []
        for it in lines:
            item_allocs = [a for a in allocations if a.po_item_id == it.item_id]
            if len(lines) == 1:
                item_allocs += po_level
            qty, fob = POFulfillmentEngine.shipped_totals(item_allocs)
            progress.append((it, qty, fob))
        return progress, unattributed

    @staticmethod
    def fulfillment_state(
        progress: Sequence[Tuple[POLineItem, float, float]], unattributed: Sequence[POShipmentAllocation]
    ) -> Optional[str]:
        """None (nothing shipped / nothing ordered), BALANCE_PARTIAL, BALANCE_FULL or BALANCE_OVER, decided on the
        raw per-line quantities (never on a rounded percentage). PO-level allocations of a multi-line PO cannot be
        attributed, so they only count against the PO total."""
        ordered_total = sum(float(it.quantity or 0.0) for it, _, _ in progress)
        unattributed_qty, _ = POFulfillmentEngine.shipped_totals(unattributed)
        shipped_total = sum(q for _, q, _ in progress) + unattributed_qty
        if ordered_total <= 0 or shipped_total <= 0:
            return None
        lines_full = all(q >= float(it.quantity or 0.0) - QTY_EPSILON for it, q, _ in progress)
        any_line_over = any(q > float(it.quantity or 0.0) + QTY_EPSILON for it, q, _ in progress)
        if shipped_total > ordered_total + QTY_EPSILON or (lines_full and any_line_over):
            return BALANCE_OVER
        if lines_full or (unattributed and shipped_total >= ordered_total - QTY_EPSILON):
            return BALANCE_FULL
        return BALANCE_PARTIAL

    def sync_po_fulfillment_status(self, po: PurchaseOrder, allocations: Sequence[POShipmentAllocation]) -> bool:
        """Set PARTIALLY_SHIPPED / FULLY_SHIPPED from the per-line shipped quantities (same rule as the balance).
        CLOSED and CANCELLED are final and never overwritten. Returns True when the status changed."""
        current = _status_code(po.status)
        if current in FINAL_STATUSES:
            return False
        state = self.fulfillment_state(*self.line_progress(po, allocations))
        if state is None:
            return False
        target = "PARTIALLY_SHIPPED" if state == BALANCE_PARTIAL else "FULLY_SHIPPED"
        if target == current:
            return False
        po.status = target
        return True

    def compute_po_balance(self, po_id: int) -> POBalanceSummaryResponse:
        """Ordered, shipped and remaining quantities / amounts of a PO.

        Line breakdown: item-level allocations; a PO-level allocation is attributed to the line only when the
        PO has a single line. Quantity / FOB totals count every allocation (same source as the PO header status).
        The status is decided on the raw per-line quantities. The overall percentage is value-weighted when the value
        is fully known (lines may use different units): shipped value / ordered value with value = qty x unit price,
        PO-level allocations of a multi-line PO counted with their FOB amount. It needs every line priced (> 0) and
        every PO-level allocation with a FOB amount (> 0). Otherwise: the mean of the line percentages (unit-safe)
        when every allocation belongs to a line, or the total quantity share (all shipped qty / ordered qty) when
        PO-level quantity exists that no line can take."""
        po = self.repo.get_by_id(po_id)
        if po is None:
            raise not_found("أمر الشراء", po_id)
        allocations = self.repo.list_allocations(po.po_id, newest_first=True)
        progress, unattributed = self.line_progress(po, allocations)
        items_balance: List[POLineItemBalanceItem] = []
        total_ordered_qty = 0.0
        total_ordered_fob = 0.0
        ordered_value = 0.0
        shipped_value = self.shipped_totals(unattributed)[1]
        value_known = all(float(a.shipped_amount_fob or 0.0) > 0 for a in unattributed)
        line_percents: List[float] = []

        for it, shipped_q, shipped_fob in progress:
            ord_q = float(it.quantity or 0.0)
            u_price = float(it.unit_price or 0.0)
            ord_fob = float(it.total_price or (ord_q * u_price))
            ordered_value += ord_q * u_price
            shipped_value += shipped_q * u_price
            value_known = value_known and u_price > 0
            line_percents.append((shipped_q / ord_q * 100.0) if ord_q > 0 else 0.0)
            items_balance.append(
                POLineItemBalanceItem(
                    item_id=it.item_id,
                    item_code=it.item_code,
                    description_ar=it.description_ar,
                    ordered_qty=ord_q,
                    shipped_qty=shipped_q,
                    remaining_qty=max(0.0, ord_q - shipped_q),
                    unit_price=u_price,
                    ordered_amount_fob=ord_fob,
                    shipped_amount_fob=shipped_fob,
                    remaining_amount_fob=max(0.0, ord_fob - shipped_fob),
                    fulfillment_percent=round((shipped_q / ord_q * 100.0) if ord_q > 0 else 0.0, 1),
                )
            )
            total_ordered_qty += ord_q
            total_ordered_fob += ord_fob

        total_shipped_qty, total_shipped_fob = self.shipped_totals(allocations)
        total_rem_qty = max(0.0, total_ordered_qty - total_shipped_qty)
        total_rem_fob = max(0.0, total_ordered_fob - total_shipped_fob)
        by_value = bool(progress) and value_known and ordered_value > 0
        if by_value:
            overall_raw = shipped_value / ordered_value * 100.0
            method_ar = "حسب القيمة التعاقدية"
        elif line_percents and not unattributed:
            overall_raw = sum(line_percents) / len(line_percents)
            method_ar = "متوسط نسب البنود"
        else:
            overall_raw = (total_shipped_qty / total_ordered_qty * 100.0) if total_ordered_qty > 0 else 0.0
            method_ar = "حسب إجمالي الكميات"
        overall_percent = round(overall_raw, 1)
        fulfillment_status = self.fulfillment_state(progress, unattributed) or BALANCE_PENDING

        curr_code = po.currency.currency_code if po.currency else None
        curr_label = f" {curr_code}" if curr_code else ""
        # Deprecated presentation field (PO-15): clients should render from the numeric fields.
        summary_ar = (
            f"ميزان أمر الشراء #{po.po_number}: تم شحن {total_shipped_qty:,.0f} من إجمالي {total_ordered_qty:,.0f} وحدة "
            f"({overall_percent}% إنجاز توريد {method_ar})، والمتبقي للتوريد {total_rem_qty:,.0f} وحدة "
            f"بقيمة تعاقدية متبقية {total_rem_fob:,.2f}{curr_label} عبر {len(allocations)} شحنات مجزأة."
        )

        po.total_shipped_quantity = round(total_shipped_qty, 2)
        po.remaining_balance_quantity = round(total_rem_qty, 2)
        if total_shipped_qty <= 0:
            po.fulfillment_status = "OPEN"
        elif total_shipped_qty >= total_ordered_qty - QTY_EPSILON:
            po.fulfillment_status = "FULLY_SHIPPED"
        else:
            po.fulfillment_status = "PARTIALLY_SHIPPED"
        self.db.commit()

        return POBalanceSummaryResponse(
            po_id=po.po_id,
            po_number=po.po_number,
            total_ordered_qty=round(total_ordered_qty, 2),
            total_shipped_qty=round(total_shipped_qty, 2),
            total_remaining_qty=round(total_rem_qty, 2),
            total_ordered_amount_fob=round(total_ordered_fob, 2),
            total_shipped_amount_fob=round(total_shipped_fob, 2),
            total_remaining_amount_fob=round(total_rem_fob, 2),
            currency_code=curr_code,
            overall_fulfillment_percent=overall_percent,
            fulfillment_status=fulfillment_status,
            line_items_balance=items_balance,
            allocations=[POShipmentAllocationResponse.model_validate(a) for a in allocations],
            executive_summary_ar=summary_ar,
        )
