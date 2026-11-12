"""
Banking Documents & Form 4 Workflow Service (Phase 3 - BP-015).
"""

import logging
from datetime import date, datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Set, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

from modules.freight_booking.model import ShipmentBooking
from modules.import_companies.model import ImportCompany
from modules.cargo_shipping.model import CargoShippingRecord
from modules.suppliers.model import Supplier
from modules.import_documentation.model import POPackingReconciliationSession, DraftBLReviewSession, ShipmentDocumentItem, BankingDocumentSession, AcidRegistrationSession, CertificateOfOriginReviewSession, InspectionCertificateReviewSession, InvoiceBLMatchSession


from modules.import_documentation.model import BankingDocumentSession
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.import_documentation.schemas import *
from modules.import_documentation.validators import (
    validate_no_duplicate_form4_session,
    validate_status,
)
import modules.import_documentation.repository as repo
from modules.common.system_messages import coded_text, msg, render_en
from modules.common.enum_codes import Placeholder, finalize_structured_values
from modules.common.file_tracking import set_file_tracking
from modules.common.errors import best_effort
from modules.common.validators import not_found, require_active
from modules.import_files.repository import codes_by_ids

from modules.import_documentation.doc_common import (
    SYSTEM_ACTOR,
    LABEL_IMPORT_FILE,
    LABEL_BANKING_DOC,
    LABEL_PURCHASE_ORDER,
    _actor,
    _bad_request,
    _conflict,
    _active_import_file,
    _get_active_import_file,
    _require_active_po,
    _validate_currency_code,
    _commit_follow_up,
    _lifecycle_follow_up,
    get_import_files_map,
)

def get_swift_coverage_for_file(db: Session, import_file_id: Optional[int]) -> Optional[Any]:
    if not import_file_id:
        return None
    from modules.import_documentation.schemas import SwiftCoverageSummary
    from modules.import_files.model import ImportFile
    from modules.financial_approval.model import PaymentRequestSession
    from modules.external_service_providers.model import ExternalServiceProvider

    imp = db.query(ImportFile).filter(ImportFile.import_file_id == import_file_id).first()
    if not imp:
        return None

    # Calculate total invoice amount
    invoice_amount = 0.0
    invoice_currency = "USD"
    if imp.invoices_data and isinstance(imp.invoices_data, list):
        for inv in imp.invoices_data:
            if isinstance(inv, dict):
                invoice_amount += float(inv.get("amount", 0.0) or 0.0)
                if inv.get("currency"):
                    invoice_currency = inv.get("currency")
    if invoice_amount == 0.0 and imp.estimated_cost:
        invoice_amount = float(imp.estimated_cost)
        invoice_currency = imp.estimated_cost_currency or "USD"

    # Query payment requests
    payments = (
        db.query(PaymentRequestSession)
        .filter(
            PaymentRequestSession.import_file_id == import_file_id,
            PaymentRequestSession.is_active == True,
        )
        .all()
    )

    total_transferred = 0.0
    swift_refs: List[str] = []
    exec_bank_id: Optional[int] = None
    exec_bank_name: Optional[str] = None

    for p in payments:
        if p.swift_transferred_amount:
            total_transferred += float(p.swift_transferred_amount)
        elif p.status == "Paid":
            total_transferred += float(p.requested_amount)

        if p.swift_reference_no and p.swift_reference_no not in swift_refs:
            swift_refs.append(p.swift_reference_no)

        # Detect executing bank from swift reconciliation notes
        if not exec_bank_name and p.swift_reconciliation_notes:
            import re
            m = re.search(r"Executing bank in Egypt:\s*([^\(]+)", p.swift_reconciliation_notes, re.IGNORECASE)
            if m:
                exec_bank_name = m.group(1).strip()

    # Fallback to imp.swift_no
    if imp.swift_no and imp.swift_no not in swift_refs:
        swift_refs.append(imp.swift_no)

    # If executing bank found by name, resolve its ID from external_service_providers
    if exec_bank_name:
        bank_p = (
            db.query(ExternalServiceProvider)
            .filter(
                ExternalServiceProvider.partner_type == "Bank",
                ExternalServiceProvider.partner_name.ilike(f"%{exec_bank_name}%"),
                ExternalServiceProvider.is_active == True,
            )
            .first()
        )
        if bank_p:
            exec_bank_id = bank_p.provider_id
            exec_bank_name = bank_p.partner_name

    coverage_pct = round((total_transferred / invoice_amount) * 100, 2) if invoice_amount > 0 else (100.0 if total_transferred > 0 else 0.0)
    is_fully_covered = coverage_pct >= 99.0 or (total_transferred > 0 and invoice_amount == 0.0)

    return SwiftCoverageSummary(
        invoice_amount=invoice_amount,
        invoice_currency=invoice_currency,
        total_swift_transferred_amount=total_transferred,
        coverage_percent=coverage_pct,
        is_fully_covered=is_fully_covered,
        executing_bank_id=exec_bank_id,
        executing_bank_name=exec_bank_name,
        swift_references=swift_refs,
    )



