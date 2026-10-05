from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User
from sqlalchemy.orm import Session
from database.database import get_db

from .schemas import (
    DemurragePolicyCreate,
    DemurragePolicyUpdate,
    DemurragePolicyResponse,
    DemurrageTrackingCreate,
    DemurrageTrackingUpdate,
    DemurrageTrackingResponse,
    DemurrageSimulationRequest,
    DemurrageSimulationResponse,
    PushToSettlementRequest,
    DualClockResponse,
    ContainerIndividualUpdate,
    FreeDaysAgreementRegister,
    FreeDaysAgreementResponse,
    ContainerRadarOverviewResponse,
    EmptyContainerReturnSubmit,
    EmptyContainerReturnResponse,
)
from .service import (
    simulate_with_defaults,
    create_demurrage_policy_service,
    get_demurrage_policies_service,
    get_demurrage_policy_by_id_service,
    update_demurrage_policy_service,
    delete_demurrage_policy_service,
    create_demurrage_tracking_service,
    get_demurrage_trackings_service,
    get_demurrage_tracking_by_id_service,
    recalculate_and_update_tracking_service,
    push_demurrage_to_financial_settlement_service,
    get_dual_clock_status_service,
    update_single_container_service,
    register_free_days_agreement_service,
    get_free_days_agreement_service,
    get_containers_radar_overview_service,
    record_empty_container_return_service,
)

router = APIRouter(prefix="/api/v1/demurrage-detention", tags=["Demurrage & Detention Engine"], dependencies=[Depends(get_current_user)])


# ----------------------------------------------------
# Interactive Simulator Endpoint
# ----------------------------------------------------

