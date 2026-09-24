"""
Customs Clearance Quotations & Price Lists Router
"""

from __future__ import annotations

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.customs_clearance_quotations.schemas import (
    CustomsClearanceRFQCreate,
    CustomsClearanceRFQUpdate,
    CustomsClearanceRFQResponse,
    CustomsClearanceQuotationCreate,
    CustomsClearanceQuotationUpdate,
    CustomsClearanceQuotationResponse,
    AwardClearanceQuotationRequest,
    ClearancePriceListItemCreate,
    ClearancePriceListItemUpdate,
    ClearancePriceListItemResponse,
)
import modules.customs_clearance_quotations.service as svc

router = APIRouter(
    prefix="/api/v1/customs-clearance-quotations",
    tags=["Customs Clearance Quotations & Price Lists"],
    dependencies=[Depends(get_current_user)],
)


# ─── RFQ Endpoints ────────────────────────────────────────────────────────────

@router.get("/rfqs", response_model=List[CustomsClearanceRFQResponse])
def get_clearance_rfqs(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    status: Optional[str] = None,
    port_name: Optional[str] = None,
    import_file_id: Optional[int] = None,
    include_inactive: bool = False,
    db: Session = Depends(get_db),
):
    """List all Customs Clearance Requests for Quotation (RFQs)."""
    return svc.get_rfqs_service(
        db,
        skip=skip,
        limit=limit,
        status_filter=status,
        port_name=port_name,
        import_file_id=import_file_id,
        include_inactive=include_inactive,
    )


@router.post("/rfqs", response_model=CustomsClearanceRFQResponse, status_code=status.HTTP_201_CREATED)
def create_clearance_rfq(
    data: CustomsClearanceRFQCreate,
    db: Session = Depends(get_db),
):
    """Create a new Customs Clearance RFQ with optional initial quotation items."""
    return svc.create_rfq_service(db, data)


@router.get("/rfqs/{rfq_id}", response_model=CustomsClearanceRFQResponse)
def get_clearance_rfq_by_id(
    rfq_id: int,
    db: Session = Depends(get_db),
):
    """Get single Customs Clearance RFQ details and competing broker quotes."""
    return svc.get_rfq_by_id_service(db, rfq_id)


@router.put("/rfqs/{rfq_id}", response_model=CustomsClearanceRFQResponse)
def update_clearance_rfq(
    rfq_id: int,
    data: CustomsClearanceRFQUpdate,
    db: Session = Depends(get_db),
):
    """Update Customs Clearance RFQ details."""
    return svc.update_rfq_service(db, rfq_id, data)


@router.delete("/rfqs/{rfq_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_clearance_rfq(
    rfq_id: int,
    db: Session = Depends(get_db),
):
    """Soft delete Customs Clearance RFQ and associated quotation items."""
    svc.delete_rfq_service(db, rfq_id)
    return None


# ─── Quotation Items Endpoints ────────────────────────────────────────────────

@router.post("/rfqs/{rfq_id}/quotations", response_model=CustomsClearanceQuotationResponse, status_code=status.HTTP_201_CREATED)
def add_quotation_to_rfq(
    rfq_id: int,
    data: CustomsClearanceQuotationCreate,
    db: Session = Depends(get_db),
):
    """Add an individual customs broker quotation to an existing clearance RFQ."""
    return svc.add_quotation_service(db, rfq_id, data)


@router.put("/quotations/{quotation_id}", response_model=CustomsClearanceQuotationResponse)
def update_clearance_quotation(
    quotation_id: int,
    data: CustomsClearanceQuotationUpdate,
    db: Session = Depends(get_db),
):
    """Update an individual customs broker quotation cost elements."""
    return svc.update_quotation_service(db, quotation_id, data)


@router.delete("/quotations/{quotation_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_clearance_quotation(
    quotation_id: int,
    db: Session = Depends(get_db),
):
    """Delete an individual clearance quotation item."""
    svc.delete_quotation_service(db, quotation_id)
    return None


@router.post("/rfqs/{rfq_id}/award", response_model=CustomsClearanceRFQResponse)
def award_clearance_quotation(
    rfq_id: int,
    data: AwardClearanceQuotationRequest,
    db: Session = Depends(get_db),
):
    """Award a specific customs broker quotation for this shipment clearance."""
    return svc.award_quotation_service(db, rfq_id, data.quotation_id, data.notes)


# ─── Price List Endpoints ─────────────────────────────────────────────────────

@router.get("/price-list", response_model=List[ClearancePriceListItemResponse])
def get_clearance_price_list(
    provider_id: Optional[int] = None,
    port_name: Optional[str] = None,
    service_category: Optional[str] = None,
    include_inactive: bool = False,
    db: Session = Depends(get_db),
):
    """List standard clearance price list items."""
    return svc.get_price_list_service(
        db,
        provider_id=provider_id,
        port_name=port_name,
        service_category=service_category,
        include_inactive=include_inactive,
    )


@router.post("/price-list", response_model=ClearancePriceListItemResponse, status_code=status.HTTP_201_CREATED)
def create_clearance_price_item(
    data: ClearancePriceListItemCreate,
    db: Session = Depends(get_db),
):
    """Add a new standard rate item to the Clearance Price List master data."""
    return svc.create_price_item_service(db, data)


@router.put("/price-list/{item_id}", response_model=ClearancePriceListItemResponse)
def update_clearance_price_item(
    item_id: int,
    data: ClearancePriceListItemUpdate,
    db: Session = Depends(get_db),
):
    """Update a clearance price list item."""
    return svc.update_price_item_service(db, item_id, data)


@router.delete("/price-list/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_clearance_price_item(
    item_id: int,
    db: Session = Depends(get_db),
):
    """Soft delete a clearance price list item."""
    svc.delete_price_item_service(db, item_id)
    return None
