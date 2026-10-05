"""Phase-1 characterization tests (package T of docs/plans/phase-01-quality-simplify-plan.md, section 4).

These tests pin the CURRENT behaviour (git 8f776ae) of the Phase-1 planning modules before the
purchase_orders / cbm_calculator / shipping_scenarios refactor starts. Every expected number is a golden
value computed from today's formulas (PO volumetric = CBM x 167; CBM calculator = L x W x H(cm) / 6000).

A refactor that is meant to be behaviour-preserving must keep every test here green without editing it.
Tests whose expected values WILL change because of an approved decision are listed in
``EXPECTED_TO_CHANGE`` below: the owner of that change updates the listed test in the same PR and says so.
"""

from datetime import date, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  registers every SQLAlchemy model in Base.metadata (conftest set DATABASE_PATH)
from database.database import Base
from modules.cbm_calculator.schemas import CBMItemCreate, CBMQuickCalcRequest
from modules.cbm_calculator.service import CBMService
from modules.currencies.model import Currency
from modules.import_companies.model import ImportCompany
from modules.customs_tariff.schemas import CustomsTariffCreate
from modules.customs_tariff.service import create_tariff_service
from modules.import_companies.schemas import ImportCompanyCreate
from modules.import_companies.service import create_import_company
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.purchase_orders.model import POLineItem, PurchaseOrder
from modules.purchase_orders.schemas import (
    ClonePurchaseOrderRequest,
    PackingListItemCreate,
    PalletPlanItem,
    POLineItemCreate,
    POShipmentAllocationCreate,
    PurchaseOrderCreate,
    PurchaseOrderUpdate,
)
from modules.purchase_orders.service import PurchaseOrderService
from modules.shipping_scenarios.schemas import ShippingEvaluationCreate, ShippingScenarioItemCreate
from modules.shipping_scenarios.service import ShippingScenarioService
from modules.suppliers.model import Supplier


# Test names whose pinned values are EXPECTED to change under an approved Phase-1 decision.
# Approved decisions:
#   (a) CBM calculator switches to the configurable air volumetric factor (default 167 kg per CBM) instead of /6000.
#   (b) Over-allocation stays allowed but must emit an OVER_SHIPPED warning.
#   (c) PO / CBM status and recommendation values are stored as codes.
#   (d) PO line item ids stay stable across PO updates.
# Everything NOT listed here must stay byte-identical through the refactor.
EXPECTED_TO_CHANGE = [
    # (d) UPDATED by package A: an update that sends `items` WITH their item_id updates the rows in place (same
    # ids, extraction columns invoice_number / customs_unit_price kept). Rows sent without an id are new rows.
    "test_update_with_item_ids_keeps_line_rows_and_extraction_columns",
    # (b) + (c) UPDATED by package A: over-allocation is still accepted but returns an OVER_SHIPPED warning, and
    # the stored PO status is a PO_STATUS code. The balance labels and every number are unchanged.
    "test_balance_single_line_fallback_and_over_shipped",
    # (c) UPDATED by package A: PO status code; lead finding (2): the balance totals and status now count the
    # PO-level allocation like the header status does (the line breakdown still does not distribute it);
    # lead finding (4): the overall percentage is value-weighted (37.5 = 300 / 800).
    "test_balance_multi_line_general_allocation_is_not_distributed",
    # (c) UPDATED by package A: PO status code; lead finding (1): the status is decided on the raw quantities, so
    # 99.96 % (displayed 100.0) is "Partially Shipped" while 4 units remain.
    "test_balance_percent_rounding_reports_fully_shipped_before_last_units",
    # (a): volumetric weight 166.67 (/6000) becomes 167.0 with the 167 factor; chargeable weight follows.
    "test_cbm_one_cubic_metre_volumetric_weight_uses_the_air_factor",
    # (c): recommended_shipping_method / recommended_container_type are bilingual labels today. The bracket
    # boundaries and container counts must not change.
    "test_cbm_recommendation_brackets",
    # (c): smart_hybrid_containers / flat_only_containers are label strings today. Counts must not change.
    "test_cbm_hybrid_vs_flat_container_counts",
    # (c) UPDATED by package A: PO status label "Draft" on the clone is now the DRAFT code.
    "test_clone_keeps_commercial_terms_and_recomputes_totals",
]


# ---------------------------------------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------------------------------------

