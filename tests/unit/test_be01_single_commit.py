"""
Unit tests for BE01-T08:
One commit per use case (customs_consultation, import_requirements).

Verifies that:
1. Clearance expense type create, update, delete call commit exactly once.
2. Broker price list create, update, soft_delete call commit exactly once.
3. Import requirement assessment create, update, restore, soft_delete call commit exactly once
   for the core entity before the side-effect phase.
4. A forced exception in the side-effect phase does not roll back or undo the saved assessment.
"""
from datetime import date, datetime, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.auth.seed_rbac import seed_rbac
from modules.currencies.model import Currency
from modules.currencies.service import clear_currency_cache
from modules.customs_consultation.model import ClearanceExpenseType, BrokerPriceList
from modules.customs_consultation.schemas import (
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeUpdate,
    BrokerPriceListCreate,
    BrokerPriceListItemCreate,
    BrokerPriceListUpdate,
)
from modules.customs_consultation.service import (
    ClearanceExpenseTypeService,
    BrokerPriceListService,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.import_requirements.model import ImportRequirementAssessment
from modules.import_requirements.schemas import (
    ImportRequirementCreate,
    ImportRequirementUpdate,
)
from modules.import_requirements.service import (
    create_assessment_service,
    update_assessment_service,
    restore_assessment_service,
    soft_delete_assessment_service,
    sync_regulatory_tasks_and_alerts,
)
import modules.import_requirements.service as ir_service


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    clear_currency_cache()
    yield sessionmaker(bind=engine, autoflush=False)
    clear_currency_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)

    # Base currencies
    egp = Currency(currency_id=1, currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_active=True)
    usd = Currency(currency_id=2, currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    session.add_all([egp, usd])
    session.commit()

    # External broker
    broker = ExternalServiceProvider(
        provider_id=1,
        partner_code="BRK-001",
        partner_name="Speedy Customs Broker",
        partner_type="Customs Broker",
        is_active=True,
    )
    session.add(broker)
    session.commit()

    # Import file
    f = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        company_name="Test Company",
        supplier_name="Test Supplier",
        status="Active",
        is_active=True,
    )
    session.add(f)
    session.commit()

    yield session


# ==============================================================================
# Clearance Expense Type Tests
# ==============================================================================

def test_expense_type_create_single_commit(db, monkeypatch):
    commit_count = 0
    orig_commit = db.commit

    def counted_commit():
        nonlocal commit_count
        commit_count += 1
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    schema = ClearanceExpenseTypeCreate(
        name_ar="رسوم تفريغ",
        name_en="Unloading Fee",
        category="Terminal",
        default_unit="Shipment",
        default_currency="EGP",
    )
    res = ClearanceExpenseTypeService.create_expense_type(db, schema)

    assert commit_count == 1
    assert res.expense_id is not None
    in_db = db.query(ClearanceExpenseType).filter(ClearanceExpenseType.expense_id == res.expense_id).first()
    assert in_db is not None
    assert in_db.name_en == "Unloading Fee"


def test_expense_type_update_single_commit(db, monkeypatch):
    schema = ClearanceExpenseTypeCreate(
        name_ar="رسوم فحص",
        name_en="Inspection Fee",
        category="Inspection",
        default_unit="Shipment",
        default_currency="EGP",
    )
    created = ClearanceExpenseTypeService.create_expense_type(db, schema)

    commit_count = 0
    orig_commit = db.commit

    def counted_commit():
        nonlocal commit_count
        commit_count += 1
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    update_schema = ClearanceExpenseTypeUpdate(name_en="Updated Inspection Fee")
    res = ClearanceExpenseTypeService.update_expense_type(db, created.expense_id, update_schema)

    assert commit_count == 1
    assert res.name_en == "Updated Inspection Fee"
    in_db = db.query(ClearanceExpenseType).filter(ClearanceExpenseType.expense_id == created.expense_id).first()
    assert in_db.name_en == "Updated Inspection Fee"


def test_expense_type_delete_single_commit(db, monkeypatch):
    schema = ClearanceExpenseTypeCreate(
        name_ar="رسوم وزن",
        name_en="Weighing Fee",
        category="Terminal",
        default_unit="Shipment",
        default_currency="EGP",
    )
    created = ClearanceExpenseTypeService.create_expense_type(db, schema)

    commit_count = 0
    orig_commit = db.commit

    def counted_commit():
        nonlocal commit_count
        commit_count += 1
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    res = ClearanceExpenseTypeService.delete_expense_type(db, created.expense_id)

    assert commit_count == 1
    assert res.is_active is False
    in_db = db.query(ClearanceExpenseType).filter(ClearanceExpenseType.expense_id == created.expense_id).first()
    assert in_db.is_active is False


