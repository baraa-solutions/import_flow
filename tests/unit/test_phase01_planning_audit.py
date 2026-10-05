"""
Phase-1 planning round 2 (package B):
- CBM shipment_mode is persisted as a SHIPMENT_MODE code (AIR / SEA); legacy NULL reads back as unknown.
- POST /cbm-calculator/{id}/link honours import_file_id (must be an active file).
- created_by / updated_by on CBM calculations, shipping-scenario sessions and consultation sessions.
- Alembic f6a7b8c9d0e1 adds the columns defensively (additive, idempotent).
"""

import importlib.util
from datetime import date, timedelta

import pytest
import sqlalchemy as sa
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  registers every SQLAlchemy model
from database.database import Base
from modules.cbm_calculator.model import CBMCalculation
from modules.cbm_calculator.schemas import (
    CBMCalculationCreate,
    CBMCalculationUpdate,
    CBMItemCreate,
    CloneCBMCalculationRequest,
)
from modules.cbm_calculator.service import CBMService
from modules.customs_consultation.schemas import CustomsConsultationCreate, CustomsConsultationUpdate
from modules.customs_consultation.service import CustomsConsultationService
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.shipping_scenarios.schemas import (
    CloneShippingEvaluationRequest,
    ShippingEvaluationCreate,
    ShippingEvaluationUpdate,
    ShippingScenarioItemCreate,
)
from modules.shipping_scenarios.service import ShippingScenarioService


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine, autoflush=False)()
    yield session
    session.close()
    engine.dispose()


def _item(**kw):
    data = dict(quantity=2, length=100.0, width=100.0, height=100.0, unit="cm", gross_weight_per_unit_kg=5.0)
    data.update(kw)
    return CBMItemCreate(**data)


def _file(db, code="IMP-AUD-1", active=True):
    f = ImportFile(import_file_code=code, company_name="C", supplier_name="S", status="Draft", is_active=active)
    db.add(f)
    db.commit()
    return f


# ── CBM shipment_mode ───────────────────────────────────────────────────────────

def test_cbm_shipment_mode_is_stored_as_code(db):
    calc = CBMService.create_calculation_service(db, CBMCalculationCreate(title="sea", shipment_mode="sea", items=[_item()]))
    assert calc.shipment_mode == "SEA"
    assert db.get(CBMCalculation, calc.calc_id).shipment_mode == "SEA"
    again = CBMService.get_calculation_service(db, calc.calc_id)
    assert again.shipment_mode == "SEA"

    updated = CBMService.update_calculation_service(db, calc.calc_id, CBMCalculationUpdate(shipment_mode="AIR"))
    assert updated.shipment_mode == "AIR"


def test_cbm_shipment_mode_not_given_stays_unknown(db):
    calc = CBMService.create_calculation_service(db, CBMCalculationCreate(title="none", items=[_item()]))
    assert calc.shipment_mode is None  # never guessed


def test_cbm_unknown_shipment_mode_is_rejected():
    with pytest.raises(ValidationError):
        CBMCalculationCreate(title="x", shipment_mode="rail", items=[_item()])


def test_cbm_legacy_row_without_mode_reads_none(db):
    calc = CBMService.create_calculation_service(db, CBMCalculationCreate(title="legacy", shipment_mode="SEA", items=[_item()]))
    db.get(CBMCalculation, calc.calc_id).shipment_mode = None
    db.commit()
    assert CBMService.get_calculation_service(db, calc.calc_id).shipment_mode is None


# ── CBM link honours import_file_id ─────────────────────────────────────────────

def test_cbm_link_sets_import_file(db):
    f = _file(db)
    calc = CBMService.create_calculation_service(db, CBMCalculationCreate(title="link", items=[_item()]))
    linked = CBMService.link_to_po_service(db, calc.calc_id, import_file_id=f.import_file_id, user="linker")
    assert linked.import_file_id == f.import_file_id
    assert linked.import_file_code == "IMP-AUD-1"
    assert linked.updated_by == "linker"