@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()

    company = create_import_company(
        session,
        ImportCompanyCreate(
            importer_name="Characterization Importer",
            address="Cairo",
            country="Egypt",
            importer_id="IMP-700100",
            importer_id_expiry=date.today() + timedelta(days=120),
            vat_id="VAT-700100",
            vat_id_expiry=date.today() + timedelta(days=90),
            registration_number="REG-700100",
            registration_expiry=date.today() + timedelta(days=60),
        ),
    )
    supplier = Supplier(
        supplier_code="SUP-CHR-001",
        company_name="Characterization Supplier",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-CHR-1",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin",
        is_active=True,
    )
    incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
    currency = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    session.add_all([company, supplier, incoterm, currency])
    session.commit()

    project = Project(
        project_code="PRJ-CHR-001",
        project_name="Characterization Project",
        project_owner="Eng. Test",
        company_id=company.company_id,
        supplier_id=supplier.supplier_id,
        incoterm_id=incoterm.incoterm_id,
        is_active=True,
    )
    session.add(project)
    session.commit()

    create_tariff_service(
        session,
        CustomsTariffCreate(
            hs_code="85414000",
            hs_description="Solar Panels",
            customs_duty_rate=Decimal("5.00"),
            vat_rate=Decimal("14.00"),
        ),
    )

    yield session
    session.close()
    engine.dispose()


def _header(db, **overrides) -> dict:
    data = dict(
        project_id=db.query(Project).first().project_id,
        company_id=db.query(ImportCompany).first().company_id,
        supplier_id=db.query(Supplier).first().supplier_id,
        incoterm_id=db.query(Incoterm).first().incoterm_id,
        currency_id=db.query(Currency).first().currency_id,
    )
    data.update(overrides)
    return data


def _line(**overrides) -> POLineItemCreate:
    data = dict(
        item_code="SOLAR-550",
        description_ar="ألواح شمسية 550 واط",
        tariff_id=None,
        quantity=100.0,
        unit_price=200.0,
        cbm_per_unit=0.2,
        gross_weight_kg=5000.0,
        net_weight_kg=4800.0,
    )
    data.update(overrides)
    return POLineItemCreate(**data)


def _packing(**overrides) -> PackingListItemCreate:
    data = dict(
        hs_code="85414000",
        item_code="SOLAR-550",
        qty_pcs=100.0,
        qty_pkg=10.0,
        unit="cm",
        length_cm=50.0,
        width_cm=40.0,
        height_cm=30.0,
        net_weight_unit_kg=9.0,
        gross_weight_unit_kg=100.0,
    )
    data.update(overrides)
    return PackingListItemCreate(**data)


def _create_po(db, **overrides):
    items = overrides.pop("items", [_line()])
    return PurchaseOrderService(db).create(PurchaseOrderCreate(items=items, **_header(db, **overrides)))


def _stored(db, po_id: int) -> PurchaseOrder:
    db.expire_all()
    return db.get(PurchaseOrder, po_id)


# ---------------------------------------------------------------------------------------------------------
# 1. Pallet plan overrides CBM, gross and package count; pallet_count is overwritten
# ---------------------------------------------------------------------------------------------------------

def test_create_with_pallet_plan_overrides_totals_and_pallet_count(db_session):
    po = _create_po(
        db_session,
        pallet_count=7,  # header value is overwritten by the plan total (3 + 2)
        pallet_plan=[
            # 1.2 x 0.8 x 1.5 = 1.44 m3 x 3 = 4.32 ; 333.333 x 3 = 999.999 kg
            PalletPlanItem(pallet_count=3, length_cm=120.0, width_cm=80.0, height_cm=150.0, gross_weight_per_pallet_kg=333.333),
            # 1.0 m3 x 2 = 2.0 ; 250.0005 x 2 = 500.001 kg
            PalletPlanItem(pallet_count=2, length_cm=100.0, width_cm=100.0, height_cm=100.0, gross_weight_per_pallet_kg=250.0005),
        ],
    )

    # Line math is still applied to the FOB value: 100 x 200.
    assert po.total_amount_fob == 20000.0
    # Pallet plan replaces the line CBM (100 x 0.2 = 20) and line gross (5000) and line packages (100).
    assert po.total_cbm == 6.32
    # 999.999 + 500.001 = 1500.0 (snapped at 0.005)
    assert po.total_gross_weight_kg == 1500.0
    assert po.total_packages_count == 5
    assert po.pallet_count == 5
    # Net weight is never touched by the pallet plan.
    assert po.total_net_weight_kg == 4800.0
    assert [p.pallet_count for p in po.pallet_plan] == [3, 2]
    assert _stored(db_session, po.po_id).pallet_count == 5


