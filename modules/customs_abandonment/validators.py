from datetime import date, datetime
from typing import Optional, Union
from fastapi import HTTPException, status

VALID_PORT_TYPES = {"SEAPORT", "DRY_PORT", "AIRPORT"}

VALID_RISK_LEVELS = {
    "NORMAL",
    "WARNING_15_DAYS",
    "CRITICAL_7_DAYS",
    "UNDER_ABANDONMENT_INVENTORY",
}

VALID_ABANDONMENT_STATUSES = {
    "ACTIVE_CLEARING",
    "EXTENSION_PENDING",
    "MOVED_TO_ABANDONED_WAREHOUSE",
    "AUCTION_SCHEDULED",
    "RESOLVED_RELEASED",
}


def normalize_port_type(raw_type: str) -> str:
    """Normalizes port type to SEAPORT, DRY_PORT, or AIRPORT."""
    if not raw_type:
        return "SEAPORT"
    clean = raw_type.strip().upper().replace(" ", "_")
    if "AIR" in clean or "جوي" in clean or "مطار" in clean:
        return "AIRPORT"
    if "DRY" in clean or "جاف" in clean:
        return "DRY_PORT"
    if "SEA" in clean or "بحر" in clean or "PORT" in clean:
        return "SEAPORT"
    if clean in VALID_PORT_TYPES:
        return clean
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=f"Invalid port type '{raw_type}'. Supported: {sorted(list(VALID_PORT_TYPES))}.",
    )


def validate_risk_level(risk_level: str) -> str:
    clean = risk_level.strip().upper()
    if clean not in VALID_RISK_LEVELS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid risk level '{risk_level}'. Supported: {sorted(list(VALID_RISK_LEVELS))}.",
        )
    return clean


def validate_abandonment_status(status_str: str) -> str:
    clean = status_str.strip().upper()
    if clean not in VALID_ABANDONMENT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid abandonment status '{status_str}'. Supported: {sorted(list(VALID_ABANDONMENT_STATUSES))}.",
        )
    return clean


def parse_date(value: Union[date, datetime, str, None]) -> Optional[date]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        try:
            return date.fromisoformat(value.strip())
        except ValueError:
            try:
                return datetime.strptime(value.strip(), "%Y-%m-%d").date()
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid date format '{value}'. Expected YYYY-MM-DD.",
                )
    return None
