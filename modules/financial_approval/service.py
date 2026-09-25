"""
Service Layer & Business Engine for Financial Approval (BP-012 & BP-013)
"""

from datetime import date, datetime, timezone, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from modules.financial_approval.model import (
    PaymentRequestSession,
    ImportBudgetApproval,
    BudgetVarianceLog,
    BudgetVarianceSetting,
    SwiftExtractionBatch,
    SwiftExtractionField,
    OcrCorrectionsLog,
)
from modules.users.model import User
from modules.notifications.model import SystemNotification
from modules.financial_approval.schemas import (
    PaymentRequestCreate,
    PaymentRequestResponse,
    ClonePaymentRequestRequest,
    PaymentRequestUpdate,
    SwiftReconciliationRequest,
    ImportBudgetCreate,
    CloneImportBudgetRequest,
    ImportBudgetUpdate,
    BudgetPrefillResponse,
    LinkedPOItemSchema,
    SmartSwiftExtractRequest,
    SmartSwiftExtractResponse,
    SmartSwiftReconcileRequest,
    SwiftFieldResponse,
    SwiftBatchResponse,
    SwiftFieldUpdateRequest,
    SwiftBatchConfirmRequest,
    SwiftBatchConfirmResponse,
    SwiftBatchMatchResponse,
    SwiftBatchReconcileRequest,
    BudgetVarianceLogResponse,
    BudgetVarianceOverrideRequest,
    BudgetVarianceSettingResponse,
    BudgetVarianceSettingUpdate,
    BudgetSyncResultResponse,
    ImportBudgetResponse,
)
import modules.financial_approval.repository as repo
from modules.financial_approval.validators import (
    validate_payment_request_inputs,
    validate_status_transition,
)


def create_payment_request_service(
    db: Session, schema: PaymentRequestCreate
) -> PaymentRequestSession:
    """Service to validate and create Payment Request with duplicate prevention per payment type."""
    validate_payment_request_inputs(
        db=db,
        requested_amount=schema.requested_amount,
        po_id=schema.po_id,
        supplier_id=schema.supplier_id,
    )

    if schema.import_file_id:
        existing = repo.get_all_payment_requests(db, import_file_id=schema.import_file_id)
        # Prevent active duplicate of the same payment type for the same import file
        active_same_type = [
            p for p in existing
            if p.is_active and p.payment_type == schema.payment_type and p.status in ("Draft", "Pending Approval", "Approved")
        ]
        if active_same_type:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"يوجد بالفعل طلب سداد مالي قيد الإجراء من نوع '{schema.payment_type}' محفوظ لهذا الملف ({active_same_type[0].payment_code}). يرجى الذهاب لتعديله أو استخدام نوع سداد آخر.",
            )

    db_item = repo.create_payment_request(db, schema)

    # 1. Resolve Import File Code for notifications and tasks
    file_code = f"IMP-{schema.import_file_id}" if schema.import_file_id else "No File"
    if schema.import_file_id:
        from modules.import_files.model import ImportFile
        imp = db.query(ImportFile).filter(ImportFile.import_file_id == schema.import_file_id).first()
        if imp:
            file_code = imp.import_file_code or imp.custom_file_number or f"IMP-{schema.import_file_id}"

    # 2. Automated Notification for Finance Department (Dashboard & In-App Alert)
    notif_title = (
        f"💳 طلب سداد دفعة مقدمة للمورد: {db_item.payment_code}"
        if db_item.payment_type == "Advance Payment"
        else f"💳 طلب سداد مالي جديد: {db_item.payment_code}"
    )
    notif_msg = (
        f"تم إصدار طلب سداد دفعة مقدمة للمورد ({db_item.supplier_name}) بمبلغ {db_item.requested_amount:,.2f} {db_item.currency_code} ({db_item.requested_amount_egp:,.2f} ج.م) للشحنة ({file_code}). يستحق في {db_item.due_date}. يتطلب المراجعة والاعتماد وسداد السويفت البنكي."
        if db_item.payment_type == "Advance Payment"
        else f"تم إصدار طلب سداد مالي للمورد ({db_item.supplier_name}) بمبلغ {db_item.requested_amount:,.2f} {db_item.currency_code} ({db_item.requested_amount_egp:,.2f} ج.م). يستحق في {db_item.due_date}."
    )
    notif = SystemNotification(
        title=notif_title,
        message=notif_msg,
        severity="WARNING" if db_item.payment_type == "Advance Payment" else "INFO",
        category="PAYMENT_REQUEST",
        entity_type="PaymentRequest",
        entity_id=db_item.payment_id,
        target_role="FINANCE_OFFICER",
    )
    db.add(notif)

    # 3. Automated Smart Task for Finance Department
    try:
        from modules.smart_tasks.repository import create_task as create_smart_task
        from modules.smart_tasks.schemas import SmartTaskCreate

        smart_task_title = (
            f"سداد الدفعة المقدمة للمورد وحساب السويفت: {db_item.supplier_name} ({db_item.payment_code})"
            if db_item.payment_type == "Advance Payment"
            else f"سداد مستحقات المورد: {db_item.supplier_name} ({db_item.payment_code})"
        )
        smart_task_desc = (
            f"سداد دفعة المورد بمبلغ {db_item.requested_amount:,.2f} {db_item.currency_code} ({db_item.requested_amount_egp:,.2f} ج.م) المستحقة في {db_item.due_date} للشحنة ({file_code}) ومطابقة إشعار التحويل البنكي MT103/SWIFT."
        )
        task_schema = SmartTaskCreate(
            title=smart_task_title,
            description=smart_task_desc,
            task_type="System Generated",
            import_file_id=db_item.import_file_id,
            import_file_code=file_code if schema.import_file_id else None,
            phase_name="المرحلة الثانية: بداية الشحنة والمالية",
            assigned_user="Finance Officer",
            priority="High",
            reminder_type="Advance Payment" if db_item.payment_type == "Advance Payment" else "Payment Request",
            due_date=str(db_item.due_date),
            status="Pending",
            notes=f"REQ_TYPE:ADVANCE_PAYMENT | Code: {db_item.payment_code} | PayId: {db_item.payment_id}",
        )
        created_task = create_smart_task(db, task_schema, created_by="Financial Approval Engine")
        setattr(db_item, "smart_task_code", created_task.task_code)
    except Exception:
        pass

    # 4. Lifecycle Board Auto-Advancement to STEP_04 (Phase 2: Approvals & ACID)
    if schema.import_file_id:
        try:
            from modules.lifecycle_board.service import advance_lifecycle_step_service
            advance_lifecycle_step_service(
                db=db,
                completed_step_code="STEP_03",
                import_file_id=db_item.import_file_id,
                target_step_codes=["STEP_04"],
                auto_complete_prior=True,
                assigned_user="Finance Officer",
                notes=f"تم إصدار طلب سداد الدفعة المقدمة للمورد ({db_item.payment_code}) بمبلغ {db_item.requested_amount:,.2f} {db_item.currency_code}",
                source_module="Financial Approval Lifecycle",
                custom_stage_title="المرحلة الثانية: بداية الشحنة",
                custom_module_name="STEP_04 اعتمادات الميزانية وسداد الموردين",
                custom_next_action="STEP_04 مراجعة واعتماد سداد الدفعة المقدمة للمورد وتجهيز السويفت البنكي",
                min_progress_percent=30.0,
            )
        except Exception:
            pass

    db.commit()
    db.refresh(db_item)
    return db_item


def update_payment_request_service(
    db: Session, payment_id: int, schema: PaymentRequestUpdate, current_user_name: Optional[str] = None
) -> PaymentRequestSession:
    db_item = repo.get_payment_request_by_id(db, payment_id)
    if not db_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payment_id} not found.",
        )

    if schema.status and schema.status != db_item.status:
        validate_status_transition(db_item.status, schema.status)

    return repo.update_payment_request(db, db_item, schema, current_user_name=current_user_name)