def test_create_pallet_plan_gross_not_snapped_beyond_tolerance(db_session):
    po = _create_po(
        db_session,
        pallet_plan=[PalletPlanItem(pallet_count=2, length_cm=120.0, width_cm=80.0, height_cm=150.0, gross_weight_per_pallet_kg=100.004)],
    )
    # 200.008 is 0.008 away from 200: outside the 0.005 snap, kept as is.
    assert po.total_gross_weight_kg == 200.008
    assert po.total_cbm == 2.88
    assert po.total_packages_count == 2


# ---------------------------------------------------------------------------------------------------------
# 2. Pallet dims only (no plan): fallback CBM from the PO pallet dims
# ---------------------------------------------------------------------------------------------------------

def test_create_with_pallet_dims_only_uses_fallback_cbm(db_session):
    po = _create_po(
        db_session,
        pallet_count=4,
        pallet_length_cm=120.0,
        pallet_width_cm=100.0,
        pallet_height_cm=160.0,
    )
    # round(1.2 x 1.0 x 1.6 x 4, 4) = 7.68 replaces the line CBM (20); packages = pallet count.
    assert po.total_cbm == 7.68
    assert po.total_packages_count == 4
    # Gross / net stay from the line items: the fallback has no weight.
    assert po.total_gross_weight_kg == 5000.0
    assert po.total_net_weight_kg == 4800.0
    assert po.pallet_plan == []
    assert _stored(db_session, po.po_id).pallet_plan is None


def test_create_with_zero_pallet_count_keeps_line_totals(db_session):
    po = _create_po(db_session)  # default pallet_count 0 with the default 120 x 80 x 150 dims
    assert po.total_cbm == 20.0
    assert po.total_gross_weight_kg == 5000.0
    # No packing list and no pallets: commercial quantity is counted as packages (PO-18, kept).
    assert po.total_packages_count == 100


# ---------------------------------------------------------------------------------------------------------
# 3. Packing gross vs line gross tolerance (< 0.1 kg keeps the line gross)
# ---------------------------------------------------------------------------------------------------------

@pytest.mark.parametrize(
    "line_gross, expected_total_gross",
    [
        (1000.05, 1000.05),  # 0.05 kg apart: certified line gross kept
        (1000.1, 1000.0),    # 0.1 kg apart (float 0.10000000000002) is not < 0.1: packing gross wins
        (1000.2, 1000.0),    # 0.2 kg apart: packing gross wins
    ],
)
def test_packing_gross_tolerance_against_line_gross(db_session, line_gross, expected_total_gross):
    po = _create_po(
        db_session,
        items=[_line(gross_weight_kg=line_gross, cbm_per_unit=0.1)],
        packing_list_items=[_packing()],  # 10 pkg x 100 kg = 1000 kg ; 10 x 0.5 x 0.4 x 0.3 = 0.6 m3
    )
    assert po.total_gross_weight_kg == expected_total_gross
    # Packing CBM (0.6) beats line CBM (100 x 0.1 = 10); packing package count beats line quantity.
    assert po.total_cbm == 0.6
    assert po.total_packages_count == 10
    # Packing net (10 x 9) replaces the line net.
    assert po.total_net_weight_kg == 90.0


def test_packing_gross_snapped_at_half_gram_tolerance(db_session):
    po = _create_po(
        db_session,
        items=[_line(gross_weight_kg=0.0, net_weight_kg=0.0)],
        # 3 x 333.3333 = 999.9999 -> snapped to 1000.0 ; net 3 x 33.3333 = 99.9999 -> 100.0
        packing_list_items=[_packing(qty_pkg=3.0, gross_weight_unit_kg=333.3333, net_weight_unit_kg=33.3333)],
    )
    assert po.total_gross_weight_kg == 1000.0
    assert po.total_net_weight_kg == 100.0
    row = po.packing_list_items[0]
    # Row totals keep the unsnapped round(x, 16) value.
    assert row.total_gross_weight_kg == 999.9999
    assert row.total_net_weight_kg == 99.9999


# ---------------------------------------------------------------------------------------------------------
# 4. Packing row with zero dims keeps the direct total_cbm; chargeable weight uses x167
# ---------------------------------------------------------------------------------------------------------

