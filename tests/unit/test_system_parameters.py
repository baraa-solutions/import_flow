"""Phase 1 shared persistence helpers (package A1):

- ``modules/common/system_parameters.py`` (table, float reader, air volumetric factor, default seeding)
- Alembic e5f6a7b8c9d0 (system_parameters + PO created_by / updated_by)
- ``sequence_generator.next_yearly_code``, ``validators.require_active``, ``import_files.repository.codes_by_ids``
- ``seed_rbac``: Phase-1 permission codes, role grants and the one-time grant copy for existing DBs
"""
import sqlite3
from pathlib import Path

import pytest
from alembic import command
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import database.models  # noqa: F401  (registers the model tables on Base.metadata, as alembic/env.py does)
from database import migration_runner
from database.database import Base
from modules.auth import seed_rbac as rbac
from modules.common import system_parameters as sp
from modules.common.sequence_generator import next_yearly_code
from modules.common.validators import require_active
from modules.import_files.model import ImportFile
from modules.import_files.repository import codes_by_ids
from modules.purchase_orders.model import PurchaseOrder
from modules.suppliers.model import Supplier
from modules.users.model import Permission, Role, RolePermission, User, UserPermission

HEAD = "e5f6a7b8c9d0"  # the revision under test (later revisions may build on it)
PREVIOUS = "d9e4f5a6b7c8"


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine, autoflush=False)()
    yield session
    session.close()
    engine.dispose()


# ── system_parameters ──

def test_missing_parameter_returns_default(db):
    assert sp.get_parameter(db, "NOPE") is None
    assert sp.get_float_parameter(db, "NOPE", 1.5) == 1.5
    assert sp.air_volumetric_kg_per_cbm(db) == 167.0


@pytest.mark.parametrize("stored, expected", [("150", 150.0), (" 166.667 ", 166.667), ("abc", 167.0), ("0", 167.0), ("-5", 167.0)])
def test_air_volumetric_factor_reads_the_db_value(db, stored, expected):
    db.add(sp.SystemParameter(param_key=sp.AIR_VOLUMETRIC_KG_PER_CBM, param_value=stored))
    db.commit()
    assert sp.air_volumetric_kg_per_cbm(db) == expected


def test_inactive_parameter_is_ignored(db):
    db.add(sp.SystemParameter(param_key="X", param_value="2.5", is_active=False))
    db.commit()
    assert sp.get_float_parameter(db, "X", 9.0) == 9.0


def test_seed_default_parameters_is_insert_only(db):
    assert sp.seed_default_parameters(db) == 1
    row = db.query(sp.SystemParameter).filter_by(param_key=sp.AIR_VOLUMETRIC_KG_PER_CBM).one()
    assert (row.param_value, row.is_active, row.created_by) == ("167", True, "system")
    row.param_value = "170"
    db.commit()
    assert sp.seed_default_parameters(db) == 0
    assert sp.air_volumetric_kg_per_cbm(db) == 170.0


# ── migration e5f6a7b8c9d0 ──

def _make_db(db_file: Path, drop_new: bool) -> None:
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        Base.metadata.create_all(bind=engine)
    finally:
        engine.dispose()
    conn = sqlite3.connect(db_file)
    try:
        if drop_new:
            conn.execute("DROP TABLE system_parameters")
            for table in ("purchase_orders", "po_shipment_allocations"):
                conn.execute(f'ALTER TABLE "{table}" DROP COLUMN "created_by"')
                conn.execute(f'ALTER TABLE "{table}" DROP COLUMN "updated_by"')
        conn.execute("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)")
        conn.execute("INSERT INTO alembic_version (version_num) VALUES (?)", (PREVIOUS,))
        conn.commit()
    finally:
        conn.close()


def _query(db_file: Path, sql: str):
    conn = sqlite3.connect(db_file)
    try:
        return conn.execute(sql).fetchall()
    finally:
        conn.close()


def _columns(db_file: Path, table: str):
    return {r[1] for r in _query(db_file, f'PRAGMA table_info("{table}")')}


