"""
modules/common/shipment_modes.py
Shipment transport taxonomy: one main ``mode`` plus an optional ``sub_mode`` (decision 2026-11-09, Trello pvTMSOaV).

- Main modes: SEA, AIR, COURIER, LAND, MULTIMODAL.
- Sub-modes belong to exactly one main mode (FCL / LCL / RORO / BULK / BREAK_BULK under SEA, ...).
- The ACID filing status is NOT part of the taxonomy: it stays the separately computed ``acid_requirement``
  (``import_file_lifecycle_service.evaluate_acid_requirement``), so "AIR_EXEMPT"-style flat codes never exist.

``import_files.shipment_mode`` still stores legacy labels ("Sea FCL", "Air", ...). ``split_legacy_mode`` reads them
into a ``(mode, sub_mode)`` pair without touching stored data, so new modules can reason in codes today.

Pure module: no database access.
"""
from __future__ import annotations

import re
from typing import Dict, Optional, Tuple

SEA, AIR, COURIER, LAND, MULTIMODAL = "SEA", "AIR", "COURIER", "LAND", "MULTIMODAL"

MODES: Tuple[str, ...] = (SEA, AIR, COURIER, LAND, MULTIMODAL)

# main mode -> allowed sub-modes (order = display order)
SUB_MODES: Dict[str, Tuple[str, ...]] = {
    SEA: ("FCL", "LCL", "RORO", "BULK", "BREAK_BULK"),
    AIR: ("GENERAL_CARGO", "CONSOLIDATED", "CHARTER", "DANGEROUS_GOODS", "PERISHABLE"),
    COURIER: ("EXPRESS", "POSTAL"),
    LAND: ("FTL", "LTL"),
    MULTIMODAL: ("SEA_AIR", "SEA_LAND", "AIR_LAND"),
}

LABELS_EN: Dict[str, str] = {
    SEA: "Sea Freight", AIR: "Air Freight", COURIER: "Express Courier", LAND: "Land Freight",
    MULTIMODAL: "Multimodal",
}
LABELS_AR: Dict[str, str] = {
    SEA: "شحن بحري", AIR: "شحن جوي", COURIER: "بريد سريع", LAND: "شحن بري", MULTIMODAL: "شحن متعدد الوسائط",
}

# Modes whose freight is billed on chargeable weight (volumetric vs gross).
WEIGHT_BILLED_MODES: Tuple[str, ...] = (AIR, COURIER)

_WORD_RE = re.compile(r"[^A-Z0-9]+")


def normalize_mode(value: Optional[str]) -> Optional[str]:
    """A main-mode code from a code or a legacy label ("Sea FCL" -> SEA, "Air" -> AIR, "ocean" -> SEA).
    ``None`` / blank -> ``None``. Raises ``ValueError`` for anything unrecognised."""
    mode, _ = split_legacy_mode(value)
    if mode is None and value is not None and str(value).strip():
        raise ValueError(f"Unknown shipment mode: {value!r}")
    return mode


def _tokens(value: Optional[str]) -> Tuple[str, ...]:
    return tuple(t for t in _WORD_RE.split(str(value or "").upper()) if t)


def split_legacy_mode(value: Optional[str], sub_mode: Optional[str] = None) -> Tuple[Optional[str], Optional[str]]:
    """``(mode, sub_mode)`` codes from a stored value. Accepts codes ("AIR", "SEA") and the legacy labels of
    ``import_files.shipment_mode`` ("Sea FCL", "Sea LCL", "Air", "Courier", "Land", "Multimodal").
    An unknown ``sub_mode`` text is dropped (``None``) rather than guessed."""
    tokens = _tokens(value)
    mode: Optional[str] = None
    embedded_sub: Optional[str] = None
    if not tokens:
        return None, None
    if tokens[0] in MODES:
        mode = tokens[0]
    elif tokens[0] in ("OCEAN", "FCL", "LCL"):
        mode = SEA
    elif tokens[0] in ("EXPRESS", "POSTAL"):
        mode = COURIER
    elif tokens[0] in ("ROAD", "TRUCK"):
        mode = LAND
    elif tokens[0] == "MULTI":
        mode = MULTIMODAL
        tokens = tokens[1:] if len(tokens) > 1 and tokens[1] == "MODAL" else tokens
    if mode is None:
        return None, None
    rest = tokens[1:]
    # Two-word sub-modes first ("Sea Break Bulk" -> BREAK_BULK, not BULK).
    candidates = ["_".join(rest[i:i + 2]) for i in range(len(rest) - 1)] + list(rest)
    for candidate in candidates:
        if candidate in SUB_MODES[mode]:
            embedded_sub = candidate
            break
    return mode, normalize_sub_mode(mode, sub_mode) or embedded_sub


def normalize_sub_mode(mode: Optional[str], sub_mode: Optional[str]) -> Optional[str]:
    """The sub-mode code when it belongs to ``mode``; ``None`` otherwise (legacy free text, blank)."""
    if not mode or not sub_mode:
        return None
    code = "_".join(_tokens(sub_mode))
    return code if code in SUB_MODES.get(mode, ()) else None


def validate_mode_pair(mode: Optional[str], sub_mode: Optional[str]) -> Tuple[str, Optional[str]]:
    """Strict check for new data: ``mode`` must be a main-mode code (legacy labels accepted) and ``sub_mode``,
    when given, must belong to it. Returns the normalised pair; raises ``ValueError`` with a reason."""
    code = normalize_mode(mode)
    if code is None:
        raise ValueError("Shipment mode is required")
    if sub_mode is None or not str(sub_mode).strip():
        return code, None
    sub_code = "_".join(_tokens(sub_mode))
    if sub_code not in SUB_MODES[code]:
        raise ValueError(f"Sub-mode {sub_mode!r} does not belong to mode {code}")
    return code, sub_code


def is_weight_billed(mode: Optional[str]) -> bool:
    """True for modes billed on chargeable weight (air, courier)."""
    try:
        return normalize_mode(mode) in WEIGHT_BILLED_MODES
    except ValueError:
        return False
