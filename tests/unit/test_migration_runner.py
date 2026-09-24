"""
Phase 2 startup migrations (docs/plans/update-system-phase2-5-spec.md A.2-A.7).

Every database here is a tmp_path file; the repo DB is never opened (test 12 checks its mtime).
"""
import hashlib
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models  # noqa: F401 - registers every model in Base.metadata
import database.schema_upgrade_service as sus
from database import migration_runner
from database.database import Base
from database.migration_runner import BASELINE_REVISION, DbState
from database.schema_upgrade_service import SchemaUpgradeService
from modules.currencies.model import Currency
from utils import db_safety
from utils.migration_linter import MigrationLinter

REPO_ROOT = Path(__file__).resolve().parents[2]
PREVIOUS_HEAD = "d3e4f5a6b7c8"


class _SpyMasterData:
    calls = 0

    def __init__(self, session):
        pass

    def sync_all(self):
        type(self).calls += 1
        return {"status": "stub"}


@pytest.fixture(autouse=True)
def _isolate(monkeypatch):
    db_safety.clear_maintenance_mode()
    _SpyMasterData.calls = 0
    monkeypatch.setattr(sus, "MasterDataSyncService", _SpyMasterData)
    monkeypatch.setattr(SchemaUpgradeService, "_get_version_tag", staticmethod(lambda: "9.9.9"))
    yield
    db_safety.clear_maintenance_mode()


# ---------------------------------------------------------------- helpers

def _engine(db_file: Path):
    return create_engine(f"sqlite:///{db_file.as_posix()}")


def _startup(db_file: Path):
    engine = _engine(db_file)
    try:
        return SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=engine, metadata=Base.metadata
        )
    finally:
        engine.dispose()


def _state(db_file: Path) -> DbState:
    engine = _engine(db_file)
    try:
        return migration_runner.inspect_db_state(engine).state
    finally:
        engine.dispose()


def _legacy_db(db_file: Path) -> Path:
    """A pre-Phase-2 DB: the full model schema with rows, no alembic_version table."""
    engine = _engine(db_file)
    try:
        Base.metadata.create_all(bind=engine)
        session = sessionmaker(bind=engine)()
        for code, name in (("EGP", "Egyptian Pound"), ("USD", "US Dollar"), ("EUR", "Euro")):
            session.add(Currency(currency_code=code, currency_name=name, currency_symbol=code))
        session.commit()
        session.close()
    finally:
        engine.dispose()
    conn = sqlite3.connect(db_file)
    conn.execute("CREATE TABLE legacy_notes (id INTEGER PRIMARY KEY, note TEXT)")
    conn.executemany("INSERT INTO legacy_notes (note) VALUES (?)", [("a",), ("b",)])
    conn.commit()
    conn.close()
    return db_file


def _set_revisions(db_file: Path, *revisions: str) -> None:
    conn = sqlite3.connect(db_file)
    conn.execute("CREATE TABLE IF NOT EXISTS alembic_version (version_num VARCHAR(32) NOT NULL)")
    conn.execute("DELETE FROM alembic_version")
    conn.executemany("INSERT INTO alembic_version (version_num) VALUES (?)", [(r,) for r in revisions])
    conn.commit()
    conn.close()


def _revisions(db_file: Path):
    conn = sqlite3.connect(db_file)
    try:
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if "alembic_version" not in tables:
            return None
        return [r[0] for r in conn.execute("SELECT version_num FROM alembic_version")]
    finally:
        conn.close()


def _row_counts(db_file: Path):
    conn = sqlite3.connect(db_file)
    try:
        tables = [
            r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
            if r[0] != "alembic_version"
        ]
        return {t: conn.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0] for t in tables}
    finally:
        conn.close()


def _schema_sql(db_file: Path):
    conn = sqlite3.connect(db_file)
    try:
        return sorted(
            (r[0], r[1] or "")
            for r in conn.execute("SELECT name, sql FROM sqlite_master WHERE tbl_name != 'alembic_version'")
        )
    finally:
        conn.close()


