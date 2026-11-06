"""
Service for Split Shipments & Multi-PO Allocations
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.split_shipments.model import SplitShipmentAllocation
from modules.split_shipments.repository import SplitShipmentRepository
from modules.split_shipments.schemas import (
    SplitShipmentAllocationCreate,
    SplitShipmentAllocationUpdate,
    BatchAllocationCreate,
    ProratedCostCalculationRequest,
    ProratedCostCalculationResponse,
    ProratedCostItemResult,
    UnallocatedPoItemOut,
    UnallocatedPoItemsOut,
)
from modules.split_shipments.validators import (
    validate_bl_numbers,
    validate_quantities,
    validate_batch_allocations,
)


class SplitShipmentService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = SplitShipmentRepository(db)

    def list_unallocated_po_items(self, shipment_id: int) -> UnallocatedPoItemsOut:
        """Real PO lines linked to the import file that still have quantity left to allocate."""
        import_file = self.repo.get_import_file(shipment_id)
        if not import_file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Import file #{shipment_id} not found.",
            )

        linked_po_ids = [
            int(po_id) for po_id in (import_file.po_ids or []) if str(po_id).isdigit()
        ]
        lines = self.repo.list_po_lines_for_shipment(shipment_id, linked_po_ids)
        allocated_by_item = self.repo.get_allocated_quantity_by_po_item(shipment_id)

        items: List[UnallocatedPoItemOut] = []
        for line, po in lines:
            total_qty = float(line.quantity or 0.0)
            allocated_qty = allocated_by_item.get(line.item_id, 0.0)
            remaining = round(total_qty - allocated_qty, 4)
            if remaining <= 0:
                continue
            items.append(
                UnallocatedPoItemOut(
                    po_item_id=line.item_id,
                    po_id=po.po_id,
                    po_number=po.po_number,
                    item_sku=(line.item_code or "").strip() or f"PO-LINE-{line.item_id}",
                    item_name=line.description_ar or line.description_en or line.main_description or "",
                    unit_of_measure=line.unit_of_measure,
                    total_quantity=total_qty,
                    allocated_quantity=allocated_qty,
                    remaining_quantity=remaining,
                )
            )

        return UnallocatedPoItemsOut(
            shipment_id=shipment_id,
            bl_number=import_file.bl_number,
            items=items,
            total=len(items),
        )

    def create_allocation(
        self,
        payload: SplitShipmentAllocationCreate,
        user_id: Optional[int] = None,
    ) -> SplitShipmentAllocation:
        validate_bl_numbers(payload.parent_bl_number, payload.split_bl_number)
        ratio = validate_quantities(payload.allocated_quantity, payload.total_item_quantity)

        # Check existing allocations for cumulative cap
        existing = self.repo.get_existing_allocations_for_item(
            payload.shipment_id,
            payload.po_item_id,
            payload.item_sku,
        )
        current_allocated = sum(e.allocated_quantity for e in existing)
        if (current_allocated + payload.allocated_quantity) > payload.total_item_quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"SKU '{payload.item_sku}' already has {current_allocated} units allocated. "
                    f"Adding {payload.allocated_quantity} exceeds total order quantity of {payload.total_item_quantity}."
                ),
            )

        customs_cost = round((payload.customs_cost_pool or 0.0) * ratio, 2)
        freight_cost = round((payload.freight_cost_pool or 0.0) * ratio, 2)

        allocation = SplitShipmentAllocation(
            shipment_id=payload.shipment_id,
            parent_bl_number=payload.parent_bl_number.strip().upper(),
            split_bl_number=payload.split_bl_number.strip().upper(),
            po_id=payload.po_id,
            po_item_id=payload.po_item_id,
            item_sku=payload.item_sku.strip(),
            allocated_quantity=payload.allocated_quantity,
            total_item_quantity=payload.total_item_quantity,
            allocation_ratio=ratio,
            prorated_customs_cost=customs_cost,
            prorated_freight_cost=freight_cost,
            currency=payload.currency.upper(),
            notes=payload.notes,
            created_by_user_id=user_id,
            updated_by_user_id=user_id,
        )
        self.repo.create(allocation)
        self.db.commit()
        return self.repo.get_by_id(allocation.id)

    def create_batch_allocations(
        self,
        payload: BatchAllocationCreate,
        user_id: Optional[int] = None,
    ) -> List[SplitShipmentAllocation]:
        validate_batch_allocations(payload)

        created_records = []
        for item in payload.items:
            ratio = validate_quantities(item.allocated_quantity, item.total_item_quantity)

            # Check DB existing
            existing = self.repo.get_existing_allocations_for_item(
                payload.shipment_id,
                item.po_item_id,
                item.item_sku,
            )
            already_allocated = sum(e.allocated_quantity for e in existing)
            if (already_allocated + item.allocated_quantity) > item.total_item_quantity:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=(
                        f"Item SKU '{item.item_sku}' already has {already_allocated} allocated in database. "
                        f"Cannot allocate {item.allocated_quantity} more (Total limit: {item.total_item_quantity})."
                    ),
                )

            customs_prorated = round(payload.customs_cost_pool * ratio, 2)
            freight_prorated = round(payload.freight_cost_pool * ratio, 2)

            alloc = SplitShipmentAllocation(
                shipment_id=payload.shipment_id,
                parent_bl_number=payload.parent_bl_number.strip().upper(),
                split_bl_number=item.split_bl_number.strip().upper(),
                po_id=item.po_id,
                po_item_id=item.po_item_id,
                item_sku=item.item_sku.strip(),
                allocated_quantity=item.allocated_quantity,
                total_item_quantity=item.total_item_quantity,
                allocation_ratio=ratio,
                prorated_customs_cost=customs_prorated,
                prorated_freight_cost=freight_prorated,
                currency=payload.currency.upper(),
                notes=item.notes,
                created_by_user_id=user_id,
                updated_by_user_id=user_id,
            )
            self.repo.create(alloc)
            created_records.append(alloc)

        self.db.commit()
        return created_records

    def update_allocation(
        self,
        allocation_id: int,
        payload: SplitShipmentAllocationUpdate,
        user_id: Optional[int] = None,
    ) -> SplitShipmentAllocation:
        alloc = self.repo.get_by_id(allocation_id)
        if not alloc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Split allocation #{allocation_id} not found.",
            )

        if payload.parent_bl_number is not None:
            alloc.parent_bl_number = payload.parent_bl_number.strip().upper()
        if payload.split_bl_number is not None:
            alloc.split_bl_number = payload.split_bl_number.strip().upper()
        if payload.po_id is not None:
            alloc.po_id = payload.po_id
        if payload.po_item_id is not None:
            alloc.po_item_id = payload.po_item_id
        if payload.item_sku is not None:
            alloc.item_sku = payload.item_sku.strip()

        new_qty = payload.allocated_quantity if payload.allocated_quantity is not None else alloc.allocated_quantity
        new_total = payload.total_item_quantity if payload.total_item_quantity is not None else alloc.total_item_quantity

        if payload.allocated_quantity is not None or payload.total_item_quantity is not None:
            new_ratio = validate_quantities(new_qty, new_total)
            existing = self.repo.get_existing_allocations_for_item(
                alloc.shipment_id,
                alloc.po_item_id,
                alloc.item_sku,
                exclude_id=alloc.id,
            )
            other_allocated = sum(e.allocated_quantity for e in existing)
            if (other_allocated + new_qty) > new_total:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Updated allocated quantity exceeds available total for SKU {alloc.item_sku}.",
                )
            alloc.allocated_quantity = new_qty
            alloc.total_item_quantity = new_total
            alloc.allocation_ratio = new_ratio

        if payload.prorated_customs_cost is not None:
            alloc.prorated_customs_cost = payload.prorated_customs_cost
        if payload.prorated_freight_cost is not None:
            alloc.prorated_freight_cost = payload.prorated_freight_cost
        if payload.currency is not None:
            alloc.currency = payload.currency.upper()
        if payload.notes is not None:
            alloc.notes = payload.notes

        alloc.updated_by_user_id = user_id
        alloc.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        return self.repo.get_by_id(alloc.id)

    def soft_delete_allocation(self, allocation_id: int, user_id: Optional[int] = None) -> bool:
        alloc = self.repo.get_by_id(allocation_id)
        if not alloc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Split allocation #{allocation_id} not found.",
            )
        alloc.is_deleted = True
        alloc.updated_by_user_id = user_id
        alloc.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        return True

    def calculate_prorated_costs(
        self,
        req: ProratedCostCalculationRequest,
        user_id: Optional[int] = None,
    ) -> ProratedCostCalculationResponse:
        allocations, total = self.repo.list_by_shipment(req.shipment_id, limit=500)
        if not allocations:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No active split allocations found for shipment #{req.shipment_id}.",
            )

        results = []
        for alloc in allocations:
            customs_share = round(req.customs_cost_pool * alloc.allocation_ratio, 2)
            freight_share = round(req.freight_cost_pool * alloc.allocation_ratio, 2)

            alloc.prorated_customs_cost = customs_share
            alloc.prorated_freight_cost = freight_share
            alloc.currency = req.currency.upper()
            alloc.updated_by_user_id = user_id
            alloc.updated_at = datetime.now(timezone.utc)

            results.append(
                ProratedCostItemResult(
                    allocation_id=alloc.id,
                    item_sku=alloc.item_sku,
                    split_bl_number=alloc.split_bl_number,
                    allocated_quantity=alloc.allocated_quantity,
                    allocation_ratio=alloc.allocation_ratio,
                    prorated_customs_cost=customs_share,
                    prorated_freight_cost=freight_share,
                )
            )

        self.db.commit()
        return ProratedCostCalculationResponse(
            shipment_id=req.shipment_id,
            total_allocations=len(results),
            customs_cost_pool=req.customs_cost_pool,
            freight_cost_pool=req.freight_cost_pool,
            currency=req.currency.upper(),
            allocations=results,
        )
