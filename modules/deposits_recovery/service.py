"""
Business Logic & Service Layer for Refundable Deposits Ledger
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.deposits_recovery.model import RefundableDeposit
from modules.deposits_recovery.repository import RefundableDepositsRepository
from modules.deposits_recovery.schemas import (
    BankLgReleaseRequest,
    DepositRecoveryMetricsOut,
    EirReturnLinkRequest,
    RefundClaimSubmitRequest,
    RefundSettlementRequest,
    RefundableDepositCreate,
    RefundableDepositUpdate,
)
from modules.deposits_recovery.validators import (
    validate_amounts,
    validate_bank_lg_requirements,
    validate_deposit_code_unique,
    validate_eir_return_data,
)


class RefundableDepositsService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = RefundableDepositsRepository(db)

    def generate_code(self) -> str:
        current_year = datetime.now(timezone.utc).year
        seq = self.repo.get_next_sequence_number(current_year)
        return f"DEP-{current_year}-{seq:04d}"

    def list_deposits(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        deposit_type: Optional[str] = None,
        beneficiary_type: Optional[str] = None,
        recovery_status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[RefundableDeposit], int]:
        return self.repo.list_deposits(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            deposit_type=deposit_type,
            beneficiary_type=beneficiary_type,
            recovery_status=recovery_status,
            search=search,
        )

    def get_by_id(self, deposit_id: int) -> RefundableDeposit:
        item = self.repo.get_by_id(deposit_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Refundable deposit record #{deposit_id} not found.",
            )
        return item

    def create_deposit(
        self,
        data: RefundableDepositCreate,
        current_user_id: Optional[int] = None,
    ) -> RefundableDeposit:
        code = data.deposit_code or self.generate_code()
        validate_deposit_code_unique(self.repo, code)
        validate_bank_lg_requirements(data.deposit_type, data.bank_lg_number)

        deposit = RefundableDeposit(
            deposit_code=code,
            import_file_id=data.import_file_id,
            deposit_type=data.deposit_type,
            beneficiary_type=data.beneficiary_type,
            beneficiary_name=data.beneficiary_name,
            container_number=data.container_number,
            eir_number=data.eir_number,
            eir_return_date=data.eir_return_date,
            deposit_amount=data.deposit_amount,
            currency=data.currency or "EGP",
            paid_date=data.paid_date,
            payment_reference=data.payment_reference,
            bank_lg_number=data.bank_lg_number,
            bank_lg_issuing_bank=data.bank_lg_issuing_bank,
            bank_lg_expiry_date=data.bank_lg_expiry_date,
            recovery_status="PENDING",
            refunded_amount=0.0,
            deduction_amount=0.0,
            notes=data.notes,
            created_by_user_id=current_user_id,
        )

        saved = self.repo.create(deposit)
        self.db.commit()
        return saved

    def update_deposit(
        self,
        deposit_id: int,
        data: RefundableDepositUpdate,
        current_user_id: Optional[int] = None,
    ) -> RefundableDeposit:
        item = self.get_by_id(deposit_id)
        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(item, field, value)

        item.updated_at = datetime.now(timezone.utc)
        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def link_eir_return(
        self,
        deposit_id: int,
        req: EirReturnLinkRequest,
        current_user_id: Optional[int] = None,
    ) -> RefundableDeposit:
        item = self.get_by_id(deposit_id)
        validate_eir_return_data(req.container_number, req.eir_number)

        item.container_number = req.container_number
        item.eir_number = req.eir_number
        item.eir_return_date = req.eir_return_date
        if req.notes:
            prev = item.notes or ""
            item.notes = f"{prev}\n[EIR Link]: {req.notes}".strip()

        item.updated_at = datetime.now(timezone.utc)
        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def submit_claim(
        self,
        deposit_id: int,
        req: RefundClaimSubmitRequest,
        current_user_id: Optional[int] = None,
    ) -> RefundableDeposit:
        item = self.get_by_id(deposit_id)
        if item.recovery_status in ["REFUNDED", "LG_RELEASED"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot submit claim for deposit already in status {item.recovery_status}.",
            )

        item.recovery_status = "SUBMITTED"
        prev = item.notes or ""
        ref_text = f" Ref: {req.submission_reference}" if req.submission_reference else ""
        item.notes = f"{prev}\n[Claim Submitted {req.claim_submission_date}{ref_text}] {req.notes or ''}".strip()
        item.updated_at = datetime.now(timezone.utc)

        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def settle_refund(
        self,
        deposit_id: int,
        req: RefundSettlementRequest,
        current_user_id: Optional[int] = None,
    ) -> RefundableDeposit:
        item = self.get_by_id(deposit_id)
        validate_amounts(item.deposit_amount, req.refunded_amount, req.deduction_amount)

        item.refunded_amount = req.refunded_amount
        item.refund_date = req.refund_date
        item.refund_reference = req.refund_reference
        item.deduction_amount = req.deduction_amount
        item.deduction_reason = req.deduction_reason

        if req.refunded_amount > 0:
            item.recovery_status = "REFUNDED"
        elif req.deduction_amount >= item.deposit_amount:
            item.recovery_status = "FORFEITED"
        else:
            item.recovery_status = "CLAIM_APPROVED"

        if req.notes:
            prev = item.notes or ""
            item.notes = f"{prev}\n[Settlement]: {req.notes}".strip()

        item.updated_at = datetime.now(timezone.utc)
        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def release_bank_lg(
        self,
        deposit_id: int,
        req: BankLgReleaseRequest,
        current_user_id: Optional[int] = None,
    ) -> RefundableDeposit:
        item = self.get_by_id(deposit_id)
        if item.deposit_type != "BANK_LETTER_OF_GUARANTEE":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only BANK_LETTER_OF_GUARANTEE deposits can have release letters processed.",
            )

        item.recovery_status = "LG_RELEASED"
        item.refund_date = req.release_date
        item.refund_reference = req.release_letter_reference
        prev = item.notes or ""
        item.notes = f"{prev}\n[LG Released {req.release_date} - Ref: {req.release_letter_reference}] {req.notes or ''}".strip()
        item.updated_at = datetime.now(timezone.utc)

        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def delete_deposit(self, deposit_id: int) -> None:
        item = self.get_by_id(deposit_id)
        self.repo.soft_delete(item)
        self.db.commit()

    def get_metrics(self) -> DepositRecoveryMetricsOut:
        data = self.repo.get_metrics_data()
        return DepositRecoveryMetricsOut(**data)
