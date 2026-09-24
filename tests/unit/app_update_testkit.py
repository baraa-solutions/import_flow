"""
Shared helpers for the Phase 5 app-update tests (apply / rollback / stage-local / post-update / pre-fetch).

Not collected by pytest (no test_ prefix). Everything lives under tmp_path: a temp install folder with a space in
its name ("Sorour Logistics"), a temp SQLite DB next to it, a temp update data dir, a test Ed25519 key and a
FakeLauncher. The real DB, the real update dir and the network are never touched.
"""
import base64
import hashlib
import json
import sqlite3
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, List, Optional, Tuple

import httpx
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool

import modules.app_update.service as update_service
from modules.app_update.repository import HISTORY_FILE, UpdateFileRepository
from modules.app_update.service import UpdateService
from modules.audit_logs.model import AuditLog
from utils.db_safety import sqlite_online_backup

KEY_ID = "ktest"
NEW_VERSION = "2.1.0"
OLD_VERSION = "2.0.3"
NEW_INSTALLER = b"MZ" + b"\x00new-installer-2.1.0" * 3000
OLD_INSTALLER = b"MZ" + b"\x00old-installer-2.0.3" * 2000
BACKUP_NAME = "pre_update_v2.0.3_to_v2.1.0_20261001_101500.db"


def installer_name(version: str) -> str:
    return f"Sorour_Logistics_Setup_v{version}.exe"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def install_test_key(monkeypatch) -> Ed25519PrivateKey:
    key = Ed25519PrivateKey.generate()
    public = base64.b64encode(key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)).decode()
    monkeypatch.setattr(update_service, "UPDATE_SIGNING_PUBLIC_KEYS", {KEY_ID: public})
    return key


def payload(
    version: str = NEW_VERSION,
    installer: bytes = NEW_INSTALLER,
    previous: Optional[Tuple[str, bytes]] = (OLD_VERSION, OLD_INSTALLER),
    expires_at: str = "2099-01-01T00:00:00Z",
    build: int = 210,
    size: Optional[int] = None,
    digest: Optional[str] = None,
) -> dict:
    data = {
        "schema": 1,
        "app": "sorour-logistics",
        "channel": "stable",
        "version": version,
        "build_number": build,
        "released_at": "2026-01-01T10:00:00Z",
        "expires_at": expires_at,
        "min_supported_version": "2.0.0",
        "mandatory": False,
        "release_notes": {"ar": ["جديد"], "en": ["New"]},
        "installer": {
            "path": f"releases/{version}/{installer_name(version)}",
            "size_bytes": len(installer) if size is None else size,
            "sha256": digest or sha(installer),
        },
    }
    if previous is not None:
        prev_version, prev_bytes = previous
        data["previous"] = {
            "version": prev_version,
            "installer": {
                "path": f"releases/{prev_version}/{installer_name(prev_version)}",
                "size_bytes": len(prev_bytes),
                "sha256": sha(prev_bytes),
            },
        }
    return data


def sign(key: Ed25519PrivateKey, data: dict) -> bytes:
    signed = json.dumps(data, separators=(",", ":"))
    signature = base64.b64encode(key.sign(signed.encode("utf-8"))).decode()
    return json.dumps({"key_id": KEY_ID, "signature": signature, "signed": signed}).encode()


class FakeLauncher:
    """Records (command, cwd); returns pid 4242; optionally raises or runs a hook first."""

    def __init__(self, raises: Optional[BaseException] = None, pid: int = 4242):
        self.calls: List[Tuple[str, Path]] = []
        self.raises = raises
        self.pid = pid
        self.hook: Optional[Callable[[str, Path], None]] = None

    def __call__(self, command: str, cwd: Path) -> int:
        self.calls.append((command, Path(cwd)))
        if self.hook:
            self.hook(command, cwd)
        if self.raises is not None:
            raise self.raises
        return self.pid


def create_live_db(path: Path, rows: int = 3) -> None:
    """A small WAL-mode SQLite DB with an `items` table and the audit_logs table."""
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    try:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL)")
        conn.executemany("INSERT INTO items (name) VALUES (?)", [(f"item-{i}",) for i in range(rows)])
        conn.commit()
    finally:
        conn.close()
    engine = create_engine(f"sqlite:///{path.as_posix()}", poolclass=NullPool)
    AuditLog.__table__.create(engine)
    engine.dispose()


def insert_items(path: Path, names: List[str]) -> None:
    conn = sqlite3.connect(str(path))
    try:
        conn.executemany("INSERT INTO items (name) VALUES (?)", [(n,) for n in names])
        conn.commit()
    finally:
        conn.close()


def item_names(path: Path) -> List[str]:
    conn = sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True)
    try:
        return [r[0] for r in conn.execute("SELECT name FROM items ORDER BY id")]
    finally:
        conn.close()


def audit_actions(path: Path) -> List[Tuple[str, str, str]]:
    conn = sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True)
    try:
        return [tuple(r) for r in conn.execute(
            "SELECT action, performed_by, entity_code FROM audit_logs WHERE entity_type='AppUpdate' ORDER BY log_id"
        )]
    finally:
        conn.close()


def db_bytes_sha(path: Path) -> str:
    """sha256 over the DB file and its -wal (what a reader would see)."""
    digest = hashlib.sha256(path.read_bytes())
    wal = Path(f"{path}-wal")
    if wal.exists():
        digest.update(wal.read_bytes())
    return digest.hexdigest()


def history(data_dir: Path) -> List[dict]:
    path = data_dir / HISTORY_FILE
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def events(data_dir: Path) -> List[str]:
    return [e["event"] for e in history(data_dir)]


