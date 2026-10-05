from typing import List, Optional

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from modules.import_requirements import service
from modules.import_requirements.schemas import (
    ImportRequirementCreate,
    ImportRequirementPrefillResponse,
    ImportRequirementResponse,
    ImportRequirementUpdate,
)
from modules.users.model import User

VIEW = "import_files.view"
MANAGE = "import_requirements.manage"

router = APIRouter(
    prefix="/api/v1/import-requirements",
    tags=["Import Requirements Assessment (BP-011)"],
    dependencies=[Depends(get_current_user)],
)


@router.get("/prefill/{import_file_id}", response_model=ImportRequirementPrefillResponse,
    summary="Auto-extract all requirement and compliance prefill data from Import File and Customs Consultation")
def get_file_prefill(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return service.get_import_file_prefill_service(db, import_file_id)


@router.post("", response_model=ImportRequirementResponse, status_code=status.HTTP_201_CREATED,
    summary="Create a new Import Requirements Assessment (BP-011)")
def create_assessment(
    payload: ImportRequirementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return service.create_assessment_service(db, payload, user=current_user.username)


@router.get("", response_model=List[ImportRequirementResponse],
    summary="List all Import Requirements Assessments")
def list_assessments(
    import_file_id: Optional[int] = None,
    overall_status: Optional[str] = None,
    risk_level: Optional[str] = None,
    search: Optional[str] = None,
    include_inactive: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return service.get_all_assessments_service(
        db, import_file_id=import_file_id, overall_status=overall_status,
        risk_level=risk_level, search=search, include_inactive=include_inactive
    )


@router.get("/{assessment_id}", response_model=ImportRequirementResponse,
    summary="Get a single Import Requirements Assessment by ID")
def get_assessment(
    assessment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return service.get_assessment_by_id_service(db, assessment_id)


@router.put("/{assessment_id}", response_model=ImportRequirementResponse,
    summary="Update an Import Requirements Assessment")
def update_assessment(
    assessment_id: int,
    payload: ImportRequirementUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return service.update_assessment_service(db, assessment_id, payload, user=current_user.username)


@router.post("/{assessment_id}/restore", response_model=ImportRequirementResponse,
    summary="Restore a soft-deleted Import Requirements Assessment")
def restore_assessment(
    assessment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return service.restore_assessment_service(db, assessment_id, user=current_user.username)


@router.delete("/{assessment_id}", status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft-delete an Import Requirements Assessment")
def delete_assessment(
    assessment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    service.soft_delete_assessment_service(db, assessment_id, user=current_user.username)
