"""
modules/common/system_parameters.py
Generic key/value system parameters (``system_parameters`` table) for configurable business constants
that are not tariff data, e.g. the air volumetric factor.

Values are stored as text; readers parse them (``get_float_parameter``) and fall back to the documented
default when the row is missing, inactive or unparsable, so a fresh database behaves like the seeded one.
The Alembic migration that creates the table seeds the defaults; ``seed_default_parameters`` inserts any
missing default (insert-only, never overwrites a configured value). It runs on every startup through
``MasterDataSyncService.sync_all`` (``schema_upgrade_service``), so a new key only needs an entry in
``DEFAULT_PARAMETERS``, no migration.

Each default below is the module constant its reader falls back to (checked by tests/unit/test_review_wave_codes.py),
so seeding never changes a computed number. Readers:
- ``INSURANCE_*``: ``modules/cargo_insurance/service.py`` ``load_insurance_rates``
- ``DD_*``: ``modules/demurrage_detention/service.py`` (``default_tariff``, ``_standard_free_days``, cost avoidance);
  the two ``*_TIERS`` keys hold a JSON list read with ``get_parameter`` + ``json.loads`` (``_tiers_parameter``)
- ``settlement.*``: ``modules/financial_settlement/service.py`` ``ESTIMATE_PARAMETER_DEFAULTS`` (PL-08 estimate)
"""
from __future__ import annotations

import logging
import math
from datetime import datetime, timezone
from typing import Dict, Optional, Tuple

from sqlalchemy import Boolean, Column, DateTime, Integer, String, text
from sqlalchemy.orm import Session

from database.database import Base

logger = logging.getLogger(__name__)

AIR_VOLUMETRIC_KG_PER_CBM = "AIR_VOLUMETRIC_KG_PER_CBM"
DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM = 167.0

# Air freight suite (modules/air_freight): AWB volumetric divisors, free airport storage, review tolerance.
AIR_VOLUMETRIC_DIVISOR = "AIR_VOLUMETRIC_DIVISOR"
DEFAULT_AIR_VOLUMETRIC_DIVISOR = 6000.0
COURIER_VOLUMETRIC_DIVISOR = "COURIER_VOLUMETRIC_DIVISOR"
DEFAULT_COURIER_VOLUMETRIC_DIVISOR = 5000.0
AIR_FREE_STORAGE_DAYS = "AIR_FREE_STORAGE_DAYS"
DEFAULT_AIR_FREE_STORAGE_DAYS = 3.0
AIR_AWB_WEIGHT_TOLERANCE_PCT = "AIR_AWB_WEIGHT_TOLERANCE_PCT"
DEFAULT_AIR_AWB_WEIGHT_TOLERANCE_PCT = 0.5

# key -> (default value as stored text, description)
DEFAULT_PARAMETERS: Dict[str, Tuple[str, str]] = {
    AIR_VOLUMETRIC_KG_PER_CBM: (
        f"{DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM:g}",  # "167"
        "Air freight volumetric factor (kg per CBM) for chargeable weight; used by purchase orders and the CBM calculator",
    ),
    AIR_VOLUMETRIC_DIVISOR: (
        f"{DEFAULT_AIR_VOLUMETRIC_DIVISOR:g}",  # "6000"
        "IATA air freight volumetric divisor (cm3 per kg): volumetric kg = L x W x H (cm) / divisor; air AWB records",
    ),
    COURIER_VOLUMETRIC_DIVISOR: (
        f"{DEFAULT_COURIER_VOLUMETRIC_DIVISOR:g}",  # "5000"
        "Express courier volumetric divisor (cm3 per kg) for courier AWB records",
    ),
    AIR_FREE_STORAGE_DAYS: (
        f"{DEFAULT_AIR_FREE_STORAGE_DAYS:g}",  # "3"
        "Free airport storage days after cargo arrival before storage charges start (air AWB records)",
    ),
    AIR_AWB_WEIGHT_TOLERANCE_PCT: (
        f"{DEFAULT_AIR_AWB_WEIGHT_TOLERANCE_PCT:g}",  # "0.5"
        "Allowed gross / chargeable weight difference (percent) between a draft AWB and the shipment record",
    ),
    # ── Cargo insurance (04-05 shared needs) ──
    "INSURANCE_RATE_ICC_A": ("0.0025", "Cargo insurance base rate, Institute Cargo Clauses A (all risks)"),
    "INSURANCE_RATE_AIR_ALL_RISKS": ("0.0020", "Cargo insurance base rate, air cargo all risks"),
    "INSURANCE_RATE_ICC_B": ("0.0015", "Cargo insurance base rate, Institute Cargo Clauses B"),
    "INSURANCE_RATE_ICC_C": ("0.0010", "Cargo insurance base rate, Institute Cargo Clauses C"),
    "INSURANCE_WAR_STRIKES_RATE": ("0.0005", "War & strikes add-on rate on the insured value"),
    "INSURANCE_TAX_RATE": ("0.05", "Cargo insurance tax / stamp duty rate on (net premium + issuance fee)"),
    "INSURANCE_ISSUANCE_FEE": ("15", "Cargo insurance fixed certificate issuance fee (certificate currency)"),
    "INSURANCE_MIN_PREMIUM": ("30", "Cargo insurance minimum net premium (certificate currency)"),
    "INSURANCE_MARKUP": ("0.10", "Cargo insurance insured value markup on CIF (0.10 = 110% CIF)"),
    # ── Demurrage & detention defaults without a carrier policy (04-05 shared needs) ──
    "DD_DEFAULT_DEMURRAGE_TIERS": (
        '[{"from_day":1,"to_day":7,"rate_per_day":40.0},{"from_day":8,"to_day":14,"rate_per_day":70.0},'
        '{"from_day":15,"to_day":null,"rate_per_day":120.0}]',
        "Default demurrage tiers (USD per container per day, JSON list) when no carrier policy matches",
    ),
    "DD_DEFAULT_DETENTION_TIERS": (
        '[{"from_day":1,"to_day":7,"rate_per_day":35.0},{"from_day":8,"to_day":14,"rate_per_day":65.0},'
        '{"from_day":15,"to_day":null,"rate_per_day":110.0}]',
        "Default detention tiers (USD per container per day, JSON list) when no carrier policy matches",
    ),
    "DD_DEFAULT_FREE_DAYS_DEMURRAGE": ("5", "Default demurrage free days when no carrier policy matches (Standard shipping line default tariff)"),
    "DD_DEFAULT_FREE_DAYS_DETENTION": ("7", "Default detention free days when no carrier policy matches"),
    "DD_DEFAULT_STORAGE_FREE_DAYS": ("7", "Default port storage free days when no carrier policy matches (Egyptian port terminal standard free time)"),
    "DD_DEFAULT_STORAGE_RATE_EGP": (
        "250",
        "Default port storage rate (EGP per container per day) when no carrier policy matches",
    ),
    "DD_DEFAULT_TARIFF_CURRENCY": (
        "USD",
        "Default currency for demurrage and detention tariffs when no carrier policy matches",
    ),
    "DD_STANDARD_FREE_DAYS": ("5", "Standard free days used for the BK-02 cost-avoidance comparison (carrier standard baseline before negotiation)"),
    "DD_DEFAULT_NEGOTIATED_FREE_DAYS": ("21", "Commercial standard negotiated demurrage free days with shipping lines"),
    "DD_AVOIDANCE_RATE_USD": ("70", "USD per day per container used for the BK-02 estimated cost avoidance"),
    # ── Financial settlement PL-08 estimate constants (09 shared needs) ──
    "settlement.deemed_freight_pct": ("2", "Deemed freight as a percentage of FOB when no freight quote exists (PL-08)"),
    "settlement.deemed_insurance_pct": (
        "2.5",
        "Deemed insurance as a percentage of FOB when no insurance certificate exists (PL-08)",
    ),
    "settlement.default_clearance_egp": ("4500", "Default clearance fees (EGP) in the estimated landed cost"),
    "settlement.default_port_handling_egp": ("5000", "Default port handling charges (EGP) in the estimated landed cost"),
    "settlement.default_inland_transport_egp": ("7500", "Default inland transport cost (EGP) in the estimated landed cost"),
    "settlement.default_bank_fees_egp": ("2500", "Default bank fees (EGP) in the estimated landed cost"),
    "settlement.default_other_expenses_egp": ("2000", "Default other expenses (EGP) in the estimated landed cost"),
}


