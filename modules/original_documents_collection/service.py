import copy
import io
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional
from urllib.parse import quote_plus

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

from modules.import_files.model import ImportFile
from modules.common.clock import cairo_today
from modules.common.errors import best_effort
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking
from modules.common.validators import get_or_404
from modules.import_documentation.service import get_central_archive_service
import modules.docs_customs_approval.service as dca_service
from . import validators
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

logger = logging.getLogger(__name__)

IMPORT_FILE_LABEL_AR = "ملف الاستيراد"
SESSION_LABEL_AR = "جلسة تحصيل المستندات الأصلية"
CODE_ATTEMPTS = 2

# SH-04 tasks closed when the originals are fully received. CargoX creates them with this task type / code;
# the title matches only cover legacy rows created before task types and message codes existed.
SH04_TASK_TYPES = ("ORIGINAL_DOCS_RECEIPT", "ORIGINAL_DOCS", "SH-04")
SH04_TASK_MSG_CODES = ("CGX_TASK_COLLECT_ORIGINALS",)
SH04_LEGACY_TITLE_MARKERS = ("SH-04", "أصول المستندات")


def _counters(docs: List[Dict[str, Any]]) -> Dict[str, Any]:
    total = len(docs)
    received = sum(1 for d in docs if d.get("is_received", False))
    verified = sum(1 for d in docs if d.get("is_verified", False))
    return {
        "total_documents_count": total,
        "received_documents_count": received,
        "verified_documents_count": verified,
        "pending_documents_count": total - received,
        "completion_percentage": round((verified / total * 100.0), 1) if total > 0 else 0.0,
    }


def _auto_status(counters: Dict[str, Any], fallback: str) -> str:
    """Status ladder: verified -> received -> partial -> ``fallback`` (DRAFT on save, unchanged on confirm)."""
    total = counters["total_documents_count"]
    if total > 0 and counters["verified_documents_count"] == total:
        return "FULLY_VERIFIED"
    if total > 0 and counters["received_documents_count"] == total:
        return "FULLY_RECEIVED"
    if counters["received_documents_count"] > 0:
        return "PARTIALLY_RECEIVED"
    return fallback


def _days_since(dispatch: Optional[str], today) -> int:
    """Whole days between a stored ``YYYY-MM-DD[...]`` dispatch date and ``today`` (0 when unknown/future)."""
    if not dispatch:
        return 0
    try:
        disp_date = datetime.strptime(str(dispatch).strip().split("T")[0], "%Y-%m-%d").date()
    except ValueError:
        return 0  # legacy rows saved before date validation (ODC-08)
    return max((today - disp_date).days, 0)


def _is_sh04_task(task) -> bool:
    if task.task_type in SH04_TASK_TYPES or task.msg_code in SH04_TASK_MSG_CODES:
        return True
    title = task.title or ""
    return any(marker in title for marker in SH04_LEGACY_TITLE_MARKERS)  # legacy rows only


