"""
DB safety (docs/plans/update-system-plan.md section 0: A13-A15, R9, R12): maintenance scripts.

Every script that writes a database must
- take ONE explicit target (--db) and refuse without it,
- refuse without --confirm,
- refuse a missing target and a target in use (the backend keeps a WAL connection open),
- take a verified, protected backup first and abort (target unchanged) when that backup fails,
- never touch any database other than the target: decoy DBs are created at every old hard-coded location
  (under a patched ROOT_DIR) and must keep their sha256.

Everything runs on tmp_path; the real repo / dist databases are never opened.
"""
import hashlib
import importlib
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest

import scripts.db_script_guard as guard
from utils.db_safety import is_protected_backup

REPO_ROOT = Path(__file__).resolve().parents[2]

OLD_HARDCODED_LOCATIONS = [
    Path("sorour_logistics.db"),
    Path("dist") / "Sorour_Logistics_Standalone" / "sorour_logistics.db",
    Path("dist") / "ImportFlow_Standalone" / "sorour_logistics.db",
    Path("dist") / "sorour_logistics.db",
    Path("dist_backend") / "sorour_logistics.db",
]


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

def sha256(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def make_operational_db(path: Path) -> Path:
    """A small DB with every table the legacy scripts touch, and some rows to lose."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE import_companies (id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE suppliers (id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE external_service_providers (id INTEGER PRIMARY KEY, name TEXT, partner_type TEXT);
        CREATE TABLE cargox_envelopes (id INTEGER PRIMARY KEY);
        CREATE TABLE cargox_envelope_documents (id INTEGER PRIMARY KEY);
        CREATE TABLE projects (id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE import_files (id INTEGER PRIMARY KEY, file_number TEXT);
        CREATE TABLE countries (country_id INTEGER PRIMARY KEY AUTOINCREMENT, country_code VARCHAR(10) NOT NULL UNIQUE,
            country_name VARCHAR(150) NOT NULL, country_name_ar VARCHAR(150), is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at DATETIME, updated_at DATETIME);
        CREATE TABLE cities (city_id INTEGER PRIMARY KEY AUTOINCREMENT, city_code VARCHAR(20) NOT NULL UNIQUE,
            city_name VARCHAR(150) NOT NULL, country_code VARCHAR(10), is_active BOOLEAN NOT NULL DEFAULT 1,
            created_at DATETIME, updated_at DATETIME);
        CREATE TABLE currencies (currency_id INTEGER PRIMARY KEY AUTOINCREMENT, currency_code VARCHAR(10) NOT NULL UNIQUE,
            currency_name TEXT, currency_symbol TEXT, is_base_currency BOOLEAN, decimal_places INTEGER,
            is_active BOOLEAN, created_at DATETIME, updated_at DATETIME);
        CREATE TABLE transport_locations (location_id INTEGER PRIMARY KEY AUTOINCREMENT, un_locode VARCHAR(10) UNIQUE,
            location_name TEXT, location_type TEXT, country TEXT, city TEXT, notes TEXT, is_active BOOLEAN,
            created_at DATETIME, updated_at DATETIME);
        INSERT INTO import_companies VALUES (1, 'Real Importer Co');
        INSERT INTO suppliers VALUES (1, 'Real Supplier');
        INSERT INTO external_service_providers VALUES (1, 'Real Broker', 'Customs Broker');
        INSERT INTO projects VALUES (1, 'Real Project');
        INSERT INTO import_files VALUES (1, 'IF-0001');
        INSERT INTO currencies (currency_code, currency_name) VALUES ('USD', 'US Dollar');
        INSERT INTO transport_locations (location_id, un_locode, location_name, location_type, country, city)
            VALUES (8, 'EGALY', 'Alexandria', 'Port', 'Egypt', 'Alexandria');
        """
    )
    conn.commit()
    conn.close()
    return path


def count_rows(path: Path, table: str) -> int:
    conn = sqlite3.connect(path)
    try:
        return conn.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
    finally:
        conn.close()


@pytest.fixture
def workspace(tmp_path, monkeypatch):
    """fake_root with decoy DBs at every old hard-coded location, plus a separate explicit target."""
    fake_root = tmp_path / "fake_root"
    decoys = {}
    for rel in OLD_HARDCODED_LOCATIONS:
        decoy = make_operational_db(fake_root / rel)
        decoys[decoy] = sha256(decoy)
    # The "live" app database for the guard is the decoy at the old root location.
    monkeypatch.setattr(guard, "default_db_path", lambda: fake_root / "sorour_logistics.db")
    target = make_operational_db(tmp_path / "work" / "target.db")
    return {"root": fake_root, "decoys": decoys, "target": target, "tmp": tmp_path}


