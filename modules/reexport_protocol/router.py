from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from database.database import get_db
from modules.auth.router import get_current_user
from modules.auth.permissions import require_permission
from modules.users.model import User

from .schemas import (
    ReexportDossierCreate,
    ReexportDossierUpdate,
    ReexportDossierResponse,
    ReexportDossierListResponse,
    OutboundBookingRequest,
    SupervisionCommitteeRequest,
    CreditNoteRequest,
    DutyDrawbackRequest,
    StatusTransitionRequest,
    DestructionAlertOverviewResponse,
)
from .service import ReexportProtocolService

router = APIRouter(
    prefix="/api/v1/reexport-protocol",
    tags=["Egyptian Customs Law 207/2020 - Re-export Protocol & Statutory Destruction"],
    dependencies=[Depends(get_current_user)],
)


@router.post(
    "",
    response_model=ReexportDossierResponse,
    status_code=status.HTTP_201_CREATED,
    summary="إنشاء ملف إعادة تصدير لبضاعة مرفوضة رقابياً طبقاً للقانون 207 لسنة 2020",
)
def create_reexport_dossier_endpoint(
    payload: ReexportDossierCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.update")),
):
    return ReexportProtocolService.create_dossier(db, payload, user=current_user.username)


@router.get(
    "/alerts/destruction-countdown",
    response_model=DestructionAlertOverviewResponse,
    summary="لوحة إنذارات مهلة الـ 30 يوماً وتنازلي الإعدام الجمركي للبضائع المرفوضة",
)
def get_destruction_countdown_alerts_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.view")),
):
    return ReexportProtocolService.get_destruction_countdown_alerts(db)


@router.get(
    "",
    response_model=ReexportDossierListResponse,
    summary="استعراض قائمة ملفات إعادة التصدير مع البحث والتصفية",
)
def list_reexport_dossiers_endpoint(
    include_inactive: bool = Query(False, description="تضمين السجلات المحذوفة"),
    import_file_id: Optional[int] = Query(None, description="تصفية برقم الملف الاستيرادي"),
    status: Optional[str] = Query(None, description="تصفية بحالة دورة إعادة التصدير"),
    search: Optional[str] = Query(None, description="بحث برقم القرار أو رقم مظهر الصادر أو البوليصة"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.view")),
):
    items, total = ReexportProtocolService.list_dossiers(
        db,
        include_inactive=include_inactive,
        import_file_id=import_file_id,
        status_filter=status,
        search=search,
        skip=skip,
        limit=limit,
    )
    return ReexportDossierListResponse(total=total, items=items)


@router.get(
    "/{reexport_id}",
    response_model=ReexportDossierResponse,
    summary="جلب تفاصيل ملف إعادة تصدير محدد",
)
def get_reexport_dossier_endpoint(
    reexport_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.view")),
):
    return ReexportProtocolService.get_dossier(db, reexport_id)


@router.put(
    "/{reexport_id}",
    response_model=ReexportDossierResponse,
    summary="تحديث بيانات ملف إعادة التصدير",
)
def update_reexport_dossier_endpoint(
    reexport_id: int,
    payload: ReexportDossierUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.update")),
):
    return ReexportProtocolService.update_dossier(db, reexport_id, payload, user=current_user.username)


@router.delete(
    "/{reexport_id}",
    response_model=ReexportDossierResponse,
    summary="حذف ناعم لملف إعادة التصدير",
)
def delete_reexport_dossier_endpoint(
    reexport_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.update")),
):
    return ReexportProtocolService.soft_delete_dossier(db, reexport_id, user=current_user.username)


@router.post(
    "/{reexport_id}/outbound-declaration",
    response_model=ReexportDossierResponse,
    summary="تسجيل حجز الشحن العكسي وتفاصيل مظهر الصادر الجمركي",
)
def record_outbound_booking_endpoint(
    reexport_id: int,
    payload: OutboundBookingRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.update")),
):
    return ReexportProtocolService.record_outbound_booking(db, reexport_id, payload, user=current_user.username)


@router.post(
    "/{reexport_id}/supervision-committee",
    response_model=ReexportDossierResponse,
    summary="تسجيل تشكيل لجنة الإشراف الجمركي ومعاينة إعادة التصدير",
)
def form_supervision_committee_endpoint(
    reexport_id: int,
    payload: SupervisionCommitteeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.update")),
):
    return ReexportProtocolService.form_supervision_committee(db, reexport_id, payload, user=current_user.username)


@router.post(
    "/{reexport_id}/credit-note",
    response_model=ReexportDossierResponse,
    summary="تسجيل ومتابعة إشعار الخصم الدائن الصادر من المورد الأجنبي (Credit Note)",
)
def record_credit_note_endpoint(
    reexport_id: int,
    payload: CreditNoteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.update")),
):
    return ReexportProtocolService.record_credit_note(db, reexport_id, payload, user=current_user.username)


@router.post(
    "/{reexport_id}/duty-drawback",
    response_model=ReexportDossierResponse,
    summary="تسجيل استرداد الرسوم الجمركية ورد الضرائب (دروباك / تسوية جمركية)",
)
def record_duty_drawback_endpoint(
    reexport_id: int,
    payload: DutyDrawbackRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.update")),
):
    return ReexportProtocolService.record_duty_drawback(db, reexport_id, payload, user=current_user.username)


@router.patch(
    "/{reexport_id}/status",
    response_model=ReexportDossierResponse,
    summary="تحديث حالة الدورة المستندية لإعادة التصدير وفق القواعد القانونية",
)
def transition_status_endpoint(
    reexport_id: int,
    payload: StatusTransitionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("customs_clearance.update")),
):
    return ReexportProtocolService.transition_status(
        db, reexport_id, payload.status.value, user=current_user.username
    )