def _pre_migration_files(db_file: Path):
    return sorted((db_file.parent / "backups").glob("pre_migration_*.db"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


# ---------------------------------------------------------------- inspect_db_state

def test_inspect_db_state_classifies_every_state(tmp_path):
    fresh = tmp_path / "fresh.db"
    assert _state(fresh) == DbState.FRESH

    legacy = _legacy_db(tmp_path / "legacy.db")
    assert _state(legacy) == DbState.UNSTAMPED
    _set_revisions(legacy)  # table present but empty
    assert _state(legacy) == DbState.UNSTAMPED

    _set_revisions(legacy, BASELINE_REVISION)
    assert _state(legacy) == DbState.AT_HEAD
    _set_revisions(legacy, PREVIOUS_HEAD)
    assert _state(legacy) == DbState.BEHIND
    _set_revisions(legacy, "ffffffffffff")
    assert _state(legacy) == DbState.UNKNOWN
    _set_revisions(legacy, PREVIOUS_HEAD[:4])  # a prefix is not a known revision
    assert _state(legacy) == DbState.UNKNOWN
    _set_revisions(legacy, PREVIOUS_HEAD, BASELINE_REVISION)
    assert _state(legacy) == DbState.UNKNOWN


def test_inspect_db_state_raises_on_corrupt_db(tmp_path):
    db_file = tmp_path / "corrupt.db"
    db_file.write_bytes(b"SQLite format 3\x00" + b"\xff" * 8192)
    with pytest.raises(Exception):
        _state(db_file)


# ---------------------------------------------------------------- A.7 1-9

def test_1_fresh_db_is_stamped_without_backup(tmp_path):
    db_file = tmp_path / "sorour_logistics.db"
    res = _startup(db_file)
    assert res["status"] == "upgraded_successfully"
    assert res["migration"]["state"] == "fresh"
    assert res["migration"]["action"] == "stamped"
    assert res["migration"]["to_revision"] == BASELINE_REVISION
    assert _revisions(db_file) == [migration_runner.get_head_revision()]
    assert _pre_migration_files(db_file) == []


def test_2_legacy_unstamped_db_gets_verified_backup_then_stamp(tmp_path):
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")
    counts_before = _row_counts(db_file)
    assert counts_before["currencies"] == 3 and counts_before["legacy_notes"] == 2

    res = _startup(db_file)

    assert res["status"] == "upgraded_successfully"
    assert res["migration"] == {
        "state": "unstamped",
        "action": "stamped",
        "from_revision": None,
        "to_revision": BASELINE_REVISION,
        "backup_file": res["migration"]["backup_file"],
    }
    backups = _pre_migration_files(db_file)
    assert len(backups) == 1
    assert backups[0].name == res["migration"]["backup_file"]
    assert backups[0].name.startswith(f"pre_migration_unstamped_to_{BASELINE_REVISION}_")
    assert db_safety.check_integrity(backups[0]) == "ok"
    assert _row_counts(backups[0]) == counts_before
    assert _revisions(db_file) == [BASELINE_REVISION]
    assert _row_counts(db_file) == counts_before
    assert _SpyMasterData.calls == 1


def test_3_db_at_head_does_nothing(tmp_path, monkeypatch):
    db_file = tmp_path / "sorour_logistics.db"
    _startup(db_file)
    assert _state(db_file) == DbState.AT_HEAD

    def _no_upgrade(engine):
        raise AssertionError("upgrade_to_head must not run at head")

    def _no_backup(*args, **kwargs):
        raise AssertionError("no pre_migration backup at head")

    monkeypatch.setattr(migration_runner, "upgrade_to_head", _no_upgrade)
    monkeypatch.setattr(migration_runner, "take_pre_migration_backup", _no_backup)
    res = _startup(db_file)
    assert res["status"] == "upgraded_successfully"
    assert res["migration"]["action"] == "none"
    assert res["migration"]["state"] == "at_head"
    assert _pre_migration_files(db_file) == []


def test_4_behind_db_is_backed_up_and_upgraded_without_schema_change(tmp_path):
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")
    _set_revisions(db_file, PREVIOUS_HEAD)
    schema_before = _schema_sql(db_file)
    counts_before = _row_counts(db_file)

    res = _startup(db_file)

    assert res["status"] == "upgraded_successfully"
    assert res["migration"]["state"] == "behind"
    assert res["migration"]["action"] == "upgraded"
    assert res["migration"]["from_revision"] == PREVIOUS_HEAD
    assert res["migration"]["to_revision"] == BASELINE_REVISION
    backups = _pre_migration_files(db_file)
    assert [b.name for b in backups] == [res["migration"]["backup_file"]]
    assert backups[0].name.startswith(f"pre_migration_{PREVIOUS_HEAD}_to_{BASELINE_REVISION}_")
    assert _revisions(backups[0]) == [PREVIOUS_HEAD]
    assert _revisions(db_file) == [BASELINE_REVISION]
    assert _schema_sql(db_file) == schema_before
    assert _row_counts(db_file) == counts_before


def test_5_unknown_revision_r10_writes_nothing(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient

    import main  # import (and its own startup on the conftest DB) before this DB is inspected

    _SpyMasterData.calls = 0  # a first `import main` runs its own startup through the spy
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")
    _set_revisions(db_file, "ffffffffffff")
    sha_before = _sha256(db_file)
    snapshot_calls = []
    monkeypatch.setattr(sus, "sqlite_online_backup", lambda *a, **k: snapshot_calls.append(a))

    res = _startup(db_file)

    assert res["status"] == "maintenance_mode"
    assert "R10" in res["error"] and "ffffffffffff" in res["error"]
    assert res["migration"]["action"] == "refused"
    assert db_safety.is_maintenance_mode() is True
    assert _sha256(db_file) == sha_before
    assert not (tmp_path / "backups").exists()
    assert snapshot_calls == []
    assert _SpyMasterData.calls == 0

    client = TestClient(main.app)
    blocked = client.post("/api/v1/production-sync/backup?target=dev")
    assert blocked.status_code == 503
    assert blocked.json()["detail"] == db_safety.MAINTENANCE_DETAIL


def test_6_two_alembic_rows_is_unknown(tmp_path):
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")
    _set_revisions(db_file, PREVIOUS_HEAD, BASELINE_REVISION)
    sha_before = _sha256(db_file)
    res = _startup(db_file)
    assert res["status"] == "maintenance_mode"
    assert res["migration"]["state"] == "unknown"
    assert db_safety.is_maintenance_mode() is True
    assert _sha256(db_file) == sha_before


def test_7_pre_migration_backup_failure_blocks_the_stamp(tmp_path, monkeypatch):
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")

    def _broken_backup(src, dest, **kwargs):
        raise db_safety.BackupVerificationError("simulated integrity failure")

    monkeypatch.setattr(migration_runner, "sqlite_online_backup", _broken_backup)
    res = _startup(db_file)
    assert res["status"] == "maintenance_mode"
    assert "pre-migration backup failed" in res["error"]
    assert db_safety.is_maintenance_mode() is True
    assert _revisions(db_file) is None  # alembic_version not created
    assert _pre_migration_files(db_file) == []
    assert _SpyMasterData.calls == 0


def test_8_failed_upgrade_keeps_backup_and_never_restores(tmp_path, monkeypatch):
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")
    _set_revisions(db_file, PREVIOUS_HEAD)

    def _half_applied_upgrade(engine):
        conn = sqlite3.connect(db_file)
        conn.execute("INSERT INTO legacy_notes (note) VALUES ('written-by-failed-migration')")
        conn.commit()
        conn.close()
        raise RuntimeError("simulated migration failure")

    monkeypatch.setattr(migration_runner, "upgrade_to_head", _half_applied_upgrade)
    res = _startup(db_file)

    assert res["status"] == "maintenance_mode"
    assert "simulated migration failure" in res["error"]
    assert db_safety.is_maintenance_mode() is True
    backups = _pre_migration_files(db_file)
    assert len(backups) == 1 and backups[0].name in res["error"]
    assert _row_counts(backups[0])["legacy_notes"] == 2
    # No automatic restore: the live DB still carries the failed migration's write.
    assert _row_counts(db_file)["legacy_notes"] == 3
    assert _revisions(db_file) == [PREVIOUS_HEAD]
    assert _SpyMasterData.calls == 0


def test_9_second_startup_after_stamp_takes_no_new_backup(tmp_path):
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")
    first = _startup(db_file)
    assert first["migration"]["action"] == "stamped"
    backups_after_first = _pre_migration_files(db_file)
    assert len(backups_after_first) == 1

    second = _startup(db_file)
    assert second["status"] == "upgraded_successfully"
    assert second["migration"]["state"] == "at_head"
    assert second["migration"]["action"] == "none"
    assert second["migration"]["backup_file"] is None
    assert _pre_migration_files(db_file) == backups_after_first


# ---------------------------------------------------------------- A.7 10-13

def test_10_frozen_script_location_is_meipass(tmp_path, monkeypatch):
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "_MEIPASS", str(tmp_path), raising=False)
    assert migration_runner.alembic_script_location() == tmp_path / "alembic"


def test_source_script_location_is_repo_alembic():
    assert migration_runner.alembic_script_location() == REPO_ROOT / "alembic"
    cfg = migration_runner.build_alembic_config()
    assert cfg.config_file_name is None
    assert cfg.attributes["configure_logger"] is False


def test_11_single_head_is_the_baseline_and_linter_passes():
    from alembic.script import ScriptDirectory

    script = ScriptDirectory.from_config(migration_runner.build_alembic_config())
    assert script.get_heads() == [BASELINE_REVISION]
    assert migration_runner.get_head_revision() == BASELINE_REVISION
    assert script.get_revision(BASELINE_REVISION).down_revision == PREVIOUS_HEAD
    is_safe, issues = MigrationLinter.lint_directory(REPO_ROOT / "alembic" / "versions")
    assert is_safe, issues


def test_12_alembic_cli_honours_database_path(tmp_path):
    db_file = tmp_path / "cli.db"
    repo_db = REPO_ROOT / "sorour_logistics.db"
    repo_mtime = repo_db.stat().st_mtime_ns if repo_db.exists() else None
    env = {k: v for k, v in os.environ.items() if k != "DATABASE_URL"}
    env["DATABASE_PATH"] = str(db_file)
    env["SECRET_KEY"] = "subprocess-secret-key-0123456789abcdef-xyz"
    proc = subprocess.run(
        [sys.executable, "-m", "alembic", "-c", "alembic.ini", "stamp", "head"],
        cwd=str(REPO_ROOT), env=env, capture_output=True, text=True, timeout=600,
    )
    assert proc.returncode == 0, proc.stdout[-2000:] + proc.stderr[-2000:]
    assert _revisions(db_file) == [BASELINE_REVISION]
    if repo_mtime is not None:
        assert repo_db.stat().st_mtime_ns == repo_mtime


def test_13_pre_migration_backups_are_protected_from_pruning(tmp_path):
    assert db_safety.is_protected_backup("pre_migration_x.db") is True
    assert db_safety.PRE_MIGRATION_PREFIX in db_safety.PROTECTED_BACKUP_PREFIXES
    backups = tmp_path / "backups"
    backups.mkdir()
    protected = [
        backups / "pre_migration_unstamped_to_e1f2a3b4c5d6_20260101_000000.db",
        backups / "auto_pre_upgrade_v1.0.0_20200101_000000_pre_migration_hold.db",
    ]
    for p in protected:
        p.write_bytes(b"x")
    for i in range(12):
        (backups / f"auto_pre_upgrade_v1.0.{i}_2025010{i % 10}_00000{i % 10}_{i}.db").write_bytes(b"x")
    removed = SchemaUpgradeService._prune_snapshots(backups, max_auto_backups=1, keep_path=None)
    assert removed  # the pruner did run
    for p in protected:
        assert p.exists()
        assert p.name not in removed


# ---------------------------------------------------------------- review fixes

_REVISION_TEMPLATE = '''"""{rev}"""
from alembic import op
import sqlalchemy as sa

revision = "{rev}"
down_revision = {down!r}
branch_labels = None
depends_on = None


def upgrade() -> None:
{body}


def downgrade() -> None:
    pass
'''


def _temp_script_dir(tmp_path: Path, revisions) -> Path:
    """A throwaway Alembic script dir (the repo's env.py + the given revisions)."""
    root = tmp_path / "alembic"
    (root / "versions").mkdir(parents=True)
    (root / "env.py").write_bytes((REPO_ROOT / "alembic" / "env.py").read_bytes())
    down = None
    for rev, body in revisions:
        (root / "versions" / f"{rev}_test.py").write_text(
            _REVISION_TEMPLATE.format(rev=rev, down=down, body=body), encoding="utf-8"
        )
        down = rev
    return root


def test_failing_revision_leaves_db_at_last_successful_revision(tmp_path, monkeypatch):
    """transaction_per_migration: each revision commits with its alembic_version update."""
    script_dir = _temp_script_dir(tmp_path, [
        ("aaaa00000001", '    op.create_table("t1", sa.Column("id", sa.Integer, primary_key=True))'),
        ("aaaa00000002", '    op.create_table("t2", sa.Column("id", sa.Integer, primary_key=True))'),
        ("aaaa00000003", '    raise RuntimeError("simulated broken revision")'),
    ])
    monkeypatch.setattr(migration_runner, "alembic_script_location", lambda: script_dir)
    db_file = tmp_path / "chain.db"
    engine = _engine(db_file)
    try:
        with pytest.raises(RuntimeError, match="simulated broken revision"):
            migration_runner.upgrade_to_head(engine)
    finally:
        engine.dispose()
    assert _revisions(db_file) == ["aaaa00000002"]
    conn = sqlite3.connect(db_file)
    tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    conn.close()
    assert {"t1", "t2"} <= tables


def test_upgrade_through_a_chain_reaches_head(tmp_path, monkeypatch):
    script_dir = _temp_script_dir(tmp_path, [
        ("bbbb00000001", '    op.create_table("t1", sa.Column("id", sa.Integer, primary_key=True))'),
        ("bbbb00000002", '    op.create_table("t2", sa.Column("id", sa.Integer, primary_key=True))'),
    ])
    monkeypatch.setattr(migration_runner, "alembic_script_location", lambda: script_dir)
    db_file = tmp_path / "chain_ok.db"
    engine = _engine(db_file)
    try:
        assert migration_runner.upgrade_to_head(engine) == "bbbb00000002"
        assert migration_runner.stamp_head(engine) == "bbbb00000002"
    finally:
        engine.dispose()
    assert _revisions(db_file) == ["bbbb00000002"]


def test_engine_database_different_from_db_path_fails_before_any_write(tmp_path):
    db_path_file = _legacy_db(tmp_path / "declared.db")
    engine_file = _legacy_db(tmp_path / "actual.db")
    shas = (_sha256(db_path_file), _sha256(engine_file))
    engine = _engine(engine_file)
    try:
        res = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_path_file), target_engine=engine, metadata=Base.metadata
        )
    finally:
        engine.dispose()
    assert res["status"] == "maintenance_mode"
    assert "differs from DATABASE_PATH" in res["error"]
    assert db_safety.is_maintenance_mode() is True
    assert (_sha256(db_path_file), _sha256(engine_file)) == shas
    assert not (tmp_path / "backups").exists()
    assert _SpyMasterData.calls == 0