def enrich_banking_response(db: Session, item: BankingDocumentSession, import_file: Optional[Any] = None):
    import_file_code = None
    importer_name = None
    supplier_name = None
    po_number = None

    if item.import_file_id:
        imp = import_file if import_file is not None else get_import_files_map(db, [item.import_file_id]).get(item.import_file_id)
        if imp:
            import_file_code = imp.import_file_code or imp.custom_file_number
            importer_name = imp.company_name
            supplier_name = imp.supplier_name
            po_number = imp.po_number

    swift_cov = get_swift_coverage_for_file(db, item.import_file_id)

    blockers: List[str] = []
    if (item.tax_coding_sheet_status or "NOT_STARTED") != "UPLOADED_BY_ACCOUNTANT":
        blockers.append("شيت التكويد الضريبي لم يتم رفعه وتكويده على منصة نافذة بواسطة محاسب الشركة بعد.")
    if not item.items_pulled_verified:
        blockers.append("لم يقم المستخلص الجمركي بسحب الأصناف على نافذة للتحقق من نجاح التكويد.")
    if (item.nafeza_bank_link_status or "PENDING") != "LINKED_TO_BANK":
        blockers.append("لم يتم ربط الشحنة على البنك في منصة نافذة بواسطة المستخلص الجمركي.")
    if not item.is_bank_matching_swift:
        blockers.append("البنك المربوط عليه في نافذة لا يطابق البنك المنفذ لسويفت التحويل.")

    can_submit = len(blockers) == 0

    from modules.import_documentation.schemas import BankingDocumentResponse
    res = BankingDocumentResponse.model_validate(item)
    res.import_file_code = import_file_code
    res.importer_name = importer_name
    res.supplier_name = supplier_name
    res.po_number = po_number
    res.swift_coverage = swift_cov
    res.can_submit_form4 = can_submit
    res.blockers = blockers
    return res



