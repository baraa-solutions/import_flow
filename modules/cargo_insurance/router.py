from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session

from database.database import get_db
from modules.cargo_insurance.schemas import (
    InsuranceCalculationInput,
    InsuranceCalculationResult,
    CargoInsuranceCertificateCreate,
    CargoInsuranceCertificateUpdate,
    CargoInsuranceCertificateResponse,
    CargoInsuranceCertificateListResponse,
)
from modules.cargo_insurance.service import (
    CargoInsuranceService,
    calculate_cargo_insurance_engine,
)

router = APIRouter(prefix="/api/v1/cargo-insurance", tags=["Cargo & Marine Insurance"], dependencies=[Depends(get_current_user)])


@router.post(
    "/calculate",
    response_model=InsuranceCalculationResult,
    summary="Calculate Insured Value and Gross Premium",
)
def calculate_insurance(payload: InsuranceCalculationInput):
    """
    Financial engine for calculating 110% CIF Insured Value, Base Premium,
    War & Strikes Add-on, Minimum Premium thresholds, and applicable taxes.
    """
    return calculate_cargo_insurance_engine(payload)


@router.post(
    "/certificates",
    response_model=CargoInsuranceCertificateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Cargo Insurance Certificate Draft",
)
def create_certificate(
    payload: CargoInsuranceCertificateCreate,
    db: Session = Depends(get_db),
):
    service = CargoInsuranceService(db)
    return service.create_certificate(payload)


@router.get(
    "/certificates",
    response_model=CargoInsuranceCertificateListResponse,
    summary="List all Cargo Insurance Certificates with filtering and pagination",
)
def list_certificates(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    import_file_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    service = CargoInsuranceService(db)
    items, total = service.list_certificates(
        skip=skip,
        limit=limit,
        import_file_id=import_file_id,
        status=status,
        search=search,
    )
    return CargoInsuranceCertificateListResponse(
        total=total,
        items=[CargoInsuranceCertificateResponse.model_validate(item) for item in items],
    )


@router.get(
    "/certificates/{certificate_id}",
    response_model=CargoInsuranceCertificateResponse,
    summary="Get single Cargo Insurance Certificate details",
)
def get_certificate(
    certificate_id: int,
    db: Session = Depends(get_db),
):
    service = CargoInsuranceService(db)
    return service.get_certificate(certificate_id)


@router.put(
    "/certificates/{certificate_id}",
    response_model=CargoInsuranceCertificateResponse,
    summary="Update Cargo Insurance Certificate",
)
def update_certificate(
    certificate_id: int,
    payload: CargoInsuranceCertificateUpdate,
    db: Session = Depends(get_db),
):
    service = CargoInsuranceService(db)
    return service.update_certificate(certificate_id, payload)


@router.post(
    "/certificates/{certificate_id}/issue",
    response_model=CargoInsuranceCertificateResponse,
    summary="Officially Issue Cargo Insurance Certificate",
)
def issue_certificate(
    certificate_id: int,
    db: Session = Depends(get_db),
):
    service = CargoInsuranceService(db)
    return service.issue_certificate(certificate_id)


@router.delete(
    "/certificates/{certificate_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete Cargo Insurance Certificate",
)
def delete_certificate(
    certificate_id: int,
    db: Session = Depends(get_db),
):
    service = CargoInsuranceService(db)
    service.delete_certificate(certificate_id)
    return None
