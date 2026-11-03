"""
Repository for Multimodal Freight Details
"""

from typing import List, Optional, Tuple
from sqlalchemy import func
from sqlalchemy.orm import Session
from modules.multimodal_freight.model import MultimodalFreightDetails


class MultimodalFreightRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, details_id: int) -> Optional[MultimodalFreightDetails]:
        return (
            self.db.query(MultimodalFreightDetails)
            .filter(
                MultimodalFreightDetails.id == details_id,
                MultimodalFreightDetails.is_deleted.is_(False),
            )
            .first()
        )

    def get_by_shipment_and_mode(
        self,
        shipment_id: int,
        transport_mode: str,
    ) -> Optional[MultimodalFreightDetails]:
        return (
            self.db.query(MultimodalFreightDetails)
            .filter(
                MultimodalFreightDetails.shipment_id == shipment_id,
                MultimodalFreightDetails.transport_mode == transport_mode,
                MultimodalFreightDetails.is_deleted.is_(False),
            )
            .first()
        )

    def list_by_shipment(
        self,
        shipment_id: int,
        transport_mode: Optional[str] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> Tuple[List[MultimodalFreightDetails], int]:
        query = self.db.query(MultimodalFreightDetails).filter(
            MultimodalFreightDetails.shipment_id == shipment_id,
            MultimodalFreightDetails.is_deleted.is_(False),
        )
        if transport_mode:
            query = query.filter(MultimodalFreightDetails.transport_mode == transport_mode)

        total = query.count()
        items = query.order_by(MultimodalFreightDetails.id.asc()).offset(skip).limit(limit).all()
        return items, total

    def count_modes(self, shipment_id: int) -> dict:
        rows = (
            self.db.query(
                MultimodalFreightDetails.transport_mode,
                func.count(MultimodalFreightDetails.id),
            )
            .filter(
                MultimodalFreightDetails.shipment_id == shipment_id,
                MultimodalFreightDetails.is_deleted.is_(False),
            )
            .group_by(MultimodalFreightDetails.transport_mode)
            .all()
        )
        return {mode: count for mode, count in rows}

    def create(self, details: MultimodalFreightDetails) -> MultimodalFreightDetails:
        self.db.add(details)
        self.db.flush()
        return details

    def save(self, details: MultimodalFreightDetails) -> MultimodalFreightDetails:
        self.db.flush()
        self.db.refresh(details)
        return details