def test_packing_row_direct_cbm_and_chargeable_weight_x167(db_session):
    po = _create_po(
        db_session,
        packing_list_items=[
            # zero dims -> direct CBM 2.5 kept ; chargeable = max(2 x 100, round(2.5 x 167, 2)) = 417.5
            _packing(item_code="A", qty_pkg=2.0, length_cm=0.0, width_cm=0.0, height_cm=0.0, total_cbm=2.5),
            # dims win over the direct value: round(2 x 1.2 x 0.8 x 1.0, 4) = 1.92 ; max(200, 320.64) = 320.64
            _packing(item_code="B", qty_pkg=2.0, length_cm=120.0, width_cm=80.0, height_cm=100.0, total_cbm=9.99),
            # gross dominates: 0.1 x 167 = 16.7 < 50
            _packing(item_code="C", qty_pkg=1.0, length_cm=0.0, width_cm=0.0, height_cm=0.0, total_cbm=0.1,
                     gross_weight_unit_kg=50.0),
        ],
    )
    rows = {r.item_code: r for r in po.packing_list_items}
    assert rows["A"].total_cbm == 2.5
    assert rows["A"].chargeable_weight_kg == 417.5
    assert rows["B"].total_cbm == 1.92
    assert rows["B"].chargeable_weight_kg == 320.64
    assert rows["C"].total_cbm == 0.1
    assert rows["C"].chargeable_weight_kg == 50.0
    assert po.total_cbm == 4.52
    # 200 + 200 + 50 = 450 replaces the line gross (5000).
    assert po.total_gross_weight_kg == 450.0
    assert po.total_packages_count == 5


# ---------------------------------------------------------------------------------------------------------
# 5. Units mm and m store the same length_cm and the same CBM as cm
# ---------------------------------------------------------------------------------------------------------

@pytest.mark.parametrize(
    "unit, dims",
    [
        ("cm", (120.0, 80.0, 100.0)),
        ("mm", (1200.0, 800.0, 1000.0)),
        ("m", (1.2, 0.8, 1.0)),
    ],
)
def test_packing_units_normalise_to_cm(db_session, unit, dims):
    length, width, height = dims
    po = _create_po(
        db_session,
        packing_list_items=[_packing(qty_pkg=5.0, unit=unit, length_cm=length, width_cm=width, height_cm=height)],
    )
    row = po.packing_list_items[0]
    assert (row.length_cm, row.width_cm, row.height_cm) == (120.0, 80.0, 100.0)
    # round(5 x 1.2 x 0.8 x 1.0, 4) = 4.8 ; chargeable max(500, round(4.8 x 167, 2) = 801.6)
    assert row.total_cbm == 4.8
    assert row.chargeable_weight_kg == 801.6
    assert po.total_cbm == 4.8
    # `unit` is never persisted: the response reports the schema default.
    assert row.unit == "cm"


# ---------------------------------------------------------------------------------------------------------
# 6. Update without pallet_plan re-applies the stored plan
# ---------------------------------------------------------------------------------------------------------

def test_update_without_pallet_plan_reapplies_stored_plan(db_session):
    service = PurchaseOrderService(db_session)
    po = _create_po(
        db_session,
        pallet_plan=[PalletPlanItem(pallet_count=3, length_cm=120.0, width_cm=80.0, height_cm=150.0, gross_weight_per_pallet_kg=300.0)],
    )
    assert (po.total_cbm, po.total_gross_weight_kg, po.total_packages_count) == (4.32, 900.0, 3)

    updated = service.update(
        po.po_id,
        PurchaseOrderUpdate(items=[_line(quantity=50.0, unit_price=10.0, cbm_per_unit=1.0, gross_weight_kg=7000.0)]),
    )
    # FOB follows the new lines; CBM / gross / packages still come from the stored pallet plan.
    assert updated.total_amount_fob == 500.0
    assert updated.total_cbm == 4.32
    assert updated.total_gross_weight_kg == 900.0
    assert updated.total_packages_count == 3
    assert updated.pallet_count == 3
    assert updated.version == 2


# ---------------------------------------------------------------------------------------------------------
# 7. Header-only update leaves the totals unchanged
# ---------------------------------------------------------------------------------------------------------

def test_header_only_update_keeps_totals_and_item_ids(db_session):
    service = PurchaseOrderService(db_session)
    po = _create_po(
        db_session,
        items=[_line(gross_weight_kg=1000.05, cbm_per_unit=0.1)],
        packing_list_items=[_packing()],
    )
    before = (po.total_amount_fob, po.total_cbm, po.total_gross_weight_kg, po.total_net_weight_kg, po.total_packages_count)
    assert before == (20000.0, 0.6, 1000.05, 90.0, 10)

    updated = service.update(po.po_id, PurchaseOrderUpdate(notes="  header only  ", payment_terms="TT 30 days", version=1))

    after = (updated.total_amount_fob, updated.total_cbm, updated.total_gross_weight_kg,
             updated.total_net_weight_kg, updated.total_packages_count)
    assert after == before
    assert updated.notes == "header only"
    assert updated.version == 2
    assert [i.item_id for i in updated.items] == [i.item_id for i in po.items]
    assert [p.packing_item_id for p in updated.packing_list_items] == [p.packing_item_id for p in po.packing_list_items]


