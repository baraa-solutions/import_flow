from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc
from .model import ContainerDepositLedger


class ContainerDepositRepository:
    @staticmethod
    def create(db: Session, entry: ContainerDepositLedger) -> ContainerDepositLedger:
        db.add(entry)
        db.commit()
        db.refresh(entry)
        return entry

    @staticmethod
    def get_by_id(db: Session, deposit_id: int) -> Optional[ContainerDepositLedger]:
        return db.query(ContainerDepositLedger).filter(
            ContainerDepositLedger.deposit_id == deposit_id
        ).first()

    @staticmethod
    def get_by_container(db: Session, container_number: str) -> List[ContainerDepositLedger]:
        return db.query(ContainerDepositLedger).filter(
            ContainerDepositLedger.container_number == container_number,
            ContainerDepositLedger.is_active == True,
        ).all()

    @staticmethod
    def list(
        db: Session,
        include_inactive: bool = False,
        import_file_id: Optional[int] = None,
        carrier_name: Optional[str] = None,
        refund_status: Optional[str] = None,
        container_number: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[ContainerDepositLedger], int]:
        query = db.query(ContainerDepositLedger)
        if not include_inactive:
            query = query.filter(ContainerDepositLedger.is_active == True)

        if import_file_id is not None:
            query = query.filter(ContainerDepositLedger.import_file_id == import_file_id)

        if carrier_name:
            query = query.filter(ContainerDepositLedger.carrier_name.ilike(f"%{carrier_name}%"))

        if refund_status:
            query = query.filter(ContainerDepositLedger.refund_status == refund_status)

        if container_number:
            query = query.filter(ContainerDepositLedger.container_number.ilike(f"%{container_number}%"))

        total = query.count()
        items = query.order_by(desc(ContainerDepositLedger.created_at)).offset(skip).limit(limit).all()
        return items, total

    @staticmethod
    def update(db: Session, entry: ContainerDepositLedger) -> ContainerDepositLedger:
        db.commit()
        db.refresh(entry)
        return entry

    @staticmethod
    def soft_delete(db: Session, deposit_id: int, user: str) -> Optional[ContainerDepositLedger]:
        entry = ContainerDepositRepository.get_by_id(db, deposit_id)
        if entry:
            entry.is_active = False
            entry.updated_by = user
            db.commit()
            db.refresh(entry)
        return entry

    @staticmethod
    def get_all_active(db: Session) -> List[ContainerDepositLedger]:
        return db.query(ContainerDepositLedger).filter(
            ContainerDepositLedger.is_active == True
        ).all()
