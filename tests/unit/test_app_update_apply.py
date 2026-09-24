"""
POST /apply service flow (spec update-system-phase2-5 §B.3): re-verify, re-hash #1, R5 backup, promote, marker,
re-hash #2, detached launch, 202. Temp install dir + temp DB + FakeLauncher; nothing real is launched.
"""
import json
import subprocess
from datetime import datetime
from pathlib import Path

import pytest
from fastapi import HTTPException

import modules.app_update.service as update_service
from app_update_testkit import (
    NEW_INSTALLER,
    NEW_VERSION,
    OLD_VERSION,
    audit_actions,
    events,
    history,
    installer_name,
    make_env,
    payload,
    sha,
    sign,
)
from modules.app_update.repository import PENDING_FILE, UpdateFileRepository
from modules.app_update.validators import (
    DETAIL_DEV_MODE,
    DETAIL_HASH_MISMATCH,
    DETAIL_LAUNCH_FAILED,
    DETAIL_NOT_READY,
    DETAIL_UPDATE_BUSY,
    build_installer_command,
)
from utils.db_safety import check_integrity, clear_maintenance_mode, is_maintenance_mode, sha256_file


@pytest.fixture(autouse=True)
def _no_maintenance_leak():
    clear_maintenance_mode()
    yield
    clear_maintenance_mode()


@pytest.fixture
def env(tmp_path, monkeypatch):
    return make_env(tmp_path, monkeypatch)


def _backups(env):
    return sorted(p.name for p in env.backups_dir.glob("pre_update_*.db")) if env.backups_dir.exists() else []


# ─── happy path ──────────────────────────────────────────────────────────────

def test_apply_happy_path(env):
    service = env.ready_service()
    session = env.session_factory()
    try:
        result = service.apply(NEW_VERSION, actor="admin", db=session)
    finally:
        session.close()

    # 202 body
    assert result.state == "installing"
    assert result.backup_file.startswith("pre_update_v2.0.3_to_v2.1.0_") and result.backup_file.endswith(".db")
    assert isinstance(result.backup_created_at, datetime)
    assert service.get_status().state == "installing"
    assert is_maintenance_mode() is True  # stays on until Setup stops the process

    # the backup: integrity ok, sidecar sha matches
    backup = env.backups_dir / result.backup_file
    assert check_integrity(backup) == "ok"
    sidecar = json.loads((env.backups_dir / (result.backup_file + ".json")).read_text(encoding="utf-8"))
    assert sidecar["sha256"] == sha256_file(backup)
    assert sidecar["integrity"] == "ok"
    assert sidecar["from_version"] == OLD_VERSION and sidecar["to_version"] == NEW_VERSION
    assert sidecar["size_bytes"] == backup.stat().st_size

    # the exact command and cwd
    installers = env.data_dir / "installers"
    installer = installers / installer_name(NEW_VERSION)
    log = env.data_dir / "logs" / "install_2.1.0.log"
    assert len(env.launcher.calls) == 1
    command, cwd = env.launcher.calls[0]
    assert command == (
        f'"{installer}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1 '
        f'/DIR="{env.app_dir}" /LOG="{log}"'
    )
    assert '/DIR="' in command and "Sorour Logistics\"" in command
    assert cwd == installers
    assert log.parent.is_dir()  # Inno does not create the log folder
    assert installer.read_bytes() == NEW_INSTALLER
    assert not (env.data_dir / "staging" / installer_name(NEW_VERSION)).exists()

    # marker
    marker = json.loads((env.data_dir / PENDING_FILE).read_text(encoding="utf-8"))
    assert marker["schema"] == 1
    assert marker["kind"] == "update"
    assert marker["from_version"] == OLD_VERSION and marker["to_version"] == NEW_VERSION
    assert marker["app_dir"] == str(env.app_dir)
    assert marker["db_path"] == str(env.db_path)
    assert marker["backup_file"] == result.backup_file
    assert marker["backup_sha256"] == sidecar["sha256"]
    assert marker["backup_created_at"] == sidecar["created_at"]
    assert marker["installer_file"] == installer_name(NEW_VERSION)
    assert marker["installer_sha256"] == sha(NEW_INSTALLER)
    assert marker["install_log"] == str(log)
    assert marker["manifest_raw"] == (env.data_dir / "staging" / "staged_manifest.json").read_text(encoding="utf-8")
    assert marker["aside_file"] is None
    assert marker["actor"] == "admin"
    assert marker["started_at"]

    # history order: backup_ok (file name only) then install_launched
    entries = history(env.data_dir)
    names = [e["event"] for e in entries]
    assert names.index("backup_ok") < names.index("install_launched")
    backup_ok = next(e for e in entries if e["event"] == "backup_ok")
    assert backup_ok["detail"] == result.backup_file
    assert next(e for e in entries if e["event"] == "install_launched")["detail"] == "pid=4242"

    # audit row (written into the live DB through the request session)
    assert audit_actions(env.db_path) == [("UPDATE_APPLY", "admin", NEW_VERSION)]