def _handle_swift_payment_completion_workflow(
    db: Session,
    db_item: PaymentRequestSession,
    swift_reference_no: Optional[str] = None,
    transferred_amount: Optional[float] = None,
    currency_code: Optional[str] = None,
) -> None:
    """
    Central business engine workflow triggered whenever a Payment Request is marked Paid
    or reconciled with SWIFT MT103 confirmation:
    1. Ensures db_item status is 'Paid' and captures SWIFT reference.
    2. Synchronizes swift_no to linked ImportFile.
    3. Auto-advances ImportFile lifecycle from STEP_04 to STEP_05 (ACID Operations & Nafeza).
    4. Auto-completes prior pending payment SmartTasks.
    5. Dispatches SmartTask for Logistics Officer to obtain ACID number on Nafeza.
    6. Emits SystemNotification for LOGISTICS_OFFICER.
    """
    swift_ref = swift_reference_no or db_item.swift_reference_no or f"SWF-{db_item.payment_id}"
    amt = float(transferred_amount or db_item.swift_transferred_amount or db_item.requested_amount or 0.0)
    curr = currency_code or db_item.swift_transferred_currency or db_item.currency_code or "USD"

    db_item.status = "Paid"
    db_item.swift_reference_no = swift_ref

    if not db_item.import_file_id:
        return

    from modules.import_files.model import ImportFile
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == db_item.import_file_id).first()
    if not imp:
        return

    # Update swift_no on ImportFile
    imp.swift_no = swift_ref
    file_code = imp.import_file_code or f"IMP-{imp.import_file_id}"

    # Auto-complete pending advance payment SmartTasks
    try:
        from modules.smart_tasks.model import SmartTask
        open_tasks = db.query(SmartTask).filter(
            SmartTask.import_file_id == imp.import_file_id,
            SmartTask.status.in_(["Pending", "In Progress"]),
            SmartTask.is_active == True,
        ).all()
        for t in open_tasks:
            t_notes = t.notes or ""
            t_title = t.title or ""
            if (
                (db_item.payment_code and db_item.payment_code in (t_notes + t_title))
                or (f"PayId: {db_item.payment_id}" in t_notes)
                or ("سداد الدفعة" in t_title)
                or (t.reminder_type in ["Advance Payment", "Payment Request"])
            ):
                t.status = "Completed"
                t.is_auto_closed = True
    except Exception:
        pass

    # Auto-advance lifecycle from STEP_04 to STEP_05
    try:
        from modules.lifecycle_board.service import advance_lifecycle_step_service
        advance_lifecycle_step_service(
            db=db,
            completed_step_code="STEP_04",
            import_file_id=imp.import_file_id,
            target_step_codes=["STEP_05"],
            auto_complete_prior=True,
            assigned_user="Logistics Officer",
            notes=f"تم سداد الحوالة البنكية وسويفت MT103 رقم {swift_ref} بمبلغ {amt:,.2f} {curr}",
            source_module="Financial SWIFT Engine",
            custom_stage_title="Phase 2: Approvals & ACID",
            custom_module_name="STEP_05 إصدار رقم ACID نافذة",
            custom_next_action="STEP_05 طلب واستخراج رقم القيد الجمركي المبدئي (ACID) عبر منظومة نافذة",
            min_progress_percent=35.0,
        )
    except Exception:
        pass

    # Emit SystemNotification to LOGISTICS_OFFICER
    try:
        notif = SystemNotification(
            title=f"تم سداد الدفعة وحوالة السويفت - جاهز لطلب ACID ({file_code})",
            message=f"تم تأكيد سداد التحويل البنكي وحوالة السويفت رقم ({swift_ref}) بمبلغ ({amt:,.2f} {curr}) للملف الاستيرادي ({file_code}). تم فتح مرحلة استخراج ACID عبر نافذة.",
            severity="INFO",
            category="DUTY_PAYMENT",
            entity_type="PaymentRequest",
            entity_id=db_item.payment_id,
            target_role="LOGISTICS_OFFICER",
        )
        db.add(notif)
    except Exception:
        pass

    # Create explicit SmartTask for Logistics Officer to obtain ACID if not already present
    try:
        from modules.smart_tasks.model import SmartTask
        from modules.smart_tasks.schemas import SmartTaskCreate
        from modules.smart_tasks.repository import create_task as create_smart_task

        acid_task_exists = db.query(SmartTask).filter(
            SmartTask.import_file_id == imp.import_file_id,
            SmartTask.title.ilike("%ACID%"),
            SmartTask.status.in_(["Pending", "In Progress"]),
            SmartTask.is_active == True,
        ).first()

        if not acid_task_exists:
            task_schema = SmartTaskCreate(
                title=f"[{file_code}] — استخراج الرقم التعريفي المبدئي للشحنة ACID عبر نافذة",
                description=f"تم تحويل السويفت البنكي بنجاح برقم {swift_ref}. المطلوب الآن استخراج الرقم المبدئي ACID للشحنة ({file_code}) عبر منصة نافذة ورفع المستندات الأولية.",
                task_type="System Generated",
                import_file_id=imp.import_file_id,
                import_file_code=file_code,
                phase_name="Phase 2: Approvals & ACID",
                assigned_user="Logistics Officer",
                priority="High",
                reminder_type="ACID Operations",
                due_date=str(date.today() + timedelta(days=3)),
                status="Pending",
                notes=f"ACTION:ISSUE_ACID | SwiftRef: {swift_ref} | PayId: {db_item.payment_id}",
            )
            create_smart_task(db, task_schema, created_by="Financial SWIFT Engine")
    except Exception:
        pass


def approve_payment_request_service(
    db: Session, payment_id: int
) -> PaymentRequestSession:
    """Approves a payment request and emits notification to Finance Officer."""
    db_item = repo.get_payment_request_by_id(db, payment_id)
    if not db_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payment_id} not found.",
        )

    db_item.status = "Approved"

    # Emit SystemNotification for Finance Officer
    try:
        from modules.import_files.model import ImportFile
        file_code = None
        if db_item.import_file_id:
            imp = db.query(ImportFile).filter(ImportFile.import_file_id == db_item.import_file_id).first()
            if imp:
                file_code = imp.import_file_code
        ref_text = f" للملف ({file_code})" if file_code else ""
        notif = SystemNotification(
            title=f"تمت الموافقة على طلب الصرف: {db_item.payment_code}",
            message=f"تمت الموافقة على طلب الصرف رقم ({db_item.payment_code}){ref_text} بمبلغ {db_item.requested_amount:,.2f} {db_item.currency_code} لصالح المورد ({db_item.supplier_name}). الطلب جاهز للتنفيذ والتحويل البنكي.",
            severity="INFO",
            category="DUTY_PAYMENT",
            entity_type="PaymentRequest",
            entity_id=db_item.payment_id,
            target_role="FINANCE_OFFICER",
        )
        db.add(notif)
    except Exception:
        pass

    db.commit()
    db.refresh(db_item)
    return db_item


def execute_payment_service(
    db: Session, payment_id: int, swift_reference_no: str | None = None
) -> PaymentRequestSession:
    """Marks payment request as Paid once SWIFT transfer copy is generated."""
    db_item = repo.get_payment_request_by_id(db, payment_id)
    if not db_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payment_id} not found.",
        )

    db_item.status = "Paid"
    if swift_reference_no:
        db_item.swift_reference_no = swift_reference_no

    _handle_swift_payment_completion_workflow(
        db=db,
        db_item=db_item,
        swift_reference_no=swift_reference_no or db_item.swift_reference_no,
        transferred_amount=float(db_item.swift_transferred_amount or db_item.requested_amount or 0.0),
        currency_code=db_item.swift_transferred_currency or db_item.currency_code,
    )

    db.commit()
    db.refresh(db_item)
    return db_item


def reconcile_swift_service(
    db: Session, payment_id: int, payload: SwiftReconciliationRequest
) -> PaymentRequestSession:
    """
    Reconciles SWIFT Confirmation against Payment Request:
    - Calculates turnaround days between request_date and swift_receipt_date.
    - Compares swift_transferred_amount against requested_amount.
    - Calculates variance (swift_transferred_amount - requested_amount).
    - Determines variance status: 'Matched' (diff == 0), 'Deficit' (diff < 0), 'Surplus' (diff > 0).
    - Automatically updates linked Import File's `swift_no` in import_files table.
    - Advances lifecycle stage to STEP_05 and creates ACID tasks for Logistics Officer.
    - Sets Payment Request status to 'Paid'.
    """
    db_item = repo.get_payment_request_by_id(db, payment_id)
    if not db_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payment_id} not found.",
        )

    # 1. Processing turnaround days
    req_date = db_item.request_date or date.today()
    receipt_date = payload.swift_receipt_date
    processing_days = max(0, (receipt_date - req_date).days)

    # 2. Variance calculation
    variance = round(payload.swift_transferred_amount - db_item.requested_amount, 2)
    if abs(variance) < 0.01:
        variance_status = "Matched"
    elif variance < 0:
        variance_status = "Deficit"
    else:
        variance_status = "Surplus"

    # 3. Update payment request session
    db_item.swift_reference_no = payload.swift_reference_no
    db_item.swift_receipt_date = payload.swift_receipt_date
    db_item.swift_transferred_amount = payload.swift_transferred_amount
    db_item.swift_transferred_currency = payload.swift_transferred_currency
    db_item.swift_variance_amount = variance
    db_item.swift_variance_status = variance_status
    db_item.swift_processing_days = processing_days
    db_item.swift_reconciliation_notes = payload.swift_reconciliation_notes
    db_item.status = "Paid"

    # 4. Handle SWIFT payment completion workflow (Lifecycle sync, SmartTask, SystemNotification)
    _handle_swift_payment_completion_workflow(
        db=db,
        db_item=db_item,
        swift_reference_no=payload.swift_reference_no,
        transferred_amount=payload.swift_transferred_amount,
        currency_code=payload.swift_transferred_currency,
    )

    db.commit()
    db.refresh(db_item)
    return db_item


def clone_payment_request_service(
    db: Session, payment_id: int, schema: ClonePaymentRequestRequest
) -> PaymentRequestSession:
    """
    Clones an existing Payment Request into a new Draft record:
    - Generates new unique payment code via repo.generate_payment_code(db).
    - Status is reset to 'Draft'.
    - Payment/SWIFT execution fields are reset: is_paid=False, paid_at=None, swift_reference_no=None,
      swift_receipt_date=None, swift_transferred_amount=None, swift_transferred_currency=None,
      swift_variance_amount=None, swift_variance_status='Pending', swift_processing_days=None,
      swift_reconciliation_notes=None.
    - Dates are set to current date: request_date=date.today(), due_date=date.today() + 12 days.
    - If unlink_import_file is True, import_file_id and po_id are reset to None.
    - If target_supplier_id is specified, supplier is updated.
    - Title is set to schema.new_title or f"{orig.title} (نسخة)".
    """
    from datetime import timedelta

    orig = repo.get_payment_request_by_id(db, payment_id)
    if not orig:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payment_id} not found.",
        )

    code = repo.generate_payment_code(db)
    req_date = date.today()
    due_date = date.today() + timedelta(days=12)

    title = schema.new_title or f"{orig.title} (نسخة)"
    supplier_id = schema.target_supplier_id or orig.supplier_id
    supplier_name = orig.supplier_name
    beneficiary_name = orig.beneficiary_name

    if schema.target_supplier_id and schema.target_supplier_id != orig.supplier_id:
        from modules.suppliers.model import Supplier
        sup = db.query(Supplier).filter(Supplier.supplier_id == schema.target_supplier_id).first()
        if sup:
            supplier_name = sup.company_name
            beneficiary_name = sup.company_name

    amount = schema.new_requested_amount if schema.new_requested_amount is not None else orig.requested_amount
    rate = orig.exchange_rate or 50.0
    egp_amount = amount * rate

    import_file_id = None if schema.unlink_import_file else orig.import_file_id
    po_id = None if schema.unlink_import_file else orig.po_id

    notes = orig.notes
    if schema.remarks:
        notes = f"{notes}\n{schema.remarks}".strip() if notes else schema.remarks

    cloned = PaymentRequestSession(
        payment_code=code,
        title=title,
        import_file_id=import_file_id,
        po_id=po_id,
        supplier_id=supplier_id,
        supplier_name=supplier_name,
        project_id=orig.project_id,
        payment_type=orig.payment_type,
        requested_amount=amount,
        currency_code=orig.currency_code,
        exchange_rate=rate,
        requested_amount_egp=egp_amount,
        request_date=req_date,
        due_date=due_date,
        status="Draft",
        beneficiary_name=beneficiary_name,
        bank_name=orig.bank_name,
        swift_code=orig.swift_code,
        iban_account_no=orig.iban_account_no,
        bank_country=orig.bank_country,
        notes=notes,
        is_active=True,
    )
    db.add(cloned)
    db.commit()
    db.refresh(cloned)
    return cloned


