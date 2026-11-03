"""
Service for Preferential Trade Agreements & Origin Verifications
"""

from datetime import date, timedelta
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.trade_agreements.model import PreferentialOriginVerification
from modules.trade_agreements.repository import TradeAgreementsRepository
from modules.trade_agreements.schemas import (
    SubmissionStatus,
    TradeAgreementCreate,
    TradeAgreementOut,
    TradeAgreementUpdate,
    TradeAgreementVerifyOriginal,
)
from modules.trade_agreements.validators import TradeAgreementsValidator


class TradeAgreementsService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = TradeAgreementsRepository(db)
        self.validator = TradeAgreementsValidator()

    @staticmethod
    def _calculate_default_expiry(issuing_date: date, validity_months: int) -> date:
        # Approximate 30.5 days per month
        days = int(validity_months * 30.5)
        return issuing_date + timedelta(days=days)

    def _enrich(self, item: PreferentialOriginVerification) -> TradeAgreementOut:
        data = TradeAgreementOut.model_validate(item)
        today = date.today()

        if item.expiry_date:
            diff_exp = (item.expiry_date - today).days
            data.days_until_expiry = diff_exp
            data.is_cert_expired = diff_exp < 0 and item.submission_status not in (
                SubmissionStatus.ORIGINAL_SUBMITTED.value,
                SubmissionStatus.VERIFIED_ELECTRONICALLY.value,
            )
        else:
            data.days_until_expiry = None
            data.is_cert_expired = False

        if item.provisional_escrow_required and not item.provisional_escrow_refunded:
            if item.provisional_escrow_deadline:
                diff_esc = (item.provisional_escrow_deadline - today).days
                data.days_until_escrow_deadline = diff_esc
                data.is_escrow_at_risk = diff_esc <= 15
            else:
                data.days_until_escrow_deadline = None
                data.is_escrow_at_risk = False
        else:
            data.days_until_escrow_deadline = None
            data.is_escrow_at_risk = False

        return data

    def create_verification(
        self,
        payload: TradeAgreementCreate,
        user_id: Optional[int] = None,
    ) -> TradeAgreementOut:
        expiry = payload.expiry_date
        if not expiry:
            expiry = self._calculate_default_expiry(payload.issuing_date, payload.validity_months)

        self.validator.validate_dates(payload.issuing_date, expiry)
        self.validator.validate_escrow(
            payload.provisional_escrow_required,
            payload.provisional_escrow_amount,
            payload.provisional_escrow_deadline,
            payload.issuing_date,
        )

        sub_status = payload.submission_status.value
        has_orig = payload.has_original_received
        if has_orig and sub_status == SubmissionStatus.COPY_SUBMITTED.value:
            sub_status = SubmissionStatus.ORIGINAL_SUBMITTED.value

        code = self.repo.generate_next_code()
        item = PreferentialOriginVerification(
            verification_code=code,
            import_file_id=payload.import_file_id,
            shipment_id=payload.shipment_id,
            agreement_name=payload.agreement_name.value,
            certificate_type=payload.certificate_type.value,
            certificate_number=payload.certificate_number,
            issuing_country=payload.issuing_country,
            issuing_authority=payload.issuing_authority,
            issuing_date=payload.issuing_date,
            validity_months=payload.validity_months,
            expiry_date=expiry,
            submission_status=sub_status,
            has_original_received=has_orig,
            original_received_date=payload.original_received_date,
            provisional_escrow_required=payload.provisional_escrow_required,
            provisional_escrow_amount=payload.provisional_escrow_amount,
            provisional_escrow_receipt=payload.provisional_escrow_receipt,
            provisional_escrow_deadline=payload.provisional_escrow_deadline,
            provisional_escrow_refunded=payload.provisional_escrow_refunded,
            refund_date=payload.refund_date,
            direct_transport_compliant=payload.direct_transport_compliant,
            rules_of_origin_criterion=payload.rules_of_origin_criterion.value if payload.rules_of_origin_criterion else None,
            verification_notes=payload.verification_notes,
            created_by_user_id=user_id,
            updated_by_user_id=user_id,
        )
        created = self.repo.create(item)
        self.db.commit()
        self.db.refresh(created)
        return self._enrich(created)

    def get_verification(self, item_id: int) -> TradeAgreementOut:
        item = self.repo.get_by_id(item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Preferential origin verification #{item_id} not found.",
            )
        return self._enrich(item)

    def list_verifications(
        self,
        import_file_id: Optional[int] = None,
        agreement_name: Optional[str] = None,
        submission_status: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
    ) -> Tuple[List[TradeAgreementOut], int]:
        items, total = self.repo.list_verifications(
            import_file_id=import_file_id,
            agreement_name=agreement_name,
            submission_status=submission_status,
            skip=skip,
            limit=limit,
        )
        return [self._enrich(x) for x in items], total

    def update_verification(
        self,
        item_id: int,
        payload: TradeAgreementUpdate,
        user_id: Optional[int] = None,
    ) -> TradeAgreementOut:
        item = self.repo.get_by_id(item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Preferential origin verification #{item_id} not found.",
            )

        issuing_date = payload.issuing_date if payload.issuing_date is not None else item.issuing_date
        expiry_date = payload.expiry_date if payload.expiry_date is not None else item.expiry_date
        self.validator.validate_dates(issuing_date, expiry_date)

        escrow_req = payload.provisional_escrow_required if payload.provisional_escrow_required is not None else item.provisional_escrow_required
        escrow_amt = payload.provisional_escrow_amount if payload.provisional_escrow_amount is not None else item.provisional_escrow_amount
        escrow_deadline = payload.provisional_escrow_deadline if payload.provisional_escrow_deadline is not None else item.provisional_escrow_deadline
        self.validator.validate_escrow(escrow_req, escrow_amt, escrow_deadline, issuing_date)

        for field, value in payload.model_dump(exclude_unset=True).items():
            if hasattr(item, field):
                setattr(item, field, value.value if hasattr(value, "value") else value)

        item.updated_by_user_id = user_id
        updated = self.repo.update(item)
        self.db.commit()
        self.db.refresh(updated)
        return self._enrich(updated)

    def verify_original(
        self,
        item_id: int,
        payload: TradeAgreementVerifyOriginal,
        user_id: Optional[int] = None,
    ) -> TradeAgreementOut:
        item = self.repo.get_by_id(item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Preferential origin verification #{item_id} not found.",
            )

        self.validator.validate_original_verification(
            payload.original_received_date,
            item.issuing_date,
            payload.provisional_escrow_refunded,
            payload.refund_date,
        )

        item.has_original_received = True
        item.original_received_date = payload.original_received_date
        item.submission_status = SubmissionStatus.ORIGINAL_SUBMITTED.value
        item.provisional_escrow_refunded = payload.provisional_escrow_refunded
        if payload.refund_date:
            item.refund_date = payload.refund_date
        if payload.verification_notes:
            item.verification_notes = (item.verification_notes or "") + f"\n[Original Verified]: {payload.verification_notes}"

        item.updated_by_user_id = user_id
        updated = self.repo.update(item)
        self.db.commit()
        self.db.refresh(updated)
        return self._enrich(updated)

    def delete_verification(self, item_id: int, user_id: Optional[int] = None) -> bool:
        item = self.repo.get_by_id(item_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Preferential origin verification #{item_id} not found.",
            )
        self.repo.soft_delete(item, user_id=user_id)
        self.db.commit()
        return True
