"""
Repository for Container Tracking & Demurrage Charges
"""

from typing import List, Optional, Tuple
from sqlalchemy import func, select
from sqlalchemy.orm import Session
from modules.container_tracking.model import (
    ContainerLifecycleUnit,
    ContainerDemurrageCharge,
)


class ContainerTrackingRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, container_id: int) -> Optional[ContainerLifecycleUnit]:
        return (
            self.db.query(ContainerLifecycleUnit)
            .filter(
                ContainerLifecycleUnit.id == container_id,
                ContainerLifecycleUnit.is_deleted.is_(False),
            )
            .first()
        )

    def get_by_number(self, shipment_id: int, container_number: str) -> Optional[ContainerLifecycleUnit]:
        return (
            self.db.query(ContainerLifecycleUnit)
            .filter(
                ContainerLifecycleUnit.shipment_id == shipment_id,
                ContainerLifecycleUnit.container_number == container_number,
                ContainerLifecycleUnit.is_deleted.is_(False),
            )
            .first()
        )

    def list_by_shipment(
        self,
        shipment_id: int,
        status: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[ContainerLifecycleUnit], int]:
        query = self.db.query(ContainerLifecycleUnit).filter(
            ContainerLifecycleUnit.shipment_id == shipment_id,
            ContainerLifecycleUnit.is_deleted.is_(False),
        )
        if status:
            query = query.filter(ContainerLifecycleUnit.status == status)

        total = query.count()
        items = query.order_by(ContainerLifecycleUnit.id.asc()).offset(skip).limit(limit).all()
        return items, total

    def count_statuses(self, shipment_id: int) -> dict:
        rows = (
            self.db.query(ContainerLifecycleUnit.status, func.count(ContainerLifecycleUnit.id))
            .filter(
                ContainerLifecycleUnit.shipment_id == shipment_id,
                ContainerLifecycleUnit.is_deleted.is_(False),
            )
            .group_by(ContainerLifecycleUnit.status)
            .all()
        )
        return {status: count for status, count in rows}

    def create(
        self,
        unit: ContainerLifecycleUnit,
    ) -> ContainerLifecycleUnit:
        self.db.add(unit)
        self.db.flush()
        return unit

    def save(self, unit: ContainerLifecycleUnit) -> ContainerLifecycleUnit:
        self.db.flush()
        self.db.refresh(unit)
        return unit

    # -------------------------------------------------------------------------
    # Demurrage Charges Repository Methods
    # -------------------------------------------------------------------------

    def get_demurrage_by_id(self, demurrage_id: int) -> Optional[ContainerDemurrageCharge]:
        return (
            self.db.query(ContainerDemurrageCharge)
            .filter(
                ContainerDemurrageCharge.id == demurrage_id,
                ContainerDemurrageCharge.is_deleted.is_(False),
            )
            .first()
        )

    def get_demurrage_by_container_id(self, container_id: int) -> Optional[ContainerDemurrageCharge]:
        return (
            self.db.query(ContainerDemurrageCharge)
            .filter(
                ContainerDemurrageCharge.container_id == container_id,
                ContainerDemurrageCharge.is_deleted.is_(False),
            )
            .order_by(ContainerDemurrageCharge.id.desc())
            .first()
        )

    def create_demurrage(
        self,
        demurrage: ContainerDemurrageCharge,
    ) -> ContainerDemurrageCharge:
        self.db.add(demurrage)
        self.db.flush()
        return demurrage

    def save_demurrage(self, demurrage: ContainerDemurrageCharge) -> ContainerDemurrageCharge:
        self.db.flush()
        self.db.refresh(demurrage)
        return demurrage