# --- IMPORT BUDGET SERVICE ---
def create_import_budget_service(
    db: Session, schema: ImportBudgetCreate
) -> ImportBudgetApproval:
    """Creates import budget approval with duplicate prevention."""
    if schema.import_file_id:
        existing = repo.get_all_import_budgets(db, import_file_id=schema.import_file_id)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="يوجد بالفعل اعتماد ميزانية محفوظ لهذا الملف. يرجى الذهاب لتعديل الميزانية الحالية بدلاً من إنشاء اعتماد جديد.",
            )

    created = repo.create_import_budget(db, schema)
    if schema.import_file_id:
        try:
            from modules.lifecycle_board.service import sync_budget_lifecycle_stage
            is_approved = (created.budget_status == "Budget Approved")
            sync_budget_lifecycle_stage(db, schema.import_file_id, is_approved=is_approved, approved_by=created.approved_by)
        except Exception:
            pass
    return created


def approve_import_budget_service(
    db: Session, budget_id: int, approved_by: str = "Finance Manager"
) -> ImportBudgetApproval:
    db_item = repo.get_import_budget_by_id(db, budget_id)
    if not db_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import Budget ID {budget_id} not found.",
        )

    if db_item.has_unresolved_variance and not db_item.variance_override_reason:
        hard_block_log = db.query(BudgetVarianceLog).filter(
            BudgetVarianceLog.budget_id == budget_id,
            BudgetVarianceLog.resolution_type == "pending",
            BudgetVarianceLog.is_hard_block == True,
        ).first()
        if hard_block_log:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"لا يمكن اعتماد الميزانية لوجود فارق تكاليف غير مسوى يتجاوز العتبة المحددة ({hard_block_log.variance_percentage:.1f}% في {hard_block_log.field_name} - Hard Block). يجب مزامنة التكاليف أولاً أو تقديم مبرر مكتوب إجباري لتجاوز الحظر.",
            )

    db_item.budget_status = "Budget Approved"
    db_item.approved_by = approved_by
    db_item.approved_date = date.today()

    file_code = None
    if db_item.import_file_id:
        from modules.import_files.model import ImportFile
        imp = db.query(ImportFile).filter(ImportFile.import_file_id == db_item.import_file_id).first()
        if imp:
            file_code = imp.import_file_code

    # Emit System Notification
    try:
        ref_text = f" للملف ({file_code})" if file_code else ""
        notif = SystemNotification(
            title=f"تم اعتماد الميزانية التقديرية: {db_item.budget_code}",
            message=f"تم اعتماد الميزانية التقديرية ({db_item.budget_code}){ref_text} بإجمالي {db_item.total_budget_egp:,.2f} ج.م من قبل {approved_by}.",
            severity="INFO",
            category="DUTY_PAYMENT",
            entity_type="ImportBudget",
            entity_id=db_item.budget_id,
            target_role="FINANCE_OFFICER",
        )
        db.add(notif)
    except Exception:
        pass

    # Auto-complete pending budget review/approval SmartTasks
    if db_item.import_file_id:
        try:
            from modules.smart_tasks.model import SmartTask
            tasks = db.query(SmartTask).filter(
                SmartTask.import_file_id == db_item.import_file_id,
                SmartTask.status.in_(["Pending", "In Progress"]),
                SmartTask.is_active == True,
            ).all()
            for t in tasks:
                t_title = t.title or ""
                t_notes = t.notes or ""
                if (
                    "الميزانية" in t_title
                    or "BUDGET" in t_notes
                    or (db_item.budget_code and db_item.budget_code in (t_notes + t_title))
                ):
                    t.status = "Completed"
                    t.is_auto_closed = True
        except Exception:
            pass

    db.commit()
    db.refresh(db_item)

    if db_item.import_file_id:
        try:
            from modules.lifecycle_board.service import sync_budget_lifecycle_stage
            sync_budget_lifecycle_stage(db, db_item.import_file_id, is_approved=True, approved_by=approved_by)
        except Exception:
            pass

    return db_item


def clone_import_budget_service(
    db: Session, budget_id: int, schema: CloneImportBudgetRequest
) -> ImportBudgetApproval:
    """
    Clones an existing Import Budget into a new record:
    - Generates new unique budget code via repo.generate_budget_code(db).
    - Status is reset to 'Pending Review' (Draft).
    - Approval fields are reset: approved_by=None, approved_date=None.
    - If unlink_import_file is True, import_file_id is set to None.
    - If target_import_file_id is provided, validates that no existing budget conflicts.
    - If new_exchange_rate is provided, recalculates invoice_amount_egp and freight_cost_egp.
    - Title is set to schema.new_title or f"{orig.title} (نسخة)".
    - total_budget_egp is recalculated dynamically.
    - Notes append remarks if provided.
    """
    orig = repo.get_import_budget_by_id(db, budget_id)
    if not orig:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import Budget ID {budget_id} not found.",
        )

    target_file_id = None
    if not schema.unlink_import_file:
        target_file_id = schema.target_import_file_id or orig.import_file_id

    if target_file_id:
        existing = repo.get_all_import_budgets(db, import_file_id=target_file_id)
        if target_file_id != orig.import_file_id and existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"يوجد بالفعل اعتماد ميزانية محفوظ لملف الاستيراد المستهدف ({target_file_id}).",
            )
        elif target_file_id == orig.import_file_id:
            # When cloning within the same file without unlinking, unlink by default to prevent duplicate key/logic clash
            target_file_id = None

    code = repo.generate_budget_code(db)
    title = schema.new_title or f"{orig.title} (نسخة)"
    rate = schema.new_exchange_rate if (schema.new_exchange_rate and schema.new_exchange_rate > 0) else orig.exchange_rate

    inv_foreign = orig.invoice_amount_foreign
    frt_foreign = orig.freight_cost_foreign
    inv_egp = inv_foreign * rate if inv_foreign > 0 else orig.invoice_amount_egp
    frt_egp = frt_foreign * rate if frt_foreign > 0 else orig.freight_cost_egp
    cust_egp = orig.customs_duties_egp
    clr_egp = orig.clearance_inland_egp
    total_budget_egp = inv_egp + frt_egp + cust_egp + clr_egp

    notes = orig.notes
    if schema.remarks:
        notes = f"{notes}\n{schema.remarks}".strip() if notes else schema.remarks

    cloned = ImportBudgetApproval(
        budget_code=code,
        title=title,
        import_file_id=target_file_id,
        po_id=None if schema.unlink_import_file else orig.po_id,
        project_id=orig.project_id,
        invoice_amount_foreign=inv_foreign,
        invoice_currency=orig.invoice_currency,
        invoice_amount_egp=inv_egp,
        freight_cost_foreign=frt_foreign,
        freight_currency=orig.freight_currency,
        freight_cost_egp=frt_egp,
        customs_duties_egp=cust_egp,
        clearance_inland_egp=clr_egp,
        exchange_rate=rate,
        total_budget_egp=total_budget_egp,
        budget_status="Pending Review",
        approved_by=None,
        approved_date=None,
        notes=notes,
        is_active=True,
    )
    db.add(cloned)
    db.commit()
    db.refresh(cloned)
    return cloned


