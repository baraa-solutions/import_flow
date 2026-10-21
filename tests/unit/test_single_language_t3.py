"""
Tier-3 normalization and clone defaults in services (single-language storage, Phase A).
"""
from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import main  # noqa: F401
from database.database import Base
from modules.customs_clearance_quotations import service as quote_service
from modules.customs_clearance_quotations.schemas import ClearancePriceListItemCreate, ClearancePriceListItemUpdate
from modules.customs_clearance_quotations.model import ClearanceServicePriceListItem
from modules.customs_consultation.model import BrokerPriceList, CustomsConsultationSession
from modules.customs_consultation.schemas import (
    BrokerPriceListCreate,
    BrokerPriceListItemCreate,
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeUpdate,
    CloneBrokerPriceListRequest,
    CloneConsultationRequest,
)
from modules.customs_consultation.service import (
    BrokerPriceListService,
    ClearanceExpenseTypeService,
    CustomsConsultationService,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.inland_transport.model import InlandTransportBooking
from modules.lifecycle_board import service as lifecycle_service
from modules.lifecycle_board.schemas import StepConfigUpdateRequest
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.purchase_orders.model import PurchaseOrder
from modules.import_documentation.model import InspectionCertificateReviewSession
from modules.currencies.model import Currency
from modules.customs_consultation.model import ClearanceExpenseType


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    session.add(Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="E£", is_active=True))
    session.add(ExternalServiceProvider(provider_id=1, partner_code="PRT-BRK-001", partner_name="Nasr Customs",
                                        partner_type="Customs Broker", is_active=True))
    session.commit()
    yield session
    session.close()
    engine.dispose()


# ─── Clearance quotation price list: service_category + currency ───────────────

def test_price_item_category_and_currency_become_codes(db):
    item = quote_service.create_price_item_service(db, ClearancePriceListItemCreate(
        provider_id=1, provider_name="Nasr Customs", port_name="Alexandria",
        service_category="مصاريف الفحص والعرض", unit_price=1500.0, currency="جنيه",
    ))
    assert item.service_category == "INSPECTION_FEE"
    assert item.currency == "EGP"
    updated = quote_service.update_price_item_service(db, item.price_item_id, ClearancePriceListItemUpdate(
        service_category="Port & Demurrage Charges", currency="usd"))
    assert updated.service_category == "PORT_CHARGES" and updated.currency == "USD"
    default = quote_service.create_price_item_service(db, ClearancePriceListItemCreate(
        provider_id=1, provider_name="Nasr Customs", port_name="Alexandria", unit_price=10.0))
    assert default.service_category == "CLEARANCE_FEE"


def test_price_list_filter_by_code_also_matches_legacy_rows(db):
    db.add(ClearanceServicePriceListItem(provider_id=1, provider_name="Nasr", port_name="Alex",
                                         service_category="أتعاب التخليص الجمركي", container_type="40HQ",
                                         unit_price=100.0, currency="EGP"))
    db.commit()
    quote_service.create_price_item_service(db, ClearancePriceListItemCreate(
        provider_id=1, provider_name="Nasr", port_name="Alex", service_category="CLEARANCE_FEE", unit_price=200.0))
    by_code = quote_service.get_price_list_service(db, service_category="CLEARANCE_FEE")
    assert sorted(i.unit_price for i in by_code) == [100.0, 200.0]
    by_label = quote_service.get_price_list_service(db, service_category="Clearance Agency Fee")
    assert len(by_label) == 2
    assert quote_service.get_price_list_service(db, service_category="Unknown Cat") == []


# ─── Broker price lists: category / unit + clone ───────────────────────────────

def test_expense_type_category_and_unit_become_codes(db):
    created = ClearanceExpenseTypeService.create_expense_type(db, ClearanceExpenseTypeCreate(
        expense_code="EXP-T-001", name_ar="أتعاب", name_en="Fee",
        category="Clearance Fees (أتعاب ومصاريف تخليص)", default_unit="Per Ton (لكل طن إضافي)",
    ))
    assert created.category == "CLEARANCE_FEES" and created.default_unit == "PER_EXTRA_TON"
    updated = ClearanceExpenseTypeService.update_expense_type(
        db, created.expense_id, ClearanceExpenseTypeUpdate(category="Port & Handling", default_unit="Custom unit"))
    assert updated.category == "PORT_HANDLING" and updated.default_unit == "Custom unit"
    listed = ClearanceExpenseTypeService.list_expense_types(db, category="Port & Handling")
    assert [e.expense_code for e in listed] == ["EXP-T-001"]


