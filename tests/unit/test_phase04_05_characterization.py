"""
Phases 4-5 characterization tests (docs/plans/phase-04-05-quality-plan.md, section 3).

Written green on the code BEFORE the 04-05 fixes: they pin the money and date outputs that the fixes must keep
identical (booking cost engine, insurance premium, tiered demurrage fee, simulator boundaries, container SLA
ladder, shipment-update inspection). Two pins document known-wrong behaviour kept on purpose until a CTO
decision: the substring match of the savings engine (Q4) and the "last free day = OVERDUE" boundary of the dual
clock and the radar (Q11).
"""
from datetime import date, datetime, timedelta

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.cargo_insurance.schemas import InsuranceCalculationInput
from modules.cargo_insurance.service import calculate_cargo_insurance_engine
from modules.cargo_shipping.model import CargoShippingRecord
from modules.cargo_shipping.validators import calculate_container_sla_and_status, validate_container_reuse_conflict
from modules.demurrage_detention.model import DemurrageTracking
from modules.demurrage_detention.schemas import DemurrageSimulationRequest
from modules.demurrage_detention.service import (
    DEFAULT_DEMURRAGE_TIERS,
    DEFAULT_DETENTION_TIERS,
    calculate_tiered_fee,
    get_containers_radar_overview_service,
    get_dual_clock_status_service,
    simulate_demurrage_and_detention,
)
from modules.freight_booking.model import ShipmentBooking
from modules.freight_booking.service import calculate_transit_time_and_costs
from modules.import_files.model import ImportFile
from modules.shipment_updates.model import ShipmentUpdateLog
from modules.shipment_updates.service import inspect_shipment_phases_service


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine, autoflush=False)()
    session.add(ImportFile(
        import_file_id=1, import_file_code="IMP-2026-0450", company_name="Char Co", supplier_name="Char Supplier",
        owner="tester", current_module="Phase 3 - Documents & ACID",
    ))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


# 1. Booking cost engine ------------------------------------------------------------------------------------

def test_booking_cost_engine_golden_values():
    booking = ShipmentBooking(
        containers_data=[{"container_type": "40HC", "quantity": 2}],
        cost_charges_data=[
            {"charge_type": "Sea Freight 40HC", "unit": "Per Container", "quantity": 1, "rate": 2000.0, "currency": "USD"},
            {"charge_type": "BL Fee", "unit": "Per Shipment", "quantity": 1, "rate": 100.0, "currency": "USD"},
        ],
        quotation_details_data={"original_quote_total_usd": 4500.0, "original_container_40ft_price": 2200.0},
        original_freight_cost_usd=0.0,
    )
    calculate_transit_time_and_costs(booking)

    assert booking.total_freight_cost_usd == 4100.0
    assert [c["total"] for c in booking.cost_charges_data] == [4000.0, 100.0]
    assert [c["quantity"] for c in booking.cost_charges_data] == [2, 1]
    assert booking.original_freight_cost_usd == 4500.0
    assert booking.cost_variance_usd == 400.0
    assert booking.cost_savings_usd == 400.0
    assert booking.savings_notes == (
        "Freight savings achieved: $400.00 USD (8.9% saving on freight cost) "
        "[Sea Freight 40HC: ($2,200.00 - $2,000.00) × 2 = $400.00 USD]"
    )
    breakdown = booking.quotation_details_data["savings_breakdown"]
    assert len(breakdown) == 1
    assert breakdown[0]["subtotal_savings"] == 400.0
    assert breakdown[0]["unit_label"] == "40ft Container"


def test_booking_savings_substring_match_pinned_for_q4():
    """BE45-T20: "THC 40HC" is a local surcharge and is never compared with the 40ft ocean-freight rate."""
    booking = ShipmentBooking(
        containers_data=[{"container_type": "40HC", "quantity": 2}],
        cost_charges_data=[{"charge_type": "THC 40HC", "unit": "Per Container", "quantity": 1, "rate": 150.0}],
        quotation_details_data={"original_container_40ft_price": 2200.0},
        original_freight_cost_usd=0.0,
    )
    calculate_transit_time_and_costs(booking)
    assert booking.total_freight_cost_usd == 300.0
    assert booking.cost_variance_usd == 0.0
    assert booking.cost_savings_usd == 0.0
    assert len(booking.quotation_details_data.get("savings_breakdown", [])) == 0
    assert "THC 40HC" not in booking.savings_notes