def _tables(db_file: Path):
    return {r[0] for r in _query(db_file, "SELECT name FROM sqlite_master WHERE type='table'")}


def _upgrade(db_file: Path) -> str:
    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        return migration_runner.upgrade_to_head(engine)
    finally:
        engine.dispose()


def test_e5f6_follows_d9e4():
    from alembic.script import ScriptDirectory

    script = ScriptDirectory.from_config(migration_runner.build_alembic_config())
    assert script.get_revision(HEAD).down_revision == PREVIOUS


def test_behind_db_gets_table_seed_and_columns_then_downgrade_removes_them(tmp_path):
    db_file = tmp_path / "behind.db"
    _make_db(db_file, drop_new=True)
    assert "system_parameters" not in _tables(db_file)
    assert "created_by" not in _columns(db_file, "purchase_orders")

    assert _upgrade(db_file) == migration_runner.get_head_revision()

    assert _query(db_file, "SELECT param_key, param_value, is_active FROM system_parameters") == [
        ("AIR_VOLUMETRIC_KG_PER_CBM", "167", 1)
    ]
    for table in ("purchase_orders", "po_shipment_allocations"):
        assert {"created_by", "updated_by"} <= _columns(db_file, table)

    engine = create_engine(f"sqlite:///{db_file.as_posix()}")
    try:
        with engine.connect() as connection:
            command.downgrade(migration_runner.build_alembic_config(connection), PREVIOUS)
            connection.commit()
    finally:
        engine.dispose()
    assert "system_parameters" not in _tables(db_file)
    assert "created_by" not in _columns(db_file, "po_shipment_allocations")


def test_create_all_db_upgrade_writes_no_rows(tmp_path):
    db_file = tmp_path / "created.db"
    _make_db(db_file, drop_new=False)
    assert _upgrade(db_file) == migration_runner.get_head_revision()
    assert _query(db_file, "SELECT COUNT(*) FROM system_parameters") == [(0,)]
    assert {"created_by", "updated_by"} <= _columns(db_file, "purchase_orders")


# ── next_yearly_code ──

def _po(db, number):
    db.add(PurchaseOrder(po_number=number, project_id=1, company_id=1, supplier_id=1, incoterm_id=1, currency_id=1))
    db.commit()


def test_next_yearly_code_starts_at_one_and_skips_foreign_suffixes(db):
    assert next_yearly_code(db, PurchaseOrder.po_number, "PO", year=2026) == "PO-2026-001"
    for number in ("PO-2026-007", "PO-2026-REF01", "PO-2026-003-COPY", "PO-2025-050", "PO-2026-002"):
        _po(db, number)
    assert next_yearly_code(db, PurchaseOrder.po_number, "PO", year=2026) == "PO-2026-008"
    assert next_yearly_code(db, PurchaseOrder.po_number, "PO", year=2025) == "PO-2025-051"
    assert next_yearly_code(db, PurchaseOrder.po_number, "PO", year=2027) == "PO-2027-001"
    assert next_yearly_code(db, PurchaseOrder.po_number, "PO", pad=5, year=2026) == "PO-2026-00008"


# ── require_active ──

def _supplier(db, code, active=True):
    s = Supplier(supplier_code=code, company_name=code, supplier_type="Manufacturer", registration_type="CargoX",
                 foreign_exporter_id=code, foreign_exporter_country="Germany", foreign_exporter_country_code="DE",
                 address="Berlin", is_active=active)
    db.add(s)
    db.commit()
    return s


def test_require_active_returns_entity_or_raises_arabic_400(db):
    active = _supplier(db, "SUP-A")
    inactive = _supplier(db, "SUP-B", active=False)
    assert require_active(db, Supplier, active.supplier_id, "المورد") is active
    assert require_active(db, Supplier, None, "المورد") is None
    for missing in (inactive.supplier_id, 999):
        with pytest.raises(HTTPException) as exc:
            require_active(db, Supplier, missing, "المورد")
        assert exc.value.status_code == 400
        assert exc.value.detail == f"المورد رقم {missing} غير موجود أو غير نشط."
    with pytest.raises(HTTPException) as exc:
        require_active(db, Supplier, 999, "المورد", status_code=404)
    assert exc.value.status_code == 404