def test_update_with_item_ids_keeps_line_rows_and_extraction_columns(db_session):
    """EXPECTED_TO_CHANGE (d), updated by package A: PO-01 upsert by item_id."""
    service = PurchaseOrderService(db_session)
    po = _create_po(db_session)
    old_id = po.items[0].item_id
    row = db_session.get(POLineItem, old_id)
    row.invoice_number = "INV-001"
    row.customs_unit_price = Decimal("190.0000")
    db_session.commit()

    updated = service.update(po.po_id, PurchaseOrderUpdate(items=[_line(item_id=old_id)]))

    assert updated.items[0].item_id == old_id
    db_session.expire_all()
    kept = db_session.get(POLineItem, old_id)
    assert kept.invoice_number == "INV-001"
    assert float(kept.customs_unit_price) == 190.0
    assert updated.total_amount_fob == 20000.0
    assert updated.total_cbm == 20.0


# ---------------------------------------------------------------------------------------------------------
# 8. Balance: single-line fallback for PO-level allocations; over-shipment
# ---------------------------------------------------------------------------------------------------------

def _allocate(service, po_id, qty, fob, ref, item_id=None):
    return service.allocate_shipment(
        po_id,
        POShipmentAllocationCreate(po_item_id=item_id, shipment_ref=ref, shipped_quantity=qty, shipped_amount_fob=fob),
    )


def test_balance_single_line_fallback_and_over_shipped(db_session):
    """EXPECTED_TO_CHANGE (b) + (c)."""
    service = PurchaseOrderService(db_session)
    po = _create_po(db_session, items=[_line(quantity=100.0, unit_price=10.0)])

    first = _allocate(service, po.po_id, 40.0, 400.0, "BL-001")  # no po_item_id: PO-level allocation
    assert first.messages == []
    assert _stored(db_session, po.po_id).status == "PARTIALLY_SHIPPED"
    bal = service.compute_po_balance(po.po_id)
    line = bal.line_items_balance[0]
    assert (line.shipped_qty, line.remaining_qty, line.fulfillment_percent) == (40.0, 60.0, 40.0)
    assert (line.shipped_amount_fob, line.remaining_amount_fob) == (400.0, 600.0)
    assert bal.overall_fulfillment_percent == 40.0
    assert bal.fulfillment_status == "Partially Shipped"

    # Over-allocation is accepted, with an OVER_SHIPPED warning.
    second = _allocate(service, po.po_id, 70.0, 700.0, "BL-002")
    assert [(m.code, m.severity, m.params["shipped_qty"], m.params["ordered_qty"]) for m in second.messages] == [
        ("OVER_SHIPPED", "warning", 110.0, 100.0)
    ]
    assert _stored(db_session, po.po_id).status == "FULLY_SHIPPED"
    bal = service.compute_po_balance(po.po_id)
    line = bal.line_items_balance[0]
    assert (line.shipped_qty, line.remaining_qty, line.fulfillment_percent) == (110.0, 0.0, 110.0)
    assert (line.shipped_amount_fob, line.remaining_amount_fob) == (1100.0, 0.0)
    assert (bal.total_ordered_qty, bal.total_shipped_qty, bal.total_remaining_qty) == (100.0, 110.0, 0.0)
    assert (bal.total_ordered_amount_fob, bal.total_shipped_amount_fob, bal.total_remaining_amount_fob) == (1000.0, 1100.0, 0.0)
    assert bal.overall_fulfillment_percent == 110.0
    assert bal.fulfillment_status == "Over-Shipped"
    assert bal.currency_code == "USD"
    assert len(bal.allocations) == 2


def test_balance_multi_line_general_allocation_is_not_distributed(db_session):
    """EXPECTED_TO_CHANGE (c): status labels only."""
    service = PurchaseOrderService(db_session)
    po = _create_po(
        db_session,
        items=[_line(item_code="A", quantity=60.0, unit_price=10.0), _line(item_code="B", quantity=40.0, unit_price=5.0)],
    )
    _allocate(service, po.po_id, 30.0, 300.0, "BL-001")

    # The PO header status counts every allocation...
    assert _stored(db_session, po.po_id).status == "PARTIALLY_SHIPPED"
    # ...and so do the balance totals; the line breakdown does not distribute a PO-level allocation.
    bal = service.compute_po_balance(po.po_id)
    assert [l.shipped_qty for l in bal.line_items_balance] == [0.0, 0.0]
    assert (bal.total_shipped_qty, bal.total_remaining_qty) == (30.0, 70.0)
    assert (bal.total_ordered_amount_fob, bal.total_shipped_amount_fob, bal.total_remaining_amount_fob) == (800.0, 300.0, 500.0)
    # lead finding (4): value-weighted percentage, 300 FOB shipped of 800 ordered value
    assert bal.overall_fulfillment_percent == 37.5
    assert bal.fulfillment_status == "Partially Shipped"


