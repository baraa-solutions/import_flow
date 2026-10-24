from datetime import date, datetime
from typing import Optional, Union
from fastapi import HTTPException, status


TERMINAL_ALIASES = {
    "ACCHCO": "ACCHCO",
    "ALEXANDRIA": "ACCHCO",
    "DEKHEILA": "ACCHCO",
    "EL_DEKHEILA": "ACCHCO",
    "EL DEKHEILA": "ACCHCO",
    "ALEX": "ACCHCO",
    "DPW_SOKHNA": "DP_WORLD_SOKHNA",
    "DP_WORLD_SOKHNA": "DP_WORLD_SOKHNA",
    "DP_WORLD": "DP_WORLD_SOKHNA",
    "DPW": "DP_WORLD_SOKHNA",
    "SOKHNA": "DP_WORLD_SOKHNA",
    "AIN_SOKHNA": "DP_WORLD_SOKHNA",
    "DCHC": "DCHC",
    "DAMIETTA": "DCHC",
    "SCCT": "SCCT",
    "EAST_PORT_SAID": "SCCT",
    "PORT_SAID_EAST": "SCCT",
    "PORT_SAID": "SCCT",
}

TERMINAL_NAMES = {
    "ACCHCO": "Alexandria Container & Cargo Handling Co. (Alexandria/Dekheila)",
    "DP_WORLD_SOKHNA": "DP World Sokhna",
    "DCHC": "Damietta Container & Cargo Handling Co. (Damietta)",
    "SCCT": "Suez Canal Container Terminal (East Port Said)",
}

VALID_CONTAINER_SIZES = {"20ft", "40ft"}
VALID_STATUSES = {"ESTIMATED", "INVOICED", "PAID"}


def normalize_terminal_code(raw_code: str) -> str:
    """
    Normalizes Egyptian container terminal code or alias.
    Raises HTTPException 400 if unrecognized.
    """
    if not raw_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Terminal code is required.",
        )
    clean = raw_code.strip().upper().replace("-", "_")
    key = "_".join(clean.split())
    if key in TERMINAL_ALIASES:
        return TERMINAL_ALIASES[key]
    
    # Partial matching check
    for alias, standard in TERMINAL_ALIASES.items():
        if alias in key or key in alias:
            return standard
            
    supported = ", ".join(sorted(list(TERMINAL_NAMES.keys())))
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=f"Unsupported terminal code '{raw_code}'. Supported Egyptian terminals: {supported}.",
    )


def normalize_container_size(raw_size: str) -> str:
    """Normalizes container size to '20ft' or '40ft'."""
    if not raw_size:
        return "20ft"
    clean = raw_size.strip().upper()
    if "40" in clean or "45" in clean:
        return "40ft"
    if "20" in clean:
        return "20ft"
    return "20ft"


def parse_date(value: Union[date, datetime, str, None]) -> Optional[date]:
    """Converts string/datetime/date to date."""
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


def validate_storage_dates(gate_in: date, end_date: date) -> None:
    """Validates date order for yard storage."""
    if end_date < gate_in:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"End/Gate-out date ({end_date}) cannot be earlier than Gate-in date ({gate_in}).",
        )


def duplicate_terminal_rate_error(
    terminal_code: str,
    container_size: str,
    is_reefer: bool,
    effective_date: date,
    existing_is_active: Optional[bool] = True,
) -> HTTPException:
    """409 for a rate card that would repeat uq_port_terminal_rate_unique."""
    kind = "مبرّدة" if is_reefer else "جافة"
    message = (
        f"يوجد بالفعل سعر أرضيات للمحطة {terminal_code} لحاوية {container_size} ({kind}) "
        f"يسري من {effective_date.isoformat()}."
    )
    if existing_is_active is False:
        message += " السعر الموجود محذوف، عدّله وأعد تفعيله بدلاً من إضافة سعر جديد."
    else:
        message += " عدّل السعر الموجود أو اختر تاريخ سريان مختلفاً."
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={
            "code": "PORT_TERMINAL_RATE_EXISTS",
            "message": message,
            "terminal_code": terminal_code,
            "container_size": container_size,
            "is_reefer": is_reefer,
            "effective_date": effective_date.isoformat(),
        },
    )


def validate_unique_terminal_rate(
    existing,
    terminal_code: str,
    container_size: str,
    is_reefer: bool,
    effective_date: date,
) -> None:
    """Raise 409 when another row (active or soft-deleted) already holds this rate card key."""
    if existing is not None:
        raise duplicate_terminal_rate_error(
            terminal_code, container_size, is_reefer, effective_date, existing.is_active
        )


def validate_accrual_status(status_str: str) -> str:
    """Validates accrual financial status."""
    clean = status_str.strip().upper()
    if clean not in VALID_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid accrual status '{status_str}'. Must be one of {sorted(list(VALID_STATUSES))}.",
        )
    return clean
