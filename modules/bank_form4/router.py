from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.bank_form4.schemas import (
    BankForm4Create,
    BankForm4Update,
    BankForm4Response,
    BankForm4ListResponse,
    DelayCostCalculation,
    NafezaTransmissionUpdate,
)
from modules.bank_form4.service import BankForm4Service
from modules.users.model import User

router = APIRouter(
    prefix="/api/v1/bank-form4",
    tags=["Bank Form 4 Tracking"],
    dependencies=[Depends(get_current_user)],
)


@router.post(
    "",
    response_model=BankForm4Response,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Bank Form 4 record",
)
def create_bank_form4(
    payload: BankForm4Create,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    record = service.create_record(payload, current_user=current_user.username)
    return BankForm4Response.model_validate(record)


@router.get(
    "",
    response_model=BankForm4ListResponse,
    summary="List Bank Form 4 records with filtering and pagination",
)
def list_bank_form4_records(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    import_file_id: Optional[int] = Query(None),
    nafeza_status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    items, total = service.list_records(
        skip=skip,
        limit=limit,
        import_file_id=import_file_id,
        nafeza_status=nafeza_status,
        search=search,
    )
    return BankForm4ListResponse(
        total=total,
        items=[BankForm4Response.model_validate(item) for item in items],
    )


@router.get(
    "/by-file/{import_file_id}",
    response_model=List[BankForm4Response],
    summary="Get Bank Form 4 records by Import File ID",
)
def get_bank_form4_by_file(
    import_file_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    items = service.get_records_by_file(import_file_id)
    return [BankForm4Response.model_validate(item) for item in items]


@router.get(
    "/by-number/{form4_number}",
    response_model=BankForm4Response,
    summary="Get Bank Form 4 record by official Form 4 number",
)
def get_bank_form4_by_number(
    form4_number: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    record = service.get_record_by_form4_number(form4_number)
    return BankForm4Response.model_validate(record)


@router.get(
    "/{form4_id}",
    response_model=BankForm4Response,
    summary="Get single Bank Form 4 record details",
)
def get_bank_form4(
    form4_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    record = service.get_record(form4_id)
    return BankForm4Response.model_validate(record)


@router.put(
    "/{form4_id}",
    response_model=BankForm4Response,
    summary="Update Bank Form 4 record details",
)
def update_bank_form4(
    form4_id: int,
    payload: BankForm4Update,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    record = service.update_record(form4_id, payload, current_user=current_user.username)
    return BankForm4Response.model_validate(record)


@router.post(
    "/{form4_id}/calculate-delay-cost",
    response_model=BankForm4Response,
    summary="Calculate and update financing delay costs",
)
def calculate_delay_cost(
    form4_id: int,
    payload: DelayCostCalculation,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    record = service.calculate_delay_costs(form4_id, payload, current_user=current_user.username)
    return BankForm4Response.model_validate(record)


@router.post(
    "/{form4_id}/nafeza-transmission",
    response_model=BankForm4Response,
    summary="Update Nafeza transmission state (AWAITING_BANK, TRANSMITTED, VALUE_MISMATCH, ACCEPTED)",
)
def update_nafeza_transmission(
    form4_id: int,
    payload: NafezaTransmissionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    record = service.update_nafeza_transmission(form4_id, payload, current_user=current_user.username)
    return BankForm4Response.model_validate(record)


@router.delete(
    "/{form4_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete Bank Form 4 record",
)
def delete_bank_form4(
    form4_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    service = BankForm4Service(db)
    service.delete_record(form4_id, current_user=current_user.username)
    return None
