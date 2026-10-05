"""
Phase 9 characterization tests (docs/plans/phase-09-quality-plan.md, section 2).

Golden values captured on the code BEFORE the phase-09 fixes. They pin every money output the plan lists as
"must stay byte-identical": the landed-cost engine, the PL-08 simulation (with and without overrides, no
system parameter rows), the CLO-02 actual landed cost on clean data (no FX fallback, real weights / CBM,
HS codes present) and the Odoo journal / CSV of a settlement without seller-paid rows.

The fixtures avoid every input a phase-09 fix changes on purpose (hard-coded FX, missing HS / weight / CBM,
seller-paid credits, the fixed 40/60 duty/VAT split, per-item CBM in the simulation), so these numbers must
not move. Floats are compared with ``==`` on purpose.
"""
import copy
import importlib
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.currencies import service as currency_service
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_clearance.model import ClearanceExpenseInvoice, CustomsClearanceRecord
from modules.customs_tariff.model import CustomsTariff, FeeCode
from modules.import_files.model import ImportFile
from modules.incoterms.model import Incoterm
from modules.inland_transport.model import InlandTransportBooking
from modules.projects.model import Project
from modules.purchase_orders.model import POLineItem, PurchaseOrder
from modules.suppliers.model import Supplier
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.odoo_export_service import (
    export_odoo_csv_service,
    generate_odoo_journal_entry_service,
)
from modules.financial_settlement.schemas import (
    ActualLandedCostCalculationRequest,
    EstimatedLandedCostSimulationRequest,
)
from modules.financial_settlement.service import (
    calculate_actual_landed_cost_service,
    calculate_landed_cost_engine,
    simulate_estimated_landed_cost_service,
)

# Register every table: the services import some models lazily, so create_all must not depend on test order.
for _model_file in sorted(Path(__file__).resolve().parents[2].glob("modules/*/model.py")):
    importlib.import_module(f"modules.{_model_file.parent.name}.model")


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    currency_service.clear_currency_cache()
    try:
        yield session
    finally:
        session.close()
        currency_service.clear_currency_cache()
        engine.dispose()


# ──────────────────────────────────────────────────────────────────────────────
# 1. Engine
# ──────────────────────────────────────────────────────────────────────────────

ENGINE_EXPENSES = [
    {"invoice_no": "E1", "category": "Freight", "amount_egp": 12345.67, "allocation_rule": "Volume-Based"},
    {"invoice_no": "E2", "category": "Customs Duty", "amount_egp": 9876.54, "allocation_rule": "Value-Based"},
    {"invoice_no": "E3", "category": "Clearance", "amount_egp": 0.0, "amount_fx": 321.5, "exchange_rate": 48.37,
     "allocation_rule": "Weight-Based"},
    {"invoice_no": "E4", "category": "Inland Transport", "amount_egp": 4567.89, "allocation_rule": "Equal"},
    {"invoice_no": "E5", "category": "Storage", "amount_egp": 1111.11, "allocation_rule": "Value-Based"},
    {"invoice_no": "E6", "category": "Freight", "amount_egp": 99999.0, "is_seller_paid": True},
    {"invoice_no": "E7", "category": "Insurance", "amount_egp": 500.0, "payer": "Seller"},
]

ENGINE_ITEMS = [
    {"item_code": "A", "item_name": "A", "qty": 10, "fob_unit_egp": 1234.56, "gross_weight_kg": 300.5, "cbm": 2.25},
    {"item_code": "B", "item_name": "B", "qty": 0.5, "fob_unit_egp": 8000.0, "gross_weight_kg": 120.0, "cbm": 0.75},
    {"item_code": "C", "item_name": "C", "qty": 7, "fob_unit_egp": 333.33, "gross_weight_kg": 80.25, "cbm": 1.5},
]

ITEM_KEYS = (
    "fob_total_egp", "allocated_freight_egp", "allocated_customs_egp", "allocated_clearance_egp",
    "allocated_transport_egp", "allocated_other_egp", "total_landed_cost_egp", "unit_landed_cost_egp",
    "markup_factor",
)


def run_engine(rule=None):
    expenses = copy.deepcopy(ENGINE_EXPENSES)
    if rule is not None:
        for e in expenses:
            e["allocation_rule"] = rule
    res = calculate_landed_cost_engine(expenses, copy.deepcopy(ENGINE_ITEMS), incoterm="cif ")
    return {
        "incoterm_code": res["incoterm_code"],
        "total_fob_egp": res["total_fob_egp"],
        "total_expenses_egp": res["total_expenses_egp"],
        "total_landed_cost_egp": res["total_landed_cost_egp"],
        "average_markup_factor": res["average_markup_factor"],
        "items": [[i[k] for k in ITEM_KEYS] for i in res["item_landed_costs"]],
        "filled_amount_egp": expenses[2]["amount_egp"],
    }


@pytest.mark.parametrize("rule", [None, "Value-Based", "Weight-Based", "Volume-Based", "Equal"])
def test_engine_golden(rule):
    assert run_engine(rule) == GOLDEN_ENGINE[str(rule)]