# ==============================================================================
# Broker Price List Tests
# ==============================================================================

def test_price_list_create_single_commit(db, monkeypatch):
    commit_count = 0
    orig_commit = db.commit

    def counted_commit():
        nonlocal commit_count
        commit_count += 1
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    schema = BrokerPriceListCreate(
        title="Speedy Alexandria 2026",
        broker_id=1,
        broker_name="Speedy Customs Broker",
        port_name="Alexandria Port",
        effective_from=date(2026, 1, 1),
        effective_to=date(2026, 12, 31),
        items=[
            BrokerPriceListItemCreate(
                expense_name="Storage",
                category="Terminal",
                unit_type="Container",
                standard_price=500.0,
                currency="EGP",
            )
        ],
    )
    res = BrokerPriceListService.create_price_list(db, schema)

    assert commit_count == 1
    assert res.price_list_id is not None
    in_db = db.query(BrokerPriceList).filter(BrokerPriceList.price_list_id == res.price_list_id).first()
    assert in_db is not None
    assert len(in_db.items) == 1


def test_price_list_update_single_commit(db, monkeypatch):
    schema = BrokerPriceListCreate(
        title="Speedy Dekheila 2026",
        broker_id=1,
        broker_name="Speedy Customs Broker",
        effective_from=date(2026, 1, 1),
        effective_to=date(2026, 12, 31),
    )
    created = BrokerPriceListService.create_price_list(db, schema)

    commit_count = 0
    orig_commit = db.commit

    def counted_commit():
        nonlocal commit_count
        commit_count += 1
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    update_schema = BrokerPriceListUpdate(title="Speedy Dekheila 2026 Revised")
    res = BrokerPriceListService.update_price_list(db, created.price_list_id, update_schema)

    assert commit_count == 1
    assert res.title == "Speedy Dekheila 2026 Revised"
    in_db = db.query(BrokerPriceList).filter(BrokerPriceList.price_list_id == created.price_list_id).first()
    assert in_db.title == "Speedy Dekheila 2026 Revised"


def test_price_list_soft_delete_single_commit(db, monkeypatch):
    schema = BrokerPriceListCreate(
        title="Speedy Sokhna 2026",
        broker_id=1,
        broker_name="Speedy Customs Broker",
        effective_from=date(2026, 1, 1),
        effective_to=date(2026, 12, 31),
    )
    created = BrokerPriceListService.create_price_list(db, schema)

    commit_count = 0
    orig_commit = db.commit

    def counted_commit():
        nonlocal commit_count
        commit_count += 1
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    res = BrokerPriceListService.soft_delete_price_list(db, created.price_list_id)

    assert commit_count == 1
    assert res.is_active is False
    in_db = db.query(BrokerPriceList).filter(BrokerPriceList.price_list_id == created.price_list_id).first()
    assert in_db.is_active is False


# ==============================================================================
# Import Requirements Assessment Tests
# ==============================================================================

def test_assessment_create_single_commit_before_side_effects(db, monkeypatch):
    commit_timestamps = []
    side_effects_started = False
    orig_commit = db.commit

    def counted_commit():
        commit_timestamps.append(side_effects_started)
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    orig_sync = ir_service._sync_tasks_safely

    def spy_sync(s, assessment_id):
        nonlocal side_effects_started
        side_effects_started = True
        return orig_sync(s, assessment_id)

    monkeypatch.setattr(ir_service, "_sync_tasks_safely", spy_sync)

    payload = ImportRequirementCreate(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        hs_code="8415820010",
        commodity_description="Air conditioners",
        country_of_origin="China",
        overall_status="Draft",
        risk_level="Medium",
    )
    created = create_assessment_service(db, payload, user="alice")

    # Exactly one commit before side effects started
    before_side_effects = [s for s in commit_timestamps if not s]
    assert len(before_side_effects) == 1

    # Assessment is stored in DB
    in_db = db.query(ImportRequirementAssessment).filter(
        ImportRequirementAssessment.assessment_id == created.assessment_id
    ).first()
    assert in_db is not None
    assert in_db.hs_code == "8415820010"
    assert in_db.created_by == "alice"