def _handle_banking_document_verification_workflow(
    db: Session,
    db_item: BankingDocumentSession,
    previous_status: Optional[str] = None,
    previous_ref: Optional[str] = None,
) -> None:
    """
    Central business engine workflow triggered whenever a Banking Document
    (Form 4 / Form 9 / Letter of Credit L/C) is linked, updated, or received (DC-03 / BP-015):
    1. Synchronizes document reference, request date, received date, and execution days into linked ImportFile.
    2. If the document is approved/received/issued (has a non-pending reference number),
       advances ImportFile lifecycle from STEP_12 to STEP_13 (Customs Declaration 46).
    3. Auto-completes prior pending SmartTasks for Form 4 / LC bank approvals.
    4. Dispatches new SmartTask for Customs Broker / Specialist to prepare Customs Declaration 46 (CS-03 / STEP_13).
    5. Emits SystemNotification for CUSTOMS_BROKER & FINANCIAL_CONTROLLER & ALL.

    Runs after the document commit: every step is a best-effort follow-up that commits its own work (DOC-11).
    BE03-T09: Follow-ups 2-5 only fire on transition into the issued state (was not issued before, or reference number changed).
    """
    if not db_item.import_file_id:
        return

    ref_num = (db_item.doc_reference_number or "").strip()
    is_valid_ref = bool(ref_num and ref_num.upper() != "PENDING")

    imp = _get_active_import_file(db, db_item.import_file_id)
    if not imp:
        return
    file_id = imp.import_file_id
    doc_type = db_item.doc_type
    bank_name = db_item.bank_name
    bank_doc_id = db_item.bank_doc_id

    # 1. Synchronize to ImportFile
    def _sync_file() -> None:
        if db_item.request_date:
            imp.form4_request_date = db_item.request_date
        if is_valid_ref:
            imp.form4_no = ref_num
        if db_item.received_date:
            imp.form4_received_date = db_item.received_date
            imp.form4_execution_days = db_item.execution_days

    _commit_follow_up(db, _sync_file, "Banking document import file sync")

    # Only advance lifecycle and dispatch next tasks if it's verified / received / approved by bank
    if not (is_valid_ref and db_item.status in ["Received", "Approved by Bank", "Form Issued", "Verified", "Endorsed"]):
        return

    # BE03-T09: Only fire lifecycle advance, smart tasks, and notifications on transition into issued state
    prev_ref = (previous_ref or "").strip()
    prev_is_valid_ref = bool(prev_ref and prev_ref.upper() != "PENDING")
    prev_was_issued = prev_is_valid_ref and (previous_status in ["Received", "Approved by Bank", "Form Issued", "Verified", "Endorsed"])
    if prev_was_issued and prev_ref == ref_num:
        return

    imp = _get_active_import_file(db, file_id)
    if not imp:
        return
    file_code = imp.import_file_code or imp.custom_file_number or f"IMP-{imp.import_file_id}"

    # 2. Advance lifecycle from STEP_12 to STEP_13
    _lifecycle_follow_up(
        db, "Lifecycle advance STEP_12->STEP_13",
        completed_step_code="STEP_12",
        import_file_id=file_id,
        target_step_codes=["STEP_13"],
        auto_complete_prior=True,
        assigned_user="Customs Broker",
        notes_msg=msg(
            "DOC_BANK_DOCUMENT_RECORDED",
            doc_type=doc_type,
            reference_no=ref_num,
            import_file_code=file_code,
        ),
        next_action_msg=msg("NA_CS_REGISTER_DECLARATION_46"),
        source_module="Banking Documents Engine",
        min_progress_percent=65.0,
    )

    # 3. Auto-complete prior pending SmartTasks for Banking Document / Form 4
    def _complete_prior_tasks() -> None:
        from modules.smart_tasks.model import SmartTask
        pending_tasks = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == file_id,
                SmartTask.status.in_(["Pending", "In Progress"]),
            )
            .all()
        )
        for t in pending_tasks:
            combined_text = (t.title or "") + " " + (t.description or "") + " " + (t.reminder_type or "")
            if any(k in combined_text for k in ["نموذج 4", "اعتماد", "Form 4", "L/C", "STEP_12", "مستند بنكي", "المصادقة البنكية"]):
                t.status = "Completed"
                t.completion_notes = f"{doc_type} no. {ref_num} received and approved via {bank_name}."

    _commit_follow_up(db, _complete_prior_tasks, "Complete prior banking smart tasks")

    # 4. Dispatch new SmartTask for Customs Broker / Specialist (CS-03 / STEP_13)
    def _create_declaration_task() -> None:
        from modules.smart_tasks.model import SmartTask
        from modules.smart_tasks.repository import create_task as create_smart_task
        from modules.smart_tasks.schemas import SmartTaskCreate

        decl_task_msg = msg(
            "DOC_TASK_DECLARATION_46",
            import_file_code=file_code,
            doc_type=doc_type,
            reference_no=ref_num,
            bank_name=bank_name,
        )

        # BE03-T09: Skip if an active non-completed task already exists for this file and message
        existing_task = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == file_id,
                SmartTask.msg_code == decl_task_msg.code,
                SmartTask.is_active == True,
                SmartTask.status.in_(["Pending", "In Progress"]),
            )
            .first()
        )
        if existing_task:
            return

        task_title = render_en(decl_task_msg.code, decl_task_msg.params, "title")
        task_desc = render_en(decl_task_msg.code, decl_task_msg.params, "body")
        decl_due = date.today() + timedelta(days=2)
        task_schema = SmartTaskCreate(
            title=task_title,
            description=task_desc,
            task_type="System Generated",
            import_file_id=file_id,
            import_file_code=file_code,
            phase_name="Phase 5: Port Operations & Clearance",
            assigned_user="Customs Broker",
            priority="High",
            reminder_type="Customs Declaration 46",
            due_date=str(decl_due),
            status="Pending",
            notes=f"ACTION:DECLARATION_46 | File: {file_code} | BankDoc: {ref_num}",
        )
        create_smart_task(
            db, task_schema, created_by="Banking Documents Engine",
            msg_code=decl_task_msg.code, msg_params=decl_task_msg.params, commit=False,
        )

    _commit_follow_up(db, _create_declaration_task, "Create Customs Declaration 46 smart task")

    # 5. Emit SystemNotification
    def _notify() -> None:
        from modules.notifications.model import SystemNotification
        bank_msg = msg(
            "DOC_BANK_DOCUMENT_RECORDED",
            doc_type=doc_type,
            reference_no=ref_num,
            bank_name=bank_name,
            import_file_code=file_code,
        )
        db.add(SystemNotification(
            title=render_en(bank_msg.code, bank_msg.params, "title"),
            message=render_en(bank_msg.code, bank_msg.params, "body"),
            msg_code=bank_msg.code,
            msg_params=bank_msg.params,
            severity="INFO",
            category="BANKING_DOCUMENT_VERIFICATION",
            entity_type="BankingDocumentSession",
            entity_id=bank_doc_id,
            target_role="CUSTOMS_BROKER",
        ))

    _commit_follow_up(db, _notify, "Banking system notification")