def test_engine_without_items_skips_seller_paid_rows():
    # Intended change (customs review 2 #10): was 12.75, the seller-paid 2.25 is not the importer's cost
    # (the engine already skipped it when items exist).
    res = calculate_landed_cost_engine([{"amount_egp": 10.5}, {"amount_egp": 2.25, "is_seller_paid": True}], [])
    assert res["total_fob_egp"] == 0.0
    assert res["total_expenses_egp"] == 10.5
    assert res["total_landed_cost_egp"] == 10.5
    assert res["item_landed_costs"] == []


# ──────────────────────────────────────────────────────────────────────────────
# 2. Simulation (PL-08) and 4. Actual (CLO-02)
# ──────────────────────────────────────────────────────────────────────────────

def seed_shipment(db, *, customs_rate="50.0000", commercial_rate="48.5000", po_rate=48.5, cbm=(0.0, 0.0)):
    """A clean shipment: USD PO with an explicit rate, two tariffed lines with weights and CBM, a goods invoice
    with its own rate and EGP-only expense sources (no FX lookup needed for the actual landed cost). The simulation
    goldens use lines without CBM (the pre-fix simulation never read the CBM column, FS-05)."""
    db.add_all([
        FeeCode(code="390", name_ar="x", collection_group="g", calculation_type="flat",
                flat_amount=Decimal("1081.00"), effective_from=date(2020, 1, 1), is_active=True),
        FeeCode(code="392", name_ar="y", collection_group="g", calculation_type="flat",
                flat_amount=Decimal("3457.00"), effective_from=date(2020, 1, 1), is_active=True),
    ])
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db.add(usd)
    db.flush()
    db.add(ExchangeRate(currency_id=usd.currency_id, customs_rate=Decimal(customs_rate),
                        commercial_rate=Decimal(commercial_rate), effective_date=date(2020, 1, 1), is_active=True))
    t1 = CustomsTariff(hs_code="8479.89.90", hs_description="Machinery", customs_duty_rate=Decimal("5.00"),
                       vat_rate=Decimal("14.00"), schedule_tax_rate=Decimal("0.00"),
                       development_fee_rate=Decimal("0.00"), customs_service_fee_rate=Decimal("1.00"),
                       effective_from=date(2020, 1, 1), is_active=True)
    t2 = CustomsTariff(hs_code="8504.40.90", hs_description="Converters", customs_duty_rate=Decimal("10.00"),
                       vat_rate=Decimal("14.00"), schedule_tax_rate=Decimal("5.00"),
                       development_fee_rate=Decimal("0.00"), customs_service_fee_rate=Decimal("1.00"),
                       effective_from=date(2020, 1, 1), is_active=True)
    supplier = Supplier(supplier_code="SUP-P09", company_name="P09 Supplier", supplier_type="Manufacturer",
                        registration_type="CargoX", foreign_exporter_id="EXP-P09", foreign_exporter_country="Germany",
                        foreign_exporter_country_code="DE", address="DE", is_active=True)
    inc = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
    db.add_all([t1, t2, supplier, inc])
    db.flush()
    project = Project(project_code="PRJ-P09", project_name="P09", project_owner="x", company_id=1,
                      supplier_id=supplier.supplier_id, incoterm_id=inc.incoterm_id, is_active=True)
    db.add(project)
    imp = ImportFile(
        import_file_code="IMP-P09-0001", company_id=1, company_name="P09 Co", supplier_id=supplier.supplier_id,
        supplier_name="P09 Supplier", incoterm_code="FOB", estimated_cost=20000.0, estimated_cost_currency="USD",
        hs_code="8479.89.90", product_category="Machinery", is_active=True,
        invoices_data=[{"invoice_no": "CI-1", "currency": "USD", "amount": 20000.0, "exchange_rate": 48.5,
                        "payment_status": "PAID", "invoice_date": "2026-03-01"}],
    )
    db.add(imp)
    db.flush()
    po = PurchaseOrder(po_number="PO-P09-1", import_file_id=imp.import_file_id, project_id=project.project_id,
                       company_id=1, supplier_id=supplier.supplier_id, incoterm_id=inc.incoterm_id,
                       currency_id=usd.currency_id, total_amount_fob=20000.0, exchange_rate=po_rate,
                       country_of_origin="CN", is_active=True)
    db.add(po)
    db.flush()
    db.add_all([
        POLineItem(po_id=po.po_id, item_code="ITM-MAC-01", description_ar="Machine", description_en="Machine",
                   quantity=10, unit_price=1500.0, total_price=15000.0, tariff_id=t1.tariff_id,
                   gross_weight_kg=3000.0, total_cbm=cbm[0], country_of_origin="CN"),
        POLineItem(po_id=po.po_id, item_code="ITM-CONV-02", description_ar="Converter", description_en="Converter",
                   quantity=50, unit_price=100.0, total_price=5000.0, tariff_id=t2.tariff_id,
                   gross_weight_kg=1000.0, total_cbm=cbm[1], country_of_origin="CN"),
    ])
    db.commit()
    return imp


