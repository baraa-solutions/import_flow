"""
Business Logic & Service Layer for Logistics Exceptions
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.logistics_exceptions.model import LogisticsException
from modules.logistics_exceptions.repository import LogisticsExceptionsRepository
from modules.logistics_exceptions.schemas import (
    AcidImpactResolution,
    ExceptionMetricsOut,
    ExceptionResolveRequest,
    LogisticsExceptionCreate,
    LogisticsExceptionUpdate,
    ValuationDisputeAppeal,
)
from modules.logistics_exceptions.validators import (
    validate_acid_dates,
    validate_exception_code_unique,
    validate_resolution_requirements,
    validate_valuation_dispute,
)


class LogisticsExceptionsService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = LogisticsExceptionsRepository(db)

    def generate_code(self) -> str:
        current_year = datetime.now(timezone.utc).year
        seq = self.repo.get_next_sequence_number(current_year)
        return f"EXC-{current_year}-{seq:04d}"

    def list_exceptions(
        self,
        skip: int = 0,
        limit: int = 50,
        import_file_id: Optional[int] = None,
        exception_type: Optional[str] = None,
        severity: Optional[str] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Tuple[List[LogisticsException], int]:
        return self.repo.list_exceptions(
            skip=skip,
            limit=limit,
            import_file_id=import_file_id,
            exception_type=exception_type,
            severity=severity,
            status=status,
            search=search,
        )

    def get_by_id(self, exception_id: int) -> LogisticsException:
        item = self.repo.get_by_id(exception_id)
        if not item:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Logistics exception #{exception_id} not found.",
            )
        return item

    def log_exception(
        self,
        data: LogisticsExceptionCreate,
        current_user_id: Optional[int] = None,
    ) -> LogisticsException:
        code = data.exception_code or self.generate_code()
        validate_exception_code_unique(self.repo, code)
        validate_acid_dates(data.acid_original_expiry, data.acid_adjusted_expiry)
        validate_valuation_dispute(
            data.valuation_original_customs_val,
            data.valuation_declared_val,
            data.valuation_dispute_amount,
        )

        # Automatic supply chain intelligence rules:
        acid_status = data.acid_impact_status
        if data.acid_original_expiry and data.delay_impact_days > 0 and acid_status == "NOT_AFFECTED":
            acid_status = "ACTION_REQUIRED"

        # Automated KPI delay suspension on high impact
        delay_suspended = data.delay_kpi_suspended
        suspension_reason = data.suspension_reason
        if (data.severity == "CRITICAL" or data.delay_impact_days >= 7) and not delay_suspended:
            delay_suspended = True
            suspension_reason = (
                suspension_reason
                or f"Automated KPI suspension triggered: severe delay impact ({data.delay_impact_days} days) / {data.severity} exception."
            )

        # Automated dispute amount calculation if missing
        dispute_amount = data.valuation_dispute_amount
        if (
            dispute_amount is None
            and data.valuation_original_customs_val is not None
            and data.valuation_declared_val is not None
        ):
            dispute_amount = max(0.0, data.valuation_original_customs_val - data.valuation_declared_val)

        exception = LogisticsException(
            exception_code=code,
            import_file_id=data.import_file_id,
            shipment_id=data.shipment_id,
            exception_type=data.exception_type,
            severity=data.severity,
            title_ar=data.title_ar,
            title_en=data.title_en,
            description=data.description,
            delay_impact_days=data.delay_impact_days,
            acid_number=data.acid_number,
            acid_original_expiry=data.acid_original_expiry,
            acid_adjusted_expiry=data.acid_adjusted_expiry,
            acid_impact_status=acid_status,
            delay_kpi_suspended=delay_suspended,
            suspension_reason=suspension_reason,
            valuation_dispute_amount=dispute_amount,
            valuation_original_customs_val=data.valuation_original_customs_val,
            valuation_declared_val=data.valuation_declared_val,
            appeal_status=data.appeal_status or ("PENDING_APPEAL" if dispute_amount and dispute_amount > 0 else "NONE"),
            resolution_strategy=data.resolution_strategy,
            status="OPEN",
            created_by_user_id=current_user_id,
        )

        saved = self.repo.create(exception)
        self.db.commit()
        return saved

    def update_exception(
        self,
        exception_id: int,
        data: LogisticsExceptionUpdate,
        current_user_id: Optional[int] = None,
    ) -> LogisticsException:
        item = self.get_by_id(exception_id)
        validate_acid_dates(data.acid_original_expiry or item.acid_original_expiry, data.acid_adjusted_expiry or item.acid_adjusted_expiry)

        for field, value in data.model_dump(exclude_unset=True).items():
            setattr(item, field, value)

        item.updated_at = datetime.now(timezone.utc)
        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def resolve_acid_impact(
        self,
        exception_id: int,
        resolution: AcidImpactResolution,
        current_user_id: Optional[int] = None,
    ) -> LogisticsException:
        item = self.get_by_id(exception_id)
        validate_acid_dates(item.acid_original_expiry, resolution.acid_adjusted_expiry)

        item.acid_adjusted_expiry = resolution.acid_adjusted_expiry
        item.acid_impact_status = resolution.acid_impact_status
        if resolution.notes:
            prev_desc = item.description or ""
            item.description = f"{prev_desc}\n[ACID Alignment]: {resolution.notes}".strip()

        item.updated_at = datetime.now(timezone.utc)
        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def submit_valuation_appeal(
        self,
        exception_id: int,
        appeal: ValuationDisputeAppeal,
        current_user_id: Optional[int] = None,
    ) -> LogisticsException:
        item = self.get_by_id(exception_id)
        validate_valuation_dispute(
            appeal.valuation_original_customs_val,
            appeal.valuation_declared_val,
            appeal.valuation_dispute_amount,
        )

        item.valuation_original_customs_val = appeal.valuation_original_customs_val
        item.valuation_declared_val = appeal.valuation_declared_val
        item.valuation_dispute_amount = appeal.valuation_dispute_amount
        item.appeal_status = appeal.appeal_status
        if appeal.resolution_strategy:
            item.resolution_strategy = appeal.resolution_strategy

        prev_desc = item.description or ""
        item.description = f"{prev_desc}\n[Valuation Appeal]: {appeal.appeal_grounds}".strip()
        item.updated_at = datetime.now(timezone.utc)

        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def resolve_exception(
        self,
        exception_id: int,
        request: ExceptionResolveRequest,
        current_user_id: Optional[int] = None,
    ) -> LogisticsException:
        item = self.get_by_id(exception_id)
        validate_resolution_requirements(request.resolution_strategy)

        item.status = request.status
        item.resolution_strategy = request.resolution_strategy
        item.resolved_at = datetime.now(timezone.utc)
        item.resolved_by_user_id = current_user_id
        item.delay_kpi_suspended = False  # Reinstate KPIs upon resolution
        item.updated_at = datetime.now(timezone.utc)

        updated = self.repo.update(item)
        self.db.commit()
        return updated

    def delete_exception(self, exception_id: int) -> None:
        item = self.get_by_id(exception_id)
        self.repo.soft_delete(item)
        self.db.commit()

    def get_metrics(self) -> ExceptionMetricsOut:
        data = self.repo.get_metrics_data()
        return ExceptionMetricsOut(**data)
