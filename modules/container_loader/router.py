import logging
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from modules.auth.permissions import require_permission
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from .container_specs import ContainerSpec, get_container_specs_dict
from .schemas import ContainerLoaderEvaluationResult, ContainerLoaderRequest
from .service import evaluate_container_loading_service, list_container_specs_service

logger = logging.getLogger(__name__)

container_loader_router = APIRouter(prefix="/api/v1/container-loader", tags=["Container Loader"], dependencies=[Depends(get_current_user)])


@container_loader_router.post("/evaluate", response_model=ContainerLoaderEvaluationResult, dependencies=[Depends(require_permission("cbm.manage"))])
def evaluate_container_loading(request: ContainerLoaderRequest, db: Session = Depends(get_db)):
    """
    Smart 2D/3D Container Loader Recommendation Engine Endpoint.
    Evaluates cargo payload weight, volume CBM, package 3D dimensions, door opening limits,
    and 2D floor loading arrangement for stackable and non-stackable cargo.
    """
    try:
        return evaluate_container_loading_service(request, db)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error evaluating container loading: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="حدث خطأ داخلي أثناء تقييم تحميل الحاوية.")


@container_loader_router.get("/specs")
def list_container_specs(db: Session = Depends(get_db)):
    """
    Returns standard container specification metadata (20GP, 40GP, 40HC, 45HC).
    """
    specs = list_container_specs_service(db)
    return [
        {
            "code": s.code,
            "name": s.name,
            "internal_length_m": s.internal_length,
            "internal_width_m": s.internal_width,
            "internal_height_m": s.internal_height,
            "door_width_m": s.door_width,
            "door_height_m": s.door_height,
            "max_payload_kg": s.max_payload,
            "total_cbm_capacity": s.total_cbm_capacity,
            "total_floor_area_m2": s.total_floor_area,
        }
        for s in specs
    ]