# ── codes_by_ids ──

def test_codes_by_ids_prefers_file_code_then_custom_number(db):
    names = dict(company_name="Importer", supplier_name="Supplier")
    a = ImportFile(import_file_code="IMP-2026-0001", custom_file_number="C-1", is_active=True, **names)
    b = ImportFile(import_file_code="", custom_file_number="C-2", is_active=False, **names)  # soft-deleted still resolves
    db.add_all([a, b])
    db.commit()
    got = codes_by_ids(db, [a.import_file_id, b.import_file_id, None, 12345])
    assert got == {a.import_file_id: "IMP-2026-0001", b.import_file_id: "C-2"}
    assert codes_by_ids(db, []) == {}
    assert codes_by_ids(db, [None]) == {}


# ── RBAC ──

PHASE1 = ("purchase_orders.delete", "cbm.manage", "shipping_scenarios.manage",
          "customs_consultation.manage", "import_requirements.manage")


def _role_codes(db, role_code):
    role = db.query(Role).filter_by(role_code=role_code).one()
    return {rp.permission.permission_code for rp in role.role_permissions}


def test_phase1_codes_are_in_the_catalog():
    catalog = {p["code"]: p for p in rbac.PERMISSIONS_CATALOG}
    for code in PHASE1:
        entry = catalog[code]
        assert entry["en"] and entry["ar"] and entry["desc"] and entry["action"] in ("delete", "manage")


def test_fresh_seed_role_matrix(db):
    rbac.seed_rbac(db)
    assert set(PHASE1) <= _role_codes(db, "GENERAL_MANAGER")
    operator = _role_codes(db, "LOGISTICS_OPERATOR")
    assert {"cbm.manage", "shipping_scenarios.manage", "import_requirements.manage"} <= operator
    assert "purchase_orders.delete" not in operator and "customs_consultation.manage" not in operator
    customs = _role_codes(db, "CUSTOMS_OFFICER")
    assert "customs_consultation.manage" in customs and "cbm.manage" not in customs
    for viewer in ("AUDITOR_VIEWER", "FINANCE_OFFICER"):
        assert not set(PHASE1) & _role_codes(db, viewer)
    assert set(PHASE1) <= _role_codes(db, "ADMIN")


def test_existing_db_copies_grants_once_to_custom_roles_and_user_overrides(db, monkeypatch):
    # An existing DB seeded before Phase 1: catalog and roles without the new codes.
    old_catalog = [p for p in rbac.PERMISSIONS_CATALOG if p["code"] not in PHASE1]
    monkeypatch.setattr(rbac, "PERMISSIONS_CATALOG", old_catalog)
    monkeypatch.setattr(rbac, "ROLES_CONFIG", [
        {**r, "permissions": [c for c in r["permissions"] if c not in PHASE1]} for r in rbac.ROLES_CONFIG
    ])
    rbac.seed_rbac(db)
    perms = {p.permission_code: p for p in db.query(Permission).all()}
    custom = Role(role_code="PLANNER", name_en="Planner", name_ar="مخطط", is_system_role=False, is_active=True)
    db.add(custom)
    db.flush()
    db.add(RolePermission(role_id=custom.role_id, permission_id=perms["purchase_orders.edit"].permission_id))
    user = User(username="u1", email="u1@x.local", hashed_password="x", full_name="U1", role="OPERATOR", is_active=True)
    db.add(user)
    db.flush()
    db.add(UserPermission(user_id=user.user_id, permission_id=perms["quotations.manage"].permission_id, is_granted=True))
    db.add(UserPermission(user_id=user.user_id, permission_id=perms["import_files.edit"].permission_id, is_granted=False))
    db.commit()
    monkeypatch.undo()

    rbac.seed_rbac(db)

    assert "cbm.manage" in _role_codes(db, "PLANNER")
    assert "purchase_orders.delete" not in _role_codes(db, "PLANNER")
    overrides = {up.permission.permission_code: up.is_granted
                 for up in db.query(UserPermission).filter_by(user_id=user.user_id)}
    assert overrides["shipping_scenarios.manage"] is True
    assert overrides["import_requirements.manage"] is False  # a revoke is copied as a revoke

    # Removing the copied grant sticks: the copy runs only when the code is first inserted.
    cbm = db.query(Permission).filter_by(permission_code="cbm.manage").one()
    db.query(RolePermission).filter_by(role_id=custom.role_id, permission_id=cbm.permission_id).delete()
    db.commit()
    rbac.seed_rbac(db)
    assert "cbm.manage" not in _role_codes(db, "PLANNER")


