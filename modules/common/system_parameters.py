"""
modules/common/system_parameters.py
Generic key/value system parameters (``system_parameters`` table) for configurable business constants
that are not tariff data, e.g. the air volumetric factor.

Values are stored as text; readers parse them (``get_float_parameter``) and fall back to the documented
default when the row is missing, inactive or unparsable, so a fresh database behaves like the seeded one.
The Alembic migration that creates the table seeds the defaults; ``seed_default_parameters`` inserts any
missing default (insert-only, never overwrites a configured value).
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Dict, Optional, Tuple

from sqlalchemy import Boolean, Column, DateTime, Integer, String, text
from sqlalchemy.orm import Session

from database.database import Base

logger = logging.getLogger(__name__)

AIR_VOLUMETRIC_KG_PER_CBM = "AIR_VOLUMETRIC_KG_PER_CBM"
DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM = 167.0

# key -> (default value as stored text, description)
DEFAULT_PARAMETERS: Dict[str, Tuple[str, str]] = {
    AIR_VOLUMETRIC_KG_PER_CBM: (
        f"{DEFAULT_AIR_VOLUMETRIC_KG_PER_CBM:g}",  # "167"
        "Air freight volumetric factor (kg per CBM) for chargeable weight; used by purchase orders and the CBM calculator",
    ),
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


def get_float_parameter(db: Session, key: str, default: float) -> float:
    """Active parameter parsed as float; ``default`` when missing or unparsable (logged)."""
    raw = get_parameter(db, key)
    if raw is None:
        return default
    try:
        return float(str(raw).strip())
    except ValueError:
        logger.warning("System parameter %s has a non-numeric value %r; using default %s", key, raw, default)
        return default


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