def assert_decoys_untouched(ws):
    for decoy, digest in ws["decoys"].items():
        assert decoy.exists(), f"decoy removed: {decoy}"
        assert sha256(decoy) == digest, f"decoy changed: {decoy}"
    for folder in (ws["root"] / "backups", ws["root"] / "dist" / "backups"):
        assert not folder.exists(), f"a backup was written next to a decoy: {folder}"


def load(module_name: str, ws, monkeypatch):
    module = importlib.import_module(module_name)
    if hasattr(module, "ROOT_DIR"):
        monkeypatch.setattr(module, "ROOT_DIR", ws["root"])
    return module


# (module, entry-point function name) for the scripts sharing the standard --db/--confirm CLI.
STANDARD_SCRIPTS = [
    ("execute_user_database_updates", "execute_updates_on_db"),
    ("populate_all_world_transport_locations", "execute_all_updates"),
    ("populate_package_types_and_uom", "populate_db"),
    ("clean_transport_locations", "clean_transport_locations"),
    ("clean_and_isolate_databases", "clean_database"),
    ("update_db_schema", None),
]
STANDARD_IDS = [name for name, _ in STANDARD_SCRIPTS]


# ----------------------------------------------------------------------------
# Guard unit tests
# ----------------------------------------------------------------------------

def test_lock_probe_detects_an_idle_wal_connection(tmp_path):
    db = make_operational_db(tmp_path / "live.db")
    holder = sqlite3.connect(db)
    try:
        holder.execute("PRAGMA journal_mode=WAL;")
        holder.execute("SELECT COUNT(*) FROM projects").fetchone()
        assert guard.is_db_in_use(db) is True
    finally:
        holder.close()
    assert guard.is_db_in_use(db) is False


def test_lock_probe_never_creates_a_missing_file(tmp_path):
    missing = tmp_path / "nope.db"
    assert guard.is_db_in_use(missing) is False
    assert not missing.exists()


def test_verified_backup_is_protected_and_restorable(tmp_path):
    db = make_operational_db(tmp_path / "a.db")
    result = guard.take_verified_backup(db, tag="unit")
    assert result.path.parent == tmp_path / "backups"
    assert result.path.name.startswith("pre_migration_unit_a_")
    assert is_protected_backup(result.path)
    assert result.integrity == "ok"
    assert count_rows(result.path, "projects") == 1


def test_guard_refuses_without_confirm_and_same_file(tmp_path):
    db = make_operational_db(tmp_path / "a.db")
    with pytest.raises(guard.UnsafeTargetError):
        guard.guard_destructive_target(db, confirm=False, tag="t")
    with pytest.raises(guard.UnsafeTargetError):
        guard.guard_destructive_target(db, confirm=True, tag="t", forbid=[tmp_path / "a.db"])
    with pytest.raises(guard.UnsafeTargetError):
        guard.guard_destructive_target(None, confirm=True, tag="t")
    assert not (tmp_path / "backups").exists()


def test_programmatic_guard_refuses_the_live_database(workspace):
    live = workspace["root"] / "sorour_logistics.db"
    with pytest.raises(guard.UnsafeTargetError):
        guard.guard_programmatic_target(live)
    # DATABASE_PATH (conftest's temp DB) is live as well
    with pytest.raises(guard.UnsafeTargetError):
        guard.guard_programmatic_target(Path(os.environ["DATABASE_PATH"]))
    assert guard.guard_programmatic_target(workspace["target"]) == workspace["target"]
    assert_decoys_untouched(workspace)


# ----------------------------------------------------------------------------
# Standard destructive scripts
# ----------------------------------------------------------------------------

@pytest.mark.parametrize("module_name,_fn", STANDARD_SCRIPTS, ids=STANDARD_IDS)
def test_refuses_without_db(module_name, _fn, workspace, monkeypatch):
    module = load(module_name, workspace, monkeypatch)
    assert module.main(["--confirm"]) == guard.EXIT_REFUSED
    assert_decoys_untouched(workspace)


@pytest.mark.parametrize("module_name,_fn", STANDARD_SCRIPTS, ids=STANDARD_IDS)
def test_refuses_without_confirm(module_name, _fn, workspace, monkeypatch):
    module = load(module_name, workspace, monkeypatch)
    target = workspace["target"]
    before = sha256(target)
    assert module.main(["--db", str(target)]) == guard.EXIT_REFUSED
    assert sha256(target) == before
    assert not (target.parent / "backups").exists()
    assert_decoys_untouched(workspace)


@pytest.mark.parametrize("module_name,_fn", STANDARD_SCRIPTS, ids=STANDARD_IDS)
def test_refuses_missing_target(module_name, _fn, workspace, monkeypatch):
    module = load(module_name, workspace, monkeypatch)
    missing = workspace["tmp"] / "work" / "missing.db"
    assert module.main(["--db", str(missing), "--confirm"]) == guard.EXIT_REFUSED
    assert not missing.exists()
    assert_decoys_untouched(workspace)