def create_banking_document_service(
    db: Session, schema: BankingDocumentCreate, user: Optional[str] = None
):
    if schema.import_file_id is not None:
        _active_import_file(db, schema.import_file_id)
    _require_active_po(db, schema.po_id)
    _validate_currency_code(db, schema.currency_code)
    if schema.doc_type == "Form 4":
        validate_no_duplicate_form4_session(db, schema.import_file_id)

    # Auto-resolve SWIFT executing bank if not explicitly provided
    if schema.import_file_id and (not schema.swift_executing_bank_name or not schema.swift_reference_no):
        swift_cov = get_swift_coverage_for_file(db, schema.import_file_id)
        if swift_cov:
            if not schema.swift_executing_bank_name and swift_cov.executing_bank_name:
                schema.swift_executing_bank_id = swift_cov.executing_bank_id
                schema.swift_executing_bank_name = swift_cov.executing_bank_name
            if not schema.swift_reference_no and swift_cov.swift_references:
                schema.swift_reference_no = swift_cov.swift_references[0]
            if (not schema.bank_id or schema.bank_name in ["", "PENDING"]) and swift_cov.executing_bank_name:
                schema.bank_id = swift_cov.executing_bank_id
                schema.bank_name = swift_cov.executing_bank_name

    item = repo.create_banking_document(db, schema, user=user)

    # Dispatch initial SmartTask for Broker to pull Tax Coding Sheet
    if item.import_file_id and item.tax_coding_sheet_status == "NOT_STARTED":
        def _dispatch_pull_task():
            from modules.smart_tasks.repository import create_task as create_smart_task
            from modules.smart_tasks.schemas import SmartTaskCreate
            from modules.import_files.model import ImportFile
            imp = db.query(ImportFile).filter(ImportFile.import_file_id == item.import_file_id).first()
            f_code = imp.import_file_code if imp else f"IMP-{item.import_file_id}"
            pull_msg = msg("DOC_TASK_TAX_CODING_PULL", import_file_code=f_code)
            task_schema = SmartTaskCreate(
                title=render_en(pull_msg.code, pull_msg.params, "title"),
                description=render_en(pull_msg.code, pull_msg.params, "body"),
                task_type="System Generated",
                import_file_id=item.import_file_id,
                import_file_code=f_code,
                phase_name="Phase 4: Digital & Banking",
                assigned_user="Customs Broker",
                priority="High",
                reminder_type="Tax Coding Sheet",
                due_date=str(date.today() + timedelta(days=2)),
                status="Pending",
                notes=f"ACTION:TAX_CODING_PULL | BankDoc: {item.bank_doc_code}",
            )
            create_smart_task(
                db, task_schema, created_by="Banking Documents Engine",
                msg_code=pull_msg.code, msg_params=pull_msg.params, commit=False,
            )

        _commit_follow_up(db, _dispatch_pull_task, "Dispatch tax coding sheet pull task")

    # Sync and trigger workflow
    _handle_banking_document_verification_workflow(db, item, previous_status=None, previous_ref=None)

    return enrich_banking_response(db, item)


