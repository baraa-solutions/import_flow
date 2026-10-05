"""modules/common/cargo_math.py: pure cargo measurement math (Phase 1, package A1)."""
import pytest

from modules.common import cargo_math as cm
from modules.common import enum_codes as ec


# ── units ──

@pytest.mark.parametrize(
    "unit, dims",
    [("cm", (120.0, 80.0, 100.0)), ("mm", (1200.0, 800.0, 1000.0)), ("m", (1.2, 0.8, 1.0)), (None, (120.0, 80.0, 100.0)),
     (" CM ", (120.0, 80.0, 100.0))],
)
def test_to_metres_and_to_cm_agree_across_units(unit, dims):
    assert cm.to_metres(*dims, unit) == pytest.approx((1.2, 0.8, 1.0))
    assert cm.to_cm(*dims, unit) == pytest.approx((120.0, 80.0, 100.0))


def test_unit_conversion_keeps_the_exact_float_operations():
    # same expressions the PO repository used: mm / 1000.0 and / 10.0, cm / 100.0, m * 100.0
    assert cm.to_metres(333.0, 1.0, 1.0, "mm")[0] == 333.0 / 1000.0
    assert cm.to_cm(333.0, 1.0, 1.0, "mm")[0] == 333.0 / 10.0
    assert cm.to_metres(33.3, 1.0, 1.0, "cm")[0] == 33.3 / 100.0
    assert cm.to_cm(0.333, 1.0, 1.0, "m")[0] == 0.333 * 100.0


@pytest.mark.parametrize("bad", ["in", "ft", "inch", "cms"])
def test_unknown_length_unit_is_rejected(bad):
    with pytest.raises(ValueError):
        cm.to_metres(1.0, 1.0, 1.0, bad)
    with pytest.raises(ValueError):
        cm.normalize_length_unit(bad)


# ── weights ──

@pytest.mark.parametrize(
    "value, expected",
    [(999.9999, 1000.0), (1000.004, 1000.0), (200.008, 200.008), (0.0, 0.0), (12.5, 12.5), (-0.001, 0.0)],
)
def test_snap_weight(value, expected):
    assert cm.snap_weight(value) == expected


def test_chargeable_weight_uses_the_factor_parameter():
    assert cm.chargeable_weight_kg(200.0, 2.5, 167.0) == 417.5
    assert cm.chargeable_weight_kg(50.0, 0.1, 167.0) == 50.0
    assert cm.chargeable_weight_kg(0.0, 1.0, 166.667) == 166.67
    assert cm.volumetric_weight_kg(1.0, 167.0) == 167.0


# ── rows ──

def test_line_totals_round_price_2_and_cbm_4():
    t = cm.line_totals(10.0, 12.345, 0.12345, 100.0, 90.0)
    assert (t.total_price, t.total_cbm, t.gross_weight_kg, t.net_weight_kg) == (123.45, 1.2345, 100.0, 90.0)


def test_packing_row_dims_win_over_direct_cbm_and_zero_dims_keep_it():
    dims = cm.packing_row_totals(2.0, 9.0, 100.0, 120.0, 80.0, 100.0, "cm", 9.99, 167.0)
    assert (dims.total_cbm, dims.chargeable_weight_kg, dims.total_gross_weight_kg, dims.total_net_weight_kg) == (1.92, 320.64, 200.0, 18.0)
    direct = cm.packing_row_totals(2.0, 9.0, 100.0, 0.0, None, 0.0, "cm", 2.5, 167.0)
    assert (direct.total_cbm, direct.chargeable_weight_kg) == (2.5, 417.5)
    assert (direct.length_cm, direct.width_cm, direct.height_cm) == (0.0, 0.0, 0.0)


def test_packing_row_keeps_16_decimal_weights():
    row = cm.packing_row_totals(3.0, 33.3333, 333.3333, 0, 0, 0, "cm", 0.0, 167.0)
    assert row.total_gross_weight_kg == 999.9999
    assert row.total_net_weight_kg == 99.9999


# ── pallets ──

def test_pallet_plan_totals_from_dicts_and_objects():
    class Row:
        pallet_count, length_cm, width_cm, height_cm, gross_weight_per_pallet_kg = 2, 100.0, 100.0, 100.0, 250.0005

    totals = cm.pallet_plan_totals([
        {"pallet_count": 3, "length_cm": 120.0, "width_cm": 80.0, "height_cm": 150.0, "gross_weight_per_pallet_kg": 333.333},
        Row(),
        {"pallet_count": 0, "length_cm": 500.0, "width_cm": 500.0, "height_cm": 500.0, "gross_weight_per_pallet_kg": 9.0},
    ])
    assert (totals.cbm, totals.gross_kg, totals.count) == (6.32, 1500.0, 5)
    assert cm.pallet_plan_totals(None) == cm.PalletTotals()


