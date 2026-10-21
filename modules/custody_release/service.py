from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common.validators import validate_foreign_key
from modules.custody_release.model import CustodyReleaseDossier
from modules.custody_release.repository import CustodyReleaseRepository
from modules.custody_release.schemas import (
    CustodyBreachReportSubmit,
    CustodyFinalClearanceSubmit,
    CustodyReleaseDossierCreate,
    CustodyReleaseDossierUpdate,
    CustodyWarehouseFreezeSubmit,
    WarehouseDispenseValidationResult,
)
from modules.custody_release.validators import (
    validate_breach_report,
    validate_custody_create,
    validate_dispense_attempt,
    validate_final_clearance,
)
from modules.import_files.model import ImportFile


class CustodyReleaseService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = CustodyReleaseRepository(db)

    def create_dossier(
        self,
        payload: CustodyReleaseDossierCreate,
        current_user: str = "system",
    ) -> CustodyReleaseDossier:
        validate_custody_create(payload)

        # Validate parent ImportFile exists
        validate_foreign_key(self.db, ImportFile, payload.import_file_id, "import_file_id", "ملف الاستيراد")

        # Check unique undertaking number
        existing = self.repo.get_by_undertaking_number(payload.custody_undertaking_number.strip())
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"رقم إقرار / تعهد التحفظ الجمركي ({payload.custody_undertaking_number}) مسجل بالفعل بالملف رقم {existing.custody_code}.",
            )

        custody_code = self.repo.generate_next_custody_code()
        now = datetime.now(timezone.utc)

        dossier = CustodyReleaseDossier(
            custody_code=custody_code,
            import_file_id=payload.import_file_id,
            warehouse_id=payload.warehouse_id,
            warehouse_address=payload.warehouse_address,
            custody_undertaking_number=payload.custody_undertaking_number.strip(),
            judicial_officer_name=payload.judicial_officer_name,
            lead_seals_count=payload.lead_seals_count,
            lead_seal_numbers=payload.lead_seal_numbers,
            transport_permit_number=payload.transport_permit_number,
            status=payload.status,
            lock_active=payload.lock_active,
            notes=payload.notes,
            created_at=now,
            created_by=current_user,
            updated_at=now,
            updated_by=current_user,
            is_active=True,
        )

        created = self.repo.add(dossier)
        self.db.commit()
        self.db.refresh(created)
        return created

    def get_dossier(self, custody_id: int, include_inactive: bool = False) -> CustodyReleaseDossier:
        dossier = self.repo.get_by_id(custody_id, include_inactive=include_inactive)
        if not dossier:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"ملف التحفظ الجمركي رقم {custody_id} غير موجود.",
            )
        return dossier

    def list_dossiers(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        warehouse_id: Optional[int] = None,
        status_filter: Optional[str] = None,
        lock_active: Optional[bool] = None,
        include_inactive: bool = False,
    ) -> Tuple[List[CustodyReleaseDossier], int]:
        return self.repo.list_dossiers(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            warehouse_id=warehouse_id,
            status=status_filter,
            lock_active=lock_active,
            include_inactive=include_inactive,
        )

    def update_dossier(
        self,
        custody_id: int,
        payload: CustodyReleaseDossierUpdate,
        current_user: str = "system",
    ) -> CustodyReleaseDossier:
        dossier = self.get_dossier(custody_id)
        update_data = payload.model_dump(exclude_unset=True)

        for key, value in update_data.items():
            setattr(dossier, key, value)

        dossier.updated_at = datetime.now(timezone.utc)
        dossier.updated_by = current_user

        updated = self.repo.update(dossier)
        self.db.commit()
        self.db.refresh(updated)
        return updated

    def freeze_in_warehouse(
        self,
        custody_id: int,
        payload: CustodyWarehouseFreezeSubmit,
        current_user: str = "system",
    ) -> CustodyReleaseDossier:
        """
        Confirms cargo arrival and sets status to FROZEN_IN_WAREHOUSE,
        enforcing active warehouse lock.
        """
        dossier = self.get_dossier(custody_id)

        dossier.status = "FROZEN_IN_WAREHOUSE"
        dossier.lock_active = True
        if payload.warehouse_address:
            dossier.warehouse_address = payload.warehouse_address
        if payload.notes:
            formatted_note = f"[Warehouse freeze and custody hold]: {payload.notes}"
            dossier.notes = f"{dossier.notes}\n{formatted_note}" if dossier.notes else formatted_note

        dossier.updated_at = datetime.now(timezone.utc)
        dossier.updated_by = current_user

        updated = self.repo.update(dossier)
        self.db.commit()
        self.db.refresh(updated)
        return updated

    def approve_final_clearance(
        self,
        custody_id: int,
        payload: CustodyFinalClearanceSubmit,
        current_user: str = "system",
    ) -> CustodyReleaseDossier:
        """
        Releases the under-custody lock once final laboratory and customs clearance is confirmed.
        Unlocks warehouse dispensing.
        """
        dossier = self.get_dossier(custody_id)
        validate_final_clearance(payload)

        if dossier.status == "BREACH_REPORTED":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="لا يمكن فك التحفظ والإفراج النهائي: تم تسجيل مخالفة سابقة على الملف وتتطلب تسوية قضائية وقانونية مسبقة.",
            )

        dossier.status = "SAMPLE_CLEAR_FINAL_RELEASE"
        dossier.lock_active = False  # Lock released!
        dossier.final_clearance_letter_number = payload.final_clearance_letter_number.strip()
        dossier.release_approved_at = payload.release_approved_at or datetime.now(timezone.utc)

        if payload.notes:
            formatted_note = f"[Final release and match]: {payload.notes}"
            dossier.notes = f"{dossier.notes}\n{formatted_note}" if dossier.notes else formatted_note

        dossier.updated_at = datetime.now(timezone.utc)
        dossier.updated_by = current_user

        updated = self.repo.update(dossier)
        self.db.commit()
        self.db.refresh(updated)
        return updated

    def report_breach(
        self,
        custody_id: int,
        payload: CustodyBreachReportSubmit,
        current_user: str = "system",
    ) -> CustodyReleaseDossier:
        """
        Reports breach of lead seals, unauthorized cargo tampering, or unauthorized movement.
        Enforces strict block.
        """
        dossier = self.get_dossier(custody_id)
        validate_breach_report(payload)

        dossier.status = "BREACH_REPORTED"
        dossier.lock_active = True
        dossier.breach_reason = payload.breach_reason.strip()

        formatted_note = f"[Breach and seizure report]: {payload.breach_reason}"
        if payload.notes:
            formatted_note += f" | {payload.notes}"
        dossier.notes = f"{dossier.notes}\n{formatted_note}" if dossier.notes else formatted_note

        dossier.updated_at = datetime.now(timezone.utc)
        dossier.updated_by = current_user

        updated = self.repo.update(dossier)
        self.db.commit()
        self.db.refresh(updated)
        return updated

    def validate_warehouse_dispense(self, import_file_id: int) -> WarehouseDispenseValidationResult:
        """
        Checks whether warehouse goods can be physically dispatched or dispensed.
        Returns validation result indicating whether dispensing is allowed or blocked.
        """
        locked_dossier = self.repo.get_active_locked_for_file(import_file_id)
        if locked_dossier:
            if locked_dossier.status == "BREACH_REPORTED":
                return WarehouseDispenseValidationResult(
                    is_allowed=False,
                    lock_active=True,
                    status=locked_dossier.status,
                    message=f"صرف البضاعة محظور: تم الإبلاغ عن مخالفة فض أختام أو خرق للتحفظ الجمركي على الملف ({locked_dossier.custody_code}).",
                    custody_id=locked_dossier.custody_id,
                    custody_undertaking_number=locked_dossier.custody_undertaking_number,
                )
            return WarehouseDispenseValidationResult(
                is_allowed=False,
                lock_active=True,
                status=locked_dossier.status,
                message=f"صرف البضاعة من المستودع محظور قطعيًا: الشحنة خاضعة للإفراج المؤقت تحت التحفظ بموجب التعهد رقم ({locked_dossier.custody_undertaking_number}) ومغلقة بالرصاص الجمركي لحين صدور الإفراج النهائي.",
                custody_id=locked_dossier.custody_id,
                custody_undertaking_number=locked_dossier.custody_undertaking_number,
            )

        return WarehouseDispenseValidationResult(
            is_allowed=True,
            lock_active=False,
            status="CLEARED",
            message="صرف البضاعة من المستودع مصرّح به: لا توجد أي قيود أو تحفظ جمركي نشط على هذه الشحنة.",
            custody_id=None,
            custody_undertaking_number=None,
        )

    def enforce_dispense_check(self, import_file_id: int) -> None:
        """
        Raises HTTPException if warehouse dispensing is blocked.
        Used by warehouse dispatch / delivery note services.
        """
        locked_dossier = self.repo.get_active_locked_for_file(import_file_id)
        if locked_dossier:
            validate_dispense_attempt(locked_dossier)

    def soft_delete(self, custody_id: int, current_user: str = "system") -> None:
        dossier = self.get_dossier(custody_id)
        self.repo.soft_delete(dossier, current_user=current_user)
        self.db.commit()

    def restore(self, custody_id: int, current_user: str = "system") -> CustodyReleaseDossier:
        dossier = self.get_dossier(custody_id, include_inactive=True)
        self.repo.restore(dossier, current_user=current_user)
        self.db.commit()
        self.db.refresh(dossier)
        return dossier
