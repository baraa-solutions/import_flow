from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from modules.broker_custody.model import BrokerCustodyAdvance, BrokerExpenseItem
from modules.common.sequence_generator import next_yearly_code


class BrokerCustodyRepository:
    def __init__(self, db: Session):
        self.db = db

    def generate_next_advance_code(self) -> str:
        """Generates next sequential reference code: ADV-YYYY-NNNN"""
        return next_yearly_code(self.db, BrokerCustodyAdvance.advance_code, "ADV", pad=4)

    # -------------------------------------------------------------
    # Advance CRUD
    # -------------------------------------------------------------
    def add_advance(self, advance: BrokerCustodyAdvance) -> BrokerCustodyAdvance:
        self.db.add(advance)
        self.db.flush()
        return advance

    def get_advance_by_id(self, advance_id: int) -> Optional[BrokerCustodyAdvance]:
        return (
            self.db.query(BrokerCustodyAdvance)
            .filter(
                BrokerCustodyAdvance.advance_id == advance_id,
                BrokerCustodyAdvance.is_active == True,
            )
            .first()
        )

    def list_advances(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        broker_id: Optional[int] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[BrokerCustodyAdvance], int]:
        query = self.db.query(BrokerCustodyAdvance).filter(BrokerCustodyAdvance.is_active == True)

        if import_file_id is not None:
            query = query.filter(BrokerCustodyAdvance.import_file_id == import_file_id)

        if broker_id is not None:
            query = query.filter(BrokerCustodyAdvance.broker_id == broker_id)

        if status and status.upper() != "ALL":
            query = query.filter(BrokerCustodyAdvance.status == status.upper())

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                (BrokerCustodyAdvance.advance_code.ilike(term))
                | (BrokerCustodyAdvance.broker_name.ilike(term))
                | (BrokerCustodyAdvance.import_file_code.ilike(term))
            )

        total = query.count()
        items = (
            query.order_by(BrokerCustodyAdvance.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )
        return items, total

    def soft_delete_advance(self, advance: BrokerCustodyAdvance) -> None:
        advance.is_active = False

    # -------------------------------------------------------------
    # Expense Item CRUD
    # -------------------------------------------------------------
    def add_expense_item(self, item: BrokerExpenseItem) -> BrokerExpenseItem:
        self.db.add(item)
        self.db.flush()
        return item

    def get_expense_item_by_id(self, item_id: int) -> Optional[BrokerExpenseItem]:
        return (
            self.db.query(BrokerExpenseItem)
            .filter(
                BrokerExpenseItem.item_id == item_id,
                BrokerExpenseItem.is_active == True,
            )
            .first()
        )

    def list_expense_items(self, advance_id: int) -> List[BrokerExpenseItem]:
        return (
            self.db.query(BrokerExpenseItem)
            .filter(
                BrokerExpenseItem.advance_id == advance_id,
                BrokerExpenseItem.is_active == True,
            )
            .order_by(BrokerExpenseItem.item_id.asc())
            .all()
        )

    def soft_delete_expense_item(self, item: BrokerExpenseItem) -> None:
        item.is_active = False