@pytest.mark.parametrize("module_name,_fn", STANDARD_SCRIPTS, ids=STANDARD_IDS)
def test_refuses_target_in_use(module_name, _fn, workspace, monkeypatch):
    module = load(module_name, workspace, monkeypatch)
    target = workspace["target"]
    holder = sqlite3.connect(target)
    try:
        holder.execute("PRAGMA journal_mode=WAL;")
        holder.execute("SELECT COUNT(*) FROM projects").fetchone()
        assert module.main(["--db", str(target), "--confirm"]) == guard.EXIT_REFUSED
        assert holder.execute("SELECT COUNT(*) FROM projects").fetchone()[0] == 1
        assert holder.execute("SELECT COUNT(*) FROM import_companies").fetchone()[0] == 1
    finally:
        holder.close()
    assert not (target.parent / "backups").exists()
    assert_decoys_untouched(workspace)


@pytest.mark.parametrize("module_name,_fn", STANDARD_SCRIPTS, ids=STANDARD_IDS)
def test_aborts_when_backup_fails(module_name, _fn, workspace, monkeypatch):
    module = load(module_name, workspace, monkeypatch)

    def failing_backup(*_args, **_kwargs):
        raise OSError("disk full")

    monkeypatch.setattr(guard, "sqlite_online_backup", failing_backup)
    target = workspace["target"]
    before = sha256(target)
    assert module.main(["--db", str(target), "--confirm"]) == guard.EXIT_REFUSED
    assert sha256(target) == before
    assert_decoys_untouched(workspace)


@pytest.mark.parametrize("module_name,_fn", STANDARD_SCRIPTS, ids=STANDARD_IDS)
def test_backs_up_then_changes_only_the_target(module_name, _fn, workspace, monkeypatch):
    module = load(module_name, workspace, monkeypatch)
    target = workspace["target"]
    before = sha256(target)

    assert module.main(["--db", str(target), "--confirm"]) == 0

    backups = sorted((target.parent / "backups").glob("pre_migration_*.db"))
    assert len(backups) == 1, backups
    assert is_protected_backup(backups[0])
    # The backup holds the pre-change data.
    assert count_rows(backups[0], "projects") == 1
    assert count_rows(backups[0], "import_companies") == 1
    assert sha256(target) != before
    assert_decoys_untouched(workspace)


def test_destructive_scripts_really_changed_the_target(workspace, monkeypatch):
    """Normal behaviour is kept: the wipes still happen on the confirmed target."""
    target = workspace["target"]
    assert load("execute_user_database_updates", workspace, monkeypatch).main(["--db", str(target), "--confirm"]) == 0
    assert count_rows(target, "import_companies") == 0
    assert count_rows(target, "countries") > 200
    assert load("populate_all_world_transport_locations", workspace, monkeypatch).main(
        ["--db", str(target), "--confirm"]) == 0
    assert count_rows(target, "projects") == 0
    assert load("clean_and_isolate_databases", workspace, monkeypatch).main(["--db", str(target), "--confirm"]) == 0
    assert count_rows(target, "import_files") == 0
    assert count_rows(target, "transport_locations") > 0
    assert len(list((target.parent / "backups").glob("pre_migration_*.db"))) == 3
    assert_decoys_untouched(workspace)


@pytest.mark.parametrize("module_name,fn_name", [s for s in STANDARD_SCRIPTS if s[1]], ids=STANDARD_IDS[:-1])
def test_importable_function_refuses_the_live_database(module_name, fn_name, workspace, monkeypatch):
    module = load(module_name, workspace, monkeypatch)
    live = workspace["root"] / "sorour_logistics.db"
    with pytest.raises(guard.UnsafeTargetError):
        getattr(module, fn_name)(live)
    assert_decoys_untouched(workspace)


def test_clean_database_programmatic_call_on_a_bundle_copy_still_works(workspace, monkeypatch):
    """package_production.py calls clean_database(<fresh bundle copy>) without confirm."""
    module = load("clean_and_isolate_databases", workspace, monkeypatch)
    bundle_copy = make_operational_db(workspace["tmp"] / "bundle" / "sorour_logistics.db")
    assert module.clean_database(bundle_copy) is True
    assert count_rows(bundle_copy, "projects") == 0
    assert not (bundle_copy.parent / "backups").exists()
    assert_decoys_untouched(workspace)


def test_clean_transport_locations_import_has_no_side_effects(workspace, monkeypatch):
    before = {p: sha256(p) for p in workspace["decoys"]}
    monkeypatch.chdir(workspace["root"])
    sys.modules.pop("clean_transport_locations", None)
    importlib.import_module("clean_transport_locations")
    assert {p: sha256(p) for p in workspace["decoys"]} == before


# ----------------------------------------------------------------------------
# update_db_schema: the customs_tariffs rebuild (DROP TABLE) needs a verified backup
# ----------------------------------------------------------------------------

