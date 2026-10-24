from datetime import date, datetime, timezone
from typing import List, Optional, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func, desc

from .model import PortTerminalRate, PortStorageAccrual


class PortStorageRepository:

    # --- Rates ---

    @staticmethod
    def get_terminal_rate(db: Session, rate_id: int) -> Optional[PortTerminalRate]:
        return db.query(PortTerminalRate).filter(
            PortTerminalRate.rate_id == rate_id,
            PortTerminalRate.is_active == True,
        ).first()

    @staticmethod
    def find_terminal_rate(
        db: Session,
        terminal_code: str,
        container_size: str,
        is_reefer: bool = False,
        effective_date: Optional[date] = None,
    ) -> Optional[PortTerminalRate]:
        query = db.query(PortTerminalRate).filter(
            PortTerminalRate.terminal_code == terminal_code,
            PortTerminalRate.container_size == container_size,
            PortTerminalRate.is_reefer == is_reefer,
            PortTerminalRate.is_active == True,
        )
        if effective_date:
            query = query.filter(PortTerminalRate.effective_date <= effective_date)
        return query.order_by(desc(PortTerminalRate.effective_date)).first()

    @staticmethod
    def list_terminal_rates(
        db: Session,
        terminal_code: Optional[str] = None,
        container_size: Optional[str] = None,
        is_reefer: Optional[bool] = None,
        is_active: bool = True,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[PortTerminalRate], int]:
        query = db.query(PortTerminalRate)
        if is_active is not None:
            query = query.filter(PortTerminalRate.is_active == is_active)
        if terminal_code:
            query = query.filter(PortTerminalRate.terminal_code == terminal_code)
        if container_size:
            query = query.filter(PortTerminalRate.container_size == container_size)
        if is_reefer is not None:
            query = query.filter(PortTerminalRate.is_reefer == is_reefer)
            
        total = query.count()
        rates = query.order_by(PortTerminalRate.terminal_code, PortTerminalRate.container_size).offset(skip).limit(limit).all()
        return rates, total

    @staticmethod
    def find_rate_by_id_any_status(db: Session, rate_id: int) -> Optional[PortTerminalRate]:
        return db.query(PortTerminalRate).filter(PortTerminalRate.rate_id == rate_id).first()

    @staticmethod
    def find_rate_by_unique_key(
        db: Session,
        terminal_code: str,
        container_size: str,
        is_reefer: bool,
        effective_date: date,
        exclude_rate_id: Optional[int] = None,
    ) -> Optional[PortTerminalRate]:
        """Any row (active or soft-deleted) holding uq_port_terminal_rate_unique's key."""
        query = db.query(PortTerminalRate).filter(
            PortTerminalRate.terminal_code == terminal_code,
            PortTerminalRate.container_size == container_size,
            PortTerminalRate.is_reefer == is_reefer,
            PortTerminalRate.effective_date == effective_date,
        )
        if exclude_rate_id is not None:
            query = query.filter(PortTerminalRate.rate_id != exclude_rate_id)
        return query.first()

    @staticmethod
    def create_terminal_rate(db: Session, rate_obj: PortTerminalRate) -> PortTerminalRate:
        db.add(rate_obj)
        db.commit()
        db.refresh(rate_obj)
        return rate_obj

    @staticmethod
    def update_terminal_rate(db: Session, rate_id: int, updates: Dict[str, Any]) -> Optional[PortTerminalRate]:
        rate = db.query(PortTerminalRate).filter(PortTerminalRate.rate_id == rate_id).first()
        if not rate:
            return None
        for key, value in updates.items():
            if hasattr(rate, key) and value is not None:
                setattr(rate, key, value)
        rate.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(rate)
        return rate

    @staticmethod
    def delete_terminal_rate(db: Session, rate_id: int, user: str = "System") -> bool:
        rate = db.query(PortTerminalRate).filter(PortTerminalRate.rate_id == rate_id).first()
        if not rate:
            return False
        rate.is_active = False
        rate.updated_by = user
        rate.updated_at = datetime.now(timezone.utc)
        db.commit()
        return True

    # --- Accruals ---

    @staticmethod
    def get_storage_accrual(db: Session, accrual_id: int) -> Optional[PortStorageAccrual]:
        return db.query(PortStorageAccrual).filter(
            PortStorageAccrual.accrual_id == accrual_id,
            PortStorageAccrual.is_active == True,
        ).first()

    @staticmethod
    def list_storage_accruals(
        db: Session,
        import_file_id: Optional[int] = None,
        terminal_code: Optional[str] = None,
        container_number: Optional[str] = None,
        status: Optional[str] = None,
        is_active: bool = True,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[PortStorageAccrual], int]:
        query = db.query(PortStorageAccrual)
        if is_active is not None:
            query = query.filter(PortStorageAccrual.is_active == is_active)
        if import_file_id:
            query = query.filter(PortStorageAccrual.import_file_id == import_file_id)
        if terminal_code:
            query = query.filter(PortStorageAccrual.terminal_code == terminal_code)
        if container_number:
            query = query.filter(PortStorageAccrual.container_number.ilike(f"%{container_number}%"))
        if status:
            query = query.filter(PortStorageAccrual.status == status)

        total = query.count()
        accruals = query.order_by(desc(PortStorageAccrual.accrual_id)).offset(skip).limit(limit).all()
        return accruals, total

    @staticmethod
    def create_storage_accrual(db: Session, accrual_obj: PortStorageAccrual) -> PortStorageAccrual:
        db.add(accrual_obj)
        db.commit()
        db.refresh(accrual_obj)
        return accrual_obj

    @staticmethod
    def update_storage_accrual(db: Session, accrual_id: int, updates: Dict[str, Any]) -> Optional[PortStorageAccrual]:
        accrual = db.query(PortStorageAccrual).filter(PortStorageAccrual.accrual_id == accrual_id).first()
        if not accrual:
            return None
        for key, value in updates.items():
            if hasattr(accrual, key) and value is not None:
                setattr(accrual, key, value)
        accrual.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(accrual)
        return accrual

    @staticmethod
    def delete_storage_accrual(db: Session, accrual_id: int, user: str = "System") -> bool:
        accrual = db.query(PortStorageAccrual).filter(PortStorageAccrual.accrual_id == accrual_id).first()
        if not accrual:
            return False
        accrual.is_active = False
        accrual.updated_by = user
        accrual.updated_at = datetime.now(timezone.utc)
        db.commit()
        return True

    @staticmethod
    def get_summary(db: Session, import_file_id: Optional[int] = None) -> Dict[str, Any]:
        query = db.query(PortStorageAccrual).filter(PortStorageAccrual.is_active == True)
        if import_file_id:
            query = query.filter(PortStorageAccrual.import_file_id == import_file_id)

        rows = query.all()
        total_accruals = len(rows)
        total_storage = sum(r.storage_charges_egp or 0.0 for r in rows)
        total_reefer = sum(r.reefer_plugging_charges_egp or 0.0 for r in rows)
        total_fees = sum((r.xray_scan_fee_egp or 0.0) + (r.scale_fee_egp or 0.0) for r in rows)
        total_accrued = sum(r.total_port_storage_egp or 0.0 for r in rows)
        
        estimated = sum(1 for r in rows if r.status == "ESTIMATED")
        invoiced = sum(1 for r in rows if r.status == "INVOICED")
        paid = sum(1 for r in rows if r.status == "PAID")

        return {
            "total_accruals": total_accruals,
            "total_storage_charges_egp": round(total_storage, 2),
            "total_reefer_charges_egp": round(total_reefer, 2),
            "total_ancillary_fees_egp": round(total_fees, 2),
            "total_port_storage_egp": round(total_accrued, 2),
            "estimated_count": estimated,
            "invoiced_count": invoiced,
            "paid_count": paid,
        }
