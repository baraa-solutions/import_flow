from datetime import date, datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status


from .model import CustomsClearanceRecord, ClearanceExpenseInvoice
from .schemas import (
    CustomsClearanceCreate,
    CustomsClearanceUpdate,
    CustomsBrokerAuthorizationSubmit,
    DeliveryOrderPaymentSubmit,
    CustomsDeclaration46Submit,
    CustomsInspectionSamplingSubmit,
    FinalDutyAssessmentSubmit,
    CustomsDutyPaymentSubmit,
    DutyPaymentSubmit,
    CompleteReleaseSubmit,
    CustomsFinalReleaseSubmit,
    UnderBondReleaseSubmit,
    LabTestResultSubmit,
    ClearanceExpenseInvoiceCreate,
    ClearanceExpenseInvoiceUpdate,
    ClearanceExpenseInvoiceResponse,
    ClearanceInvoicesSummaryResponse,
)

from .repository import (
    generate_customs_clearance_code,
    get_customs_clearance_by_id,
    get_customs_clearance_list,
    create_customs_clearance,
    update_customs_clearance,
    soft_delete_customs_clearance,
    restore_customs_clearance,
)
from .validators import validate_bank_receipt_no, validate_release_permit
from modules.import_files.model import ImportFile
from modules.common import enum_codes

def create_customs_clearance_service(db: Session, schema: CustomsClearanceCreate) -> CustomsClearanceRecord:
    # Check import file exists
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id, ImportFile.is_active == True).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية المرتكز عليه غير موجود أو محذوف.")

    # ACID Expiry Guard: Prevent clearance with expired ACID
    from datetime import date
    if imp_file.acid_expiry_date:
        try:
            exp_date = imp_file.acid_expiry_date if isinstance(imp_file.acid_expiry_date, date) else date.fromisoformat(str(imp_file.acid_expiry_date))
            if exp_date < date.today():
                raise HTTPException(
                    status_code=400,
                    detail=f"لا يمكن فتح بيان تخليص جمركي — رقم ACID الخاص بهذا الملف منتهي الصلاحية في {exp_date}. يجب تجديد ACID أولاً."
                )
        except HTTPException:
            raise
        except Exception:
            pass  # If date parse fails, allow through

    existing = db.query(CustomsClearanceRecord).filter(
        CustomsClearanceRecord.import_file_id == schema.import_file_id,
        CustomsClearanceRecord.is_active == True,
    ).first()
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"يوجد بالفعل بيان تخليص جمركي مسجل لهذا الملف الاستيرادي (كود البيان: {existing.clearance_code}). يرجى مراجعة وتحديث البيان الحالي بدلاً من إنشاء بيان مكرر.",
        )

    code = generate_customs_clearance_code(db)
    record = create_customs_clearance(db, schema, code)

    try:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="CustomsClearanceRecord",
            entity_id=record.customs_clearance_id,
            entity_code=record.clearance_code,
            action="CREATE",
            new_data=schema.model_dump(exclude_unset=True),
            performed_by="Customs Broker",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("AuditLog for CustomsClearanceRecord create failed: %s", e)

    # Auto sync declaration 46 code if provided
    if schema.declaration_46_no:
        imp_file.form46_no = schema.declaration_46_no
        db.commit()

    # Lifecycle advance: STEP_12 → STEP_13 (Customs Declaration 46 opened)
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=schema.import_file_id,
            completed_step_code="STEP_12",
            target_step_codes=["STEP_13"],
            notes=f"تم فتح سجل التخليص الجمركي ({code}) وانتقال الملف إلى مرحلة قيد ومطابقة الإقرار الجمركي 46.",
            assigned_user="Customs Broker",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance STEP_12→STEP_13 failed: %s", e)

    return record


def authorize_customs_broker_service(
    db: Session,
    payload: CustomsBrokerAuthorizationSubmit,
    user: str = "Customs Specialist",
) -> CustomsClearanceRecord:
    """
    BP-027 / CS-01: Customs Broker Electronic Authorization Workflow.
    - Validates import file and customs broker provider.
    - Updates or creates the customs clearance record with broker delegation details.
    - Synchronizes ImportFile broker info, delegation number/date, status, sets progress to >= 80%,
      and advances next_action to 'سداد إذن التسليم الملاحي واستلام D/O (CS-02)'.
    - Auto-completes pending CS-01 SmartTasks.
    - Dispatches downstream CS-02 SmartTask (Delivery Order Payment).
    - Emits SystemNotification for all stakeholders.
    - Advances lifecycle board step: STEP_12 -> STEP_13.
    - Optionally creates formal broker mandate letter.
    """
    # 1. Validate ImportFile
    imp_file = (
        db.query(ImportFile)
        .filter(ImportFile.import_file_id == payload.import_file_id, ImportFile.is_active == True)
        .first()
    )
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ملف الشحنة الاستيرادية المطلوب غير موجود أو محذوف.",
        )

    # 2. Validate Customs Broker
    from modules.external_service_providers.model import ExternalServiceProvider
    broker = (
        db.query(ExternalServiceProvider)
        .filter(
            ExternalServiceProvider.provider_id == payload.broker_id,
            ExternalServiceProvider.is_active == True,
        )
        .first()
    )
    if not broker:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="المخلص الجمركي المختار غير مسجل أو محذوف.",
        )

    delegation_no = payload.delegation_number.strip()
    if len(delegation_no) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم التفويض الإلكتروني يجب ألا يقل عن 3 أحرف/أرقام.",
        )

    delegation_dt = payload.delegation_date or datetime.now(timezone.utc)

    # 3. Optional: Generate formal mandate letter
    mandate_letter_code = None
    if payload.generate_mandate_letter:
        try:
            from modules.formal_letters.schemas import FormalLetterGenerateRequest
            from modules.formal_letters.service import generate_formal_letter_service
            letter_req = FormalLetterGenerateRequest(
                import_file_id=payload.import_file_id,
                template_type="customs_broker_mandate",
                recipient_name=f"السيد مدير عام {payload.customs_office_name or 'جمارك الإسكندرية'}",
                broker_name=broker.partner_name,
                broker_license=broker.clearance_license_number or "رخصة معتمدة",
                custom_notes=payload.authorization_notes,
            )
            created_letter = generate_formal_letter_service(db, letter_req, user=user)
            if created_letter:
                mandate_letter_code = created_letter.letter_code
        except Exception as ex_letter:
            import logging
            logging.getLogger(__name__).warning("Formal letter generation skipped/failed: %s", ex_letter)

    # 4. Find or create CustomsClearanceRecord
    record = (
        db.query(CustomsClearanceRecord)
        .filter(
            CustomsClearanceRecord.import_file_id == payload.import_file_id,
            CustomsClearanceRecord.is_active == True,
        )
        .first()
    )
    if not record:
        clearance_code = generate_customs_clearance_code(db)
        record = CustomsClearanceRecord(
            clearance_code=clearance_code,
            import_file_id=payload.import_file_id,
            broker_id=broker.provider_id,
            broker_name=broker.partner_name,
            delegation_number=delegation_no,
            delegation_date=delegation_dt,
            delegation_status="Authorized",
            customs_office_name=payload.customs_office_name or "Alexandria Port Customs",
            authorization_notes=payload.authorization_notes,
            mandate_letter_code=mandate_letter_code,
            status="Broker Authorized - Ready for 46",
            owner=imp_file.owner or "Kamal",
            created_by=user,
            updated_by=user,
        )
        db.add(record)
    else:
        record.broker_id = broker.provider_id
        record.broker_name = broker.partner_name
        record.delegation_number = delegation_no
        record.delegation_date = delegation_dt
        record.delegation_status = "Authorized"
        if payload.customs_office_name:
            record.customs_office_name = payload.customs_office_name
        if payload.authorization_notes:
            record.authorization_notes = payload.authorization_notes
        if mandate_letter_code:
            record.mandate_letter_code = mandate_letter_code
        if record.status in ("Inspection In Progress", "Open", "Draft"):
            record.status = "Broker Authorized - Ready for 46"
        record.updated_at = datetime.now(timezone.utc)
        record.updated_by = user

    # 5. Synchronize ImportFile
    imp_file.broker_id = broker.provider_id
    imp_file.broker_name = broker.partner_name
    imp_file.customs_broker_delegation_no = delegation_no
    imp_file.customs_broker_delegated_at = delegation_dt
    imp_file.customs_broker_authorization_status = "Authorized"
    imp_file.current_module = "Phase 6 - Customs Preparation"
    imp_file.current_stage = "Customs Broker Authorized (تفويض المخلص الجمركي)"
    if (imp_file.progress_percent or 0.0) < 80.0:
        imp_file.progress_percent = 80.0
    imp_file.next_action = "سداد إذن التسليم الملاحي واستلام D/O (CS-02)"
    imp_file.updated_at = datetime.now(timezone.utc)
    imp_file.updated_by = user

    # 6. Auto-complete pending CS-01 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.status != "Completed",
            )
            .all()
        )
        for t in pending_tasks:
            if (
                t.task_type in ("CUSTOMS_BROKER_ASSIGNMENT", "CS-01")
                or "CS-01" in (t.title or "")
                or "تعيين المخلص" in (t.title or "")
                or "التفويض الإلكتروني" in (t.title or "")
            ):
                t.status = "Completed"
                t.completion_notes = f"تم تعيين وتفويض المخلص الجمركي ({broker.partner_name}) برقم تفويض ({delegation_no})."
                t.updated_at = datetime.now(timezone.utc)
    except Exception as ex_task:
        import logging
        logging.getLogger(__name__).warning("Error completing CS-01 SmartTasks: %s", ex_task)

    # 7. Dispatch downstream CS-02 SmartTask (Delivery Order Payment)
    file_label = imp_file.import_file_code or f"IMP-{imp_file.import_file_id}"
    try:
        from modules.smart_tasks.model import SmartTask
        from datetime import timedelta
        import uuid
        existing_cs02 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.task_type.in_(["DELIVERY_ORDER_PAYMENT", "CS-02"]),
            )
            .first()
        )
        if not existing_cs02:
            due_dt = (datetime.now(timezone.utc) + timedelta(days=3)).strftime("%Y-%m-%d")
            task_code = f"TASK-{uuid.uuid4().hex[:8].upper()}"
            downstream_task = SmartTask(
                task_code=task_code,
                import_file_id=payload.import_file_id,
                import_file_code=file_label,
                title=f"سداد إذن التسليم الملاحي واستلام D/O (CS-02) — {file_label}".strip(),
                description=f"تم تعيين وتفويض المخلص الجمركي ({broker.partner_name}) برقم تفويض ({delegation_no}). يرجى سداد مصاريف التوكيل الملاحي واستلام إذن التسليم (Delivery Order) لبدء الكشف والمعاينة وقيد نموذج 46.",
                task_type="DELIVERY_ORDER_PAYMENT",
                priority="High",
                status="Pending",
                assigned_user="Logistics Operations",
                due_date=due_dt,
                created_by=user,
            )
            db.add(downstream_task)
    except Exception as ex_cs02:
        import logging
        logging.getLogger(__name__).warning("Error dispatching CS-02 task: %s", ex_cs02)

    # 8. Emit SystemNotification
    try:
        from modules.notifications.model import SystemNotification
        notif = SystemNotification(
            title=f"تم تفويض المخلص الجمركي إلكترونياً — {broker.partner_name}",
            message=f"تم اعتماد وتفويض المخلص الجمركي ({broker.partner_name}) للشحنة ({file_label}) برقم تفويض ({delegation_no}). الملف جاهز لسداد إذن التسليم والبدء في الإقرار الجمركي 46 ك.م.",
            category="STAGE_PROGRESSION",
            severity="INFO",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="ALL",
            is_read=False,
        )
        db.add(notif)
    except Exception as ex_notif:
        import logging
        logging.getLogger(__name__).warning("Error emitting broker authorization notification: %s", ex_notif)

    # 9. Advance lifecycle board step: STEP_12 -> STEP_13
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=payload.import_file_id,
            completed_step_code="STEP_12",
            target_step_codes=["STEP_13"],
            notes=f"تم تعيين وتفويض المخلص الجمركي ({broker.partner_name}) برقم تفويض ({delegation_no}). انتقال الملف إلى مرحلة إقرار 46 ك.م.",
            assigned_user="Customs Broker",
            custom_next_action="سداد إذن التسليم الملاحي واستلام D/O (CS-02)",
            min_progress_percent=80.0,
        )
    except Exception as ex_lb:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance STEP_12->STEP_13 failed: %s", ex_lb)

    db.commit()
    db.refresh(record)
    return record