# --- CROSS-MODULE PREFILL & AGGREGATOR ENGINE ---
def get_budget_prefill_service(
    db: Session, import_file_id: int
) -> BudgetPrefillResponse:
    """
    Cross-module aggregation engine for Payment Requests and Budget Approval.
    Pulls data from:
    1. Import Files & Linked Purchase Orders (Invoice Amounts & Payment Terms)
    2. Foreign Supplier Master Data (Bank Details, SWIFT, Account No, IBAN)
    3. Shipping Scenarios (Highest Estimated Freight Rate)
    4. Customs Consultation Engine (Estimated Customs Duty, VAT, & Broker Fees)
    """
    from modules.import_files.model import ImportFile
    from modules.purchase_orders.model import PurchaseOrder
    from modules.shipping_scenarios.model import ShippingEvaluationSession
    from modules.customs_consultation.model import CustomsConsultationSession
    from modules.suppliers.model import Supplier
    from modules.projects.model import Project

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not imp:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import File with ID {import_file_id} not found.",
        )

    # 1. Fetch Linked Purchase Orders
    po_query = db.query(PurchaseOrder).filter(PurchaseOrder.is_active == True)
    if imp.po_ids and isinstance(imp.po_ids, list):
        pos = po_query.filter(
            (PurchaseOrder.import_file_id == import_file_id) | (PurchaseOrder.po_id.in_(imp.po_ids))
        ).all()
    else:
        pos = po_query.filter(PurchaseOrder.import_file_id == import_file_id).all()

    linked_pos_schemas: List[LinkedPOItemSchema] = []
    total_invoice = 0.0
    invoice_curr = "USD"
    payment_terms_set = set()
    terms_list_str = []

    from modules.currencies.model import Currency

    # Batch preload linked projects and currencies to eliminate N+1 queries
    project_ids = [po.project_id for po in pos if po.project_id]
    prj_map = (
        {p.project_id: p.project_name for p in db.query(Project).filter(Project.project_id.in_(project_ids)).all()}
        if project_ids
        else {}
    )

    currency_ids = [po.currency_id for po in pos if po.currency_id]
    curr_map = (
        {c.currency_id: c.currency_code for c in db.query(Currency).filter(Currency.currency_id.in_(currency_ids)).all()}
        if currency_ids
        else {}
    )

    for po in pos:
        prj_name = prj_map.get(po.project_id)

        p_term = po.payment_terms or "Standard Payment"
        payment_terms_set.add(p_term)
        terms_list_str.append(f"{po.po_number} ({p_term})")
        
        curr_code = curr_map.get(po.currency_id, "USD")
        if po.currency_id and po.currency_id in curr_map:
            invoice_curr = curr_code

        po_amt = float(po.total_amount_fob or 0.0)
        if po_amt == 0.0 and po.items:
            po_amt = sum(float(it.quantity or 0.0) * float(it.unit_price or 0.0) for it in po.items)
            
        total_invoice += po_amt

        linked_pos_schemas.append(
            LinkedPOItemSchema(
                po_id=po.po_id,
                po_number=po.po_number,
                pi_number=po.proforma_invoice_number,
                project_id=po.project_id,
                project_name=prj_name,
                payment_terms=p_term,
                currency=curr_code,
                total_amount=po_amt,
                status=po.status,
            )
        )

    # If no purchase orders linked yet or total is 0, check invoices_data recorded in ImportFile
    if total_invoice == 0.0 and imp.invoices_data and isinstance(imp.invoices_data, list):
        for inv in imp.invoices_data:
            if isinstance(inv, dict):
                amt = float(inv.get("amount", 0.0) or 0.0)
                if amt > 0:
                    total_invoice += amt
                    if inv.get("currency"):
                        invoice_curr = inv["currency"]

    # If still 0, fallback to estimated_cost on import_file
    if total_invoice == 0.0 and imp.estimated_cost:
        total_invoice = float(imp.estimated_cost or 0.0)
        if imp.estimated_cost_currency:
            invoice_curr = imp.estimated_cost_currency

    if len(payment_terms_set) == 1:
        payment_terms_summary = next(iter(payment_terms_set))
    elif len(payment_terms_set) > 1:
        payment_terms_summary = f"متعدد ({', '.join(terms_list_str)})"
    else:
        payment_terms_summary = "Advance Payment"

    # 2. Supplier and Banking Info
    sup = None
    if imp.supplier_id:
        sup = db.query(Supplier).filter(Supplier.supplier_id == imp.supplier_id).first()
    elif pos and pos[0].supplier_id:
        sup = db.query(Supplier).filter(Supplier.supplier_id == pos[0].supplier_id).first()
    elif imp.supplier_name:
        sup = db.query(Supplier).filter(Supplier.company_name == imp.supplier_name).first()

    supplier_name = sup.company_name if sup else (imp.supplier_name or "Foreign Exporter")
    bank_name = sup.bank_name if sup else None
    swift_code = sup.swift_code if sup else None
    account_no = sup.account_number if sup else None
    iban = sup.iban if sup else None

    # 3. Estimated Freight: Always retrieve highest / maximum freight rate across all options
    po_ids = [p.po_id for p in pos]
    shipping_sessions = db.query(ShippingEvaluationSession).filter(
        (ShippingEvaluationSession.import_file_id == import_file_id) |
        (ShippingEvaluationSession.po_id.in_(po_ids) if po_ids else False),
        ShippingEvaluationSession.is_active == True,
    ).all()

    highest_freight = 0.0
    freight_currency = "USD"

    for s in shipping_sessions:
        for itm in s.items:
            f_amt = float(getattr(itm, "total_quotation_amount", 0.0) or 0.0)
            if f_amt == 0.0:
                c40 = (itm.container_40ft_price or 0.0) * (itm.container_40ft_qty or 1) if itm.container_40ft_applicable else 0.0
                c20 = (itm.container_20ft_price or 0.0) * (itm.container_20ft_qty or 1) if itm.container_20ft_applicable else 0.0
                lcl = (itm.lcl_cbm_price or 0.0) * (itm.lcl_cbm_qty or 1) if itm.lcl_cbm_applicable else 0.0
                f_amt = c40 + c20 + lcl

            curr = getattr(itm, "quotation_currency", None) or "USD"
            if f_amt > highest_freight:
                highest_freight = f_amt
                freight_currency = curr

    # 4. Customs Taxes and Broker Clearance from Customs Consultation
    customs_query = db.query(CustomsConsultationSession).filter(
        CustomsConsultationSession.is_active == True,
    )
    if po_ids:
        customs_sessions = customs_query.filter(
            (CustomsConsultationSession.import_file_id == import_file_id) |
            (CustomsConsultationSession.po_id.in_(po_ids))
        ).all()
    else:
        customs_sessions = customs_query.filter(
            CustomsConsultationSession.import_file_id == import_file_id
        ).all()

    estimated_duties_egp = 0.0
    estimated_clearance_fees_egp = 0.0
    broker_id: Optional[int] = None
    broker_name: Optional[str] = None
    for cs in customs_sessions:
        d_amt = float(cs.estimated_duties_egp or 0.0)
        c_amt = float(cs.total_broker_fees_egp or 0.0)
        if d_amt > 0:
            estimated_duties_egp = max(estimated_duties_egp, d_amt)
        if c_amt > 0:
            if c_amt >= estimated_clearance_fees_egp:
                estimated_clearance_fees_egp = c_amt
                if cs.broker_id:
                    broker_id = cs.broker_id
                if cs.broker_name:
                    broker_name = cs.broker_name
        elif not broker_name and cs.broker_name:
            broker_id = cs.broker_id
            broker_name = cs.broker_name

    # 5. Fetch Dynamic Exchange Rates from Currencies Master & Rates History
    from modules.currencies.repository import CurrencyRepository

    curr_repo = CurrencyRepository(db)
    currency_obj = curr_repo.get_currency_by_code(invoice_curr or "USD")
    exchange_rate = 50.0
    if currency_obj:
        if currency_obj.is_base_currency:
            exchange_rate = 1.0
        else:
            latest_rate = curr_repo.get_latest_rate(currency_obj.currency_id, target_date=date.today())
            if latest_rate and latest_rate.commercial_rate:
                exchange_rate = float(latest_rate.commercial_rate)

    # Freight Exchange Rate
    freight_exchange_rate = 50.0
    if freight_currency.upper() == "EGP":
        freight_exchange_rate = 1.0
    else:
        f_curr_obj = curr_repo.get_currency_by_code(freight_currency or "USD")
        if f_curr_obj:
            if f_curr_obj.is_base_currency:
                freight_exchange_rate = 1.0
            else:
                latest_f_rate = curr_repo.get_latest_rate(f_curr_obj.currency_id, target_date=date.today())
                if latest_f_rate and latest_f_rate.commercial_rate:
                    freight_exchange_rate = float(latest_f_rate.commercial_rate)

    total_invoice_egp = total_invoice * exchange_rate
    estimated_freight_egp = highest_freight * freight_exchange_rate
    grand_total_egp = total_invoice_egp + estimated_freight_egp + estimated_duties_egp + estimated_clearance_fees_egp

    incoterm_str = imp.incoterm_code or "FOB"
    file_code_str = imp.import_file_code or f"IMP-{imp.import_file_id}"
    file_title_str = f"شحنة {file_code_str}"

    return BudgetPrefillResponse(
        import_file_id=imp.import_file_id,
        import_file_code=file_code_str,
        import_file_title=file_title_str,
        incoterm=incoterm_str,
        supplier_id=sup.supplier_id if sup else None,
        supplier_name=supplier_name,
        beneficiary_name=supplier_name,
        bank_name=bank_name,
        swift_code=swift_code,
        account_number=account_no,
        iban=iban,
        payment_terms_summary=payment_terms_summary,
        linked_pos=linked_pos_schemas,
        total_invoice_amount=total_invoice,
        invoice_currency=invoice_curr,
        total_invoice_amount_egp=total_invoice_egp,
        estimated_freight_cost=highest_freight,
        freight_currency=freight_currency,
        estimated_freight_cost_egp=estimated_freight_egp,
        estimated_customs_duties_egp=estimated_duties_egp,
        estimated_clearance_fees_egp=estimated_clearance_fees_egp,
        broker_id=broker_id,
        broker_name=broker_name,
        estimated_grand_total_egp=grand_total_egp,
        exchange_rate=exchange_rate,
    )

def get_all_payment_requests_service(db: Session, include_inactive: bool = False, search: Optional[str] = None, po_id: Optional[int] = None, supplier_id: Optional[int] = None, status: Optional[str] = None) -> List[PaymentRequestSession]:
    return repo.get_all_payment_requests(db, include_inactive=include_inactive, search=search, po_id=po_id, supplier_id=supplier_id, status=status)

def get_payment_request_by_id_service(db: Session, payment_id: int) -> Optional[PaymentRequestSession]:
    return repo.get_payment_request_by_id(db, payment_id)

def soft_delete_payment_request_service(db: Session, payment_id: int) -> bool:
    return repo.soft_delete_payment_request(db, payment_id)

def restore_payment_request_service(db: Session, payment_id: int) -> bool:
    return repo.restore_payment_request(db, payment_id)

def get_all_import_budgets_service(db: Session, include_inactive: bool = False, search: Optional[str] = None, import_file_id: Optional[int] = None, po_id: Optional[int] = None, budget_status: Optional[str] = None) -> List[ImportBudgetApproval]:
    return repo.get_all_import_budgets(db, include_inactive=include_inactive, search=search, import_file_id=import_file_id, po_id=po_id, budget_status=budget_status)

def get_import_budget_by_id_service(db: Session, budget_id: int) -> Optional[ImportBudgetApproval]:
    return repo.get_import_budget_by_id(db, budget_id)

def update_import_budget_service(
    db: Session, budget_id: int, schema: ImportBudgetUpdate, current_user_name: Optional[str] = None
) -> ImportBudgetApproval:
    db_item = repo.get_import_budget_by_id(db, budget_id)
    if not db_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import Budget ID {budget_id} not found.",
        )
    updated = repo.update_import_budget(db, db_item, schema, current_user_name=current_user_name)
    if updated.import_file_id:
        try:
            from modules.lifecycle_board.service import sync_budget_lifecycle_stage
            is_approved = (updated.budget_status == "Budget Approved")
            sync_budget_lifecycle_stage(db, updated.import_file_id, is_approved=is_approved, approved_by=updated.approved_by)
        except Exception:
            pass
    return updated

def soft_delete_import_budget_service(db: Session, budget_id: int) -> bool:
    return repo.soft_delete_import_budget(db, budget_id)

def restore_import_budget_service(db: Session, budget_id: int) -> bool:
    return repo.restore_import_budget(db, budget_id)

# ==============================================================================
# BUDGET VARIANCE THRESHOLD & CONFIGURATION SERVICES
# ==============================================================================

def get_variance_threshold_service(db: Session) -> float:
    """Returns the configured variance threshold percentage (default 5.0%)."""
    setting = db.query(BudgetVarianceSetting).filter(
        BudgetVarianceSetting.setting_key == "variance_threshold_percentage"
    ).first()
    if setting and setting.setting_value:
        try:
            return float(setting.setting_value)
        except ValueError:
            return 5.0
    return 5.0


