"""
Freight Quotations REST Router (BP-008)
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from database.database import get_db
from modules.freight_quotations.schemas import (
    FreightRFQRequestCreate,
    FreightRFQRequestUpdate,
    FreightRFQRequestResponse,
    RFQBenchmarkResponse,
)
from modules.freight_quotations.service import FreightQuotationService


router = APIRouter(
    prefix="/api/v1/freight-quotations",
    tags=["Freight Quotations (BP-008)"],
    dependencies=[Depends(get_current_user)],
)


@router.post(
    "",
    response_model=FreightRFQRequestResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Freight RFQ request (BP-008)",
)
def create_rfq(
    rfq_in: FreightRFQRequestCreate,
    db: Session = Depends(get_db),
):
    return FreightQuotationService.create_rfq(db, rfq_in)


@router.get(
    "",
    response_model=List[FreightRFQRequestResponse],
    summary="List Freight RFQ requests with filtering (BP-008)",
)
def list_rfqs(
    include_inactive: bool = Query(False, description="Include soft-deleted RFQs"),
    search: Optional[str] = Query(None, description="Search by code, title, POL, or POD"),
    shipping_method: Optional[str] = Query(None, description="Filter by shipping method"),
    import_file_id: Optional[int] = Query(None, description="Filter by Import File ID"),
    po_id: Optional[int] = Query(None, description="Filter by Purchase Order ID"),
    project_id: Optional[int] = Query(None, description="Filter by Project ID"),
    status: Optional[str] = Query(None, description="Filter by RFQ status"),
    db: Session = Depends(get_db),
):
    return FreightQuotationService.list_rfqs(
        db,
        include_inactive=include_inactive,
        search=search,
        shipping_method=shipping_method,
        import_file_id=import_file_id,
        po_id=po_id,
        project_id=project_id,
        status=status,
    )


@router.get(
    "/{rfq_id}",
    response_model=FreightRFQRequestResponse,
    summary="Get Freight RFQ request by ID",
)
def get_rfq(
    rfq_id: int,
    db: Session = Depends(get_db),
):
    return FreightQuotationService.get_rfq(db, rfq_id)


@router.put(
    "/{rfq_id}",
    response_model=FreightRFQRequestResponse,
    summary="Update Freight RFQ request",
)
def update_rfq(
    rfq_id: int,
    update_in: FreightRFQRequestUpdate,
    db: Session = Depends(get_db),
):
    return FreightQuotationService.update_rfq(db, rfq_id, update_in)


@router.post(
    "/{rfq_id}/award/{quotation_id}",
    response_model=FreightRFQRequestResponse,
    summary="Award RFQ to winning carrier quotation",
)
def award_quotation(
    rfq_id: int,
    quotation_id: int,
    db: Session = Depends(get_db),
):
    return FreightQuotationService.award_quotation(db, rfq_id, quotation_id)


@router.delete(
    "/{rfq_id}",
    response_model=FreightRFQRequestResponse,
    summary="Soft delete Freight RFQ request",
)
def soft_delete_rfq(
    rfq_id: int,
    db: Session = Depends(get_db),
):
    return FreightQuotationService.soft_delete_rfq(db, rfq_id)


@router.post(
    "/{rfq_id}/restore",
    response_model=FreightRFQRequestResponse,
    summary="Restore soft-deleted Freight RFQ request",
)
def restore_rfq(
    rfq_id: int,
    db: Session = Depends(get_db),
):
    return FreightQuotationService.restore_rfq(db, rfq_id)


@router.get(
    "/{rfq_id}/benchmark",
    response_model=RFQBenchmarkResponse,
    summary="مقارنة ومفاضلة وترتيب أفضل 3 عروض شحن للمسار (Trade-Lane Forwarder Benchmarking)",
)
def benchmark_rfq_quotes(
    rfq_id: int,
    db: Session = Depends(get_db),
):
    return FreightQuotationService.evaluate_and_rank_rfq_quotes(db, rfq_id)