def test_booking_cost_increase_and_exact_match_notes():
    increase = ShipmentBooking(
        containers_data=[{"container_type": "20GP", "quantity": 1}],
        cost_charges_data=[{"charge_type": "Sea Freight", "unit": "Per Container", "quantity": 1, "rate": 1200.0}],
        quotation_details_data={"original_quote_total_usd": 1000.0},
        original_freight_cost_usd=0.0,
    )
    calculate_transit_time_and_costs(increase)
    assert increase.cost_variance_usd == -200.0
    assert increase.cost_savings_usd == 0.0
    assert increase.savings_notes == "Freight cost increase: +$200.00 USD over the initial quotation"

    exact = ShipmentBooking(containers_data=[], cost_charges_data=[], quotation_details_data={}, original_freight_cost_usd=0.0)
    calculate_transit_time_and_costs(exact)
    assert exact.total_freight_cost_usd == 0.0
    assert exact.savings_notes == "Executed rate matches the approved quotation exactly"


# 2. Booking dates ------------------------------------------------------------------------------------------

def test_booking_transit_delay_and_warehouse_eta_with_atd():
    booking = ShipmentBooking(
        etd=datetime(2026, 8, 10, 10), eta=datetime(2026, 8, 25, 10), atd=datetime(2026, 8, 12, 9),
        expected_warehouse_days=7,
    )
    calculate_transit_time_and_costs(booking)
    assert booking.transit_time_days == 15
    assert booking.departure_delay_days == 2
    assert booking.expected_warehouse_arrival_date == datetime(2026, 9, 3, 10)


def test_booking_warehouse_eta_without_atd_uses_default_7_days():
    booking = ShipmentBooking(etd=datetime(2026, 8, 10, 10), eta=datetime(2026, 8, 25, 10), expected_warehouse_days=None)
    calculate_transit_time_and_costs(booking)
    assert booking.transit_time_days == 15
    assert booking.departure_delay_days == 0
    assert booking.expected_warehouse_arrival_date == datetime(2026, 9, 1, 10)


# 3. Insurance engine ---------------------------------------------------------------------------------------

def test_insurance_icc_a_with_war_hits_minimum_premium():
    r = calculate_cargo_insurance_engine(InsuranceCalculationInput(invoice_value=5000, freight_cost=500))
    assert (r.cif_value, r.insured_value) == (5500.0, 6050.0)
    assert (r.base_rate, r.base_premium) == (0.0025, 15.12)
    assert (r.war_rate, r.war_strikes_premium) == (0.0005, 3.02)
    assert r.net_premium == 30.0
    assert (r.issuance_fee, r.tax_rate, r.tax_amount) == (15.0, 0.05, 2.25)
    assert r.total_payable_premium == 47.25


def test_insurance_icc_c_without_war_above_minimum():
    r = calculate_cargo_insurance_engine(InsuranceCalculationInput(
        invoice_value=100000, freight_cost=5000, other_costs=1000, coverage_clause="ICC_C", include_war_and_strikes=False,
    ))
    assert (r.cif_value, r.insured_value) == (106000.0, 116600.0)
    assert (r.base_rate, r.base_premium) == (0.001, 116.6)
    assert (r.war_rate, r.war_strikes_premium) == (0.0, 0.0)
    assert r.net_premium == 116.6
    assert r.tax_amount == 6.58
    assert r.total_payable_premium == 138.18


def test_insurance_icc_a_with_war_above_minimum_tax_at_the_cent():
    r = calculate_cargo_insurance_engine(InsuranceCalculationInput(invoice_value=50000, freight_cost=3000))
    assert (r.base_premium, r.war_strikes_premium, r.net_premium) == (145.75, 29.15, 174.9)
    assert r.tax_amount == 9.5
    assert r.total_payable_premium == 199.4


