from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.shipping_scenarios.schemas import (
    ShippingEvaluationCreate,
    ShippingEvaluationResponse,
    ShippingEvaluationUpdate,
    CloneShippingEvaluationRequest,
)
from modules.shipping_scenarios.service import ShippingScenarioService

router = APIRouter(
    prefix="/api/v1/shipping-scenarios",
    tags=["Shipping Scenarios Evaluation Engine (BP-007)"],
    dependencies=[Depends(get_current_user)],
)


@router.post("", response_model=ShippingEvaluationResponse, status_code=status.HTTP_201_CREATED)
def create_shipping_evaluation(
    payload: ShippingEvaluationCreate, db: Session = Depends(get_db)
):
    """
    Create a new shipping scenarios evaluation session with carrier options.
    """
    return ShippingScenarioService.create_session_service(db, payload)


@router.get("", response_model=List[ShippingEvaluationResponse])
def list_shipping_evaluations(
    include_inactive: bool = Query(False, description="Include soft-deleted evaluation sessions"),
    import_file_id: Optional[int] = Query(None, description="Filter by Import File ID"),
    project_id: Optional[int] = Query(None, description="Filter by Project ID"),
    po_id: Optional[int] = Query(None, description="Filter by Purchase Order ID"),
    search: Optional[str] = Query(None, description="Search term for code, title, or notes"),
    db: Session = Depends(get_db),
):
    """
    Retrieve stored shipping evaluation history logs with optional search & filters.
    """
    return ShippingScenarioService.list_sessions_service(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        project_id=project_id,
        po_id=po_id,
        search=search,
    )


@router.get("/{session_id}", response_model=ShippingEvaluationResponse)
def get_shipping_evaluation(session_id: int, db: Session = Depends(get_db)):
    """
    Get detailed information and calculated metrics for a specific shipping evaluation session.
    """
    return ShippingScenarioService.get_session_service(db, session_id)


@router.put("/{session_id}", response_model=ShippingEvaluationResponse)
def update_shipping_evaluation(
    session_id: int, payload: ShippingEvaluationUpdate, db: Session = Depends(get_db)
):
    """
    Update carrier options, sailing dates, or CRD of a saved shipping evaluation session.
    """
    return ShippingScenarioService.update_session_service(db, session_id, payload)


@router.delete("/{session_id}", status_code=status.HTTP_200_OK)
def soft_delete_shipping_evaluation(session_id: int, db: Session = Depends(get_db)):
    """
    Soft delete a shipping evaluation session.
    """
    return ShippingScenarioService.soft_delete_service(db, session_id)


@router.post("/{session_id}/restore", response_model=ShippingEvaluationResponse)
def restore_shipping_evaluation(session_id: int, db: Session = Depends(get_db)):
    """
    Restore a soft-deleted shipping evaluation session.
    """
    return ShippingScenarioService.restore_service(db, session_id)


@router.post(
    "/{session_id}/clone",
    response_model=ShippingEvaluationResponse,
    status_code=status.HTTP_201_CREATED,
)
def clone_shipping_evaluation(
    session_id: int,
    payload: Optional[CloneShippingEvaluationRequest] = None,
    db: Session = Depends(get_db),
):
    """
    Clone an existing shipping evaluation study with new unique code and reset operational links.
    """
    return ShippingScenarioService.clone_session_service(db, session_id, payload)