def test_cbm_link_to_inactive_import_file_is_400(db):
    f = _file(db, code="IMP-AUD-OFF", active=False)
    calc = CBMService.create_calculation_service(db, CBMCalculationCreate(title="link", items=[_item()]))
    with pytest.raises(HTTPException) as exc:
        CBMService.link_to_po_service(db, calc.calc_id, import_file_id=f.import_file_id)
    assert exc.value.status_code == 400


# ── created_by / updated_by ─────────────────────────────────────────────────────

def test_cbm_audit_users(db):
    calc = CBMService.create_calculation_service(db, CBMCalculationCreate(title="a", items=[_item()]), user="creator")
    assert (calc.created_by, calc.updated_by) == ("creator", "creator")
    upd = CBMService.update_calculation_service(db, calc.calc_id, CBMCalculationUpdate(title="b"), user="editor")
    assert (upd.created_by, upd.updated_by) == ("creator", "editor")
    CBMService.soft_delete_service(db, calc.calc_id, user="deleter")
    assert db.get(CBMCalculation, calc.calc_id).updated_by == "deleter"
    clone = CBMService.clone_cbm_calculation(db, calc.calc_id, CloneCBMCalculationRequest(), user="cloner")
    assert (clone.created_by, clone.updated_by) == ("cloner", "cloner")


def test_shipping_scenario_audit_users(db):
    crd = date(2026, 3, 1)
    item = ShippingScenarioItemCreate(provider_name="Line A", vessel_name="Vessel A", sailing_date=crd,
                                      estimated_arrival_date=crd + timedelta(days=20))
    res = ShippingScenarioService.create_session_service(
        db, ShippingEvaluationCreate(title="audit", cargo_ready_date=crd, items=[item]), user="planner"
    )
    assert (res.created_by, res.updated_by) == ("planner", "planner")
    upd = ShippingScenarioService.update_session_service(db, res.session_id, ShippingEvaluationUpdate(title="t2"), user="editor")
    assert (upd.created_by, upd.updated_by) == ("planner", "editor")
    clone = ShippingScenarioService.clone_session_service(db, res.session_id, CloneShippingEvaluationRequest(), user="cloner")
    assert (clone.created_by, clone.updated_by) == ("cloner", "cloner")


def test_consultation_audit_users(db):
    db.add(ExternalServiceProvider(provider_id=7, partner_code="CB-7", partner_name="Broker", partner_type="Customs Broker"))
    db.commit()
    res = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="audit", broker_id=7, broker_name="Broker"), modified_by="officer"
    )
    assert (res.created_by, res.updated_by) == ("officer", "officer")
    upd = CustomsConsultationService.update_consultation(
        db, res.consultation_id, CustomsConsultationUpdate(notes="n"), modified_by="reviewer"
    )
    assert (upd.created_by, upd.updated_by) == ("officer", "reviewer")
    deleted = CustomsConsultationService.soft_delete_consultation(db, res.consultation_id, modified_by="deleter")
    assert deleted.updated_by == "deleter"


# ── Alembic f6a7b8c9d0e1 ────────────────────────────────────────────────────────

def _run_migration(conn, direction: str) -> None:
    from alembic.migration import MigrationContext
    from alembic.operations import Operations

    module = importlib.import_module("alembic.versions.f6a7b8c9d0e1_cbm_shipment_mode_and_planning_audit_by") \
        if False else _load_migration()
    ctx = MigrationContext.configure(conn)
    with Operations.context(ctx):
        getattr(module, direction)()


