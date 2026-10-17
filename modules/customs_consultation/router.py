"""
Customs Consultation & Broker Price Lists REST Router (BP-009)
"""

from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from sqlalchemy.orm import Session
from database.database import get_db
from modules.auth.permissions import require_permission
from modules.users.model import User
from modules.customs_consultation.schemas import (
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeUpdate,
    ClearanceExpenseTypeResponse,
    BrokerPriceListCreate,
    BrokerPriceListUpdate,
    BrokerPriceListResponse,
    CustomsConsultationCreate,
    CustomsConsultationUpdate,
    CustomsConsultationResponse,
    CustomsRecalculationRequest,
    CustomsRecalculationResponse,
    CloneBrokerPriceListRequest,
    CloneConsultationRequest,
)
from modules.customs_consultation.service import (
    ClearanceExpenseTypeService,
    BrokerPriceListService,
    CustomsConsultationService,
)

VIEW = "customs_clearance.view"
MANAGE = "customs_consultation.manage"
MASTER_VIEW = "master_data.view"
MASTER_EDIT = "master_data.edit"

router = APIRouter(
    prefix="/api/v1/customs-consultations",
    tags=["Customs Consultation & Broker Price Lists (BP-009)"],
    dependencies=[Depends(get_current_user)],
)


# ==============================================================================
# Customs Re-estimation & Variance Comparison (إعادة احتساب الجمارك ومقارنة الفروق)
# ==============================================================================

@router.post(
    "/recalculate-from-reconciliation",
    response_model=CustomsRecalculationResponse,
    summary="Recalculate customs duties based on final reconciled invoice and compare variances",
)
def recalculate_from_reconciliation(
    payload: CustomsRecalculationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return CustomsConsultationService.recalculate_from_reconciliation_service(
        db,
        import_file_id=payload.import_file_id,
        exchange_rate=payload.exchange_rate,
        preliminary_exchange_rate=payload.preliminary_exchange_rate,
        freight_egp=payload.freight_egp,
        insurance_egp=payload.insurance_egp,
        estimate_date=payload.estimate_date,
    )



# ==============================================================================
# Clearance Expense Types Endpoints (تكويد أنواع المصروفات)
# ==============================================================================

@router.get(
    "/expense-types",
    response_model=List[ClearanceExpenseTypeResponse],
    summary="List all Clearance & Logistics Expense Types",
)
def list_expense_types(
    include_inactive: bool = Query(False, description="Include inactive expense types"),
    category: Optional[str] = Query(None, description="Filter by category"),
    search: Optional[str] = Query(None, description="Search by code or name"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MASTER_VIEW)),
):
    return ClearanceExpenseTypeService.list_expense_types(
        db, include_inactive=include_inactive, category=category, search=search
    )


@router.post(
    "/expense-types",
    response_model=ClearanceExpenseTypeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Expense Type in the catalog",
)
def create_expense_type(
    schema: ClearanceExpenseTypeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MASTER_EDIT)),
):
    return ClearanceExpenseTypeService.create_expense_type(db, schema, user=current_user.username)


@router.get(
    "/expense-types/{expense_id}",
    response_model=ClearanceExpenseTypeResponse,
    summary="Get Expense Type by ID",
)
def get_expense_type(
    expense_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MASTER_VIEW)),
):
    return ClearanceExpenseTypeService.get_expense_type(db, expense_id)


@router.put(
    "/expense-types/{expense_id}",
    response_model=ClearanceExpenseTypeResponse,
    summary="Update Expense Type",
)
def update_expense_type(
    expense_id: int,
    schema: ClearanceExpenseTypeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MASTER_EDIT)),
):
    return ClearanceExpenseTypeService.update_expense_type(db, expense_id, schema, user=current_user.username)


@router.delete(
    "/expense-types/{expense_id}",
    response_model=ClearanceExpenseTypeResponse,
    summary="Deactivate / Delete Expense Type",
)
def delete_expense_type(
    expense_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MASTER_EDIT)),
):
    return ClearanceExpenseTypeService.delete_expense_type(db, expense_id, user=current_user.username)


# ==============================================================================
# Broker Price Lists Endpoints (قوائم أسعار المخلصين)
# ==============================================================================

