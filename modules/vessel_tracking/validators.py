import re
from typing import Tuple


def clean_imo_number(imo: str | None) -> str | None:
    """Strip spaces and optional 'IMO' prefix, returning clean 7-digit string."""
    if not imo:
        return None
    cleaned = re.sub(r"[^\d]", "", imo.strip().upper())
    return cleaned if len(cleaned) == 7 else None


def validate_imo_checksum(imo_digits: str) -> bool:
    """
    Validates official IMO 7-digit checksum:
    multiply first 6 digits by weights 7..2, modulo 10 must equal the 7th digit.
    """
    if not imo_digits or len(imo_digits) != 7 or not imo_digits.isdigit():
        return False
    digits = [int(d) for d in imo_digits]
    calculated_check = sum(digits[i] * (7 - i) for i in range(6)) % 10
    return calculated_check == digits[6]


def validate_mmsi_number(mmsi: str | None) -> bool:
    """MMSI must be a 9-digit numeric code with valid MID prefix."""
    if not mmsi:
        return False
    cleaned = re.sub(r"[^\d]", "", mmsi.strip())
    if len(cleaned) != 9 or not cleaned.isdigit():
        return False
    mid = int(cleaned[:3])
    # Maritime Identification Digits are typically 201-775
    return 201 <= mid <= 775


def validate_coordinates(latitude: float, longitude: float) -> Tuple[bool, str | None]:
    """Ensures geographical coordinates fall within standard Earth projection bounds."""
    if not (-90.0 <= latitude <= 90.0):
        return False, f"Invalid latitude {latitude}. Must be between -90 and 90."
    if not (-180.0 <= longitude <= 180.0):
        return False, f"Invalid longitude {longitude}. Must be between -180 and 180."
    return True, None


def validate_navigational_speed(speed_knots: float) -> Tuple[bool, str | None]:
    """Validates realistic vessel operating speed in knots."""
    if speed_knots < 0.0 or speed_knots > 45.0:
        return False, f"Vessel speed {speed_knots} knots is out of normal maritime range (0-45 kts)."
    return True, None
