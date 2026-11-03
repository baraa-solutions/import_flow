"""
Repository for Trade Finance
"""

from typing import List, Optional, Tuple
from sqlalchemy import or_
from sqlalchemy.orm import Session

from modules.trade_finance.model import FxHedgingAndVariance, ImportFinanceInstrument, LcBankCharge


class TradeFinanceRepository:
    def __init__(self, db: Session):
        self.db = db

    # -------------------------------------------------------------
    # Finance Instruments
    # -------------------------------------------------------------
    def get_instrument_by_id(self, inst_id: int) -> Optional[ImportFinanceInstrument]:
        return (
            self.db.query(ImportFinanceInstrument)
            .filter(
                ImportFinanceInstrument.id == inst_id,
                ImportFinanceInstrument.is_active.is_(True),
            )
            .first()
        )

    def get_instrument_by_number(self, inst_number: str) -> Optional[ImportFinanceInstrument]:
        return (
            self.db.query(ImportFinanceInstrument)
            .filter(
                ImportFinanceInstrument.instrument_number == inst_number.strip(),
                ImportFinanceInstrument.is_active.is_(True),
            )
            .first()
        )

    def list_instruments(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        instrument_type: Optional[str] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[ImportFinanceInstrument], int]:
        query = self.db.query(ImportFinanceInstrument).filter(
            ImportFinanceInstrument.is_active.is_(True)
        )

        if import_file_id:
            query = query.filter(ImportFinanceInstrument.import_file_id == import_file_id)
        if instrument_type:
            query = query.filter(ImportFinanceInstrument.instrument_type == instrument_type.upper())
        if status:
            query = query.filter(ImportFinanceInstrument.status == status.upper())

        if search:
            pattern = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    ImportFinanceInstrument.instrument_number.ilike(pattern),
                    ImportFinanceInstrument.issuing_bank.ilike(pattern),
                    ImportFinanceInstrument.advising_bank.ilike(pattern),
                )
            )

        total = query.count()
        items = query.order_by(ImportFinanceInstrument.created_at.desc()).offset(skip).limit(limit).all()
        return items, total

    def create_instrument(self, inst: ImportFinanceInstrument) -> ImportFinanceInstrument:
        self.db.add(inst)
        return inst

    def soft_delete_instrument(self, inst: ImportFinanceInstrument, current_user: str = "system") -> None:
        inst.is_active = False
        inst.updated_by = current_user

    # -------------------------------------------------------------
    # Bank Charges
    # -------------------------------------------------------------
    def get_charge_by_id(self, charge_id: int) -> Optional[LcBankCharge]:
        return (
            self.db.query(LcBankCharge)
            .filter(
                LcBankCharge.id == charge_id,
                LcBankCharge.is_active.is_(True),
            )
            .first()
        )

    def add_charge(self, charge: LcBankCharge) -> LcBankCharge:
        self.db.add(charge)
        return charge

    def soft_delete_charge(self, charge: LcBankCharge, current_user: str = "system") -> None:
        charge.is_active = False
        charge.updated_by = current_user

    # -------------------------------------------------------------
    # FX Hedging & Variance
    # -------------------------------------------------------------
    def get_fx_record_by_id(self, fx_id: int) -> Optional[FxHedgingAndVariance]:
        return (
            self.db.query(FxHedgingAndVariance)
            .filter(
                FxHedgingAndVariance.id == fx_id,
                FxHedgingAndVariance.is_active.is_(True),
            )
            .first()
        )

    def add_fx_record(self, fx: FxHedgingAndVariance) -> FxHedgingAndVariance:
        self.db.add(fx)
        return fx

    def soft_delete_fx_record(self, fx: FxHedgingAndVariance, current_user: str = "system") -> None:
        fx.is_active = False
        fx.updated_by = current_user