@router.get(
    "/price-lists",
    response_model=List[BrokerPriceListResponse],
    summary="List all Broker Price Lists / Tariffs",
)
def list_price_lists(
    include_inactive: bool = Query(False, description="Include inactive price lists"),
    broker_id: Optional[int] = Query(None, description="Filter by Broker ID"),
    search: Optional[str] = Query(None, description="Search by code, title, broker name"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return BrokerPriceListService.list_price_lists(
        db, include_inactive=include_inactive, broker_id=broker_id, search=search
    )


@router.get(
    "/price-lists/active/{broker_id}",
    response_model=Optional[BrokerPriceListResponse],
    summary="Get current active Price List for a Broker by target date",
)
def get_active_price_list_for_broker(
    broker_id: int,
    target_date: Optional[date] = Query(None, description="Target date (defaults to today)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return BrokerPriceListService.get_active_price_list_for_broker(db, broker_id, target_date)


@router.post(
    "/price-lists",
    response_model=BrokerPriceListResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Broker Price List / Tariff",
)
def create_price_list(
    schema: BrokerPriceListCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return BrokerPriceListService.create_price_list(db, schema, user=current_user.username)


@router.get(
    "/price-lists/{price_list_id}",
    response_model=BrokerPriceListResponse,
    summary="Get Broker Price List by ID",
)
def get_price_list(
    price_list_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return BrokerPriceListService.get_price_list(db, price_list_id)


@router.put(
    "/price-lists/{price_list_id}",
    response_model=BrokerPriceListResponse,
    summary="Update Broker Price List",
)
def update_price_list(
    price_list_id: int,
    schema: BrokerPriceListUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return BrokerPriceListService.update_price_list(db, price_list_id, schema, user=current_user.username)


@router.delete(
    "/price-lists/{price_list_id}",
    response_model=BrokerPriceListResponse,
    summary="Soft delete Broker Price List",
)
def delete_price_list(
    price_list_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return BrokerPriceListService.soft_delete_price_list(db, price_list_id, user=current_user.username)


@router.post(
    "/price-lists/{price_list_id}/clone",
    response_model=BrokerPriceListResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Clone a Broker Price List (Universal Clone Engine UX-CLONE-011)",
)
def clone_price_list(
    price_list_id: int,
    payload: CloneBrokerPriceListRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return BrokerPriceListService.clone_price_list(db, price_list_id, payload, user=current_user.username)



# ==============================================================================
# Consultation Sessions Endpoints (دراسات الاستشارة والفحص الجمركي)
# ==============================================================================

@router.post(
    "",
    response_model=CustomsConsultationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Customs Consultation study session (BP-009)",
)
def create_consultation(
    session_in: CustomsConsultationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return CustomsConsultationService.create_consultation(db, session_in, modified_by=current_user.username)


@router.get(
    "",
    response_model=List[CustomsConsultationResponse],
    summary="List all Customs Consultation studies with filtering (BP-009)",
)
def list_consultations(
    include_inactive: bool = Query(False, description="Include soft-deleted studies"),
    search: Optional[str] = Query(None, description="Search by code, title, or broker name"),
    broker_id: Optional[int] = Query(None, description="Filter by Customs Broker ID"),
    import_file_id: Optional[int] = Query(None, description="Filter by Import File ID"),
    po_id: Optional[int] = Query(None, description="Filter by Purchase Order ID"),
    project_id: Optional[int] = Query(None, description="Filter by Project ID"),
    status: Optional[str] = Query(None, description="Filter by overall status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return CustomsConsultationService.list_consultations(
        db,
        include_inactive=include_inactive,
        search=search,
        broker_id=broker_id,
        import_file_id=import_file_id,
        po_id=po_id,
        project_id=project_id,
        status=status,
    )


@router.get(
    "/{consultation_id}",
    response_model=CustomsConsultationResponse,
    summary="Get Customs Consultation study by ID",
)
def get_consultation(
    consultation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(VIEW)),
):
    return CustomsConsultationService.get_consultation(db, consultation_id)


@router.put(
    "/{consultation_id}",
    response_model=CustomsConsultationResponse,
    summary="Update Customs Consultation study",
)
def update_consultation(
    consultation_id: int,
    update_in: CustomsConsultationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return CustomsConsultationService.update_consultation(
        db, consultation_id, update_in, modified_by=current_user.username
    )


@router.delete(
    "/{consultation_id}",
    response_model=CustomsConsultationResponse,
    summary="Soft delete Customs Consultation study",
)
def soft_delete_consultation(
    consultation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return CustomsConsultationService.soft_delete_consultation(db, consultation_id, modified_by=current_user.username)


@router.post(
    "/{consultation_id}/restore",
    response_model=CustomsConsultationResponse,
    summary="Restore soft-deleted Customs Consultation study",
)
def restore_consultation(
    consultation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return CustomsConsultationService.restore_consultation(db, consultation_id, modified_by=current_user.username)


@router.post(
    "/{consultation_id}/clone",
    response_model=CustomsConsultationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Clone a Customs Consultation study (Universal Clone Engine UX-CLONE-011)",
)
def clone_consultation(
    consultation_id: int,
    payload: CloneConsultationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission(MANAGE)),
):
    return CustomsConsultationService.clone_consultation(db, consultation_id, payload, modified_by=current_user.username)