def test_price_list_items_normalized_and_clone_uses_copy_code_and_english_notes(db):
    pl = BrokerPriceListService.create_price_list(db, BrokerPriceListCreate(
        title="Alex 2026", broker_id=1, broker_name="Nasr Customs", effective_from=date(2026, 1, 1),
        items=[BrokerPriceListItemCreate(expense_name="Fee 20ft", category="Clearance Fees (أتعاب ومصاريف تخليص)",
                                         unit_type="Per Invoice (لكل فاتورة)", standard_price=2500.0, currency="EGP"),
               BrokerPriceListItemCreate(expense_name="Odd", category="Special Cat", unit_type="SET")],
    ))
    assert [(i.category, i.unit_type) for i in pl.items] == [("CLEARANCE_FEES", "PER_INVOICE"), ("Special Cat", "SET")]

    first = BrokerPriceListService.clone_price_list(db, pl.price_list_id, CloneBrokerPriceListRequest(new_title="Alex 2027"))
    second = BrokerPriceListService.clone_price_list(db, pl.price_list_id, CloneBrokerPriceListRequest(new_title="Alex 2028"))
    assert first.price_list_code == f"{pl.price_list_code}-COPY"
    assert second.price_list_code == f"{pl.price_list_code}-COPY2"
    assert first.notes == f"Cloned from: {pl.price_list_code}"


def test_consultation_clone_uses_copy_code_and_english_notes(db):
    original = CustomsConsultationSession(consultation_code="CC-2026-0001", title="Study", broker_id=1,
                                          broker_name="Nasr Customs", overall_status="Draft")
    db.add(original)
    db.commit()
    cloned = CustomsConsultationService.clone_consultation(
        db, original.consultation_id, CloneConsultationRequest(new_title="Study (Copy)"))
    assert cloned.consultation_code == "CC-2026-0001-COPY"
    assert cloned.notes == "Cloned from: CC-2026-0001"
    kept = CustomsConsultationService.clone_consultation(
        db, original.consultation_id, CloneConsultationRequest(new_title="Mine", notes="my own note"))
    assert kept.consultation_code == "CC-2026-0001-COPY2" and kept.notes == "my own note"


# ─── Lifecycle step configs: skip reason categories ────────────────────────────

def test_default_reason_categories_are_codes_and_updates_normalize(db):
    assert lifecycle_service.DEFAULT_REASON_CATEGORIES == [
        "CLIENT_AGREEMENT", "NOT_APPLICABLE_TO_MODE", "REGULATORY_EXEMPTION", "OTHER"]
    cfg = lifecycle_service.update_step_config_service(
        db, "STEP_02",
        StepConfigUpdateRequest(reason_categories=["Other / أخرى", "OTHER", "Custom reason"],
                                justification="Phase A normalization test"),
        current_user_role="ADMIN", current_username="admin",
    )
    assert cfg.reason_categories == ["OTHER", "Custom reason"]


# ─── Model defaults are codes / English ────────────────────────────────────────

@pytest.mark.parametrize(
    "column,expected",
    [
        (CustomsClearanceRecord.__table__.c.release_type, "FINAL_GREEN"),
        (CustomsClearanceRecord.__table__.c.payment_method, "SADAD_EFINANCE"),
        (InlandTransportBooking.__table__.c.truck_type, "FLATBED"),
        (ClearanceExpenseType.__table__.c.category, "CLEARANCE_FEES"),
        (ClearanceExpenseType.__table__.c.default_unit, "PER_INVOICE"),
        (ClearanceServicePriceListItem.__table__.c.service_category, "CLEARANCE_FEE"),
        (PurchaseOrder.__table__.c.payment_terms, "LC at Sight"),
        (InspectionCertificateReviewSession.__table__.c.regulatory_authority, "GOEIC"),
    ],
)
def test_model_defaults_are_language_independent(column, expected):
    assert column.default.arg == expected

# ─── Review fixes: landed-cost / Odoo buckets, consultation filter, PO reference ─

from modules.financial_settlement.service import actual_expense_bucket  # noqa: E402
from modules.financial_settlement.odoo_export_service import classify_odoo_cost_category  # noqa: E402
from modules.common import enum_codes as ec  # noqa: E402
from modules.purchase_orders.service import _copy_reference  # noqa: E402

