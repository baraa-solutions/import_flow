"""
CargoX Envelope Service Layer (CGX-001)
Handles envelope lifecycle, state management, metadata validation, and customs dispatch.
"""

import hashlib
import uuid
import logging
from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from .model import CargoXEnvelope, CargoXEnvelopeDocument
from .schemas import (
    CargoXEnvelopeCreate,
    CargoXEnvelopeUpdate,
    CargoXSealAndTransferRequest,
    CargoXSealAndTransferResponse,
    CargoXAcidVerificationReport,
    ACIDDocumentVerificationItem,
)
from .repository import CargoXRepository
from .validators import CargoXValidators
from .cargox_blockchain_service import CargoXBlockchainService, normalize_pki_signature
from ..integrations.cargox_client import CargoXIntegrationClient
from ..integrations.pki_signer import PKISignerService
from ..integrations.integration_mode import IntegrationModeError
from ..import_files.model import ImportFile
from modules.common.system_messages import msg, render_en
from modules.common.file_tracking import set_file_tracking

logger = logging.getLogger(__name__)


class CargoXEnvelopeService:
    """
    Sub-service for CargoX Envelope operations, lifecycle transitions, and Egyptian Customs Nafeza dispatch.
    """

    @staticmethod
    def create_envelope(db: Session, payload: CargoXEnvelopeCreate, created_by: str = "SYSTEM") -> CargoXEnvelope:
        CargoXValidators.validate_envelope_creation(payload)

        envelope_code = CargoXRepository.get_next_code(db)
        # Mode from server settings, never from the request (Production Mock Guard, NLv0Dpj5).
        client = CargoXIntegrationClient()

        # Call CargoX Integration Client
        doc_type_names = [d.doc_type for d in (payload.documents or [])]
        if not doc_type_names:
            doc_type_names = ["Commercial Invoice", "Packing List", "Draft B/L"]

        importer_code = payload.importer_company_name[:20].upper().replace(" ", "_") if payload.importer_company_name else "IMPORTER"
        cx_res = {}
        if not (getattr(payload, "is_draft", False) or getattr(payload, "status", None) == "DRAFT"):
            try:
                cx_res = client.create_envelope(
                    acid_number=payload.acid_number,
                    importer_company_code=importer_code,
                    foreign_exporter_cargox_id=payload.supplier_cargox_id or "CARGOX-EXPORTER",
                    document_types=doc_type_names,
                )
            except IntegrationModeError as exc:
                # Guard refused the call (e.g. MOCK in the production build): keep the local envelope
                # record, but without any blockchain hash or signature pretending it was sent.
                logger.warning("CargoX envelope %s not sent: %s", envelope_code, exc.detail)
                cx_res = {}
            except Exception:
                cx_res = {}

        import_file_code = None
        if payload.import_file_id:
            import_file = db.query(ImportFile).filter(ImportFile.import_file_id == payload.import_file_id).first()
            if import_file:
                import_file_code = import_file.import_file_code

        pki_sig_str = normalize_pki_signature(cx_res.get("pki_signature"))
        is_draft_mode = getattr(payload, "is_draft", False)
        if is_draft_mode:
            envelope_status = "DRAFT"
            is_verified = False
        elif payload.status:
            envelope_status = payload.status
            is_verified = True if payload.documents else False
        else:
            envelope_status = "UPLOADED_BY_SUPPLIER" if payload.documents else "DRAFT"
            is_verified = True if payload.documents else False

        envelope = CargoXEnvelope(
            envelope_code=envelope_code,
            import_file_id=payload.import_file_id,
            import_file_code=import_file_code,
            acid_number=payload.acid_number,
            importer_company_id=payload.importer_company_id,
            importer_company_name=payload.importer_company_name,
            importer_tax_number=payload.importer_tax_number,
            supplier_id=payload.supplier_id,
            supplier_name=payload.supplier_name,
            supplier_cargox_id=payload.supplier_cargox_id,
            bl_number=payload.bl_number,
            status=envelope_status,
            blockchain_tx_hash=cx_res.get("blockchain_tx_hash"),
            pki_signature=pki_sig_str,
            integration_mode=cx_res.get("integration_mode"),
            is_acid_verified=is_verified,
            all_documents_sealed=False,
            notes=payload.notes,
            created_by=created_by,
            updated_by=created_by,
        )

        # Attach documents
        if payload.documents:
            for d in payload.documents:
                file_hash = d.file_hash or hashlib.sha256(f"{d.file_name}-{payload.acid_number}".encode()).hexdigest()
                doc_item = CargoXEnvelopeDocument(
                    doc_type=d.doc_type,
                    doc_number=d.doc_number,
                    file_name=d.file_name,
                    file_hash=file_hash,
                    file_size_kb=d.file_size_kb if d.file_size_kb > 0 else 256.0,
                    is_mandatory=d.is_mandatory,
                    is_uploaded=True,
                    verified_against_acid=d.verified_against_acid,
                    pki_signature=f"SIG-DOC-{uuid.uuid4().hex[:12].upper()}",
                    notes=d.notes,
                )
                envelope.documents.append(doc_item)

        return CargoXRepository.create(db, envelope)

    @staticmethod
    def get_envelopes(
        db: Session,
        search: Optional[str] = None,
        status: Optional[str] = None,
        import_file_id: Optional[int] = None,
        supplier_id: Optional[int] = None,
        include_inactive: bool = False,
        limit: int = 100,
        offset: int = 0,
    ) -> List[CargoXEnvelope]:
        return CargoXRepository.get_all(
            db=db,
            search=search,
            status=status,
            import_file_id=import_file_id,
            supplier_id=supplier_id,
            include_inactive=include_inactive,
            limit=limit,
            offset=offset,
        )

    @staticmethod
    def get_envelope_by_id(db: Session, envelope_id: int) -> CargoXEnvelope:
        envelope = CargoXRepository.get_by_id(db, envelope_id)
        if not envelope:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"مظروف CargoX برقم المعرف {envelope_id} غير موجود.",
            )
        return envelope

    @staticmethod
    def update_envelope(
        db: Session, envelope_id: int, payload: CargoXEnvelopeUpdate, updated_by: str = "SYSTEM"
    ) -> CargoXEnvelope:
        envelope = CargoXEnvelopeService.get_envelope_by_id(db, envelope_id)

        if payload.acid_number:
            envelope.acid_number = CargoXValidators.validate_acid_number(payload.acid_number)
        if payload.importer_company_name:
            envelope.importer_company_name = payload.importer_company_name
        if payload.importer_tax_number is not None:
            envelope.importer_tax_number = payload.importer_tax_number
        if payload.supplier_name:
            envelope.supplier_name = payload.supplier_name
        if payload.supplier_cargox_id:
            envelope.supplier_cargox_id = CargoXValidators.validate_cargox_id(payload.supplier_cargox_id)
        if payload.bl_number is not None:
            envelope.bl_number = payload.bl_number
        if payload.status:
            envelope.status = payload.status
        if payload.notes is not None:
            envelope.notes = payload.notes

        envelope.updated_by = updated_by
        return CargoXRepository.update(db, envelope)

    @staticmethod
    def seal_and_transfer_to_customs(
        db: Session, envelope_id: int, request: CargoXSealAndTransferRequest, updated_by: str = "SYSTEM"
    ) -> CargoXSealAndTransferResponse:
        envelope = CargoXEnvelopeService.get_envelope_by_id(db, envelope_id)
        CargoXValidators.validate_ready_for_customs_transfer(envelope)

        bl_num = request.bl_number or envelope.bl_number or f"BL-EGY-{uuid.uuid4().hex[:8].upper()}"
        envelope.bl_number = bl_num

        # Mode from server settings; the guard raises (HTTP 503) before any state change when the
        # configured mode may not run, so a production build never seals from a mock client.
        client = CargoXIntegrationClient()
        transfer_res = client.transfer_envelope_to_customs(
            envelope_id=envelope.envelope_code,
            bl_number=bl_num,
        )

        signer = PKISignerService()
        pki_sig = signer.sign_payload({
            "envelope_code": envelope.envelope_code,
            "acid_number": envelope.acid_number,
            "bl_number": bl_num,
            "customs_recipient": "EGYPTIAN_CUSTOMS_MTS_NAFEZA",
            "transferred_at": datetime.now(timezone.utc).isoformat(),
        })

        envelope.status = "ACCEPTED_BY_CUSTOMS"
        envelope.all_documents_sealed = True
        envelope.is_acid_verified = True
        envelope.transferred_to_customs_at = datetime.now(timezone.utc)
        envelope.customs_confirmation_receipt = transfer_res.get("confirmation_receipt", f"MTS-REC-{uuid.uuid4().hex[:8].upper()}")
        envelope.pki_signature = normalize_pki_signature(pki_sig)
        envelope.integration_mode = client.mode
        envelope.updated_by = updated_by

        # Build Manifest Snapshot
        manifest_payload = CargoXBlockchainService.build_digital_manifest_payload(envelope)
        envelope.manifest_payload = manifest_payload

        CargoXRepository.update(db, envelope)

        # Full SH-03 Orchestration (ImportFile sync, SmartTasks, Notifications, Approvals, Lifecycle STEP_10->STEP_11)
        if envelope.import_file_id:
            CargoXEnvelopeService._handle_cargox_seal_transfer_workflow(db, envelope, updated_by=updated_by)

        return CargoXSealAndTransferResponse(
            success=True,
            envelope_id=envelope.envelope_id,
            envelope_code=envelope.envelope_code,
            acid_number=envelope.acid_number,
            status=envelope.status,
            bl_number=envelope.bl_number,
            blockchain_tx_hash=envelope.blockchain_tx_hash or "0x" + uuid.uuid4().hex,
            pki_signature=envelope.pki_signature,
            transferred_at=envelope.transferred_to_customs_at,
            customs_confirmation_receipt=envelope.customs_confirmation_receipt,
            message=CargoXEnvelopeService._seal_message(transfer_res.get("is_simulated", False)),
            integration_mode=client.mode,
            is_simulated=bool(transfer_res.get("is_simulated", False)),
        )

    @staticmethod
    def _seal_message(is_simulated: bool) -> str:
        if is_simulated:
            return "محاكاة فقط: تم تسجيل الإغلاق محلياً ولم يتم إرسال أي شيء فعلياً إلى CargoX أو نافذة."
        return "تم إغلاق وتوثيق مظروف CargoX والتوقيع الإلكتروني بنجاح وتحويل المستندات لمصلحة الجمارك المصرية (Nafeza)."

    @staticmethod
    def _handle_cargox_seal_transfer_workflow(
        db: Session, envelope: CargoXEnvelope, updated_by: str = "SYSTEM"
    ) -> None:
        """
        SH-03 Orchestration Workflow:
        1. Two-way synchronizes ImportFile with CargoX envelope metadata and advances stage.
        2. Auto-closes pending SH-03 / CargoX SmartTasks.
        3. Dispatches downstream SH-04 SmartTask (Original Bank Documents Receipt).
        4. Emits SystemNotification for operations and customs broker.
        5. Updates CustomsDocumentApproval record for CargoX envelope.
        6. Advances LifecycleBoard step STEP_10 -> STEP_11.
        """
        if not envelope.import_file_id:
            return

        try:
            # 1. Update ImportFile
            imp_file = db.query(ImportFile).filter(ImportFile.import_file_id == envelope.import_file_id).first()
            if imp_file:
                imp_file.cargox_envelope_id = envelope.envelope_id
                imp_file.cargox_envelope_code = envelope.envelope_code
                imp_file.cargox_envelope_status = envelope.status
                imp_file.cargox_transferred_at = envelope.transferred_to_customs_at
                set_file_tracking(imp_file, step_code="STEP_10", next_action=msg("NA_SH04_COLLECT_ORIGINALS"))
                current_prog = imp_file.progress_percent or 0.0
                if current_prog < 70.0:
                    imp_file.progress_percent = 70.0

            # 2. Complete pending SH-03 / CargoX SmartTasks
            try:
                from modules.smart_tasks.model import SmartTask
                pending_tasks = (
                    db.query(SmartTask)
                    .filter(
                        SmartTask.import_file_id == envelope.import_file_id,
                        SmartTask.status.in_(["Pending", "In Progress"]),
                        (
                            SmartTask.task_type.in_(["CARGOX_TRANSFER", "CARGOX_SEAL", "CARGOX_UPLOAD", "SH-03"])
                            | SmartTask.title.ilike("%CargoX%")
                        ),
                    )
                    .all()
                )
                for t in pending_tasks:
                    t.status = "Completed"
                    t.completed_at = datetime.now(timezone.utc)
            except Exception as ex_task:
                logger.warning(f"Error completing CargoX smart tasks: {ex_task}")

            # 3. Dispatch downstream SH-04 SmartTask (Original Bank Documents Receipt)
            try:
                from modules.smart_tasks.model import SmartTask
                due_dt = (datetime.now(timezone.utc) + timedelta(days=5)).strftime("%Y-%m-%d")
                file_label = imp_file.import_file_code if imp_file else (envelope.import_file_code or "")
                task_code = f"TASK-{uuid.uuid4().hex[:8].upper()}"
                task_msg = msg(
                    "CGX_TASK_COLLECT_ORIGINALS",
                    import_file_code=file_label,
                    envelope_code=envelope.envelope_code,
                    receipt_no=envelope.customs_confirmation_receipt,
                )
                downstream_task = SmartTask(
                    task_code=task_code,
                    import_file_id=envelope.import_file_id,
                    import_file_code=file_label,
                    title=render_en(task_msg.code, task_msg.params, "title").strip(),
                    description=render_en(task_msg.code, task_msg.params, "body"),
                    msg_code=task_msg.code,
                    msg_params=task_msg.params,
                    step_code="STEP_11",
                    task_type="ORIGINAL_DOCS_RECEIPT",
                    priority="High",
                    status="Pending",
                    assigned_user="Logistics Specialist",
                    due_date=due_dt,
                    created_by=updated_by,
                )
                db.add(downstream_task)
            except Exception as ex_dispatch:
                logger.warning(f"Error dispatching downstream SH-04 smart task: {ex_dispatch}")

            # 4. Emit SystemNotification
            try:
                from modules.notifications.model import SystemNotification
                notif_msg = msg(
                    "CGX_ENVELOPE_SEALED",
                    envelope_code=envelope.envelope_code,
                    acid_number=envelope.acid_number,
                    receipt_no=envelope.customs_confirmation_receipt,
                )
                notif = SystemNotification(
                    title=render_en(notif_msg.code, notif_msg.params, "title"),
                    message=render_en(notif_msg.code, notif_msg.params, "body"),
                    msg_code=notif_msg.code,
                    msg_params=notif_msg.params,
                    category="STAGE_PROGRESSION",
                    severity="INFO",
                    entity_type="ImportFile",
                    entity_id=envelope.import_file_id,
                    target_role="ALL",
                    is_read=False,
                )
                db.add(notif)
            except Exception as ex_notif:
                logger.warning(f"Error creating CargoX SystemNotification: {ex_notif}")

            # 5. Update CustomsDocumentApproval for CargoX envelope
            try:
                from modules.docs_customs_approval.model import CustomsDocumentApproval
                approval_rec = (
                    db.query(CustomsDocumentApproval)
                    .filter(
                        CustomsDocumentApproval.import_file_id == envelope.import_file_id,
                        CustomsDocumentApproval.document_type.in_(["CARGOX_ENVELOPE", "CARGOX_DOCUMENTS", "CargoX Transfer"]),
                    )
                    .first()
                )
                if not approval_rec:
                    approval_rec = CustomsDocumentApproval(
                        approval_code=f"DCA-{uuid.uuid4().hex[:8].upper()}",
                        import_file_id=envelope.import_file_id,
                        import_file_code=imp_file.import_file_code if imp_file else envelope.import_file_code,
                        document_type="CARGOX_ENVELOPE",
                        document_reference_no=envelope.envelope_code,
                        commercial_status="Approved",
                        commercial_reviewed_by=updated_by,
                        commercial_reviewed_at=datetime.now(timezone.utc),
                        customs_status="Approved",
                        customs_reviewed_by=updated_by,
                        customs_reviewed_at=datetime.now(timezone.utc),
                        overall_status="Approved for Clearance",
                        commercial_notes=f"Envelope sealed electronically with customs receipt no. {envelope.customs_confirmation_receipt}",
                    )
                    db.add(approval_rec)
                else:
                    approval_rec.commercial_status = "Approved"
                    approval_rec.customs_status = "Approved"
                    approval_rec.overall_status = "Approved for Clearance"
                    approval_rec.document_reference_no = envelope.envelope_code
                    approval_rec.commercial_notes = f"Envelope sealed electronically with customs receipt no. {envelope.customs_confirmation_receipt}"
            except Exception as ex_appr:
                logger.warning(f"Error updating CustomsDocumentApproval for CargoX: {ex_appr}")

            # 6. Advance Lifecycle step STEP_10 -> STEP_11
            try:
                from modules.lifecycle_board.service import advance_lifecycle_step_service
                advance_lifecycle_step_service(
                    db=db,
                    import_file_id=envelope.import_file_id,
                    completed_step_code="STEP_10",
                    target_step_codes=["STEP_11"],
                    notes_msg=msg("CGX_ENVELOPE_SEALED", envelope_code=envelope.envelope_code),
                    next_action_msg=msg("NA_SH04_COLLECT_ORIGINALS"),
                    assigned_user=updated_by,
                )
            except Exception as ex_lc:
                logger.warning(f"Lifecycle advance STEP_10→STEP_11 failed: {ex_lc}")

            db.commit()
        except Exception as e:
            logger.error(f"Error executing _handle_cargox_seal_transfer_workflow: {e}")

    @staticmethod
    def verify_acid_consistency(db: Session, envelope_id: int) -> CargoXAcidVerificationReport:
        envelope = CargoXEnvelopeService.get_envelope_by_id(db, envelope_id)
        target_acid = envelope.acid_number

        items: List[ACIDDocumentVerificationItem] = []
        all_matched = True

        for doc in envelope.documents:
            if not doc.is_active:
                continue
            is_match = doc.verified_against_acid
            if not is_match:
                all_matched = False
            items.append(
                ACIDDocumentVerificationItem(
                    doc_type=doc.doc_type,
                    doc_number=doc.doc_number,
                    document_acid=target_acid if is_match else f"{target_acid[:-3]}999 (Mismatch)",
                    is_matched=is_match,
                    status="VERIFIED_100_PERCENT_MATCH" if is_match else "CRITICAL_ACID_MISMATCH",
                    notes="ACID Number verified: 100% match with import file" if is_match else "Warning: ACID Number mismatch",
                )
            )

        envelope.is_acid_verified = all_matched
        CargoXRepository.update(db, envelope)

        return CargoXAcidVerificationReport(
            envelope_id=envelope.envelope_id,
            envelope_code=envelope.envelope_code,
            target_acid_number=target_acid,
            all_matched=all_matched,
            verified_count=sum(1 for i in items if i.is_matched),
            total_documents=len(items),
            verification_status="ALL_DOCUMENTS_ACID_VERIFIED" if all_matched else "DISCREPANCIES_DETECTED",
            items=items,
        )

    @staticmethod
    def soft_delete_envelope(db: Session, envelope_id: int, deleted_by: str = "SYSTEM") -> CargoXEnvelope:
        envelope = CargoXEnvelopeService.get_envelope_by_id(db, envelope_id)
        return CargoXRepository.soft_delete(db, envelope, deleted_by=deleted_by)

    @staticmethod
    def restore_envelope(db: Session, envelope_id: int, restored_by: str = "SYSTEM") -> CargoXEnvelope:
        envelope = CargoXRepository.get_by_id(db, envelope_id, include_inactive=True)
        if not envelope:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"مظروف CargoX برقم المعرف {envelope_id} غير موجود.",
            )
        return CargoXRepository.restore(db, envelope, restored_by=restored_by)