def seed_actual_sources(db, imp):
    db.add(CustomsClearanceRecord(clearance_code="CLR-P09", import_file_id=imp.import_file_id,
                                  declaration_46_no="D46-P09", total_duty_payable=160000.0,
                                  duty_paid_amount=160000.0, status="Final Release Granted", is_active=True))
    db.add(ClearanceExpenseInvoice(invoice_code="CEI-P09-1", import_file_id=imp.import_file_id,
                                   provider_name="Broker", invoice_number="BRK-1",
                                   expense_category="Customs Brokerage Fees", currency="EGP", amount_egp=12000.0,
                                   payment_status="Paid", is_active=True))
    db.add(ClearanceExpenseInvoice(invoice_code="CEI-P09-2", import_file_id=imp.import_file_id,
                                   provider_name="Local Forwarder", invoice_number="FRT-1",
                                   expense_category="Ocean Freight", currency="EGP", amount_egp=15000.0,
                                   payment_status="Paid", is_active=True))
    db.add(InlandTransportBooking(
        transport_code="TR-P09", waybill_number="WB-P09", import_file_id=imp.import_file_id,
        carrier_name="Carrier", truck_plate_number="1", driver_name="d", driver_phone="010",
        driver_national_id="29001011234567", pickup_port_location="Alex", destination_warehouse="Cairo",
        planned_departure_at=datetime(2026, 3, 5), expected_arrival_at=datetime(2026, 3, 6),
        booking_date=datetime(2026, 3, 5), transport_fare_egp=18000.0, status="Delivered", is_active=True))
    db.commit()


SIM_HEADER = (
    "exchange_rate", "total_fob_fc", "total_fob_egp", "total_freight_egp", "total_insurance_egp",
    "total_customs_and_taxes_egp", "total_clearance_and_port_egp", "total_inland_transport_egp",
    "total_other_expenses_egp", "total_expenses_egp", "total_landed_cost_egp", "total_landed_cost_fc",
    "average_markup_factor", "average_markup_percent",
)
SIM_ITEM = (
    "qty", "unit_price_fc", "fob_total_fc", "fob_unit_egp", "fob_total_egp", "allocated_freight_egp",
    "allocated_insurance_egp", "allocated_customs_duty_egp", "allocated_vat_egp",
    "allocated_clearance_and_port_egp", "allocated_inland_transport_egp", "allocated_other_egp",
    "total_expenses_allocated_egp", "total_landed_cost_egp", "unit_landed_cost_egp", "unit_landed_cost_fc",
    "markup_factor", "markup_percent",
)

SIM_OVERRIDES = dict(
    exchange_rate_override=49.25, freight_amount_egp_override=30000.0, insurance_amount_egp_override=4000.0,
    clearance_fees_egp_override=4100.0, port_handling_egp_override=5200.0, inland_transport_egp_override=7300.0,
    bank_fees_egp_override=2600.0, other_expenses_egp_override=1900.0, allocation_preference="Weight-Based",
    estimate_date=date(2026, 3, 1),
)


def sim_snapshot(res):
    return {
        "header": [getattr(res, k) for k in SIM_HEADER],
        "currency": res.currency,
        "expenses": [(e.category, e.amount_fc, e.amount_egp, e.currency, e.allocation_rule)
                     for e in res.expenses_breakdown],
        "items": [[getattr(i, k) for k in SIM_ITEM] for i in res.items_breakdown],
    }


def run_simulation(db, overrides):
    imp = seed_shipment(db)
    req = EstimatedLandedCostSimulationRequest(**overrides) if overrides else None
    return sim_snapshot(simulate_estimated_landed_cost_service(db, imp.import_file_id, req))


def test_simulation_golden_with_all_overrides(db):
    assert run_simulation(db, SIM_OVERRIDES) == GOLDEN_SIM_OVERRIDES


def test_simulation_golden_with_defaults(db):
    assert run_simulation(db, None) == GOLDEN_SIM_DEFAULTS


ACT_HEADER = (
    "exchange_rate", "total_items_count", "total_invoices_count", "estimated_total_fob_egp",
    "actual_total_fob_egp", "fob_variance_egp", "fob_variance_pct", "estimated_total_expenses_egp",
    "actual_total_expenses_egp", "expenses_variance_egp", "expenses_variance_pct",
    "estimated_total_landed_cost_egp", "actual_total_landed_cost_egp", "landed_variance_egp",
    "landed_variance_pct", "estimated_markup_factor", "actual_markup_factor", "variance_status",
)
ACT_ITEM = (
    "qty", "gross_weight_kg", "cbm", "fob_unit_egp", "fob_total_egp", "allocated_freight_egp",
    "allocated_insurance_egp", "allocated_customs_duty_egp", "allocated_vat_egp", "allocated_clearance_egp",
    "allocated_inland_transport_egp", "allocated_demurrage_egp", "allocated_other_egp",
    "total_allocated_expenses_egp", "actual_total_landed_cost_egp", "actual_unit_landed_cost_egp",
    "actual_markup_factor", "actual_markup_pct",
)


