"""
Service for Customs Special & Suspended Duty Regimes
"""

from datetime import date
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.customs_regimes.model import CustomsSpecialRegime
from modules.customs_regimes.repository import CustomsRegimesRepository
from modules.customs_regimes.schemas import (
    CustomsRegimeCreate,
    CustomsRegimeOut,
    CustomsRegimeSettle,
    CustomsRegimeUpdate,
    RegimeStatus,
)
from modules.customs_regimes.validators import CustomsRegimesValidator


class CustomsRegimesService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CustomsRegimesRepository(db)
        self.validator = CustomsRegimesValidator()

    def _enrich(self, item: CustomsSpecialRegime) -> CustomsRegimeOut:
        data = CustomsRegimeOut.model_validate(item)
        today = date.today()

        if item.re_export_deadline:
            diff = (item.re_export_deadline - today).days
            data.days_until_re_export = diff
            data.is_expired = diff < 0 and item.status not in ("SETTLED", "CLOSED")
        else:
            data.days_until_re_export = None
            data.is_expired = False

        if item.guarantee_amount > 0 and item.status == "ACTIVE":
            if item.guarantee_expiry_date:
                data.guarantee_active = item.guarantee_expiry_date >= today
            else:
                data.guarantee_active = True
        else:
            data.guarantee_active = False

        return data

    def create_regime(self, payload: CustomsRegimeCreate, user_id: Optional[int] = None) -> CustomsRegimeOut:
        self.validator.validate_guarantee_completeness(payload.guarantee_amount, payload.guarantee_type)
        self.validator.validate_guarantee_dates(payload.guarantee_issue_date, payload.guarantee_expiry_date)
        self.validator.validate_re_export_dates(payload.release_date, payload.re_export_deadline)

        code = self.repo.generate_next_code()
        regime = CustomsSpecialRegime(
            regime_code=code,
            import_file_id=payload.import_file_id,
            shipment_id=payload.shipment_id,
            regime_type=payload.regime_type.value,
            status=payload.status.value,
            customs_office=payload.customs_office,
            release_form_number=payload.release_form_number,
            release_date=payload.release_date,
            guarantee_type=payload.guarantee_type.value if payload.guarantee_type else None,
            guarantee_reference=payload.guarantee_reference,
            guarantee_bank=payload.guarantee_bank,
            guarantee_amount=payload.guarantee_amount,
            guarantee_currency=payload.guarantee_currency,
            guarantee_issue_date=payload.guarantee_issue_date,
            guarantee_expiry_date=payload.guarantee_expiry_date,
            re_export_deadline=payload.re_export_deadline,
            actual_re_export_date=payload.actual_re_export_date,
            re_export_export_declaration_no=payload.re_export_export_declaration_no,
            drawback_reconciliation_ref=payload.drawback_reconciliation_ref,
            drawback_refund_amount=payload.drawback_refund_amount,
            reconciled_date=payload.reconciled_date,
            is_settled=payload.is_settled,
            notes=payload.notes,
            created_by_user_id=user_id,
            updated_by_user_id=user_id,
        )
        created = self.repo.create(regime)
        self.db.commit()
        self.db.refresh(created)
        return self._enrich(created)

    def get_regime(self, regime_id: int) -> CustomsRegimeOut:
        item = self.repo.get_by_id(regime_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs regime record #{regime_id} not found.",
            )
        return self._enrich(item)

    def list_regimes(
        self,
        import_file_id: Optional[int] = None,
        regime_type: Optional[str] = None,
        status_filter: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
    ) -> Tuple[List[CustomsRegimeOut], int]:
        items, total = self.repo.list_regimes(
            import_file_id=import_file_id,
            regime_type=regime_type,
            status=status_filter,
            skip=skip,
            limit=limit,
        )
        return [self._enrich(x) for x in items], total

    def update_regime(
        self,
        regime_id: int,
        payload: CustomsRegimeUpdate,
        user_id: Optional[int] = None,
    ) -> CustomsRegimeOut:
        item = self.repo.get_by_id(regime_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs regime record #{regime_id} not found.",
            )

        issue_date = payload.guarantee_issue_date if payload.guarantee_issue_date is not None else item.guarantee_issue_date
        expiry_date = payload.guarantee_expiry_date if payload.guarantee_expiry_date is not None else item.guarantee_expiry_date
        self.validator.validate_guarantee_dates(issue_date, expiry_date)

        rel_date = payload.release_date if payload.release_date is not None else item.release_date
        deadline = payload.re_export_deadline if payload.re_export_deadline is not None else item.re_export_deadline
        self.validator.validate_re_export_dates(rel_date, deadline)

        for field, value in payload.model_dump(exclude_unset=True).items():
            if hasattr(item, field):
                setattr(item, field, value.value if hasattr(value, "value") else value)

        item.updated_by_user_id = user_id
        updated = self.repo.update(item)
        self.db.commit()
        self.db.refresh(updated)
        return self._enrich(updated)

    def settle_regime(
        self,
        regime_id: int,
        payload: CustomsRegimeSettle,
        user_id: Optional[int] = None,
    ) -> CustomsRegimeOut:
        item = self.repo.get_by_id(regime_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs regime record #{regime_id} not found.",
            )

        self.validator.validate_settlement(payload, item.regime_type)

        if payload.actual_re_export_date:
            item.actual_re_export_date = payload.actual_re_export_date
        if payload.re_export_export_declaration_no:
            item.re_export_export_declaration_no = payload.re_export_export_declaration_no
        if payload.drawback_reconciliation_ref:
            item.drawback_reconciliation_ref = payload.drawback_reconciliation_ref
        if payload.drawback_refund_amount > 0:
            item.drawback_refund_amount = payload.drawback_refund_amount
        item.reconciled_date = payload.reconciled_date
        item.is_settled = True
        item.status = RegimeStatus.SETTLED.value
        if payload.notes:
            item.notes = (item.notes or "") + f"\n[Settlement]: {payload.notes}"

        item.updated_by_user_id = user_id
        updated = self.repo.update(item)
        self.db.commit()
        self.db.refresh(updated)
        return self._enrich(updated)

    def delete_regime(self, regime_id: int, user_id: Optional[int] = None) -> bool:
        item = self.repo.get_by_id(regime_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Customs regime record #{regime_id} not found.",
            )
        self.repo.soft_delete(item, user_id=user_id)
        self.db.commit()
        return True