LEGACY_TARIFF_TABLE = """
CREATE TABLE customs_tariffs (
    tariff_id INTEGER PRIMARY KEY, hs_code VARCHAR(20) NOT NULL, hs_description TEXT, customs_category TEXT,
    customs_duty_rate FLOAT, vat_rate FLOAT, schedule_tax_rate FLOAT, development_fee_rate FLOAT,
    import_fee_rate FLOAT, requires_coo BOOLEAN, requires_inspection BOOLEAN, requires_acid BOOLEAN,
    regulatory_authority TEXT, prior_approval_note TEXT, effective_from DATE, effective_to DATE, source_url TEXT,
    last_verified_date DATE, verified_by TEXT, confidence TEXT, notes TEXT, is_active BOOLEAN,
    created_at DATETIME, updated_at DATETIME,
    CONSTRAINT uq_customs_tariff_hs_code UNIQUE (hs_code)
);
INSERT INTO customs_tariffs (tariff_id, hs_code, hs_description, is_active) VALUES (1, '8471.30.00', 'Laptops', 1);
"""


def test_update_db_schema_rebuild_aborts_before_drop_when_backup_fails(tmp_path, monkeypatch):
    update_db_schema = importlib.import_module("update_db_schema")
    db = tmp_path / "legacy.db"
    conn = sqlite3.connect(db)
    conn.executescript(LEGACY_TARIFF_TABLE)
    conn.close()

    def failing_backup(*_args, **_kwargs):
        raise OSError("disk full")

    monkeypatch.setattr(guard, "sqlite_online_backup", failing_backup)
    with pytest.raises(guard.UnsafeTargetError):
        update_db_schema.migrate_db(db)
    conn = sqlite3.connect(db)
    try:
        sql = conn.execute("SELECT sql FROM sqlite_master WHERE name='customs_tariffs'").fetchone()[0]
        assert "uq_customs_tariff_hs_code" in sql  # not rebuilt, not dropped
        assert conn.execute("SELECT COUNT(*) FROM customs_tariffs").fetchone()[0] == 1
    finally:
        conn.close()


def test_update_db_schema_migrate_db_defaults_to_the_engine_database(monkeypatch):
    update_db_schema = importlib.import_module("update_db_schema")
    seen = {}
    monkeypatch.setattr(update_db_schema, "_migrate", lambda path, eng, _b: seen.update(path=path, engine=eng))
    update_db_schema.migrate_db()
    assert os.path.samefile(seen["path"], os.environ["DATABASE_PATH"])
    assert seen["engine"] is update_db_schema.engine


# ----------------------------------------------------------------------------
# reset_clean_production_db
# ----------------------------------------------------------------------------

def test_reset_refuses_without_confirm_and_on_failed_backup(workspace, monkeypatch):
    module = load("reset_clean_production_db", workspace, monkeypatch)
    target = workspace["target"]
    before = sha256(target)
    assert module.main(["--db", str(target)]) == guard.EXIT_REFUSED
    assert module.main(["--confirm"]) == guard.EXIT_REFUSED

    def failing_backup(*_args, **_kwargs):
        raise OSError("disk full")

    monkeypatch.setattr(guard, "sqlite_online_backup", failing_backup)
    assert module.main(["--db", str(target), "--confirm"]) == guard.EXIT_REFUSED
    assert target.exists() and sha256(target) == before
    with pytest.raises(guard.UnsafeTargetError):
        module.build_clean_production_db(workspace["root"] / "sorour_logistics.db")
    assert_decoys_untouched(workspace)


def test_reset_keeps_the_target_when_no_reference_snapshot_exists(workspace, monkeypatch):
    module = load("reset_clean_production_db", workspace, monkeypatch)
    monkeypatch.setattr(module, "BACKUPS_DIR", workspace["tmp"] / "empty_backups")
    target = workspace["target"]
    with pytest.raises(FileNotFoundError):
        module.build_clean_production_db(target, confirm=True)
    # the verified backup was taken, and the target was not deleted
    assert count_rows(target, "projects") == 1
    assert len(list((target.parent / "backups").glob("pre_migration_*.db"))) == 1
    assert_decoys_untouched(workspace)


# ----------------------------------------------------------------------------
# sync_to_production
# ----------------------------------------------------------------------------

@pytest.fixture
def sync_module(workspace, monkeypatch):
    module = importlib.import_module("sync_to_production")
    root = workspace["root"]
    monkeypatch.setattr(module, "ROOT_DIR", root)
    monkeypatch.setattr(module, "DIST_DIR", root / "dist")
    monkeypatch.setattr(module, "STANDALONE_DIR", root / "dist" / "Sorour_Logistics_Standalone")
    monkeypatch.setattr(module, "DEV_DB", root / "sorour_logistics.db")
    monkeypatch.setattr(module, "PROD_DB", root / "dist" / "Sorour_Logistics_Standalone" / "sorour_logistics.db")
    monkeypatch.setattr(module, "BACKUPS_DIR", root / "backups")
    return module


