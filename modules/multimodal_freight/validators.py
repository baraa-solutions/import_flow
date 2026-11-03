"""
Validators for Multimodal Freight Details
"""

from typing import Optional
from fastapi import HTTPException, status
from modules.multimodal_freight.schemas import TransportMode


def validate_multimodal_payload(
    transport_mode: TransportMode,
    awb_number: Optional[str] = None,
    terminal_handling_charges: Optional[float] = None,
    lcl_cbm: Optional[float] = None,
    lcl_rate_per_cbm: Optional[float] = None,
    roro_vehicle_type: Optional[str] = None,
    roro_dimensions_cbm: Optional[float] = None,
    bulk_cargo_type: Optional[str] = None,
    bulk_tonnage: Optional[float] = None,
) -> None:
    mode_str = transport_mode.value if isinstance(transport_mode, TransportMode) else str(transport_mode)

    if mode_str == "AIR":
        if not awb_number or not awb_number.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="AWB (Air Waybill) number is required for Air Freight.",
            )
        if terminal_handling_charges is not None and terminal_handling_charges < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Terminal handling charges cannot be negative.",
            )

    elif mode_str == "LCL":
        if lcl_cbm is not None and lcl_cbm <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="LCL cargo volume (CBM) must be greater than zero.",
            )
        if lcl_rate_per_cbm is not None and lcl_rate_per_cbm < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="LCL freight rate per CBM cannot be negative.",
            )

    elif mode_str == "RORO":
        if not roro_vehicle_type or not roro_vehicle_type.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Vehicle or machinery type is required for Ro-Ro freight.",
            )
        if roro_dimensions_cbm is not None and roro_dimensions_cbm <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ro-Ro vehicle dimensions (CBM) must be greater than zero.",
            )

    elif mode_str == "BULK":
        if not bulk_cargo_type or not bulk_cargo_type.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bulk commodity type is required for Bulk cargo.",
            )
        if bulk_tonnage is not None and bulk_tonnage <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bulk tonnage must be greater than zero.",
            )
