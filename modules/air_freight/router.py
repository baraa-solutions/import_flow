"""FastAPI routes of the air freight suite (AWB records, chargeable weight, draft AWB review)."""
from typing import List, Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.permissions import require_permission
from modules.users.model import User

from . import service, validators
from .model import AirShipmentRecord
from .schemas import (
    AirShipmentRecordCreate,
    AirShipmentRecordResponse,
    AirShipmentRecordUpdate,
    AwbNumberCheck,
    ChargeableWeightRequest,
    ChargeableWeightResult,
    DraftAwbReviewCreate,
    DraftAwbReviewDecision,
    DraftAwbReviewResponse,
)

router = APIRouter(prefix="/api/v1/air-freight", tags=["Air Freight & AWB"])

# Air freight is part of multimodal freight operations: same permissions (no new RBAC seed needed).
can_view = require_permission("multimodal_freight.view")
can_manage = require_permission("multimodal_freight.manage")


def _out(db: Session, record: AirShipmentRecord) -> AirShipmentRecordResponse:
    out = AirShipmentRecordResponse.model_validate(record)
    out.storage = service.storage_status_of(db, record)
    return out


@router.post("/chargeable-weight", response_model=ChargeableWeightResult)
def calculate_chargeable_weight(
    payload: ChargeableWeightRequest, db: Session = Depends(get_db), _: User = Depends(can_view)
):
    return service.calculate_chargeable_weight(db, payload)


@router.get("/awb-check", response_model=AwbNumberCheck)
def check_awb_number(awb_number: str = Query(..., min_length=1), _: User = Depends(can_view)):
    digits, prefix, error = validators.parse_awb_number(awb_number)
    return AwbNumberCheck(
        awb_number=awb_number, is_valid=error is None and digits is not None,
        normalized=validators.format_awb_number(digits), airline_prefix=prefix, reason_code=error,
    )


@router.get("/records", response_model=List[AirShipmentRecordResponse])
def list_air_records(
    import_file_id: Optional[int] = Query(None),
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
    _: User = Depends(can_view),
):
    return [_out(db, r) for r in service.list_air_records(db, import_file_id, include_inactive)]


@router.get("/records/{air_record_id}", response_model=AirShipmentRecordResponse)
def get_air_record(air_record_id: int, db: Session = Depends(get_db), _: User = Depends(can_view)):
    return _out(db, service.get_air_record(db, air_record_id))


@router.post("/records", response_model=AirShipmentRecordResponse, status_code=status.HTTP_201_CREATED)
def create_air_record(
    payload: AirShipmentRecordCreate, db: Session = Depends(get_db), current_user: User = Depends(can_manage)
):
    return _out(db, service.create_air_record(db, payload, current_user.username))


@router.put("/records/{air_record_id}", response_model=AirShipmentRecordResponse)
def update_air_record(
    air_record_id: int,
    payload: AirShipmentRecordUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    return _out(db, service.update_air_record(db, air_record_id, payload, current_user.username))


@router.delete("/records/{air_record_id}", response_model=AirShipmentRecordResponse)
def delete_air_record(air_record_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_manage)):
    return _out(db, service.soft_delete_air_record(db, air_record_id, current_user.username))


@router.post("/records/{air_record_id}/restore", response_model=AirShipmentRecordResponse)
def restore_air_record(air_record_id: int, db: Session = Depends(get_db), current_user: User = Depends(can_manage)):
    return _out(db, service.restore_air_record(db, air_record_id, current_user.username))


@router.get("/records/{air_record_id}/reviews", response_model=List[DraftAwbReviewResponse])
def list_reviews(air_record_id: int, db: Session = Depends(get_db), _: User = Depends(can_view)):
    return service.list_reviews(db, air_record_id)


@router.post("/reviews", response_model=DraftAwbReviewResponse, status_code=status.HTTP_201_CREATED)
def create_review(payload: DraftAwbReviewCreate, db: Session = Depends(get_db), current_user: User = Depends(can_manage)):
    return service.create_review(db, payload, current_user.username)


@router.post("/reviews/{awb_review_id}/decision", response_model=DraftAwbReviewResponse)
def decide_review(
    awb_review_id: int,
    payload: DraftAwbReviewDecision,
    db: Session = Depends(get_db),
    current_user: User = Depends(can_manage),
):
    return service.decide_review(db, awb_review_id, payload, current_user.username)
