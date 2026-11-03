"""
FastAPI Router for Regulatory Matrix
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.regulatory_matrix.schemas import (
    HsCodeRegulatoryCreate,
    HsCodeRegulatoryListResponse,
    HsCodeRegulatoryResponse,
    HsCodeRegulatoryUpdate,
)
from modules.regulatory_matrix.service import RegulatoryMatrixService
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/regulatory-matrix",
    tags=["Regulatory Matrix & Proactive Compliance"],
)

can_view = require_permission("regulatory_matrix.view")
can_manage = require_permission("regulatory_matrix.manage")


@router.post(
    "",
    response_model=HsCodeRegulatoryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new HS Code regulatory requirement",
)
def create_regulatory_requirement(
    payload: HsCodeRegulatoryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RegulatoryMatrixService(db)
    req = service.create_requirement(payload, current_user=current_user.username)
    return HsCodeRegulatoryResponse.model_validate(req)


@router.get(
    "",
    response_model=HsCodeRegulatoryListResponse,
    summary="List regulatory requirements with filtering",
)
def list_regulatory_requirements(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    hs_code: Optional[str] = Query(None, description="Filter by HS code prefix"),
    agency_code: Optional[str] = Query(None, description="Filter by agency code"),
    stage_timing: Optional[str] = Query(None, description="Filter by stage timing"),
    is_mandatory: Optional[bool] = Query(None, description="Filter by mandatory flag"),
    search: Optional[str] = Query(None, description="General search term"),
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = RegulatoryMatrixService(db)
    items, total = service.list_requirements(
        skip=skip,
        limit=limit,
        hs_code=hs_code,
        agency_code=agency_code,
        stage_timing=stage_timing,
        is_mandatory=is_mandatory,
        search=search,
    )
    return HsCodeRegulatoryListResponse(
        total=total,
        items=[HsCodeRegulatoryResponse.model_validate(it) for it in items],
    )


@router.get(
    "/by-hs/{hs_code}",
    response_model=List[HsCodeRegulatoryResponse],
    summary="Get all regulatory requirements for an HS Code",
)
def get_requirements_for_hs_code(
    hs_code: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = RegulatoryMatrixService(db)
    items = service.get_requirements_for_hs_code(hs_code)
    return [HsCodeRegulatoryResponse.model_validate(it) for it in items]


@router.get(
    "/{req_id}",
    response_model=HsCodeRegulatoryResponse,
    summary="Get regulatory requirement details by ID",
)
def get_regulatory_requirement(
    req_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_view),
):
    service = RegulatoryMatrixService(db)
    req = service.get_requirement(req_id)
    return HsCodeRegulatoryResponse.model_validate(req)


@router.put(
    "/{req_id}",
    response_model=HsCodeRegulatoryResponse,
    summary="Update regulatory requirement",
)
def update_regulatory_requirement(
    req_id: int,
    payload: HsCodeRegulatoryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RegulatoryMatrixService(db)
    req = service.update_requirement(req_id, payload, current_user=current_user.username)
    return HsCodeRegulatoryResponse.model_validate(req)


@router.delete(
    "/{req_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete regulatory requirement",
)
def delete_regulatory_requirement(
    req_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    service = RegulatoryMatrixService(db)
    service.delete_requirement(req_id, current_user=current_user.username)
    return None