def test_backup_name_gets_a_suffix_on_collision(env, monkeypatch):
    fixed = datetime(2026, 10, 1, 8, 15, 0).astimezone()
    service = env.ready_service(utcnow=lambda: fixed)
    stem = f"pre_update_v2.0.3_to_v2.1.0_{fixed.strftime('%Y%m%d_%H%M%S')}"
    env.backups_dir.mkdir(parents=True)
    (env.backups_dir / f"{stem}.db").write_bytes(b"older")
    result = service.apply(NEW_VERSION, actor="admin")
    assert result.backup_file == f"{stem}_1.db"


# ─── re-hash #1 / #2 ─────────────────────────────────────────────────────────

def test_rehash_1_mismatch_is_422_file_deleted_no_backup(env):
    service = env.ready_service()
    staged = env.data_dir / "staging" / installer_name(NEW_VERSION)
    staged.write_bytes(b"X" * len(NEW_INSTALLER))  # same size, other bytes

    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 422
    assert exc.value.detail == DETAIL_HASH_MISMATCH
    assert not staged.exists()
    assert _backups(env) == []
    assert env.launcher.calls == []
    status = service.get_status()
    assert (status.state, status.error_code) == ("failed", "hash_mismatch")
    assert "hash_mismatch" in events(env.data_dir)
    assert is_maintenance_mode() is False


def test_rehash_2_mismatch_is_422_marker_removed_backup_kept(env, monkeypatch):
    service = env.ready_service()
    staged = env.data_dir / "staging" / installer_name(NEW_VERSION)
    real_backup = update_service.sqlite_online_backup

    def backup_then_swap(src, dest, **kwargs):
        result = real_backup(src, dest, **kwargs)
        staged.write_bytes(b"Y" * len(NEW_INSTALLER))  # swapped during the backup window
        return result

    monkeypatch.setattr(update_service, "sqlite_online_backup", backup_then_swap)
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 422
    assert exc.value.detail == DETAIL_HASH_MISMATCH
    assert not (env.data_dir / PENDING_FILE).exists()
    assert not (env.data_dir / "installers" / installer_name(NEW_VERSION)).exists()
    assert len(_backups(env)) == 1  # the backup is kept
    assert env.launcher.calls == []
    assert is_maintenance_mode() is False
    assert service.get_status().error_code == "hash_mismatch"


# ─── state guards ────────────────────────────────────────────────────────────

def test_not_ready_is_409(env):
    service = env.service()
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 409
    assert exc.value.detail == DETAIL_NOT_READY
    assert env.launcher.calls == []


def test_version_mismatch_is_409(env):
    service = env.ready_service()
    with pytest.raises(HTTPException) as exc:
        service.apply("2.2.0", actor="admin")
    assert exc.value.status_code == 409
    assert exc.value.detail == DETAIL_NOT_READY
    assert _backups(env) == []


@pytest.mark.parametrize("busy", ["downloading", "verifying", "backing_up", "installing"])
def test_busy_is_409(env, busy):
    service = env.ready_service()
    service._state = busy
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 409
    assert exc.value.detail == DETAIL_UPDATE_BUSY
    assert env.launcher.calls == []


def test_dev_mode_is_400_and_launcher_not_called(env):
    env.stage(sign(env.key, payload()))
    service = env.service(apply_supported=False)
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 400
    assert exc.value.detail == DETAIL_DEV_MODE
    assert env.launcher.calls == []
    assert _backups(env) == []


def test_tampered_staged_manifest_is_409_not_ready(env):
    service = env.ready_service()
    manifest_file = env.data_dir / "staging" / "staged_manifest.json"
    manifest_file.write_text(manifest_file.read_text(encoding="utf-8").replace("2.1.0", "2.1.9"), encoding="utf-8")
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 409
    assert service.get_status().state == "failed"
    assert _backups(env) == []


