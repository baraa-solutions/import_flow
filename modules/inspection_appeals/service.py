from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common.validators import validate_foreign_key
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.import_files.model import ImportFile
from modules.inspection_appeals.model import InspectionAppeal
from modules.inspection_appeals.repository import InspectionAppealRepository
from modules.inspection_appeals.schemas import (
    AppealCommitteeDecisionSubmit,
    AppealTierProgression,
    InspectionAppealCreate,
    InspectionAppealUpdate,
    TriplicateLabAssignSubmit,
)
from modules.inspection_appeals.validators import (
    validate_appeal_create,
    validate_appeal_result,
    validate_appeal_tier,
    validate_committee_decision,
    validate_initial_test_result,
    validate_regulatory_authority,
    validate_tier_progression,
)


class InspectionAppealService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = InspectionAppealRepository(db)

    def create_appeal(self, payload: InspectionAppealCreate, current_user: str = "system") -> InspectionAppeal:
        validate_appeal_create(payload)

        # Ensure parent entities exist
        validate_foreign_key(self.db, ImportFile, payload.import_file_id, "import_file_id", "ملف الاستيراد")
        if payload.clearance_id is not None:
            validate_foreign_key(
                self.db,
                CustomsClearanceRecord,
                payload.clearance_id,
                "customs_clearance_id",
                "سجل التخليص الجمركي",
            )

        appeal_code = self.repo.generate_next_appeal_code()
        now = datetime.now(timezone.utc)

        appeal = InspectionAppeal(
            appeal_code=appeal_code,
            import_file_id=payload.import_file_id,
            clearance_id=payload.clearance_id,
            regulatory_authority=payload.regulatory_authority,
            sample_number=payload.sample_number,
            sample_draw_date=payload.sample_draw_date,
            initial_test_result=payload.initial_test_result,
            rejection_reason=payload.rejection_reason,
            appeal_tier=payload.appeal_tier,
            appeal_submission_date=payload.appeal_submission_date or now,
            appeal_committee_date=payload.appeal_committee_date,
            triplicate_lab_assigned=payload.triplicate_lab_assigned,
            appeal_result="PENDING",
            official_letter_ref=payload.official_letter_ref,
            notes=payload.notes,
            created_at=now,
            created_by=current_user,
            updated_at=now,
            updated_by=current_user,
            is_active=True,
        )

        created = self.repo.add(appeal)
        self.db.commit()
        self.db.refresh(created)
        return created

    def get_appeal(self, appeal_id: int, include_inactive: bool = False) -> InspectionAppeal:
        appeal = self.repo.get_by_id(appeal_id, include_inactive=include_inactive)
        if not appeal:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"طلب التظلم رقم {appeal_id} غير موجود.",
            )
        return appeal

    def list_appeals(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        clearance_id: Optional[int] = None,
        regulatory_authority: Optional[str] = None,
        appeal_tier: Optional[str] = None,
        appeal_result: Optional[str] = None,
        include_inactive: bool = False,
    ) -> Tuple[List[InspectionAppeal], int]:
        return self.repo.list_appeals(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            clearance_id=clearance_id,
            regulatory_authority=regulatory_authority,
            appeal_tier=appeal_tier,
            appeal_result=appeal_result,
            include_inactive=include_inactive,
        )

    def update_appeal(
        self,
        appeal_id: int,
        payload: InspectionAppealUpdate,
        current_user: str = "system",
    ) -> InspectionAppeal:
        appeal = self.get_appeal(appeal_id)
        update_data = payload.model_dump(exclude_unset=True)

        if "regulatory_authority" in update_data and update_data["regulatory_authority"]:
            validate_regulatory_authority(update_data["regulatory_authority"])
        if "initial_test_result" in update_data and update_data["initial_test_result"]:
            validate_initial_test_result(update_data["initial_test_result"])
        if "appeal_tier" in update_data and update_data["appeal_tier"]:
            validate_appeal_tier(update_data["appeal_tier"])
        if "appeal_result" in update_data and update_data["appeal_result"]:
            validate_appeal_result(update_data["appeal_result"])
        if "clearance_id" in update_data and update_data["clearance_id"] is not None:
            validate_foreign_key(
                self.db,
                CustomsClearanceRecord,
                update_data["clearance_id"],
                "customs_clearance_id",
                "سجل التخليص الجمركي",
            )

        for key, value in update_data.items():
            setattr(appeal, key, value)

        appeal.updated_at = datetime.now(timezone.utc)
        appeal.updated_by = current_user

        updated = self.repo.update(appeal)
        self.db.commit()
        self.db.refresh(updated)
        return updated

    def progress_tier(
        self,
        appeal_id: int,
        payload: AppealTierProgression,
        current_user: str = "system",
    ) -> InspectionAppeal:
        appeal = self.get_appeal(appeal_id)
        validate_tier_progression(
            current_tier=appeal.appeal_tier,
            target_tier=payload.target_tier,
            triplicate_lab_assigned=payload.triplicate_lab_assigned,
            current_result=appeal.appeal_result,
        )

        appeal.appeal_tier = payload.target_tier
        if payload.triplicate_lab_assigned:
            appeal.triplicate_lab_assigned = payload.triplicate_lab_assigned
        if payload.official_letter_ref:
            appeal.official_letter_ref = payload.official_letter_ref
        if payload.notes:
            formatted_note = f"[تصعيد إلى {payload.target_tier}]: {payload.notes}"
            appeal.notes = f"{appeal.notes}\n{formatted_note}" if appeal.notes else formatted_note

        appeal.appeal_result = "PENDING"
        appeal.updated_at = datetime.now(timezone.utc)
        appeal.updated_by = current_user

        updated = self.repo.update(appeal)
        self.db.commit()
        self.db.refresh(updated)
        return updated

    def record_committee_decision(
        self,
        appeal_id: int,
        payload: AppealCommitteeDecisionSubmit,
        current_user: str = "system",
    ) -> InspectionAppeal:
        appeal = self.get_appeal(appeal_id)
        validate_committee_decision(payload)

        appeal.appeal_result = payload.appeal_result
        if payload.appeal_committee_date:
            appeal.appeal_committee_date = payload.appeal_committee_date
        else:
            appeal.appeal_committee_date = datetime.now(timezone.utc)
        if payload.official_letter_ref:
            appeal.official_letter_ref = payload.official_letter_ref
        if payload.notes:
            formatted_note = f"[قرار اللجنة - {payload.appeal_result}]: {payload.notes}"
            appeal.notes = f"{appeal.notes}\n{formatted_note}" if appeal.notes else formatted_note

        appeal.updated_at = datetime.now(timezone.utc)
        appeal.updated_by = current_user

        updated = self.repo.update(appeal)
        self.db.commit()
        self.db.refresh(updated)
        return updated

    def assign_triplicate_lab(
        self,
        appeal_id: int,
        payload: TriplicateLabAssignSubmit,
        current_user: str = "system",
    ) -> InspectionAppeal:
        appeal = self.get_appeal(appeal_id)

        appeal.triplicate_lab_assigned = payload.triplicate_lab_assigned
        if payload.official_letter_ref:
            appeal.official_letter_ref = payload.official_letter_ref
        if payload.notes:
            formatted_note = f"[إحالة للمعمل المحايد {payload.triplicate_lab_assigned}]: {payload.notes}"
            appeal.notes = f"{appeal.notes}\n{formatted_note}" if appeal.notes else formatted_note

        appeal.updated_at = datetime.now(timezone.utc)
        appeal.updated_by = current_user

        updated = self.repo.update(appeal)
        self.db.commit()
        self.db.refresh(updated)
        return updated

    def soft_delete(self, appeal_id: int, current_user: str = "system") -> None:
        appeal = self.get_appeal(appeal_id)
        self.repo.soft_delete(appeal, current_user=current_user)
        self.db.commit()

    def restore(self, appeal_id: int, current_user: str = "system") -> InspectionAppeal:
        appeal = self.get_appeal(appeal_id, include_inactive=True)
        self.repo.restore(appeal, current_user=current_user)
        self.db.commit()
        self.db.refresh(appeal)
        return appeal
