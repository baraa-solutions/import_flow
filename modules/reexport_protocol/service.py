from datetime import date, datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from .model import ReexportDossier
from .repository import ReexportProtocolRepository
from .schemas import (
    ReexportDossierCreate,
    ReexportDossierUpdate,
    OutboundBookingRequest,
    SupervisionCommitteeRequest,
    CreditNoteRequest,
    DutyDrawbackRequest,
    DestructionAlertOverviewResponse,
    DestructionAlertSummary,
)
from .validators import (
    validate_legal_deadline,
    clean_container_numbers,
    validate_amounts,
    calculate_destruction_countdown,
    validate_status_transition,
)


class ReexportProtocolService:
    @staticmethod
    def create_dossier(
        db: Session, payload: ReexportDossierCreate, user: str = "System"
    ) -> ReexportDossier:
        # Check existing decree number
        existing = ReexportProtocolRepository.get_by_decree(db, payload.rejection_decree_number)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Re-export dossier with decree number {payload.rejection_decree_number} already exists.",
            )

        # Validate statutory deadline (30 days from decree)
        deadline = validate_legal_deadline(payload.rejection_date, payload.legal_reexport_deadline)
        days_remaining, _ = calculate_destruction_countdown(deadline)

        # Validate amounts and clean containers
        validate_amounts(payload.duty_amount_refundable_egp, payload.credit_note_amount_usd)
        cleaned_containers = clean_container_numbers(payload.container_numbers)

        dossier = ReexportDossier(
            import_file_id=payload.import_file_id,
            import_file_code=payload.import_file_code,
            rejection_authority=payload.rejection_authority,
            rejection_decree_number=payload.rejection_decree_number,
            rejection_date=payload.rejection_date,
            legal_reexport_deadline=deadline,
            days_remaining_to_destruction=days_remaining,
            reexport_reason=payload.reexport_reason,
            customs_outbound_declaration_no=payload.customs_outbound_declaration_no,
            supervision_committee_formed=payload.supervision_committee_formed,
            customs_officer_in_charge=payload.customs_officer_in_charge,
            return_carrier_id=payload.return_carrier_id,
            return_booking_number=payload.return_booking_number,
            outbound_bl_number=payload.outbound_bl_number,
            container_numbers=cleaned_containers,
            return_port_of_discharge=payload.return_port_of_discharge,
            duty_drawback_status=payload.duty_drawback_status.value if payload.duty_drawback_status else "PENDING_APPLICATION",
            duty_amount_refundable_egp=payload.duty_amount_refundable_egp,
            supplier_credit_note_status=payload.supplier_credit_note_status.value if payload.supplier_credit_note_status else "REQUESTED",
            credit_note_amount_usd=payload.credit_note_amount_usd,
            status=payload.status.value if payload.status else "MANDATED",
            notes=payload.notes,
            created_by=user,
            updated_by=user,
        )

        return ReexportProtocolRepository.create(db, dossier)

    @staticmethod
    def get_dossier(db: Session, reexport_id: int) -> ReexportDossier:
        dossier = ReexportProtocolRepository.get_by_id(db, reexport_id)
        if not dossier or not dossier.is_active:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Re-export dossier with ID {reexport_id} not found.",
            )
        # Update dynamic countdown
        dossier.calculate_days_remaining()
        return dossier

    @staticmethod
    def list_dossiers(
        db: Session,
        include_inactive: bool = False,
        import_file_id: Optional[int] = None,
        status_filter: Optional[str] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[ReexportDossier], int]:
        items, total = ReexportProtocolRepository.list(
            db,
            include_inactive=include_inactive,
            import_file_id=import_file_id,
            status=status_filter,
            search=search,
            skip=skip,
            limit=limit,
        )
        for item in items:
            item.calculate_days_remaining()
        return items, total

    @staticmethod
    def update_dossier(
        db: Session, reexport_id: int, payload: ReexportDossierUpdate, user: str = "System"
    ) -> ReexportDossier:
        dossier = ReexportProtocolService.get_dossier(db, reexport_id)

        update_data = payload.model_dump(exclude_unset=True)

        if "rejection_date" in update_data or "legal_reexport_deadline" in update_data:
            rejection_date = update_data.get("rejection_date", dossier.rejection_date)
            deadline = update_data.get("legal_reexport_deadline", dossier.legal_reexport_deadline)
            new_deadline = validate_legal_deadline(rejection_date, deadline)
            dossier.rejection_date = rejection_date
            dossier.legal_reexport_deadline = new_deadline
            dossier.calculate_days_remaining()

        if "container_numbers" in update_data and update_data["container_numbers"] is not None:
            dossier.container_numbers = clean_container_numbers(update_data["container_numbers"])

        if "duty_amount_refundable_egp" in update_data:
            validate_amounts(update_data["duty_amount_refundable_egp"], 0.0)
            dossier.duty_amount_refundable_egp = update_data["duty_amount_refundable_egp"]

        if "credit_note_amount_usd" in update_data:
            validate_amounts(0.0, update_data["credit_note_amount_usd"])
            dossier.credit_note_amount_usd = update_data["credit_note_amount_usd"]

        if "status" in update_data and update_data["status"] is not None:
            target_status = update_data["status"].value if hasattr(update_data["status"], "value") else update_data["status"]
            state_dict = {
                "return_booking_number": dossier.return_booking_number,
                "supervision_committee_formed": dossier.supervision_committee_formed,
                "customs_outbound_declaration_no": dossier.customs_outbound_declaration_no,
                "outbound_bl_number": dossier.outbound_bl_number,
            }
            validate_status_transition(dossier.status, target_status, state_dict)
            dossier.status = target_status

        # Update remaining simple scalar attributes
        simple_attrs = [
            "rejection_authority",
            "rejection_decree_number",
            "reexport_reason",
            "customs_outbound_declaration_no",
            "supervision_committee_formed",
            "customs_officer_in_charge",
            "return_carrier_id",
            "return_booking_number",
            "outbound_bl_number",
            "return_port_of_discharge",
            "notes",
        ]
        for attr in simple_attrs:
            if attr in update_data and update_data[attr] is not None:
                setattr(dossier, attr, update_data[attr])

        if "duty_drawback_status" in update_data and update_data["duty_drawback_status"] is not None:
            val = update_data["duty_drawback_status"]
            dossier.duty_drawback_status = val.value if hasattr(val, "value") else str(val)

        if "supplier_credit_note_status" in update_data and update_data["supplier_credit_note_status"] is not None:
            val = update_data["supplier_credit_note_status"]
            dossier.supplier_credit_note_status = val.value if hasattr(val, "value") else str(val)

        dossier.updated_by = user
        dossier.updated_at = datetime.now(timezone.utc)
        return ReexportProtocolRepository.update(db, dossier)

    @staticmethod
    def soft_delete_dossier(db: Session, reexport_id: int, user: str = "System") -> ReexportDossier:
        dossier = ReexportProtocolService.get_dossier(db, reexport_id)
        return ReexportProtocolRepository.soft_delete(db, reexport_id, user)

    @staticmethod
    def record_outbound_booking(
        db: Session, reexport_id: int, req: OutboundBookingRequest, user: str = "System"
    ) -> ReexportDossier:
        dossier = ReexportProtocolService.get_dossier(db, reexport_id)
        dossier.return_carrier_id = req.return_carrier_id
        dossier.return_booking_number = req.return_booking_number
        dossier.return_port_of_discharge = req.return_port_of_discharge
        if req.outbound_bl_number:
            dossier.outbound_bl_number = req.outbound_bl_number

        if dossier.status == "MANDATED":
            dossier.status = "BOOKING_CONFIRMED"

        dossier.updated_by = user
        dossier.updated_at = datetime.now(timezone.utc)
        return ReexportProtocolRepository.update(db, dossier)

    @staticmethod
    def form_supervision_committee(
        db: Session, reexport_id: int, req: SupervisionCommitteeRequest, user: str = "System"
    ) -> ReexportDossier:
        dossier = ReexportProtocolService.get_dossier(db, reexport_id)
        dossier.supervision_committee_formed = req.supervision_committee_formed
        dossier.customs_officer_in_charge = req.customs_officer_in_charge
        dossier.customs_outbound_declaration_no = req.customs_outbound_declaration_no

        if dossier.status in ("MANDATED", "BOOKING_CONFIRMED"):
            dossier.status = "CUSTOMS_INSPECTED"

        dossier.updated_by = user
        dossier.updated_at = datetime.now(timezone.utc)
        return ReexportProtocolRepository.update(db, dossier)

    @staticmethod
    def record_credit_note(
        db: Session, reexport_id: int, req: CreditNoteRequest, user: str = "System"
    ) -> ReexportDossier:
        validate_amounts(0.0, req.credit_note_amount_usd)
        dossier = ReexportProtocolService.get_dossier(db, reexport_id)
        dossier.supplier_credit_note_status = req.supplier_credit_note_status.value
        dossier.credit_note_amount_usd = req.credit_note_amount_usd
        dossier.updated_by = user
        dossier.updated_at = datetime.now(timezone.utc)
        return ReexportProtocolRepository.update(db, dossier)

    @staticmethod
    def record_duty_drawback(
        db: Session, reexport_id: int, req: DutyDrawbackRequest, user: str = "System"
    ) -> ReexportDossier:
        validate_amounts(req.duty_amount_refundable_egp, 0.0)
        dossier = ReexportProtocolService.get_dossier(db, reexport_id)
        dossier.duty_drawback_status = req.duty_drawback_status.value
        dossier.duty_amount_refundable_egp = req.duty_amount_refundable_egp
        dossier.updated_by = user
        dossier.updated_at = datetime.now(timezone.utc)
        return ReexportProtocolRepository.update(db, dossier)

    @staticmethod
    def transition_status(
        db: Session, reexport_id: int, target_status: str, user: str = "System"
    ) -> ReexportDossier:
        dossier = ReexportProtocolService.get_dossier(db, reexport_id)
        state_dict = {
            "return_booking_number": dossier.return_booking_number,
            "supervision_committee_formed": dossier.supervision_committee_formed,
            "customs_outbound_declaration_no": dossier.customs_outbound_declaration_no,
            "outbound_bl_number": dossier.outbound_bl_number,
        }
        validate_status_transition(dossier.status, target_status, state_dict)
        dossier.status = target_status
        dossier.updated_by = user
        dossier.updated_at = datetime.now(timezone.utc)
        return ReexportProtocolRepository.update(db, dossier)

    @staticmethod
    def get_destruction_countdown_alerts(
        db: Session, as_of_date: Optional[date] = None
    ) -> DestructionAlertOverviewResponse:
        active_dossiers = ReexportProtocolRepository.get_active_dossiers(db)
        alerts: List[DestructionAlertSummary] = []
        critical_count = 0
        urgent_count = 0
        warning_count = 0
        normal_count = 0

        for d in active_dossiers:
            days_rem, level = calculate_destruction_countdown(d.legal_reexport_deadline, as_of_date)
            d.days_remaining_to_destruction = days_rem

            if level == "CRITICAL":
                critical_count += 1
            elif level == "URGENT":
                urgent_count += 1
            elif level == "WARNING":
                warning_count += 1
            else:
                normal_count += 1

            alerts.append(
                DestructionAlertSummary(
                    reexport_id=d.reexport_id,
                    import_file_id=d.import_file_id,
                    import_file_code=d.import_file_code,
                    rejection_decree_number=d.rejection_decree_number,
                    rejection_authority=d.rejection_authority,
                    rejection_date=d.rejection_date,
                    legal_reexport_deadline=d.legal_reexport_deadline,
                    days_remaining_to_destruction=days_rem,
                    alert_level=level,
                    status=d.status,
                )
            )

        return DestructionAlertOverviewResponse(
            total_active_dossiers=len(active_dossiers),
            critical_count=critical_count,
            urgent_count=urgent_count,
            warning_count=warning_count,
            normal_count=normal_count,
            alerts=alerts,
        )