def test_pallet_fallback_needs_count_and_all_dims():
    assert cm.PalletFallback(4, 120.0, 100.0, 160.0).cbm() == 7.68
    assert cm.PalletFallback(0, 120.0, 100.0, 160.0).cbm() == 0.0
    assert cm.PalletFallback(4, 120.0, 0.0, 160.0).cbm() == 0.0


# ── PO totals precedence ──

LINES = [cm.line_totals(100.0, 200.0, 0.2, 5000.0, 4800.0)]


def test_po_totals_lines_only_counts_quantity_as_packages():
    t = cm.compute_po_totals(LINES, None, None, cm.PalletFallback(0, 120.0, 80.0, 150.0))
    assert (t.amount_fob, t.cbm, t.gross_kg, t.net_kg, t.packages, t.pallet_count) == (20000.0, 20.0, 5000.0, 4800.0, 100, None)


@pytest.mark.parametrize("line_gross, expected", [(1000.05, 1000.05), (1000.1, 1000.0), (1000.2, 1000.0)])
def test_po_totals_packing_gross_tolerance(line_gross, expected):
    lines = [cm.line_totals(100.0, 200.0, 0.1, line_gross, 4800.0)]
    rows = [cm.packing_row_totals(10.0, 9.0, 100.0, 50.0, 40.0, 30.0, "cm", 0.0, 167.0)]
    t = cm.compute_po_totals(lines, rows, None)
    assert (t.gross_kg, t.cbm, t.packages, t.net_kg) == (expected, 0.6, 10, 90.0)


def test_po_totals_pallet_plan_overrides_and_reports_pallet_count():
    plan = [{"pallet_count": 3, "length_cm": 120.0, "width_cm": 80.0, "height_cm": 150.0, "gross_weight_per_pallet_kg": 300.0}]
    t = cm.compute_po_totals(LINES, None, plan, cm.PalletFallback(7, 120.0, 80.0, 150.0))
    assert (t.amount_fob, t.cbm, t.gross_kg, t.net_kg, t.packages, t.pallet_count) == (20000.0, 4.32, 900.0, 4800.0, 3, 3)


def test_po_totals_fallback_when_no_plan():
    t = cm.compute_po_totals(LINES, None, [], cm.PalletFallback(4, 120.0, 100.0, 160.0))
    assert (t.cbm, t.packages, t.gross_kg) == (7.68, 4, 5000.0)


def test_po_totals_none_lines_keep_base():
    base = cm.CargoTotals(amount_fob=10.0, cbm=1.0, gross_kg=2.0, net_kg=1.5, packages=3)
    assert cm.compute_po_totals(None, None, None, None, base=base) == base


# ── recommendation (codes + CBM calculator brackets) ──

@pytest.mark.parametrize(
    "cbm, gross, method, container, count",
    [
        (1.5, 300.0, "AIR", None, 0),
        (1.5, 300.01, "LCL", "LCL", 1),
        (1.51, 10.0, "LCL", "LCL", 1),
        (15.0, 0.0, "LCL", "LCL", 1),
        (15.01, 0.0, "FCL", "C20_ST", 1),
        (33.0, 0.0, "FCL", "C20_ST", 1),
        (67.0, 0.0, "FCL", "C40_ST", 1),
        (76.0, 0.0, "FCL", "C40_HC", 1),
        (76.01, 0.0, "FCL", "C40_HC", 2),
        (153.0, 0.0, "FCL", "C40_HC", 3),
    ],
)
def test_recommend_container_brackets(cbm, gross, method, container, count):
    rec = cm.recommend_container(cbm, gross)
    assert (rec.shipping_method, rec.container_type, rec.container_count) == (method, container, count)
    assert ec.is_code(ec.SHIPPING_METHOD, rec.shipping_method)
    assert container is None or ec.is_code(ec.CONTAINER_TYPE, rec.container_type)


@pytest.mark.parametrize("cbm, expected", [(0.0, (1, 1, 0)), (74.0, (1, 2, 1)), (148.01, (3, 3, 0)), (53.0, (1, 1, 0))])
def test_container_counts_40hc(cbm, expected):
    assert cm.container_counts_40hc(cbm) == expected


def test_legacy_recommendation_labels_normalise_to_codes():
    assert ec.normalize(ec.SHIPPING_METHOD, "Air Freight (شحن جوي)") == "AIR"
    assert ec.normalize(ec.SHIPPING_METHOD, "FCL Container (حاوية كاملة بحرية)") == "FCL"
    assert ec.normalize(ec.CONTAINER_TYPE, "40FT High Cube Containers (40' HC)") == "C40_HC"
    assert ec.normalize(ec.CONTAINER_TYPE, "20FT Standard Container (20' ST)") == "C20_ST"