def test_balance_percent_rounding_reports_fully_shipped_before_last_units(db_session):
    """EXPECTED_TO_CHANGE (c): status labels only."""
    service = PurchaseOrderService(db_session)
    po = _create_po(db_session, items=[_line(quantity=10000.0, unit_price=1.0)])
    item_id = po.items[0].item_id
    _allocate(service, po.po_id, 9996.0, 9996.0, "BL-001", item_id=item_id)

    assert _stored(db_session, po.po_id).status == "PARTIALLY_SHIPPED"
    bal = service.compute_po_balance(po.po_id)
    # 99.96 % is displayed rounded (100.0) but the status comes from the 4 remaining units.
    assert bal.overall_fulfillment_percent == 100.0
    assert bal.fulfillment_status == "Partially Shipped"
    assert bal.total_remaining_qty == 4.0
    assert bal.line_items_balance[0].fulfillment_percent == 100.0


# ---------------------------------------------------------------------------------------------------------
# 9. CBM calculator golden values (x167 configurable air factor, recommendation brackets)
# ---------------------------------------------------------------------------------------------------------

def _quick(length_m: float, gross_kg: float = 0.0, qty: int = 1):
    item = CBMItemCreate(quantity=qty, length=length_m, width=1.0, height=1.0, unit="m", gross_weight_per_unit_kg=gross_kg)
    return CBMService.quick_calculate(CBMQuickCalcRequest(items=[item]))


def test_cbm_one_cubic_metre_volumetric_weight_uses_the_air_factor():
    """CHANGED (a), package B: the configurable air factor (default 167 kg/CBM) replaced /6000 (166.67)."""
    res = CBMService.quick_calculate(
        CBMQuickCalcRequest(items=[CBMItemCreate(quantity=1, length=100.0, width=100.0, height=100.0, unit="cm")])
    )
    assert res.total_cbm == 1.0
    assert res.total_volumetric_weight_kg == 167.0
    assert res.air_chargeable_weight_kg == 167.0
    assert res.items[0]["volumetric_weight_kg"] == 167.0

    # Gross above volumetric wins.
    res = _quick(1.0, gross_kg=200.0)
    assert res.air_chargeable_weight_kg == 200.0


@pytest.mark.parametrize(
    "length_m, gross_kg, method, container, count",
    [
        (1.5, 300.0, "AIR", None, 0),
        (1.5, 300.01, "LCL", "LCL", 1),
        (1.51, 0.0, "LCL", "LCL", 1),
        (15.0, 0.0, "LCL", "LCL", 1),
        (15.01, 0.0, "FCL", "C20_ST", 1),
        (33.0, 0.0, "FCL", "C20_ST", 1),
        (33.01, 0.0, "FCL", "C40_ST", 1),
        (67.0, 0.0, "FCL", "C40_ST", 1),
        (67.01, 0.0, "FCL", "C40_HC", 1),
        (76.0, 0.0, "FCL", "C40_HC", 1),
        (76.01, 0.0, "FCL", "C40_HC", 2),
        (152.0, 0.0, "FCL", "C40_HC", 2),
        (152.01, 0.0, "FCL", "C40_HC", 3),
    ],
)
def test_cbm_recommendation_brackets(length_m, gross_kg, method, container, count):
    """CHANGED (c), package B: SHIPPING_METHOD / CONTAINER_TYPE codes; brackets and counts unchanged."""
    res = _quick(length_m, gross_kg=gross_kg)
    assert res.total_cbm == length_m
    assert res.recommended_shipping_method == method
    assert res.recommended_container_type == container
    assert res.recommended_container_count == count