@pytest.mark.parametrize("action", ["--db-only", "--pull", "--full"])
def test_sync_write_actions_refuse_without_db_or_confirm(action, sync_module, workspace):
    target = workspace["target"]
    before = sha256(target)
    assert sync_module.main([action]) == guard.EXIT_REFUSED
    assert sync_module.main([action, "--db", str(target)]) == guard.EXIT_REFUSED
    assert sha256(target) == before
    assert_decoys_untouched(workspace)


def test_sync_push_merges_into_the_explicit_target_only(sync_module, workspace):
    source = make_operational_db(workspace["tmp"] / "work" / "dev_source.db")
    conn = sqlite3.connect(source)
    conn.execute("INSERT INTO projects VALUES (2, 'New Dev Project')")
    conn.commit()
    conn.close()
    source_digest = sha256(source)
    target = workspace["target"]

    assert sync_module.main(["--db-only", "--source", str(source), "--db", str(target), "--confirm"]) == 0

    assert count_rows(target, "projects") == 2
    assert sha256(source) == source_digest
    backups = list((target.parent / "backups").glob("pre_migration_*.db"))
    assert len(backups) == 1 and count_rows(backups[0], "projects") == 1
    assert_decoys_untouched(workspace)


def test_sync_push_default_source_is_only_read(sync_module, workspace):
    target = workspace["target"]
    assert sync_module.main(["--db-only", "--db", str(target), "--confirm"]) == 0
    assert_decoys_untouched(workspace)  # the default source (decoy dev DB) kept its sha256


def test_sync_refuses_target_equal_to_source(sync_module, workspace):
    target = workspace["target"]
    before = sha256(target)
    assert sync_module.main(["--pull", "--source", str(target), "--db", str(target), "--confirm"]) == guard.EXIT_REFUSED
    assert sha256(target) == before


def test_sync_creates_a_missing_target_with_the_online_backup_api(sync_module, workspace):
    new_target = workspace["tmp"] / "work" / "new_prod" / "prod.db"
    assert sync_module.main(["--db-only", "--source", str(workspace["target"]), "--db", str(new_target), "--confirm"]) == 0
    assert count_rows(new_target, "projects") == 1
    assert_decoys_untouched(workspace)


def test_sync_smart_migrate_unguarded_refuses_live_db(sync_module, workspace):
    with pytest.raises(guard.UnsafeTargetError):
        sync_module.smart_non_destructive_migrate(workspace["target"], workspace["root"] / "sorour_logistics.db")
    assert_decoys_untouched(workspace)


def test_sync_find_project_root_has_no_hardcoded_workspace():
    source = (REPO_ROOT / "sync_to_production.py").read_text(encoding="utf-8")
    assert "C:/Users/Hp" not in source
    assert "D:/ImportFlow" not in source


# ----------------------------------------------------------------------------
# prepare_uat_environment (A14)
# ----------------------------------------------------------------------------

@pytest.fixture
def uat_module(workspace, monkeypatch):
    module = importlib.import_module("scripts.prepare_uat_environment")
    monkeypatch.setattr(module, "ROOT_DIR", workspace["root"])
    monkeypatch.setattr(module, "PROD_DB", workspace["root"] / "sorour_logistics.db")
    monkeypatch.setattr(module, "UAT_DB", workspace["root"] / "sorour_logistics_uat.db")
    return module


def test_uat_init_creates_a_new_clean_copy(uat_module, workspace):
    source = make_operational_db(workspace["tmp"] / "work" / "source.db")
    uat = workspace["tmp"] / "work" / "uat.db"
    assert uat_module.main(["--init", "--source", str(source), "--db", str(uat)]) == 0
    assert count_rows(uat, "projects") == 1  # master table preserved
    assert count_rows(uat, "import_files") == 0  # operational table wiped
    assert count_rows(source, "import_files") == 1
    assert_decoys_untouched(workspace)


def test_uat_refuses_source_or_live_db_as_target(uat_module, workspace):
    source = workspace["target"]
    before = sha256(source)
    assert uat_module.main(["--reset", "--source", str(source), "--db", str(source), "--confirm"]) == guard.EXIT_REFUSED
    assert sha256(source) == before
    live = workspace["root"] / "sorour_logistics.db"
    assert uat_module.main(["--reset", "--source", str(source), "--db", str(live), "--confirm"]) == guard.EXIT_REFUSED
    assert uat_module.main(["--init", "--db", str(live)]) == guard.EXIT_REFUSED
    assert_decoys_untouched(workspace)