def _get_banking_document_or_404(db: Session, bank_doc_id: int) -> BankingDocumentSession:
    item = repo.get_banking_document_by_id(db, bank_doc_id)
    if not item:
        raise not_found(LABEL_BANKING_DOC, bank_doc_id)
    return item


def update_banking_document_service(
    db: Session, bank_doc_id: int, schema: BankingDocumentUpdate, user: Optional[str] = None
):
    validate_status("banking", schema.status)
    item = _get_banking_document_or_404(db, bank_doc_id)

    if schema.currency_code is not None:
        _validate_currency_code(db, schema.currency_code)

    if schema.import_file_id is not None:
        _active_import_file(db, schema.import_file_id)
        validate_no_duplicate_form4_session(db, schema.import_file_id, current_doc_id=bank_doc_id)
    if getattr(schema, "po_id", None) is not None:
        _require_active_po(db, schema.po_id)

    prev_status = item.status
    prev_ref = item.doc_reference_number
    updated = repo.update_banking_document(db, item, schema, user=user)

    # Sync and trigger workflow
    _handle_banking_document_verification_workflow(db, updated, previous_status=prev_status, previous_ref=prev_ref)

    return enrich_banking_response(db, updated)


def receive_banking_document_service(
    db: Session, bank_doc_id: int, form4_number: str, received_date: date, notes: str | None = None,
    user: Optional[str] = None,
):
    item = _get_banking_document_or_404(db, bank_doc_id)

    prev_status = item.status
    prev_ref = item.doc_reference_number

    req_date = item.request_date or item.issue_date
    if req_date and received_date < req_date:
        raise _bad_request(
            f"تاريخ الاستلام ({received_date}) لا يمكن أن يكون قبل تاريخ الطلب ({req_date})."
        )
    exec_days = max(0, (received_date - (req_date or date.today())).days)

    item.doc_reference_number = form4_number.strip()
    item.received_date = received_date
    item.execution_days = exec_days
    item.status = "Received"
    if notes:
        item.notes = f"{item.notes}\n{notes}" if item.notes else notes

    item.updated_at = datetime.now(timezone.utc)
    if user is not None:
        item.updated_by = user
    db.commit()
    db.refresh(item)

    # Sync and trigger workflow
    _handle_banking_document_verification_workflow(db, item, previous_status=prev_status, previous_ref=prev_ref)

    return enrich_banking_response(db, item)


def delete_banking_document_service(db: Session, bank_doc_id: int, user: Optional[str] = None):
    item = _get_banking_document_or_404(db, bank_doc_id)
    repo.delete_banking_document(db, item)
    db.commit()
    return {"status": "success", "message": f"Banking Document {bank_doc_id} deleted"}


def list_banking_documents_service(
    db: Session,
    import_file_id: Optional[int] = None,
    skip: int = 0,
    limit: Optional[int] = None,
    return_total: bool = False,
) -> Union[List[Any], Tuple[List[Any], int]]:
    """Banking documents with import file details, one bulk file query (DOC-17 / DOC-24)."""
    res = repo.get_all_banking_documents(
        db, import_file_id=import_file_id, skip=skip, limit=limit, return_total=return_total
    )
    if return_total:
        items, total = res
    else:
        items, total = res, len(res)

    import_files_map = get_import_files_map(db, [item.import_file_id for item in items])
    enriched = [enrich_banking_response(db, item, import_file=import_files_map.get(item.import_file_id)) for item in items]
    return (enriched, total) if return_total else enriched


def get_banking_document_service(db: Session, bank_doc_id: int):
    return enrich_banking_response(db, _get_banking_document_or_404(db, bank_doc_id))


