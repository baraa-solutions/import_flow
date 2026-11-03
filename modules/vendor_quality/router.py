"""
FastAPI Router for Pre-Shipment Inspection (PSI) and Vendor Quality Rating
"""

from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.users.model import User
from modules.vendor_quality.schemas import (
    PsiCertificateUploadRequest,
    VendorHistoricalRankingOut,
    VendorQualityCreate,
    VendorQualityListOut,
    VendorQualityOut,
    VendorQualityUpdate,
)
from modules.vendor_quality.service import VendorQualityService

router = APIRouter(
    prefix="/api/v1/vendor-quality",
    tags=["Pre-Shipment Inspection (PSI) & Vendor Quality"],
)

can_view = require_permission("purchase_orders.view")
can_manage = require_permission("purchase_orders.edit")


@router.get("", response_model=VendorQualityListOut, summary="List PSI and vendor quality assessments")
def list_assessments(
    vendor_id: Optional[int] = Query(None, description="Filter by vendor"),
    purchase_order_id: Optional[int] = Query(None, description="Filter by purchase order"),
    import_file_id: Optional[int] = Query(None, description="Filter by import file"),
    inspection_agency: Optional[str] = Query(None, description="Filter by inspection agency"),
    psi_result: Optional[str] = Query(None, description="Filter by PSI result"),
    rating_grade: Optional[str] = Query(None, description="Filter by grade"),
    search: Optional[str] = Query(None, description="Search keyword"),
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    skip = (page - 1) * size
    service = VendorQualityService(db)
    items, total = service.list_assessments(
        skip=skip,
        limit=size,
        vendor_id=vendor_id,
        purchase_order_id=purchase_order_id,
        import_file_id=import_file_id,
        inspection_agency=inspection_agency,
        psi_result=psi_result,
        rating_grade=rating_grade,
        search=search,
    )
    return VendorQualityListOut(items=items, total=total, page=page, size=size)


@router.get("/rankings", response_model=VendorHistoricalRankingOut, summary="Get historical vendor ratings and ranking")
def get_historical_rankings(
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = VendorQualityService(db)
    return service.get_rankings()


@router.get("/{record_id}", response_model=VendorQualityOut, summary="Get assessment details")
def get_assessment(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = VendorQualityService(db)
    return service.get_by_id(record_id)


@router.post("", response_model=VendorQualityOut, status_code=status.HTTP_201_CREATED, summary="Create vendor quality assessment")
def create_assessment(
    data: VendorQualityCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = VendorQualityService(db)
    return service.create_assessment(data, current_user_id=current_user.user_id)


@router.put("/{record_id}", response_model=VendorQualityOut, summary="Update vendor assessment")
def update_assessment(
    record_id: int,
    data: VendorQualityUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = VendorQualityService(db)
    return service.update_assessment(record_id, data, current_user_id=current_user.user_id)


@router.post("/{record_id}/upload-psi", response_model=VendorQualityOut, summary="Upload pre-shipment inspection certificate")
def upload_psi_certificate(
    record_id: int,
    req: PsiCertificateUploadRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = VendorQualityService(db)
    return service.upload_psi_certificate(record_id, req, current_user_id=current_user.user_id)


@router.delete("/{record_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Soft delete assessment")
def delete_assessment(
    record_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = VendorQualityService(db)
    service.delete_assessment(record_id)
    return None
