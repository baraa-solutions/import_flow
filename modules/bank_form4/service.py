from datetime import date, datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.bank_form4.model import BankForm4Record
from modules.bank_form4.repository import BankForm4Repository
from modules.bank_form4.schemas import (
    BankForm4Create,
    BankForm4Update,
    DelayCostCalculation,
    NafezaTransmissionUpdate,
)
from modules.bank_form4.validators import (
    validate_bank_form4_create,
    validate_bank_form4_update,
    validate_nafeza_transmission_status,
)
from modules.common.validators import not_found
from modules.import_files.model import ImportFile


class BankForm4Service:
    def __init__(self, db: Session):
        self.db = db
        self.repo = BankForm4Repository(db)

    def create_record(self, data: BankForm4Create, current_user: str = "system") -> BankForm4Record:
        validate_bank_form4_create(data)

        # Ensure import file exists and obtain file code if not supplied
        file_code = data.import_file_code
        if not file_code:
            imp_file = self.db.query(ImportFile).filter(ImportFile.import_file_id == data.import_file_id).first()
            if not imp_file:
                raise not_found("ملف الشحنة", data.import_file_id)
            file_code = imp_file.import_file_code

        # Check unique form4_number if provided
        if data.form4_number:
            existing = self.repo.get_by_form4_number(data.form4_number)
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"رقم استمارة 4 ({data.form4_number}) مسجل بالفعل بالمنظومة.",
                )

        # Calculate initial total financing delay cost if provided or computable
        total_delay_cost = data.total_financing_delay_cost
        if total_delay_cost is None:
            total_delay_cost = round(data.bank_delay_days * data.daily_financing_cost, 2)

        record = BankForm4Record(
            import_file_id=data.import_file_id,
            import_file_code=file_code,
            bank_id=data.bank_id,
            bank_name=data.bank_name.strip(),
            bank_branch=data.bank_branch.strip() if data.bank_branch else None,
            bank_officer_name=data.bank_officer_name.strip() if data.bank_officer_name else None,
            financing_mode=data.financing_mode.strip().upper(),
            currency=data.currency.strip().upper(),
            fx_amount=data.fx_amount,
            fx_allotment_status=data.fx_allotment_status.strip().upper(),
            swift_reference=data.swift_reference.strip() if data.swift_reference else None,
            form4_number=data.form4_number.strip() if data.form4_number else None,
            form4_issue_date=data.form4_issue_date,
            nafeza_transmission_status=data.nafeza_transmission_status.strip().upper(),
            bank_delay_days=data.bank_delay_days,
            daily_financing_cost=data.daily_financing_cost,
            total_financing_delay_cost=total_delay_cost,
            notes=data.notes,
            created_by=current_user,
            updated_by=current_user,
        )

        self.repo.add(record)
        self.db.commit()
        self.db.refresh(record)
        return record

    def get_record(self, form4_id: int) -> BankForm4Record:
        record = self.repo.get_by_id(form4_id)
        if not record:
            raise not_found("سجل استمارة 4 البنكية", form4_id)
        return record

    def get_records_by_file(self, import_file_id: int) -> List[BankForm4Record]:
        return self.repo.get_by_import_file_id(import_file_id)

    def get_record_by_form4_number(self, form4_number: str) -> BankForm4Record:
        record = self.repo.get_by_form4_number(form4_number)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"استمارة 4 برقم {form4_number} غير موجودة.",
            )
        return record

    def list_records(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        nafeza_status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[BankForm4Record], int]:
        return self.repo.list(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            nafeza_status=nafeza_status,
            search=search,
        )

    def update_record(self, form4_id: int, data: BankForm4Update, current_user: str = "system") -> BankForm4Record:
        record = self.get_record(form4_id)
        updates = validate_bank_form4_update(data)

        if "form4_number" in updates and updates["form4_number"]:
            f4_num = updates["form4_number"].strip()
            existing = self.repo.get_by_form4_number(f4_num)
            if existing and existing.form4_id != form4_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"رقم استمارة 4 ({f4_num}) مسجل بالفعل بالمنظومة لسجل آخر.",
                )
            updates["form4_number"] = f4_num

        for key, value in updates.items():
            setattr(record, key, value)

        # Automatically recalculate total delay cost if days or daily cost were updated
        if "bank_delay_days" in updates or "daily_financing_cost" in updates:
            if "total_financing_delay_cost" not in updates:
                record.total_financing_delay_cost = round(record.bank_delay_days * record.daily_financing_cost, 2)

        record.updated_by = current_user
        record.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(record)
        return record

    def calculate_delay_costs(
        self,
        form4_id: int,
        calc_input: DelayCostCalculation,
        current_user: str = "system",
    ) -> BankForm4Record:
        """
        Business logic to calculate financing delay costs based on daily cost or annual interest rate.
        """
        record = self.get_record(form4_id)

        # 1. Determine daily cost
        if calc_input.annual_interest_rate is not None and calc_input.annual_interest_rate > 0:
            daily_cost = round((record.fx_amount * (calc_input.annual_interest_rate / 100.0)) / 365.0, 2)
        elif calc_input.daily_financing_cost is not None:
            daily_cost = calc_input.daily_financing_cost
        else:
            daily_cost = record.daily_financing_cost

        # 2. Determine delay days
        delay_days = calc_input.bank_delay_days if calc_input.bank_delay_days is not None else record.bank_delay_days

        # 3. Calculate total delay cost
        total_delay_cost = round(delay_days * daily_cost, 2)

        # Update record
        record.bank_delay_days = delay_days
        record.daily_financing_cost = daily_cost
        record.total_financing_delay_cost = total_delay_cost
        record.updated_by = current_user
        record.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        self.db.refresh(record)
        return record

    def update_nafeza_transmission(
        self,
        form4_id: int,
        update_data: NafezaTransmissionUpdate,
        current_user: str = "system",
    ) -> BankForm4Record:
        """
        Business logic to update Nafeza transmission state (AWAITING_BANK, TRANSMITTED, VALUE_MISMATCH, ACCEPTED).
        """
        record = self.get_record(form4_id)
        status_val = validate_nafeza_transmission_status(update_data.nafeza_transmission_status)

        record.nafeza_transmission_status = status_val

        if update_data.form4_number:
            f4_num = update_data.form4_number.strip()
            existing = self.repo.get_by_form4_number(f4_num)
            if existing and existing.form4_id != form4_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"رقم استمارة 4 ({f4_num}) مسجل بالفعل لسجل آخر.",
                )
            record.form4_number = f4_num

        if update_data.form4_issue_date:
            record.form4_issue_date = update_data.form4_issue_date

        if update_data.notes:
            if record.notes:
                record.notes = f"{record.notes}\n[{status_val}]: {update_data.notes}"
            else:
                record.notes = f"[{status_val}]: {update_data.notes}"

        record.updated_by = current_user
        record.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(record)
        return record

    def delete_record(self, form4_id: int, current_user: str = "system") -> None:
        record = self.get_record(form4_id)
        record.updated_by = current_user
        self.repo.soft_delete(record)
        self.db.commit()