def _load_migration():
    from pathlib import Path

    path = Path(__file__).resolve().parents[2] / "alembic" / "versions" / "f6a7b8c9d0e1_cbm_shipment_mode_and_planning_audit_by.py"
    spec = importlib.util.spec_from_file_location("mig_f6a7b8c9d0e1", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_migration_adds_columns_idempotently_and_downgrades():
    module = _load_migration()
    assert module.revision == "f6a7b8c9d0e1"
    assert module.down_revision == "e5f6a7b8c9d0"

    engine = create_engine("sqlite:///:memory:", poolclass=StaticPool)
    with engine.begin() as conn:
        conn.execute(sa.text("CREATE TABLE cbm_calculations (calc_id INTEGER PRIMARY KEY, calc_code VARCHAR(50))"))
        conn.execute(sa.text("CREATE TABLE shipping_evaluation_sessions (session_id INTEGER PRIMARY KEY)"))
        conn.execute(sa.text("CREATE TABLE customs_consultation_sessions (consultation_id INTEGER PRIMARY KEY)"))
        conn.execute(sa.text("INSERT INTO cbm_calculations (calc_id, calc_code) VALUES (1, 'CALC-2025-001')"))

    def cols(table):
        return {c["name"] for c in sa.inspect(engine).get_columns(table)}

    with engine.begin() as conn:
        _run_migration(conn, "upgrade")
    assert {"shipment_mode", "created_by", "updated_by"} <= cols("cbm_calculations")
    assert {"created_by", "updated_by"} <= cols("shipping_evaluation_sessions")
    assert {"created_by", "updated_by"} <= cols("customs_consultation_sessions")
    with engine.connect() as conn:
        row = conn.execute(sa.text("SELECT shipment_mode, created_by FROM cbm_calculations")).one()
    assert tuple(row) == (None, None)  # legacy rows stay NULL (unknown)

    with engine.begin() as conn:
        _run_migration(conn, "upgrade")  # second run is a no-op
    with engine.begin() as conn:
        _run_migration(conn, "downgrade")
    assert "shipment_mode" not in cols("cbm_calculations")
    assert "created_by" not in cols("customs_consultation_sessions")


# ── Shipping scenarios: one active study per import file (coded 409) ─────────────

def test_second_scenario_session_for_same_file_is_coded_409(db):
    f = _file(db, code="IMP-SCE-1")
    crd = date(2026, 3, 1)
    first = ShippingScenarioService.create_session_service(
        db, ShippingEvaluationCreate(title="one", cargo_ready_date=crd, import_file_id=f.import_file_id)
    )
    with pytest.raises(HTTPException) as exc:
        ShippingScenarioService.create_session_service(
            db, ShippingEvaluationCreate(title="two", cargo_ready_date=crd, import_file_id=f.import_file_id)
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "SCENARIO_SESSION_EXISTS"
    assert exc.value.detail["session_code"] == first.session_code


# ── Review round: editable with since-deactivated references, one-per-file on reactivation ─────────

def _provider(db, pid, active=True):
    db.add(ExternalServiceProvider(provider_id=pid, partner_code=f"FF-{pid}", partner_name=f"P{pid}",
                                   partner_type="Freight Forwarder", is_active=active))
    db.commit()


def test_scenario_update_with_since_deactivated_provider_is_allowed(db):
    _provider(db, 41)
    crd = date(2026, 4, 1)
    item = dict(provider_id=41, provider_name="Line A", vessel_name="Vessel A", sailing_date=crd,
                estimated_arrival_date=crd + timedelta(days=20))
    res = ShippingScenarioService.create_session_service(
        db, ShippingEvaluationCreate(title="t", cargo_ready_date=crd, items=[ShippingScenarioItemCreate(**item)])
    )
    db.get(ExternalServiceProvider, 41).is_active = False
    db.commit()
    # Flutter resends the full payload; only the title changed.
    upd = ShippingScenarioService.update_session_service(
        db, res.session_id,
        ShippingEvaluationUpdate(title="renamed", cargo_ready_date=crd, items=[ShippingScenarioItemCreate(**item)]),
    )
    assert upd.title == "renamed"
    # A NEW reference to an inactive provider is still refused.
    _provider(db, 42, active=False)
    with pytest.raises(HTTPException) as exc:
        ShippingScenarioService.update_session_service(
            db, res.session_id,
            ShippingEvaluationUpdate(items=[ShippingScenarioItemCreate(**{**item, "provider_id": 42})]),
        )
    assert exc.value.status_code == 400


def test_cbm_update_with_since_deactivated_import_file_is_allowed(db):
    f = _file(db, code="IMP-CBM-OFF")
    calc = CBMService.create_calculation_service(
        db, CBMCalculationCreate(title="t", import_file_id=f.import_file_id, items=[_item()])
    )
    f.is_active = False
    db.commit()
    upd = CBMService.update_calculation_service(
        db, calc.calc_id, CBMCalculationUpdate(title="renamed", import_file_id=f.import_file_id)
    )
    assert upd.title == "renamed"


def test_scenario_restore_runs_one_per_file_check(db):
    f = _file(db, code="IMP-SCE-RST")
    crd = date(2026, 3, 1)
    first = ShippingScenarioService.create_session_service(
        db, ShippingEvaluationCreate(title="one", cargo_ready_date=crd, import_file_id=f.import_file_id)
    )
    ShippingScenarioService.soft_delete_service(db, first.session_id)
    ShippingScenarioService.create_session_service(
        db, ShippingEvaluationCreate(title="two", cargo_ready_date=crd, import_file_id=f.import_file_id)
    )
    for action in (
        lambda: ShippingScenarioService.restore_service(db, first.session_id),
        lambda: ShippingScenarioService.update_session_service(db, first.session_id, ShippingEvaluationUpdate(title="x")),
    ):
        with pytest.raises(HTTPException) as exc:
            action()
        assert exc.value.status_code == 409


def test_consultation_duplicate_and_restore_are_coded_409(db):
    db.add(ExternalServiceProvider(provider_id=8, partner_code="CB-8", partner_name="Broker", partner_type="Customs Broker"))
    db.commit()
    f = _file(db, code="IMP-CC-DUP")
    first = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="one", broker_id=8, broker_name="B", import_file_id=f.import_file_id)
    )
    with pytest.raises(HTTPException) as exc:
        CustomsConsultationService.create_consultation(
            db, CustomsConsultationCreate(title="two", broker_id=8, broker_name="B", import_file_id=f.import_file_id)
        )
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "CONSULTATION_EXISTS"
    assert exc.value.detail["consultation_code"] == first.consultation_code

    CustomsConsultationService.soft_delete_consultation(db, first.consultation_id)
    CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="three", broker_id=8, broker_name="B", import_file_id=f.import_file_id)
    )
    with pytest.raises(HTTPException) as exc:
        CustomsConsultationService.restore_consultation(db, first.consultation_id)
    assert exc.value.status_code == 409


