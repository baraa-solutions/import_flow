"""
FastAPI Router for Smart Email Listener (INT-EMAIL-010)
"""

from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from modules.auth.router import get_current_user, require_admin
from sqlalchemy.orm import Session
from database.database import get_db

from .schemas import (
    InboundEmailCreate,
    InboundEmailParsePreviewRequest,
    ArrivalNoticeParseResult,
    InboundEmailLogResponse,
    EmailSettingsCreate,
    EmailSettingsResponse,
    EmailConnectionTestRequest,
    EmailConnectionTestResult,
    InboxFetchRequest,
    InboxFetchResult,
    OutboundEmailSendRequest,
    OutboundEmailSendResult,
    TasksBatchApprovalRequest,
    TasksBatchApprovalResult,
)
from .service import (
    process_inbound_email_service,
    preview_arrival_notice_service,
    test_email_connection_service,
    fetch_and_process_inbox_service,
    send_outbound_email_service,
    get_local_outlook_info,
    approve_and_route_tasks_service,
)
from . import repository

router = APIRouter(prefix="/api/v1/smart-email", tags=["Smart Email Listener (INT-EMAIL-010)"], dependencies=[Depends(get_current_user)])
compat_router = APIRouter(prefix="/smart-email", include_in_schema=False, dependencies=[Depends(get_current_user)])


@router.post(
    "/incoming",
    response_model=ArrivalNoticeParseResult,
    status_code=status.HTTP_201_CREATED,
    summary="استلام ومعالجة إيميل إشعار وصول واستخراج البوليصة وتوليد مهمة السداد",
)
@compat_router.post(
    "/incoming",
    response_model=ArrivalNoticeParseResult,
    status_code=status.HTTP_201_CREATED,
)
def process_incoming_email_endpoint(req: InboundEmailCreate, db: Session = Depends(get_db)):
    return process_inbound_email_service(db, req)


@router.post(
    "/parse-preview",
    response_model=ArrivalNoticeParseResult,
    summary="معاينة فورية لاستخراج بيانات إشعار الوصول بدون تسجيل في قاعدة البيانات",
)
@compat_router.post(
    "/parse-preview",
    response_model=ArrivalNoticeParseResult,
)
def preview_email_parse_endpoint(req: InboundEmailParsePreviewRequest):
    return preview_arrival_notice_service(req)


@router.get(
    "/logs",
    response_model=List[InboundEmailLogResponse],
    summary="جلب سجل الإيميلات الواردة والمعالجة",
)
@compat_router.get(
    "/logs",
    response_model=List[InboundEmailLogResponse],
)
def get_email_logs_endpoint(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    logs = repository.get_email_logs(db, limit=limit, offset=offset)
    return logs


@router.get(
    "/logs/{email_id}",
    response_model=InboundEmailLogResponse,
    summary="جلب تفاصيل إيميل وارد ومعالج محدد",
)
@compat_router.get(
    "/logs/{email_id}",
    response_model=InboundEmailLogResponse,
)
def get_email_log_detail_endpoint(email_id: int, db: Session = Depends(get_db)):
    log = repository.get_email_log_by_id(db, email_id)
    if not log:
        from fastapi import HTTPException
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="سجل الإيميل غير موجود.")
    return log


@router.get(
    "/local-outlook-status",
    summary="فحص وتحديد حالة الاتصال ببرنامج Microsoft Outlook المثبت على الجهاز",
)
@compat_router.get(
    "/local-outlook-status",
)
def get_local_outlook_status_endpoint():
    return get_local_outlook_info()


@router.get(
    "/settings",
    response_model=Optional[EmailSettingsResponse],
    summary="جلب إعدادات خادم البريد الحالية",
    dependencies=[Depends(require_admin)],
)
@compat_router.get(
    "/settings",
    response_model=Optional[EmailSettingsResponse],
    dependencies=[Depends(require_admin)],
)
def get_email_settings_endpoint(db: Session = Depends(get_db)):
    settings = repository.get_email_settings(db)
    return settings


@router.post(
    "/settings",
    response_model=EmailSettingsResponse,
    summary="حفظ أو تحديث إعدادات خادم البريد (IMAP/SMTP)",
    dependencies=[Depends(require_admin)],
)
@compat_router.post(
    "/settings",
    response_model=EmailSettingsResponse,
    dependencies=[Depends(require_admin)],
)
def save_email_settings_endpoint(req: EmailSettingsCreate, db: Session = Depends(get_db)):
    settings = repository.save_or_update_email_settings(db, req.model_dump())
    return settings


@router.post(
    "/test-connection",
    response_model=EmailConnectionTestResult,
    summary="اختبار الاتصال بخادمي IMAP و SMTP والتحقق من صحة بيانات الدخول",
    dependencies=[Depends(require_admin)],
)
@compat_router.post(
    "/test-connection",
    response_model=EmailConnectionTestResult,
    dependencies=[Depends(require_admin)],
)
def test_email_connection_endpoint(req: EmailConnectionTestRequest):
    return test_email_connection_service(req)


@router.post(
    "/fetch-inbox",
    response_model=InboxFetchResult,
    summary="مزامنة فورية وفحص صندوق الوارد (IMAP) لاستخراج إشعارات الوصول وتوليد المهام",
)
@compat_router.post(
    "/fetch-inbox",
    response_model=InboxFetchResult,
)
def fetch_inbox_endpoint(
    req: Optional[InboxFetchRequest] = None,
    db: Session = Depends(get_db),
):
    if req is None:
        req = InboxFetchRequest()
    return fetch_and_process_inbox_service(
        db,
        max_emails=req.max_emails,
        folder=req.folder,
        only_unseen=req.only_unseen,
    )


@router.post(
    "/send-email",
    response_model=OutboundEmailSendResult,
    summary="إرسال بريد إلكتروني صادر عبر خادم SMTP",
    dependencies=[Depends(require_admin)],
)
@compat_router.post(
    "/send-email",
    response_model=OutboundEmailSendResult,
    dependencies=[Depends(require_admin)],
)
def send_outbound_email_endpoint(
    req: OutboundEmailSendRequest,
    db: Session = Depends(get_db),
):
    return send_outbound_email_service(req, db)


@router.post(
    "/approve-and-route-tasks",
    response_model=TasksBatchApprovalResult,
    summary="اعتماد وتوجيه المهام الذكية المستخلصة من البريد للمستخدمين أو الفرق المحددة",
)
@compat_router.post(
    "/approve-and-route-tasks",
    response_model=TasksBatchApprovalResult,
)
def approve_and_route_tasks_endpoint(
    req: TasksBatchApprovalRequest,
    db: Session = Depends(get_db),
):
    return approve_and_route_tasks_service(db, req)