def test_uri_engine_on_the_same_file_is_accepted(tmp_path):
    db_file = _legacy_db(tmp_path / "same.db")
    engine = create_engine(f"sqlite:///file:{db_file.as_posix()}?mode=rwc&uri=true")
    try:
        assert migration_runner.sqlite_engine_file(engine) == Path(db_file.as_posix())
        res = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(db_file), target_engine=engine, metadata=Base.metadata
        )
    finally:
        engine.dispose()
    assert res["status"] == "upgraded_successfully"
    assert res["migration"]["action"] == "stamped"
    assert len(_pre_migration_files(db_file)) == 1


def test_in_memory_engine_never_backs_up_the_db_path_file(tmp_path):
    decoy = _legacy_db(tmp_path / "decoy.db")
    sha = _sha256(decoy)
    engine = create_engine("sqlite://")
    try:
        assert migration_runner.sqlite_engine_file(engine) is None
        res = SchemaUpgradeService.execute_safe_startup_upgrade(
            db_path=str(decoy), target_engine=engine, metadata=Base.metadata
        )
    finally:
        engine.dispose()
    assert res["status"] == "upgraded_successfully"
    assert res["backup_created"] is None
    assert res["migration"]["backup_file"] is None
    assert list((tmp_path / "backups").glob("*.db")) == []
    assert _sha256(decoy) == sha