def act_snapshot(res):
    cats = {c.category: c for c in res.categories_breakdown}
    duty, vat = cats["Customs Duty"], cats["VAT & Taxes"]
    return {
        "header": [getattr(res, k) for k in ACT_HEADER],
        # The fixed 40/60 duty/VAT split of the estimate is replaced by the real split (FS-07): only the sum is pinned.
        "categories": [
            (c.category, c.actual_egp, c.invoices_count)
            + (() if c.category in ("Customs Duty", "VAT & Taxes") else (c.estimated_egp, c.variance_egp, c.variance_pct))
            for c in res.categories_breakdown
        ],
        "estimated_duty_plus_vat": round(duty.estimated_egp + vat.estimated_egp, 2),
        "items": [[getattr(i, k) for k in ACT_ITEM] for i in res.items_breakdown],
    }


@pytest.mark.parametrize("pref", ["Value-Based", "Weight-Based", "Equal"])
def test_actual_landed_cost_golden(db, pref):
    imp = seed_shipment(db, cbm=(12.0, 4.0))
    seed_actual_sources(db, imp)
    res = calculate_actual_landed_cost_service(
        db, imp.import_file_id, ActualLandedCostCalculationRequest(allocation_preference=pref)
    )
    assert act_snapshot(res) == GOLDEN_ACTUAL[pref]


# ──────────────────────────────────────────────────────────────────────────────
# 5. Odoo journal + CSV (no seller-paid rows, EGP invoices)
# ──────────────────────────────────────────────────────────────────────────────

ODOO_EXPENSES = [
    {"invoice_no": "FR-1", "category": "Freight", "provider_name": "Maersk", "currency": "EGP",
     "amount_fx": 50000.0, "exchange_rate": 1.0, "amount_egp": 50000.0, "allocation_rule": "Volume-Based"},
    {"invoice_no": "CU-1", "category": "Customs Duty", "provider_name": "Customs", "currency": "EGP",
     "amount_fx": 20000.0, "exchange_rate": 1.0, "amount_egp": 20000.0, "allocation_rule": "Value-Based"},
    {"invoice_no": "BR-1", "category": "Brokerage", "provider_name": "Broker", "currency": "EGP",
     "amount_fx": 3333.33, "exchange_rate": 1.0, "amount_egp": 3333.33, "allocation_rule": "Equal"},
    {"invoice_no": "TR-1", "category": "Local Transport", "provider_name": "Trucks", "currency": "EGP",
     "amount_fx": 4500.0, "exchange_rate": 1.0, "amount_egp": 4500.0, "allocation_rule": "Weight-Based"},
    {"invoice_no": "DM-1", "category": "Demurrage", "provider_name": "Line", "currency": "EGP",
     "amount_fx": 1200.5, "exchange_rate": 1.0, "amount_egp": 1200.5, "allocation_rule": "Value-Based"},
    {"invoice_no": "OT-1", "category": "Bank Charges", "provider_name": "Bank", "currency": "EGP",
     "amount_fx": 250.0, "exchange_rate": 1.0, "amount_egp": 250.0, "allocation_rule": "Value-Based"},
]
ODOO_ITEMS = [
    {"item_code": "I-1", "item_name": "Pumps", "qty": 10, "fob_unit_egp": 10000.0, "gross_weight_kg": 500.0, "cbm": 4.0},
    {"item_code": "I-2", "item_name": "Valves", "qty": 40, "fob_unit_egp": 2500.0, "gross_weight_kg": 200.0, "cbm": 2.0},
]


def seed_odoo_settlement(db, expenses=None):
    imp = ImportFile(import_file_code="IMP-P09-ODOO", company_name="P09 Importer", supplier_name="P09 Steel",
                     project_names="P09 Project", is_active=True)
    db.add(imp)
    db.flush()
    exp = copy.deepcopy(expenses if expenses is not None else ODOO_EXPENSES)
    calc = calculate_landed_cost_engine(exp, copy.deepcopy(ODOO_ITEMS))
    rec = LandedCostSettlementRecord(
        settlement_code="LCS-2026-0901", import_file_id=imp.import_file_id, incoterm_code="FOB",
        expense_invoices=exp, total_fob_egp=calc["total_fob_egp"], total_expenses_egp=calc["total_expenses_egp"],
        total_landed_cost_egp=calc["total_landed_cost_egp"], average_markup_factor=calc["average_markup_factor"],
        item_landed_costs=calc["item_landed_costs"], status="Calculated", accountant_name="acc",
        created_at=datetime(2026, 3, 10, 9, 30), is_active=True,
    )
    db.add(rec)
    db.commit()
    return rec