def test_prefill_currency_is_optional():
    from modules.import_requirements.schemas import ImportRequirementHSCodeItem, ImportRequirementPrefillResponse

    assert ImportRequirementPrefillResponse(import_file_id=1, import_file_code="X").currency is None
    assert ImportRequirementHSCodeItem(hs_code="1234").currency is None


def test_saved_inactive_reference_cannot_be_reused_or_moved(db):
    _provider(db, 51)
    crd = date(2026, 5, 1)
    base = dict(provider_name="Line A", vessel_name="Vessel A", sailing_date=crd,
                estimated_arrival_date=crd + timedelta(days=20))
    res = ShippingScenarioService.create_session_service(
        db, ShippingEvaluationCreate(title="t", cargo_ready_date=crd,
                                     items=[ShippingScenarioItemCreate(provider_id=51, **base)])
    )
    db.get(ExternalServiceProvider, 51).is_active = False
    db.commit()
    kept = ShippingScenarioItemCreate(provider_id=51, **base)
    # extra option reusing the inactive provider
    extra = ShippingScenarioItemCreate(provider_id=51, **{**base, "vessel_name": "Vessel B"})
    # the inactive provider moved to the customs-broker field
    moved = ShippingScenarioItemCreate(customs_broker_id=51, **{**base, "vessel_name": "Vessel C"})
    for items in ([kept, extra], [moved]):
        with pytest.raises(HTTPException) as exc:
            ShippingScenarioService.update_session_service(db, res.session_id, ShippingEvaluationUpdate(items=items))
        assert exc.value.status_code == 400
    ok = ShippingScenarioService.update_session_service(db, res.session_id, ShippingEvaluationUpdate(items=[kept]))
    assert ok.items[0].provider_id == 51