def test_session_db_has_its_own_folder_so_backups_do_not_leak_into_temp():
    session_db = Path(os.environ["DATABASE_PATH"])
    assert session_db.parent.name.startswith("importflow_test_db_")
    assert db_safety.backups_dir_for(session_db) == (session_db.parent / "backups").resolve()
    # conftest stamps the session DB right after create_all, so `import main` takes no pre_migration backup.
    assert _revisions(session_db) == [BASELINE_REVISION]
    assert _pre_migration_files(session_db) == []


def test_session_engine_url_points_into_the_test_temp_dir():
    from database.database import DATABASE_URL, engine

    assert "DATABASE_URL" not in os.environ
    assert engine.dialect.name == "sqlite"
    engine_file = migration_runner.sqlite_engine_file(engine)
    assert engine_file is not None
    assert engine_file.resolve().parent.name.startswith("importflow_test_db_")
    assert engine_file.resolve() == Path(os.environ["DATABASE_PATH"]).resolve()
    assert "importflow_test_db_" in DATABASE_URL


def test_fresh_db_with_a_file_gets_no_auto_snapshot(tmp_path):
    db_file = tmp_path / "sorour_logistics.db"
    sqlite3.connect(db_file).execute("PRAGMA user_version = 1").connection.close()  # non-empty file, no tables
    assert db_file.stat().st_size > 0
    res = _startup(db_file)
    assert res["status"] == "upgraded_successfully"
    assert res["migration"]["state"] == "fresh"
    assert res["backup_created"] is None
    assert list((tmp_path / "backups").glob("*.db")) == []