@router.post("/simulate", response_model=DemurrageSimulationResponse, summary="محاكي حساب غرامات وفترات سماح الحاويات والأرضيات")
def simulate_demurrage_endpoint(req: DemurrageSimulationRequest, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.view"))):
    return simulate_with_defaults(db, req)


# ----------------------------------------------------
# Carrier Tariff Policies Endpoints
# ----------------------------------------------------

@router.post("/policies", response_model=DemurragePolicyResponse, status_code=status.HTTP_201_CREATED, summary="إنشاء سياسة تعريفة غرامات لخط ملاحي")
def create_policy_endpoint(req: DemurragePolicyCreate, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.manage"))):
    return create_demurrage_policy_service(db, req, user=current_user.username)


@router.get("/policies", response_model=List[DemurragePolicyResponse], summary="استعراض سياسات غرامات الخطوط الملاحية")
def get_policies_endpoint(
    carrier_name: Optional[str] = Query(None, description="تصفية باسم الخط الملاحي"),
    container_type: Optional[str] = Query(None, description="تصفية بنوع الحاوية"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("demurrage_detention.view")),
):
    return get_demurrage_policies_service(db, carrier_name=carrier_name, container_type=container_type)


@router.get("/policies/{policy_id}", response_model=DemurragePolicyResponse, summary="جلب تفاصيل سياسة غرامات محددة")
def get_policy_by_id_endpoint(policy_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.view"))):
    return get_demurrage_policy_by_id_service(db, policy_id)


@router.put("/policies/{policy_id}", response_model=DemurragePolicyResponse, summary="تعديل سياسة غرامات خط ملاحي")
def update_policy_endpoint(policy_id: int, req: DemurragePolicyUpdate, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.manage"))):
    return update_demurrage_policy_service(db, policy_id, req, user=current_user.username)


@router.delete("/policies/{policy_id}", response_model=DemurragePolicyResponse, summary="حذف سياسة غرامات (Soft Delete)")
def delete_policy_endpoint(policy_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.manage"))):
    return delete_demurrage_policy_service(db, policy_id, user=current_user.username)


# ----------------------------------------------------
# Container Tracking Sessions Endpoints
# ----------------------------------------------------

@router.post("/trackings", response_model=DemurrageTrackingResponse, status_code=status.HTTP_201_CREATED, summary="إنشاء جلسة تتبع حاويات وحساب غرامات")
def create_tracking_endpoint(req: DemurrageTrackingCreate, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.manage"))):
    return create_demurrage_tracking_service(db, req, user=current_user.username)


@router.get("/trackings", response_model=List[DemurrageTrackingResponse], summary="استعراض جلسات تتبع الحاويات")
def get_trackings_endpoint(
    import_file_id: Optional[int] = Query(None, description="تصفية برقم ملف الاستيراد"),
    carrier_name: Optional[str] = Query(None, description="تصفية باسم الخط الملاحي"),
    status: Optional[str] = Query(None, description="تصفية بالحالة"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("demurrage_detention.view")),
):
    return get_demurrage_trackings_service(db, import_file_id=import_file_id, carrier_name=carrier_name, status_filter=status)


@router.get("/trackings/{tracking_id}", response_model=DemurrageTrackingResponse, summary="جلب تفاصيل جلسة تتبع حاويات")
def get_tracking_by_id_endpoint(tracking_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.view"))):
    return get_demurrage_tracking_by_id_service(db, tracking_id)


@router.put("/trackings/{tracking_id}", response_model=DemurrageTrackingResponse, summary="تحديث وإعادة حساب جلسة تتبع حاويات")
def update_tracking_endpoint(tracking_id: int, req: DemurrageTrackingUpdate, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.manage"))):
    return recalculate_and_update_tracking_service(db, tracking_id, req, user=current_user.username)


@router.post("/trackings/push-to-settlement", summary="ترحيل الغرامات تلقائياً إلى فواتير التسوية المالية Landed Cost")
def push_to_settlement_endpoint(req: PushToSettlementRequest, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.manage"))):
    return push_demurrage_to_financial_settlement_service(db, req, user=current_user.username, actor=current_user)


@router.get(
    "/trackings/{tracking_id}/dual-clock",
    response_model=DualClockResponse,
    summary="جلب رادار العداد المزدوج المتزامن (غرامات الخط الملاحي USD مقابل أرضيات ساحة الميناء EGP)",
)
def get_dual_clock_endpoint(tracking_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.view"))):
    return get_dual_clock_status_service(db, tracking_id)


@router.patch(
    "/trackings/{tracking_id}/containers/{container_no}",
    response_model=DemurrageTrackingResponse,
    summary="تحديث حاوية مفردة داخل الشحنة (خروج بوابة / إرجاع فارغ EIR / سيل ملاحي)",
)
def update_single_container_endpoint(
    tracking_id: int,
    container_no: str,
    req: ContainerIndividualUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("demurrage_detention.manage")),
):
    return update_single_container_service(db, tracking_id, container_no, req, user=current_user.username)


# ----------------------------------------------------
# Free Days Agreement Endpoints (BK-02)
# ----------------------------------------------------

@router.post("/free-days-agreement", response_model=FreeDaysAgreementResponse, status_code=status.HTTP_201_CREATED, summary="تسجيل وتوثيق اتفاقية فترات السماح الممنوحة للحاويات (BK-02)")
def register_free_days_agreement_endpoint(req: FreeDaysAgreementRegister, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.manage"))):
    return register_free_days_agreement_service(db, req, user=current_user.username)


@router.get("/free-days-agreement/{import_file_id}", response_model=FreeDaysAgreementResponse, summary="جلب بيانات اتفاقية فترات السماح المعتمدة لملف استيراد")
def get_free_days_agreement_endpoint(import_file_id: int, db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.view"))):
    return get_free_days_agreement_service(db, import_file_id)


# ----------------------------------------------------
# TR-02: Demurrage & Detention Radar Overview Endpoint
# ----------------------------------------------------

@router.get(
    "/radar-overview",
    response_model=ContainerRadarOverviewResponse,
    summary="رادار مراقبة فترات السماح وتفادي غرامات الحاويات والأرضيات (TR-02)",
)
def get_radar_overview_endpoint(db: Session = Depends(get_db), current_user: User = Depends(require_permission("demurrage_detention.view"))):
    return get_containers_radar_overview_service(db)


# ----------------------------------------------------
# TR-05: Empty Container Return (EIR) Endpoint
# ----------------------------------------------------

@router.post(
    "/empty-container-return",
    response_model=EmptyContainerReturnResponse,
    status_code=status.HTTP_201_CREATED,
    summary="تسجيل إرجاع الحاويات الفارغة للخط الملاحي وإيصال EIR وإيقاف الغرامات (TR-05)",
)
def record_empty_container_return_endpoint(
    req: EmptyContainerReturnSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("demurrage_detention.manage")),
):
    return record_empty_container_return_service(db, req, user=current_user.username)