def record_delivery_order_payment_service(
    db: Session,
    payload: DeliveryOrderPaymentSubmit,
    user: str = "System",
) -> CustomsClearanceRecord:
    """
    CS-02: Record Shipping Line Agency Fees Payment & Receive Delivery Order (D/O)
    سداد إذن التسليم الملاحي واستلام D/O

    1. Validate import file exists and active
    2. Validate inputs (DO Number, payment ref, positive fees, expiry date)
    3. Validate and fetch shipping agent if provided
    4. Find or create CustomsClearanceRecord with delivery order data
    5. Synchronize ImportFile (status, DO number, expiry, next action, progress >= 83%)
    6. Complete pending CS-02 SmartTasks
    7. Dispatch downstream CS-03 SmartTask (Customs Declaration 46)
    8. Emit SystemNotification to all stakeholders
    9. Advance/maintain Lifecycle Board on STEP_13
    """
    # 1. Validate ImportFile
    imp_file = (
        db.query(ImportFile)
        .filter(
            ImportFile.import_file_id == payload.import_file_id,
            ImportFile.is_active == True,
        )
        .first()
    )
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ملف الشحنة الاستيرادية غير موجود أو محذوف.",
        )

    # 2. Validate DO Number & Payment Ref
    do_number = payload.delivery_order_number.strip()
    if len(do_number) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم إذن التسليم الملاحي يجب ألا يقل عن 3 أحرف/أرقام.",
        )

    payment_ref = payload.delivery_order_payment_ref.strip()
    if len(payment_ref) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم إيصال أو مرجع سداد مصاريف التوكيل الملاحي مطلوب.",
        )

    # 3. Validate Shipping Agent (ExternalServiceProvider)
    shipping_agent_name = payload.shipping_agent_name
    if payload.shipping_agent_id:
        from modules.external_service_providers.model import ExternalServiceProvider
        agent = (
            db.query(ExternalServiceProvider)
            .filter(
                ExternalServiceProvider.provider_id == payload.shipping_agent_id,
                ExternalServiceProvider.is_active == True,
            )
            .first()
        )
        if not agent:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="التوكيل / الخط الملاحي المختار غير مسجل أو محذوف.",
            )
        shipping_agent_name = agent.partner_name

    do_dt = payload.delivery_order_date or datetime.now(timezone.utc)
    paid_dt = payload.delivery_order_paid_at or datetime.now(timezone.utc)
    expiry_dt = payload.delivery_order_expiry

    # 4. Find or create CustomsClearanceRecord
    record = (
        db.query(CustomsClearanceRecord)
        .filter(
            CustomsClearanceRecord.import_file_id == payload.import_file_id,
            CustomsClearanceRecord.is_active == True,
        )
        .first()
    )
    if not record:
        clearance_code = generate_customs_clearance_code(db)
        record = CustomsClearanceRecord(
            clearance_code=clearance_code,
            import_file_id=payload.import_file_id,
            delivery_order_number=do_number,
            delivery_order_date=do_dt,
            delivery_order_expiry=expiry_dt,
            free_days_allowed=payload.free_days_allowed,
            shipping_agent_id=payload.shipping_agent_id,
            shipping_agent_name=shipping_agent_name,
            delivery_order_fees=payload.delivery_order_fees,
            delivery_order_currency=payload.delivery_order_currency,
            delivery_order_payment_ref=payment_ref,
            delivery_order_paid_at=paid_dt,
            delivery_order_status="Paid & Received",
            delivery_order_file_url=payload.delivery_order_file_url,
            delivery_order_notes=payload.notes,
            status="D/O Received - Ready for 46",
            owner=imp_file.owner or "Kamal",
            created_by=user,
            updated_by=user,
        )
        db.add(record)
    else:
        record.delivery_order_number = do_number
        record.delivery_order_date = do_dt
        record.delivery_order_expiry = expiry_dt
        record.free_days_allowed = payload.free_days_allowed
        if payload.shipping_agent_id:
            record.shipping_agent_id = payload.shipping_agent_id
        if shipping_agent_name:
            record.shipping_agent_name = shipping_agent_name
        record.delivery_order_fees = payload.delivery_order_fees
        record.delivery_order_currency = payload.delivery_order_currency
        record.delivery_order_payment_ref = payment_ref
        record.delivery_order_paid_at = paid_dt
        record.delivery_order_status = "Paid & Received"
        if payload.delivery_order_file_url:
            record.delivery_order_file_url = payload.delivery_order_file_url
        if payload.notes:
            record.delivery_order_notes = payload.notes
        if record.status in ("Inspection In Progress", "Open", "Draft", "Broker Authorized - Ready for 46"):
            record.status = "D/O Received - Ready for 46"
        record.updated_at = datetime.now(timezone.utc)
        record.updated_by = user

    # 5. Synchronize ImportFile
    imp_file.delivery_order_no = do_number
    imp_file.delivery_order_date = do_dt
    imp_file.delivery_order_expiry_date = expiry_dt
    imp_file.delivery_order_status = "PAID_AND_RECEIVED"
    imp_file.current_module = "Phase 6 - Customs Preparation"
    imp_file.current_stage = "Delivery Order Paid & Received (سداد إذن التسليم الملاحي)"
    if (imp_file.progress_percent or 0.0) < 83.0:
        imp_file.progress_percent = 83.0
    imp_file.next_action = "قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)"
    imp_file.updated_at = datetime.now(timezone.utc)
    imp_file.updated_by = user

    # 6. Auto-complete pending CS-02 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.status != "Completed",
            )
            .all()
        )
        for t in pending_tasks:
            if (
                t.task_type in ("DELIVERY_ORDER_PAYMENT", "CS-02")
                or "CS-02" in (t.title or "")
                or "إذن التسليم" in (t.title or "")
                or "D/O" in (t.title or "")
            ):
                t.status = "Completed"
                t.completion_notes = f"تم سداد مصاريف التوكيل واستلام إذن التسليم رقم ({do_number}) بإيصال ({payment_ref})."
                t.updated_at = datetime.now(timezone.utc)
    except Exception as ex_task:
        import logging
        logging.getLogger(__name__).warning("Error completing CS-02 SmartTasks: %s", ex_task)

    # 7. Dispatch downstream CS-03 SmartTask (Customs Declaration 46)
    file_label = imp_file.import_file_code or f"IMP-{imp_file.import_file_id}"
    exp_str = expiry_dt.strftime("%Y-%m-%d") if hasattr(expiry_dt, "strftime") else str(expiry_dt)
    try:
        from modules.smart_tasks.model import SmartTask
        from datetime import timedelta
        import uuid
        existing_cs03 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.task_type.in_(["CUSTOMS_DECLARATION_46", "CS-03"]),
            )
            .first()
        )
        if not existing_cs03:
            due_dt = (datetime.now(timezone.utc) + timedelta(days=2)).strftime("%Y-%m-%d")
            task_code = f"TASK-{uuid.uuid4().hex[:8].upper()}"
            downstream_task = SmartTask(
                task_code=task_code,
                import_file_id=payload.import_file_id,
                import_file_code=file_label,
                title=f"قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03) — {file_label}".strip(),
                description=f"تم سداد مصاريف التوكيل الملاحي واستلام إذن التسليم (D/O: {do_number}) بصلاحية حتى {exp_str}. يرجى سرعة قيد وتثبيت الإقرار الجمركي ونموذج 46 ك.م عبر نافذة MTS للبدء في إجراءات الكشف والتثمين.",
                task_type="CUSTOMS_DECLARATION_46",
                priority="High",
                status="Pending",
                assigned_user="Customs Broker",
                due_date=due_dt,
                created_by=user,
            )
            db.add(downstream_task)
    except Exception as ex_cs03:
        import logging
        logging.getLogger(__name__).warning("Error dispatching CS-03 task: %s", ex_cs03)

    # 8. Emit SystemNotification
    try:
        from modules.notifications.model import SystemNotification
        notif = SystemNotification(
            title=f"تم سداد إذن التسليم واستلام D/O — {file_label}",
            message=f"تم تسجيل سداد مصاريف التوكيل الملاحي ({shipping_agent_name or 'التوكيل المختص'}) واستلام إذن التسليم ({do_number}) للشحنة ({file_label}). تنتهي الصلاحية في ({exp_str}). الملف جاهز لقيد نموذج 46.",
            category="STAGE_PROGRESSION",
            severity="INFO",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="ALL",
            is_read=False,
        )
        db.add(notif)
    except Exception as ex_notif:
        import logging
        logging.getLogger(__name__).warning("Error emitting D/O notification: %s", ex_notif)

    # 9. Advance/maintain Lifecycle Board on STEP_13
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=payload.import_file_id,
            completed_step_code="STEP_12",
            target_step_codes=["STEP_13"],
            notes=f"تم سداد مصاريف التوكيل الملاحي واستلام إذن التسليم ({do_number}). جاهز لقيد 46 ك.م.",
            assigned_user="Customs Broker",
            custom_next_action="قيد الإقرار الجمركي ونموذج 46 ك.م (CS-03)",
            min_progress_percent=83.0,
        )
    except Exception as ex_lb:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance for CS-02 failed: %s", ex_lb)

    db.commit()
    db.refresh(record)
    return record


