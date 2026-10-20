from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code
from modules.custody_release.model import CustodyReleaseDossier


class CustodyReleaseRepository:
    def __init__(self, db: Session):
        self.db = db

    def generate_next_custody_code(self) -> str:
        """Generates next sequential business code ``CUS-YYYY-NNNNN``."""
        return next_yearly_code(self.db, CustodyReleaseDossier.custody_code, "CUS", pad=5)

    def add(self, dossier: CustodyReleaseDossier) -> CustodyReleaseDossier:
        self.db.add(dossier)
        self.db.flush()
        return dossier

    def get_by_id(self, custody_id: int, include_inactive: bool = False) -> Optional[CustodyReleaseDossier]:
        query = self.db.query(CustodyReleaseDossier).filter(CustodyReleaseDossier.custody_id == custody_id)
        if not include_inactive:
            query = query.filter(CustodyReleaseDossier.is_active == True)
        return query.first()

    def get_by_code(self, custody_code: str) -> Optional[CustodyReleaseDossier]:
        return (
            self.db.query(CustodyReleaseDossier)
            .filter(
                CustodyReleaseDossier.custody_code == custody_code,
                CustodyReleaseDossier.is_active == True,
            )
            .first()
        )

    def get_by_undertaking_number(self, undertaking_number: str) -> Optional[CustodyReleaseDossier]:
        return (
            self.db.query(CustodyReleaseDossier)
            .filter(
                CustodyReleaseDossier.custody_undertaking_number == undertaking_number,
                CustodyReleaseDossier.is_active == True,
            )
            .first()
        )

    def get_active_locked_for_file(self, import_file_id: int) -> Optional[CustodyReleaseDossier]:
        """Returns any active dossier for the file where warehouse lock is currently active."""
        return (
            self.db.query(CustodyReleaseDossier)
            .filter(
                CustodyReleaseDossier.import_file_id == import_file_id,
                CustodyReleaseDossier.is_active == True,
                CustodyReleaseDossier.lock_active == True,
            )
            .first()
        )

    def list_dossiers(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        warehouse_id: Optional[int] = None,
        status: Optional[str] = None,
        lock_active: Optional[bool] = None,
        include_inactive: bool = False,
    ) -> Tuple[List[CustodyReleaseDossier], int]:
        query = self.db.query(CustodyReleaseDossier)
        if not include_inactive:
            query = query.filter(CustodyReleaseDossier.is_active == True)
        if import_file_id is not None:
            query = query.filter(CustodyReleaseDossier.import_file_id == import_file_id)
        if warehouse_id is not None:
            query = query.filter(CustodyReleaseDossier.warehouse_id == warehouse_id)
        if status:
            query = query.filter(CustodyReleaseDossier.status == status)
        if lock_active is not None:
            query = query.filter(CustodyReleaseDossier.lock_active == lock_active)

        total = query.count()
        items = query.order_by(CustodyReleaseDossier.custody_id.desc()).offset(skip).limit(limit).all()
        return items, total

    def update(self, dossier: CustodyReleaseDossier) -> CustodyReleaseDossier:
        self.db.flush()
        return dossier

    def soft_delete(self, dossier: CustodyReleaseDossier, current_user: str = "system") -> None:
        dossier.is_active = False
        dossier.updated_by = current_user
        dossier.updated_at = datetime.now(timezone.utc)
        self.db.flush()

    def restore(self, dossier: CustodyReleaseDossier, current_user: str = "system") -> None:
        dossier.is_active = True
        dossier.updated_by = current_user
        dossier.updated_at = datetime.now(timezone.utc)
        self.db.flush()