def test_odoo_journal_golden(db):
    rec = seed_odoo_settlement(db)
    entry = generate_odoo_journal_entry_service(db, rec.settlement_id)
    assert (entry.total_debit, entry.total_credit, entry.is_balanced, entry.difference) == GOLDEN_ODOO_TOTALS
    assert [
        (l.account_code, l.account_name, l.partner_name, l.label, l.debit, l.credit, l.currency, l.amount_currency,
         l.cost_category)
        for l in entry.lines
    ] == GOLDEN_ODOO_LINES


def test_odoo_csv_golden(db):
    rec = seed_odoo_settlement(db)
    csv_text = export_odoo_csv_service(db, rec.settlement_id).replace(
        f"importflow_settlement_{rec.settlement_id}", "importflow_settlement_<id>"
    )
    assert csv_text == GOLDEN_ODOO_CSV


# ──────────────────────────────────────────────────────────────────────────────
# Golden values (captured on the pre-fix code)
# Intended change since capture (customs review 2 #7): item B has qty 0.5, its unit landed cost and markup now
# divide by 0.5 instead of max(qty, 1) = 1 (both doubled). Every other value is the pre-fix capture.
# ──────────────────────────────────────────────────────────────────────────────
GOLDEN_ENGINE = {'Equal': {'average_markup_factor': 3.3263,
           'filled_amount_egp': 15550.955,
           'incoterm_code': 'CIF',
           'items': [[12345.599999999999,
                      4115.223333333333,
                      3292.1800000000003,
                      5183.651666666667,
                      1522.63,
                      370.36999999999995,
                      26829.655,
                      2682.9655,
                      2.173215963582167],
                     [4000.0,
                      4115.223333333333,
                      3292.1800000000003,
                      5183.651666666667,
                      1522.63,
                      370.36999999999995,
                      18484.055,
                      36968.11,
                      4.62101375],
                     [2333.31,
                      4115.223333333333,
                      3292.1800000000003,
                      5183.651666666667,
                      1522.63,
                      370.36999999999995,
                      16817.365,
                      2402.4807142857144,
                      7.207514217999323]],
           'total_expenses_egp': 43452.17,
           'total_fob_egp': 18678.91,
           'total_landed_cost_egp': 62131.07},
 'None': {'average_markup_factor': 3.3263,
          'filled_amount_egp': 15550.955,
          'incoterm_code': 'CIF',
          'items': [[12345.599999999999,
                     6172.835,
                     6527.77984496954,
                     9332.125766350475,
                     1522.63,
                     734.3747368556301,
                     36635.345348175644,
                     3663.5345348175642,
                     2.9674819650868036],
                    [4000.0,
                     2057.6116666666667,
                     2115.014205861049,
                     3726.639241138292,
                     1522.63,
                     237.9389375504245,
                     13659.834051216432,
                     27319.668102432865,
                     3.414958512804108],
                    [2333.31,
                     4115.223333333333,
                     1233.745949169411,
                     2492.189992511233,
                     1522.63,
                     138.79632559394523,
                     11835.89560060792,
                     1690.8422286582743,
                     5.072577411748941]],
          'total_expenses_egp': 43452.17,
          'total_fob_egp': 18678.91,
          'total_landed_cost_egp': 62131.07},
 'Value-Based': {'average_markup_factor': 3.3263,
                 'filled_amount_egp': 15550.955,
                 'incoterm_code': 'CIF',
                 'items': [[12345.599999999999,
                            8159.721501522305,
                            6527.77984496954,
                            10278.215915596787,
                            3019.0917341536524,
                            734.3747368556301,
                            41064.78373309791,
                            4106.478373309791,
                            3.3262687705010623],
                           [4000.0,
                            2643.7666866000213,
                            2115.014205861049,
                            3330.1632696982856,
                            978.1919822944702,
                            237.9389375504245,
                            13305.075082004252,
                            26610.150164008504,
                            3.326268770501063],
                           [2333.31,
                            1542.1818118776737,
                            1233.745949169411,
                            1942.5758147049264,
                            570.6062835518775,
                            138.79632559394523,
                            7761.216184897834,
                            1108.745169271119,
                            3.3262687705010623]],
                 'total_expenses_egp': 43452.17,
                 'total_fob_egp': 18678.91,
                 'total_landed_cost_egp': 62131.07},
 'Volume-Based': {'average_markup_factor': 3.3263,
                  'filled_amount_egp': 15550.955,
                  'incoterm_code': 'CIF',
                  'items': [[12345.599999999999,
                             6172.835,
                             4938.27,
                             7775.4775,
                             2283.945,
                             555.555,
                             34071.682499999995,
                             3407.1682499999997,
                             2.7598239453732503],
                            [4000.0,
                             2057.6116666666667,
                             1646.0900000000001,
                             2591.8258333333333,
                             761.315,
                             185.18499999999997,
                             11242.0275,
                             22484.055,
                             2.810506875],
                            [2333.31,
                             4115.223333333333,
                             3292.1800000000003,
                             5183.651666666667,
                             1522.63,
                             370.36999999999995,
                             16817.365,
                             2402.4807142857144,
                             7.207514217999323]],
                  'total_expenses_egp': 43452.17,
                  'total_fob_egp': 18678.91,
                  'total_landed_cost_egp': 62131.07},
 'Weight-Based': {'average_markup_factor': 3.3263,
                  'filled_amount_egp': 15550.955,
                  'incoterm_code': 'CIF',
                  'items': [[12345.599999999999,
                             7408.634717923116,
                             5926.9101747378945,
                             9332.125766350475,
                             2741.190104842736,
                             666.7769445831253,
                             38421.237708437344,
                             3842.1237708437343,
                             3.1121401720805264],
                            [4000.0,
                             2958.5230154767846,
                             2366.8193709435845,
                             3726.639241138292,
                             1094.6516225661508,
                             266.26699950074885,
                             14412.90024962556,
                             28825.80049925112,
                             3.60322506240639],
                            [2333.31,
                             1978.5122666000998,
                             1582.8104543185223,
                             2492.189992511233,
                             732.0482725911133,
                             178.06605591612578,
                             9296.937041937093,
                             1328.1338631338706,
                             3.98444143381595]],
                  'total_expenses_egp': 43452.17,
                  'total_fob_egp': 18678.91,
                  'total_landed_cost_egp': 62131.07}}

