"""
Service for Multimodal Freight Details
"""

from datetime import datetime, timezone
from typing import Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from modules.multimodal_freight.model import MultimodalFreightDetails
from modules.multimodal_freight.repository import MultimodalFreightRepository
from modules.multimodal_freight.schemas import (
    MultimodalFreightCreate,
    MultimodalFreightUpdate,
    ModeCostCalculationResult,
    TransportMode,
)
from modules.multimodal_freight.validators import validate_multimodal_payload


class MultimodalFreightService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = MultimodalFreightRepository(db)

    def create_details(
        self,
        payload: MultimodalFreightCreate,
        user_id: Optional[int] = None,
    ) -> MultimodalFreightDetails:
        validate_multimodal_payload(
            transport_mode=payload.transport_mode,
            awb_number=payload.awb_number,
            terminal_handling_charges=payload.terminal_handling_charges,
            lcl_cbm=payload.lcl_cbm,
            lcl_rate_per_cbm=payload.lcl_rate_per_cbm,
            roro_vehicle_type=payload.roro_vehicle_type,
            roro_dimensions_cbm=payload.roro_dimensions_cbm,
            bulk_cargo_type=payload.bulk_cargo_type,
            bulk_tonnage=payload.bulk_tonnage,
        )

        details = MultimodalFreightDetails(
            shipment_id=payload.shipment_id,
            transport_mode=payload.transport_mode.value,
            awb_number=payload.awb_number.strip().upper() if payload.awb_number else None,
            airline_code=payload.airline_code.strip().upper() if payload.airline_code else None,
            flight_number=payload.flight_number.strip().upper() if payload.flight_number else None,
            terminal_handling_charges=payload.terminal_handling_charges or 0.0,
            lcl_cbm=payload.lcl_cbm or 0.0,
            lcl_rate_per_cbm=payload.lcl_rate_per_cbm or 0.0,
            lcl_cfs_fee=payload.lcl_cfs_fee or 0.0,
            roro_vehicle_type=payload.roro_vehicle_type.strip().upper() if payload.roro_vehicle_type else None,
            roro_dimensions_cbm=payload.roro_dimensions_cbm or 0.0,
            bulk_cargo_type=payload.bulk_cargo_type.strip().upper() if payload.bulk_cargo_type else None,
            bulk_tonnage=payload.bulk_tonnage or 0.0,
            special_handling_notes=payload.special_handling_notes,
            created_by_user_id=user_id,
            updated_by_user_id=user_id,
        )
        self.repo.create(details)
        self.db.commit()
        return self.repo.get_by_id(details.id)

    def update_details(
        self,
        details_id: int,
        payload: MultimodalFreightUpdate,
        user_id: Optional[int] = None,
    ) -> MultimodalFreightDetails:
        details = self.repo.get_by_id(details_id)
        if not details:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Freight details #{details_id} not found.",
            )

        target_mode = payload.transport_mode or TransportMode(details.transport_mode)
        validate_multimodal_payload(
            transport_mode=target_mode,
            awb_number=payload.awb_number if payload.awb_number is not None else details.awb_number,
            terminal_handling_charges=payload.terminal_handling_charges if payload.terminal_handling_charges is not None else details.terminal_handling_charges,
            lcl_cbm=payload.lcl_cbm if payload.lcl_cbm is not None else details.lcl_cbm,
            lcl_rate_per_cbm=payload.lcl_rate_per_cbm if payload.lcl_rate_per_cbm is not None else details.lcl_rate_per_cbm,
            roro_vehicle_type=payload.roro_vehicle_type if payload.roro_vehicle_type is not None else details.roro_vehicle_type,
            roro_dimensions_cbm=payload.roro_dimensions_cbm if payload.roro_dimensions_cbm is not None else details.roro_dimensions_cbm,
            bulk_cargo_type=payload.bulk_cargo_type if payload.bulk_cargo_type is not None else details.bulk_cargo_type,
            bulk_tonnage=payload.bulk_tonnage if payload.bulk_tonnage is not None else details.bulk_tonnage,
        )

        if payload.transport_mode is not None:
            details.transport_mode = payload.transport_mode.value
        if payload.awb_number is not None:
            details.awb_number = payload.awb_number.strip().upper() if payload.awb_number else None
        if payload.airline_code is not None:
            details.airline_code = payload.airline_code.strip().upper() if payload.airline_code else None
        if payload.flight_number is not None:
            details.flight_number = payload.flight_number.strip().upper() if payload.flight_number else None
        if payload.terminal_handling_charges is not None:
            details.terminal_handling_charges = payload.terminal_handling_charges
        if payload.lcl_cbm is not None:
            details.lcl_cbm = payload.lcl_cbm
        if payload.lcl_rate_per_cbm is not None:
            details.lcl_rate_per_cbm = payload.lcl_rate_per_cbm
        if payload.lcl_cfs_fee is not None:
            details.lcl_cfs_fee = payload.lcl_cfs_fee
        if payload.roro_vehicle_type is not None:
            details.roro_vehicle_type = payload.roro_vehicle_type.strip().upper() if payload.roro_vehicle_type else None
        if payload.roro_dimensions_cbm is not None:
            details.roro_dimensions_cbm = payload.roro_dimensions_cbm
        if payload.bulk_cargo_type is not None:
            details.bulk_cargo_type = payload.bulk_cargo_type.strip().upper() if payload.bulk_cargo_type else None
        if payload.bulk_tonnage is not None:
            details.bulk_tonnage = payload.bulk_tonnage
        if payload.special_handling_notes is not None:
            details.special_handling_notes = payload.special_handling_notes

        details.updated_by_user_id = user_id
        details.updated_at = datetime.now(timezone.utc)

        self.db.commit()
        return self.repo.get_by_id(details.id)

    def soft_delete_details(self, details_id: int, user_id: Optional[int] = None) -> bool:
        details = self.repo.get_by_id(details_id)
        if not details:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Freight details #{details_id} not found.",
            )
        details.is_deleted = True
        details.updated_by_user_id = user_id
        details.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        return True

    def calculate_subtotal(self, details: MultimodalFreightDetails) -> float:
        mode = details.transport_mode
        if mode == "AIR":
            return round(details.terminal_handling_charges or 0.0, 2)
        elif mode == "LCL":
            cbm_cost = (details.lcl_cbm or 0.0) * (details.lcl_rate_per_cbm or 0.0)
            cfs_cost = details.lcl_cfs_fee or 0.0
            return round(cbm_cost + cfs_cost, 2)
        elif mode == "RORO":
            return round((details.roro_dimensions_cbm or 0.0) * 120.0, 2)  # Benchmark baseline rate
        elif mode == "BULK":
            return round((details.bulk_tonnage or 0.0) * 45.0, 2)  # Benchmark baseline rate
        return 0.0

    def calculate_mode_costs(self, details_id: int) -> ModeCostCalculationResult:
        details = self.repo.get_by_id(details_id)
        if not details:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Freight details #{details_id} not found.",
            )

        subtotal = self.calculate_subtotal(details)
        breakdown = {
            "mode": details.transport_mode,
            "subtotal": subtotal,
        }
        if details.transport_mode == "AIR":
            breakdown["terminal_handling_charges"] = details.terminal_handling_charges
        elif details.transport_mode == "LCL":
            breakdown["cbm_charge"] = round((details.lcl_cbm or 0.0) * (details.lcl_rate_per_cbm or 0.0), 2)
            breakdown["cfs_fee"] = details.lcl_cfs_fee
        elif details.transport_mode == "RORO":
            breakdown["cbm"] = details.roro_dimensions_cbm
        elif details.transport_mode == "BULK":
            breakdown["tonnage"] = details.bulk_tonnage

        return ModeCostCalculationResult(
            details_id=details.id,
            shipment_id=details.shipment_id,
            transport_mode=details.transport_mode,
            calculated_freight_subtotal=subtotal,
            breakdown=breakdown,
        )