EXPENSE_LEGACY = list(ec.legacy_labels()[ec.CLEARANCE_EXPENSE_CATEGORY].items())


@pytest.mark.parametrize("legacy,code", EXPENSE_LEGACY)
def test_coded_clearance_rows_land_in_the_same_buckets_as_legacy_rows(legacy, code):
    english = ec.label_en(ec.CLEARANCE_EXPENSE_CATEGORY, code)
    # Landed cost: the non-broker path is the unchanged HEAD keyword logic applied to the legacy text.
    head = actual_expense_bucket(legacy)
    for value in (legacy, code, english):
        assert actual_expense_bucket(value, "BROKER") == head, value
    # Odoo: settlement snapshot rows are "Clearance / <category>"; other rows may hold the bare category.
    assert classify_odoo_cost_category(f"Clearance / {english}") == classify_odoo_cost_category(f"Clearance / {legacy}")
    assert classify_odoo_cost_category(code) == classify_odoo_cost_category(legacy)


def test_landed_cost_totals_unchanged_for_a_mixed_fixture():
    amounts = [1000.0 * (i + 1) for i in range(len(EXPENSE_LEGACY))]
    legacy_totals, coded_totals = {}, {}
    for (legacy, code), amount in zip(EXPENSE_LEGACY, amounts):
        head = actual_expense_bucket(legacy)
        legacy_totals[head] = legacy_totals.get(head, 0.0) + amount
        bucket = actual_expense_bucket(code, "BROKER")
        coded_totals[bucket] = coded_totals.get(bucket, 0.0) + amount
    assert coded_totals == legacy_totals
    # ACC2-T02: Code-first classification (PORT_DUES_WHARFAGE and STEVEDORING_HANDLING map to Clearance & Port, not Freight)
    assert actual_expense_bucket("PORT_DUES_WHARFAGE", "BROKER") == "Clearance & Port"
    assert actual_expense_bucket("STEVEDORING_HANDLING", "BROKER") == "Clearance & Port"
    assert actual_expense_bucket("BROKER_FEES", "BROKER") == "Clearance & Port"
    assert classify_odoo_cost_category("Clearance / Inspection & Weighing") == "Clearance"


def test_unprefixed_manual_odoo_rows_keep_their_head_bucket():
    # ACC2-T02: CLEARANCE_EXPENSE_CATEGORY codes and English labels map code-first to Clearance / Demurrage
    assert classify_odoo_cost_category("Port Dues & Wharfage") == "Clearance"
    assert classify_odoo_cost_category("Clearance / Port Dues & Wharfage") == "Clearance"
    assert classify_odoo_cost_category("PORT_DUES_WHARFAGE") == "Clearance"
    assert classify_odoo_cost_category("Storage & Demurrage") == "Demurrage"


def test_non_clearance_categories_are_untouched():
    assert actual_expense_bucket("Ocean Freight", "CARRIER") == "Freight"
    assert actual_expense_bucket("Storage & Demurrage", "DEMURRAGE") == "Demurrage & Storage"
    assert classify_odoo_cost_category("Marine insurance") == "Other"


def test_expense_type_filter_by_code_matches_legacy_rows(db):
    db.add(ClearanceExpenseType(expense_code="EXP-OLD-1", name_ar="قديم", name_en="Old",
                                category="Clearance Fees (أتعاب ومصاريف تخليص)", default_unit="Per Invoice (لكل فاتورة)"))
    db.commit()
    ClearanceExpenseTypeService.create_expense_type(db, ClearanceExpenseTypeCreate(
        expense_code="EXP-NEW-1", name_ar="جديد", name_en="New", category="CLEARANCE_FEES"))
    for flt in ("CLEARANCE_FEES", "Clearance Fees", "Clearance Fees (أتعاب ومصاريف تخليص)"):
        found = ClearanceExpenseTypeService.list_expense_types(db, category=flt)
        assert sorted(e.expense_code for e in found) == ["EXP-NEW-1", "EXP-OLD-1"], flt
    assert ClearanceExpenseTypeService.list_expense_types(db, category="Unknown") == []


def test_po_clone_reference_copy_suffix_fits_max_length():
    assert _copy_reference("Chiller Units") == "Chiller Units-COPY"
    copied = _copy_reference("R" * 200)
    assert len(copied) == 200 and copied.endswith("-COPY")
    assert _copy_reference(None) is None and _copy_reference("") is None
