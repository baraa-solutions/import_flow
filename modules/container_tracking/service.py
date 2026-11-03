"""
Service for Container Tracking & Demurrage Charges
"""

from datetime import date, datetime, timedelta, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.container_tracking.model import (
    ContainerLifecycleUnit,
    ContainerDemurrageCharge,
)
from modules.container_tracking.repository import ContainerTrackingRepository
from modules.container_tracking.schemas import (
    ContainerLifecycleUnitCreate,
    ContainerLifecycleUnitUpdate,
    ContainerDemurrageCreate,
    ContainerDemurrageUpdate,
    DemurrageCalculationResult,
    ContainerStatus,
)
from modules.container_tracking.validators import (
    validate_container_number,
    validate_container_dates,
    validate_container_weights,
)


class ContainerTrackingService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = ContainerTrackingRepository(db)

    def create_container(
        self,
        payload: ContainerLifecycleUnitCreate,
        user_id: Optional[int] = None,
    ) -> ContainerLifecycleUnit:
        # 1. Validation
        clean_number = validate_container_number(payload.container_number)
        existing = self.repo.get_by_number(payload.shipment_id, clean_number)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Container {clean_number} already exists for shipment #{payload.shipment_id}.",
            )

        validate_container_dates(
            payload.discharge_date,
            payload.gate_out_held_date,
            payload.empty_returned_date,
        )
        validate_container_weights(
            payload.tare_weight,
            payload.payload_weight,
            payload.gross_weight,
            payload.vgm_weight,
        )

        # 2. Derive status automatically if not explicitly given or changed
        computed_status = payload.status
        if payload.empty_returned_date:
            computed_status = ContainerStatus.RETURNED_EMPTY
        elif payload.gate_out_held_date:
            computed_status = ContainerStatus.GATE_OUT_HELD
        elif payload.discharge_date:
            computed_status = ContainerStatus.DISCHARGED

        unit = ContainerLifecycleUnit(
            container_number=clean_number,
            seal_number=payload.seal_number.strip() if payload.seal_number else None,
            iso_type=payload.iso_type.strip().upper(),
            tare_weight=payload.tare_weight,
            payload_weight=payload.payload_weight,
            gross_weight=payload.gross_weight,
            vgm_weight=payload.vgm_weight,
            discharge_date=payload.discharge_date,
            gate_out_held_date=payload.gate_out_held_date,
            empty_returned_date=payload.empty_returned_date,
            status=computed_status.value if isinstance(computed_status, ContainerStatus) else computed_status,
            shipment_id=payload.shipment_id,
            notes=payload.notes,
            created_by_user_id=user_id,
            updated_by_user_id=user_id,
        )
        self.repo.create(unit)

        # 3. Create initial demurrage charge tracking if free_time or rate configured
        free_days = payload.initial_free_time_days or 14
        rate = payload.daily_demurrage_rate or 0.0
        free_end = None
        if payload.discharge_date:
            free_end = payload.discharge_date + timedelta(days=free_days)

        demurrage = ContainerDemurrageCharge(
            container_id=unit.id,
            free_time_days=free_days,
            free_time_end_date=free_end,
            daily_demurrage_rate=rate,
            actual_return_date=payload.empty_returned_date,
            currency=payload.currency or "USD",
            created_by_user_id=user_id,
            updated_by_user_id=user_id,
        )
        self.repo.create_demurrage(demurrage)
        self._recalculate_demurrage_charge(demurrage, unit)

        self.db.commit()
        return self.repo.get_by_id(unit.id)

    def update_container(
        self,
        container_id: int,
        payload: ContainerLifecycleUnitUpdate,
        user_id: Optional[int] = None,
    ) -> ContainerLifecycleUnit:
        unit = self.repo.get_by_id(container_id)
        if not unit:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Container unit #{container_id} not found.",
            )

        if payload.container_number is not None:
            clean_num = validate_container_number(payload.container_number)
            if clean_num != unit.container_number:
                existing = self.repo.get_by_number(unit.shipment_id, clean_num)
                if existing and existing.id != container_id:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail=f"Container {clean_num} already exists in this shipment.",
                    )
                unit.container_number = clean_num

        if payload.seal_number is not None:
            unit.seal_number = payload.seal_number.strip() if payload.seal_number else None
        if payload.iso_type is not None:
            unit.iso_type = payload.iso_type.strip().upper()

        new_tare = payload.tare_weight if payload.tare_weight is not None else unit.tare_weight
        new_payload = payload.payload_weight if payload.payload_weight is not None else unit.payload_weight
        new_gross = payload.gross_weight if payload.gross_weight is not None else unit.gross_weight
        new_vgm = payload.vgm_weight if payload.vgm_weight is not None else unit.vgm_weight
        validate_container_weights(new_tare, new_payload, new_gross, new_vgm)

        unit.tare_weight = new_tare
        unit.payload_weight = new_payload
        unit.gross_weight = new_gross
        unit.vgm_weight = new_vgm

        new_discharge = payload.discharge_date if payload.discharge_date is not None else unit.discharge_date
        new_gate_out = payload.gate_out_held_date if payload.gate_out_held_date is not None else unit.gate_out_held_date
        new_empty = payload.empty_returned_date if payload.empty_returned_date is not None else unit.empty_returned_date
        validate_container_dates(new_discharge, new_gate_out, new_empty)

        unit.discharge_date = new_discharge
        unit.gate_out_held_date = new_gate_out
        unit.empty_returned_date = new_empty

        # Dynamic state progression
        if payload.status is not None:
            unit.status = payload.status.value if isinstance(payload.status, ContainerStatus) else payload.status
        else:
            if unit.status != ContainerStatus.DAMAGED.value:
                if unit.empty_returned_date:
                    unit.status = ContainerStatus.RETURNED_EMPTY.value
                elif unit.gate_out_held_date:
                    unit.status = ContainerStatus.GATE_OUT_HELD.value
                elif unit.discharge_date:
                    unit.status = ContainerStatus.DISCHARGED.value

        if payload.notes is not None:
            unit.notes = payload.notes

        unit.updated_by_user_id = user_id
        unit.updated_at = datetime.now(timezone.utc)

        # Synchronize demurrage charges
        demurrage = self.repo.get_demurrage_by_container_id(unit.id)
        if demurrage:
            if payload.empty_returned_date is not None:
                demurrage.actual_return_date = new_empty
            self._recalculate_demurrage_charge(demurrage, unit)

        self.db.commit()
        return self.repo.get_by_id(unit.id)

    def soft_delete_container(self, container_id: int, user_id: Optional[int] = None) -> bool:
        unit = self.repo.get_by_id(container_id)
        if not unit:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Container unit #{container_id} not found.",
            )
        unit.is_deleted = True
        unit.updated_by_user_id = user_id
        unit.updated_at = datetime.now(timezone.utc)

        demurrage = self.repo.get_demurrage_by_container_id(container_id)
        if demurrage:
            demurrage.is_deleted = True
            demurrage.updated_by_user_id = user_id
            demurrage.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        return True

    def calculate_demurrage(
        self,
        container_id: int,
        user_id: Optional[int] = None,
    ) -> DemurrageCalculationResult:
        unit = self.repo.get_by_id(container_id)
        if not unit:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Container unit #{container_id} not found.",
            )

        demurrage = self.repo.get_demurrage_by_container_id(container_id)
        if not demurrage:
            demurrage = ContainerDemurrageCharge(
                container_id=unit.id,
                free_time_days=14,
                daily_demurrage_rate=0.0,
                created_by_user_id=user_id,
            )
            self.repo.create_demurrage(demurrage)

        self._recalculate_demurrage_charge(demurrage, unit)
        self.db.commit()

        effective_return = demurrage.actual_return_date or unit.empty_returned_date
        return DemurrageCalculationResult(
            container_id=unit.id,
            free_time_days=demurrage.free_time_days,
            free_time_end_date=demurrage.free_time_end_date,
            effective_return_date=effective_return,
            days_overdue=demurrage.days_overdue,
            daily_demurrage_rate=demurrage.daily_demurrage_rate,
            total_demurrage_amount=demurrage.total_demurrage_amount,
            currency=demurrage.currency,
        )

    def update_demurrage_settings(
        self,
        container_id: int,
        payload: ContainerDemurrageUpdate,
        user_id: Optional[int] = None,
    ) -> ContainerDemurrageCharge:
        unit = self.repo.get_by_id(container_id)
        if not unit:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Container unit #{container_id} not found.",
            )

        demurrage = self.repo.get_demurrage_by_container_id(container_id)
        if not demurrage:
            demurrage = ContainerDemurrageCharge(
                container_id=unit.id,
                created_by_user_id=user_id,
            )
            self.repo.create_demurrage(demurrage)

        if payload.free_time_days is not None:
            demurrage.free_time_days = payload.free_time_days
        if payload.free_time_end_date is not None:
            demurrage.free_time_end_date = payload.free_time_end_date
        if payload.daily_demurrage_rate is not None:
            demurrage.daily_demurrage_rate = payload.daily_demurrage_rate
        if payload.actual_return_date is not None:
            demurrage.actual_return_date = payload.actual_return_date
        if payload.currency is not None:
            demurrage.currency = payload.currency.upper()
        if payload.notes is not None:
            demurrage.notes = payload.notes

        demurrage.updated_by_user_id = user_id
        demurrage.updated_at = datetime.now(timezone.utc)

        self._recalculate_demurrage_charge(demurrage, unit)
        self.db.commit()
        return demurrage

    def _recalculate_demurrage_charge(
        self,
        demurrage: ContainerDemurrageCharge,
        unit: ContainerLifecycleUnit,
    ) -> None:
        """Internal helper for calculating demurrage accruals."""
        # 1. Calculate free_time_end_date from discharge_date if available
        if unit.discharge_date and demurrage.free_time_days:
            demurrage.free_time_end_date = unit.discharge_date + timedelta(days=demurrage.free_time_days)

        effective_return = demurrage.actual_return_date or unit.empty_returned_date
        # If returned, use actual return date. If not returned and free time expired, use today.
        comparison_date = effective_return or date.today()

        if demurrage.free_time_end_date and comparison_date > demurrage.free_time_end_date:
            days_over = (comparison_date - demurrage.free_time_end_date).days
            demurrage.days_overdue = max(0, days_over)
        else:
            demurrage.days_overdue = 0

        demurrage.total_demurrage_amount = round(
            demurrage.days_overdue * demurrage.daily_demurrage_rate, 2
        )