GOLDEN_SIM_OVERRIDES = {'currency': 'USD',
 'expenses': [('Ocean/Air Freight', 609.14, 30000.0, 'USD', 'Weight-Based'),
              ('Marine Insurance', 81.22, 4000.0, 'USD', 'Value-Based'),
              ('Customs Duties', 1293.15, 63687.5, 'EGP', 'Direct HS Code Allocation'),
              ('VAT & Taxes', 3543.22, 174503.75, 'EGP', 'Direct HS Code Allocation'),
              ('Customs Clearance & Brokerage', 83.25, 4100.0, 'EGP', 'Weight-Based'),
              ('Port & Terminal Handling (THC)', 105.58, 5200.0, 'EGP', 'Weight-Based'),
              ('Inland Transport', 148.22, 7300.0, 'EGP', 'Weight-Based'),
              ('Banking & Form 4 Fees', 52.79, 2600.0, 'EGP', 'Value-Based'),
              ('Inspection & Administrative', 38.58, 1900.0, 'EGP', 'Value-Based')],
 'header': [49.25,
            20000.0,
            985000.0,
            30000.0,
            4000.0,
            238191.25,
            9300.0,
            7300.0,
            4500.0,
            293291.25,
            1278291.25,
            25955.15,
            1.2978,
            29.78],
 'items': [[10.0,
            1500.0,
            15000.0,
            73875.0,
            738750.0,
            22500.0,
            3000.0,
            38212.5,
            119987.25,
            6975.0,
            5475.0,
            3375.0,
            199524.75,
            938274.75,
            93827.48,
            1905.13,
            1.2701,
            27.01],
           [50.0,
            100.0,
            5000.0,
            4925.0,
            246250.0,
            7500.0,
            1000.0,
            25475.0,
            54516.5,
            2325.0,
            1825.0,
            1125.0,
            93766.5,
            340016.5,
            6800.33,
            138.08,
            1.3808,
            38.08]]}

GOLDEN_SIM_DEFAULTS = {'currency': 'USD',
 'expenses': [('Ocean/Air Freight', 400.0, 20000.0, 'USD', 'Weight-Based'),
              ('Marine Insurance', 500.0, 25000.0, 'USD', 'Value-Based'),
              ('Customs Duties', 1306.25, 65312.5, 'EGP', 'Direct HS Code Allocation'),
              ('VAT & Taxes', 3579.12, 178956.25, 'EGP', 'Direct HS Code Allocation'),
              ('Customs Clearance & Brokerage', 90.0, 4500.0, 'EGP', 'Weight-Based'),
              ('Port & Terminal Handling (THC)', 100.0, 5000.0, 'EGP', 'Weight-Based'),
              ('Inland Transport', 150.0, 7500.0, 'EGP', 'Weight-Based'),
              ('Banking & Form 4 Fees', 50.0, 2500.0, 'EGP', 'Value-Based'),
              ('Inspection & Administrative', 40.0, 2000.0, 'EGP', 'Value-Based')],
 'header': [50.0,
            20000.0,
            1000000.0,
            20000.0,
            25000.0,
            244268.75,
            9500.0,
            7500.0,
            4500.0,
            310768.75,
            1310768.75,
            26215.38,
            1.3108,
            31.08],
 'items': [[10.0,
            1500.0,
            15000.0,
            75000.0,
            750000.0,
            15000.0,
            18750.0,
            39187.5,
            123048.75,
            7125.0,
            5625.0,
            3375.0,
            212111.25,
            962111.25,
            96211.12,
            1924.22,
            1.2828,
            28.28],
           [50.0,
            100.0,
            5000.0,
            5000.0,
            250000.0,
            5000.0,
            6250.0,
            26125.0,
            55907.5,
            2375.0,
            1875.0,
            1125.0,
            98657.5,
            348657.5,
            6973.15,
            139.46,
            1.3946,
            39.46]]}