class SystemParameter(Base):
    __tablename__ = "system_parameters"

    param_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    param_key = Column(String(100), nullable=False, unique=True, index=True)
    param_value = Column(String(255), nullable=False)
    description = Column(String(255), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True, server_default=text("1"))
    created_at = Column(DateTime, nullable=True, default=lambda: datetime.now(timezone.utc))
    created_by = Column(String(100), nullable=True)
    updated_at = Column(
        DateTime,
        nullable=True,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    updated_by = Column(String(100), nullable=True)


def get_parameter(db: Session, key: str) -> Optional[str]:
    """The stored text of an active parameter, or ``None``."""
    row = (
        db.query(SystemParameter.param_value)
        .filter(SystemParameter.param_key == key, SystemParameter.is_active.is_(True))
        .first()
    )
    return row[0] if row else None


def get_float_parameter(
    db: Session,
    key: str,
    default: float,
    *,
    min_value: Optional[float] = None,
    max_value: Optional[float] = None,
) -> float:
    """Active parameter parsed as float; ``default`` when missing, unparsable, not finite (NaN / inf) or outside
    the optional inclusive range ``[min_value, max_value]`` (every fallback except "missing" is logged).

    Example: ``get_float_parameter(db, "INSURANCE_TAX_RATE", 0.05, min_value=0, max_value=1)``."""
    raw = get_parameter(db, key)
    if raw is None:
        return default
    try:
        value = float(str(raw).strip())
    except ValueError:
        logger.warning("System parameter %s has a non-numeric value %r; using default %s", key, raw, default)
        return default
    if not math.isfinite(value):
        logger.warning("System parameter %s is not a finite number (%r); using default %s", key, raw, default)
        return default
    if (min_value is not None and value < min_value) or (max_value is not None and value > max_value):
        logger.warning(
            "System parameter %s = %s is outside [%s, %s]; using default %s", key, value, min_value, max_value, default
        )
        return default
    return value


def air_volumetric_kg_per_cbm(db: Session) -> float:
    """The single air volumetric factor (kg per CBM). Non-positive values fall back to the default."""
    value = get_float_parameter(db, AIR_VOLUMETRIC_KG_PER_CBM, DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM)
    if value <= 0:
        logger.warning("System parameter %s must be positive (got %s); using default", AIR_VOLUMETRIC_KG_PER_CBM, value)
        return DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM
    return value


def seed_default_parameters(db: Session, actor: str = "system") -> int:
    """Insert every missing default parameter (existing keys, active or not, are left alone). Commits."""
    existing = {k for (k,) in db.query(SystemParameter.param_key).all()}
    added = 0
    for key, (value, description) in DEFAULT_PARAMETERS.items():
        if key in existing:
            continue
        db.add(SystemParameter(param_key=key, param_value=value, description=description, created_by=actor, updated_by=actor))
        added += 1
    if added:
        db.commit()
    return added
