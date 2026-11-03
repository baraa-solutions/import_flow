from typing import List, Optional, Tuple
from sqlalchemy import or_
from sqlalchemy.orm import Session
from modules.broker_custody.model import (
    BrokerCustodyAdvance,
    BrokerExpenseItem,
    BrokerSettlementReceipt,
    CustomsBrokerAdvance,
)
from modules.common.sequence_generator import next_yearly_code


class BrokerCustodyRepository:
    def __init__(self, db: Session):
        self.db = db

    # -------------------------------------------------------------
    # Wave 1 Customs Broker Advances CRUD
    # -------------------------------------------------------------
    def generate_next_customs_advance_code(self) -> str:
        return next_yearly_code(self.db, CustomsBrokerAdvance.advance_code, "CADV", pad=4)

    def add_customs_advance(self, advance: CustomsBrokerAdvance) -> CustomsBrokerAdvance:
        self.db.add(advance)
        self.db.flush()
        return advance

    def get_customs_advance_by_id(self, adv_id: int) -> Optional[CustomsBrokerAdvance]:
        return (
            self.db.query(CustomsBrokerAdvance)
            .filter(
                CustomsBrokerAdvance.id == adv_id,
                CustomsBrokerAdvance.is_active.is_(True),
            )
            .first()
        )

    def list_customs_advances(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        broker_id: Optional[int] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[CustomsBrokerAdvance], int]:
        query = self.db.query(CustomsBrokerAdvance).filter(CustomsBrokerAdvance.is_active.is_(True))

        if import_file_id is not None:
            query = query.filter(CustomsBrokerAdvance.import_file_id == import_file_id)
        if broker_id is not None:
            query = query.filter(CustomsBrokerAdvance.broker_id == broker_id)
        if status and status.upper() != "ALL":
            query = query.filter(CustomsBrokerAdvance.status == status.upper())

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                (CustomsBrokerAdvance.advance_code.ilike(term))
                | (CustomsBrokerAdvance.broker_name.ilike(term))
            )

        total = query.count()
        items = (
            query.order_by(CustomsBrokerAdvance.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )
        return items, total

    def soft_delete_customs_advance(self, advance: CustomsBrokerAdvance, current_user: str = "system") -> None:
        advance.is_active = False
        advance.updated_by = current_user

    # -------------------------------------------------------------
    # Wave 1 Official Receipts CRUD
    # -------------------------------------------------------------
    def add_receipt(self, receipt: BrokerSettlementReceipt) -> BrokerSettlementReceipt:
        self.db.add(receipt)
        self.db.flush()
        return receipt

    def get_receipt_by_id(self, receipt_id: int) -> Optional[BrokerSettlementReceipt]:
        return (
            self.db.query(BrokerSettlementReceipt)
            .filter(
                BrokerSettlementReceipt.id == receipt_id,
                BrokerSettlementReceipt.is_active.is_(True),
            )
            .first()
        )

    def list_receipts(self, advance_id: int) -> List[BrokerSettlementReceipt]:
        return (
            self.db.query(BrokerSettlementReceipt)
            .filter(
                BrokerSettlementReceipt.advance_id == advance_id,
                BrokerSettlementReceipt.is_active.is_(True),
            )
            .order_by(BrokerSettlementReceipt.receipt_date.asc())
            .all()
        )

    def soft_delete_receipt(self, receipt: BrokerSettlementReceipt, current_user: str = "system") -> None:
        receipt.is_active = False
        receipt.updated_by = current_user

    # -------------------------------------------------------------
    # Legacy BrokerCustodyAdvance CRUD (Preserved)
    # -------------------------------------------------------------
    def generate_next_advance_code(self) -> str:
        return next_yearly_code(self.db, BrokerCustodyAdvance.advance_code, "ADV", pad=4)

    def add_advance(self, advance: BrokerCustodyAdvance) -> BrokerCustodyAdvance:
        self.db.add(advance)
        self.db.flush()
        return advance

    def get_advance_by_id(self, advance_id: int) -> Optional[BrokerCustodyAdvance]:
        return (
            self.db.query(BrokerCustodyAdvance)
            .filter(
                BrokerCustodyAdvance.advance_id == advance_id,
                BrokerCustodyAdvance.is_active.is_(True),
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
        query = self.db.query(BrokerCustodyAdvance).filter(BrokerCustodyAdvance.is_active.is_(True))

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

    def add_expense_item(self, item: BrokerExpenseItem) -> BrokerExpenseItem:
        self.db.add(item)
        self.db.flush()
        return item

    def get_expense_item_by_id(self, item_id: int) -> Optional[BrokerExpenseItem]:
        return (
            self.db.query(BrokerExpenseItem)
            .filter(
                BrokerExpenseItem.item_id == item_id,
                BrokerExpenseItem.is_active.is_(True),
            )
            .first()
        )

    def list_expense_items(self, advance_id: int) -> List[BrokerExpenseItem]:
        return (
            self.db.query(BrokerExpenseItem)
            .filter(
                BrokerExpenseItem.advance_id == advance_id,
                BrokerExpenseItem.is_active.is_(True),
            )
            .order_by(BrokerExpenseItem.item_id.asc())
            .all()
        )

    def soft_delete_expense_item(self, item: BrokerExpenseItem) -> None:
        item.is_active = False