def test_insurance_odd_cents_rounding():
    r = calculate_cargo_insurance_engine(InsuranceCalculationInput(invoice_value=12345.67, freight_cost=890.12, coverage_clause="ICC_B"))
    assert (r.cif_value, r.insured_value) == (13235.79, 14559.37)
    assert (r.base_premium, r.war_strikes_premium) == (21.84, 7.28)
    assert r.net_premium == 30.0
    assert r.total_payable_premium == 47.25


# 4. Tiered fee ---------------------------------------------------------------------------------------------

@pytest.mark.parametrize(
    "days,dem,det",
    [(0, 0.0, 0.0), (7, 280.0, 245.0), (8, 350.0, 310.0), (15, 890.0, 810.0), (30, 2690.0, 2460.0)],
)
def test_tiered_fee_default_tiers(days, dem, det):
    assert calculate_tiered_fee(days, DEFAULT_DEMURRAGE_TIERS)["total_fee"] == dem
    assert calculate_tiered_fee(days, DEFAULT_DETENTION_TIERS)["total_fee"] == det


def test_tiered_fee_custom_tiers_breakdown():
    res = calculate_tiered_fee(5, [
        {"from_day": 1, "to_day": 3, "rate_per_day": 10.0},
        {"from_day": 4, "to_day": None, "rate_per_day": 20.0},
    ])
    assert res["total_fee"] == 70.0
    assert [(t["days_applied"], t["tier_cost"]) for t in res["tier_breakdown"]] == [(3, 30.0), (2, 40.0)]


# 5. Simulator boundaries -----------------------------------------------------------------------------------

def _sim(gate_out: date):
    return simulate_demurrage_and_detention(DemurrageSimulationRequest(
        discharge_date=date(2026, 8, 1), gate_out_date=gate_out, empty_return_date=gate_out + timedelta(days=10),
        exchange_rate=50.0, containers_count=2,
    ))


def test_simulator_gate_out_on_expiry_day_has_no_demurrage():
    s = _sim(date(2026, 8, 15))
    assert s.demurrage_expiry_date == date(2026, 8, 15)
    assert (s.demurrage_days_consumed, s.demurrage_days_overdue, s.demurrage_fee_fx) == (14, 0, 0.0)
    assert (s.detention_days_overdue, s.detention_fee_fx) == (3, 210.0)
    assert (s.storage_days_overdue, s.storage_fee_egp) == (9, 4500.0)
    assert (s.total_fee_fx, s.total_cost_egp) == (210.0, 15000.0)
    assert s.status_badge == "DETENTION_INCURRED"


def test_simulator_gate_out_one_day_after_expiry():
    s = _sim(date(2026, 8, 16))
    assert (s.demurrage_days_consumed, s.demurrage_days_overdue, s.demurrage_fee_fx) == (15, 1, 80.0)
    assert (s.storage_days_overdue, s.storage_fee_egp) == (10, 5000.0)
    assert (s.total_fee_fx, s.total_cost_egp) == (290.0, 19500.0)
    assert s.status_badge == "DEMURRAGE_AND_DETENTION_INCURRED"


# 6. Last free day: dual clock and radar (Q11 pin) ---------------------------------------------------------

def _tracking_on_last_free_day(db) -> DemurrageTracking:
    tracking = DemurrageTracking(
        tracking_code="DND-CHAR-0001", import_file_id=1, import_file_code="IMP-2026-0450", carrier_name="MSC",
        bill_of_lading_no="BL-CHAR-1", port_name="Alexandria Port", discharge_date=date.today() - timedelta(days=14),
        containers=[{"container_no": "MSCU0000014", "container_type": "40ft High Cube"}],
        currency="USD", exchange_rate=50.0, status="Free Time Active", is_active=True,
    )
    db.add(tracking)
    db.commit()
    return tracking


def test_dual_clock_last_free_day_is_overdue_pinned_for_q11(db):
    tracking = _tracking_on_last_free_day(db)
    clock = get_dual_clock_status_service(db, tracking.tracking_id)
    assert clock.carrier_clock.days_consumed == 14
    assert clock.carrier_clock.days_remaining == 0
    assert clock.carrier_clock.status == "OVERDUE_DEMURRAGE"
    assert clock.port_storage_clock.status == "OVERDUE_STORAGE"
    assert clock.overall_alert_level == "ACTION_REQUIRED"


