"""
Repository for Preferential Trade Agreements & Origin Verifications
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy import desc
from sqlalchemy.orm import Session

from modules.trade_agreements.model import PreferentialOriginVerification


class TradeAgreementsRepository:
    def __init__(self, db: Session):
        self.db = db

    def generate_next_code(self) -> str:
        year = datetime.now(timezone.utc).year
        prefix = f"POV-{year}-"
        last_item = (
            self.db.query(PreferentialOriginVerification)
            .filter(PreferentialOriginVerification.verification_code.like(f"{prefix}%"))
            .order_by(desc(PreferentialOriginVerification.id))
            .first()
        )
        if not last_item:
            return f"{prefix}00001"
        try:
            last_seq = int(last_item.verification_code.split("-")[-1])
            return f"{prefix}{last_seq + 1:05d}"
        except (ValueError, IndexError):
            return f"{prefix}00001"

    def create(self, item: PreferentialOriginVerification) -> PreferentialOriginVerification:
        self.db.add(item)
        self.db.flush()
        return item

    def get_by_id(self, item_id: int, include_deleted: bool = False) -> Optional[PreferentialOriginVerification]:
        query = self.db.query(PreferentialOriginVerification).filter(PreferentialOriginVerification.id == item_id)
        if not include_deleted:
            query = query.filter(PreferentialOriginVerification.is_deleted.is_(False))
        return query.first()

    def get_by_code(self, code: str, include_deleted: bool = False) -> Optional[PreferentialOriginVerification]:
        query = self.db.query(PreferentialOriginVerification).filter(PreferentialOriginVerification.verification_code == code)
        if not include_deleted:
            query = query.filter(PreferentialOriginVerification.is_deleted.is_(False))
        return query.first()

    def list_verifications(
        self,
        import_file_id: Optional[int] = None,
        agreement_name: Optional[str] = None,
        submission_status: Optional[str] = None,
        include_deleted: bool = False,
        skip: int = 0,
        limit: int = 50,
    ) -> Tuple[List[PreferentialOriginVerification], int]:
        query = self.db.query(PreferentialOriginVerification)
        if not include_deleted:
            query = query.filter(PreferentialOriginVerification.is_deleted.is_(False))
        if import_file_id is not None:
            query = query.filter(PreferentialOriginVerification.import_file_id == import_file_id)
        if agreement_name is not None:
            query = query.filter(PreferentialOriginVerification.agreement_name == agreement_name)
        if submission_status is not None:
            query = query.filter(PreferentialOriginVerification.submission_status == submission_status)

        total = query.count()
        items = query.order_by(desc(PreferentialOriginVerification.created_at)).offset(skip).limit(limit).all()
        return items, total

    def update(self, item: PreferentialOriginVerification) -> PreferentialOriginVerification:
        item.updated_at = datetime.now(timezone.utc)
        self.db.flush()
        return item

    def soft_delete(self, item: PreferentialOriginVerification, user_id: Optional[int] = None) -> PreferentialOriginVerification:
        item.is_deleted = True
        item.updated_by_user_id = user_id
        item.updated_at = datetime.now(timezone.utc)
        self.db.flush()
        return item