def update_variance_threshold_service(
    db: Session, threshold_percentage: float, updated_by: Optional[str] = "Admin"
) -> BudgetVarianceSetting:
    """Updates the variance threshold percentage setting."""
    setting = db.query(BudgetVarianceSetting).filter(
        BudgetVarianceSetting.setting_key == "variance_threshold_percentage"
    ).first()
    now = datetime.now(timezone.utc)
    val_str = str(round(threshold_percentage, 2))
    if not setting:
        setting = BudgetVarianceSetting(
            setting_key="variance_threshold_percentage",
            setting_value=val_str,
            description="Maximum allowed cost variance percentage before triggering Hard Block",
            updated_by=updated_by,
            updated_at=now,
        )
        db.add(setting)
    else:
        setting.setting_value = val_str
        setting.updated_by = updated_by
        setting.updated_at = now
    db.commit()
    db.refresh(setting)
    return setting


def get_budget_variance_logs_service(
    db: Session, budget_id: int
) -> List[BudgetVarianceLog]:
    """Retrieves all variance audit logs recorded for a budget."""
    return (
        db.query(BudgetVarianceLog)
        .filter(BudgetVarianceLog.budget_id == budget_id)
        .order_by(BudgetVarianceLog.detected_at.desc())
        .all()
    )


# ==============================================================================
# EVENT-DRIVEN SCOPED VARIANCE EVALUATION ENGINE
# ==============================================================================

def evaluate_and_record_budget_variance_service(
    db: Session, import_file_id: int, modified_by: Optional[str] = "System"
) -> List[BudgetVarianceLog]:
    """
    Event-driven scoped variance evaluator:
    Triggered immediately upon changes in upstream costing sessions (customs clearance, freight, PO invoice).
    Only inspects active budgets for the given import_file_id.
    
    Status Machine Rules:
    - Draft: Auto-updates figures in-place with audit log line.
    - Pending Review / Pending Approval: Halts current approval cycle, transitions to 'Needs Revalidation', sends notifications.
    - Approved: STRICT IMMUTABILITY. Flags has_unresolved_variance = True and upstream_modified_by, sends critical notification.
    """
    active_budgets = (
        db.query(ImportBudgetApproval)
        .filter(
            ImportBudgetApproval.import_file_id == import_file_id,
            ImportBudgetApproval.is_active == True,
            ImportBudgetApproval.budget_status != "Superseded",
        )
        .all()
    )
    if not active_budgets:
        return []

    prefill = get_budget_prefill_service(db, import_file_id)
    threshold = get_variance_threshold_service(db)
    now = datetime.now(timezone.utc)
    recorded_logs: List[BudgetVarianceLog] = []

    # Import file reference for notification messages
    from modules.import_files.model import ImportFile
    imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    file_code = imp_file.import_file_code if imp_file else f"IMP-FILE-{import_file_id}"

    for budget in active_budgets:
        field_checks = [
            ("invoice_amount_egp", budget.invoice_amount_egp, prefill.total_invoice_amount_egp, "قيمة الفاتورة (FOB)"),
            ("freight_cost_egp", budget.freight_cost_egp, prefill.estimated_freight_cost_egp, "النولون والشحن الدولي"),
            ("customs_duties_egp", budget.customs_duties_egp, prefill.estimated_customs_duties_egp, "الضرائب والرسوم الجمركية"),
            ("clearance_inland_egp", budget.clearance_inland_egp, prefill.estimated_clearance_fees_egp, "مصاريف التخليص والنقل"),
        ]

        item_variances: List[BudgetVarianceLog] = []
        has_hard_block = False

        for f_name, old_val, new_val, label_ar in field_checks:
            diff = new_val - old_val
            if abs(diff) > 1.0:
                if old_val == 0.0:
                    pct = 100.0
                else:
                    pct = round((abs(diff) / old_val) * 100.0, 2)
                
                is_hard = pct > threshold
                if is_hard:
                    has_hard_block = True

                v_log = BudgetVarianceLog(
                    budget_id=budget.budget_id,
                    import_file_id=import_file_id,
                    field_name=f_name,
                    old_value=old_val,
                    new_value=new_val,
                    variance_amount=diff,
                    variance_percentage=pct,
                    threshold_percentage=threshold,
                    is_hard_block=is_hard,
                    detected_at=now,
                    modified_by=modified_by,
                    resolution_type="pending",
                )
                db.add(v_log)
                item_variances.append(v_log)
                recorded_logs.append(v_log)

        if not item_variances:
            continue

        # --- POST-SYNC STATUS MACHINE APPLIED TO BUDGET ---
        current_status = budget.budget_status

        if current_status == "Draft":
            # Draft: Auto-update numbers silently, append log line
            budget.invoice_amount_foreign = prefill.total_invoice_amount
            budget.invoice_currency = prefill.invoice_currency
            budget.invoice_amount_egp = prefill.total_invoice_amount_egp

            budget.freight_cost_foreign = prefill.estimated_freight_cost
            budget.freight_currency = prefill.freight_currency
            budget.freight_cost_egp = prefill.estimated_freight_cost_egp

            budget.customs_duties_egp = prefill.estimated_customs_duties_egp
            budget.clearance_inland_egp = prefill.estimated_clearance_fees_egp
            budget.exchange_rate = prefill.exchange_rate
            budget.total_budget_egp = (
                prefill.total_invoice_amount_egp
                + prefill.estimated_freight_cost_egp
                + prefill.estimated_customs_duties_egp
                + prefill.estimated_clearance_fees_egp
            )
            budget.has_unresolved_variance = False
            budget.last_variance_check = now
            budget.upstream_modified_by = modified_by

            for v in item_variances:
                v.resolution_type = "auto_updated"
                v.resolved_at = now
                v.resolved_by = "System"

            auto_note = f"[تحديث تلقائي {date.today()}]: تم تحديث التكاليف الحية تلقائياً لميزانية المسودة بواسطة {modified_by}."
            budget.notes = f"{budget.notes}\n{auto_note}".strip() if budget.notes else auto_note

        elif current_status in ("Pending Review", "Needs Revalidation"):
            # Pending: Stop current approval cycle, transition to Needs Revalidation
            budget.budget_status = "Needs Revalidation"
            budget.has_unresolved_variance = True
            budget.upstream_modified_by = modified_by
            budget.last_variance_check = now
            budget.approved_by = None
            budget.approved_date = None

            status_note = f"[تعديل بالمصدر {date.today()}]: رُصد فارق تكاليف بواسطة {modified_by}. تحولت الحالة إلى 'Needs Revalidation'."
            budget.notes = f"{budget.notes}\n{status_note}".strip() if budget.notes else status_note

            # In-app notification to Finance Officer and Requester
            severity = "CRITICAL" if has_hard_block else "WARNING"
            notif = SystemNotification(
                title=f"⚠️ ميزانية تحتاج إعادة تحقق: {file_code}",
                message=f"تم تعديل تكاليف في مرحلة سابقة بواسطة {modified_by} للشحنة ({file_code}). تم إيقاف دورة الاعتماد وتحويل الميزانية ({budget.budget_code}) إلى 'Needs Revalidation'.",
                severity=severity,
                category="BUDGET_VARIANCE",
                entity_type="ImportBudget",
                entity_id=budget.budget_id,
                target_role="FINANCE_OFFICER",
            )
            db.add(notif)

        elif current_status == "Budget Approved":
            # Approved: STRICT IMMUTABILITY. Do not alter budget numbers.
            budget.has_unresolved_variance = True
            budget.upstream_modified_by = modified_by
            budget.last_variance_check = now

            var_note = f"[تنبيه فارق مالي {date.today()}]: رُصد فارق تكاليف بواسطة {modified_by} لميزانية معتمدة. يلزم إنشاء إصدار مراجعة جديد (Revision)."
            budget.notes = f"{budget.notes}\n{var_note}".strip() if budget.notes else var_note

            # Critical In-app notification for Approved Budget variance
            notif = SystemNotification(
                title=f"🚨 تنبيه فارق مالي بميزانية معتمدة: {file_code}",
                message=f"تم تعديل تكاليف في المصدر لميزانية معتمدة ({budget.budget_code}) للشحنة ({file_code}) بواسطة {modified_by}. الفارق يتطلب مراجعة واعتماد إصدار جديد (Budget Revision).",
                severity="CRITICAL",
                category="BUDGET_VARIANCE",
                entity_type="ImportBudget",
                entity_id=budget.budget_id,
                target_role="FINANCE_OFFICER",
            )
            db.add(notif)

    db.commit()
    for l in recorded_logs:
        db.refresh(l)
    return recorded_logs


# ==============================================================================
# ENTERPRISE BUDGET SYNCHRONIZATION SERVICE (SoD, REVISIONS & HARD BLOCK)
# ==============================================================================