def test_radar_last_free_day_is_critical_pinned_for_q11(db):
    _tracking_on_last_free_day(db)
    radar = get_containers_radar_overview_service(db)
    assert radar.critical_overdue_count == 1
    item = radar.radar_items[0]
    assert item.radar_status == "CRITICAL_OVERDUE"
    assert item.demurrage_days_remaining == 0
    # no demurrage day is overdue yet; 9 storage days at the default 250 EGP/day
    assert item.accrued_demurrage_usd == 0.0
    assert item.accrued_storage_egp == 2250.0
    assert item.total_accrued_egp == 2250.0


# 7. Container SLA ladder and reuse window ------------------------------------------------------------------

def test_container_sla_ladder():
    assert calculate_container_sla_and_status({})["tracking_status"] == "PENDING_ASSIGNMENT"
    assigned = calculate_container_sla_and_status({"container_assignment_date": "2026-08-16T10:00:00"})
    assert assigned["tracking_status"] == "ASSIGNED"
    assert assigned["sla_deadline_at"] == "2026-08-18T10:00:00+00:00"
    on_time = calculate_container_sla_and_status({
        "container_assignment_date": "2026-08-16T10:00:00", "arrival_at_supplier_at": "2026-08-16T12:00:00",
        "loading_start_at": "2026-08-16T13:00:00", "loading_end_at": "2026-08-17T09:00:00",
        "port_gate_in_at": "2026-08-18T09:00:00",
    })
    assert on_time["tracking_status"] == "GATED_IN_AT_PORT"
    assert on_time["is_sla_breached"] is False
    late = calculate_container_sla_and_status({"container_assignment_date": "2026-08-16T10:00:00", "port_gate_in_at": "2026-08-18T11:00:00"})
    assert late["is_sla_breached"] is True
    assert calculate_container_sla_and_status({"container_assignment_date": "2026-08-16", "loading_end_at": "2026-08-16T20:00:00"})[
        "tracking_status"] == "LOADING_COMPLETED"


def test_container_reuse_window_same_seal_fails_other_seal_passes(db):
    db.add(CargoShippingRecord(
        cargo_shipping_code="SHP-2026-0900", import_file_id=1, containers_loading_data=[
            {"container_no": "MSKU7777777", "seal_no": "SL-1", "container_assignment_date": "2026-08-01T10:00:00"}
        ], courier_tracking_data={}, cargox_exchange_data={}, owner="tester", is_active=True,
    ))
    db.commit()
    with pytest.raises(HTTPException) as exc:
        validate_container_reuse_conflict(db, [{"container_no": "msku7777777", "seal_no": "sl-1", "container_assignment_date": "2026-08-16"}])
    assert exc.value.status_code == 400
    # a different seal inside the window is allowed; the same seal 16 days apart is outside the window
    validate_container_reuse_conflict(db, [{"container_no": "MSKU7777777", "seal_no": "SL-2", "container_assignment_date": "2026-08-05"}])
    validate_container_reuse_conflict(db, [{"container_no": "MSKU7777777", "seal_no": "SL-1", "container_assignment_date": "2026-08-17"}])


# 8. Shipment-update inspection ------------------------------------------------------------------------------

def test_shipment_update_inspection_phase_3(db):
    db.add(ShipmentUpdateLog(
        update_code="UPD-2026-00001", import_file_id=1, import_file_code="IMP-2026-0450",
        update_category="Follow-up & Notes", target_phase="Phase 3", phase_status="Current",
        log_date="2026-08-01", note="ACID requested", alert_priority="Normal", assigned_user="tester",
    ))
    db.commit()
    phases = inspect_shipment_phases_service(db, 1)
    assert [p.status for p in phases] == ["Completed", "Completed", "Current"] + ["Future"] * 7
    assert [p.phase_number for p in phases] == list(range(1, 11))
    assert phases[2].update_count == 1
    assert phases[2].last_note == "ACID requested"
    assert phases[2].completion_date == "2026-08-01"