def test_uat_reset_requires_confirm_and_backs_up_the_old_copy(uat_module, workspace):
    source = make_operational_db(workspace["tmp"] / "work" / "source.db")
    uat = make_operational_db(workspace["tmp"] / "work" / "uat.db")
    before = sha256(uat)
    assert uat_module.main(["--reset", "--source", str(source), "--db", str(uat)]) == guard.EXIT_REFUSED
    assert sha256(uat) == before
    assert uat_module.main(["--reset", "--source", str(source), "--db", str(uat), "--confirm"]) == 0
    assert count_rows(uat, "import_files") == 0
    backups = list((uat.parent / "backups").glob("pre_migration_uat_reset_*.db"))
    assert len(backups) == 1 and count_rows(backups[0], "import_files") == 1
    assert_decoys_untouched(workspace)


def test_uat_status_is_read_only_and_keeps_its_api(uat_module, workspace):
    uat = make_operational_db(workspace["tmp"] / "work" / "uat.db")
    before = sha256(uat)
    assert uat_module.status_uat(uat) is False  # operational rows present
    assert sha256(uat) == before
    assert uat_module.status_uat() is False  # default UAT file missing


# ----------------------------------------------------------------------------
# restore_database (A15)
# ----------------------------------------------------------------------------

@pytest.fixture
def restore_module():
    return importlib.import_module("scripts.restore_database")


def _backup_source(tmp_path: Path) -> Path:
    src = make_operational_db(tmp_path / "bk" / "daily_backup_20260101_000000.db")
    conn = sqlite3.connect(src)
    conn.execute("INSERT INTO projects VALUES (99, 'From Backup')")
    conn.commit()
    conn.close()
    return src


def test_restore_requires_db_and_confirm(restore_module, workspace):
    backup = _backup_source(workspace["tmp"])
    target = workspace["target"]
    before = sha256(target)
    assert restore_module.main(["--backup", str(backup)]) == guard.EXIT_REFUSED
    assert restore_module.main(["--backup", str(backup), "--db", str(target)]) == guard.EXIT_REFUSED
    assert sha256(target) == before
    assert not (target.parent / "backups").exists()


def test_restore_refuses_while_the_target_is_in_use(restore_module, workspace):
    backup = _backup_source(workspace["tmp"])
    target = workspace["target"]
    holder = sqlite3.connect(target)
    try:
        holder.execute("PRAGMA journal_mode=WAL;")
        holder.execute("SELECT 1 FROM projects").fetchall()
        assert restore_module.main(["--backup", str(backup), "--db", str(target), "--confirm"]) == guard.EXIT_REFUSED
        assert holder.execute("SELECT COUNT(*) FROM projects").fetchone()[0] == 1
    finally:
        holder.close()


def test_restore_takes_a_protected_pre_restore_backup_first(restore_module, workspace):
    backup = _backup_source(workspace["tmp"])
    target = workspace["target"]
    assert restore_module.main(["--backup", str(backup), "--db", str(target), "--confirm"]) == 0
    assert count_rows(target, "projects") == 2
    safety = list((target.parent / "backups").glob("pre_restore_restore_target_*.db"))
    assert len(safety) == 1
    assert is_protected_backup(safety[0])
    assert count_rows(safety[0], "projects") == 1  # the data before the restore
    assert_decoys_untouched(workspace)


def test_restore_aborts_when_the_safety_backup_fails(restore_module, workspace, monkeypatch):
    backup = _backup_source(workspace["tmp"])
    target = workspace["target"]
    before = sha256(target)

    def failing_backup(*_args, **_kwargs):
        raise OSError("disk full")

    monkeypatch.setattr(guard, "sqlite_online_backup", failing_backup)
    assert restore_module.main(["--backup", str(backup), "--db", str(target), "--confirm"]) == guard.EXIT_REFUSED
    assert sha256(target) == before


def test_restore_function_refuses_existing_target_without_confirm(restore_module, workspace):
    backup = _backup_source(workspace["tmp"])
    with pytest.raises(guard.UnsafeTargetError):
        restore_module.restore_database(backup, workspace["target"])
    with pytest.raises(guard.UnsafeTargetError):
        restore_module.restore_database(backup, workspace["root"] / "sorour_logistics.db", confirm=False)
    assert_decoys_untouched(workspace)


# ----------------------------------------------------------------------------
# Real entry points (python <script>.py): refuse without flags, exit code non-zero
# ----------------------------------------------------------------------------

SUBPROCESS_CASES = [
    ("execute_user_database_updates.py", []),
    ("populate_all_world_transport_locations.py", []),
    ("populate_package_types_and_uom.py", []),
    ("clean_transport_locations.py", []),
    ("clean_and_isolate_databases.py", []),
    ("update_db_schema.py", []),
    ("reset_clean_production_db.py", []),
    ("sync_to_production.py", ["--db-only"]),
    ("sync_to_production.py", ["--pull"]),
    ("scripts/prepare_uat_environment.py", ["--reset"]),
    ("scripts/restore_database.py", ["--backup", "x.db"]),
]