def register_customs_declaration_46_service(
    db: Session,
    payload: CustomsDeclaration46Submit,
    user: str = "System",
) -> CustomsClearanceRecord:
    """
    CS-03: Customs Declaration 46 Registration
    قيد الإقرار الجمركي ونموذج 46 ك.م

    1. Validate import file exists and active
    2. Validate declaration_46_no length >= 3
    3. Update or create CustomsClearanceRecord with form 46 details, channel, regulatory bodies
    4. Synchronize ImportFile (form46_no, form46_date, form46_status="REGISTERED", module, stage, next_action, progress >= 86%)
    5. Complete pending CS-03 SmartTasks
    6. Dispatch downstream CL-01 SmartTask (Customs Inspection & Sampling)
    7. Emit SystemNotification to all stakeholders
    8. Advance Lifecycle Board from STEP_13 to STEP_14 and STEP_15
    """
    # 1. Validate ImportFile
    imp_file = (
        db.query(ImportFile)
        .filter(
            ImportFile.import_file_id == payload.import_file_id,
            ImportFile.is_active == True,
        )
        .first()
    )
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ملف الشحنة الاستيرادية غير موجود أو محذوف.",
        )

    # 2. Validate Declaration 46 Number
    dec_no = payload.declaration_46_no.strip()
    if len(dec_no) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم الإقرار الجمركي ونموذج 46 ك.م يجب ألا يقل عن 3 أحرف/أرقام.",
        )

    dec_dt = payload.declaration_46_date or datetime.now(timezone.utc)
    channel = payload.channel_type or "Red Channel"
    office = (payload.customs_office_name or "").strip() or "Alexandria Port Customs"
    reg_bodies = enum_codes.normalize_list(enum_codes.REGULATORY_BODY, payload.regulatory_bodies) or []
    tariff_count = payload.customs_tariff_items_count if payload.customs_tariff_items_count and payload.customs_tariff_items_count > 0 else 1
    mts_cert = payload.mts_certificate_number.strip() if payload.mts_certificate_number else None

    # 3. Find or create CustomsClearanceRecord
    record = (
        db.query(CustomsClearanceRecord)
        .filter(
            CustomsClearanceRecord.import_file_id == payload.import_file_id,
            CustomsClearanceRecord.is_active == True,
        )
        .first()
    )
    if not record:
        clearance_code = generate_customs_clearance_code(db)
        record = CustomsClearanceRecord(
            clearance_code=clearance_code,
            import_file_id=payload.import_file_id,
            declaration_46_no=dec_no,
            declaration_46_date=dec_dt,
            customs_office_name=office,
            channel_type=channel,
            regulatory_bodies=reg_bodies,
            mts_certificate_number=mts_cert,
            customs_tariff_items_count=tariff_count,
            inspection_notes=payload.inspection_notes,
            status="Under Customs Clearance",
            owner=imp_file.owner or "Kamal",
            created_by=user,
            updated_by=user,
        )
        db.add(record)
    else:
        record.declaration_46_no = dec_no
        record.declaration_46_date = dec_dt
        record.customs_office_name = office
        record.channel_type = channel
        record.regulatory_bodies = reg_bodies
        if mts_cert:
            record.mts_certificate_number = mts_cert
        record.customs_tariff_items_count = tariff_count
        if payload.inspection_notes:
            record.inspection_notes = payload.inspection_notes
        record.status = "Under Customs Clearance"
        record.updated_at = datetime.now(timezone.utc)
        record.updated_by = user

    # 4. Synchronize ImportFile
    imp_file.form46_no = dec_no
    imp_file.form46_date = dec_dt
    imp_file.form46_status = "REGISTERED"
    imp_file.current_module = "Phase 7 - Customs Clearance"
    imp_file.current_stage = "Under Customs Clearance (تحت التخليص والكشف 46)"
    if (imp_file.progress_percent or 0.0) < 86.0:
        imp_file.progress_percent = 86.0
    imp_file.next_action = "تسجيل الكشف والمعاينة وسحب العينات (CL-01)"
    imp_file.updated_at = datetime.now(timezone.utc)
    imp_file.updated_by = user

    # 5. Auto-complete pending CS-03 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.status != "Completed",
            )
            .all()
        )
        for t in pending_tasks:
            if (
                t.task_type in ("CUSTOMS_DECLARATION_46", "CS-03")
                or "CS-03" in (t.title or "")
                or "قيد الإقرار" in (t.title or "")
                or "نموذج 46" in (t.title or "")
            ):
                t.status = "Completed"
                t.completion_notes = f"تم قيد الإقرار الجمركي ونموذج 46 ك.م برقم ({dec_no}) على المسار ({channel})."
                t.updated_at = datetime.now(timezone.utc)
    except Exception as ex_task:
        import logging
        logging.getLogger(__name__).warning("Error completing CS-03 SmartTasks: %s", ex_task)

    # 6. Dispatch downstream CL-01 SmartTask (Customs Inspection & Sampling)
    file_label = imp_file.import_file_code or f"IMP-{imp_file.import_file_id}"
    try:
        from modules.smart_tasks.model import SmartTask
        from datetime import timedelta
        import uuid
        existing_cl01 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.task_type.in_(["CUSTOMS_INSPECTION_SAMPLING", "CL-01"]),
            )
            .first()
        )
        if not existing_cl01:
            due_dt = (datetime.now(timezone.utc) + timedelta(days=2)).strftime("%Y-%m-%d")
            task_code = f"TASK-{uuid.uuid4().hex[:8].upper()}"
            downstream_task = SmartTask(
                task_code=task_code,
                import_file_id=payload.import_file_id,
                import_file_code=file_label,
                title=f"تسجيل الكشف والمعاينة وسحب العينات (CL-01) — {file_label}".strip(),
                description=f"تم قيد وتثبيت الإقرار الجمركي 46 ك.م برقم ({dec_no}) على المسار ({channel}) بمكتب جمارك ({office}). يرجى البدء في إجراءات المعاينة الميدانية وسحب العينات لجهات العرض المحددة.",
                task_type="CUSTOMS_INSPECTION_SAMPLING",
                priority="High",
                status="Pending",
                assigned_user="Customs Broker",
                due_date=due_dt,
                created_by=user,
            )
            db.add(downstream_task)
    except Exception as ex_cl01:
        import logging
        logging.getLogger(__name__).warning("Error dispatching CL-01 task: %s", ex_cl01)

    # 7. Emit SystemNotification
    try:
        from modules.notifications.model import SystemNotification
        notif = SystemNotification(
            title=f"تم قيد الإقرار الجمركي 46 ك.م — {file_label}",
            message=f"تم قيد وتثبيت الإقرار الجمركي 46 ك.م برقم ({dec_no}) على المسار ({channel}) للشحنة ({file_label}) بمكتب جمارك ({office}). الملف قيد الكشف والمعاينة وسحب العينات (CL-01).",
            category="STAGE_PROGRESSION",
            severity="INFO",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="ALL",
            is_read=False,
        )
        db.add(notif)
    except Exception as ex_notif:
        import logging
        logging.getLogger(__name__).warning("Error emitting declaration 46 notification: %s", ex_notif)

    # 8. Advance Lifecycle Board: complete STEP_13 and advance to STEP_14 and STEP_15
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=payload.import_file_id,
            completed_step_code="STEP_13",
            target_step_codes=["STEP_14", "STEP_15"],
            notes=f"تم قيد وتثبيت الإقرار الجمركي 46 ك.م برقم ({dec_no}) على المسار ({channel}). انتقال الشحنة إلى الكشف والمعاينة وسحب العينات.",
            assigned_user="Customs Broker",
            custom_next_action="تسجيل الكشف والمعاينة وسحب العينات (CL-01)",
            min_progress_percent=86.0,
        )
    except Exception as ex_lb:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance for CS-03 failed: %s", ex_lb)

    db.commit()
    db.refresh(record)
    return record