def record_tax_coding_sheet_pull_service(
    db: Session, bank_doc_id: int, schema: Any, user: Optional[str] = None
):
    item = _get_banking_document_or_404(db, bank_doc_id)
    item.tax_coding_sheet_status = "PULLED_BY_BROKER"
    item.tax_coding_pulled_date = schema.pulled_date
    if schema.broker_id:
        item.tax_coding_broker_id = schema.broker_id
    if schema.broker_name:
        item.tax_coding_broker_name = schema.broker_name
    if schema.file_url:
        item.tax_coding_sheet_file_url = schema.file_url
    if schema.notes:
        item.notes = f"{item.notes}\n[Tax coding sheet] Broker pull: {schema.notes}" if item.notes else f"[Tax coding sheet] Broker pull: {schema.notes}"

    item.updated_at = datetime.now(timezone.utc)
    if user is not None:
        item.updated_by = user
    db.commit()
    db.refresh(item)

    # Smart Tasks: close broker pull task, dispatch accountant upload task
    def _handle_pull_tasks():
        from modules.smart_tasks.model import SmartTask
        from modules.smart_tasks.repository import create_task as create_smart_task
        from modules.smart_tasks.schemas import SmartTaskCreate
        from modules.import_files.model import ImportFile

        f_id = item.import_file_id
        imp = db.query(ImportFile).filter(ImportFile.import_file_id == f_id).first() if f_id else None
        f_code = imp.import_file_code if imp else f"IMP-{f_id}"

        # Close pending broker pull tasks
        pending = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == f_id,
                SmartTask.status.in_(["Pending", "In Progress"]),
            )
            .all()
        )
        for t in pending:
            if "سحب شيت التكويد" in (t.title or "") or (t.notes and "ACTION:TAX_CODING_PULL" in t.notes):
                t.status = "Completed"
                t.completion_notes = f"Tax coding sheet pulled by the customs broker on {schema.pulled_date}."

        # Create task for Company Accountant
        upload_msg = msg("DOC_TASK_TAX_CODING_UPLOAD", import_file_code=f_code)
        acc_task = SmartTaskCreate(
            title=render_en(upload_msg.code, upload_msg.params, "title"),
            description=render_en(upload_msg.code, upload_msg.params, "body"),
            task_type="System Generated",
            import_file_id=f_id,
            import_file_code=f_code,
            phase_name="Phase 4: Digital & Banking",
            assigned_user="Company Accountant",
            priority="High",
            reminder_type="Tax Coding Upload",
            due_date=str(date.today() + timedelta(days=2)),
            status="Pending",
            notes=f"ACTION:TAX_CODING_UPLOAD | BankDoc: {item.bank_doc_code}",
        )
        create_smart_task(
            db, acc_task, created_by="Banking Documents Engine",
            msg_code=upload_msg.code, msg_params=upload_msg.params, commit=False,
        )

    _commit_follow_up(db, _handle_pull_tasks, "Tax coding pull smart tasks")
    return enrich_banking_response(db, item)


def record_tax_coding_sheet_upload_service(
    db: Session, bank_doc_id: int, schema: Any, user: Optional[str] = None
):
    item = _get_banking_document_or_404(db, bank_doc_id)
    item.tax_coding_sheet_status = "UPLOADED_BY_ACCOUNTANT"
    item.tax_coding_uploaded_date = schema.uploaded_date
    item.tax_coding_accountant_name = schema.accountant_name
    if schema.items_count_coded is not None:
        item.items_count_coded = schema.items_count_coded
    if schema.items_count_total is not None:
        item.items_count_total = schema.items_count_total
    if schema.file_url:
        item.tax_coding_sheet_file_url = schema.file_url
    if schema.notes:
        item.notes = f"{item.notes}\n[Tax coding sheet] Accountant upload: {schema.notes}" if item.notes else f"[Tax coding sheet] Accountant upload: {schema.notes}"

    item.updated_at = datetime.now(timezone.utc)
    if user is not None:
        item.updated_by = user
    db.commit()
    db.refresh(item)

    # Smart Tasks: close accountant upload task, dispatch broker verify & link task
    def _handle_upload_tasks():
        from modules.smart_tasks.model import SmartTask
        from modules.smart_tasks.repository import create_task as create_smart_task
        from modules.smart_tasks.schemas import SmartTaskCreate
        from modules.import_files.model import ImportFile

        f_id = item.import_file_id
        imp = db.query(ImportFile).filter(ImportFile.import_file_id == f_id).first() if f_id else None
        f_code = imp.import_file_code if imp else f"IMP-{f_id}"

        # Close pending accountant upload tasks
        pending = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == f_id,
                SmartTask.status.in_(["Pending", "In Progress"]),
            )
            .all()
        )
        for t in pending:
            if "رفع وتكويد شيت" in (t.title or "") or (t.notes and "ACTION:TAX_CODING_UPLOAD" in t.notes):
                t.status = "Completed"
                t.completion_notes = f"Items tax sheet coded and uploaded on Nafeza by accountant {schema.accountant_name} on {schema.uploaded_date}."

        target_bank = item.swift_executing_bank_name or item.bank_name
        # Create task for Customs Broker to pull items & link bank
        if target_bank:
            verify_msg = msg("DOC_TASK_ITEMS_VERIFY_BANK_LINK", bank_name=target_bank, import_file_code=f_code)
        else:
            verify_msg = msg("DOC_TASK_ITEMS_VERIFY_SWIFT_BANK_LINK", import_file_code=f_code)
        broker_task = SmartTaskCreate(
            title=render_en(verify_msg.code, verify_msg.params, "title"),
            description=render_en(verify_msg.code, verify_msg.params, "body"),
            task_type="System Generated",
            import_file_id=f_id,
            import_file_code=f_code,
            phase_name="Phase 4: Digital & Banking",
            assigned_user="Customs Broker",
            priority="High",
            reminder_type="Items Verification & Bank Linkage",
            due_date=str(date.today() + timedelta(days=1)),
            status="Pending",
            notes=f"ACTION:ITEMS_VERIFY_AND_BANK_LINK | BankDoc: {item.bank_doc_code}",
        )
        create_smart_task(
            db, broker_task, created_by="Banking Documents Engine",
            msg_code=verify_msg.code, msg_params=verify_msg.params, commit=False,
        )

    _commit_follow_up(db, _handle_upload_tasks, "Tax coding upload smart tasks")
    return enrich_banking_response(db, item)