def sync_budget_with_upstream_service(
    db: Session,
    budget_id: int,
    current_user: Optional[User] = None,
    override_justification: Optional[str] = None,
) -> BudgetSyncResultResponse:
    """
    Synchronizes an existing Import Budget with live upstream costs following enterprise rules:
    1. Permissions: Requires 'budget.sync_variance' or 'financial_approval.approve' or Finance Manager/Admin.
    2. Segregation of Duties (SoD): The modifier of upstream costing CANNOT sync an Approved budget.
    3. Status Machine & Revisions:
       - Approved budgets are IMMUTABLE: A new revision (e.g. BGT-XXXX-REV2) is created with parent_budget_id.
         The original budget is preserved and marked as 'Superseded'.
       - Needs Revalidation / Pending Review: Updated in-place and returned to 'Pending Review'.
       - Draft: Updated in-place.
    4. Threshold & Hard Block: If variance exceeds threshold and no justification provided, rejects sync.
    5. Resolves open variance logs and writes audit notes.
    """
    budget = repo.get_import_budget_by_id(db, budget_id)
    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import Budget ID {budget_id} not found.",
        )
    if not budget.import_file_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لا يمكن مزامنة هذه الميزانية لعدم وجود ملف استيراد مرتبط بها.",
        )

    # 1. PERMISSION CHECK
    from modules.auth.permissions import has_user_permission
    if current_user:
        can_sync = (
            has_user_permission(db, current_user, "budget.sync_variance")
            or has_user_permission(db, current_user, "financial_approval.approve")
            or current_user.role in ("ADMIN", "MANAGER")
        )
        if not can_sync:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="ليس لديك صلاحية مزامنة فوارق الميزانية ('budget.sync_variance'). يتطلب دور مسؤول مالي أو مدير النظام.",
            )

    # 2. SEGREGATION OF DUTIES (SoD) RULE
    # If budget was Approved, modifier cannot be the syncer/approver of the revision
    is_approved_or_superseded = budget.budget_status in ("Budget Approved", "Superseded")
    if is_approved_or_superseded and budget.upstream_modified_by and current_user:
        mod_user = budget.upstream_modified_by.strip().lower()
        curr_user = current_user.username.strip().lower()
        if mod_user == curr_user and current_user.role != "ADMIN":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="مبدأ الفصل بين المهام (Segregation of Duties): بصفتك المستخدم الذي قام بتعديل التكاليف في المصدر، لا يجوز لك مزامنة أو اعتماد الميزانية المعتمدة بنفسك. يجب أن يتولى المراجعة والاعتماد مسؤول مالي آخر.",
            )

    # 3. LIVE PREFILL & VARIANCE CHECK
    prefill = get_budget_prefill_service(db, budget.import_file_id)
    threshold = get_variance_threshold_service(db)

    field_diffs = [
        ("invoice_amount_egp", budget.invoice_amount_egp, prefill.total_invoice_amount_egp, "الفاتورة"),
        ("freight_cost_egp", budget.freight_cost_egp, prefill.estimated_freight_cost_egp, "النولون"),
        ("customs_duties_egp", budget.customs_duties_egp, prefill.estimated_customs_duties_egp, "الجمارك"),
        ("clearance_inland_egp", budget.clearance_inland_egp, prefill.estimated_clearance_fees_egp, "التخليص"),
    ]

    has_hard_block = False
    changes_desc = []
    for f_name, old_v, new_v, label in field_diffs:
        d = new_v - old_v
        if abs(d) > 1.0:
            changes_desc.append(f"{label}: {old_v:.2f} -> {new_v:.2f} ج.م")
            pct = 100.0 if old_v == 0 else round((abs(d) / old_v) * 100.0, 2)
            if pct > threshold:
                has_hard_block = True

    # Check Hard Block without written justification
    if has_hard_block and not override_justification and budget.budget_status not in ("Draft",):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"فارق التكاليف يتجاوز العتبة المحددة ({threshold}% - Hard Block). يتطلب إدخال مبرر مكتوب إجباري (Justification Note) لتنفيذ المزامنة وتجاوز الحظر.",
        )

    now = datetime.now(timezone.utc)
    current_username = current_user.username if current_user else "Finance Officer"

    # 4. STATUS MACHINE & REVISION LOGIC
    if budget.budget_status == "Budget Approved":
        # --- REVISION ENGINE: STRICT IMMUTABILITY ---
        # 1. Archive original budget record as Superseded
        orig_status = budget.budget_status
        budget.budget_status = "Superseded"
        budget.has_unresolved_variance = False
        archive_note = f"[أرشفة كإصدار ملغي {date.today()}]: استُبدلت هذه النسخة المعتمدة بالإصدار الجديد REV{budget.revision_number + 1} بواسطة {current_username}."
        budget.notes = f"{budget.notes}\n{archive_note}".strip() if budget.notes else archive_note

        # 2. Generate clean revision code
        base_code = budget.budget_code.split("-REV")[0]
        next_rev = budget.revision_number + 1
        rev_code = f"{base_code}-REV{next_rev}"

        # 3. Create brand new Revision record
        new_budget = ImportBudgetApproval(
            budget_code=rev_code,
            title=f"{budget.title} (Rev {next_rev})",
            import_file_id=budget.import_file_id,
            po_id=budget.po_id,
            project_id=budget.project_id,
            invoice_amount_foreign=prefill.total_invoice_amount,
            invoice_currency=prefill.invoice_currency,
            invoice_amount_egp=prefill.total_invoice_amount_egp,
            freight_cost_foreign=prefill.estimated_freight_cost,
            freight_currency=prefill.freight_currency,
            freight_cost_egp=prefill.estimated_freight_cost_egp,
            customs_duties_egp=prefill.estimated_customs_duties_egp,
            clearance_inland_egp=prefill.estimated_clearance_fees_egp,
            exchange_rate=prefill.exchange_rate,
            total_budget_egp=prefill.estimated_grand_total_egp,
            budget_status="Pending Review",
            approved_by=None,
            approved_date=None,
            parent_budget_id=budget.budget_id,
            revision_number=next_rev,
            has_unresolved_variance=False,
            variance_override_reason=override_justification,
            variance_overridden_by=current_username if override_justification else None,
            upstream_modified_by=budget.upstream_modified_by,
            notes=f"[إصدار مراجعة جديد {date.today()}]: أُنشئت هذه الميزانية بمزامنة التكاليف الحية بدلاً من {budget.budget_code} ({', '.join(changes_desc) if changes_desc else 'بدون فوارق'}). المنفذ: {current_username}." + (f" مبرر التجاوز: {override_justification}" if override_justification else ""),
            is_active=True,
        )
        db.add(new_budget)
        db.commit()
        db.refresh(new_budget)

        # 4. Resolve variance logs
        open_logs = db.query(BudgetVarianceLog).filter(
            BudgetVarianceLog.budget_id == budget.budget_id,
            BudgetVarianceLog.resolution_type == "pending",
        ).all()
        for log in open_logs:
            log.resolved_at = now
            log.resolved_by = current_username
            log.resolution_type = "overridden" if override_justification else "synced"
            log.justification_note = override_justification

        db.commit()

        # Lifecycle board update
        if new_budget.import_file_id:
            try:
                from modules.lifecycle_board.service import sync_budget_lifecycle_stage
                sync_budget_lifecycle_stage(db, new_budget.import_file_id, is_approved=False, approved_by=None)
            except Exception:
                pass

        log_responses = [BudgetVarianceLogResponse.model_validate(l) for l in open_logs]
        return BudgetSyncResultResponse(
            budget=ImportBudgetResponse.model_validate(new_budget),
            action_taken="revision_created",
            revision_created=True,
            original_budget_status=orig_status,
            variance_logs=log_responses,
            message=f"✅ تم إنشاء إصدار مراجعة جديد للميزانية ({new_budget.budget_code}) بنجاح، وأرشفة السجل المعتمد السابق كـ Superseded حفاظاً على الرقابة والتقارير المالية.",
        )

    else:
        # --- IN-PLACE UPDATE FOR DRAFT / NEEDS REVALIDATION / PENDING REVIEW ---
        orig_status = budget.budget_status
        budget.invoice_amount_foreign = prefill.total_invoice_amount
        budget.invoice_currency = prefill.invoice_currency
        budget.invoice_amount_egp = prefill.total_invoice_amount_egp

        budget.freight_cost_foreign = prefill.estimated_freight_cost
        budget.freight_currency = prefill.freight_currency
        budget.freight_cost_egp = prefill.estimated_freight_cost_egp

        budget.customs_duties_egp = prefill.estimated_customs_duties_egp
        budget.clearance_inland_egp = prefill.estimated_clearance_fees_egp
        budget.exchange_rate = prefill.exchange_rate
        budget.total_budget_egp = prefill.estimated_grand_total_egp

        budget.budget_status = "Draft" if orig_status == "Draft" else "Pending Review"
        budget.has_unresolved_variance = False
        budget.variance_override_reason = override_justification
        budget.variance_overridden_by = current_username if override_justification else None

        sync_note = f"[مزامنة بالتكاليف الحية {date.today()}]: تم تحديث التكاليف ({', '.join(changes_desc) if changes_desc else 'بدون فوارق'}). المنفذ: {current_username}." + (f" مبرر التجاوز: {override_justification}" if override_justification else "")
        budget.notes = f"{budget.notes}\n{sync_note}".strip() if budget.notes else sync_note

        open_logs = db.query(BudgetVarianceLog).filter(
            BudgetVarianceLog.budget_id == budget.budget_id,
            BudgetVarianceLog.resolution_type == "pending",
        ).all()
        for log in open_logs:
            log.resolved_at = now
            log.resolved_by = current_username
            log.resolution_type = "overridden" if override_justification else "synced"
            log.justification_note = override_justification

        db.commit()
        db.refresh(budget)

        if budget.import_file_id:
            try:
                from modules.lifecycle_board.service import sync_budget_lifecycle_stage
                sync_budget_lifecycle_stage(db, budget.import_file_id, is_approved=False, approved_by=None)
            except Exception:
                pass

        log_responses = [BudgetVarianceLogResponse.model_validate(l) for l in open_logs]
        return BudgetSyncResultResponse(
            budget=ImportBudgetResponse.model_validate(budget),
            action_taken="auto_updated" if orig_status == "Draft" else "revalidation_required",
            revision_created=False,
            original_budget_status=orig_status,
            variance_logs=log_responses,
            message=f"✅ تمت مزامنة الميزانية ({budget.budget_code}) بالتكاليف الحية بنجاح وهي الآن بحالة '{budget.budget_status}'.",
        )


def override_budget_variance_service(
    db: Session,
    budget_id: int,
    current_user: Optional[User] = None,
    justification_note: str = "",
) -> ImportBudgetApproval:
    """
    Overrides Hard Block variance by providing an authorized written justification.
    Records justification in budget and audit logs without mutating budget numbers.
    """
    budget = repo.get_import_budget_by_id(db, budget_id)
    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Import Budget ID {budget_id} not found.",
        )

    if not justification_note or len(justification_note.strip()) < 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="يجب كتابة مبرر تفصيلي لتجاوز حظر فارق الميزانية (لا يقل عن 5 أحرف).",
        )

    # Permission check
    from modules.auth.permissions import has_user_permission
    if current_user:
        can_override = (
            has_user_permission(db, current_user, "budget.sync_variance")
            or has_user_permission(db, current_user, "financial_approval.approve")
            or current_user.role in ("ADMIN", "MANAGER")
        )
        if not can_override:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="ليس لديك صلاحية تجاوز حظر الفوارق ('budget.sync_variance').",
            )

    now = datetime.now(timezone.utc)
    current_username = current_user.username if current_user else "Authorized Approver"

    budget.has_unresolved_variance = False
    budget.variance_override_reason = justification_note.strip()
    budget.variance_overridden_by = current_username

    audit_entry = f"[تجاوز الحظر المالي {date.today()}]: تم تجاوز حظر فارق التكاليف بواسطة {current_username}. المبرر: {justification_note.strip()}."
    budget.notes = f"{budget.notes}\n{audit_entry}".strip() if budget.notes else audit_entry

    # Mark active logs as overridden
    open_logs = db.query(BudgetVarianceLog).filter(
        BudgetVarianceLog.budget_id == budget.budget_id,
        BudgetVarianceLog.resolution_type == "pending",
    ).all()
    for log in open_logs:
        log.resolved_at = now
        log.resolved_by = current_username
        log.resolution_type = "overridden"
        log.justification_note = justification_note.strip()

    db.commit()
    db.refresh(budget)
    return budget