def record_customs_inspection_sampling_service(
    db: Session,
    payload: CustomsInspectionSamplingSubmit,
    user: str = "System",
) -> CustomsClearanceRecord:
    """
    CL-01: Inspection & Samples GOEIC Report
    تسجيل الكشف والمعاينة وسحب العينات ومطابقة الرقابة على الصادرات والواردات

    1. Validate import file exists and active
    2. Validate sampling record no if samples drawn
    3. Update or create CustomsClearanceRecord with inspection and sampling details
    4. Synchronize ImportFile (current_module, current_stage, progress >= 88%, next_action)
    5. Complete pending CL-01 SmartTasks
    6. Dispatch downstream CL-02 SmartTask (Final Customs Duty Assessment)
    7. Emit SystemNotification to all stakeholders
    8. Advance Lifecycle Board (STEP_14/15 -> STEP_17)
    """
    # 1. Validate ImportFile
    imp_file = (
        db.query(ImportFile)
        .filter(
            ImportFile.import_file_id == payload.import_file_id,
            ImportFile.is_active == True,
        )
        .first()
    )
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ملف الشحنة الاستيرادية غير موجود أو محذوف.",
        )

    # 2. Validate sampling record number if sample is drawn
    sampling_rec = (payload.sampling_record_no or "").strip()
    if payload.is_sample_drawn:
        if sampling_rec and len(sampling_rec) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="رقم محضر سحب العينات يجب ألا يقل عن 3 أحرف/أرقام.",
            )
        if not sampling_rec:
            import random
            rand_suffix = random.randint(100, 999)
            sampling_rec = f"SMP-{datetime.now().year}-{payload.import_file_id:04d}-{rand_suffix}"

    insp_dt = payload.inspection_date or datetime.now(timezone.utc)
    sampling_dt = payload.sampling_date or (insp_dt if payload.is_sample_drawn else None)
    # INSPECTION_YARD code when picked from the list (legacy Arabic names mapped); free text stays as typed.
    insp_yard = enum_codes.normalize(enum_codes.INSPECTION_YARD, (payload.inspection_yard or "").strip()) or "Joint Inspection Yard"
    insp_type = (payload.inspection_type or "").strip() or "Physical & Sampling"
    insp_result = (payload.inspection_result or "").strip() or "Conforming"
    sample_status = payload.sample_test_status or ("Samples Under Testing" if payload.is_sample_drawn else "None")
    sampled_bodies = enum_codes.normalize_list(enum_codes.REGULATORY_BODY, payload.sampled_regulatory_bodies) or []
    goeic_cert = (payload.goeic_certificate_no or "").strip() if payload.goeic_certificate_no else None
    lab_fees = float(payload.lab_service_fees or 0.0)

    # 3. Find or create CustomsClearanceRecord
    record = (
        db.query(CustomsClearanceRecord)
        .filter(
            CustomsClearanceRecord.import_file_id == payload.import_file_id,
            CustomsClearanceRecord.is_active == True,
        )
        .first()
    )
    if not record:
        clearance_code = generate_customs_clearance_code(db)
        record = CustomsClearanceRecord(
            clearance_code=clearance_code,
            import_file_id=payload.import_file_id,
            customs_office_name=insp_yard,
            channel_type="Red Channel",
            inspection_date=insp_dt,
            inspection_type=insp_type,
            inspection_yard=insp_yard,
            inspector_name=payload.inspector_name,
            inspection_result=insp_result,
            is_sample_drawn=payload.is_sample_drawn,
            sampling_date=sampling_dt,
            sampling_record_no=sampling_rec if payload.is_sample_drawn else None,
            sample_test_status=sample_status,
            sampled_regulatory_bodies=sampled_bodies,
            goeic_certificate_no=goeic_cert,
            lab_service_fees=lab_fees,
            inspection_notes=payload.inspection_notes,
            status="Inspection & Sampling Recorded",
            owner=imp_file.owner or "Kamal",
            created_by=user,
            updated_by=user,
        )
        db.add(record)
    else:
        record.inspection_date = insp_dt
        record.inspection_type = insp_type
        record.inspection_yard = insp_yard
        if payload.inspector_name:
            record.inspector_name = payload.inspector_name
        record.inspection_result = insp_result
        record.is_sample_drawn = payload.is_sample_drawn
        record.sampling_date = sampling_dt
        record.sampling_record_no = sampling_rec if payload.is_sample_drawn else None
        record.sample_test_status = sample_status
        record.sampled_regulatory_bodies = sampled_bodies
        if goeic_cert:
            record.goeic_certificate_no = goeic_cert
        if lab_fees > 0:
            record.lab_service_fees = lab_fees
        if payload.inspection_notes:
            record.inspection_notes = payload.inspection_notes
        record.status = "Inspection & Sampling Recorded"
        record.updated_at = datetime.now(timezone.utc)
        record.updated_by = user

    # 4. Synchronize ImportFile
    imp_file.current_module = "Phase 7 - Customs Clearance & Inspection"
    imp_file.current_stage = "Customs Inspection & Sampling Completed (تم الكشف وسحب العينات)"
    if (imp_file.progress_percent or 0.0) < 88.0:
        imp_file.progress_percent = 88.0
    imp_file.next_action = "احتساب الرسوم والضرائب الجمركية النهائية (CL-02)"
    imp_file.updated_at = datetime.now(timezone.utc)
    imp_file.updated_by = user

    # 5. Auto-complete pending CL-01 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.status != "Completed",
            )
            .all()
        )
        for t in pending_tasks:
            if (
                t.task_type in ("CUSTOMS_INSPECTION_SAMPLING", "CL-01")
                or "CL-01" in (t.title or "")
                or "الكشف والمعاينة" in (t.title or "")
                or "سحب العينات" in (t.title or "")
            ):
                t.status = "Completed"
                t.completion_notes = f"تم إنجاز الكشف والمعاينة بنتيجة ({insp_result}) وسحب العينات بمحضر ({sampling_rec if payload.is_sample_drawn else 'بدون سحب'})."
                t.updated_at = datetime.now(timezone.utc)
    except Exception as ex_task:
        import logging
        logging.getLogger(__name__).warning("Error completing CL-01 SmartTasks: %s", ex_task)

    # 6. Dispatch downstream CL-02 SmartTask (Final Customs Duty Assessment)
    file_label = imp_file.import_file_code or f"IMP-{imp_file.import_file_id}"
    try:
        from modules.smart_tasks.model import SmartTask
        from datetime import timedelta
        import uuid
        existing_cl02 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.task_type.in_(["FINAL_DUTY_ASSESSMENT", "CL-02"]),
            )
            .first()
        )
        if not existing_cl02:
            due_dt = (datetime.now(timezone.utc) + timedelta(days=2)).strftime("%Y-%m-%d")
            task_code = f"TASK-{uuid.uuid4().hex[:8].upper()}"
            downstream_task = SmartTask(
                task_code=task_code,
                import_file_id=payload.import_file_id,
                import_file_code=file_label,
                title=f"احتساب الرسوم والضرائب الجمركية النهائية (CL-02) — {file_label}".strip(),
                description=f"تم تسجيل الكشف والمعاينة وسحب العينات للشحنة ({file_label}) بنجاح بنتيجة ({insp_result}). يرجى مراجعة المطالبة الجمركية واحتساب الرسوم والضرائب الجمركية النهائية (الوارد، القيمة المضافة، رسم التنمية، ورسوم الخدمات).",
                task_type="FINAL_DUTY_ASSESSMENT",
                priority="High",
                status="Pending",
                assigned_user="Customs Broker",
                due_date=due_dt,
                created_by=user,
            )
            db.add(downstream_task)
    except Exception as ex_cl02:
        import logging
        logging.getLogger(__name__).warning("Error dispatching CL-02 task: %s", ex_cl02)

    # 7. Emit SystemNotification
    try:
        from modules.notifications.model import SystemNotification
        notif = SystemNotification(
            title=f"تم تسجيل الكشف والمعاينة وسحب العينات — {file_label}",
            message=f"تم تسجيل محضر الكشف والمعاينة الميدانية للشحنة ({file_label}) بنتيجة ({insp_result}) في ({insp_yard}). محضر سحب العينات: ({sampling_rec if payload.is_sample_drawn else 'لا يوجد'}). جاهز لاحتساب الرسوم النهائية (CL-02).",
            category="STAGE_PROGRESSION",
            severity="INFO",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="ALL",
            is_read=False,
        )
        db.add(notif)
    except Exception as ex_notif:
        import logging
        logging.getLogger(__name__).warning("Error emitting inspection notification: %s", ex_notif)

    # 8. Advance Lifecycle Board
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=payload.import_file_id,
            completed_step_code="STEP_14",
            target_step_codes=["STEP_15", "STEP_17"],
            notes=f"تم إنجاز الكشف والمعاينة بنتيجة ({insp_result}). محضر سحب العينات: ({sampling_rec if payload.is_sample_drawn else 'لا يوجد'}). انتقال الشحنة لاحتساب الرسوم الجمركية.",
            assigned_user="Customs Broker",
            custom_next_action="احتساب الرسوم والضرائب الجمركية النهائية (CL-02)",
            min_progress_percent=88.0,
        )
    except Exception as ex_lb:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance for CL-01 failed: %s", ex_lb)

    db.commit()
    db.refresh(record)
    return record


def assess_final_customs_duties_service(
    db: Session,
    payload: FinalDutyAssessmentSubmit,
    user: str = "System",
) -> CustomsClearanceRecord:
    """
    CL-02: Final Duty & Tax Assessment
    احتساب الرسوم والضرائب الجمركية النهائية

    1. Validate import file exists and active
    2. Validate nafeza_claim_number length >= 3
    3. Calculate components & total payable (Import Duty, VAT, Schedule Tax, Development Fee, Customs Service Fees, WHT, Lab Fees)
    4. Compute variance against estimated duties (if estimated exists)
    5. Update or create CustomsClearanceRecord with final assessment breakdown
    6. Synchronize ImportFile (current_module, current_stage, progress >= 90%, next_action)
    7. Auto-complete pending CL-02 SmartTasks
    8. Dispatch downstream CL-03 SmartTask (Customs Duty Payment via Sadad / E-Finance)
    9. Emit SystemNotification to all stakeholders
    10. Advance Lifecycle Board (STEP_15 -> STEP_16/STEP_17)
    """
    # 1. Validate ImportFile
    imp_file = (
        db.query(ImportFile)
        .filter(
            ImportFile.import_file_id == payload.import_file_id,
            ImportFile.is_active == True,
        )
        .first()
    )
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ملف الشحنة الاستيرادية غير موجود أو محذوف.",
        )

    # 2. Validate Nafeza claim number
    claim_no = (payload.nafeza_claim_number or "").strip()
    if len(claim_no) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم المطالبة الجمركية بنظام نافذة يجب ألا يقل عن 3 أحرف/أرقام.",
        )

    # 3. Component summation
    cif_base = float(payload.cif_base_amount or 0.0)
    rate = float(payload.customs_exchange_rate or 1.0)
    import_duty = float(payload.import_duty_amount or 0.0)
    vat = float(payload.vat_amount or 0.0)
    schedule_tax = float(payload.schedule_tax_amount or 0.0)
    dev_fee = float(payload.development_fee_amount or 0.0)
    customs_services = float(payload.customs_service_fees or 0.0)
    wht = float(payload.wht_amount or 0.0)
    lab_fees = float(payload.lab_service_fees or 0.0)

    computed_total = round(import_duty + vat + schedule_tax + dev_fee + customs_services + wht + lab_fees, 2)
    if payload.actual_duty_total is not None and payload.actual_duty_total > 0:
        actual_total = round(float(payload.actual_duty_total), 2)
    else:
        actual_total = computed_total

    claim_dt = payload.nafeza_claim_date or datetime.now(timezone.utc)

    # 4. Find or create CustomsClearanceRecord
    record = (
        db.query(CustomsClearanceRecord)
        .filter(
            CustomsClearanceRecord.import_file_id == payload.import_file_id,
            CustomsClearanceRecord.is_active == True,
        )
        .first()
    )
    if not record:
        clearance_code = generate_customs_clearance_code(db)
        record = CustomsClearanceRecord(
            clearance_code=clearance_code,
            import_file_id=payload.import_file_id,
            customs_office_name=imp_file.port_of_discharge or "ميناء الدخيلة الإسكندرية",
            owner=imp_file.owner or "Kamal",
            created_by=user,
            updated_by=user,
        )
        db.add(record)

    # 5. Compute variance against estimated_duty_total
    est_total = float(record.estimated_duty_total or 0.0)
    var_amount = 0.0
    var_pct = 0.0
    if est_total > 0:
        var_amount = round(actual_total - est_total, 2)
        var_pct = round((var_amount / est_total) * 100, 2)

    # 6. Populate record fields
    record.cif_base_amount = cif_base
    record.customs_exchange_rate = rate
    record.import_duty_amount = import_duty
    record.vat_amount = vat
    record.schedule_tax_amount = schedule_tax
    record.development_fee_amount = dev_fee
    record.customs_service_fees = customs_services
    record.wht_amount = wht
    record.lab_service_fees = lab_fees
    record.total_duty_payable = actual_total
    record.actual_duty_total = actual_total
    record.duty_variance_amount = var_amount
    record.duty_variance_percentage = var_pct
    if payload.duty_variance_reason:
        record.duty_variance_reason = payload.duty_variance_reason
    record.nafeza_claim_number = claim_no
    record.nafeza_claim_date = claim_dt
    record.assessment_status = "Assessed"
    if payload.nafeza_assessment_json:
        record.nafeza_assessment_json = payload.nafeza_assessment_json
    if payload.assessment_notes:
        record.notes = (record.notes or "") + f" | تثمين نافذة: {payload.assessment_notes}"

    record.status = "Customs Duties Assessed - Ready for Payment"
    record.payment_status = "Payment Requested" if record.payment_status in ("Unpaid", None) else record.payment_status
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user

    # 7. Synchronize ImportFile
    imp_file.current_module = "Phase 7 - Customs Clearance & Duty Assessment"
    imp_file.current_stage = "Customs Duty Assessed (احتساب الرسوم الجمركية والمطالبة)"
    if (imp_file.progress_percent or 0.0) < 90.0:
        imp_file.progress_percent = 90.0
    imp_file.next_action = "تسجيل سداد الرسوم الجمركية بسداد (CL-03)"
    imp_file.updated_at = datetime.now(timezone.utc)
    imp_file.updated_by = user

    # 8. Auto-complete pending CL-02 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.status != "Completed",
            )
            .all()
        )
        for t in pending_tasks:
            if (
                t.task_type in ("FINAL_DUTY_ASSESSMENT", "CL-02")
                or "CL-02" in (t.title or "")
                or "احتساب الرسوم" in (t.title or "")
                or "تثمين الرسوم" in (t.title or "")
            ):
                t.status = "Completed"
                t.completion_notes = f"تم احتساب واعتماد المطالبة الجمركية رقم ({claim_no}) بإجمالي ({actual_total:,.2f} ج.م)."
                t.updated_at = datetime.now(timezone.utc)
    except Exception as ex_task:
        import logging
        logging.getLogger(__name__).warning("Error completing CL-02 SmartTasks: %s", ex_task)

    # 9. Dispatch downstream CL-03 SmartTask (Duty Payment via Sadad)
    file_label = imp_file.import_file_code or f"IMP-{imp_file.import_file_id}"
    try:
        from modules.smart_tasks.model import SmartTask
        from datetime import timedelta
        import uuid
        existing_cl03 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.task_type.in_(["CUSTOMS_DUTY_PAYMENT", "CL-03"]),
            )
            .first()
        )
        if not existing_cl03:
            due_dt = (datetime.now(timezone.utc) + timedelta(days=2)).strftime("%Y-%m-%d")
            task_code = f"TASK-{uuid.uuid4().hex[:8].upper()}"
            downstream_task = SmartTask(
                task_code=task_code,
                import_file_id=payload.import_file_id,
                import_file_code=file_label,
                title=f"تسجيل سداد الرسوم الجمركية عبر سداد / E-Finance (CL-03) — {file_label}".strip(),
                description=f"صدرت المطالبة الجمركية رقم ({claim_no}) بإجمالي رسوم ({actual_total:,.2f} ج.م) للشحنة ({file_label}). يرجى إصدار أمر التحويل والسداد عبر منظومة سداد وتوثيق إيصال السداد البنكي.",
                task_type="CUSTOMS_DUTY_PAYMENT",
                priority="Urgent",
                status="Pending",
                assigned_user="Customs Broker",
                due_date=due_dt,
                created_by=user,
            )
            db.add(downstream_task)
    except Exception as ex_cl03:
        import logging
        logging.getLogger(__name__).warning("Error dispatching CL-03 task: %s", ex_cl03)

    # 10. Emit SystemNotification
    try:
        from modules.notifications.model import SystemNotification
        notif = SystemNotification(
            title=f"تم احتساب الرسوم والضرائب الجمركية — {file_label}",
            message=f"تم تثمين واعتماد المطالبة الجمركية رقم ({claim_no}) للشحنة ({file_label}) بإجمالي مستحق ({actual_total:,.2f} ج.م). جاهز للسداد عبر منظومة سداد (CL-03).",
            category="STAGE_PROGRESSION",
            severity="INFO",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="ALL",
            is_read=False,
        )
        db.add(notif)
    except Exception as ex_notif:
        import logging
        logging.getLogger(__name__).warning("Error emitting duty assessment notification: %s", ex_notif)

    # 11. Advance Lifecycle Board
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=payload.import_file_id,
            completed_step_code="STEP_15",
            target_step_codes=["STEP_16", "STEP_17"],
            notes=f"تم احتساب الرسوم والضرائب الجمركية بمطالبة نافذة #{claim_no} بإجمالي ({actual_total:,.2f} ج.م). جاهز للسداد عبر سداد.",
            assigned_user="Customs Broker",
            custom_next_action="تسجيل سداد الرسوم الجمركية بسداد (CL-03)",
            min_progress_percent=90.0,
        )
    except Exception as ex_lb:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance for CL-02 failed: %s", ex_lb)

    db.commit()
    db.refresh(record)
    return record