@pytest.mark.parametrize(
    "length_m, hybrid, flat, savings",
    [
        (1.0, 1, 1, 0),
        (53.0, 1, 1, 0),
        (53.01, 1, 2, 1),
        (74.0, 1, 2, 1),
        (74.01, 2, 2, 0),
        (106.01, 2, 3, 1),
        (148.0, 2, 3, 1),
    ],
)
def test_cbm_hybrid_vs_flat_container_counts(length_m, hybrid, flat, savings):
    """CHANGED (c), package B: "<n> x C40_HC" code text; the ceil(cbm / 74) and ceil(cbm / 53) counts unchanged."""
    res = _quick(length_m)
    assert res.smart_hybrid_containers == f"{hybrid} x C40_HC"
    assert res.flat_only_containers == f"{flat} x C40_HC"
    assert (res.smart_hybrid_containers_count, res.flat_only_containers_count) == (hybrid, flat)
    assert res.hybrid_savings_count == savings


def test_cbm_rounding_points():
    # 3 x (33.3 x 33.3 x 33.3 cm): line CBM round 4, volumetric round 2, gross round 2.
    res = CBMService.quick_calculate(
        CBMQuickCalcRequest(items=[
            CBMItemCreate(quantity=3, length=33.3, width=33.3, height=33.3, unit="cm", gross_weight_per_unit_kg=1.005),
            CBMItemCreate(quantity=7, length=333.0, width=222.0, height=111.0, unit="mm", gross_weight_per_unit_kg=0.333),
        ])
    )
    assert res.total_qty == 10
    assert res.items[0]["total_cbm"] == 0.1108
    # Volumetric values follow the approved 167 kg/CBM factor (were 18.46 / 9.57 / 28.04 with /6000).
    assert res.items[0]["volumetric_weight_kg"] == 18.5
    assert res.items[0]["total_gross_weight_kg"] == 3.01  # 3 x 1.005 = 3.0149999...
    assert res.items[1]["length_cm"] == 33.3
    assert res.items[1]["total_cbm"] == 0.0574
    assert res.items[1]["volumetric_weight_kg"] == 9.59
    assert res.total_cbm == 0.1682
    assert res.total_volumetric_weight_kg == 28.09
    assert res.total_gross_weight_kg == 5.35
    assert res.air_chargeable_weight_kg == 28.09


# ---------------------------------------------------------------------------------------------------------
# 10. Shipping scenarios: average days uses round() (banker's rounding) for the warehouse date
# ---------------------------------------------------------------------------------------------------------

CRD = date(2026, 1, 1)


def _scenario(provider: str, vessel: str, eta_offset: int, **overrides) -> ShippingScenarioItemCreate:
    data = dict(
        provider_name=provider,
        vessel_name=vessel,
        sailing_date=CRD,
        estimated_arrival_date=CRD + timedelta(days=eta_offset),
        expected_line_delay_days=0,
    )
    data.update(overrides)
    return ShippingScenarioItemCreate(**data)


@pytest.mark.parametrize(
    "offsets, avg_days, avg_wh_offset",
    [
        ((20, 21), 20.5, 20),  # round(20.5) == 20 (banker's rounding, half to even)
        ((21, 22), 21.5, 22),  # round(21.5) == 22
        ((20, 21, 21), 20.7, 21),  # 20.666... -> 20.7 displayed, round() -> 21
    ],
)
def test_scenario_average_days_bankers_rounding(db_session, offsets, avg_days, avg_wh_offset):
    items = [_scenario(f"Line {i}", f"Vessel {i}", off) for i, off in enumerate(offsets)]
    res = ShippingScenarioService.create_session_service(
        db_session,
        ShippingEvaluationCreate(title="avg", cargo_ready_date=CRD, avg_form4_days=0, avg_clearance_days=0, items=items),
    )
    assert res.avg_expected_transit_days == avg_days
    assert res.avg_expected_warehouse_arrival_date == CRD + timedelta(days=avg_wh_offset)


def test_scenario_day_arithmetic_earliest_latest_and_exclusion(db_session):
    items = [
        # lead 20 + ready 2 + form4 5 + clearance 7 + delay 3 = 37
        _scenario("COSCO Shipping", "COSCO A", 22, sailing_date=CRD + timedelta(days=2), expected_line_delay_days=3),
        # lead 25 + ready 0 + 12 + 0 = 37: ties with COSCO -> earliest/latest keep the first one
        _scenario("Maersk Line", "MAERSK B", 25),
        # excluded: 10 + 12 = 22 would be the earliest, but it is ignored for average / earliest / latest
        _scenario("MSC", "MSC C", 10, is_excluded_from_average=True),
        # 40 + 12 = 52: latest
        _scenario("CMA CGM", "CMA D", 40),
    ]
    res = ShippingScenarioService.create_session_service(
        db_session,
        ShippingEvaluationCreate(title="days", cargo_ready_date=CRD, avg_form4_days=5, avg_clearance_days=7, items=items),
    )
    totals = [i.expected_total_days_to_warehouse for i in res.items]
    assert totals == [37, 37, 22, 52]
    assert [i.vessel_lead_time_days for i in res.items] == [20, 25, 10, 40]
    assert [i.ready_for_shipping_days for i in res.items] == [2, 0, 0, 0]
    assert res.items[0].expected_warehouse_arrival_date == CRD + timedelta(days=37)
    # (37 + 37 + 52) / 3 = 42.0
    assert res.avg_expected_transit_days == 42.0
    assert res.avg_expected_warehouse_arrival_date == CRD + timedelta(days=42)
    assert res.earliest_arrival_scenario_provider == "COSCO Shipping"
    assert res.earliest_arrival_date == CRD + timedelta(days=37)
    assert res.latest_arrival_scenario_provider == "CMA CGM"
    assert res.latest_arrival_date == CRD + timedelta(days=52)
    # No is_recommended flag: the earliest scenario is recommended as "provider (vessel)".
    assert res.recommended_scenario_provider == "COSCO Shipping (COSCO A)"