# --- SMART AI SWIFT MT103 EXTRACTION REVIEW LAYER SERVICES ---
def _build_batch_response(batch: SwiftExtractionBatch) -> SwiftBatchResponse:
    """Helper to convert SwiftExtractionBatch to SwiftBatchResponse with mandatory field validation."""
    fields_list = []
    missing_mandatory = []
    field_map = {f.field_key: f for f in batch.fields}

    mandatory_keys = [
        ("amount", "المبلغ المحول / Transferred Amount"),
        ("currency", "العملة / Currency"),
        ("beneficiary_name", "اسم المستفيد / Beneficiary Name"),
        ("beneficiary_account_or_iban", "رقم حساب أو آيبان المستفيد / Account or IBAN"),
        ("transaction_reference", "الرقم المرجعي للسويفت / SWIFT Reference"),
    ]

    for key, label in mandatory_keys:
        fld = field_map.get(key)
        if not fld:
            missing_mandatory.append(label)
        else:
            val = (fld.final_value or "").strip()
            if not val:
                missing_mandatory.append(label)
            elif key == "amount":
                try:
                    num = float(val)
                    if num <= 0:
                        missing_mandatory.append(label)
                except ValueError:
                    missing_mandatory.append(label)

    for f in batch.fields:
        fields_list.append(
            SwiftFieldResponse(
                id=f.id,
                batch_id=f.batch_id,
                field_key=f.field_key,
                swift_field_code=f.swift_field_code,
                field_label=f.field_label,
                raw_ocr_text=f.raw_ocr_text,
                parsed_value=f.parsed_value,
                confidence_score=f.confidence_score,
                is_edited_by_user=f.is_edited_by_user,
                edited_value=f.edited_value,
                final_value=f.final_value,
                is_mandatory=f.is_mandatory,
                is_empty=f.is_empty,
                created_at=f.created_at,
                updated_at=f.updated_at,
            )
        )

    all_mandatory_valid = len(missing_mandatory) == 0

    return SwiftBatchResponse(
        batch_id=batch.batch_id,
        batch_code=batch.batch_code,
        source_filename=batch.source_filename,
        source_file_type=batch.source_file_type,
        raw_source_text=batch.raw_source_text,
        normalized_text=batch.normalized_text,
        status=batch.status,
        reviewed_by=batch.reviewed_by,
        reviewed_at=batch.reviewed_at,
        matched_payment_id=batch.matched_payment_id,
        reconciled_at=batch.reconciled_at,
        fields=fields_list,
        all_mandatory_valid=all_mandatory_valid,
        missing_mandatory_fields=missing_mandatory,
        created_at=batch.created_at,
        updated_at=batch.updated_at,
    )


def extract_swift_for_review_service(
    db: Session,
    raw_text: str,
    filename: Optional[str] = None,
    file_type: Optional[str] = None,
) -> SwiftBatchResponse:
    """Extracts SWIFT fields and persists a batch in 'EXTRACTED_PENDING_REVIEW'."""
    from modules.financial_approval.swift_file_extractor import normalize_swift_ocr_text
    from modules.financial_approval.swift_mt103_parser import extract_swift_fields_breakdown

    normalized = normalize_swift_ocr_text(raw_text)
    text_to_parse = normalized if normalized.strip() else raw_text
    breakdown = extract_swift_fields_breakdown(text_to_parse)
    fields_data = breakdown.get("fields", [])

    batch = repo.create_swift_extraction_batch(
        db=db,
        raw_source_text=raw_text,
        normalized_text=normalized,
        source_filename=filename,
        source_file_type=file_type,
        fields_breakdown=fields_data,
    )
    return _build_batch_response(batch)


def get_swift_batch_review_service(db: Session, batch_id: int) -> SwiftBatchResponse:
    """Retrieves batch review info with validation breakdown."""
    batch = repo.get_swift_extraction_batch(db, batch_id)
    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"SWIFT extraction batch {batch_id} not found.",
        )
    return _build_batch_response(batch)


def update_swift_batch_field_service(
    db: Session,
    batch_id: int,
    field_key: str,
    payload: SwiftFieldUpdateRequest,
) -> SwiftBatchResponse:
    """Updates an individual field, records in OCR audit log, and recalculates validity."""
    batch = repo.get_swift_extraction_batch(db, batch_id)
    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"SWIFT extraction batch {batch_id} not found.",
        )
    if batch.status in ("RECONCILED", "REJECTED"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot edit fields of a batch in '{batch.status}' status.",
        )

    updated_field = repo.update_swift_batch_field(
        db=db,
        batch_id=batch_id,
        field_key=field_key,
        new_value=payload.value,
        user_name=payload.user_name or "admin",
    )
    if not updated_field:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Field '{field_key}' not found in batch {batch_id}.",
        )

    db.refresh(batch)
    return _build_batch_response(batch)


def re_extract_single_field_service(db: Session, batch_id: int, field_key: str) -> SwiftBatchResponse:
    """Re-runs extraction regex for a single field from source text."""
    batch = repo.get_swift_extraction_batch(db, batch_id)
    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"SWIFT extraction batch {batch_id} not found.",
        )
    from modules.financial_approval.swift_mt103_parser import extract_swift_fields_breakdown

    text_to_parse = batch.normalized_text if batch.normalized_text and batch.normalized_text.strip() else batch.raw_source_text
    breakdown = extract_swift_fields_breakdown(text_to_parse)
    field_item = next((f for f in breakdown.get("fields", []) if f["field_key"] == field_key), None)
    if not field_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Field '{field_key}' could not be re-extracted.",
        )

    p_val = field_item.get("parsed_value")
    p_val_str = str(p_val) if p_val is not None else ""
    fld = next((f for f in batch.fields if f.field_key == field_key), None)
    if fld:
        fld.parsed_value = p_val_str
        fld.final_value = p_val_str
        fld.confidence_score = float(field_item.get("confidence_score", 0.0))
        fld.raw_ocr_text = field_item.get("raw_ocr_text")
        fld.is_edited_by_user = False
        fld.edited_value = None
        fld.is_empty = not bool(p_val_str.strip())
        fld.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(batch)

    return _build_batch_response(batch)


def confirm_swift_batch_review_service(
    db: Session,
    batch_id: int,
    payload: SwiftBatchConfirmRequest,
) -> SwiftBatchConfirmResponse:
    """
    Validates all mandatory fields, confirms the batch, and unlocks the matching matrix.
    Raises 400 if any mandatory field is missing or empty.
    """
    batch = repo.get_swift_extraction_batch(db, batch_id)
    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"SWIFT extraction batch {batch_id} not found.",
        )

    batch_resp = _build_batch_response(batch)
    if not batch_resp.all_mandatory_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot confirm SWIFT review: Mandatory fields are missing or invalid: {', '.join(batch_resp.missing_mandatory_fields)}",
        )

    confirmed_batch = repo.confirm_swift_batch_review(
        db=db,
        batch_id=batch_id,
        user_name=payload.user_name or "admin",
    )
    confirmed_fields = {f.field_key: f.final_value for f in confirmed_batch.fields}

    return SwiftBatchConfirmResponse(
        success=True,
        batch_id=confirmed_batch.batch_id,
        batch_code=confirmed_batch.batch_code,
        status=confirmed_batch.status,
        message="تم تأكيد صحة بيانات السويفت بنجاح وتم فتح مصفوفة المطابقة المالية.",
        confirmed_fields=confirmed_fields,
        batch=_build_batch_response(confirmed_batch),
    )


def match_reviewed_batch_service(
    db: Session,
    batch_id: int,
    target_payment_id: Optional[int] = None,
) -> SwiftBatchMatchResponse:
    """
    Matches a reviewed batch against payment requests strictly using `final_value`.
    REJECTS with 403 if batch is not in 'REVIEWED_CONFIRMED' or 'RECONCILED'.
    """
    from modules.financial_approval.swift_mt103_parser import match_swift_against_payment_request

    batch = repo.get_swift_extraction_batch(db, batch_id)
    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"SWIFT extraction batch {batch_id} not found.",
        )

    if batch.status not in ("REVIEWED_CONFIRMED", "RECONCILED"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="SWIFT batch has not been reviewed and confirmed. You must confirm the extracted fields before proceeding to matching.",
        )

    # Build confirmed dict STRICTLY from final_value
    confirmed_dict = {}
    for f in batch.fields:
        confirmed_dict[f.field_key] = f.final_value

    amt_str = confirmed_dict.get("amount", "0")
    try:
        confirmed_dict["amount"] = float(amt_str)
    except (ValueError, TypeError):
        confirmed_dict["amount"] = 0.0

    all_requests = repo.get_all_payment_requests(db, include_inactive=False)
    candidate_matches = []
    best_match = None
    highest_score = -1

    for req in all_requests:
        match_info = match_swift_against_payment_request(confirmed_dict, req)
        candidate_matches.append(match_info)

        if target_payment_id and req.payment_id == target_payment_id:
            best_match = match_info
            highest_score = 999
        elif match_info["confidence_score"] > highest_score:
            highest_score = match_info["confidence_score"]
            best_match = match_info

    candidate_matches.sort(key=lambda x: x["confidence_score"], reverse=True)

    return SwiftBatchMatchResponse(
        success=True,
        batch_id=batch.batch_id,
        status=batch.status,
        matched_payment_request=best_match,
        candidate_matches=candidate_matches[:10],
        confirmed_fields={f.field_key: f.final_value for f in batch.fields},
    )