def get_customs_clearance_service(db: Session, record_id: int) -> CustomsClearanceRecord:
    record = get_customs_clearance_by_id(db, record_id)
    if not record:
        raise HTTPException(status_code=404, detail="سجل التخليص الجمركي والمعاينة غير موجود.")
    return record

def list_customs_clearances_service(
    db: Session,
    include_inactive: bool = False,
    import_file_id: Optional[int] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
) -> List[CustomsClearanceRecord]:
    return get_customs_clearance_list(db, include_inactive, import_file_id, status, search)

def record_customs_duty_payment_service(
    db: Session, payload: CustomsDutyPaymentSubmit, user: str = "Customs Broker"
) -> CustomsClearanceRecord:
    """
    CL-03: Customs Duty Payment Receipt (تسجيل سداد الرسوم الجمركية بسداد / E-Finance)
    1. Validate active ImportFile.
    2. Validate receipt no, sadad no, paying bank, and duty_paid_amount > 0.
    3. Retrieve or create CustomsClearanceRecord.
    4. Update clearance record with payment attributes.
    5. Synchronize ImportFile (customs_duty_paid_amount, customs_duty_receipt_no, etc.).
    6. Auto-complete pending CL-03 SmartTasks.
    7. Dispatch downstream CL-04 SmartTask (Final Release Order).
    8. Emit central SystemNotification.
    9. Advance Lifecycle Board STEP_16 -> STEP_17.
    """
    # 1. Validate active ImportFile
    imp_file = (
        db.query(ImportFile)
        .filter(ImportFile.import_file_id == payload.import_file_id, ImportFile.is_active == True)
        .first()
    )
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ملف الشحنة الاستيرادية المحدد غير موجود أو غير نشط.",
        )

    # 2. Validate payment parameters
    receipt_no = payload.bank_receipt_no.strip()
    validate_bank_receipt_no(receipt_no)
    sadad_no = payload.sadad_number.strip()
    if len(sadad_no) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم منظومة سداد / E-Finance يجب ألا يقل عن 3 أحرف.",
        )
    if payload.duty_paid_amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="المبلغ المسدد للرسوم الجمركية يجب أن يكون أكبر من الصفر.",
        )

    # 3. Retrieve or create CustomsClearanceRecord
    record = (
        db.query(CustomsClearanceRecord)
        .filter(
            CustomsClearanceRecord.import_file_id == payload.import_file_id,
            CustomsClearanceRecord.is_active == True,
        )
        .first()
    )
    if not record:
        code = generate_customs_clearance_code(db)
        create_schema = CustomsClearanceCreate(
            import_file_id=payload.import_file_id,
            customs_office_name=imp_file.port_of_discharge or "Alexandria Port Customs",
            declaration_46_no=imp_file.form46_no or "DEC-AUTO-46",
            declaration_46_date=datetime.now(timezone.utc),
            status="Customs Duties Assessed - Ready for Payment",
            owner=imp_file.owner or "Kamal",
        )
        record = create_customs_clearance(db, create_schema, code)

    # 4. Update clearance record
    pay_dt = payload.payment_date or datetime.now(timezone.utc)
    record.bank_receipt_no = receipt_no
    record.sadad_number = sadad_no
    record.paying_bank_name = enum_codes.normalize(enum_codes.DUTY_BANK, payload.paying_bank_name.strip())
    record.payment_date = pay_dt
    record.payment_method = enum_codes.normalize(enum_codes.PAYMENT_METHOD, payload.payment_method) or "SADAD_EFINANCE"
    record.duty_paid_amount = payload.duty_paid_amount
    record.actual_duty_total = payload.duty_paid_amount
    if payload.receipt_file_url:
        record.receipt_file_url = payload.receipt_file_url
    if payload.payment_notes:
        record.payment_notes = payload.payment_notes
        record.notes = (record.notes or "") + f" | سداد جمركي: {payload.payment_notes}"

    # Recalculate variance if estimated exists
    if record.estimated_duty_total and record.estimated_duty_total > 0:
        record.duty_variance_amount = record.actual_duty_total - record.estimated_duty_total
        record.duty_variance_percentage = round((record.duty_variance_amount / record.estimated_duty_total) * 100, 2)

    record.payment_status = "Paid & Verified"
    record.status = "Duty Paid - Ready for Final Release"
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user

    # 5. Synchronize ImportFile
    imp_file.customs_duty_paid_amount = payload.duty_paid_amount
    imp_file.customs_duty_receipt_no = receipt_no
    imp_file.customs_duty_sadad_no = sadad_no
    imp_file.customs_duty_payment_date = pay_dt
    imp_file.customs_duty_payment_status = "PAID"
    imp_file.current_module = "Phase 7 - Customs Clearance & Duty Payment"
    imp_file.current_stage = "Duty Paid (تم سداد الرسوم الجمركية بسداد)"
    if (imp_file.progress_percent or 0.0) < 92.0:
        imp_file.progress_percent = 92.0
    imp_file.next_action = "صدور أمر الإفراج الجمركي الأخضر (CL-04)"
    imp_file.updated_at = datetime.now(timezone.utc)
    imp_file.updated_by = user

    file_label = imp_file.import_file_code or f"IMP-{imp_file.import_file_id}"

    # 6. Auto-complete pending CL-03 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.status != "Completed",
            )
            .all()
        )
        for t in pending_tasks:
            if (
                t.task_type in ("CUSTOMS_DUTY_PAYMENT", "CL-03")
                or "CL-03" in (t.title or "")
                or "سداد" in (t.title or "")
            ):
                t.status = "Completed"
                t.completion_notes = f"تم تأكيد سداد الرسوم الجمركية برقم سداد ({sadad_no}) وإيصال #{receipt_no} بمبلغ ({payload.duty_paid_amount:,.2f} ج.م)."
                t.updated_at = datetime.now(timezone.utc)
    except Exception as ex_task:
        import logging
        logging.getLogger(__name__).warning("Error completing CL-03 SmartTasks: %s", ex_task)

    # 7. Dispatch downstream CL-04 SmartTask (Final Release Order)
    try:
        from modules.smart_tasks.model import SmartTask
        from datetime import timedelta
        import uuid
        existing_cl04 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.task_type.in_(["CUSTOMS_FINAL_RELEASE", "CL-04"]),
            )
            .first()
        )
        if not existing_cl04:
            due_dt = (datetime.now(timezone.utc) + timedelta(days=2)).strftime("%Y-%m-%d")
            task_code = f"TASK-{uuid.uuid4().hex[:8].upper()}"
            downstream_task = SmartTask(
                task_code=task_code,
                import_file_id=payload.import_file_id,
                import_file_code=file_label,
                title=f"صدور أمر الإفراج الجمركي الأخضر وبدء إجراءات النقل (CL-04) — {file_label}".strip(),
                description=f"تم سداد الرسوم الجمركية بمبلغ ({payload.duty_paid_amount:,.2f} ج.م) بنجاح عبر سداد برقم ({sadad_no}) للشحنة ({file_label}). يرجى استخراج إذن الإفراج النهائي الأخضر وتنسيق خروج الحاويات من الميناء.",
                task_type="CUSTOMS_FINAL_RELEASE",
                priority="Urgent",
                status="Pending",
                assigned_user="Customs Broker",
                due_date=due_dt,
                created_by=user,
            )
            db.add(downstream_task)
    except Exception as ex_cl04:
        import logging
        logging.getLogger(__name__).warning("Error dispatching CL-04 task: %s", ex_cl04)

    # 8. Emit SystemNotification
    try:
        from modules.notifications.model import SystemNotification
        notif = SystemNotification(
            title=f"تم سداد الرسوم الجمركية — {file_label}",
            message=f"تم تأكيد سداد الرسوم الجمركية للشحنة ({file_label}) بمبلغ ({payload.duty_paid_amount:,.2f} ج.م) عبر منظومة سداد ({sadad_no}) وإيصال #{receipt_no}. جاهز لصدور أمر الإفراج الجمركي الأخضر (CL-04).",
            category="STAGE_PROGRESSION",
            severity="INFO",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="ALL",
            is_read=False,
        )
        db.add(notif)
    except Exception as ex_notif:
        import logging
        logging.getLogger(__name__).warning("Error emitting duty payment notification: %s", ex_notif)

    # 9. Advance Lifecycle Board STEP_16 -> STEP_17
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=payload.import_file_id,
            completed_step_code="STEP_16",
            target_step_codes=["STEP_17"],
            notes=f"تم سداد الرسوم الجمركية بنجاح برقم سداد {sadad_no} وإيصال {receipt_no}. بانتظار صدور إذن الإفراج النهائي.",
            assigned_user="Customs Broker",
            custom_next_action="صدور أمر الإفراج الجمركي الأخضر (CL-04)",
            min_progress_percent=92.0,
        )
    except Exception as ex_lb:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance for CL-03 failed: %s", ex_lb)

    db.commit()
    db.refresh(record)
    return record