@dataclass
class Env:
    tmp: Path
    key: Ed25519PrivateKey
    app_dir: Path
    db_path: Path
    data_dir: Path
    launcher: FakeLauncher = field(default_factory=FakeLauncher)
    free_bytes: int = 10 * 1024 ** 3
    disposed: int = 0

    @property
    def backups_dir(self) -> Path:
        return self.app_dir / "backups"

    @property
    def repo(self) -> UpdateFileRepository:
        return UpdateFileRepository(self.data_dir)

    def session_factory(self):
        engine = create_engine(f"sqlite:///{self.db_path.as_posix()}", poolclass=NullPool)
        return sessionmaker(bind=engine)()

    def dispose(self) -> None:
        self.disposed += 1

    def service(
        self,
        installed: Optional[str] = OLD_VERSION,
        apply_supported: bool = True,
        transport: Optional[httpx.BaseTransport] = None,
        **overrides,
    ) -> UpdateService:
        kwargs = dict(
            data_dir=self.data_dir,
            transport=transport or httpx.MockTransport(lambda request: httpx.Response(404)),
            installed_version_provider=(lambda: (installed, 205)) if installed else (lambda: None),
            apply_supported_provider=lambda: apply_supported,
            run_in_background=lambda fn: fn(),
            db_path=self.db_path,
            app_dir_provider=lambda: self.app_dir,
            launcher=self.launcher,
            dispose_engine=self.dispose,
            disk_free=lambda _path: self.free_bytes,
            session_factory=self.session_factory,
        )
        kwargs.update(overrides)
        return UpdateService(**kwargs)

    # ─── staging ──────────────────────────────────────────────────────────
    def stage(self, manifest_raw: bytes, installer: bytes = NEW_INSTALLER, version: str = NEW_VERSION) -> Path:
        """Put a verified-looking staged installer + staged_manifest.json on disk (what a finished download leaves)."""
        repo = self.repo
        repo.ensure_staging_dir()
        staged = repo.staged_file(installer_name(version))
        staged.write_bytes(installer)
        repo.save_staged_manifest(manifest_raw)
        return staged

    def ready_service(self, manifest_raw: Optional[bytes] = None, **kwargs) -> UpdateService:
        raw = manifest_raw or sign(self.key, payload())
        self.stage(raw)
        service = self.service(**kwargs)
        assert service.get_status().state == "ready"
        return service

    # ─── rollback scenario ───────────────────────────────────────────────
    def take_pre_update_backup(self, name: str = BACKUP_NAME) -> str:
        self.backups_dir.mkdir(parents=True, exist_ok=True)
        return sqlite_online_backup(self.db_path, self.backups_dir / name).sha256

    def keep_previous_installer(self, data: bytes = OLD_INSTALLER, version: str = OLD_VERSION) -> Path:
        repo = self.repo
        repo.ensure_installers_dir()
        target = repo.installer_path(installer_name(version))
        target.write_bytes(data)
        return target

    def write_last_update_result(
        self,
        manifest_raw: bytes,
        backup_sha: str,
        backup_file: str = BACKUP_NAME,
        result: str = "failed",
        code: Optional[str] = "migration_failed",
        **overrides,
    ) -> dict:
        record = {
            "schema": 1,
            "kind": "update",
            "from_version": OLD_VERSION,
            "to_version": NEW_VERSION,
            "app_dir": str(self.app_dir),
            "db_path": str(self.db_path),
            "backup_file": backup_file,
            "backup_sha256": backup_sha,
            "backup_created_at": "2026-10-01T08:15:00+00:00",
            "installer_file": installer_name(NEW_VERSION),
            "installer_sha256": sha(NEW_INSTALLER),
            "install_log": str(self.data_dir / "logs" / "install_2.1.0.log"),
            "manifest_raw": manifest_raw.decode("utf-8"),
            "aside_file": None,
            "started_at": "2026-10-01T08:15:01+00:00",
            "actor": "admin",
            "result": result,
            "code": code,
            "detail": None,
            "finished_at": "2026-10-01T08:17:00+00:00",
            "client_checked": False,
        }
        record.update(overrides)
        self.repo.save_last_result(record)
        return record

    def marker(self, **overrides) -> dict:
        record = {
            "schema": 1,
            "kind": "update",
            "from_version": OLD_VERSION,
            "to_version": NEW_VERSION,
            "app_dir": str(self.app_dir),
            "db_path": str(self.db_path),
            "backup_file": BACKUP_NAME,
            "backup_sha256": "a" * 64,
            "backup_created_at": "2026-10-01T08:15:00+00:00",
            "installer_file": installer_name(NEW_VERSION),
            "installer_sha256": sha(NEW_INSTALLER),
            "install_log": str(self.data_dir / "logs" / "install_2.1.0.log"),
            "manifest_raw": sign(self.key, payload()).decode("utf-8"),
            "aside_file": None,
            "started_at": "2026-10-01T08:15:01+00:00",
            "actor": "admin",
        }
        record.update(overrides)
        self.repo.save_pending(record)
        return record


def make_env(tmp_path: Path, monkeypatch, rows: int = 3) -> Env:
    key = install_test_key(monkeypatch)
    app_dir = tmp_path / "Programs" / "Sorour Logistics"
    db_path = app_dir / "sorour_logistics.db"
    create_live_db(db_path, rows=rows)
    data_dir = tmp_path / "updates"
    monkeypatch.setenv("UPDATE_DATA_DIR", str(tmp_path / "env-updates"))
    monkeypatch.delenv("UPDATE_BASE_URL", raising=False)
    return Env(tmp=tmp_path, key=key, app_dir=app_dir, db_path=db_path, data_dir=data_dir)
