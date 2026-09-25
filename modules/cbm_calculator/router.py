from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.cbm_calculator.schemas import (
    CBMCalculationCreate,
    CBMCalculationResponse,
    CBMCalculationUpdate,
    CBMQuickCalcRequest,
    CBMQuickCalcResponse,
    CloneCBMCalculationRequest,
    LinkToPORequest,
)
from modules.cbm_calculator.service import CBMService

router = APIRouter(prefix="/api/v1/cbm-calculator", tags=["Cargo Measurement Engine & CBM Calculator"], dependencies=[Depends(get_current_user)])


@router.post("/quick-calculate", response_model=CBMQuickCalcResponse, status_code=status.HTTP_200_OK)
def quick_calculate_cbm(payload: CBMQuickCalcRequest):
    """
    Perform instant standalone calculation without persisting to database.
    """
    return CBMService.quick_calculate(payload)


@router.post("", response_model=CBMCalculationResponse, status_code=status.HTTP_201_CREATED)
def create_cbm_calculation(
    payload: CBMCalculationCreate, db: Session = Depends(get_db)
):
    """
    Create and save a new CBM calculation session (Standalone or linked to PO/Project).
    """
    return CBMService.create_calculation_service(db, payload)


@router.get("", response_model=List[CBMCalculationResponse])
def list_cbm_calculations(
    include_inactive: bool = Query(False, description="Include soft-deleted calculations"),
    import_file_id: Optional[int] = Query(None, description="Filter by Import File ID"),
    project_id: Optional[int] = Query(None, description="Filter by Project ID"),
    po_id: Optional[int] = Query(None, description="Filter by Purchase Order ID"),
    search: Optional[str] = Query(None, description="Search term for code, title, or notes"),
    db: Session = Depends(get_db),
):
    """
    Retrieve stored CBM calculation history logs with optional search & filters.
    """
    return CBMService.list_calculations_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        project_id=project_id,
        po_id=po_id,
        search=search,
    )


@router.get("/{calc_id}", response_model=CBMCalculationResponse)
def get_cbm_calculation(calc_id: int, db: Session = Depends(get_db)):
    """
    Get detailed information and items for a specific calculation session.
    """
    return CBMService.get_calculation_service(db, calc_id)


@router.put("/{calc_id}", response_model=CBMCalculationResponse)
def update_cbm_calculation(
    calc_id: int, payload: CBMCalculationUpdate, db: Session = Depends(get_db)
):
    """
    Update items, dimensions, or title/notes of a saved calculation session.
    """
    return CBMService.update_calculation_service(db, calc_id, payload)


@router.post("/{calc_id}/link", response_model=CBMCalculationResponse)
def link_calculation_to_po(
    calc_id: int, payload: LinkToPORequest, db: Session = Depends(get_db)
):
    """
    Link or assign a saved calculation record to a Purchase Order or Project.
    """
    return CBMService.link_to_po_service(
        db, calc_id, po_id=payload.po_id, project_id=payload.project_id
    )


@router.delete("/{calc_id}", status_code=status.HTTP_200_OK)
def soft_delete_cbm_calculation(calc_id: int, db: Session = Depends(get_db)):
    """
    Soft delete a CBM calculation record.
    """
    return CBMService.soft_delete_service(db, calc_id)


@router.post("/{calc_id}/restore", response_model=CBMCalculationResponse)
def restore_cbm_calculation(calc_id: int, db: Session = Depends(get_db)):
    """
    Restore a soft-deleted CBM calculation record.
    """
    return CBMService.restore_service(db, calc_id)


@router.post("/{calc_id}/clone", response_model=CBMCalculationResponse, status_code=status.HTTP_201_CREATED)
def clone_cbm_calculation(
    calc_id: int, payload: CloneCBMCalculationRequest, db: Session = Depends(get_db)
):
    """
    Clone a CBM calculation session into a new draft with independent code, resetting linkages.
    """
    return CBMService.clone_cbm_calculation(db, calc_id, payload)