def submit_duty_payment_service(db: Session, record_id: int, payload: DutyPaymentSubmit) -> CustomsClearanceRecord:
    """BP-031 Record Customs Duty Payment & Match Final Customs Ledger."""
    validate_bank_receipt_no(payload.bank_receipt_no)
    
    record = get_customs_clearance_service(db, record_id)
    record.bank_receipt_no = payload.bank_receipt_no
    record.paying_bank_name = enum_codes.normalize(enum_codes.DUTY_BANK, payload.paying_bank_name)
    record.payment_date = payload.payment_date
    record.payment_notes = payload.payment_notes
    
    if payload.actual_duty_total is not None and payload.actual_duty_total > 0:
        record.actual_duty_total = payload.actual_duty_total
    elif record.actual_duty_total == 0.0:
        record.actual_duty_total = record.total_duty_payable
        
    if payload.estimated_duty_total is not None and payload.estimated_duty_total > 0:
        record.estimated_duty_total = payload.estimated_duty_total

    if record.estimated_duty_total > 0:
        record.duty_variance_amount = record.actual_duty_total - record.estimated_duty_total
        record.duty_variance_percentage = round((record.duty_variance_amount / record.estimated_duty_total) * 100, 2)

    if payload.duty_variance_reason:
        record.duty_variance_reason = payload.duty_variance_reason

    if payload.nafeza_assessment_json:
        record.nafeza_assessment_json = payload.nafeza_assessment_json

    record.payment_status = "Paid & Verified"
    record.status = "Duty Paid"
    record.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(record)

    # Lifecycle advance: Advance to STEP_17 upon duty payment confirmation
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=record.import_file_id,
            completed_step_code="STEP_16",
            target_step_codes=["STEP_17"],
            notes=f"تم سداد الرسوم الجمركية برقم إيصال ({payload.bank_receipt_no}) لدى {payload.paying_bank_name or 'البنك التجاري'}. بانتظار صدور إذن الإفراج النهائي.",
            assigned_user="Customs Broker",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance STEP_16->STEP_17 failed: %s", e)

    return record


def issue_final_customs_release_service(
    db: Session,
    payload: CustomsFinalReleaseSubmit,
    user: str = "Kamal"
) -> CustomsClearanceRecord:
    """
    CL-04: Issue Final Customs Release Order (صدور إذن الإفراج الجمركي الأخضر وبدء إجراءات النقل).
    - Hard-blocks if ACID has expired (DC-02).
    - Requires duties to be paid (CL-03).
    - Sets release_permit_no, release_date, release_officer_name, gate_pass_number, release_document_url, dispatch_authorized.
    - Synchronizes ImportFile: is_customs_released=True, customs_released_at, advances progress to >= 95%.
    - Auto-completes CL-04 SmartTasks.
    - Dispatches downstream TR-01 (Inland Transport) & TR-02 (Demurrage Radar) SmartTasks.
    - Emits central SystemNotification.
    - Advances LifecycleBoard STEP_17 -> STEP_18.
    """
    import logging
    logger = logging.getLogger(__name__)

    # 1. Fetch & Validate ImportFile
    imp_file = (
        db.query(ImportFile)
        .filter(ImportFile.import_file_id == payload.import_file_id, ImportFile.is_active == True)
        .first()
    )
    if not imp_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ملف الشحنة رقم ({payload.import_file_id}) غير مسجل أو محذوف.",
        )

    # 2. DC-02 / ACID-002: Strict Customs Release Hard-Block if ACID has expired
    if imp_file.acid_expiry_date and not imp_file.is_customs_released:
        today = date.today()
        if imp_file.acid_expiry_date < today:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"حظر الإفراج الجمركي: رقم القيد الجمركي ACID ({imp_file.acid_number or 'غير محدد'}) "
                    f"منتهي الصلاحية منذ {imp_file.acid_expiry_date}. "
                    "لا يجوز إصدار إذن الإفراج الجمركي النهائي إلا بعد تجديد أو تمديد صلاحية الرقم التعريفي عبر منظومة نافذة."
                ),
            )

    # 3. Find or create CustomsClearanceRecord
    record = None
    if payload.clearance_id:
        record = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.customs_clearance_id == payload.clearance_id,
            CustomsClearanceRecord.is_active == True,
        ).first()

    if not record:
        record = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.import_file_id == payload.import_file_id,
            CustomsClearanceRecord.is_active == True,
        ).first()

    if not record:
        clearance_code = generate_customs_clearance_code(db)
        record = CustomsClearanceRecord(
            clearance_code=clearance_code,
            import_file_id=payload.import_file_id,
            customs_office_name=imp_file.port_of_discharge or "Alexandria Port Customs",
            status="Duty Paid - Ready for Final Release",
            owner=imp_file.owner or "Kamal",
            created_by=user,
            updated_by=user,
        )
        db.add(record)

    # 4. Validate duty payment status
    is_duty_paid = (
        record.payment_status in ("Paid & Verified", "Paid", "Duties Paid")
        or imp_file.customs_duty_payment_status == "PAID"
        or (record.duty_paid_amount and record.duty_paid_amount > 0)
        or (imp_file.customs_duty_paid_amount and imp_file.customs_duty_paid_amount > 0)
    )
    if not is_duty_paid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يمكن إصدار أمر الإفراج الجمركي النهائي قبل تأكيد وتوثيق سداد الرسوم الجمركية بنجاح عبر سداد (CL-03).",
        )

    # 5. Validate release permit number
    permit_no = payload.release_permit_no.strip()
    if len(permit_no) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رقم إذن الإفراج الجمركي الأخضر يجب ألا يقل عن 3 أحرف أو أرقام.",
        )

    rel_dt = payload.release_date or datetime.now(timezone.utc)

    # 6. Update CustomsClearanceRecord
    record.release_permit_no = permit_no
    record.release_date = rel_dt
    if payload.release_officer_name:
        record.release_officer_name = payload.release_officer_name
    record.release_type = enum_codes.normalize(enum_codes.RELEASE_TYPE, payload.release_type) or "FINAL_GREEN"
    if payload.release_document_url:
        record.release_document_url = payload.release_document_url
    if payload.gate_pass_number:
        record.gate_pass_number = payload.gate_pass_number
    if payload.port_gate_out_date:
        record.port_gate_out_date = payload.port_gate_out_date
    record.demurrage_storage_fees = payload.demurrage_storage_fees or 0.0
    record.dispatch_authorized = payload.dispatch_authorized
    record.dispatch_date = datetime.now(timezone.utc) if payload.dispatch_authorized else None
    if payload.transport_instructions:
        record.transport_instructions = payload.transport_instructions
    record.status = "Final Release Granted"
    if payload.notes:
        record.notes = (record.notes or "") + f" | إفراج جمركي: {payload.notes}"
    record.updated_at = datetime.now(timezone.utc)
    record.updated_by = user

    # 7. Synchronize ImportFile
    imp_file.is_customs_released = True
    imp_file.customs_released_at = rel_dt
    imp_file.customs_release_permit_no = permit_no
    imp_file.customs_release_type = enum_codes.normalize(enum_codes.RELEASE_TYPE, payload.release_type) or "FINAL_GREEN"
    if payload.release_officer_name:
        imp_file.customs_release_officer = payload.release_officer_name
    if payload.gate_pass_number:
        imp_file.customs_gate_pass_no = payload.gate_pass_number
    imp_file.current_module = "Phase 7 - Customs Clearance & Release"
    imp_file.current_stage = "Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)"
    if (imp_file.progress_percent or 0.0) < 95.0:
        imp_file.progress_percent = 95.0
    imp_file.next_action = "تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01) ومراقبة فترات السماح (TR-02)"
    imp_file.updated_at = datetime.now(timezone.utc)
    imp_file.updated_by = user

    file_label = imp_file.import_file_code or f"IMP-{imp_file.import_file_id}"

    # 8. Complete pending CL-04 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_cl04 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.status != "Completed",
            )
            .all()
        )
        for t in pending_cl04:
            if (
                t.task_type in ("CUSTOMS_FINAL_RELEASE", "CL-04")
                or "CL-04" in (t.title or "")
                or "إفراج" in (t.title or "")
            ):
                t.status = "Completed"
                t.completion_notes = f"تم استلام واعتماد إذن الإفراج النهائي الأخضر برقم ({permit_no}) بتاريخ {rel_dt.strftime('%Y-%m-%d')}."
                t.updated_at = datetime.now(timezone.utc)
    except Exception as ex_task:
        logger.warning("Error completing CL-04 SmartTasks: %s", ex_task)

    # 9. Dispatch Downstream TR-01 & TR-02 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        from datetime import timedelta
        import uuid

        due_dt = (datetime.now(timezone.utc) + timedelta(days=2)).strftime("%Y-%m-%d")

        # TR-01: Inland Transport Coordination
        existing_tr01 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.task_type.in_(["INLAND_TRANSPORT", "TR-01"]),
            )
            .first()
        )
        if not existing_tr01:
            task_code_tr01 = f"TASK-{uuid.uuid4().hex[:8].upper()}"
            db.add(SmartTask(
                task_code=task_code_tr01,
                import_file_id=payload.import_file_id,
                import_file_code=file_label,
                title=f"تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01) — {file_label}".strip(),
                description=f"تم صدور إذن الإفراج النهائي الأخضر برقم ({permit_no}). يرجى تأكيد وحجز شاحنات النقل وتوثيق أرقام السيارات والسائقين لنقل الشحنة من الميناء إلى المستودع.",
                task_type="INLAND_TRANSPORT",
                priority="High",
                status="Pending",
                assigned_user="Logistics Officer",
                due_date=due_dt,
                created_by=user,
            ))

        # TR-02: Demurrage & Detention Radar
        existing_tr02 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == payload.import_file_id,
                SmartTask.task_type.in_(["DEMURRAGE_TRACKING", "TR-02"]),
            )
            .first()
        )
        if not existing_tr02:
            task_code_tr02 = f"TASK-{uuid.uuid4().hex[:8].upper()}"
            db.add(SmartTask(
                task_code=task_code_tr02,
                import_file_id=payload.import_file_id,
                import_file_code=file_label,
                title=f"مراقبة فترات السماح وتفادي غرامات الأرضيات والتأخير (TR-02) — {file_label}".strip(),
                description=f"متابعة خروج الحاويات من الميناء وتفريغها بالمخزن قبل انتهاء فترات السماح ({record.free_days_allowed or imp_file.target_free_days or 14} يوم) لتفادي غرامات الخط الملاحي.",
                task_type="DEMURRAGE_TRACKING",
                priority="Medium",
                status="Pending",
                assigned_user="Operations Team",
                due_date=due_dt,
                created_by=user,
            ))
    except Exception as ex_tr:
        logger.warning("Error dispatching TR tasks: %s", ex_tr)

    # 10. Emit Central SystemNotification
    try:
        from modules.notifications.model import SystemNotification
        db.add(SystemNotification(
            title=f"صدور إذن الإفراج الجمركي الأخضر — {file_label}",
            message=f"صدر إذن الإفراج الجمركي الأخضر النهائي برقم ({permit_no}) للشحنة ({file_label}). تم الترخيص بالصرف والتحميل على سيارات النقل الداخلي (TR-01).",
            category="STAGE_PROGRESSION",
            severity="INFO",
            entity_type="ImportFile",
            entity_id=payload.import_file_id,
            target_role="ALL",
            is_read=False,
        ))
    except Exception as ex_notif:
        logger.warning("Error emitting release notification: %s", ex_notif)

    # 11. Advance LifecycleBoard STEP_17 -> STEP_18
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=payload.import_file_id,
            completed_step_code="STEP_17",
            target_step_codes=["STEP_18"],
            notes=f"صدر أمر الإفراج النهائي الأخضر برقم ({permit_no}). تم ترخيص الصرف والنقل إلى مرحلة النقل والمخازن.",
            assigned_user="Customs Broker",
            custom_stage_title="Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)",
            custom_next_action="تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01)",
            min_progress_percent=95.0,
        )
    except Exception as ex_lb:
        logger.warning("Lifecycle advance STEP_17->STEP_18 failed: %s", ex_lb)

    db.commit()
    db.refresh(record)
    return record