@pytest.mark.parametrize("script,args", SUBPROCESS_CASES, ids=[f"{s}{' ' + ' '.join(a) if a else ''}" for s, a in SUBPROCESS_CASES])
def test_script_entry_point_refuses_without_flags(script, args, tmp_path):
    env = dict(os.environ)
    env["DATABASE_PATH"] = str(tmp_path / "scratch_app.db")
    env["PYTHONIOENCODING"] = "utf-8"
    proc = subprocess.run(
        [sys.executable, str(REPO_ROOT / script), *args],
        cwd=str(tmp_path),
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=240,
    )
    assert proc.returncode == guard.EXIT_REFUSED, proc.stdout + proc.stderr
    assert "[REFUSED]" in proc.stderr


# ----------------------------------------------------------------------------
# Round 3: installed laptop DBs are live; race re-check; restore temp dir; admin-only reset seed
# ----------------------------------------------------------------------------

def test_installer_app_id_and_folder_match_the_iss():
    iss = (REPO_ROOT / "installer" / "importflow_setup.iss").read_text(encoding="utf-8-sig")
    assert "AppId={" + guard.INSTALLER_APP_ID in iss
    assert f'#define MyAppName "{guard.INSTALLED_APP_FOLDER}"' in iss
    assert "DefaultDirName={autopf}\\{#MyAppName}" in iss


class _FakeWinreg:
    HKEY_CURRENT_USER = "HKCU"
    HKEY_LOCAL_MACHINE = "HKLM"
    KEY_WOW64_64KEY = 0x100
    KEY_WOW64_32KEY = 0x200
    KEY_READ = 0x20019

    def __init__(self, values):
        self.values = values  # {(hive, view): {value_name: value}}
        self.opened = []

    def OpenKey(self, hive, key, reserved, access):
        view = access & (self.KEY_WOW64_64KEY | self.KEY_WOW64_32KEY)
        self.opened.append((hive, key, view))
        if (hive, view) not in self.values:
            raise OSError("not found")
        return (hive, view)

    def QueryValueEx(self, handle, name):
        data = self.values[handle]
        if name not in data:
            raise OSError("no value")
        return data[name], 1

    def CloseKey(self, handle):
        pass


def test_registry_app_path_is_read_from_every_hive_and_view(monkeypatch, tmp_path):
    per_user = tmp_path / "PerUser" / "Sorour Logistics"
    admin = tmp_path / "Admin" / "Sorour Logistics"
    fake = _FakeWinreg({
        ("HKCU", 0x100): {"Inno Setup: App Path": str(per_user)},
        ("HKLM", 0x200): {"InstallLocation": '"' + str(admin) + '"'},
    })
    monkeypatch.setitem(sys.modules, "winreg", fake)
    monkeypatch.setattr(sys, "platform", "win32")
    dirs = guard._registry_app_dirs()
    assert per_user in dirs
    assert admin in dirs
    assert {(h, v) for h, _k, v in fake.opened} == {("HKCU", 0x100), ("HKCU", 0x200), ("HKLM", 0x100), ("HKLM", 0x200)}
    assert all(k.endswith(guard.INSTALLER_APP_ID + "_is1") for _h, k, _v in fake.opened)


def test_installed_laptop_databases_are_live(monkeypatch, tmp_path):
    registry_dir = tmp_path / "Custom" / "Sorour Logistics"
    monkeypatch.setattr(guard, "_registry_app_dirs", lambda: [registry_dir])
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "LocalAppData"))
    monkeypatch.setenv("ProgramFiles", str(tmp_path / "PF"))
    monkeypatch.setenv("ProgramFiles(x86)", str(tmp_path / "PF86"))
    live = [
        registry_dir / "sorour_logistics.db",
        tmp_path / "LocalAppData" / "Programs" / "Sorour Logistics" / "sorour_logistics.db",
        tmp_path / "PF" / "Sorour Logistics" / "sorour_logistics.db",
        tmp_path / "PF86" / "Sorour Logistics" / "sorour_logistics.db",
    ]
    for db in live:
        make_operational_db(db)
        assert guard.is_live_db(db), db
        with pytest.raises(guard.UnsafeTargetError):
            guard.guard_programmatic_target(db)
    other = make_operational_db(tmp_path / "elsewhere" / "sorour_logistics.db")
    assert not guard.is_live_db(other)
    module = importlib.import_module("clean_and_isolate_databases")
    before = sha256(live[1])
    with pytest.raises(guard.UnsafeTargetError):
        module.clean_database(live[1])
    assert sha256(live[1]) == before


def test_uat_refuses_the_installed_laptop_db_as_target(monkeypatch, tmp_path):
    installed = make_operational_db(tmp_path / "LocalAppData" / "Programs" / "Sorour Logistics" / "sorour_logistics.db")
    monkeypatch.setattr(guard, "_registry_app_dirs", lambda: [])
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "LocalAppData"))
    uat = importlib.import_module("scripts.prepare_uat_environment")
    source = make_operational_db(tmp_path / "src.db")
    before = sha256(installed)
    assert uat.main(["--reset", "--source", str(source), "--db", str(installed), "--confirm"]) == guard.EXIT_REFUSED
    assert sha256(installed) == before


