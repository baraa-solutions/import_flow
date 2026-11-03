"""
Business Logic Service for Trade Finance
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.common.validators import not_found
from modules.import_files.model import ImportFile
from modules.trade_finance.model import FxHedgingAndVariance, ImportFinanceInstrument, LcBankCharge
from modules.trade_finance.repository import TradeFinanceRepository
from modules.trade_finance.schemas import (
    FxHedgingAndVarianceCreate,
    FxHedgingAndVarianceUpdate,
    ImportFinanceInstrumentCreate,
    ImportFinanceInstrumentUpdate,
    LcBankChargeCreate,
    LcBankChargeUpdate,
)
from modules.trade_finance.validators import (
    validate_bank_charge_create,
    validate_bank_charge_update,
    validate_fx_create,
    validate_fx_update,
    validate_instrument_create,
    validate_instrument_update,
)


class TradeFinanceService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = TradeFinanceRepository(db)

    # -------------------------------------------------------------
    # Instrument Operations
    # -------------------------------------------------------------
    def create_instrument(
        self, data: ImportFinanceInstrumentCreate, current_user: str = "system"
    ) -> ImportFinanceInstrument:
        validate_instrument_create(data)

        # 1. Verify Import File
        file = self.db.query(ImportFile).filter(ImportFile.import_file_id == data.import_file_id).first()
        if not file:
            raise not_found("ملف الشحنة الاستيرادية", data.import_file_id)

        # 2. Check unique instrument number
        existing = self.repo.get_instrument_by_number(data.instrument_number)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"رقم الأداة التمويلية ({data.instrument_number}) مسجل مسبقاً في النظام.",
            )

        inst = ImportFinanceInstrument(
            instrument_type=data.instrument_type.upper(),
            instrument_number=data.instrument_number.strip(),
            import_file_id=data.import_file_id,
            issuing_bank=data.issuing_bank.strip(),
            advising_bank=data.advising_bank.strip() if data.advising_bank else None,
            currency=data.currency.strip().upper(),
            amount=data.amount,
            issue_date=data.issue_date,
            expiry_date=data.expiry_date,
            shipment_deadline=data.shipment_deadline,
            presentation_period_days=data.presentation_period_days,
            payment_terms=data.payment_terms.strip() if data.payment_terms else None,
            status="DRAFT",
            tolerance_percentage=data.tolerance_percentage,
            notes=data.notes.strip() if data.notes else None,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.create_instrument(inst)
        self.db.commit()
        self.db.refresh(inst)
        return inst

    def get_instrument(self, inst_id: int) -> ImportFinanceInstrument:
        inst = self.repo.get_instrument_by_id(inst_id)
        if not inst:
            raise not_found("أداة التمويل / الاعتماد المستندي", inst_id)
        return inst

    def list_instruments(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        instrument_type: Optional[str] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[ImportFinanceInstrument], int]:
        return self.repo.list_instruments(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            instrument_type=instrument_type,
            status=status,
            search=search,
        )

    def update_instrument(
        self, inst_id: int, data: ImportFinanceInstrumentUpdate, current_user: str = "system"
    ) -> ImportFinanceInstrument:
        inst = self.get_instrument(inst_id)
        updates = validate_instrument_update(data)

        for key, value in updates.items():
            setattr(inst, key, value)

        inst.updated_by = current_user
        inst.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(inst)
        return inst

    def delete_instrument(self, inst_id: int, current_user: str = "system") -> None:
        inst = self.get_instrument(inst_id)
        self.repo.soft_delete_instrument(inst, current_user=current_user)
        self.db.commit()

    # -------------------------------------------------------------
    # Bank Charges Operations
    # -------------------------------------------------------------
    def add_bank_charge(
        self, inst_id: int, data: LcBankChargeCreate, current_user: str = "system"
    ) -> LcBankCharge:
        inst = self.get_instrument(inst_id)
        validate_bank_charge_create(data)

        charge = LcBankCharge(
            finance_instrument_id=inst.id,
            charge_type=data.charge_type.upper(),
            currency=data.currency.strip().upper(),
            amount=data.amount,
            amount_egp=data.amount_egp,
            debit_date=data.debit_date,
            debit_account=data.debit_account.strip() if data.debit_account else None,
            swift_reference=data.swift_reference.strip() if data.swift_reference else None,
            notes=data.notes.strip() if data.notes else None,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.add_charge(charge)
        self.db.commit()
        self.db.refresh(charge)
        return charge

    def delete_bank_charge(self, charge_id: int, current_user: str = "system") -> None:
        charge = self.repo.get_charge_by_id(charge_id)
        if not charge:
            raise not_found("المصروف البنكي", charge_id)
        self.repo.soft_delete_charge(charge, current_user=current_user)
        self.db.commit()

    # -------------------------------------------------------------
    # FX Hedging & Variance Operations
    # -------------------------------------------------------------
    def add_fx_record(
        self, inst_id: int, data: FxHedgingAndVarianceCreate, current_user: str = "system"
    ) -> FxHedgingAndVariance:
        inst = self.get_instrument(inst_id)
        validate_fx_create(data)

        booking_total = round(data.original_amount * data.booking_rate, 2)
        settlement_total = None
        variance_amount = 0.0
        variance_nature = "NEUTRAL"

        if data.settlement_rate is not None:
            settlement_total = round(data.original_amount * data.settlement_rate, 2)
            variance_amount = round(settlement_total - booking_total, 2)
            if variance_amount > 0:
                variance_nature = "UNFAVORABLE_LOSS"
            elif variance_amount < 0:
                variance_nature = "FAVORABLE_GAIN"

        fx = FxHedgingAndVariance(
            finance_instrument_id=inst.id,
            foreign_currency=data.foreign_currency.strip().upper(),
            original_amount=data.original_amount,
            booking_date=data.booking_date,
            booking_rate=data.booking_rate,
            booking_total_egp=booking_total,
            settlement_date=data.settlement_date,
            settlement_rate=data.settlement_rate,
            settlement_total_egp=settlement_total,
            hedging_contract_ref=data.hedging_contract_ref.strip() if data.hedging_contract_ref else None,
            variance_amount_egp=variance_amount,
            variance_nature=variance_nature,
            notes=data.notes.strip() if data.notes else None,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.add_fx_record(fx)
        self.db.commit()
        self.db.refresh(fx)
        return fx

    def update_fx_record(
        self, fx_id: int, data: FxHedgingAndVarianceUpdate, current_user: str = "system"
    ) -> FxHedgingAndVariance:
        fx = self.repo.get_fx_record_by_id(fx_id)
        if not fx:
            raise not_found("سجل فروق العملة والتحوط", fx_id)

        updates = validate_fx_update(data)
        for key, value in updates.items():
            setattr(fx, key, value)

        if "settlement_rate" in updates and fx.settlement_rate is not None:
            fx.settlement_total_egp = round(fx.original_amount * fx.settlement_rate, 2)
            fx.variance_amount_egp = round(fx.settlement_total_egp - fx.booking_total_egp, 2)
            if fx.variance_amount_egp > 0:
                fx.variance_nature = "UNFAVORABLE_LOSS"
            elif fx.variance_amount_egp < 0:
                fx.variance_nature = "FAVORABLE_GAIN"
            else:
                fx.variance_nature = "NEUTRAL"

        fx.updated_by = current_user
        fx.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(fx)
        return fx

    def delete_fx_record(self, fx_id: int, current_user: str = "system") -> None:
        fx = self.repo.get_fx_record_by_id(fx_id)
        if not fx:
            raise not_found("سجل فروق العملة", fx_id)
        self.repo.soft_delete_fx_record(fx, current_user=current_user)
        self.db.commit()