def complete_customs_release_service(db: Session, record_id: int, payload: CompleteReleaseSubmit) -> CustomsClearanceRecord:
    """BP-032 Complete Final Customs Release Order."""
    record = get_customs_clearance_service(db, record_id)

    # DC-02 / ACID-002: Strict Customs Release Hard-Block if ACID has expired and shipment is not already released
    if record.import_file_id:
        imp_file_check = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
        if imp_file_check and imp_file_check.acid_expiry_date and not imp_file_check.is_customs_released:
            today = date.today()
            if imp_file_check.acid_expiry_date < today:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=(
                        f"حظر الإفراج الجمركي: رقم القيد الجمركي ACID ({imp_file_check.acid_number or 'غير محدد'}) "
                        f"منتهي الصلاحية منذ {imp_file_check.acid_expiry_date}. "
                        "لا يجوز إصدار إذن الإفراج الجمركي النهائي إلا بعد تجديد أو تمديد صلاحية الرقم التعريفي عبر منظومة نافذة."
                    ),
                )

    validate_release_permit(payload.release_permit_no, record.payment_status)

    rel_dt = payload.release_date or datetime.now(timezone.utc)
    record.release_permit_no = payload.release_permit_no
    record.release_date = rel_dt
    if payload.release_officer_name:
        record.release_officer_name = payload.release_officer_name
    if payload.release_type:
        record.release_type = enum_codes.normalize(enum_codes.RELEASE_TYPE, payload.release_type)
    if payload.release_document_url:
        record.release_document_url = payload.release_document_url
    if payload.gate_pass_number:
        record.gate_pass_number = payload.gate_pass_number
    if payload.port_gate_out_date:
        record.port_gate_out_date = payload.port_gate_out_date
    record.demurrage_storage_fees = payload.demurrage_storage_fees
    record.dispatch_authorized = payload.dispatch_authorized
    record.dispatch_date = datetime.now(timezone.utc) if payload.dispatch_authorized else None
    if payload.transport_instructions:
        record.transport_instructions = payload.transport_instructions
    record.status = "Final Release Granted"
    if payload.notes:
        record.notes = (record.notes or "") + f" | إفراج: {payload.notes}"
    record.updated_at = datetime.now(timezone.utc)

    # Update import file operational stage and release state
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
    if imp_file:
        imp_file.is_customs_released = True
        imp_file.customs_released_at = rel_dt
        imp_file.customs_release_permit_no = payload.release_permit_no
        if payload.release_type:
            imp_file.customs_release_type = enum_codes.normalize(enum_codes.RELEASE_TYPE, payload.release_type)
        if payload.release_officer_name:
            imp_file.customs_release_officer = payload.release_officer_name
        if payload.gate_pass_number:
            imp_file.customs_gate_pass_no = payload.gate_pass_number
        imp_file.current_module = "Phase 7 - Customs Clearance & Release"
        imp_file.current_stage = "Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)"
        if (imp_file.progress_percent or 0.0) < 95.0:
            imp_file.progress_percent = 95.0
        imp_file.next_action = "تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01) ومراقبة فترات السماح (TR-02)"
        imp_file.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(record)

    # Lifecycle advance: STEP_17 → STEP_18 (Final customs release → Demurrage & Detention)
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            import_file_id=record.import_file_id,
            completed_step_code="STEP_17",
            target_step_codes=["STEP_18"],
            notes=f"صدر أمر الإفراج النهائي برقم ({payload.release_permit_no}). تم نقل الملف إلى مرحلة إدارة الغرامات وفترات السماح.",
            assigned_user="Customs Broker",
            custom_stage_title="Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)",
            custom_next_action="تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01)",
            min_progress_percent=95.0,
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("Lifecycle advance STEP_17→STEP_18 failed: %s", e)

    return record


def _normalize_clearance_update(schema: CustomsClearanceUpdate) -> CustomsClearanceUpdate:
    """Tier-3 fields of a generic update: legacy labels -> enum codes (unknown values unchanged)."""
    changes = {}
    for field_name, enum_type in (
        ("release_type", enum_codes.RELEASE_TYPE),
        ("payment_method", enum_codes.PAYMENT_METHOD),
        ("paying_bank_name", enum_codes.DUTY_BANK),
    ):
        value = getattr(schema, field_name, None)
        if value is not None:
            changes[field_name] = enum_codes.normalize(enum_type, value)
    for field_name in ("regulatory_bodies", "sampled_regulatory_bodies"):
        value = getattr(schema, field_name, None)
        if value is not None:
            changes[field_name] = enum_codes.normalize_list(enum_codes.REGULATORY_BODY, value)
    return schema.model_copy(update=changes) if changes else schema


def update_customs_clearance_service(db: Session, record_id: int, schema: CustomsClearanceUpdate) -> CustomsClearanceRecord:
    existing = get_customs_clearance_service(db, record_id)
    schema = _normalize_clearance_update(schema)
    update_data = schema.model_dump(exclude_unset=True, exclude_none=True)
    old_data = {k: getattr(existing, k, None) for k in update_data.keys()}

    updated = update_customs_clearance(db, record_id, schema)

    if schema.declaration_46_no:
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == updated.import_file_id).first()
        if imp_file:
            imp_file.form46_no = schema.declaration_46_no
            db.commit()

    try:
        from modules.audit_logs.service import AuditLogService
        AuditLogService(db).log_activity(
            entity_type="CustomsClearanceRecord",
            entity_id=updated.customs_clearance_id,
            entity_code=updated.clearance_code,
            action="UPDATE",
            old_data=old_data,
            new_data=update_data,
            performed_by="Customs Broker",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning("AuditLog for CustomsClearanceRecord update failed: %s", e)

    return updated

def delete_customs_clearance_service(db: Session, record_id: int) -> bool:
    get_customs_clearance_service(db, record_id)
    return soft_delete_customs_clearance(db, record_id)

soft_delete_customs_clearance_service = delete_customs_clearance_service


# =========================================================================
# LOG-BOND-003: Under-Bond Clearance & Laboratory Quarantine Services
# =========================================================================

def issue_under_bond_release_service(db: Session, record_id: int, payload: UnderBondReleaseSubmit) -> CustomsClearanceRecord:
    """
    LOG-BOND-003: Conditional Under-Bond Release (السحب على عهدة تحت التحفظ الجمركي).
    Allows moving cargo to factory warehouse to avoid high port demurrage/storage while lab testing is underway.
    Strictly locks goods from being consumed, manufactured, or dispatched.
    """
    record = get_customs_clearance_service(db, record_id)
    if not payload.bond_guarantee_ref or len(payload.bond_guarantee_ref.strip()) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يمكن السحب على عهدة بدون إرفاق رقم التعهد أو خطاب الضمان البنكي/الجمركي المعتمد.",
        )

    record.is_under_bond_release = True
    record.bond_guarantee_ref = payload.bond_guarantee_ref.strip()
    record.quarantine_lock = True
    record.dispatch_authorized = False
    record.lab_test_result = "Pending"
    record.status = "Under Bond Released"
    record.release_date = payload.temporary_release_date
    record.port_gate_out_date = payload.temporary_release_date
    record.notes = (record.notes or "") + f" | تم السحب على عهدة بموجب تعهد #{record.bond_guarantee_ref} لمقر: {payload.customs_warehouse_location}"
    record.updated_at = datetime.now(timezone.utc)

    # Sync to ImportFile
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
    if imp_file:
        imp_file.current_module = "Phase 7 - Customs Clearance & Inspection"
        imp_file.current_stage = "Under-Bond Quarantine (سحب على عهدة)"
        imp_file.next_action = "Awaiting Laboratory Test Results (بانتظار نتيجة المعامل)"

    db.commit()
    db.refresh(record)
    return record


def record_lab_result_and_lift_quarantine_service(db: Session, record_id: int, payload: LabTestResultSubmit) -> CustomsClearanceRecord:
    """
    LOG-BOND-003: Record final laboratory test certificate and lift quarantine lock if conforming.
    """
    record = get_customs_clearance_service(db, record_id)
    if not record.is_under_bond_release:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="هذه الشحنة ليست مقيدة في مسار السحب على عهدة أو التحفظ الجمركي.",
        )

    record.lab_test_result = payload.lab_test_result
    record.lab_certificate_number = payload.lab_certificate_number

    if payload.lab_test_result.lower() in ["conforming", "مطابق", "approved", "مقبول"]:
        if payload.lift_quarantine_lock:
            record.quarantine_lock = False
            record.dispatch_authorized = True
            record.quarantine_lifted_date = payload.test_completion_date or datetime.now(timezone.utc)
            record.quarantine_lifted_by = "Customs Laboratory Authority"
            record.status = "Final Release Granted"

            imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
            if imp_file:
                imp_file.current_stage = "Lab Approved & Final Released"
                imp_file.is_customs_released = True
                imp_file.next_action = "Warehouse Inventory Ready for Dispatch"
    else:
        # Non-conforming
        record.quarantine_lock = True
        record.dispatch_authorized = False
        record.status = "Lab Non-Conforming - Rejected"
        imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == record.import_file_id).first()
        if imp_file:
            imp_file.current_stage = "Lab Rejected (مرفوض معملياً)"
            imp_file.next_action = "Re-export or Disposal (إعادة تصدير أو إعدام)"

    record.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(record)
    return record


def restore_customs_clearance_service(db: Session, record_id: int) -> CustomsClearanceRecord:
    restored = restore_customs_clearance(db, record_id)
    if not restored:
        raise HTTPException(status_code=404, detail="السجل المطلوب استعادته غير موجود.")
    return restored


# ==============================================================================
# CL-05: Clearance Fees & Port Invoices Services (تسجيل فواتير المخلص والعتالة والموانئ)
# ==============================================================================

def generate_clearance_invoice_code(db: Session) -> str:
    """Generate unique sequential code for clearance invoice e.g. CLI-2026-0001"""
    year = datetime.now().year
    count = db.query(ClearanceExpenseInvoice).count() + 1
    return f"CLI-{year}-{count:04d}"


