"""
Database Repository for Logistics Exceptions
"""

from typing import List, Optional, Tuple
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from modules.logistics_exceptions.model import LogisticsException


class LogisticsExceptionsRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, exception_id: int) -> Optional[LogisticsException]:
        return (
            self.db.query(LogisticsException)
            .filter(LogisticsException.id == exception_id, LogisticsException.is_deleted == False)
            .first()
        )

    def get_by_code(self, code: str) -> Optional[LogisticsException]:
        return (
            self.db.query(LogisticsException)
            .filter(LogisticsException.exception_code == code, LogisticsException.is_deleted == False)
            .first()
        )

    def list_exceptions(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        exception_type: Optional[str] = None,
        severity: Optional[str] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
        include_deleted: bool = False,
    ) -> Tuple[List[LogisticsException], int]:
        query = self.db.query(LogisticsException)
        if not include_deleted:
            query = query.filter(LogisticsException.is_deleted == False)

        if import_file_id is not None:
            query = query.filter(LogisticsException.import_file_id == import_file_id)

        if exception_type:
            query = query.filter(LogisticsException.exception_type == exception_type)

        if severity:
            query = query.filter(LogisticsException.severity == severity)

        if status:
            query = query.filter(LogisticsException.status == status)

        if search:
            s = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    LogisticsException.exception_code.ilike(s),
                    LogisticsException.title_ar.ilike(s),
                    LogisticsException.title_en.ilike(s),
                    LogisticsException.acid_number.ilike(s),
                    LogisticsException.description.ilike(s),
                )
            )

        total = query.count()
        items = query.order_by(LogisticsException.created_at.desc()).offset(skip).limit(limit).all()
        return items, total

    def create(self, exception: LogisticsException) -> LogisticsException:
        self.db.add(exception)
        self.db.flush()
        self.db.refresh(exception)
        return exception

    def update(self, exception: LogisticsException) -> LogisticsException:
        self.db.flush()
        self.db.refresh(exception)
        return exception

    def soft_delete(self, exception: LogisticsException) -> None:
        exception.is_deleted = True
        exception.is_active = False
        self.db.flush()

    def get_next_sequence_number(self, year: int) -> int:
        prefix = f"EXC-{year}-"
        count = (
            self.db.query(func.count(LogisticsException.id))
            .filter(LogisticsException.exception_code.like(f"{prefix}%"))
            .scalar()
            or 0
        )
        return count + 1

    def get_metrics_data(self) -> dict:
        base_query = self.db.query(LogisticsException).filter(LogisticsException.is_deleted == False)
        total = base_query.count()
        open_count = base_query.filter(LogisticsException.status.in_(["OPEN", "UNDER_REVIEW"])).count()
        critical_count = base_query.filter(
            LogisticsException.severity == "CRITICAL",
            LogisticsException.status.in_(["OPEN", "UNDER_REVIEW"]),
        ).count()
        acid_count = base_query.filter(
            LogisticsException.acid_impact_status.in_(["ACTION_REQUIRED", "EXTENSION_REQUESTED", "SUSPENDED"]),
            LogisticsException.status.in_(["OPEN", "UNDER_REVIEW"]),
        ).count()
        kpi_suspended = base_query.filter(
            LogisticsException.delay_kpi_suspended == True,
            LogisticsException.status.in_(["OPEN", "UNDER_REVIEW"]),
        ).count()

        dispute_sum = (
            self.db.query(func.coalesce(func.sum(LogisticsException.valuation_dispute_amount), 0.0))
            .filter(
                LogisticsException.is_deleted == False,
                LogisticsException.status.in_(["OPEN", "UNDER_REVIEW"]),
            )
            .scalar()
        )

        return {
            "total_exceptions": total,
            "open_exceptions": open_count,
            "critical_exceptions": critical_count,
            "acid_impacted_count": acid_count,
            "kpi_suspended_count": kpi_suspended,
            "total_dispute_amount_egp": float(dispute_sum or 0.0),
        }