def reconcile_reviewed_batch_service(
    db: Session,
    batch_id: int,
    payload: SwiftBatchReconcileRequest,
) -> PaymentRequestResponse:
    """
    Reconciles a reviewed and confirmed batch against a payment request strictly using `final_value`.
    REJECTS with 403 if batch is not in 'REVIEWED_CONFIRMED'.
    """
    from modules.import_files.model import ImportFile

    batch = repo.get_swift_extraction_batch(db, batch_id)
    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"SWIFT extraction batch {batch_id} not found.",
        )

    if batch.status not in ("REVIEWED_CONFIRMED", "RECONCILED"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="SWIFT batch must be in REVIEWED_CONFIRMED status to reconcile.",
        )

    db_item = repo.get_payment_request_by_id(db, payload.payment_id)
    if not db_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payload.payment_id} not found.",
        )

    field_map = {f.field_key: f.final_value for f in batch.fields}

    swift_ref = field_map.get("transaction_reference") or f"SWF-REF-{batch.batch_id}"
    raw_date = field_map.get("value_date")
    receipt_date = date.today()
    if raw_date:
        try:
            receipt_date = datetime.strptime(raw_date, "%Y-%m-%d").date()
        except Exception:
            pass

    try:
        amt = float(field_map.get("amount") or db_item.requested_amount)
    except Exception:
        amt = float(db_item.requested_amount)

    curr = field_map.get("currency") or db_item.currency_code
    beneficiary_swift = field_map.get("beneficiary_bank_swift")
    sender_swift = field_map.get("sender_bank_swift")
    sender_bank = field_map.get("sender_bank_name")
    iban_acc = field_map.get("beneficiary_account_or_iban")

    db_item.swift_reference_no = swift_ref
    db_item.swift_receipt_date = receipt_date
    db_item.swift_transferred_amount = amt
    db_item.swift_transferred_currency = curr

    # Payment request SWIFT code must ALWAYS store the Beneficiary Bank's SWIFT (:57A), NOT the Sender/Issuing Bank!
    if beneficiary_swift:
        db_item.swift_code = beneficiary_swift
    if iban_acc:
        db_item.iban_account_no = iban_acc

    variance = amt - float(db_item.requested_amount)
    db_item.swift_variance_amount = round(variance, 2)
    if abs(variance) < 0.01:
        db_item.swift_variance_status = "Matched"
    elif variance < 0:
        db_item.swift_variance_status = "Deficit"
    else:
        db_item.swift_variance_status = "Surplus"

    if db_item.request_date and receipt_date:
        delta = (receipt_date - db_item.request_date).days
        db_item.swift_processing_days = max(0, delta)

    recon_notes = []
    if payload.notes:
        recon_notes.append(payload.notes)
    if sender_swift or sender_bank:
        sender_label = f"البنك المنفذ في مصر: {sender_bank or ''} ({sender_swift or ''})".strip()
        recon_notes.append(sender_label)
    if recon_notes:
        db_item.swift_reconciliation_notes = " | ".join(recon_notes)

    if payload.auto_execute:
        _handle_swift_payment_completion_workflow(
            db=db,
            db_item=db_item,
            swift_reference_no=swift_ref,
            transferred_amount=amt,
            currency_code=curr,
        )
    elif db_item.import_file_id:
        from modules.import_files.model import ImportFile
        imp = db.query(ImportFile).filter(ImportFile.import_file_id == db_item.import_file_id).first()
        if imp:
            imp.swift_no = swift_ref

    repo.update_swift_batch_status(
        db=db,
        batch_id=batch_id,
        status="RECONCILED",
        matched_payment_id=db_item.payment_id,
    )

    db.commit()
    db.refresh(db_item)
    return db_item


def smart_extract_swift_service(
    db: Session, payload: SmartSwiftExtractRequest
) -> SmartSwiftExtractResponse:
    """
    Parses raw SWIFT MT103 text, creates an extraction batch in 'EXTRACTED_PENDING_REVIEW',
    and generates preliminary candidate matches.
    """
    from modules.financial_approval.swift_mt103_parser import (
        parse_swift_mt103_text,
        match_swift_against_payment_request,
    )

    parsed = parse_swift_mt103_text(payload.raw_text)
    if not parsed.get("success"):
        return SmartSwiftExtractResponse(
            success=False,
            parsed_swift={},
            matched_payment_request=None,
            candidate_matches=[],
            error=parsed.get("error", "Failed to parse SWIFT MT103 text"),
        )

    # Create extraction batch for review
    batch_resp = extract_swift_for_review_service(
        db=db,
        raw_text=payload.raw_text,
        filename="pasted_swift_text.txt",
        file_type="Text Input",
    )

    all_requests = repo.get_all_payment_requests(db, include_inactive=False)
    candidate_matches = []
    best_match = None
    highest_score = -1

    for req in all_requests:
        match_info = match_swift_against_payment_request(parsed, req)
        candidate_matches.append(match_info)

        if payload.target_payment_id and req.payment_id == payload.target_payment_id:
            best_match = match_info
            highest_score = 999
        elif match_info["confidence_score"] > highest_score:
            highest_score = match_info["confidence_score"]
            best_match = match_info

    candidate_matches.sort(key=lambda x: x["confidence_score"], reverse=True)

    return SmartSwiftExtractResponse(
        success=True,
        parsed_swift=parsed,
        matched_payment_request=best_match,
        candidate_matches=candidate_matches[:10],
        raw_text=payload.raw_text,
        batch_id=batch_resp.batch_id,
        batch=batch_resp,
    )


def smart_extract_swift_from_file_service(
    db: Session,
    filename: str,
    content_bytes: bytes,
    target_payment_id: Optional[int] = None,
) -> SmartSwiftExtractResponse:
    """
    Extracts text from uploaded Word, Excel, PDF, or Image file, creates an extraction batch
    in 'EXTRACTED_PENDING_REVIEW', and prepares candidate matches.
    """
    from modules.financial_approval.swift_file_extractor import extract_text_from_swift_file
    from modules.financial_approval.swift_mt103_parser import (
        parse_swift_mt103_text,
        match_swift_against_payment_request,
    )

    raw_text, normalized_text = extract_text_from_swift_file(filename, content_bytes)
    if not normalized_text.strip() and not raw_text.strip():
        return SmartSwiftExtractResponse(
            success=False,
            parsed_swift={},
            matched_payment_request=None,
            candidate_matches=[],
            raw_text="",
            detected_filename=filename,
            error=f"Could not extract readable text from file '{filename}'. Ensure the file is not empty or corrupted.",
        )

    # Parse normalized text
    text_to_parse = normalized_text if normalized_text.strip() else raw_text
    parsed = parse_swift_mt103_text(text_to_parse)

    # Detect file type label
    lower = filename.lower()
    if lower.endswith('.pdf'):
        f_type = "PDF Document"
    elif lower.endswith(('.docx', '.doc')):
        f_type = "Word Document"
    elif lower.endswith(('.xlsx', '.xls', '.csv')):
        f_type = "Excel Spreadsheet"
    elif lower.endswith(('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif')):
        f_type = "Image / Scanned Slip (OCR)"
    else:
        f_type = "Text File"

    # Create extraction batch for review
    batch_resp = extract_swift_for_review_service(
        db=db,
        raw_text=raw_text if raw_text.strip() else normalized_text,
        filename=filename,
        file_type=f_type,
    )

    all_requests = repo.get_all_payment_requests(db, include_inactive=False)
    candidate_matches = []
    best_match = None
    highest_score = -1

    for req in all_requests:
        match_info = match_swift_against_payment_request(parsed, req)
        candidate_matches.append(match_info)

        if target_payment_id and req.payment_id == target_payment_id:
            best_match = match_info
            highest_score = 999
        elif match_info["confidence_score"] > highest_score:
            highest_score = match_info["confidence_score"]
            best_match = match_info

    candidate_matches.sort(key=lambda x: x["confidence_score"], reverse=True)

    return SmartSwiftExtractResponse(
        success=parsed.get("success", True),
        parsed_swift=parsed,
        matched_payment_request=best_match,
        candidate_matches=candidate_matches[:10],
        raw_text=raw_text if raw_text.strip() else normalized_text,
        detected_filename=filename,
        detected_file_type=f_type,
        batch_id=batch_resp.batch_id,
        batch=batch_resp,
    )


def smart_reconcile_swift_service(
    db: Session, payload: SmartSwiftReconcileRequest
) -> PaymentRequestSession:
    """
    Auto-updates Payment Request with confirmed SWIFT details, performs variance
    reconciliation, confirms bank info, and marks as Paid.
    """
    from modules.import_files.model import ImportFile

    db_item = repo.get_payment_request_by_id(db, payload.payment_id)
    if not db_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Payment Request ID {payload.payment_id} not found.",
        )

    # 1. Update SWIFT fields
    db_item.swift_reference_no = payload.swift_reference_no
    db_item.swift_receipt_date = payload.swift_receipt_date
    db_item.swift_transferred_amount = payload.swift_transferred_amount
    db_item.swift_transferred_currency = payload.swift_transferred_currency

    # 2. Update / Confirm Bank details if provided
    if payload.bank_name:
        db_item.bank_name = payload.bank_name
    if payload.swift_code:
        db_item.swift_code = payload.swift_code
    if payload.iban_account_no:
        db_item.iban_account_no = payload.iban_account_no

    # 3. Calculate variance & processing days
    variance = float(payload.swift_transferred_amount) - float(db_item.requested_amount)
    db_item.swift_variance_amount = round(variance, 2)

    if abs(variance) < 0.01:
        db_item.swift_variance_status = "Matched"
    elif variance < 0:
        db_item.swift_variance_status = "Deficit"
    else:
        db_item.swift_variance_status = "Surplus"

    if db_item.request_date and payload.swift_receipt_date:
        delta = (payload.swift_receipt_date - db_item.request_date).days
        db_item.swift_processing_days = max(0, delta)

    if payload.swift_reconciliation_notes:
        db_item.swift_reconciliation_notes = payload.swift_reconciliation_notes

    if payload.auto_execute:
        _handle_swift_payment_completion_workflow(
            db=db,
            db_item=db_item,
            swift_reference_no=payload.swift_reference_no,
            transferred_amount=payload.swift_transferred_amount,
            currency_code=payload.swift_transferred_currency,
        )
    elif db_item.import_file_id:
        from modules.import_files.model import ImportFile
        imp = db.query(ImportFile).filter(ImportFile.import_file_id == db_item.import_file_id).first()
        if imp:
            imp.swift_no = payload.swift_reference_no

    db.commit()
    db.refresh(db_item)
    return db_item