# ── startup seeding through MasterDataSyncService.sync_all ──

def test_sync_all_seeds_the_parameter_once_and_keeps_a_configured_value(db):
    import importlib
    import pkgutil

    import modules
    for info in pkgutil.iter_modules(modules.__path__):  # every model on Base.metadata (sync_all touches many tables)
        try:
            importlib.import_module(f"modules.{info.name}.model")
        except ModuleNotFoundError:
            pass
    Base.metadata.create_all(bind=db.get_bind())
    from database.master_data_sync_service import MasterDataSyncService

    first = MasterDataSyncService(db).sync_all()
    assert first["system_parameters_added"] == 1
    assert sp.air_volumetric_kg_per_cbm(db) == 167.0
    db.query(sp.SystemParameter).filter_by(param_key=sp.AIR_VOLUMETRIC_KG_PER_CBM).update({"param_value": "170"})
    db.commit()
    second = MasterDataSyncService(db).sync_all()
    assert second["system_parameters_added"] == 0
    assert sp.air_volumetric_kg_per_cbm(db) == 170.0


# ── simplify pass: get_or_404, not_null_columns, CodedHTTPException, best_effort, to_item, enum aliases ──

def test_get_or_404(db):
    from modules.common.validators import get_or_404

    active = _supplier(db, "SUP-G1")
    inactive = _supplier(db, "SUP-G2", active=False)
    assert get_or_404(db, Supplier, active.supplier_id, "المورد") is active
    assert get_or_404(db, Supplier, inactive.supplier_id, "المورد") is inactive
    for entity_id, kw in ((inactive.supplier_id, {"active_only": True}), (999, {})):
        with pytest.raises(HTTPException) as exc:
            get_or_404(db, Supplier, entity_id, "المورد", **kw)
        assert (exc.value.status_code, exc.value.detail) == (404, f"المورد رقم {entity_id} غير موجود.")


def test_not_null_columns():
    from modules.common.validators import not_null_columns

    cols = not_null_columns(PurchaseOrder)
    assert {"project_id", "po_number", "status", "exchange_rate"} <= cols
    assert "po_id" not in cols and "notes" not in cols and "import_file_id" not in cols


def test_coded_http_exception_keeps_the_flat_detail_shape():
    from modules.common.errors import CodedHTTPException

    exc = CodedHTTPException(409, "IR_ASSESSMENT_EXISTS", "رسالة", assessment_code="IRA-1", assessment_id=7)
    assert exc.status_code == 409
    assert exc.detail == {"code": "IR_ASSESSMENT_EXISTS", "message": "رسالة", "assessment_code": "IRA-1", "assessment_id": 7}
    with pytest.raises(KeyError):
        CodedHTTPException(409, "NOT_A_CODE", "x")
    with pytest.raises(TypeError):
        CodedHTTPException(409, "PO_NUMBER_TAKEN", "x", po_number={"bad": 1})


def test_best_effort_rolls_back_and_returns_none(db):
    from modules.common.errors import best_effort

    def boom():
        db.add(sp.SystemParameter(param_key="X", param_value="1"))
        db.flush()
        raise RuntimeError("fail")

    assert best_effort(db, lambda a, b=0: a + b, "add", 2, b=3) == 5
    assert best_effort(db, boom, "boom") is None
    assert db.query(sp.SystemParameter).count() == 0


