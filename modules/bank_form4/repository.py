from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from modules.bank_form4.model import BankForm4Record


class BankForm4Repository:
    def __init__(self, db: Session):
        self.db = db

    def add(self, record: BankForm4Record) -> BankForm4Record:
        self.db.add(record)
        self.db.flush()
        return record

    def get_by_id(self, form4_id: int) -> Optional[BankForm4Record]:
        return (
            self.db.query(BankForm4Record)
            .filter(
                BankForm4Record.form4_id == form4_id,
                BankForm4Record.is_active == True,
            )
            .first()
        )

    def get_by_import_file_id(self, import_file_id: int) -> List[BankForm4Record]:
        return (
            self.db.query(BankForm4Record)
            .filter(
                BankForm4Record.import_file_id == import_file_id,
                BankForm4Record.is_active == True,
            )
            .order_by(BankForm4Record.form4_id.desc())
            .all()
        )

    def get_by_form4_number(self, form4_number: str) -> Optional[BankForm4Record]:
        if not form4_number:
            return None
        return (
            self.db.query(BankForm4Record)
            .filter(
                BankForm4Record.form4_number == form4_number.strip(),
                BankForm4Record.is_active == True,
            )
            .first()
        )

    def list(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        nafeza_status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[BankForm4Record], int]:
        query = self.db.query(BankForm4Record).filter(BankForm4Record.is_active == True)

        if import_file_id is not None:
            query = query.filter(BankForm4Record.import_file_id == import_file_id)

        if nafeza_status and nafeza_status.upper() != "ALL":
            query = query.filter(BankForm4Record.nafeza_transmission_status == nafeza_status.upper())

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                (BankForm4Record.import_file_code.ilike(term))
                | (BankForm4Record.form4_number.ilike(term))
                | (BankForm4Record.bank_name.ilike(term))
                | (BankForm4Record.swift_reference.ilike(term))
            )

        total = query.count()
        items = (
            query.order_by(BankForm4Record.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )
        return items, total

    def soft_delete(self, record: BankForm4Record) -> None:
        record.is_active = False