def test_assessment_update_single_commit_before_side_effects(db, monkeypatch):
    payload = ImportRequirementCreate(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        hs_code="8415820010",
        commodity_description="Air conditioners",
        country_of_origin="China",
        overall_status="Draft",
        risk_level="Medium",
    )
    created = create_assessment_service(db, payload, user="alice")

    commit_timestamps = []
    side_effects_started = False
    orig_commit = db.commit

    def counted_commit():
        commit_timestamps.append(side_effects_started)
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    orig_sync = ir_service._sync_tasks_safely

    def spy_sync(s, assessment_id):
        nonlocal side_effects_started
        side_effects_started = True
        return orig_sync(s, assessment_id)

    monkeypatch.setattr(ir_service, "_sync_tasks_safely", spy_sync)

    update_payload = ImportRequirementUpdate(
        commodity_description="Industrial Air Conditioners",
        overall_status="Complete",
    )
    updated = update_assessment_service(db, created.assessment_id, update_payload, user="bob")

    before_side_effects = [s for s in commit_timestamps if not s]
    assert len(before_side_effects) == 1
    assert updated.commodity_description == "Industrial Air Conditioners"


def test_assessment_soft_delete_single_commit(db, monkeypatch):
    payload = ImportRequirementCreate(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        hs_code="8415820010",
        commodity_description="Air conditioners",
        country_of_origin="China",
        overall_status="Draft",
        risk_level="Medium",
    )
    created = create_assessment_service(db, payload, user="alice")

    commit_count = 0
    orig_commit = db.commit

    def counted_commit():
        nonlocal commit_count
        commit_count += 1
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    soft_delete_assessment_service(db, created.assessment_id, user="charlie")

    assert commit_count == 1
    in_db = db.query(ImportRequirementAssessment).filter(
        ImportRequirementAssessment.assessment_id == created.assessment_id
    ).first()
    assert in_db.is_active is False
    assert in_db.updated_by == "charlie"


def test_assessment_restore_single_commit(db, monkeypatch):
    payload = ImportRequirementCreate(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        hs_code="8415820010",
        commodity_description="Air conditioners",
        country_of_origin="China",
        overall_status="Draft",
        risk_level="Medium",
    )
    created = create_assessment_service(db, payload, user="alice")
    soft_delete_assessment_service(db, created.assessment_id, user="alice")

    commit_timestamps = []
    side_effects_started = False
    orig_commit = db.commit

    def counted_commit():
        commit_timestamps.append(side_effects_started)
        return orig_commit()

    monkeypatch.setattr(db, "commit", counted_commit)

    orig_sync = ir_service._sync_tasks_safely

    def spy_sync(s, assessment_id):
        nonlocal side_effects_started
        side_effects_started = True
        return orig_sync(s, assessment_id)

    monkeypatch.setattr(ir_service, "_sync_tasks_safely", spy_sync)

    restored = restore_assessment_service(db, created.assessment_id, user="dave")

    before_side_effects = [s for s in commit_timestamps if not s]
    assert len(before_side_effects) == 1
    assert restored.is_active is True
    assert restored.updated_by == "dave"


def test_assessment_side_effect_failure_leaves_core_row_saved(db, monkeypatch):
    """
    Verifies transaction isolation: a forced exception in the regulatory task/alert
    sync side effect does NOT undo or roll back the saved core assessment.
    """
    def failing_sync(session, assessment_id):
        raise RuntimeError("Simulated failure in regulatory task synchronization!")

    monkeypatch.setattr(ir_service, "sync_regulatory_tasks_and_alerts", failing_sync)

    payload = ImportRequirementCreate(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        hs_code="8415820010",
        commodity_description="Air conditioners",
        country_of_origin="China",
        overall_status="Draft",
        risk_level="Medium",
    )

    # Should not raise; best_effort catches the side effect exception and logs it
    created = create_assessment_service(db, payload, user="alice")

    assert created is not None
    assert created.assessment_id is not None

    # Query DB in a fresh query: the assessment is committed and safe
    in_db = db.query(ImportRequirementAssessment).filter(
        ImportRequirementAssessment.assessment_id == created.assessment_id
    ).first()

    assert in_db is not None
    assert in_db.assessment_code == created.assessment_code
    assert in_db.hs_code == "8415820010"
    assert in_db.created_by == "alice"