def test_to_item_validates_through_msg():
    from modules.common.system_messages import SystemMessageItem, to_item

    item = to_item("OVER_SHIPPED", "warning", shipped_qty=2.0)
    assert isinstance(item, SystemMessageItem) and item.params == {"shipped_qty": 2.0}
    with pytest.raises(KeyError):
        to_item("NOT_A_CODE")


def test_kilogram_has_one_code_and_air_container_text_means_no_value():
    from modules.common import enum_codes as ec

    assert [ec.normalize(ec.MEASURE_UNIT, v) for v in ("KGM", "kg", "KGS", "Kilogram")] == ["KG"] * 4
    assert "KGM" not in ec.codes(ec.MEASURE_UNIT)
    assert ec.normalize(ec.CONTAINER_TYPE, "N/A (Air Freight Cargo)") is None
    assert "N/A (Air Freight Cargo)" not in ec.build_contract()[ec.CONTAINER_TYPE]["legacy"]


# ── freight RFQ uses the configurable air factor (approved: one factor) ──

def _rfq_db(db, shipment_mode):
    from modules.import_companies.model import ImportCompany
    from modules.purchase_orders.model import PackingListItem
    from datetime import date

    db.add(ImportCompany(company_id=1, importer_name="Imp", address="Cairo", country="Egypt", importer_id="I-1",
                         importer_id_expiry=date(2030, 1, 1), vat_id="V-1", vat_id_expiry=date(2030, 1, 1),
                         registration_number="R-1", registration_expiry=date(2030, 1, 1)))
    _supplier(db, "SUP-RFQ")
    db.add(ImportFile(import_file_id=9, import_file_code="IMP-2026-0009", company_id=1, company_name="Imp",
                      supplier_name="Supp", incoterm_code="EXW", shipment_mode=shipment_mode,
                      port_of_loading="Milan Airport", port_of_discharge="Cairo International Airport"))
    db.add(PurchaseOrder(po_id=9, po_number="PO-RFQ-9", import_file_id=9, project_id=1, company_id=1, supplier_id=1,
                         incoterm_id=1, currency_id=1, total_cbm=0.2944, total_gross_weight_kg=10.0, total_net_weight_kg=8.0,
                         total_packages_count=1))
    db.add(PackingListItem(po_id=9, item_code="A", hs_code="84145925", qty_pkg=1, length_cm=80.0, width_cm=80.0,
                           height_cm=46.0, total_gross_weight_kg=10.0, total_net_weight_kg=8.0))
    db.commit()


@pytest.mark.parametrize("factor, expected", [(None, 49.16), ("200", 58.88)])
def test_freight_rfq_air_chargeable_weight_uses_the_parameter(db, factor, expected):
    from modules.import_files.service import generate_freight_rfq_service

    _rfq_db(db, "Air")
    if factor:
        db.add(sp.SystemParameter(param_key=sp.AIR_VOLUMETRIC_KG_PER_CBM, param_value=factor))
        db.commit()
    rfq = generate_freight_rfq_service(db, import_file_id=9)
    # 0.8 x 0.8 x 0.46 = 0.2944 CBM x factor (167 default) > 10 kg gross
    assert rfq["is_air"] is True
    assert rfq["chargeable_weight_kg"] == pytest.approx(expected, abs=0.01)


def test_freight_rfq_courier_keeps_its_own_divisor(db):
    from modules.import_files.service import generate_freight_rfq_service

    _rfq_db(db, "Courier Express")
    rfq = generate_freight_rfq_service(db, import_file_id=9)
    assert rfq["chargeable_weight_kg"] == pytest.approx(0.2944 * 200.0, abs=0.01)  # L x W x H / 5000


# ── seed_rbac security review: built-in links only for new roles / new codes, one-time batches ──

def _link_count(db):
    return db.query(RolePermission).count()


def _unlink(db, role_code, perm_code):
    role = db.query(Role).filter_by(role_code=role_code).one()
    perm = db.query(Permission).filter_by(permission_code=perm_code).one()
    db.query(RolePermission).filter_by(role_id=role.role_id, permission_id=perm.permission_id).delete()
    db.commit()


