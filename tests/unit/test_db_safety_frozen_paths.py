"""
DB safety (docs/plans/update-system-plan.md section 0), R11: in the frozen build every runtime path
(.env, version.json, DB, backups, backup encryption key) resolves next to the executable, never under
sys._MEIPASS. Generated secrets persist across restarts.

Frozen is simulated by patching sys.frozen / sys.executable (in-process) or by setting them before the
first import in a subprocess (module-level constants: settings, database, crypto_utils).
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

import database.schema_upgrade_service as sus
import modules.production_sync.service as sync_service
import utils.crypto_utils as crypto_utils
from utils import db_safety

REPO_ROOT = Path(__file__).resolve().parents[2]
SECRET_ENV_KEYS = (
    "SECRET_KEY", "ADMIN_INITIAL_PASSWORD", "BACKUP_ENCRYPTION_KEY", "DATABASE_PATH", "DATABASE_URL",
    "ALLOW_DEV_AUTH_BYPASS",
)
_ORIGINAL_BACKUP_KEY = os.environ.get("BACKUP_ENCRYPTION_KEY")


@pytest.fixture(autouse=True)
def _restore_secret_env():
    """get_backup_encryption_key() writes os.environ directly; put every secret env var back so nothing
    leaks into later tests (monkeypatch.delenv on an absent key records nothing to restore)."""
    saved = {k: os.environ.get(k) for k in SECRET_ENV_KEYS}
    yield
    for key, value in saved.items():
        if value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = value


@pytest.fixture
def frozen_app(tmp_path, monkeypatch):
    app_dir = tmp_path / "Sorour Logistics"
    meipass = tmp_path / "_MEI12345"
    app_dir.mkdir()
    meipass.mkdir()
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "executable", str(app_dir / "backend.exe"))
    monkeypatch.setattr(sys, "_MEIPASS", str(meipass), raising=False)
    return app_dir, meipass


def test_runtime_paths_resolve_under_exe_dir(frozen_app):
    app_dir, meipass = frozen_app
    assert db_safety.is_frozen_build() is True
    assert db_safety.app_base_dir() == app_dir.resolve()
    assert db_safety.env_file_path() == app_dir.resolve() / ".env"
    assert db_safety.version_file_path() == app_dir.resolve() / "version.json"
    assert db_safety.default_db_path() == app_dir.resolve() / "sorour_logistics.db"
    for p in (db_safety.env_file_path(), db_safety.version_file_path(), db_safety.default_db_path()):
        assert meipass.resolve() not in p.parents


def test_dev_paths_resolve_to_repo_root(monkeypatch):
    monkeypatch.delattr(sys, "frozen", raising=False)
    assert db_safety.app_base_dir() == REPO_ROOT


def test_backups_dir_is_next_to_db(tmp_path):
    assert db_safety.backups_dir_for(tmp_path / "x" / "sorour_logistics.db") == (tmp_path / "x" / "backups").resolve()


def test_schema_upgrade_reads_version_json_next_to_exe(frozen_app):
    app_dir, meipass = frozen_app
    (app_dir / "version.json").write_text(json.dumps({"version": "9.8.7"}), encoding="utf-8")
    (meipass / "version.json").write_text(json.dumps({"version": "0.0.1"}), encoding="utf-8")
    assert sus.SchemaUpgradeService._get_version_tag() == "9.8.7"


def test_production_sync_frozen_paths_use_the_live_db(frozen_app, monkeypatch):
    app_dir, _ = frozen_app
    live = app_dir / "sorour_logistics.db"
    monkeypatch.setattr(sync_service, "DB_PATH", str(live))
    root, standalone, dev_db, prod_db, backups = sync_service._resolve_paths()
    assert root == app_dir.resolve()
    assert dev_db == prod_db == live.resolve()
    assert backups == app_dir.resolve() / "backups"


def test_production_sync_dev_paths_honour_database_path(monkeypatch, tmp_path):
    monkeypatch.delattr(sys, "frozen", raising=False)
    live = tmp_path / "custom" / "my.db"
    monkeypatch.setattr(sync_service, "DB_PATH", str(live))
    _, _, dev_db, _, backups = sync_service._resolve_paths()
    assert dev_db == live.resolve()
    assert backups == (tmp_path / "custom" / "backups").resolve()


# ---------------------------------------------------------------- crypto key persistence (in-process)

def test_backup_key_is_persisted_and_reused(tmp_path, monkeypatch):
    env_file = tmp_path / ".env"
    monkeypatch.setattr(crypto_utils, "ENV_PATH", env_file)
    monkeypatch.delenv("BACKUP_ENCRYPTION_KEY", raising=False)
    first = crypto_utils.get_backup_encryption_key()
    assert "BACKUP_ENCRYPTION_KEY=" in env_file.read_text(encoding="utf-8")
    monkeypatch.delenv("BACKUP_ENCRYPTION_KEY", raising=False)  # simulate a new process
    second = crypto_utils.get_backup_encryption_key()
    assert first == second
    assert env_file.read_text(encoding="utf-8").count("BACKUP_ENCRYPTION_KEY=") == 1


def test_backup_key_refused_when_it_cannot_be_persisted(tmp_path, monkeypatch):
    not_a_file = tmp_path / "env_is_a_directory"
    not_a_file.mkdir()
    monkeypatch.setattr(crypto_utils, "ENV_PATH", not_a_file)
    monkeypatch.delenv("BACKUP_ENCRYPTION_KEY", raising=False)
    with pytest.raises(RuntimeError):
        crypto_utils.get_backup_encryption_key()
    assert "BACKUP_ENCRYPTION_KEY" not in os.environ


# ---------------------------------------------------------------- module constants in a fresh "frozen" process

def _frozen_subprocess(app_dir: Path, meipass: Path, body: str) -> dict:
    env = {k: v for k, v in os.environ.items() if k not in SECRET_ENV_KEYS}
    code = (
        "import sys, json\n"
        "sys.frozen = True\n"
        f"sys.executable = {str(app_dir / 'backend.exe')!r}\n"
        f"sys._MEIPASS = {str(meipass)!r}\n"
        + body
    )
    proc = subprocess.run(
        [sys.executable, "-c", code], cwd=str(REPO_ROOT), env=env,
        capture_output=True, text=True, timeout=300,
    )
    assert proc.returncode == 0, proc.stderr[-3000:]
    return json.loads(proc.stdout.strip().splitlines()[-1])


SETTINGS_BODY = (
    "import settings\n"
    "print(json.dumps({'env': str(settings.ENV_PATH), 'secret': settings.SECRET_KEY,"
    " 'prod': settings.IS_PRODUCTION_BUILD, 'db': settings.DATABASE_PATH}))\n"
)


def test_frozen_settings_env_lives_next_to_exe_and_secret_persists(tmp_path):
    app_dir, meipass = tmp_path / "app", tmp_path / "_MEI999"
    app_dir.mkdir()
    meipass.mkdir()
    first = _frozen_subprocess(app_dir, meipass, SETTINGS_BODY)
    second = _frozen_subprocess(app_dir, meipass, SETTINGS_BODY)

    assert Path(first["env"]) == (app_dir / ".env").resolve()
    assert first["prod"] is True
    assert Path(first["db"]) == (app_dir / "sorour_logistics.db").resolve()
    assert len(first["secret"]) >= 32
    assert first["secret"] == second["secret"]  # generated once, reused after "restart"
    env_text = (app_dir / ".env").read_text(encoding="utf-8")
    assert env_text.count("SECRET_KEY=") == 1
    assert "ALLOW_DEV_AUTH_BYPASS=false" in env_text
    assert list(meipass.iterdir()) == []


def test_frozen_settings_keeps_existing_env_values(tmp_path):
    app_dir, meipass = tmp_path / "app", tmp_path / "_MEI998"
    app_dir.mkdir()
    meipass.mkdir()
    existing = "k" * 40
    (app_dir / ".env").write_text(f"SECRET_KEY={existing}\nADMIN_INITIAL_PASSWORD=Xx-123456!\n", encoding="utf-8")
    result = _frozen_subprocess(app_dir, meipass, SETTINGS_BODY)
    assert result["secret"] == existing
    assert (app_dir / ".env").read_text(encoding="utf-8").count("SECRET_KEY=") == 1


def test_frozen_build_ignores_dev_auth_bypass_in_env(tmp_path):
    app_dir, meipass = tmp_path / "app", tmp_path / "_MEI995"
    app_dir.mkdir()
    meipass.mkdir()
    (app_dir / ".env").write_text("SECRET_KEY=" + "q" * 40 + "\nALLOW_DEV_AUTH_BYPASS=true\n", encoding="utf-8")
    body = (
        "import settings, modules.auth.permissions as p\n"
        "print(json.dumps({'s': settings.ALLOW_DEV_AUTH_BYPASS, 'p': p.ALLOW_DEV_AUTH_BYPASS}))\n"
    )
    result = _frozen_subprocess(app_dir, meipass, body)
    assert result == {"s": False, "p": False}


def test_backup_key_env_does_not_leak_between_tests():
    # Runs after the crypto tests above in file order; the autouse fixture must have restored it.
    assert os.environ.get("BACKUP_ENCRYPTION_KEY") == _ORIGINAL_BACKUP_KEY


def test_frozen_database_path_is_next_to_exe(tmp_path):
    app_dir, meipass = tmp_path / "app", tmp_path / "_MEI997"
    app_dir.mkdir()
    meipass.mkdir()
    body = (
        "from database import database as d\n"
        "print(json.dumps({'db': d.DB_PATH}))\n"
    )
    result = _frozen_subprocess(app_dir, meipass, body)
    assert Path(result["db"]) == (app_dir / "sorour_logistics.db").resolve()
    assert not (app_dir / "sorour_logistics.db").exists()  # importing never creates the DB


def test_frozen_crypto_key_lives_next_to_exe_and_persists(tmp_path):
    app_dir, meipass = tmp_path / "app", tmp_path / "_MEI996"
    app_dir.mkdir()
    meipass.mkdir()
    body = (
        "import utils.crypto_utils as c\n"
        "print(json.dumps({'env': str(c.ENV_PATH), 'key': c.get_backup_encryption_key().hex()}))\n"
    )
    first = _frozen_subprocess(app_dir, meipass, body)
    second = _frozen_subprocess(app_dir, meipass, body)
    assert Path(first["env"]) == (app_dir / ".env").resolve()
    assert first["key"] == second["key"]
    assert list(meipass.iterdir()) == []