def _fake_app_update_repository(monkeypatch, **attrs):
    import types

    fake = types.ModuleType("modules.app_update.repository")
    for name, value in attrs.items():
        setattr(fake, name, value)
    monkeypatch.setitem(sys.modules, "modules.app_update.repository", fake)


def test_rollback_hook_missing_is_ignored(monkeypatch, tmp_path):
    _fake_app_update_repository(monkeypatch)  # a build without the Phase 5 hook
    assert SchemaUpgradeService._rollback_pending_reason(tmp_path / "x.db") is None


def test_rollback_pending_reason_blocks_startup_before_any_write(tmp_path, monkeypatch):
    seen = []

    def _reason(db_path):
        seen.append(Path(db_path))
        return "rollback pending: restore failed"

    _fake_app_update_repository(monkeypatch, rollback_pending_reason=_reason)
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")
    sha = _sha256(db_file)
    res = _startup(db_file)
    assert seen == [db_file]
    assert res["status"] == "maintenance_mode"
    assert res["error"] == "rollback pending: restore failed"
    assert db_safety.maintenance_reason() == "rollback pending: restore failed"
    assert _sha256(db_file) == sha
    assert not (tmp_path / "backups").exists()
    assert _SpyMasterData.calls == 0


def test_rollback_hook_error_fails_closed(tmp_path, monkeypatch):
    def _boom(db_path):
        raise OSError("state file unreadable")

    _fake_app_update_repository(monkeypatch, rollback_pending_reason=_boom)
    db_file = _legacy_db(tmp_path / "sorour_logistics.db")
    res = _startup(db_file)
    assert res["status"] == "maintenance_mode"
    assert "rollback state unreadable" in res["error"]
    assert not (tmp_path / "backups").exists()