def record_items_verification_service(
    db: Session, bank_doc_id: int, schema: Any, user: Optional[str] = None
):
    item = _get_banking_document_or_404(db, bank_doc_id)
    item.items_pulled_verified = schema.verified
    item.items_pulled_date = schema.verified_date
    if schema.items_count_total is not None:
        item.items_count_total = schema.items_count_total
    if schema.items_count_coded is not None:
        item.items_count_coded = schema.items_count_coded
    if schema.regulatory_bodies_detected is not None:
        item.regulatory_bodies_detected = schema.regulatory_bodies_detected
    if schema.notes:
        item.notes = f"{item.notes}\n[Items pull] Broker confirmation: {schema.notes}" if item.notes else f"[Items pull] Broker confirmation: {schema.notes}"

    item.updated_at = datetime.now(timezone.utc)
    if user is not None:
        item.updated_by = user
    db.commit()
    db.refresh(item)

    # If regulatory bodies detected (e.g. GOEIC, NFSA, etc.), emit notification / alert
    if schema.regulatory_bodies_detected:
        def _regulatory_alert():
            from modules.notifications.model import SystemNotification
            from modules.import_files.model import ImportFile
            imp = db.query(ImportFile).filter(ImportFile.import_file_id == item.import_file_id).first() if item.import_file_id else None
            f_code = imp.import_file_code if imp else f"IMP-{item.import_file_id}"
            alert_msg = msg(
                "DOC_REGULATORY_BODIES_DETECTED",
                import_file_code=f_code,
                regulatory_bodies=", ".join(schema.regulatory_bodies_detected),
            )
            db.add(SystemNotification(
                title=render_en(alert_msg.code, alert_msg.params, "title"),
                message=render_en(alert_msg.code, alert_msg.params, "body"),
                msg_code=alert_msg.code,
                msg_params=alert_msg.params,
                target_role="CUSTOMS_BROKER",
            ))

        _commit_follow_up(db, _regulatory_alert, "Regulatory screening alert")

    return enrich_banking_response(db, item)