def test_second_seed_run_is_a_no_op(db):
    rbac.seed_rbac(db)
    links = _link_count(db)
    again = rbac.seed_rbac(db)
    assert (again["permissions_added"], again["roles_added"], again["role_permissions_linked"]) == (0, 0, 0)
    assert _link_count(db) == links


def test_fresh_db_derived_grant_copy_is_a_no_op(db):
    # fresh catalog: the source codes did not exist before this run, so nothing is copied to custom roles
    result = rbac.seed_rbac(db)
    assert result["permissions_added"] == len(rbac.PERMISSIONS_CATALOG)
    assert db.query(UserPermission).count() == 0


@pytest.mark.parametrize("role_code, code", [
    ("GENERAL_MANAGER", "purchase_orders.delete"),
    ("LOGISTICS_OPERATOR", "cbm.manage"),
    ("CUSTOMS_OFFICER", "quotations.view"),
])
def test_removal_from_a_built_in_role_survives_a_restart(db, role_code, code):
    rbac.seed_rbac(db)
    _unlink(db, role_code, code)
    rbac.seed_rbac(db)
    assert code not in _role_codes(db, role_code)


@pytest.mark.parametrize("role_code, code", [("CUSTOMS_OFFICER", "quotations.view"),
                                             ("LOGISTICS_OPERATOR", "customs_clearance.view")])
def test_phase1_read_grants_reach_existing_dbs_once(db, role_code, code):
    rbac.seed_rbac(db)
    assert code in _role_codes(db, role_code)
    # an existing DB seeded before the batch: no marker yet, role without the read grant
    _unlink(db, role_code, code)
    db.query(sp.SystemParameter).filter_by(param_key=rbac.RBAC_GRANT_BATCHES_KEY).delete()
    db.commit()
    rbac.seed_rbac(db)
    assert code in _role_codes(db, role_code)
    marker = db.query(sp.SystemParameter).filter_by(param_key=rbac.RBAC_GRANT_BATCHES_KEY).one()
    assert "2026-10-05-phase1-read-grants" in marker.param_value.split(",")
    # applied once: a later removal sticks
    _unlink(db, role_code, code)
    rbac.seed_rbac(db)
    assert code not in _role_codes(db, role_code)


def test_read_grants_do_not_give_write_access(db):
    rbac.seed_rbac(db)
    assert "quotations.manage" not in _role_codes(db, "CUSTOMS_OFFICER")
    assert not {"customs_clearance.update", "customs_consultation.manage"} & _role_codes(db, "LOGISTICS_OPERATOR")


def test_crash_during_seed_leaves_nothing_half_linked(db, monkeypatch):
    """An existing DB gains the Phase-1 codes; the run fails after the catalog step: nothing may be committed,
    so the next run still sees the codes as new and links them to the built-in roles."""
    old_catalog = [p for p in rbac.PERMISSIONS_CATALOG if p["code"] not in PHASE1]
    monkeypatch.setattr(rbac, "PERMISSIONS_CATALOG", old_catalog)
    monkeypatch.setattr(rbac, "ROLES_CONFIG", [
        {**r, "permissions": [c for c in r["permissions"] if c not in PHASE1]} for r in rbac.ROLES_CONFIG
    ])
    rbac.seed_rbac(db)
    monkeypatch.undo()

    def boom(*args, **kwargs):
        raise RuntimeError("crash between the role links and the commit")

    monkeypatch.setattr(rbac, "_apply_one_time_role_grants", boom)
    with pytest.raises(RuntimeError):
        rbac.seed_rbac(db)
    db.rollback()
    assert db.query(Permission).filter_by(permission_code="purchase_orders.delete").first() is None
    monkeypatch.undo()

    rbac.seed_rbac(db)
    assert "purchase_orders.delete" in _role_codes(db, "GENERAL_MANAGER")
    assert "cbm.manage" in _role_codes(db, "LOGISTICS_OPERATOR")


def test_fresh_seed_has_no_duplicate_role_links(db):
    rbac.seed_rbac(db)
    pairs = [(rp.role_id, rp.permission_id) for rp in db.query(RolePermission).all()]
    assert len(pairs) == len(set(pairs))