GOLDEN_ACTUAL = {'Equal': {'categories': [('Freight', 15000.0, 1, 20000.0, -5000.0, -25.0),
                          ('Insurance', 0.0, 0, 25000.0, -25000.0, -100.0),
                          ('Customs Duty', 160000.0, 1),
                          ('VAT & Taxes', 0.0, 0),
                          ('Clearance & Port', 12000.0, 1, 9500.0, 2500.0, 26.32),
                          ('Inland Transport', 18000.0, 1, 7500.0, 10500.0, 140.0),
                          ('Demurrage & Storage', 0.0, 0, 0.0, 0.0, 0.0),
                          ('Other & Admin', 0.0, 0, 4500.0, -4500.0, -100.0)],
           'estimated_duty_plus_vat': 244268.75,
           'header': [48.5,
                      2,
                      5,
                      1000000.0,
                      970000.0,
                      -30000.0,
                      -3.0,
                      310768.75,
                      205000.0,
                      -105768.75,
                      -34.03,
                      1310768.75,
                      1175000.0,
                      -135768.75,
                      -10.36,
                      1.3108,
                      1.2113,
                      'UNDER_BUDGET'],
           'items': [[10.0,
                      3000.0,
                      12.0,
                      72750.0,
                      727500.0,
                      11250.0,
                      0.0,
                      120000.0,
                      0.0,
                      6000.0,
                      13500.0,
                      0.0,
                      0.0,
                      150750.0,
                      878250.0,
                      87825.0,
                      1.2072,
                      20.72],
                     [50.0,
                      1000.0,
                      4.0,
                      4850.0,
                      242500.0,
                      3750.0,
                      0.0,
                      40000.0,
                      0.0,
                      6000.0,
                      4500.0,
                      0.0,
                      0.0,
                      54250.0,
                      296750.0,
                      5935.0,
                      1.2237,
                      22.37]]},
 'Value-Based': {'categories': [('Freight', 15000.0, 1, 20000.0, -5000.0, -25.0),
                                ('Insurance', 0.0, 0, 25000.0, -25000.0, -100.0),
                                ('Customs Duty', 160000.0, 1),
                                ('VAT & Taxes', 0.0, 0),
                                ('Clearance & Port', 12000.0, 1, 9500.0, 2500.0, 26.32),
                                ('Inland Transport', 18000.0, 1, 7500.0, 10500.0, 140.0),
                                ('Demurrage & Storage', 0.0, 0, 0.0, 0.0, 0.0),
                                ('Other & Admin', 0.0, 0, 4500.0, -4500.0, -100.0)],
                 'estimated_duty_plus_vat': 244268.75,
                 'header': [48.5,
                            2,
                            5,
                            1000000.0,
                            970000.0,
                            -30000.0,
                            -3.0,
                            310768.75,
                            205000.0,
                            -105768.75,
                            -34.03,
                            1310768.75,
                            1175000.0,
                            -135768.75,
                            -10.36,
                            1.3108,
                            1.2113,
                            'UNDER_BUDGET'],
                 'items': [[10.0,
                            3000.0,
                            12.0,
                            72750.0,
                            727500.0,
                            11250.0,
                            0.0,
                            120000.0,
                            0.0,
                            9000.0,
                            13500.0,
                            0.0,
                            0.0,
                            153750.0,
                            881250.0,
                            88125.0,
                            1.2113,
                            21.13],
                           [50.0,
                            1000.0,
                            4.0,
                            4850.0,
                            242500.0,
                            3750.0,
                            0.0,
                            40000.0,
                            0.0,
                            3000.0,
                            4500.0,
                            0.0,
                            0.0,
                            51250.0,
                            293750.0,
                            5875.0,
                            1.2113,
                            21.13]]},
 'Weight-Based': {'categories': [('Freight', 15000.0, 1, 20000.0, -5000.0, -25.0),
                                 ('Insurance', 0.0, 0, 25000.0, -25000.0, -100.0),
                                 ('Customs Duty', 160000.0, 1),
                                 ('VAT & Taxes', 0.0, 0),
                                 ('Clearance & Port', 12000.0, 1, 9500.0, 2500.0, 26.32),
                                 ('Inland Transport', 18000.0, 1, 7500.0, 10500.0, 140.0),
                                 ('Demurrage & Storage', 0.0, 0, 0.0, 0.0, 0.0),
                                 ('Other & Admin', 0.0, 0, 4500.0, -4500.0, -100.0)],
                  'estimated_duty_plus_vat': 244268.75,
                  'header': [48.5,
                             2,
                             5,
                             1000000.0,
                             970000.0,
                             -30000.0,
                             -3.0,
                             310768.75,
                             205000.0,
                             -105768.75,
                             -34.03,
                             1310768.75,
                             1175000.0,
                             -135768.75,
                             -10.36,
                             1.3108,
                             1.2113,
                             'UNDER_BUDGET'],
                  'items': [[10.0,
                             3000.0,
                             12.0,
                             72750.0,
                             727500.0,
                             11250.0,
                             0.0,
                             120000.0,
                             0.0,
                             9000.0,
                             13500.0,
                             0.0,
                             0.0,
                             153750.0,
                             881250.0,
                             88125.0,
                             1.2113,
                             21.13],
                            [50.0,
                             1000.0,
                             4.0,
                             4850.0,
                             242500.0,
                             3750.0,
                             0.0,
                             40000.0,
                             0.0,
                             3000.0,
                             4500.0,
                             0.0,
                             0.0,
                             51250.0,
                             293750.0,
                             5875.0,
                             1.2113,
                             21.13]]}}