def test_not_newer_than_installed_is_409(env):
    env.stage(sign(env.key, payload()))
    service = env.service(installed=OLD_VERSION)
    assert service.get_status().state == "ready"
    service._installed_version_provider = lambda: (NEW_VERSION, 210)  # installed meanwhile
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 409
    assert env.launcher.calls == []


# ─── launch failure ──────────────────────────────────────────────────────────

def test_launcher_raises_is_500_marker_removed_maintenance_cleared_backup_kept(env):
    env.launcher.raises = OSError("CreateProcess failed")
    service = env.ready_service()
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 500
    assert exc.value.detail == DETAIL_LAUNCH_FAILED
    assert not (env.data_dir / PENDING_FILE).exists()
    assert is_maintenance_mode() is False
    assert len(_backups(env)) == 1
    status = service.get_status()
    assert (status.state, status.error_code) == ("failed", "launch_failed")
    assert events(env.data_dir)[-1] == "launch_failed"


def test_path_with_a_quote_is_a_launch_failure(env):
    service = env.ready_service(app_dir_provider=lambda: Path('C:/evil"dir'))
    with pytest.raises(HTTPException) as exc:
        service.apply(NEW_VERSION, actor="admin")
    assert exc.value.status_code == 500
    assert env.launcher.calls == []
    assert not (env.data_dir / PENDING_FILE).exists()


# ─── recovery after restart ──────────────────────────────────────────────────

def test_recovery_new_instance_becomes_ready_and_applies(env):
    env.stage(sign(env.key, payload()))
    fresh = env.service()
    status = fresh.get_status()
    assert status.state == "ready"
    assert status.version == NEW_VERSION
    assert status.downloaded_bytes == status.total_bytes == len(NEW_INSTALLER)
    assert fresh.apply(NEW_VERSION, actor="admin").state == "installing"
    assert len(env.launcher.calls) == 1


def test_recovery_on_apply_without_a_prior_status_call(env):
    env.stage(sign(env.key, payload()))
    assert env.service().apply(NEW_VERSION, actor="admin").state == "installing"


@pytest.mark.parametrize("case", ["no_manifest", "tampered", "not_newer", "wrong_size", "dev_mode"])
def test_recovery_conditions(env, case):
    raw = sign(env.key, payload())
    staged = env.stage(raw)
    installed = OLD_VERSION
    apply_supported = True
    if case == "no_manifest":
        (env.data_dir / "staging" / "staged_manifest.json").unlink()
    elif case == "tampered":
        (env.data_dir / "staging" / "staged_manifest.json").write_bytes(raw.replace(b"2.1.0", b"2.1.1"))
    elif case == "not_newer":
        installed = NEW_VERSION
    elif case == "wrong_size":
        staged.write_bytes(NEW_INSTALLER[:-1])
    elif case == "dev_mode":
        apply_supported = False
    assert env.service(installed=installed, apply_supported=apply_supported).get_status().state == "idle"


# ─── installers/ pruning and the command builder ─────────────────────────────

def test_prune_installers_keeps_newest_three_and_ignores_other_files(tmp_path):
    repo = UpdateFileRepository(tmp_path / "updates")
    folder = repo.ensure_installers_dir()
    for version in ("2.0.3", "2.1.0", "2.0.10", "1.9.9", "2.2.0"):
        (folder / installer_name(version)).write_bytes(b"x")
    others = ["notes.txt", "Sorour_Logistics_Setup_v2.0.1.exe.part", "Other_Setup_v9.9.9.exe",
              "Sorour_Logistics_Setup_v2.0.exe", "sorour_logistics_setup_v0.0.1.EXE"]
    for name in others:
        (folder / name).write_bytes(b"keep")
    removed = repo.prune_installers(keep=3)
    kept = sorted(p.name for p in folder.iterdir())
    assert sorted(p.name for p in removed) == [installer_name("1.9.9"), installer_name("2.0.3")]
    assert kept == sorted(others + [installer_name(v) for v in ("2.0.10", "2.1.0", "2.2.0")])


def test_promote_prunes_to_three(env):
    folder = env.repo.ensure_installers_dir()
    for version in ("1.0.0", "1.1.0", "2.0.3"):
        (folder / installer_name(version)).write_bytes(b"x")
    service = env.ready_service()
    service.apply(NEW_VERSION, actor="admin")
    assert sorted(p.name for p in folder.glob("*.exe")) == sorted(
        installer_name(v) for v in ("1.1.0", "2.0.3", "2.1.0")
    )


