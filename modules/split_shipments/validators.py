"""
Validators for Split Shipments & Multi-PO Allocations
"""

from typing import List
from fastapi import HTTPException, status
from modules.split_shipments.schemas import (
    SplitShipmentAllocationCreate,
    SplitShipmentAllocationUpdate,
    BatchAllocationCreate,
)


def validate_bl_numbers(parent_bl: str, split_bl: str) -> None:
    p = parent_bl.strip()
    s = split_bl.strip()
    if not p:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Parent Bill of Lading (Master B/L) number cannot be empty.",
        )
    if not s:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Split Bill of Lading number cannot be empty.",
        )


def validate_quantities(allocated_qty: float, total_qty: float) -> float:
    """Validate quantity values and calculate the exact allocation ratio."""
    if total_qty <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Total item quantity must be greater than zero.",
        )
    if allocated_qty <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Allocated quantity must be greater than zero.",
        )
    if allocated_qty > total_qty:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Allocated quantity ({allocated_qty}) cannot exceed total item quantity ({total_qty}).",
        )
    return round(allocated_qty / total_qty, 6)


def validate_batch_allocations(payload: BatchAllocationCreate) -> None:
    if not payload.items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Batch allocation items list cannot be empty.",
        )

    parent_bl = payload.parent_bl_number.strip()
    if not parent_bl:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Parent B/L number is required for batch allocations.",
        )

    # Check for exceeding total item quantity per SKU/item within the batch
    sku_totals: dict = {}
    for item in payload.items:
        validate_bl_numbers(parent_bl, item.split_bl_number)
        validate_quantities(item.allocated_quantity, item.total_item_quantity)

        key = (item.po_item_id, item.item_sku) if item.po_item_id else item.item_sku
        current_sum = sku_totals.get(key, 0.0) + item.allocated_quantity
        if current_sum > item.total_item_quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Cumulative allocated quantity for SKU '{item.item_sku}' ({current_sum}) "
                    f"exceeds total order quantity ({item.total_item_quantity})."
                ),
            )
        sku_totals[key] = current_sum