def test_scenario_explicit_recommendation_wins(db_session):
    items = [
        _scenario("COSCO Shipping", "COSCO A", 20),
        _scenario("Maersk Line", "MAERSK B", 30, is_recommended=True),
    ]
    res = ShippingScenarioService.create_session_service(
        db_session,
        ShippingEvaluationCreate(title="rec", cargo_ready_date=CRD, avg_form4_days=0, avg_clearance_days=0, items=items),
    )
    assert res.recommended_scenario_provider == "Maersk Line (MAERSK B)"
    assert res.earliest_arrival_scenario_provider == "COSCO Shipping"


# ---------------------------------------------------------------------------------------------------------
# 11. Clone keeps exchange_rate, payment_terms and items; totals are recomputed from the copied rows
# ---------------------------------------------------------------------------------------------------------

def test_clone_keeps_commercial_terms_and_recomputes_totals(db_session):
    """EXPECTED_TO_CHANGE (c): status label "Draft" only."""
    service = PurchaseOrderService(db_session)
    po = _create_po(
        db_session,
        po_reference="Solar batch",
        exchange_rate=48.5,
        payment_terms="TT 30 days",
        items=[
            _line(item_code="A", quantity=10.0, unit_price=12.345, cbm_per_unit=0.12345, gross_weight_kg=100.0, net_weight_kg=90.0),
            _line(item_code="B", quantity=3.0, unit_price=1.1, cbm_per_unit=0.5, gross_weight_kg=30.0, net_weight_kg=25.0),
        ],
    )
    # Line totals: round(10 x 12.345, 2) = 123.45 ; round(3 x 1.1, 2) = 3.3 ; CBM round(1.2345, 4) + 1.5
    assert po.total_amount_fob == 126.75
    assert po.total_cbm == 2.7345
    assert po.total_packages_count == 13

    # Simulate an outside overwrite of the stored totals (e.g. CBM link): the clone must recompute.
    stored = _stored(db_session, po.po_id)
    stored.total_cbm = Decimal("999.0000")
    stored.total_amount_fob = Decimal("1.00")
    db_session.commit()

    clone = service.clone_purchase_order(po.po_id, ClonePurchaseOrderRequest(new_po_number="po-clone-001"))

    assert clone.po_id != po.po_id
    assert clone.po_number == "PO-CLONE-001"
    assert clone.po_reference == "Solar batch-COPY"
    assert clone.exchange_rate == 48.5
    assert clone.payment_terms == "TT 30 days"
    assert clone.status == "DRAFT"
    assert clone.import_file_id is None
    assert clone.notes == f"Cloned from: {po.po_number}"
    # The clone recomputes from the STORED per-unit values: cbm_per_unit is Numeric(10, 4), so the 0.12345
    # sent on create reads back as 0.1235 and the cloned line CBM is 10 x 0.1235 = 1.235 (original: 1.2345).
    assert [(i.item_code, i.quantity, i.unit_price, i.cbm_per_unit, i.total_price, i.total_cbm) for i in clone.items] == [
        ("A", 10.0, 12.345, 0.1235, 123.45, 1.235),
        ("B", 3.0, 1.1, 0.5, 3.3, 1.5),
    ]
    assert {i.item_id for i in clone.items}.isdisjoint({i.item_id for i in po.items})
    assert clone.total_amount_fob == 126.75
    assert clone.total_cbm == 2.735  # not 999 (recomputed) and not 2.7345 (see the 4-decimal note above)
    assert clone.total_gross_weight_kg == 130.0
    assert clone.total_net_weight_kg == 115.0
    assert clone.total_packages_count == 13