GOLDEN_ODOO_TOTALS = (279283.83, 279283.83, True, 0.0)

GOLDEN_ODOO_LINES = [('110400',
  'بضاعة بالطريق - Goods in Transit (Landed Cost)',
  'P09 Importer',
  'إثبات تكلفة وصول الشحنة الإجمالية (Landed Cost) - ملف IMP-P09-ODOO',
  279283.83,
  0.0,
  'EGP',
  None,
  'Goods'),
 ('210100',
  'موردون خارجيون - P09 Steel',
  'P09 Steel',
  'قيمة بضاعة الفاتورة التجارية (FOB Goods) - المورد P09 Steel',
  0.0,
  200000.0,
  'EGP',
  None,
  'Goods'),
 ('210200',
  'موردو خدمات الشحن والنولون - Maersk',
  'Maersk',
  'فاتورة نولون شحن رقم FR-1 - شركة Maersk',
  0.0,
  50000.0,
  'EGP',
  None,
  'Freight'),
 ('210500',
  'مصلحة الجمارك والضرائب - Customs',
  'Customs',
  'مطالبة جمركية ورسوم إقرار 46 رقم CU-1 - Customs',
  0.0,
  20000.0,
  'EGP',
  None,
  'Customs'),
 ('210300',
  'مستخلصو الجمارك والأتعاب - Broker',
  'Broker',
  'أتعاب ومصاريف تخليص جمركي فاتورة BR-1 - Broker',
  0.0,
  3333.33,
  'EGP',
  None,
  'Clearance'),
 ('210400',
  'مقاولو النقل الداخلي - Trucks',
  'Trucks',
  'فاتورة نقل داخلي وتعتيق رقم TR-1 - Trucks',
  0.0,
  4500.0,
  'EGP',
  None,
  'Transport'),
 ('210600',
  'غرامات أرضيات وتأخير حاويات - Line',
  'Line',
  'غرامات أرضيات وتأخير حاويات فاتورة DM-1 - Line',
  0.0,
  1200.5,
  'EGP',
  None,
  'Demurrage'),
 ('210800',
  'مصروفات استيراد متنوعة - Bank',
  'Bank',
  'مصروفات استيرادية Bank Charges فاتورة OT-1 - Bank',
  0.0,
  250.0,
  'EGP',
  None,
  'Other')]

GOLDEN_ODOO_CSV = 'id,date,ref,journal_id/code,line_ids/account_id/code,line_ids/partner_id/name,line_ids/name,line_ids/debit,line_ids/credit,line_ids/currency_id/name,line_ids/amount_currency,line_ids/analytic_distribution\r\nimportflow_settlement_<id>,2026-03-10,IMP-P09-ODOO / LCS-2026-0901,MISC,110400,P09 Importer,إثبات تكلفة وصول الشحنة الإجمالية (Landed Cost) - ملف IMP-P09-ODOO,279283.83,0.00,EGP,,P09 Project\r\n,,,,210100,P09 Steel,قيمة بضاعة الفاتورة التجارية (FOB Goods) - المورد P09 Steel,0.00,200000.00,EGP,,P09 Project\r\n,,,,210200,Maersk,فاتورة نولون شحن رقم FR-1 - شركة Maersk,0.00,50000.00,EGP,,P09 Project\r\n,,,,210500,Customs,مطالبة جمركية ورسوم إقرار 46 رقم CU-1 - Customs,0.00,20000.00,EGP,,P09 Project\r\n,,,,210300,Broker,أتعاب ومصاريف تخليص جمركي فاتورة BR-1 - Broker,0.00,3333.33,EGP,,P09 Project\r\n,,,,210400,Trucks,فاتورة نقل داخلي وتعتيق رقم TR-1 - Trucks,0.00,4500.00,EGP,,P09 Project\r\n,,,,210600,Line,غرامات أرضيات وتأخير حاويات فاتورة DM-1 - Line,0.00,1200.50,EGP,,P09 Project\r\n,,,,210800,Bank,مصروفات استيرادية Bank Charges فاتورة OT-1 - Bank,0.00,250.00,EGP,,P09 Project\r\n'