def record_nafeza_bank_link_service(
    db: Session, bank_doc_id: int, schema: Any, user: Optional[str] = None
):
    from fastapi import HTTPException
    from modules.external_service_providers.model import ExternalServiceProvider

    item = _get_banking_document_or_404(db, bank_doc_id)
    bank_p = db.query(ExternalServiceProvider).filter(
        ExternalServiceProvider.provider_id == schema.bank_id,
        ExternalServiceProvider.is_active == True,
    ).first()
    if not bank_p:
        raise not_found("Bank", schema.bank_id)

    bank_name = bank_p.partner_name

    # Check match against SWIFT executing bank
    is_matching = True
    if item.swift_executing_bank_name:
        clean_target = (item.swift_executing_bank_name or "").strip().lower()
        clean_selected = bank_name.strip().lower()
        is_matching = (clean_target in clean_selected) or (clean_selected in clean_target)

    if not is_matching and not getattr(schema, "override_swift_mismatch", False):
        raise HTTPException(
            status_code=400,
            detail=(
                f"عدم تطابق بنكي: البنك المختار للربط ({bank_name}) لا يطابق البنك المنفذ لسويفت التحويل "
                f"({item.swift_executing_bank_name}). يجب الربط على نفس بنك السويفت، أو تفعيل خيار التخطي بمبرر."
            ),
        )

    item.nafeza_bank_link_status = "LINKED_TO_BANK"
    item.nafeza_bank_link_date = schema.link_date
    item.nafeza_linked_bank_id = schema.bank_id
    item.nafeza_linked_bank_name = bank_name
    item.is_bank_matching_swift = is_matching

    # Lock session bank_id and bank_name to the linked bank
    item.bank_id = schema.bank_id
    item.bank_name = bank_name
    if schema.notes:
        item.notes = f"{item.notes}\n[Nafeza bank link] {schema.notes}" if item.notes else f"[Nafeza bank link] {schema.notes}"
    if getattr(schema, "override_reason", None):
        item.notes = f"{item.notes}\n[SWIFT bank mismatch override]: {schema.override_reason}"

    item.updated_at = datetime.now(timezone.utc)
    if user is not None:
        item.updated_by = user
    db.commit()
    db.refresh(item)

    # Smart Tasks: close items verify & link task, dispatch Bank Form 4 application task
    def _handle_link_tasks():
        from modules.smart_tasks.model import SmartTask
        from modules.smart_tasks.repository import create_task as create_smart_task
        from modules.smart_tasks.schemas import SmartTaskCreate
        from modules.import_files.model import ImportFile

        f_id = item.import_file_id
        imp = db.query(ImportFile).filter(ImportFile.import_file_id == f_id).first() if f_id else None
        f_code = imp.import_file_code if imp else f"IMP-{f_id}"

        # Close broker items verify and link task
        pending = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == f_id,
                SmartTask.status.in_(["Pending", "In Progress"]),
            )
            .all()
        )
        for t in pending:
            if "سحب الأصناف" in (t.title or "") or (t.notes and "ACTION:ITEMS_VERIFY_AND_BANK_LINK" in t.notes):
                t.status = "Completed"
                t.completion_notes = f"Items verified and linked to bank {bank_name} on Nafeza on {schema.link_date}."

        # Create task for Import / Banking Officer to submit Form 4 to bank
        form4_msg = msg("DOC_TASK_FORM4_SUBMIT", bank_name=bank_name, import_file_code=f_code)
        bank_task = SmartTaskCreate(
            title=render_en(form4_msg.code, form4_msg.params, "title"),
            description=render_en(form4_msg.code, form4_msg.params, "body"),
            task_type="System Generated",
            import_file_id=f_id,
            import_file_code=f_code,
            phase_name="Phase 4: Digital & Banking",
            assigned_user="Bank Specialist",
            priority="High",
            reminder_type="Bank Form 4 Application",
            due_date=str(date.today() + timedelta(days=2)),
            status="Pending",
            notes=f"ACTION:FORM4_SUBMIT | BankDoc: {item.bank_doc_code}",
        )
        create_smart_task(
            db, bank_task, created_by="Banking Documents Engine",
            msg_code=form4_msg.code, msg_params=form4_msg.params, commit=False,
        )

    _commit_follow_up(db, _handle_link_tasks, "Nafeza bank link smart tasks")
    return enrich_banking_response(db, item)



def get_all_banking_documents_service(
    db: Session,
    import_file_id: int = None,
    skip: int = 0,
    limit: int | None = None,
    return_total: bool = False,
):
    return repo.get_all_banking_documents(
        db,
        import_file_id=import_file_id,
        skip=skip,
        limit=limit,
        return_total=return_total,
    )

def get_banking_document_by_id_service(db: Session, bank_doc_id: int):
    return repo.get_banking_document_by_id(db, bank_doc_id)