class OriginalDocumentsCollectionService:
    @staticmethod
    def auto_populate_from_central_archive(
        db: Session, import_file_id: int
    ) -> OriginalDocumentsAutoPopulateResponse:
        import_file = get_or_404(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, active_only=True)

        existing_session = OriginalDocumentsCollectionRepository.get_by_import_file(db, import_file_id)

        # Retrieve central archive details if available
        # Optional enrichment (COO / inspection flags): a failing archive lookup is logged, the checklist still builds.
        archive_data = best_effort(db, get_central_archive_service, "central archive lookup", db, import_file_id)

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
        """Create or update the file's collection session, then run the SH-04 orchestration. One transaction:
        any failure of the required steps rolls everything back (ODC-06)."""
        import_file = get_or_404(db, ImportFile, payload.import_file_id, IMPORT_FILE_LABEL_AR, active_only=True)

        docs_list = validators.normalize_documents(
            [d.model_dump() if isinstance(d, OriginalDocumentItem) else dict(d) for d in payload.documents_list]
        )
        couriers_list = validators.normalize_couriers(
            [c.model_dump() if isinstance(c, CourierEntry) else dict(c) for c in payload.couriers_list]
        )
        counters = _counters(docs_list)

        # The four automatic statuses are recomputed from the counters; IN_TRANSIT / DISCREPANCY_NOTED are kept.
        status_val = validators.normalize_session_status(payload.status or "DRAFT")
        if status_val in validators.AUTO_SESSION_STATUSES:
            status_val = _auto_status(counters, "DRAFT")

        for attempt in range(1, CODE_ATTEMPTS + 1):
            existing_session = OriginalDocumentsCollectionRepository.get_by_import_file(db, payload.import_file_id)
            previous_status = existing_session.status if existing_session else None
            try:
                if existing_session:
                    updates = {
                        "acid_number": payload.acid_number or existing_session.acid_number,
                        "importer_name": payload.importer_name or existing_session.importer_name,
                        "supplier_name": payload.supplier_name or existing_session.supplier_name,
                        "status": status_val,
                        "couriers_list": couriers_list,
                        "documents_list": docs_list,
                        "discrepancy_override_reason": payload.discrepancy_override_reason,
                        "notes": payload.notes,
                        "updated_by": username,
                        **counters,
                    }
                    saved = OriginalDocumentsCollectionRepository.update(db, existing_session, updates)
                else:
                    saved = OriginalDocumentsCollectionRepository.create(
                        db,
                        OriginalDocumentsCollectionSession(
                            collection_code=OriginalDocumentsCollectionRepository.get_next_collection_code(db),
                            import_file_id=payload.import_file_id,
                            import_file_code=import_file.import_file_code or payload.import_file_code,
                            acid_number=payload.acid_number or import_file.acid_number,
                            importer_name=payload.importer_name or getattr(import_file, "company_name", ""),
                            supplier_name=payload.supplier_name or getattr(import_file, "supplier_name", ""),
                            status=status_val,
                            couriers_list=couriers_list,
                            documents_list=docs_list,
                            discrepancy_override_reason=payload.discrepancy_override_reason,
                            notes=payload.notes,
                            created_by=username,
                            updated_by=username,
                            **counters,
                        ),
                    )
                break
            except IntegrityError:
                # The collection code (or the file's single session) was taken concurrently: nothing else has
                # been written in this transaction yet, so roll back and re-resolve once.
                db.rollback()
                if attempt == CODE_ATTEMPTS:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="تعذر حفظ جلسة تحصيل المستندات بسبب تعارض متزامن، يرجى إعادة المحاولة.",
                    )

        OriginalDocumentsCollectionService._handle_original_documents_orchestration_workflow(
            db, saved, updated_by=username, previous_status=previous_status
        )
        db.refresh(saved)
        return OriginalDocumentsCollectionResponse.model_validate(saved)

    save_or_update_session = save_or_upsert_collection_session

    @staticmethod
    def _handle_original_documents_orchestration_workflow(
        db: Session,
        session: OriginalDocumentsCollectionSession,
        updated_by: str = "ADMIN",
        previous_status: Optional[str] = None,
    ) -> None:
        """
        SH-04 orchestration, then the commit:
        1. ImportFile sync (status, session code, AWBs) on every save.
        On FULLY_RECEIVED / FULLY_VERIFIED only (ODC-05):
        2. receipt date set once, progress floor 75, next action NA_CS01_ASSIGN_BROKER; SH-04 SmartTasks closed.
        3. FULLY_VERIFIED only: commercial tier of the DCA ORIGINAL_DOCUMENTS approval (ODC-02, Q1).
        4. Lifecycle STEP_11 -> STEP_12 on the transition into FULLY_* only (the lifecycle service commits by itself).
        Steps 1-4 propagate failures (rollback). Optional, after the commit (``best_effort``):
        5. CS-01 SmartTask (created once), 6. SystemNotification on the transition into FULLY_* only (ODC-07).
        """
        fully = session.status in validators.FULLY_STATUSES
        imp_file = db.query(ImportFile).filter_by(import_file_id=session.import_file_id).first()
        if imp_file:
            imp_file.original_documents_status = session.status
            imp_file.original_documents_session_code = session.collection_code
            awbs = [c.get("courier_no") for c in (session.couriers_list or []) if c.get("courier_no")]
            imp_file.original_documents_courier_no = ", ".join(awbs) if awbs else None

            if fully:
                if imp_file.original_documents_received_at is None:
                    imp_file.original_documents_received_at = datetime.now(timezone.utc)
                if (imp_file.progress_percent or 0) < 75.0:
                    imp_file.progress_percent = 75.0
                if previous_status not in validators.FULLY_STATUSES:
                    set_file_tracking(imp_file, next_action=msg("NA_CS01_ASSIGN_BROKER"))

        if fully:
            from modules.smart_tasks.model import SmartTask

            pending_tasks = (
                db.query(SmartTask)
                .filter(SmartTask.import_file_id == session.import_file_id, SmartTask.status != "Completed")
                .all()
            )
            for t in pending_tasks:
                if _is_sh04_task(t):
                    # SmartTask has no completion_notes column: the closing note goes to ``notes``.
                    closing_note = (
                        f"Original documents received (collection {session.collection_code}, "
                        f"status {session.status})."
                    )
                    t.status = "Completed"
                    t.notes = f"{t.notes}\n{closing_note}" if t.notes else closing_note
                    t.updated_by = updated_by

            if session.status == "FULLY_VERIFIED":
                dca_service.upsert_original_documents_approval(
                    db,
                    import_file_id=session.import_file_id,
                    reference_no=session.collection_code,
                    user=updated_by,
                    commit=False,
                )

            # Only on the transition into FULLY_*: a later save of an already received session must not pull the
            # file back to STEP_12 after it moved on.
            if previous_status not in validators.FULLY_STATUSES:
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

        db.commit()

        if fully:
            file_label = (imp_file.import_file_code if imp_file else None) or session.import_file_code
            best_effort(
                db, OriginalDocumentsCollectionService._dispatch_cs01_task, "SH-04 CS-01 task dispatch",
                db, session, file_label, updated_by,
            )
            if previous_status not in validators.FULLY_STATUSES:
                best_effort(
                    db, OriginalDocumentsCollectionService._emit_received_notification,
                    "SH-04 originals received notification", db, session, file_label,
                )

    @staticmethod
    def _dispatch_cs01_task(db: Session, session: OriginalDocumentsCollectionSession, file_label: str, user: str) -> None:
        """Downstream CS-01 SmartTask (customs broker electronic authorization), created once per file."""
        from modules.smart_tasks.model import SmartTask

        existing_cs01 = (
            db.query(SmartTask)
            .filter(
                SmartTask.import_file_id == session.import_file_id,
                SmartTask.task_type.in_(["CUSTOMS_BROKER_ASSIGNMENT", "CS-01"]),
            )
            .first()
        )
        if existing_cs01:
            return
        task_msg = msg("ODC_TASK_ASSIGN_BROKER", import_file_code=file_label, collection_code=session.collection_code)
        db.add(
            SmartTask(
                task_code=f"TASK-{uuid.uuid4().hex[:8].upper()}",
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
                due_date=(cairo_today() + timedelta(days=3)).isoformat(),
                created_by=user,
            )
        )
        db.commit()

    @staticmethod
    def _emit_received_notification(db: Session, session: OriginalDocumentsCollectionSession, file_label: str) -> None:
        from modules.notifications.model import SystemNotification

        notif_msg = msg(
            "ODC_ORIGINALS_RECEIVED",
            collection_code=session.collection_code,
            import_file_code=file_label,
            completion_pct=session.completion_percentage,
        )
        db.add(
            SystemNotification(
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
        )
        db.commit()

    @staticmethod
    def get_session_by_id(db: Session, collection_id: int) -> OriginalDocumentsCollectionResponse:
        session = OriginalDocumentsCollectionRepository.get_by_id(db, collection_id)
        if not session:
            from modules.common.validators import not_found

            raise not_found(SESSION_LABEL_AR, collection_id)
        return OriginalDocumentsCollectionResponse.model_validate(session)

    @staticmethod
    def get_session_by_file(db: Session, import_file_id: int) -> OriginalDocumentsCollectionResponse:
        """The file's active session. No session yet -> 404 ``ODC_SESSION_NOT_FOUND`` (the Flutter client maps
        exactly 404 to "no session"; any other failure surfaces, so a save never upserts blindly)."""
        session = OriginalDocumentsCollectionRepository.get_by_import_file(db, import_file_id)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "ODC_SESSION_NOT_FOUND",
                    "message": f"لا توجد جلسة تحصيل مستندات أصلية لملف الاستيراد رقم {import_file_id}.",
                    "import_file_id": import_file_id,
                },
            )
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
    def export_filename(db: Session, import_file_id: int) -> str:
        """Task I naming: ``Original Documents Collection - <import file code>.xlsx`` (ODC-04)."""
        import_file = get_or_404(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, active_only=True)
        label = import_file.import_file_code or import_file.custom_file_number or f"FILE-{import_file_id}"
        return f"Original Documents Collection - {label}.xlsx"

    @staticmethod
    def export_collection_to_excel_bytes(db: Session, import_file_id: int) -> bytes:
        """Collection sheet of the import file's session (path param = import_file_id only, ODC-04); the
        auto-populated checklist when the file has no session yet."""
        get_or_404(db, ImportFile, import_file_id, IMPORT_FILE_LABEL_AR, active_only=True)
        session = OriginalDocumentsCollectionRepository.get_by_import_file(db, import_file_id)

        if not session:
            # Generate from auto-populated
            auto_data = OriginalDocumentsCollectionService.auto_populate_from_central_archive(db, import_file_id)
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
        return f"https://www.google.com/search?q={quote_plus(f'{company or ''} {clean_awb} tracking')}"

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
        received_date = validators.normalize_date(request.received_date, "تاريخ الاستلام")
        if not received_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="تاريخ الاستلام مطلوب بالصيغة YYYY-MM-DD.",
            )

        couriers = copy.deepcopy(session.couriers_list or [])
        target_awb = validators.awb_key(request.courier_no)
        # Exact AWB match only (ODC-03): "12345" must not mark "9912345" delivered.
        courier = next((c for c in couriers if target_awb and validators.awb_key(c.get("courier_no")) == target_awb), None)
        if courier is None:
            # Q2: an unknown AWB is not invented as a DHL row; the user adds the courier on the session first.
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "ODC_COURIER_NOT_FOUND",
                    "message": f"رقم الطرد ({request.courier_no.strip()}) غير مسجل في جلسة تحصيل المستندات لهذه الشحنة. "
                    "أضف الطرد إلى الجلسة أولاً.",
                    "courier_no": request.courier_no.strip(),
                    "import_file_id": request.import_file_id,
                },
            )

        courier["is_received"] = True
        courier["received_date"] = received_date
        if request.received_time:
            courier["received_time"] = request.received_time
        courier["received_by"] = request.received_by
        courier["status"] = "DELIVERED"
        if request.pod_reference:
            courier["pod_reference"] = request.pod_reference
        if request.notes:
            existing_notes = courier.get("notes") or ""
            courier["notes"] = f"{existing_notes} | {request.notes}".strip(" |")
        courier["tracking_url"] = OriginalDocumentsCollectionService.build_carrier_tracking_url(
            courier.get("courier_company") or "DHL", courier.get("courier_no") or ""
        )

        docs = copy.deepcopy(session.documents_list or [])
        if request.mark_documents_received:
            # Only the documents assigned to this courier; documents without a courier stay untouched (ODC-03).
            for d in docs:
                if validators.awb_key(d.get("courier_no")) == target_awb:
                    d["is_received"] = True
                    if not d.get("received_date"):
                        d["received_date"] = received_date
                    if d.get("status") in ["Pending", "In Transit"]:
                        d["status"] = "Received"

        counters = _counters(docs)
        previous_status = session.status
        updates = {
            "couriers_list": couriers,
            "documents_list": docs,
            "status": _auto_status(counters, session.status),
            "updated_by": username,
            **counters,
        }
        saved = OriginalDocumentsCollectionRepository.update(db, session, updates)

        OriginalDocumentsCollectionService._handle_original_documents_orchestration_workflow(
            db, saved, updated_by=username, previous_status=previous_status
        )
        db.refresh(saved)
        return OriginalDocumentsCollectionResponse.model_validate(saved)

    @staticmethod
    def get_courier_alerts(db: Session) -> CourierAlertsResponse:
        sessions = OriginalDocumentsCollectionRepository.get_active_with_couriers(db)
        today = cairo_today()

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
                days = _days_since(disp_str, today)

                if days >= validators.COURIER_SLA_DAYS:
                    level = "CRITICAL"
                    delayed_count += 1
                    msg_ar = f"طرد {c_company} رقم ({c_no}) مرسل منذ {days} أيام للشحنة {s.import_file_code} وتجاوز المهلة المقررة (SLA)"
                    msg_en = f"Courier {c_company} ({c_no}) in transit for {days} days on shipment {s.import_file_code} — SLA breached!"
                elif days >= validators.COURIER_WARN_DAYS:
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
        sessions = OriginalDocumentsCollectionRepository.get_active_with_couriers(db)
        today = cairo_today()
        result: List[CourierFlatItemResponse] = []

        for s in sessions:
            docs = s.documents_list or []
            for c in (s.couriers_list or []):
                c_no = (c.get("courier_no") or "").strip()
                c_comp = c.get("courier_company") or "DHL"
                is_rcv = c.get("is_received", False)
                disp_str = c.get("dispatch_date")
                days = _days_since(disp_str, today)

                if is_rcv:
                    status_val = "DELIVERED"
                elif days >= validators.COURIER_SLA_DAYS:  # Q4: same SLA as the CRITICAL alert
                    status_val = "DELAYED"
                elif days > 0:
                    status_val = "IN_TRANSIT"
                else:
                    status_val = "DISPATCHED"

                matched_docs_count = sum(
                    1 for d in docs if c_no and validators.awb_key(d.get("courier_no")) == c_no.upper()
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
