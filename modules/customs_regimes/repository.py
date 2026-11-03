"""
Repository for Customs Special & Suspended Duty Regimes
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy import desc, func
from sqlalchemy.orm import Session

from modules.customs_regimes.model import CustomsSpecialRegime


class CustomsRegimesRepository:
    def __init__(self, db: Session):
        self.db = db

    def generate_next_code(self) -> str:
        year = datetime.now(timezone.utc).year
        prefix = f"REG-{year}-"
        last_item = (
            self.db.query(CustomsSpecialRegime)
            .filter(CustomsSpecialRegime.regime_code.like(f"{prefix}%"))
            .order_by(desc(CustomsSpecialRegime.id))
            .first()
        )
        if not last_item:
            return f"{prefix}00001"
        try:
            last_seq = int(last_item.regime_code.split("-")[-1])
            return f"{prefix}{last_seq + 1:05d}"
        except (ValueError, IndexError):
            return f"{prefix}00001"

    def create(self, regime: CustomsSpecialRegime) -> CustomsSpecialRegime:
        self.db.add(regime)
        self.db.flush()
        return regime

    def get_by_id(self, regime_id: int, include_deleted: bool = False) -> Optional[CustomsSpecialRegime]:
        query = self.db.query(CustomsSpecialRegime).filter(CustomsSpecialRegime.id == regime_id)
        if not include_deleted:
            query = query.filter(CustomsSpecialRegime.is_deleted.is_(False))
        return query.first()

    def get_by_code(self, regime_code: str, include_deleted: bool = False) -> Optional[CustomsSpecialRegime]:
        query = self.db.query(CustomsSpecialRegime).filter(CustomsSpecialRegime.regime_code == regime_code)
        if not include_deleted:
            query = query.filter(CustomsSpecialRegime.is_deleted.is_(False))
        return query.first()

    def list_regimes(
        self,
        import_file_id: Optional[int] = None,
        regime_type: Optional[str] = None,
        status: Optional[str] = None,
        include_deleted: bool = False,
        skip: int = 0,
        limit: int = 50,
    ) -> Tuple[List[CustomsSpecialRegime], int]:
        query = self.db.query(CustomsSpecialRegime)
        if not include_deleted:
            query = query.filter(CustomsSpecialRegime.is_deleted.is_(False))
        if import_file_id is not None:
            query = query.filter(CustomsSpecialRegime.import_file_id == import_file_id)
        if regime_type is not None:
            query = query.filter(CustomsSpecialRegime.regime_type == regime_type)
        if status is not None:
            query = query.filter(CustomsSpecialRegime.status == status)

        total = query.count()
        items = query.order_by(desc(CustomsSpecialRegime.created_at)).offset(skip).limit(limit).all()
        return items, total

    def update(self, regime: CustomsSpecialRegime) -> CustomsSpecialRegime:
        regime.updated_at = datetime.now(timezone.utc)
        self.db.flush()
        return regime

    def soft_delete(self, regime: CustomsSpecialRegime, user_id: Optional[int] = None) -> CustomsSpecialRegime:
        regime.is_deleted = True
        regime.updated_by_user_id = user_id
        regime.updated_at = datetime.now(timezone.utc)
        self.db.flush()
        return regime
