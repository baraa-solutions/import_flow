"""
Service for Cargo Claims, Time-Bars & Legal Reservations
"""

from datetime import date, timedelta
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.legal_claims.model import CargoClaimAndReservation
from modules.legal_claims.repository import LegalClaimsRepository
from modules.legal_claims.schemas import (
    ClaimStatus,
    DamageNature,
    LegalClaimCreate,
    LegalClaimOut,
    LegalClaimSettle,
    LegalClaimUpdate,
    ScheduleSurvey,
)
from modules.legal_claims.validators import LegalClaimsValidator


class LegalClaimsService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = LegalClaimsRepository(db)
        self.validator = LegalClaimsValidator()

    def _enrich(self, item: CargoClaimAndReservation) -> LegalClaimOut:
        data = LegalClaimOut.model_validate(item)
        today = date.today()

        days_to_bar = (item.time_bar_statute_of_limitations_date - today).days
        data.days_until_time_bar = days_to_bar
        data.is_time_barred = days_to_bar < 0 and item.status not in (ClaimStatus.SETTLED.value,)

        if days_to_bar < 0:
            data.urgency_level = "EXPIRED"
        elif days_to_bar <= 7:
            data.urgency_level = "CRITICAL_7_DAYS"
        elif days_to_bar <= 30:
            data.urgency_level = "WARNING_30_DAYS"
        else:
            data.urgency_level = "NORMAL"

        if item.latent_notice_deadline:
            diff_latent = (item.latent_notice_deadline - today).days
            data.days_until_latent_deadline = diff_latent
            data.is_latent_notice_expired = diff_latent < 0 and not item.reservation_letter_ref
        else:
            data.days_until_latent_deadline = None
            data.is_latent_notice_expired = False

        return data

    def create_claim(
        self,
        payload: LegalClaimCreate,
        user_id: Optional[int] = None,
    ) -> LegalClaimOut:
        today = date.today()
        del_date = payload.delivery_date or today

        # Egyptian Maritime Commercial Law Art. 244 & Hague-Visby Rule: 3 days for latent damage
        latent_deadline = payload.latent_notice_deadline
        if not latent_deadline and payload.damage_nature == DamageNature.LATENT:
            latent_deadline = del_date + timedelta(days=3)

        # 1-year time-bar statute of limitations
        time_bar_date = payload.time_bar_statute_of_limitations_date
        if not time_bar_date:
            time_bar_date = del_date + timedelta(days=365)

        self.validator.validate_delivery_and_time_bar(payload.delivery_date, time_bar_date)
        if payload.survey_date:
            self.validator.validate_survey(payload.survey_date, payload.delivery_date)

        code = self.repo.generate_next_code()
        item = CargoClaimAndReservation(
            claim_code=code,
            import_file_id=payload.import_file_id,
            shipment_id=payload.shipment_id,
            claim_type=payload.claim_type.value,
            damage_nature=payload.damage_nature.value,
            delivery_date=payload.delivery_date,
            latent_notice_deadline=latent_deadline,
            apparent_notice_date=payload.apparent_notice_date,
            time_bar_statute_of_limitations_date=time_bar_date,
            status=payload.status.value,
            reservation_letter_ref=payload.reservation_letter_ref,
            reservation_letter_date=payload.reservation_letter_date,
            target_party=payload.target_party,
            survey_requested=payload.survey_requested,
            survey_date=payload.survey_date,
            surveyor_company=payload.surveyor_company,
            survey_report_ref=payload.survey_report_ref,
            claimed_amount=payload.claimed_amount,
            claimed_currency=payload.claimed_currency,
            settled_amount=payload.settled_amount,
            settlement_date=payload.settlement_date,
            notes=payload.notes,
            created_by_user_id=user_id,
            updated_by_user_id=user_id,
        )
        created = self.repo.create(item)
        self.db.commit()
        self.db.refresh(created)
        return self._enrich(created)

    def get_claim(self, claim_id: int) -> LegalClaimOut:
        item = self.repo.get_by_id(claim_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cargo claim and reservation #{claim_id} not found.",
            )
        return self._enrich(item)

    def list_claims(
        self,
        import_file_id: Optional[int] = None,
        claim_type: Optional[str] = None,
        status_filter: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
    ) -> Tuple[List[LegalClaimOut], int]:
        items, total = self.repo.list_claims(
            import_file_id=import_file_id,
            claim_type=claim_type,
            status=status_filter,
            skip=skip,
            limit=limit,
        )
        return [self._enrich(x) for x in items], total

    def update_claim(
        self,
        claim_id: int,
        payload: LegalClaimUpdate,
        user_id: Optional[int] = None,
    ) -> LegalClaimOut:
        item = self.repo.get_by_id(claim_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cargo claim and reservation #{claim_id} not found.",
            )

        delivery_date = payload.delivery_date if payload.delivery_date is not None else item.delivery_date
        time_bar_date = (
            payload.time_bar_statute_of_limitations_date
            if payload.time_bar_statute_of_limitations_date is not None
            else item.time_bar_statute_of_limitations_date
        )
        self.validator.validate_delivery_and_time_bar(delivery_date, time_bar_date)

        if payload.survey_date:
            self.validator.validate_survey(payload.survey_date, delivery_date)

        for field, value in payload.model_dump(exclude_unset=True).items():
            if hasattr(item, field):
                setattr(item, field, value.value if hasattr(value, "value") else value)

        item.updated_by_user_id = user_id
        updated = self.repo.update(item)
        self.db.commit()
        self.db.refresh(updated)
        return self._enrich(updated)

    def schedule_survey(
        self,
        claim_id: int,
        payload: ScheduleSurvey,
        user_id: Optional[int] = None,
    ) -> LegalClaimOut:
        item = self.repo.get_by_id(claim_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cargo claim and reservation #{claim_id} not found.",
            )

        self.validator.validate_survey(payload.survey_date, item.delivery_date)

        item.survey_requested = True
        item.survey_date = payload.survey_date
        item.surveyor_company = payload.surveyor_company
        item.status = ClaimStatus.SURVEY_SCHEDULED.value
        if payload.notes:
            item.notes = (item.notes or "") + f"\n[Survey Scheduled]: {payload.notes}"

        item.updated_by_user_id = user_id
        updated = self.repo.update(item)
        self.db.commit()
        self.db.refresh(updated)
        return self._enrich(updated)

    def settle_claim(
        self,
        claim_id: int,
        payload: LegalClaimSettle,
        user_id: Optional[int] = None,
    ) -> LegalClaimOut:
        item = self.repo.get_by_id(claim_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cargo claim and reservation #{claim_id} not found.",
            )

        self.validator.validate_settlement(item.claimed_amount, payload.settled_amount, payload.settlement_date)

        item.settled_amount = payload.settled_amount
        item.settlement_date = payload.settlement_date
        item.status = ClaimStatus.SETTLED.value
        if payload.notes:
            item.notes = (item.notes or "") + f"\n[Settlement]: {payload.notes}"

        item.updated_by_user_id = user_id
        updated = self.repo.update(item)
        self.db.commit()
        self.db.refresh(updated)
        return self._enrich(updated)

    def delete_claim(self, claim_id: int, user_id: Optional[int] = None) -> bool:
        item = self.repo.get_by_id(claim_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cargo claim and reservation #{claim_id} not found.",
            )
        self.repo.soft_delete(item, user_id=user_id)
        self.db.commit()
        return True
