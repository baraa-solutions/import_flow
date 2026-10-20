from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
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
from modules.cargo_insurance.service import CargoInsuranceService

router = APIRouter(prefix="/api/v1/cargo-insurance", tags=["Cargo & Marine Insurance"], dependencies=[Depends(get_current_user)])


@router.post(
    "/calculate",
    response_model=InsuranceCalculationResult,
    summary="Calculate Insured Value and Gross Premium",
)
def calculate_insurance(
    payload: InsuranceCalculationInput,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.view")),
):
    """
    Financial engine for calculating 110% CIF Insured Value, Base Premium,
    War & Strikes Add-on, Minimum Premium thresholds, and applicable taxes.
    Rates come from the system parameters (INSURANCE_*).
    """
    return CargoInsuranceService(db).calculate_insurance(payload)


@router.post(
    "/certificates",
    response_model=CargoInsuranceCertificateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Cargo Insurance Certificate Draft",
)
def create_certificate(
    payload: CargoInsuranceCertificateCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    return CargoInsuranceService(db).create_certificate(payload, current_user=current_user.username)


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
    current_user: User = Depends(require_permission("cargo_insurance.view")),
):
    items, total = CargoInsuranceService(db).list_certificates(
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
    current_user: User = Depends(require_permission("cargo_insurance.view")),
):
    return CargoInsuranceService(db).get_certificate(certificate_id)


@router.put(
    "/certificates/{certificate_id}",
    response_model=CargoInsuranceCertificateResponse,
    summary="Update Cargo Insurance Certificate (DRAFT only; status is ignored)",
)
def update_certificate(
    certificate_id: int,
    payload: CargoInsuranceCertificateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    return CargoInsuranceService(db).update_certificate(certificate_id, payload, current_user=current_user.username)


@router.post(
    "/certificates/{certificate_id}/issue",
    response_model=CargoInsuranceCertificateResponse,
    summary="Officially Issue Cargo Insurance Certificate",
)
def issue_certificate(
    certificate_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    return CargoInsuranceService(db).issue_certificate(certificate_id, current_user=current_user.username)


@router.delete(
    "/certificates/{certificate_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete Cargo Insurance Certificate",
)
def delete_certificate(
    certificate_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    CargoInsuranceService(db).delete_certificate(certificate_id, current_user=current_user.username)
    return None


@router.patch(
    "/certificates/{certificate_id}/restore",
    response_model=CargoInsuranceCertificateResponse,
    summary="Restore soft-deleted Cargo Insurance Certificate",
)
def restore_certificate(
    certificate_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("cargo_insurance.manage")),
):
    return CargoInsuranceService(db).restore_certificate(certificate_id, current_user=current_user.username)

