"""
API Router for System Parameters (BEX-T17).
"""
from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.auth.router import require_admin
from modules.users.model import User
from .schemas import SystemParameterResponse, SystemParameterUpdate
from .service import SystemParametersService

router = APIRouter(prefix="/api/v1/system-parameters", tags=["System Parameters & Business Settings"])


@router.get("", response_model=List[SystemParameterResponse])
def get_all_system_parameters(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports.view")),
):
    """Retrieve all configurable business parameters. Requires 'reports.view' permission."""
    service = SystemParametersService(db)
    return service.get_all_parameters()


@router.put("/{key}", response_model=SystemParameterResponse)
def update_system_parameter(
    key: str,
    payload: SystemParameterUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Update a system parameter value with typed validation and audit trail. Requires Admin role."""
    service = SystemParametersService(db)
    return service.update_parameter(key, payload, actor_username=current_user.username)
