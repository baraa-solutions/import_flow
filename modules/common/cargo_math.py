"""
modules/common/cargo_math.py
Pure cargo measurement math shared by purchase orders, the CBM calculator and shipping planning.

No database access and no I/O: callers pass every input, including the air volumetric factor
(``system_parameters.air_volumetric_kg_per_cbm(db)``, read once per request). The float operations and
their order are kept exactly as the purchase-order repository used them, so stored totals do not move.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Annotated, Any, Iterable, Literal, Optional, Sequence, Tuple

from pydantic import BeforeValidator

# ── Units ────────────────────────────────────────────────────────────────────────
LENGTH_UNITS: Tuple[str, ...] = ("mm", "cm", "m")
DEFAULT_LENGTH_UNIT = "cm"

# Weights within this distance of an integer are snapped to it (supplier sheets carry 16-decimal noise).
WEIGHT_SNAP_TOLERANCE = 0.005
# A packing-list gross weight closer than this to the commercial-invoice gross keeps the invoice value.
GROSS_WEIGHT_KEEP_TOLERANCE_KG = 0.1
CM3_PER_M3 = 1_000_000.0

# ── Shipping-mode / container recommendation thresholds (CBM calculator brackets) ──
AIR_MAX_CBM = 1.5
AIR_MAX_GROSS_KG = 300.0
LCL_MAX_CBM = 15.0
C20_ST_MAX_CBM = 33.0
C40_ST_MAX_CBM = 67.0
C40_HC_MAX_CBM = 76.0
# Loadable 40' HC volume for mixed (hybrid) loading vs flat-only loading.
C40_HC_HYBRID_LOAD_CBM = 74.0
C40_HC_FLAT_LOAD_CBM = 53.0

# Codes of enum_codes.SHIPPING_METHOD / enum_codes.CONTAINER_TYPE
METHOD_AIR, METHOD_LCL, METHOD_FCL = "AIR", "LCL", "FCL"
CONTAINER_LCL, CONTAINER_C20_ST, CONTAINER_C40_ST, CONTAINER_C40_HC = "LCL", "C20_ST", "C40_ST", "C40_HC"


def normalize_length_unit(unit: Optional[str]) -> str:
    """``None`` / blank -> ``cm``; otherwise one of ``LENGTH_UNITS`` (case-insensitive). Raises ``ValueError``."""
    text = (unit or "").strip().lower() or DEFAULT_LENGTH_UNIT
    if text not in LENGTH_UNITS:
        raise ValueError(f"Unknown length unit: {unit!r}")
    return text


def _coerce_length_unit(value: Any) -> Any:
    """Schema pre-validation: None / blank -> cm, text is stripped and lower-cased; anything else is left for the
    ``Literal`` check (an unknown unit is a 422)."""
    if value is None:
        return DEFAULT_LENGTH_UNIT
    if isinstance(value, str):
        return value.strip().lower() or DEFAULT_LENGTH_UNIT
    return value


# Pydantic field type for a length unit in requests (PO packing rows, CBM calculator items).
LengthUnit = Annotated[Literal["mm", "cm", "m"], BeforeValidator(_coerce_length_unit)]


def to_metres(length: float, width: float, height: float, unit: Optional[str] = DEFAULT_LENGTH_UNIT) -> Tuple[float, float, float]:
    u = normalize_length_unit(unit)
    if u == "mm":
        return length / 1000.0, width / 1000.0, height / 1000.0
    if u == "m":
        return length, width, height
    return length / 100.0, width / 100.0, height / 100.0


def to_cm(length: float, width: float, height: float, unit: Optional[str] = DEFAULT_LENGTH_UNIT) -> Tuple[float, float, float]:
    u = normalize_length_unit(unit)
    if u == "mm":
        return length / 10.0, width / 10.0, height / 10.0
    if u == "m":
        return length * 100.0, width * 100.0, height * 100.0
    return length, width, height


def snap_weight(value: float) -> float:
    """``value`` rounded to the nearest integer when it is within ``WEIGHT_SNAP_TOLERANCE`` of it."""
    nearest = round(value)
    return float(nearest) if abs(value - nearest) < WEIGHT_SNAP_TOLERANCE else value


def volumetric_weight_kg(cbm: float, kg_per_cbm: float) -> float:
    return cbm * kg_per_cbm


def chargeable_weight_kg(gross_kg: float, cbm: float, kg_per_cbm: float) -> float:
    """Air chargeable weight: ``max(gross, round(cbm * factor, 2))``."""
    return max(gross_kg, round(volumetric_weight_kg(cbm, kg_per_cbm), 2))


# ── Line items / packing rows / pallets ──────────────────────────────────────────

@dataclass(frozen=True)
class LineTotals:
    quantity: float
    total_price: float
    total_cbm: float
    gross_weight_kg: float
    net_weight_kg: float


def line_totals(quantity: float, unit_price: float, cbm_per_unit: float,
                gross_weight_kg: float = 0.0, net_weight_kg: float = 0.0) -> LineTotals:
    """Commercial line: price rounded to 2 decimals, CBM to 4. Weights are line totals as entered."""
    return LineTotals(
        quantity=quantity,
        total_price=round(quantity * unit_price, 2),
        total_cbm=round(quantity * cbm_per_unit, 4),
        gross_weight_kg=gross_weight_kg,
        net_weight_kg=net_weight_kg,
    )


@dataclass(frozen=True)
class PackingRowTotals:
    qty_pkg: float
    length_cm: float
    width_cm: float
    height_cm: float
    total_net_weight_kg: float
    total_gross_weight_kg: float
    total_cbm: float
    chargeable_weight_kg: float


def packing_row_totals(
    qty_pkg: float,
    net_weight_unit_kg: float,
    gross_weight_unit_kg: float,
    length: Optional[float],
    width: Optional[float],
    height: Optional[float],
    unit: Optional[str],
    direct_cbm: Optional[float],
    kg_per_cbm: float,
) -> PackingRowTotals:
    """One packing-list row. Dimensions are per package in ``unit``; stored dimensions are cm.

    CBM comes from the dimensions when all three are positive, otherwise the directly entered ``direct_cbm``.
    Weights are always kg (``weight_unit`` is only the declared UOM label, never converted)."""
    l_val, w_val, h_val = length or 0.0, width or 0.0, height or 0.0
    l_m, w_m, h_m = to_metres(l_val, w_val, h_val, unit)
    l_cm, w_cm, h_cm = to_cm(l_val, w_val, h_val, unit)
    tot_net = round(qty_pkg * net_weight_unit_kg, 16)
    tot_gross = round(qty_pkg * gross_weight_unit_kg, 16)
    if l_m > 0 and w_m > 0 and h_m > 0:
        tot_cbm = round(qty_pkg * (l_m * w_m * h_m), 4)
    else:
        tot_cbm = float(direct_cbm or 0.0)
    return PackingRowTotals(
        qty_pkg=qty_pkg,
        length_cm=l_cm,
        width_cm=w_cm,
        height_cm=h_cm,
        total_net_weight_kg=tot_net,
        total_gross_weight_kg=tot_gross,
        total_cbm=tot_cbm,
        chargeable_weight_kg=chargeable_weight_kg(tot_gross, tot_cbm, kg_per_cbm),
    )


@dataclass(frozen=True)
class PalletTotals:
    cbm: float = 0.0
    gross_kg: float = 0.0
    count: int = 0


def _field(row: Any, name: str) -> Any:
    value = row.get(name) if isinstance(row, dict) else getattr(row, name, None)
    return value or 0


def pallet_plan_totals(plan: Optional[Iterable[Any]]) -> PalletTotals:
    """Totals of a pallet plan (rows as dicts or objects with ``pallet_count``, ``length_cm``, ``width_cm``,
    ``height_cm``, ``gross_weight_per_pallet_kg``). Rows with no pallets are ignored."""
    cbm = 0.0
    gross = 0.0
    count = 0
    for row in plan or ():
        p_cnt = int(_field(row, "pallet_count"))
        if p_cnt <= 0:
            continue
        p_l = float(_field(row, "length_cm"))
        p_w = float(_field(row, "width_cm"))
        p_h = float(_field(row, "height_cm"))
        p_wt = float(_field(row, "gross_weight_per_pallet_kg"))
        count += p_cnt
        if p_l > 0 and p_w > 0 and p_h > 0:
            cbm += round((p_l * p_w * p_h / CM3_PER_M3) * p_cnt, 4)
        if p_wt > 0:
            gross += p_wt * p_cnt
    return PalletTotals(cbm=cbm, gross_kg=snap_weight(gross), count=count)


@dataclass(frozen=True)
class PalletFallback:
    """Uniform pallets declared on the PO header (used when there is no pallet plan). Floats / int only:
    convert database Decimals when building it."""
    count: int
    length_cm: float
    width_cm: float
    height_cm: float

    def cbm(self) -> float:
        if self.count > 0 and self.length_cm > 0 and self.width_cm > 0 and self.height_cm > 0:
            return round((self.length_cm * self.width_cm * self.height_cm / CM3_PER_M3) * self.count, 4)
        return 0.0


@dataclass(frozen=True)
class CargoTotals:
    amount_fob: float = 0.0
    cbm: float = 0.0
    gross_kg: float = 0.0
    net_kg: float = 0.0
    packages: int = 0
    pallet_count: Optional[int] = None  # set when the pallet plan defines the pallet count


def compute_po_totals(
    lines: Optional[Sequence[LineTotals]],
    packing_rows: Optional[Sequence[PackingRowTotals]],
    pallet_plan: Optional[Iterable[Any]],
    pallet_fallback: Optional[PalletFallback] = None,
    base: CargoTotals = CargoTotals(),
) -> CargoTotals:
    """Purchase-order totals. Precedence (later wins):

    1. commercial lines (``None`` keeps ``base``, e.g. an update that does not resend the lines);
       packages fall back to the commercial quantity (truncated) when nothing better exists;
    2. packing list: CBM, gross (kept from the lines when within 0.1 kg), net and package count;
    3. pallet plan: CBM, gross and package count = pallet count; otherwise the header pallet fallback
       overrides CBM and packages.
    """
    fob, cbm, gross, net, pkgs = base.amount_fob, base.cbm, base.gross_kg, base.net_kg, base.packages

    if lines is not None:
        fob = cbm = gross = net = 0.0
        pkgs = 0
        for line in lines:
            fob += line.total_price
            cbm += line.total_cbm
            gross += line.gross_weight_kg
            net += line.net_weight_kg
            pkgs += int(line.quantity)  # pinned (Q8): commercial units count as packages without a packing list

    if packing_rows:
        pkg_net = pkg_gross = pkg_cbm = pkg_count = 0.0
        for row in packing_rows:
            pkg_net += row.total_net_weight_kg
            pkg_gross += row.total_gross_weight_kg
            pkg_cbm += row.total_cbm
            pkg_count += row.qty_pkg
        if pkg_cbm > 0:
            cbm = pkg_cbm
        if pkg_gross > 0:
            pkg_gross = snap_weight(pkg_gross)
            if not (gross > 0 and abs(gross - pkg_gross) < GROSS_WEIGHT_KEEP_TOLERANCE_KG):
                gross = pkg_gross
        pkg_net = snap_weight(pkg_net)
        if pkg_net > 0:
            net = pkg_net
        if pkg_count > 0:
            pkgs = int(pkg_count)

    pallet_count: Optional[int] = None
    pallets = pallet_plan_totals(pallet_plan)
    if pallets.cbm > 0:
        cbm = pallets.cbm
    if pallets.gross_kg > 0:
        gross = pallets.gross_kg
    if pallets.count > 0:
        pkgs = pallets.count
        pallet_count = pallets.count
    elif pallet_fallback is not None:
        fallback_cbm = pallet_fallback.cbm()
        if fallback_cbm > 0:
            cbm = fallback_cbm
            pkgs = pallet_fallback.count

    return CargoTotals(amount_fob=fob, cbm=cbm, gross_kg=gross, net_kg=net, packages=pkgs, pallet_count=pallet_count)


# ── Shipping mode / container recommendation ─────────────────────────────────────

@dataclass(frozen=True)
class ContainerRecommendation:
    shipping_method: str                 # SHIPPING_METHOD code
    container_type: Optional[str]        # CONTAINER_TYPE code, None for air
    container_count: int


def recommend_container(total_cbm: float, total_gross_kg: float) -> ContainerRecommendation:
    if total_cbm <= AIR_MAX_CBM and total_gross_kg <= AIR_MAX_GROSS_KG:
        return ContainerRecommendation(METHOD_AIR, None, 0)
    if total_cbm <= LCL_MAX_CBM:
        return ContainerRecommendation(METHOD_LCL, CONTAINER_LCL, 1)
    if total_cbm <= C20_ST_MAX_CBM:
        return ContainerRecommendation(METHOD_FCL, CONTAINER_C20_ST, 1)
    if total_cbm <= C40_ST_MAX_CBM:
        return ContainerRecommendation(METHOD_FCL, CONTAINER_C40_ST, 1)
    # one 40' HC up to C40_HC_MAX_CBM (ceil = 1 for 67 < cbm <= 76), then as many as needed
    return ContainerRecommendation(METHOD_FCL, CONTAINER_C40_HC, math.ceil(total_cbm / C40_HC_MAX_CBM))


def container_counts_40hc(total_cbm: float) -> Tuple[int, int, int]:
    """(hybrid count, flat-only count, containers saved by hybrid loading); 1/1/0 for an empty load."""
    hybrid = math.ceil(total_cbm / C40_HC_HYBRID_LOAD_CBM) if total_cbm > 0 else 1
    flat = math.ceil(total_cbm / C40_HC_FLAT_LOAD_CBM) if total_cbm > 0 else 1
    return hybrid, flat, max(0, flat - hybrid)
