from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session

from modules.common.sequence_generator import next_yearly_code
from modules.inspection_appeals.model import InspectionAppeal


class InspectionAppealRepository:
    def __init__(self, db: Session):
        self.db = db

    def generate_next_appeal_code(self) -> str:
        """Generates next sequential business code ``APP-YYYY-NNNNN``."""
        return next_yearly_code(self.db, InspectionAppeal.appeal_code, "APP", pad=5)

    def add(self, appeal: InspectionAppeal) -> InspectionAppeal:
        self.db.add(appeal)
        self.db.flush()
        return appeal

    def get_by_id(self, appeal_id: int, include_inactive: bool = False) -> Optional[InspectionAppeal]:
        query = self.db.query(InspectionAppeal).filter(InspectionAppeal.appeal_id == appeal_id)
        if not include_inactive:
            query = query.filter(InspectionAppeal.is_active == True)
        return query.first()

    def get_by_code(self, appeal_code: str) -> Optional[InspectionAppeal]:
        return (
            self.db.query(InspectionAppeal)
            .filter(
                InspectionAppeal.appeal_code == appeal_code,
                InspectionAppeal.is_active == True,
            )
            .first()
        )

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
        query = self.db.query(InspectionAppeal)
        if not include_inactive:
            query = query.filter(InspectionAppeal.is_active == True)
        if import_file_id is not None:
            query = query.filter(InspectionAppeal.import_file_id == import_file_id)
        if clearance_id is not None:
            query = query.filter(InspectionAppeal.clearance_id == clearance_id)
        if regulatory_authority:
            query = query.filter(InspectionAppeal.regulatory_authority == regulatory_authority)
        if appeal_tier:
            query = query.filter(InspectionAppeal.appeal_tier == appeal_tier)
        if appeal_result:
            query = query.filter(InspectionAppeal.appeal_result == appeal_result)

        total = query.count()
        items = query.order_by(InspectionAppeal.appeal_id.desc()).offset(skip).limit(limit).all()
        return items, total

    def update(self, appeal: InspectionAppeal) -> InspectionAppeal:
        self.db.flush()
        return appeal

    def soft_delete(self, appeal: InspectionAppeal, current_user: str = "system") -> None:
        appeal.is_active = False
        appeal.updated_by = current_user
        appeal.updated_at = datetime.now(timezone.utc)
        self.db.flush()

    def restore(self, appeal: InspectionAppeal, current_user: str = "system") -> None:
        appeal.is_active = True
        appeal.updated_by = current_user
        appeal.updated_at = datetime.now(timezone.utc)
        self.db.flush()