def test_build_installer_command_exact_string():
    cmd = build_installer_command(
        Path(r"C:\Users\Hp\AppData\Local\SorourLogistics\updates\installers\Sorour_Logistics_Setup_v2.1.0.exe"),
        Path(r"C:\Users\Hp\AppData\Local\Programs\Sorour Logistics"),
        Path(r"C:\Users\Hp\AppData\Local\SorourLogistics\updates\logs\install_2.1.0.log"),
    )
    assert cmd == (
        r'"C:\Users\Hp\AppData\Local\SorourLogistics\updates\installers\Sorour_Logistics_Setup_v2.1.0.exe" '
        r'/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1 '
        r'/DIR="C:\Users\Hp\AppData\Local\Programs\Sorour Logistics" '
        r'/LOG="C:\Users\Hp\AppData\Local\SorourLogistics\updates\logs\install_2.1.0.log"'
    )


@pytest.mark.parametrize("which", [0, 1, 2])
def test_build_installer_command_rejects_a_double_quote(which):
    paths = [Path("C:/a/setup.exe"), Path("C:/app"), Path("C:/log.log")]
    paths[which] = Path('C:/x"y/z')
    with pytest.raises(ValueError):
        build_installer_command(*paths)


# ─── default launcher ────────────────────────────────────────────────────────

class _FakeProc:
    pid = 777


def test_default_launcher_is_detached_and_breaks_away(monkeypatch, tmp_path):
    calls = []

    def fake_popen(command, **kwargs):
        calls.append((command, kwargs))
        return _FakeProc()

    monkeypatch.setattr(update_service.subprocess, "Popen", fake_popen)
    assert update_service.launch_installer_detached('"C:/x.exe" /VERYSILENT', tmp_path) == 777
    command, kwargs = calls[0]
    assert command == '"C:/x.exe" /VERYSILENT'
    assert kwargs["cwd"] == str(tmp_path)
    assert kwargs["stdin"] is subprocess.DEVNULL and kwargs["stdout"] is subprocess.DEVNULL
    assert kwargs["stderr"] is subprocess.DEVNULL and kwargs["close_fds"] is True
    flags = kwargs["creationflags"]
    assert flags & 0x00000008 and flags & 0x00000200 and flags & 0x01000000


def test_default_launcher_retries_without_breakaway_on_access_denied(monkeypatch, tmp_path):
    flags_seen = []

    def fake_popen(command, **kwargs):
        flags_seen.append(kwargs["creationflags"])
        if len(flags_seen) == 1:
            error = OSError("access denied")
            error.winerror = 5
            raise error
        return _FakeProc()

    monkeypatch.setattr(update_service.subprocess, "Popen", fake_popen)
    assert update_service.launch_installer_detached("cmd", tmp_path) == 777
    assert flags_seen[0] & 0x01000000 and not flags_seen[1] & 0x01000000


def test_default_launcher_other_errors_propagate(monkeypatch, tmp_path):
    def fake_popen(command, **kwargs):
        raise FileNotFoundError("missing")

    monkeypatch.setattr(update_service.subprocess, "Popen", fake_popen)
    with pytest.raises(FileNotFoundError):
        update_service.launch_installer_detached("cmd", tmp_path)


# ─── /cancel cannot interrupt apply (review item 2) ──────────────────────────

def test_finished_download_releases_its_cancel_event(env):
    import httpx

    raw = sign(env.key, payload(previous=None))

    def handler(request):
        if request.url.path.endswith("/manifest.json"):
            return httpx.Response(200, content=raw)
        return httpx.Response(200, content=NEW_INSTALLER)

    service = env.service(transport=httpx.MockTransport(handler))
    assert service.start_download(NEW_VERSION, actor="admin").state == "ready"
    assert service._cancel_event is None


def test_cancel_during_apply_verifying_is_409_and_apply_completes(env, monkeypatch):
    from modules.app_update.validators import DETAIL_NO_DOWNLOAD_RUNNING

    service = env.ready_service()
    service._cancel_event = __import__("threading").Event()  # a stale event left by an old download
    seen = {}
    real = update_service._file_matches

    def cancel_while_verifying(path, size, digest):
        seen["state"] = service.get_status().state
        with pytest.raises(HTTPException) as exc:
            service.cancel(actor="admin")
        seen["cancel"] = (exc.value.status_code, exc.value.detail)
        return real(path, size, digest)

    monkeypatch.setattr(update_service, "_file_matches", cancel_while_verifying)
    assert service.apply(NEW_VERSION, actor="admin").state == "installing"
    assert seen == {"state": "verifying", "cancel": (409, DETAIL_NO_DOWNLOAD_RUNNING)}
    assert "download_cancelled" not in events(env.data_dir)