def _recalculate_clearance_expenses_aggregates(db: Session, import_file_id: int, clearance_record_id: Optional[int] = None):
    """Recalculate and update expense totals across clearance record, import file, and landed cost settlement"""
    invoices = db.query(ClearanceExpenseInvoice).filter(
        ClearanceExpenseInvoice.import_file_id == import_file_id,
        ClearanceExpenseInvoice.is_active == True
    ).all()

    total_net = sum(inv.net_payable_egp for inv in invoices)
    total_port = sum(inv.net_payable_egp for inv in invoices if any(k in inv.expense_category.lower() for k in ['port', 'نولون', 'wharfage', 'storage', 'أرضيات']))
    total_handling = sum(inv.net_payable_egp for inv in invoices if any(k in inv.expense_category.lower() for k in ['handling', 'stevedoring', 'عتالة', 'تفريغ', 'حمالة']))

    # Update Clearance Record
    clearance = None
    if clearance_record_id:
        clearance = db.query(CustomsClearanceRecord).filter(CustomsClearanceRecord.customs_clearance_id == clearance_record_id).first()
    if not clearance:
        clearance = db.query(CustomsClearanceRecord).filter(CustomsClearanceRecord.import_file_id == import_file_id).order_by(CustomsClearanceRecord.customs_clearance_id.desc()).first()

    if clearance:
        clearance.clearance_invoices_count = len(invoices)
        clearance.total_clearance_expenses_egp = round(total_net, 2)
        clearance.total_port_expenses_egp = round(total_port, 2)
        clearance.total_handling_expenses_egp = round(total_handling, 2)
        clearance.updated_at = datetime.now(timezone.utc)

    # Update Import File
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if imp_file:
        imp_file.total_clearance_expenses_egp = round(total_net, 2)
        imp_file.clearance_invoices_status = "Invoices Logged & Verified" if len(invoices) > 0 else "Pending Invoices"
        if imp_file.progress_percent < 96.0:
            imp_file.progress_percent = 96.0
        imp_file.next_action = "تنسيق وحجز سيارات النقل الداخلي للمخزن (TR-01) ومتابعة رادار فترات السماح (TR-02)"
        imp_file.updated_at = datetime.now(timezone.utc)

    # Sync to LandedCostSettlementRecord
    try:
        from modules.financial_settlement.model import LandedCostSettlementRecord
        settlement = db.query(LandedCostSettlementRecord).filter(
            LandedCostSettlementRecord.import_file_id == import_file_id,
            LandedCostSettlementRecord.is_active == True
        ).first()

        if settlement:
            # Build list of clearance expense items
            current_invoices = [item for item in (settlement.expense_invoices or []) if not str(item.get("category", "")).startswith("Clearance / ")]
            for inv in invoices:
                current_invoices.append({
                    "invoice_no": inv.invoice_number,
                    "invoice_code": inv.invoice_code,
                    "category": f"Clearance / {enum_codes.label_en(enum_codes.CLEARANCE_EXPENSE_CATEGORY, inv.expense_category)}",
                    "provider_name": inv.provider_name,
                    "currency": inv.currency,
                    "amount_fx": inv.amount_fx,
                    "exchange_rate": inv.exchange_rate,
                    "amount_egp": inv.amount_egp,
                    "vat_amount": inv.vat_amount,
                    "wht_amount": inv.wht_amount,
                    "net_payable_egp": inv.net_payable_egp,
                    "allocation_rule": inv.allocation_rule or "Equal",
                })
            settlement.expense_invoices = current_invoices
            settlement.total_expenses_egp = round(sum(item.get("net_payable_egp", 0.0) for item in current_invoices), 2)
            settlement.updated_at = datetime.now(timezone.utc)
    except Exception as ex:
        print(f"Landed Cost sync notification: {ex}")


def record_clearance_invoice_service(
    db: Session,
    payload: ClearanceExpenseInvoiceCreate,
    current_user: str = "Kamal"
) -> ClearanceExpenseInvoice:
    """
    CL-05: Record clearance invoice / port dues receipt, compute VAT/WHT,
    update aggregates, synchronize with Landed Cost settlement, and close SmartTasks.
    """
    imp_file = db.query(ImportFile).filter(
        ImportFile.import_file_id == payload.import_file_id,
        ImportFile.is_active == True
    ).first()
    if not imp_file:
        raise HTTPException(status_code=404, detail="ملف الشحنة الاستيرادية غير موجود أو محذوف.")

    clearance_id = payload.customs_clearance_id
    if not clearance_id:
        rec = db.query(CustomsClearanceRecord).filter(
            CustomsClearanceRecord.import_file_id == payload.import_file_id,
            CustomsClearanceRecord.is_active == True
        ).order_by(CustomsClearanceRecord.customs_clearance_id.desc()).first()
        if rec:
            clearance_id = rec.customs_clearance_id

    # Compute EGP amounts
    amount_egp = payload.amount_egp
    if (amount_egp is None or amount_egp <= 0.0) and payload.amount_fx > 0:
        amount_egp = round(payload.amount_fx * (payload.exchange_rate or 1.0), 2)

    net_payable = round(amount_egp + (payload.vat_amount or 0.0) - (payload.wht_amount or 0.0), 2)
    inv_code = generate_clearance_invoice_code(db)

    new_invoice = ClearanceExpenseInvoice(
        invoice_code=inv_code,
        import_file_id=payload.import_file_id,
        customs_clearance_id=clearance_id,
        invoice_number=payload.invoice_number.strip(),
        invoice_date=payload.invoice_date or datetime.now(timezone.utc),
        provider_id=payload.provider_id,
        provider_name=payload.provider_name.strip(),
        expense_category=enum_codes.normalize(enum_codes.CLEARANCE_EXPENSE_CATEGORY, payload.expense_category.strip()),
        currency=payload.currency or "EGP",
        amount_fx=payload.amount_fx or 0.0,
        exchange_rate=payload.exchange_rate or 1.0,
        amount_egp=amount_egp,
        vat_included=payload.vat_included,
        vat_amount=payload.vat_amount or 0.0,
        wht_deducted=payload.wht_deducted,
        wht_amount=payload.wht_amount or 0.0,
        net_payable_egp=net_payable,
        payment_status=payload.payment_status or "Unpaid",
        payment_ref=payload.payment_ref,
        document_url=payload.document_url,
        allocation_rule=payload.allocation_rule or "Equal",
        notes=payload.notes,
        is_verified=True,
        is_active=True,
        created_by=current_user,
        updated_by=current_user,
    )

    db.add(new_invoice)
    db.flush()

    # Recalculate totals across clearance record, file, and landed cost
    _recalculate_clearance_expenses_aggregates(db, payload.import_file_id, clearance_id)

    # Auto-complete pending CL-05 SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == payload.import_file_id,
            SmartTask.status.in_(["Pending", "In Progress"])
        ).all()
        for t in pending_tasks:
            t_name = (t.task_name or "").lower()
            t_code = (t.task_code or "").upper()
            if "cl-05" in t_name or "فواتير المخلص" in t_name or "أتعاب التخليص" in t_name or "مصاريف التخليص" in t_name or t_code in ["CL-05", "TSK-0205"]:
                t.status = "Completed"
                t.completed_at = datetime.now(timezone.utc)
                t.notes = f"تم تسجيل فاتورة التخليص برقم {new_invoice.invoice_number} بمبلغ {new_invoice.net_payable_egp:,.2f} ج.م"
    except Exception as ex:
        print(f"SmartTasks completion warning: {ex}")

    # Emit SystemNotification
    try:
        from modules.notifications.service import create_system_notification
        from modules.notifications.schemas import SystemNotificationCreate
        create_system_notification(
            db,
            SystemNotificationCreate(
                recipient_role="Accounting & Operations",
                title="تسجيل فاتورة تخليص ومصاريف موانئ (CL-05)",
                message=f"تم تسجيل فاتورة {enum_codes.label_en(enum_codes.CLEARANCE_EXPENSE_CATEGORY, new_invoice.expense_category)} برقم ({new_invoice.invoice_number}) بمبلغ {new_invoice.net_payable_egp:,.2f} ج.م للمقدم {new_invoice.provider_name} للشحنة {imp_file.import_file_code}.",
                priority="NORMAL",
                reference_type="CustomsClearanceInvoice",
                reference_id=str(new_invoice.invoice_id),
            )
        )
    except Exception:
        pass

    db.commit()
    db.refresh(new_invoice)
    return new_invoice


def get_clearance_invoices_by_file_service(
    db: Session,
    import_file_id: int
) -> ClearanceInvoicesSummaryResponse:
    """
    Get all active clearance invoices for an import file with category summaries.
    """
    invoices = db.query(ClearanceExpenseInvoice).filter(
        ClearanceExpenseInvoice.import_file_id == import_file_id,
        ClearanceExpenseInvoice.is_active == True
    ).order_by(ClearanceExpenseInvoice.invoice_id.desc()).all()

    total_amount = sum(inv.amount_egp for inv in invoices)
    total_vat = sum(inv.vat_amount for inv in invoices)
    total_wht = sum(inv.wht_amount for inv in invoices)
    net_payable = sum(inv.net_payable_egp for inv in invoices)

    total_clearance_fees = sum(inv.net_payable_egp for inv in invoices if any(k in inv.expense_category.lower() for k in ['broker', 'أتعاب', 'تخليص', 'clearance']))
    total_port_dues = sum(inv.net_payable_egp for inv in invoices if any(k in inv.expense_category.lower() for k in ['port', 'نولون', 'wharfage', 'storage', 'أرضيات', 'موانئ']))
    total_handling = sum(inv.net_payable_egp for inv in invoices if any(k in inv.expense_category.lower() for k in ['handling', 'stevedoring', 'عتالة', 'تفريغ', 'حمالة']))
    total_other = round(net_payable - (total_clearance_fees + total_port_dues + total_handling), 2)
    if total_other < 0:
        total_other = 0.0

    return ClearanceInvoicesSummaryResponse(
        import_file_id=import_file_id,
        invoices_count=len(invoices),
        total_amount_egp=round(total_amount, 2),
        total_vat_egp=round(total_vat, 2),
        total_wht_egp=round(total_wht, 2),
        net_payable_egp=round(net_payable, 2),
        total_clearance_fees_egp=round(total_clearance_fees, 2),
        total_port_dues_egp=round(total_port_dues, 2),
        total_handling_stevedoring_egp=round(total_handling, 2),
        total_other_expenses_egp=round(total_other, 2),
        invoices=[ClearanceExpenseInvoiceResponse.model_validate(inv) for inv in invoices],
    )


def delete_clearance_invoice_service(
    db: Session,
    invoice_id: int,
    current_user: str = "Kamal"
) -> bool:
    """
    Soft-delete clearance invoice and update totals across file and landed cost.
    """
    inv = db.query(ClearanceExpenseInvoice).filter(
        ClearanceExpenseInvoice.invoice_id == invoice_id,
        ClearanceExpenseInvoice.is_active == True
    ).first()
    if not inv:
        raise HTTPException(status_code=404, detail="فاتورة التخليص غير موجودة أو محذوفة.")

    inv.is_active = False
    inv.updated_by = current_user
    inv.updated_at = datetime.now(timezone.utc)
    import_file_id = inv.import_file_id
    clearance_id = inv.customs_clearance_id
    db.flush()

    _recalculate_clearance_expenses_aggregates(db, import_file_id, clearance_id)
    db.commit()
    return True

