"""
Database Repository for Refundable Deposits Ledger
"""

from typing import List, Optional, Tuple
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from modules.deposits_recovery.model import RefundableDeposit


class RefundableDepositsRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, deposit_id: int) -> Optional[RefundableDeposit]:
        return (
            self.db.query(RefundableDeposit)
            .filter(RefundableDeposit.id == deposit_id, RefundableDeposit.is_deleted == False)
            .first()
        )

    def get_by_code(self, code: str) -> Optional[RefundableDeposit]:
        return (
            self.db.query(RefundableDeposit)
            .filter(RefundableDeposit.deposit_code == code, RefundableDeposit.is_deleted == False)
            .first()
        )

    def list_deposits(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        deposit_type: Optional[str] = None,
        beneficiary_type: Optional[str] = None,
        recovery_status: Optional[str] = None,
        search: Optional[str] = None,
        include_deleted: bool = False,
    ) -> Tuple[List[RefundableDeposit], int]:
        query = self.db.query(RefundableDeposit)
        if not include_deleted:
            query = query.filter(RefundableDeposit.is_deleted == False)

        if import_file_id is not None:
            query = query.filter(RefundableDeposit.import_file_id == import_file_id)

        if deposit_type:
            query = query.filter(RefundableDeposit.deposit_type == deposit_type)

        if beneficiary_type:
            query = query.filter(RefundableDeposit.beneficiary_type == beneficiary_type)

        if recovery_status:
            query = query.filter(RefundableDeposit.recovery_status == recovery_status)

        if search:
            s = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    RefundableDeposit.deposit_code.ilike(s),
                    RefundableDeposit.beneficiary_name.ilike(s),
                    RefundableDeposit.container_number.ilike(s),
                    RefundableDeposit.eir_number.ilike(s),
                    RefundableDeposit.bank_lg_number.ilike(s),
                )
            )

        total = query.count()
        items = query.order_by(RefundableDeposit.created_at.desc()).offset(skip).limit(limit).all()
        return items, total

    def create(self, deposit: RefundableDeposit) -> RefundableDeposit:
        self.db.add(deposit)
        self.db.flush()
        self.db.refresh(deposit)
        return deposit

    def update(self, deposit: RefundableDeposit) -> RefundableDeposit:
        self.db.flush()
        self.db.refresh(deposit)
        return deposit

    def soft_delete(self, deposit: RefundableDeposit) -> None:
        deposit.is_deleted = True
        deposit.is_active = False
        self.db.flush()

    def get_next_sequence_number(self, year: int) -> int:
        prefix = f"DEP-{year}-"
        count = (
            self.db.query(func.count(RefundableDeposit.id))
            .filter(RefundableDeposit.deposit_code.like(f"{prefix}%"))
            .scalar()
            or 0
        )
        return count + 1

    def get_metrics_data(self) -> dict:
        base_query = self.db.query(RefundableDeposit).filter(RefundableDeposit.is_deleted == False)
        total_count = base_query.count()

        pending_items = base_query.filter(
            RefundableDeposit.recovery_status.in_(["PENDING", "SUBMITTED", "CLAIM_APPROVED"])
        )
        pending_count = pending_items.count()

        pending_amt = (
            self.db.query(
                func.coalesce(
                    func.sum(RefundableDeposit.deposit_amount - RefundableDeposit.refunded_amount - RefundableDeposit.deduction_amount),
                    0.0,
                )
            )
            .filter(
                RefundableDeposit.is_deleted == False,
                RefundableDeposit.recovery_status.in_(["PENDING", "SUBMITTED", "CLAIM_APPROVED"]),
            )
            .scalar()
        )

        recovered_amt = (
            self.db.query(func.coalesce(func.sum(RefundableDeposit.refunded_amount), 0.0))
            .filter(RefundableDeposit.is_deleted == False)
            .scalar()
        )

        deductions_amt = (
            self.db.query(func.coalesce(func.sum(RefundableDeposit.deduction_amount), 0.0))
            .filter(RefundableDeposit.is_deleted == False)
            .scalar()
        )

        active_lg = base_query.filter(
            RefundableDeposit.deposit_type == "BANK_LETTER_OF_GUARANTEE",
            RefundableDeposit.recovery_status != "LG_RELEASED",
        ).count()

        carrier_deposits = base_query.filter(
            RefundableDeposit.deposit_type == "SHIPPING_LINE_CONTAINER"
        ).count()

        return {
            "total_deposits_count": total_count,
            "pending_recovery_count": pending_count,
            "pending_recovery_amount_egp": float(pending_amt or 0.0),
            "recovered_amount_egp": float(recovered_amt or 0.0),
            "total_deductions_egp": float(deductions_amt or 0.0),
            "active_bank_lg_count": active_lg,
            "carrier_deposits_count": carrier_deposits,
        }