def test_rollback_hook_none_lets_startup_continue(tmp_path, monkeypatch):
    _fake_app_update_repository(monkeypatch, rollback_pending_reason=lambda db_path: None)
    res = _startup(tmp_path / "sorour_logistics.db")
    assert res["status"] == "upgraded_successfully"


def test_real_rollback_block_file_blocks_only_its_own_db(tmp_path, monkeypatch):
    """Integration with modules.app_update.repository: a rollback_blocked.json for this DB (and a version that
    is not installed) keeps the startup read-only; the same block for another DB does not."""
    from modules.app_update.repository import UpdateFileRepository

    data_dir = tmp_path / "updates"
    data_dir.mkdir()
    monkeypatch.setenv("UPDATE_DATA_DIR", str(data_dir))
    (tmp_path / "blocked").mkdir()
    db_file = _legacy_db(tmp_path / "blocked" / "sorour_logistics.db")
    block = {"db_path": str(db_file), "to_version": "0.0.1-never-installed", "reason": "test", "installer_path": "x.exe"}
    UpdateFileRepository(data_dir).save_rollback_block(block)
    sha = _sha256(db_file)

    res = _startup(db_file)
    assert res["status"] == "maintenance_mode"
    assert res["error"].startswith("rollback pending")
    assert _sha256(db_file) == sha
    db_safety.clear_maintenance_mode()

    other = tmp_path / "other.db"
    assert _startup(other)["status"] == "upgraded_successfully"


# ---------------------------------------------------------------- A.1 helpers

def test_quick_check_reports_ok_and_never_creates_files(tmp_path):
    db_file = _legacy_db(tmp_path / "q.db")
    assert db_safety.quick_check(db_file) == "ok"
    missing = tmp_path / "missing.db"
    with pytest.raises(FileNotFoundError):
        db_safety.quick_check(missing)
    assert not missing.exists()


def test_prefix_constants_rebuild_protected_prefixes():
    assert db_safety.PROTECTED_BACKUP_PREFIXES == (
        db_safety.PRE_INSTALL_PREFIX,
        db_safety.PRE_UPDATE_PREFIX,
        db_safety.PRE_MIGRATION_PREFIX,
        db_safety.PRE_RESTORE_PREFIX,
    )
    assert db_safety.PROTECTED_BACKUP_PREFIXES == ("pre_install_", "pre_update_", "pre_migration_", "pre_restore_")
