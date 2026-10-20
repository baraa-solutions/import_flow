from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from .model import ContainerDepositLedger
from .repository import ContainerDepositRepository
from .schemas import (
    ContainerDepositCreate,
    ContainerDepositUpdate,
    RecordEIRReturnRequest,
    RecordDepositRefundRequest,
    DisputeDeductionRequest,
    ContainerDepositOverviewResponse,
    OverdueDepositAlert,
)
from .validators import (
    clean_container_number,
    validate_deposit_amount,
    validate_eir_submission,
    validate_refund_submission,
)


class ContainerDepositService:
    @staticmethod
    def create_deposit(
        db: Session, payload: ContainerDepositCreate, user: str = "System"
    ) -> ContainerDepositLedger:
        validate_deposit_amount(payload.deposit_amount_egp)
        clean_num = clean_container_number(payload.container_number)

        entry = ContainerDepositLedger(
            import_file_id=payload.import_file_id,
            carrier_id=payload.carrier_id,
            carrier_name=payload.carrier_name,
            container_number=clean_num,
            container_type=payload.container_type,
            deposit_amount_egp=payload.deposit_amount_egp,
            payment_reference=payload.payment_reference,
            payment_date=payload.payment_date,
            refund_status="PENDING_RETURN",
            deduction_amount_egp=0.0,
            days_overdue=0,
            notes=payload.notes,
            dispute_history=[],
            created_by=user,
            updated_by=user,
        )
        return ContainerDepositRepository.create(db, entry)

    @staticmethod
    def get_deposit(db: Session, deposit_id: int) -> ContainerDepositLedger:
        entry = ContainerDepositRepository.get_by_id(db, deposit_id)
        if not entry or not entry.is_active:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Container deposit entry with ID {deposit_id} not found.",
            )
        entry.refresh_overdue_status()
        return entry

    @staticmethod
    def list_deposits(
        db: Session,
        include_inactive: bool = False,
        import_file_id: Optional[int] = None,
        carrier_name: Optional[str] = None,
        refund_status: Optional[str] = None,
        container_number: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[ContainerDepositLedger], int]:
        items, total = ContainerDepositRepository.list(
            db,
            include_inactive=include_inactive,
            import_file_id=import_file_id,
            carrier_name=carrier_name,
            refund_status=refund_status,
            container_number=container_number,
            skip=skip,
            limit=limit,
        )
        for item in items:
            item.refresh_overdue_status()
        return items, total

    @staticmethod
    def update_deposit(
        db: Session, deposit_id: int, payload: ContainerDepositUpdate, user: str = "System"
    ) -> ContainerDepositLedger:
        entry = ContainerDepositService.get_deposit(db, deposit_id)
        update_data = payload.model_dump(exclude_unset=True)

        if "deposit_amount_egp" in update_data and update_data["deposit_amount_egp"] is not None:
            validate_deposit_amount(update_data["deposit_amount_egp"])
            entry.deposit_amount_egp = update_data["deposit_amount_egp"]

        if "container_number" in update_data and update_data["container_number"] is not None:
            entry.container_number = clean_container_number(update_data["container_number"])

        for field in [
            "carrier_id",
            "carrier_name",
            "container_type",
            "payment_reference",
            "payment_date",
            "eir_return_number",
            "eir_return_date",
            "deduction_amount_egp",
            "refund_cheque_or_transfer_no",
            "refund_received_date",
            "notes",
        ]:
            if field in update_data and update_data[field] is not None:
                setattr(entry, field, update_data[field])

        if "container_condition" in update_data and update_data["container_condition"] is not None:
            val = update_data["container_condition"]
            entry.container_condition = val.value if hasattr(val, "value") else str(val)

        if "refund_status" in update_data and update_data["refund_status"] is not None:
            val = update_data["refund_status"]
            entry.refund_status = val.value if hasattr(val, "value") else str(val)

        entry.refresh_overdue_status()
        entry.updated_by = user
        entry.updated_at = datetime.now(timezone.utc)
        return ContainerDepositRepository.update(db, entry)

    @staticmethod
    def soft_delete_deposit(db: Session, deposit_id: int, user: str = "System") -> ContainerDepositLedger:
        entry = ContainerDepositService.get_deposit(db, deposit_id)
        return ContainerDepositRepository.soft_delete(db, deposit_id, user)

    @staticmethod
    def record_eir_return(
        db: Session, deposit_id: int, req: RecordEIRReturnRequest, user: str = "System"
    ) -> ContainerDepositLedger:
        entry = ContainerDepositService.get_deposit(db, deposit_id)
        
        condition_str = req.container_condition.value if hasattr(req.container_condition, "value") else str(req.container_condition)
        validate_eir_submission(
            req.eir_return_number,
            req.eir_return_date,
            entry.payment_date,
            condition_str,
            req.deduction_amount_egp,
            entry.deposit_amount_egp,
        )

        entry.eir_return_number = req.eir_return_number.strip()
        entry.eir_return_date = req.eir_return_date
        entry.container_condition = condition_str
        entry.deduction_amount_egp = req.deduction_amount_egp
        entry.refund_status = "CLAIM_SUBMITTED"

        if req.deduction_reason:
            if not entry.notes:
                entry.notes = f"EIR Note: {req.deduction_reason}"
            else:
                entry.notes += f" | EIR Note: {req.deduction_reason}"

        entry.refresh_overdue_status()
        entry.updated_by = user
        entry.updated_at = datetime.now(timezone.utc)
        return ContainerDepositRepository.update(db, entry)

    @staticmethod
    def record_refund(
        db: Session, deposit_id: int, req: RecordDepositRefundRequest, user: str = "System"
    ) -> ContainerDepositLedger:
        entry = ContainerDepositService.get_deposit(db, deposit_id)
        
        validate_refund_submission(
            req.refund_amount_egp,
            entry.deposit_amount_egp,
            entry.deduction_amount_egp,
            req.refund_received_date,
            entry.eir_return_date,
        )

        entry.refund_cheque_or_transfer_no = req.refund_cheque_or_transfer_no.strip()
        entry.refund_received_date = req.refund_received_date

        if entry.deduction_amount_egp == 0.0 and abs(req.refund_amount_egp - entry.deposit_amount_egp) < 0.01:
            entry.refund_status = "REFUNDED_FULL"
        else:
            entry.refund_status = "REFUNDED_PARTIAL"

        entry.days_overdue = 0
        entry.updated_by = user
        entry.updated_at = datetime.now(timezone.utc)
        return ContainerDepositRepository.update(db, entry)

    @staticmethod
    def dispute_deduction(
        db: Session, deposit_id: int, req: DisputeDeductionRequest, user: str = "System"
    ) -> ContainerDepositLedger:
        entry = ContainerDepositService.get_deposit(db, deposit_id)
        
        dispute_log = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "user": user,
            "dispute_reason": req.dispute_reason,
            "original_deduction_egp": entry.deduction_amount_egp,
            "waived": req.waived,
            "revised_deduction_egp": 0.0 if req.waived else req.revised_deduction_amount_egp,
        }

        # Handle history list safely
        current_history = list(entry.dispute_history or [])
        current_history.append(dispute_log)
        entry.dispute_history = current_history

        if req.waived:
            entry.deduction_amount_egp = 0.0
            entry.container_condition = "SOUND_CLEAN"
        elif req.revised_deduction_amount_egp is not None:
            if req.revised_deduction_amount_egp > entry.deposit_amount_egp:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Revised deduction cannot exceed deposit amount.",
                )
            entry.deduction_amount_egp = req.revised_deduction_amount_egp

        entry.updated_by = user
        entry.updated_at = datetime.now(timezone.utc)
        return ContainerDepositRepository.update(db, entry)

    @staticmethod
    def get_overview_and_alerts(
        db: Session, as_of_date: Optional[date] = None
    ) -> ContainerDepositOverviewResponse:
        all_active = ContainerDepositRepository.get_all_active(db)

        total_deposit_egp = 0.0
        pending_return_count = 0
        claim_submitted_count = 0
        overdue_30_days_count = 0
        overdue_deposit_egp = 0.0
        refunded_full_count = 0
        refunded_partial_count = 0
        total_refunded_egp = 0.0
        total_deductions_egp = 0.0

        alerts: List[OverdueDepositAlert] = []
        carrier_stats: Dict[str, Dict[str, Any]] = {}

        for item in all_active:
            item.refresh_overdue_status(as_of_date)
            total_deposit_egp += item.deposit_amount_egp
            total_deductions_egp += item.deduction_amount_egp

            # Carrier breakdown initialization
            c_name = item.carrier_name or "Unknown Carrier"
            if c_name not in carrier_stats:
                carrier_stats[c_name] = {
                    "total_containers": 0,
                    "total_deposit_egp": 0.0,
                    "overdue_count": 0,
                    "overdue_amount_egp": 0.0,
                }
            carrier_stats[c_name]["total_containers"] += 1
            carrier_stats[c_name]["total_deposit_egp"] += item.deposit_amount_egp

            if item.refund_status == "PENDING_RETURN":
                pending_return_count += 1
            elif item.refund_status == "CLAIM_SUBMITTED":
                claim_submitted_count += 1
            elif item.refund_status == "OVERDUE_30_DAYS":
                overdue_30_days_count += 1
                overdue_deposit_egp += item.deposit_amount_egp
                carrier_stats[c_name]["overdue_count"] += 1
                carrier_stats[c_name]["overdue_amount_egp"] += item.deposit_amount_egp
                alerts.append(
                    OverdueDepositAlert(
                        deposit_id=item.deposit_id,
                        import_file_id=item.import_file_id,
                        carrier_name=item.carrier_name,
                        container_number=item.container_number,
                        container_type=item.container_type,
                        deposit_amount_egp=item.deposit_amount_egp,
                        eir_return_number=item.eir_return_number,
                        eir_return_date=item.eir_return_date,
                        days_overdue=item.days_overdue,
                        refund_status=item.refund_status,
                    )
                )
            elif item.refund_status == "REFUNDED_FULL":
                refunded_full_count += 1
                total_refunded_egp += item.deposit_amount_egp
            elif item.refund_status == "REFUNDED_PARTIAL":
                refunded_partial_count += 1
                total_refunded_egp += (item.deposit_amount_egp - item.deduction_amount_egp)

        # Sort alerts descending by days_overdue
        alerts.sort(key=lambda a: a.days_overdue, reverse=True)

        return ContainerDepositOverviewResponse(
            total_active_deposits=len(all_active),
            total_deposit_amount_egp=total_deposit_egp,
            pending_return_count=pending_return_count,
            claim_submitted_count=claim_submitted_count,
            overdue_30_days_count=overdue_30_days_count,
            overdue_deposit_amount_egp=overdue_deposit_egp,
            refunded_full_count=refunded_full_count,
            refunded_partial_count=refunded_partial_count,
            total_refunded_amount_egp=total_refunded_egp,
            total_deductions_egp=total_deductions_egp,
            carrier_breakdown=carrier_stats,
            alerts=alerts,
        )
