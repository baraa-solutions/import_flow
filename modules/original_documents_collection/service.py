import io
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

from modules.import_files.model import ImportFile
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking
from modules.purchase_orders.model import PurchaseOrder
from modules.import_documentation.service import get_central_archive_service
from .model import OriginalDocumentsCollectionSession
from .repository import OriginalDocumentsCollectionRepository
from .schemas import (
    OriginalDocumentsCollectionCreate,
    OriginalDocumentsCollectionUpdate,
    OriginalDocumentsCollectionResponse,
    OriginalDocumentsAutoPopulateResponse,
    CourierEntry,
    OriginalDocumentItem,
    CourierReceiptProofRequest,
    CourierAlertItem,
    CourierAlertsResponse,
    CourierFlatItemResponse,
)


class OriginalDocumentsCollectionService:
    @staticmethod
    def auto_populate_from_central_archive(
        db: Session, import_file_id: int
    ) -> OriginalDocumentsAutoPopulateResponse:
        import_file = db.query(ImportFile).filter_by(import_file_id=import_file_id).first()
        if not import_file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Import File ID {import_file_id} not found.",
            )

        existing_session = OriginalDocumentsCollectionRepository.get_by_import_file(db, import_file_id)

        # Retrieve central archive details if available
        archive_data = None
        try:
            archive_data = get_central_archive_service(db, import_file_id)
        except Exception:
            archive_data = None

        # Build baseline required documents list
        # Check inspection requirement from archive
        is_inspection_required = "No"
        if archive_data and archive_data.inspection_certificate.is_available:
            is_inspection_required = "Yes"
        elif archive_data and archive_data.goeic_inspection_alert:
            is_inspection_required = "Conditional"

        # Check COO requirement
        coo_required = "Yes"
        if archive_data and archive_data.certificate_of_origin.is_waived:
            coo_required = "No"

        required_docs = [
            OriginalDocumentItem(
                category="Commercial",
                document_name="Proforma Invoice",
                is_required="Yes",
                responsible_party="Supplier",
                status="Pending",
            ),
            OriginalDocumentItem(
                category="Commercial",
                document_name="Commercial Invoice",
                is_required="Yes",
                responsible_party="Supplier",
                status="Pending",
            ),
            OriginalDocumentItem(
                category="Commercial",
                document_name="Packing List",
                is_required="Yes",
                responsible_party="Supplier",
                status="Pending",
            ),
            OriginalDocumentItem(
                category="Commercial",
                document_name="E.Invoice",
                is_required="Yes",
                responsible_party="Supplier",
                status="Pending",
            ),
            OriginalDocumentItem(
                category="Certificate",
                document_name="Certificate of Origin (COO)",
                is_required=coo_required,
                responsible_party="Supplier",
                status="Pending",
            ),
            OriginalDocumentItem(
                category="Shipping",
                document_name="Final House Bill of Lading",
                is_required="Yes",
                responsible_party="Freight Forwarder",
                status="Pending",
            ),
            OriginalDocumentItem(
                category="Shipping",
                document_name="Final Master Bill of Lading",
                is_required="Yes",
                responsible_party="Freight Forwarder",
                status="Pending",
            ),
            OriginalDocumentItem(
                category="Certificate",
                document_name="Inspection Certificate",
                is_required=is_inspection_required,
                responsible_party="Supplier",
                status="Pending",
            ),
            OriginalDocumentItem(
                category="Egypt Import",
                document_name="Blockchain Documents",
                is_required="Conditional",
                responsible_party="Supplier",
                status="Pending",
            ),
        ]

        # Default Couriers
        default_couriers = [
            CourierEntry(
                courier_no="",
                courier_company="DHL",
                dispatch_date=None,
                is_received=False,
                received_date=None,
                received_by=None,
                notes="Foreign Exporter Hard-copy Package",
            ),
            CourierEntry(
                courier_no="",
                courier_company="FedEx",
                dispatch_date=None,
                is_received=False,
                received_date=None,
                received_by=None,
                notes="Freight Forwarder Shipping Documents Package",
            ),
        ]

        existing_response = None
        if existing_session:
            existing_response = OriginalDocumentsCollectionResponse.model_validate(existing_session)

        return OriginalDocumentsAutoPopulateResponse(
            import_file_id=import_file.import_file_id,
            import_file_code=import_file.import_file_code,
            acid_number=import_file.acid_number,
            importer_name=import_file.company_name if hasattr(import_file, "company_name") else getattr(import_file, "importer_name", ""),
            supplier_name=import_file.supplier_name if hasattr(import_file, "supplier_name") else "",
            default_couriers=default_couriers,
            required_documents=required_docs,
            existing_session=existing_response,
        )

    @staticmethod
    def save_or_upsert_collection_session(
        db: Session,
        payload: OriginalDocumentsCollectionCreate,
        username: str = "ADMIN",
    ) -> OriginalDocumentsCollectionResponse:
        import_file = db.query(ImportFile).filter_by(import_file_id=payload.import_file_id).first()
        if not import_file:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Import File ID {payload.import_file_id} not found.",
            )

        # Calculate statistics
        docs_list = [d.model_dump() if isinstance(d, OriginalDocumentItem) else d for d in payload.documents_list]
        couriers_list = [c.model_dump() if isinstance(c, CourierEntry) else c for c in payload.couriers_list]

        total_count = len(docs_list)
        received_count = sum(1 for d in docs_list if d.get("is_received", False))
        verified_count = sum(1 for d in docs_list if d.get("is_verified", False))
        pending_count = total_count - received_count
        completion_pct = round((verified_count / total_count * 100.0), 1) if total_count > 0 else 0.0

        # Automatic status resolution if not explicitly set to a customized status
        status_val = payload.status
        if status_val in ["DRAFT", "PARTIALLY_RECEIVED", "FULLY_RECEIVED", "FULLY_VERIFIED"]:
            if verified_count == total_count and total_count > 0:
                status_val = "FULLY_VERIFIED"
            elif received_count == total_count and total_count > 0:
                status_val = "FULLY_RECEIVED"
            elif received_count > 0:
                status_val = "PARTIALLY_RECEIVED"
            else:
                status_val = "DRAFT"

        existing_session = OriginalDocumentsCollectionRepository.get_by_import_file(db, payload.import_file_id)

        if existing_session:
            # Update existing
            updates = {
                "acid_number": payload.acid_number or existing_session.acid_number,
                "importer_name": payload.importer_name or existing_session.importer_name,
                "supplier_name": payload.supplier_name or existing_session.supplier_name,
                "status": status_val,
                "couriers_list": couriers_list,
                "documents_list": docs_list,
                "total_documents_count": total_count,
                "received_documents_count": received_count,
                "verified_documents_count": verified_count,
                "pending_documents_count": pending_count,
                "completion_percentage": completion_pct,
                "discrepancy_override_reason": payload.discrepancy_override_reason,
                "notes": payload.notes,
                "updated_by": username,
            }
            saved = OriginalDocumentsCollectionRepository.update(db, existing_session, updates)
        else:
            # Create new
            new_code = OriginalDocumentsCollectionRepository.get_next_collection_code(db)
            new_session = OriginalDocumentsCollectionSession(
                collection_code=new_code,
                import_file_id=payload.import_file_id,
                import_file_code=payload.import_file_code,
                acid_number=payload.acid_number or import_file.acid_number,
                importer_name=payload.importer_name or getattr(import_file, "company_name", ""),
                supplier_name=payload.supplier_name or getattr(import_file, "supplier_name", ""),
                status=status_val,
                couriers_list=couriers_list,
                documents_list=docs_list,
                total_documents_count=total_count,
                received_documents_count=received_count,
                verified_documents_count=verified_count,
                pending_documents_count=pending_count,
                completion_percentage=completion_pct,
                discrepancy_override_reason=payload.discrepancy_override_reason,
                notes=payload.notes,
                created_by=username,
                updated_by=username,
            )
            saved = OriginalDocumentsCollectionRepository.create(db, new_session)

        # Execute SH-04 Orchestration Workflow (ImportFile sync, SmartTasks, Notifications, Approvals, Lifecycle)
        OriginalDocumentsCollectionService._handle_original_documents_orchestration_workflow(
            db, saved, updated_by=username
        )

        return OriginalDocumentsCollectionResponse.model_validate(saved)

    save_or_update_session = save_or_upsert_collection_session

    @staticmethod
    def _handle_original_documents_orchestration_workflow(
        db: Session,
        session: OriginalDocumentsCollectionSession,
        updated_by: str = "ADMIN",
    ) -> None:
        """
        SH-04 Orchestration Workflow:
        1. Synchronizes original documents status, couriers, and timestamps with ImportFile.
        2. Auto-closes pending SH-04 SmartTasks.
        3. Dispatches downstream CS-01 SmartTask (Customs Broker Electronic Authorization).
        4. Emits operational SystemNotification.
        5. Synchronizes CustomsDocumentApproval for ORIGINAL_DOCUMENTS.
        6. Advances Lifecycle step STEP_11 -> STEP_12 when fully received or verified.
        """
        import uuid
        import logging
        from datetime import timedelta
        logger = logging.getLogger(__name__)

        try:
            # 1. Synchronize ImportFile
            imp_file = db.query(ImportFile).filter_by(import_file_id=session.import_file_id).first()
            if imp_file:
                imp_file.original_documents_status = session.status
                imp_file.original_documents_session_code = session.collection_code
                awbs = [c.get("courier_no") for c in (session.couriers_list or []) if c.get("courier_no")]
                imp_file.original_documents_courier_no = ", ".join(awbs) if awbs else None

                if session.status in ("FULLY_RECEIVED", "FULLY_VERIFIED"):
                    imp_file.original_documents_received_at = datetime.now(timezone.utc)
                    if (imp_file.progress_percent or 0) < 75.0:
                        imp_file.progress_percent = 75.0
                    set_file_tracking(imp_file, next_action=msg("NA_CS01_ASSIGN_BROKER"))

            # 2. Complete pending SH-04 SmartTasks
            try:
                from modules.smart_tasks.model import SmartTask
                pending_tasks = (
                    db.query(SmartTask)
                    .filter(
                        SmartTask.import_file_id == session.import_file_id,
                        SmartTask.status != "Completed",
                    )
                    .all()
                )
                for t in pending_tasks:
                    if (
                        t.task_type in ("ORIGINAL_DOCS_RECEIPT", "ORIGINAL_DOCS", "SH-04")
                        or "SH-04" in (t.title or "")
                        or "أصول المستندات" in (t.title or "")
                    ):
                        t.status = "Completed"
                        t.completion_notes = f"Original documents received and verified (code: {session.collection_code}) with status {session.status}."
            except Exception as ex_task:
                logger.warning(f"Error auto-completing SH-04 SmartTasks: {ex_task}")

            # If fully received or verified, trigger downstream tasks, notifications, and approvals
            if session.status in ("FULLY_RECEIVED", "FULLY_VERIFIED"):
                file_label = imp_file.import_file_code if imp_file else session.import_file_code

                # 3. Dispatch downstream CS-01 SmartTask (Customs Broker Electronic Authorization)
                try:
                    from modules.smart_tasks.model import SmartTask
                    existing_cs01 = (
                        db.query(SmartTask)
                        .filter(
                            SmartTask.import_file_id == session.import_file_id,
                            SmartTask.task_type.in_(["CUSTOMS_BROKER_ASSIGNMENT", "CS-01"]),
                        )
                        .first()
                    )
                    if not existing_cs01:
                        due_dt = (datetime.now(timezone.utc) + timedelta(days=3)).strftime("%Y-%m-%d")
                        task_code = f"TASK-{uuid.uuid4().hex[:8].upper()}"
                        task_msg = msg(
                            "ODC_TASK_ASSIGN_BROKER",
                            import_file_code=file_label,
                            collection_code=session.collection_code,
                        )
                        downstream_task = SmartTask(
                            task_code=task_code,
                            import_file_id=session.import_file_id,
                            import_file_code=file_label,
                            title=render_en(task_msg.code, task_msg.params, "title").strip(),
                            description=render_en(task_msg.code, task_msg.params, "body"),
                            msg_code=task_msg.code,
                            msg_params=task_msg.params,
                            task_type="CUSTOMS_BROKER_ASSIGNMENT",
                            priority="High",
                            status="Pending",
                            assigned_user="Customs Specialist",
                            due_date=due_dt,
                            created_by=updated_by,
                        )
                        db.add(downstream_task)
                except Exception as ex_dispatch:
                    logger.warning(f"Error dispatching downstream CS-01 smart task: {ex_dispatch}")

                # 4. Emit SystemNotification
                try:
                    from modules.notifications.model import SystemNotification
                    notif_msg = msg(
                        "ODC_ORIGINALS_RECEIVED",
                        collection_code=session.collection_code,
                        import_file_code=file_label,
                        completion_pct=session.completion_percentage,
                    )
                    notif = SystemNotification(
                        title=render_en(notif_msg.code, notif_msg.params, "title"),
                        message=render_en(notif_msg.code, notif_msg.params, "body"),
                        msg_code=notif_msg.code,
                        msg_params=notif_msg.params,
                        category="STAGE_PROGRESSION",
                        severity="INFO",
                        entity_type="ImportFile",
                        entity_id=session.import_file_id,
                        target_role="ALL",
                        is_read=False,
                    )
                    db.add(notif)
                except Exception as ex_notif:
                    logger.warning(f"Error creating Original Docs SystemNotification: {ex_notif}")

                # 5. Update CustomsDocumentApproval for ORIGINAL_DOCUMENTS
                try:
                    from modules.docs_customs_approval.model import CustomsDocumentApproval
                    approval_rec = (
                        db.query(CustomsDocumentApproval)
                        .filter(
                            CustomsDocumentApproval.import_file_id == session.import_file_id,
                            CustomsDocumentApproval.document_type.in_(["ORIGINAL_DOCUMENTS", "ORIGINAL_BANK_DOCS", "Original Documents"]),
                        )
                        .first()
                    )
                    if not approval_rec:
                        approval_rec = CustomsDocumentApproval(
                            approval_code=f"DCA-{uuid.uuid4().hex[:8].upper()}",
                            import_file_id=session.import_file_id,
                            import_file_code=file_label,
                            document_type="ORIGINAL_DOCUMENTS",
                            document_reference_no=session.collection_code,
                            commercial_status="Approved",
                            commercial_reviewed_by=updated_by,
                            commercial_reviewed_at=datetime.now(timezone.utc),
                            customs_status="Approved",
                            customs_reviewed_by=updated_by,
                            customs_reviewed_at=datetime.now(timezone.utc),
                            overall_status="Approved for Clearance",
                            commercial_notes=f"Original bank documents received and verified under no. {session.collection_code}",
                        )
                        db.add(approval_rec)
                    else:
                        approval_rec.commercial_status = "Approved"
                        approval_rec.customs_status = "Approved"
                        approval_rec.overall_status = "Approved for Clearance"
                        approval_rec.document_reference_no = session.collection_code
                        approval_rec.commercial_notes = f"Original bank documents received and verified under no. {session.collection_code}"
                except Exception as ex_appr:
                    logger.warning(f"Error updating CustomsDocumentApproval for Original Docs: {ex_appr}")

                # 6. Advance Lifecycle step STEP_11 -> STEP_12
                try:
                    from modules.lifecycle_board.service import advance_lifecycle_step_service
                    advance_lifecycle_step_service(
                        db=db,
                        import_file_id=session.import_file_id,
                        completed_step_code="STEP_11",
                        target_step_codes=["STEP_12"],
                        notes_msg=msg("ODC_ORIGINALS_RECEIVED", collection_code=session.collection_code),
                        next_action_msg=msg("NA_CS01_ASSIGN_BROKER"),
                        assigned_user=updated_by,
                    )
                except Exception as ex_lc:
                    logger.warning(f"Lifecycle advance STEP_11→STEP_12 failed: {ex_lc}")

            db.commit()
        except Exception as e:
            logger.error(f"Error executing _handle_original_documents_orchestration_workflow: {e}")


    @staticmethod
    def get_session_by_id(db: Session, collection_id: int) -> OriginalDocumentsCollectionResponse:
        session = OriginalDocumentsCollectionRepository.get_by_id(db, collection_id)
        if not session:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collection session not found.")
        return OriginalDocumentsCollectionResponse.model_validate(session)

    @staticmethod
    def get_session_by_file(db: Session, import_file_id: int) -> Optional[OriginalDocumentsCollectionResponse]:
        session = OriginalDocumentsCollectionRepository.get_by_import_file(db, import_file_id)
        if not session:
            return None
        return OriginalDocumentsCollectionResponse.model_validate(session)

    @staticmethod
    def list_sessions(
        db: Session,
        include_inactive: bool = False,
        status: Optional[str] = None,
        search: Optional[str] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> List[OriginalDocumentsCollectionResponse]:
        sessions = OriginalDocumentsCollectionRepository.get_all(
            db,
            include_inactive=include_inactive,
            status=status,
            search=search,
            limit=limit,
            offset=offset,
        )
        return [OriginalDocumentsCollectionResponse.model_validate(s) for s in sessions]

    @staticmethod
    def export_collection_to_excel_bytes(
        db: Session, import_file_id_or_session_id: int
    ) -> bytes:
        # Resolve session
        session = OriginalDocumentsCollectionRepository.get_by_id(db, import_file_id_or_session_id)
        if not session:
            session = OriginalDocumentsCollectionRepository.get_by_import_file(db, import_file_id_or_session_id)

        if not session:
            # Generate from auto-populated
            auto_data = OriginalDocumentsCollectionService.auto_populate_from_central_archive(
                db, import_file_id_or_session_id
            )
            couriers = [c.model_dump() for c in auto_data.default_couriers]
            docs = [d.model_dump() for d in auto_data.required_documents]
            file_code = auto_data.import_file_code
            acid_no = auto_data.acid_number or "—"
            importer = auto_data.importer_name or "—"
            supplier = auto_data.supplier_name or "—"
            status_text = "DRAFT"
        else:
            couriers = session.couriers_list or []
            docs = session.documents_list or []
            file_code = session.import_file_code
            acid_no = session.acid_number or "—"
            importer = session.importer_name or "—"
            supplier = session.supplier_name or "—"
            status_text = session.status

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Original Docs Collection"

        # Fonts & Styles
        font_title = Font(name="Calibri", size=14, bold=True, color="FFFFFF")
        font_subtitle = Font(name="Calibri", size=11, bold=True, color="2C3E50")
        font_table_hdr = Font(name="Calibri", size=10, bold=True, color="FFFFFF")
        font_data = Font(name="Calibri", size=9, bold=False, color="000000")
        font_bold = Font(name="Calibri", size=9, bold=True, color="000000")

        fill_navy = PatternFill(start_color="2C3E50", end_color="2C3E50", fill_type="solid")
        fill_cobalt = PatternFill(start_color="3498DB", end_color="3498DB", fill_type="solid")
        fill_light_grey = PatternFill(start_color="F2F4F4", end_color="F2F4F4", fill_type="solid")
        fill_alt_row = PatternFill(start_color="FBFCFC", end_color="FBFCFC", fill_type="solid")

        align_center = Alignment(horizontal="center", vertical="center", wrap_text=True)
        align_left = Alignment(horizontal="left", vertical="center")
        align_right = Alignment(horizontal="right", vertical="center")

        thin_border = Border(
            left=Side(style="thin", color="BDC3C7"),
            right=Side(style="thin", color="BDC3C7"),
            top=Side(style="thin", color="BDC3C7"),
            bottom=Side(style="thin", color="BDC3C7"),
        )

        # Title Row
        ws.merge_cells("A1:L1")
        title_cell = ws["A1"]
        title_cell.value = f"PHYSICAL ORIGINAL DOCUMENTS COLLECTION & COURIER TRACKING SHEET — {file_code}"
        title_cell.font = font_title
        title_cell.fill = fill_navy
        title_cell.alignment = align_center
        ws.row_dimensions[1].height = 32

        # Metadata Header
        meta_items = [
            ("Import File:", file_code, "ACID Number:", acid_no),
            ("Importer Company:", importer, "Foreign Exporter:", supplier),
            ("Collection Status:", status_text, "Generated At:", datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")),
        ]

        row_idx = 3
        for m1_lbl, m1_val, m2_lbl, m2_val in meta_items:
            ws.cell(row=row_idx, column=1, value=m1_lbl).font = font_subtitle
            ws.cell(row=row_idx, column=2, value=m1_val).font = font_bold
            ws.cell(row=row_idx, column=6, value=m2_lbl).font = font_subtitle
            ws.cell(row=row_idx, column=7, value=m2_val).font = font_bold
            row_idx += 1

        row_idx += 1

        # Couriers Summary Section
        ws.cell(row=row_idx, column=1, value="COURIER DISPATCH PACKAGES (الطرود البريدية السريعة)").font = font_subtitle
        row_idx += 1

        courier_hdrs = ["#", "Courier No (رقم البوليصة)", "Courier Company (الشركة)", "Dispatch Date (تاريخ الإرسال)", "Received (الاستلام)", "Received Date (تاريخ الاستلام)", "Received By (المستلم)", "Notes (ملاحظات)"]
        for c_idx, h in enumerate(courier_hdrs, start=1):
            c = ws.cell(row=row_idx, column=c_idx, value=h)
            c.font = font_table_hdr
            c.fill = fill_cobalt
            c.alignment = align_center
            c.border = thin_border
        ws.row_dimensions[row_idx].height = 24
        row_idx += 1

        if not couriers:
            couriers = [{"courier_no": "—", "courier_company": "DHL", "dispatch_date": "—", "is_received": False, "received_date": "—", "received_by": "—", "notes": ""}]

        for idx, cr in enumerate(couriers, start=1):
            ws.cell(row=row_idx, column=1, value=idx).alignment = align_center
            ws.cell(row=row_idx, column=2, value=cr.get("courier_no") or "—").alignment = align_left
            ws.cell(row=row_idx, column=3, value=cr.get("courier_company") or "DHL").alignment = align_center
            ws.cell(row=row_idx, column=4, value=cr.get("dispatch_date") or "—").alignment = align_center
            ws.cell(row=row_idx, column=5, value="Yes" if cr.get("is_received") else "No").alignment = align_center
            ws.cell(row=row_idx, column=6, value=cr.get("received_date") or "—").alignment = align_center
            ws.cell(row=row_idx, column=7, value=cr.get("received_by") or "—").alignment = align_left
            ws.cell(row=row_idx, column=8, value=cr.get("notes") or "").alignment = align_left

            for col in range(1, 9):
                cell = ws.cell(row=row_idx, column=col)
                cell.font = font_data
                cell.border = thin_border
                if idx % 2 == 0:
                    cell.fill = fill_alt_row
            row_idx += 1

        row_idx += 2

        # Document Items Table
        ws.cell(row=row_idx, column=1, value="ORIGINAL HARD-COPY DOCUMENTS AUDIT & VERIFICATION (مصفوفة تدقيق واستلام أصول المستندات)").font = font_subtitle
        row_idx += 1

        doc_headers = [
            "Courier No",
            "Courier Date",
            "Document Category",
            "Document Name",
            "Required",
            "Responsible Party",
            "Received",
            "Received Date",
            "Verified",
            "Verified By",
            "Verification Date",
            "Status",
            "Remarks",
        ]

        for c_idx, h in enumerate(doc_headers, start=1):
            c = ws.cell(row=row_idx, column=c_idx, value=h)
            c.font = font_table_hdr
            c.fill = fill_navy
            c.alignment = align_center
            c.border = thin_border
        ws.row_dimensions[row_idx].height = 26
        row_idx += 1

        # Populate rows
        for d_idx, doc in enumerate(docs, start=1):
            # Find courier date if courier_no matches
            c_no = doc.get("courier_no") or ""
            c_date = ""
            for cr in couriers:
                if cr.get("courier_no") and cr.get("courier_no") == c_no:
                    c_date = cr.get("dispatch_date") or ""
                    break

            ws.cell(row=row_idx, column=1, value=c_no or "—").alignment = align_left
            ws.cell(row=row_idx, column=2, value=c_date or "—").alignment = align_center
            ws.cell(row=row_idx, column=3, value=doc.get("category") or "Commercial").alignment = align_center
            ws.cell(row=row_idx, column=4, value=doc.get("document_name") or "").alignment = align_left
            ws.cell(row=row_idx, column=5, value=doc.get("is_required") or "Yes").alignment = align_center
            ws.cell(row=row_idx, column=6, value=doc.get("responsible_party") or "Supplier").alignment = align_center
            ws.cell(row=row_idx, column=7, value="Yes" if doc.get("is_received") else "No").alignment = align_center
            ws.cell(row=row_idx, column=8, value=doc.get("received_date") or "—").alignment = align_center
            ws.cell(row=row_idx, column=9, value="Yes" if doc.get("is_verified") else "No").alignment = align_center
            ws.cell(row=row_idx, column=10, value=doc.get("verified_by") or "—").alignment = align_left
            ws.cell(row=row_idx, column=11, value=doc.get("verification_date") or "—").alignment = align_center
            ws.cell(row=row_idx, column=12, value=doc.get("status") or "Pending").alignment = align_center
            ws.cell(row=row_idx, column=13, value=doc.get("remarks") or "").alignment = align_left

            for col in range(1, 14):
                cell = ws.cell(row=row_idx, column=col)
                cell.font = font_data
                cell.border = thin_border
                if d_idx % 2 == 0:
                    cell.fill = fill_alt_row
            row_idx += 1

        # Adjust column widths automatically
        for col in ws.columns:
            max_len = max(len(str(cell.value or "")) for cell in col)
            col_letter = get_column_letter(col[0].column)
            ws.column_dimensions[col_letter].width = max(max_len + 3, 12)

        output = io.BytesIO()
        wb.save(output)
        output.seek(0)
        return output.getvalue()

    @staticmethod
    def build_carrier_tracking_url(company: str, awb: str) -> str:
        clean_awb = awb.strip()
        c = (company or "").upper()
        if "DHL" in c:
            return f"https://www.dhl.com/en/express/tracking.html?AWB={clean_awb}"
        elif "FEDEX" in c:
            return f"https://www.fedex.com/fedextrack/?trknbr={clean_awb}"
        elif "ARAMEX" in c:
            return f"https://www.aramex.com/track/results?mode=0&ShipmentNumber={clean_awb}"
        elif "UPS" in c:
            return f"https://www.ups.com/track?tracknum={clean_awb}"
        elif "NAQEL" in c:
            return f"https://www.naqelexpress.com/tracking?trackNumbers={clean_awb}"
        elif "SMSA" in c:
            return f"https://www.smsaexpress.com/track?trackNumber={clean_awb}"
        return f"https://www.google.com/search?q={company}+{clean_awb}+tracking"

    @staticmethod
    def confirm_courier_receipt(
        db: Session,
        request: CourierReceiptProofRequest,
        username: str = "ADMIN",
    ) -> OriginalDocumentsCollectionResponse:
        session = OriginalDocumentsCollectionRepository.get_by_import_file(db, request.import_file_id)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"جلسة تحصيل المستندات الأصلية للشحنة برقم {request.import_file_id} غير موجودة.",
            )

        import copy
        couriers = copy.deepcopy(session.couriers_list or [])
        found_courier = False
        target_awb = request.courier_no.strip().upper()

        for c in couriers:
            current_awb = (c.get("courier_no") or "").strip().upper()
            if current_awb == target_awb or (target_awb in current_awb and len(target_awb) > 4):
                found_courier = True
                c["is_received"] = True
                c["received_date"] = request.received_date
                if request.received_time:
                    c["received_time"] = request.received_time
                c["received_by"] = request.received_by
                c["status"] = "DELIVERED"
                if request.pod_reference:
                    c["pod_reference"] = request.pod_reference
                if request.notes:
                    existing_notes = c.get("notes") or ""
                    c["notes"] = f"{existing_notes} | {request.notes}".strip(" |")
                c["tracking_url"] = OriginalDocumentsCollectionService.build_carrier_tracking_url(
                    c.get("courier_company") or "DHL", c.get("courier_no") or ""
                )
                break

        if not found_courier:
            # If courier wasn't in the list, append it as delivered
            couriers.append({
                "courier_no": request.courier_no.strip(),
                "courier_company": "DHL",
                "dispatch_date": request.received_date,
                "is_received": True,
                "received_date": request.received_date,
                "received_time": request.received_time,
                "received_by": request.received_by,
                "pod_reference": request.pod_reference,
                "status": "DELIVERED",
                "notes": request.notes or "Added upon delivery proof confirmation",
                "tracking_url": OriginalDocumentsCollectionService.build_carrier_tracking_url(
                    "DHL", request.courier_no.strip()
                ),
            })

        docs = copy.deepcopy(session.documents_list or [])

        if request.mark_documents_received:
            for d in docs:
                doc_awb = (d.get("courier_no") or "").strip().upper()
                if doc_awb == target_awb or (target_awb in doc_awb and len(target_awb) > 4) or not doc_awb:
                    d["is_received"] = True
                    if not d.get("received_date"):
                        d["received_date"] = request.received_date
                    if d.get("status") in ["Pending", "In Transit"]:
                        d["status"] = "Received"

        total_count = len(docs)
        received_count = sum(1 for d in docs if d.get("is_received", False))
        verified_count = sum(1 for d in docs if d.get("is_verified", False))
        pending_count = total_count - received_count
        completion_pct = round((verified_count / total_count * 100.0), 1) if total_count > 0 else 0.0

        status_val = session.status
        if verified_count == total_count and total_count > 0:
            status_val = "FULLY_VERIFIED"
        elif received_count == total_count and total_count > 0:
            status_val = "FULLY_RECEIVED"
        elif received_count > 0:
            status_val = "PARTIALLY_RECEIVED"

        updates = {
            "couriers_list": couriers,
            "documents_list": docs,
            "status": status_val,
            "total_documents_count": total_count,
            "received_documents_count": received_count,
            "verified_documents_count": verified_count,
            "pending_documents_count": pending_count,
            "completion_percentage": completion_pct,
            "updated_by": username,
        }
        saved = OriginalDocumentsCollectionRepository.update(db, session, updates)

        # Execute SH-04 Orchestration Workflow
        OriginalDocumentsCollectionService._handle_original_documents_orchestration_workflow(
            db, saved, updated_by=username
        )

        return OriginalDocumentsCollectionResponse.model_validate(saved)

    @staticmethod
    def get_courier_alerts(db: Session) -> CourierAlertsResponse:
        sessions = OriginalDocumentsCollectionRepository.get_all(db, limit=500)
        today = datetime.now(timezone.utc).date()

        alerts: List[CourierAlertItem] = []
        total_active_couriers = 0
        pending_count = 0
        delayed_count = 0
        delivered_count = 0

        for s in sessions:
            for c in (s.couriers_list or []):
                total_active_couriers += 1
                c_no = c.get("courier_no") or ""
                c_company = c.get("courier_company") or "DHL"
                is_rcv = c.get("is_received", False)
                disp_str = c.get("dispatch_date")

                if is_rcv:
                    delivered_count += 1
                    continue

                pending_count += 1
                days = 0
                if disp_str:
                    try:
                        clean_disp = disp_str.strip().split("T")[0]
                        disp_date = datetime.strptime(clean_disp, "%Y-%m-%d").date()
                        days = (today - disp_date).days
                        if days < 0:
                            days = 0
                    except Exception:
                        days = 0

                level = "INFO"
                if days >= 5:
                    level = "CRITICAL"
                    delayed_count += 1
                    msg_ar = f"طرد {c_company} رقم ({c_no}) مرسل منذ {days} أيام للشحنة {s.import_file_code} وتجاوز المهلة المقررة (SLA)"
                    msg_en = f"Courier {c_company} ({c_no}) in transit for {days} days on shipment {s.import_file_code} — SLA breached!"
                elif days >= 3:
                    level = "WARNING"
                    delayed_count += 1
                    msg_ar = f"طرد {c_company} رقم ({c_no}) مرسل منذ {days} أيام للشحنة {s.import_file_code} ويقترب من مهلة التسليم"
                    msg_en = f"Courier {c_company} ({c_no}) in transit for {days} days on shipment {s.import_file_code} — approaching SLA threshold"
                else:
                    level = "INFO"
                    msg_ar = f"طرد {c_company} رقم ({c_no}) قيد التوصيل للشحنة {s.import_file_code} (منذ {days} يوم)"
                    msg_en = f"Courier {c_company} ({c_no}) in transit for shipment {s.import_file_code} ({days} days elapsed)"

                alerts.append(
                    CourierAlertItem(
                        courier_no=c_no,
                        courier_company=c_company,
                        import_file_id=s.import_file_id,
                        import_file_code=s.import_file_code,
                        acid_number=s.acid_number,
                        importer_name=s.importer_name,
                        supplier_name=s.supplier_name,
                        dispatch_date=disp_str,
                        days_in_transit=days,
                        alert_level=level,
                        alert_message_ar=msg_ar,
                        alert_message_en=msg_en,
                    )
                )

        # Sort alerts: CRITICAL first, then WARNING, then INFO, then by days descending
        level_order = {"CRITICAL": 0, "WARNING": 1, "INFO": 2}
        alerts.sort(key=lambda a: (level_order.get(a.alert_level, 3), -a.days_in_transit))

        return CourierAlertsResponse(
            total_active_couriers=total_active_couriers,
            pending_receipt_count=pending_count,
            delayed_count=delayed_count,
            delivered_count=delivered_count,
            alerts=alerts,
        )

    @staticmethod
    def get_all_couriers_flat(db: Session) -> List[CourierFlatItemResponse]:
        sessions = OriginalDocumentsCollectionRepository.get_all(db, limit=500)
        today = datetime.now(timezone.utc).date()
        result: List[CourierFlatItemResponse] = []

        for s in sessions:
            docs = s.documents_list or []
            for c in (s.couriers_list or []):
                c_no = (c.get("courier_no") or "").strip()
                c_comp = c.get("courier_company") or "DHL"
                is_rcv = c.get("is_received", False)
                disp_str = c.get("dispatch_date")

                days = 0
                if disp_str:
                    try:
                        clean_disp = disp_str.strip().split("T")[0]
                        disp_date = datetime.strptime(clean_disp, "%Y-%m-%d").date()
                        days = (today - disp_date).days
                        if days < 0:
                            days = 0
                    except Exception:
                        days = 0

                status_val = "IN_TRANSIT"
                if is_rcv:
                    status_val = "DELIVERED"
                elif days >= 4:
                    status_val = "DELAYED"
                elif days > 0:
                    status_val = "IN_TRANSIT"
                else:
                    status_val = "DISPATCHED"

                matched_docs_count = sum(
                    1 for d in docs if (d.get("courier_no") or "").strip().upper() == c_no.upper() and c_no
                )

                tracking_url = c.get("tracking_url") or OriginalDocumentsCollectionService.build_carrier_tracking_url(
                    c_comp, c_no
                )

                result.append(
                    CourierFlatItemResponse(
                        courier_no=c_no,
                        courier_company=c_comp,
                        import_file_id=s.import_file_id,
                        import_file_code=s.import_file_code,
                        importer_name=s.importer_name,
                        supplier_name=s.supplier_name,
                        dispatch_date=disp_str,
                        is_received=is_rcv,
                        received_date=c.get("received_date"),
                        received_time=c.get("received_time"),
                        received_by=c.get("received_by"),
                        tracking_url=tracking_url,
                        pod_reference=c.get("pod_reference"),
                        status=status_val,
                        days_in_transit=days,
                        associated_docs_count=matched_docs_count,
                        notes=c.get("notes"),
                    )
                )

        return result