def test_in_use_is_rechecked_after_the_backup(tmp_path, monkeypatch):
    """The backend grabs the DB while the backup runs: refuse before the first write, keep the backup."""
    db = make_operational_db(tmp_path / "a.db")
    probes = iter([False, True])
    monkeypatch.setattr(guard, "is_db_in_use", lambda _p: next(probes))
    before = sha256(db)
    with pytest.raises(guard.UnsafeTargetError, match="was kept"):
        guard.guard_destructive_target(db, confirm=True, tag="race")
    assert sha256(db) == before
    assert len(list((tmp_path / "backups").glob("pre_migration_race_*.db"))) == 1


def test_script_refuses_when_backend_opens_the_db_during_backup(workspace, monkeypatch):
    module = load("clean_and_isolate_databases", workspace, monkeypatch)
    target = workspace["target"]
    real_probe = guard.is_db_in_use
    calls = {"n": 0}

    def probe(path):
        calls["n"] += 1
        return real_probe(path) if calls["n"] == 1 else True

    monkeypatch.setattr(guard, "is_db_in_use", probe)
    assert module.main(["--db", str(target), "--confirm"]) == guard.EXIT_REFUSED
    assert count_rows(target, "import_files") == 1
    assert calls["n"] == 2


def test_encrypted_restore_decrypts_into_a_private_temp_dir(restore_module, workspace, monkeypatch):
    from utils.crypto_utils import encrypt_backup_file

    synced = workspace["tmp"] / "GoogleDrive" / "SorourLogistics-Backups"
    plain = _backup_source(workspace["tmp"])
    enc = synced / "daily_backup_20260101_000000.db.enc"
    synced.mkdir(parents=True)
    encrypt_backup_file(plain, enc)

    seen = {}
    real_decrypt = restore_module.decrypt_backup_file

    def spy(src, dest, *args, **kwargs):
        seen["dest"] = Path(dest)
        return real_decrypt(src, dest, *args, **kwargs)

    monkeypatch.setattr(restore_module, "decrypt_backup_file", spy)
    new_target = workspace["tmp"] / "work" / "restored.db"
    assert restore_module.restore_database(enc, new_target) is True
    assert count_rows(new_target, "projects") == 2
    assert synced not in seen["dest"].parents
    assert not seen["dest"].parent.exists()  # temp folder removed
    assert sorted(p.name for p in synced.iterdir()) == [enc.name]


def test_encrypted_restore_cleans_the_temp_dir_on_failure(restore_module, workspace, monkeypatch):
    enc = workspace["tmp"] / "sync" / "x.db.enc"
    enc.parent.mkdir(parents=True)
    enc.write_bytes(b"not really encrypted")
    seen = {}

    def failing_decrypt(src, dest, *args, **kwargs):
        seen["dest"] = Path(dest)
        Path(dest).write_bytes(b"partial plaintext")
        raise ValueError("tampered")

    monkeypatch.setattr(restore_module, "decrypt_backup_file", failing_decrypt)
    assert restore_module.restore_database(enc, workspace["tmp"] / "work" / "r.db") is False
    assert not seen["dest"].exists() and not seen["dest"].parent.exists()
    assert sorted(p.name for p in enc.parent.iterdir()) == ["x.db.enc"]


def test_reset_seeds_only_the_admin(workspace, monkeypatch):
    module = load("reset_clean_production_db", workspace, monkeypatch)
    conn = sqlite3.connect(":memory:")
    conn.execute(
        "CREATE TABLE users (user_id INTEGER PRIMARY KEY, username TEXT, email TEXT, full_name TEXT, "
        "hashed_password TEXT, role TEXT, role_id INTEGER, is_active BOOLEAN, "
        "must_change_password BOOLEAN NOT NULL DEFAULT 0, created_at TEXT, updated_at TEXT)"
    )
    conn.execute("INSERT INTO users (user_id, username) VALUES (7, 'old_demo_user')")
    module.seed_core_users(conn.cursor(), "HASH-FROM-ENV")
    rows = conn.execute("SELECT user_id, username, role, hashed_password, must_change_password FROM users").fetchall()
    conn.close()
    assert rows == [(1, "admin", "ADMIN", "HASH-FROM-ENV", 1)]  # forced password change on first login
    source = (REPO_ROOT / "reset_clean_production_db.py").read_text(encoding="utf-8")
    assert "hash_password(DEFAULT_ADMIN_PASSWORD)" in source
    for fixed in ("manager123", "operator123", '"operator1"', '"operator2"'):
        assert fixed not in source