# ─── installer held with write/delete denied through the launch (review item 7) ─

@pytest.mark.skipif(__import__("os").name != "nt", reason="share modes are Windows-only")
def test_installer_cannot_be_modified_while_launching(env):
    service = env.ready_service()
    blocked = {}

    def try_to_tamper(command, cwd):
        target = env.data_dir / "installers" / installer_name(NEW_VERSION)
        try:
            with open(target, "r+b") as fh:
                fh.write(b"EVIL")
            blocked["write"] = False
        except PermissionError:
            blocked["write"] = True
        try:
            target.rename(target.with_suffix(".moved"))
            blocked["rename"] = False
        except PermissionError:
            blocked["rename"] = True

    env.launcher.hook = try_to_tamper
    service.apply(NEW_VERSION, actor="admin")
    assert blocked == {"write": True, "rename": True}
    installer = env.data_dir / "installers" / installer_name(NEW_VERSION)
    assert installer.read_bytes() == NEW_INSTALLER
    with open(installer, "r+b"):
        pass  # released after the launch


def test_hash_and_hold_rejects_mismatch_and_missing(tmp_path):
    target = tmp_path / "setup.exe"
    target.write_bytes(b"abc")
    assert update_service._hash_and_hold(target, 3, sha(b"abd")) is None
    assert update_service._hash_and_hold(target, 4, sha(b"abc")) is None
    assert update_service._hash_and_hold(tmp_path / "missing.exe", 3, sha(b"abc")) is None
    held = update_service._hash_and_hold(target, 3, sha(b"abc"))
    assert held is not None
    held.close()


@pytest.mark.skipif(__import__("os").name != "nt", reason="CreateProcess share-mode check is Windows-only")
def test_a_held_executable_can_still_be_started(tmp_path):
    """CreateProcess must be able to run the file while our share-deny-write handle is open."""
    import os
    import shutil
    import time

    exe = tmp_path / "harmless.exe"
    shutil.copyfile(os.path.join(os.environ["SystemRoot"], "System32", "cmd.exe"), exe)
    data = exe.read_bytes()
    held = update_service._hash_and_hold(exe, len(data), sha(data))
    assert held is not None
    try:
        pid = update_service.launch_installer_detached(f'"{exe}" /c exit 0', tmp_path)
        assert pid > 0
    finally:
        held.close()
    for _ in range(50):  # let the detached cmd.exe exit so tmp_path can be removed
        try:
            exe.unlink()
            break
        except PermissionError:
            time.sleep(0.1)


# ─── audit only after a successful launch (review item 8) ────────────────────

def test_launch_failure_is_audited_as_failed_only(env):
    env.launcher.raises = OSError("CreateProcess failed")
    service = env.ready_service()
    session = env.session_factory()
    try:
        with pytest.raises(HTTPException):
            service.apply(NEW_VERSION, actor="admin", db=session)
    finally:
        session.close()
    assert audit_actions(env.db_path) == [("UPDATE_APPLY_FAILED", "admin", NEW_VERSION)]


def test_audit_errors_never_change_the_outcome(env, monkeypatch):
    from modules.audit_logs.service import AuditLogService

    def broken(self, **kwargs):
        raise ValueError("audit table broken")

    monkeypatch.setattr(AuditLogService, "log_activity", broken)
    service = env.ready_service()
    session = env.session_factory()
    try:
        assert service.apply(NEW_VERSION, actor="admin", db=session).state == "installing"
    finally:
        session.close()


# ─── anchored regexes (review item 10) ───────────────────────────────────────

def test_regexes_do_not_accept_a_trailing_newline():
    from modules.app_update import validators as rules

    assert not rules.is_valid_version("2.1.0\n")
    assert rules.installer_sort_key(installer_name("2.1.0") + "\n") is None
    with pytest.raises(HTTPException):
        rules.validate_backup_filename("pre_update_v2.0.3_to_v2.1.0_20261001_101500.db\n",
                                       "pre_update_v2.0.3_to_v2.1.0_20261001_101500.db\n")
    with pytest.raises(rules.ManifestError):
        rules.validate_sha256("a" * 64 + "\n")
    with pytest.raises(rules.ManifestError):
        rules.validate_installer_path("releases/2.1.0/Setup.exe\n")
