"""
Repository for Cargo Claims, Time-Bars & Legal Reservations
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from sqlalchemy import desc
from sqlalchemy.orm import Session

from modules.legal_claims.model import CargoClaimAndReservation


class LegalClaimsRepository:
    def __init__(self, db: Session):
        self.db = db

    def generate_next_code(self) -> str:
        year = datetime.now(timezone.utc).year
        prefix = f"CLM-{year}-"
        last_item = (
            self.db.query(CargoClaimAndReservation)
            .filter(CargoClaimAndReservation.claim_code.like(f"{prefix}%"))
            .order_by(desc(CargoClaimAndReservation.id))
            .first()
        )
        if not last_item:
            return f"{prefix}00001"
        try:
            last_seq = int(last_item.claim_code.split("-")[-1])
            return f"{prefix}{last_seq + 1:05d}"
        except (ValueError, IndexError):
            return f"{prefix}00001"

    def create(self, item: CargoClaimAndReservation) -> CargoClaimAndReservation:
        self.db.add(item)
        self.db.flush()
        return item

    def get_by_id(self, item_id: int, include_deleted: bool = False) -> Optional[CargoClaimAndReservation]:
        query = self.db.query(CargoClaimAndReservation).filter(CargoClaimAndReservation.id == item_id)
        if not include_deleted:
            query = query.filter(CargoClaimAndReservation.is_deleted.is_(False))
        return query.first()

    def get_by_code(self, code: str, include_deleted: bool = False) -> Optional[CargoClaimAndReservation]:
        query = self.db.query(CargoClaimAndReservation).filter(CargoClaimAndReservation.claim_code == code)
        if not include_deleted:
            query = query.filter(CargoClaimAndReservation.is_deleted.is_(False))
        return query.first()

    def list_claims(
        self,
        import_file_id: Optional[int] = None,
        claim_type: Optional[str] = None,
        status: Optional[str] = None,
        include_deleted: bool = False,
        skip: int = 0,
        limit: int = 50,
    ) -> Tuple[List[CargoClaimAndReservation], int]:
        query = self.db.query(CargoClaimAndReservation)
        if not include_deleted:
            query = query.filter(CargoClaimAndReservation.is_deleted.is_(False))
        if import_file_id is not None:
            query = query.filter(CargoClaimAndReservation.import_file_id == import_file_id)
        if claim_type is not None:
            query = query.filter(CargoClaimAndReservation.claim_type == claim_type)
        if status is not None:
            query = query.filter(CargoClaimAndReservation.status == status)

        total = query.count()
        items = query.order_by(desc(CargoClaimAndReservation.created_at)).offset(skip).limit(limit).all()
        return items, total

    def update(self, item: CargoClaimAndReservation) -> CargoClaimAndReservation:
        item.updated_at = datetime.now(timezone.utc)
        self.db.flush()
        return item

    def soft_delete(self, item: CargoClaimAndReservation, user_id: Optional[int] = None) -> CargoClaimAndReservation:
        item.is_deleted = True
        item.updated_by_user_id = user_id
        item.updated_at = datetime.now(timezone.utc)
        self.db.flush()
        return item
