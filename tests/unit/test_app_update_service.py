"""
UpdateService check / download / cancel / history (plan §4.5 steps 1-3, §4.6, §4.8, §11).
Network is httpx.MockTransport, files live in tmp_path; the real DB and network are never touched.
"""
import base64
import hashlib
import json
import threading

import httpx
import pytest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from fastapi import HTTPException

import modules.app_update.service as update_service
from modules.app_update.repository import HISTORY_FILE, LAST_MANIFEST_FILE, UpdateFileRepository
from modules.app_update.service import UpdateService
from modules.app_update.validators import (
    DETAIL_DEV_MODE,
    DETAIL_DOWNLOAD_IN_PROGRESS,
    DETAIL_HASH_MISMATCH,
    DETAIL_NO_DOWNLOAD_RUNNING,
    DETAIL_NO_UPDATE_FOR_VERSION,
    DETAIL_SERVER_UNREACHABLE,
)

KEY_ID = "ktest"
INSTALLER_BYTES = b"MZ" + b"\x00installer-body" * 5000
INSTALLER_PATH = "releases/2.1.0/Sorour_Logistics_Setup_v2.1.0.exe"
INSTALLER_NAME = "Sorour_Logistics_Setup_v2.1.0.exe"
BASE = "https://kamal-sroor.online/importflow/updates/"


def _sign(private_key, payload: dict) -> bytes:
    signed = json.dumps(payload, separators=(",", ":"))
    signature = base64.b64encode(private_key.sign(signed.encode("utf-8"))).decode()
    return json.dumps({"key_id": KEY_ID, "signature": signature, "signed": signed}).encode()


def _payload(version="2.1.0", size=None, sha=None, build=210, expires_at="2099-01-01T00:00:00Z",
             released_at="2026-01-01T10:00:00Z") -> dict:
    return {
        "schema": 1,
        "app": "sorour-logistics",
        "channel": "stable",
        "version": version,
        "build_number": build,
        "released_at": released_at,
        "expires_at": expires_at,
        "min_supported_version": "2.0.0",
        "mandatory": False,
        "release_notes": {"ar": ["جديد"], "en": ["New"]},
        "installer": {
            "path": f"releases/{version}/Sorour_Logistics_Setup_v{version}.exe",
            "size_bytes": len(INSTALLER_BYTES) if size is None else size,
            "sha256": sha or hashlib.sha256(INSTALLER_BYTES).hexdigest(),
        },
    }


class FakeServer:
    """Mock update host. Records every request; behaviour switches per test."""

    def __init__(self, manifest: bytes):
        self.manifest = manifest
        self.installer = INSTALLER_BYTES
        self.manifest_status = 200
        self.installer_status = 200
        self.offline = False
        self.requests = []

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        if self.offline:
            raise httpx.ConnectError("no route to host", request=request)
        path = request.url.path
        if path == "/importflow/updates/manifest.json":
            if self.manifest_status == 302:
                return httpx.Response(302, headers={"Location": "https://evil.example/manifest.json"})
            return httpx.Response(self.manifest_status, content=self.manifest)
        if path == "/importflow/updates/" + INSTALLER_PATH:
            return httpx.Response(self.installer_status, content=self.installer)
        return httpx.Response(404)

    def paths(self):
        return [r.url.path for r in self.requests]


@pytest.fixture(autouse=True)
def _env(tmp_path, monkeypatch):
    monkeypatch.setenv("UPDATE_DATA_DIR", str(tmp_path / "env-updates"))
    monkeypatch.delenv("UPDATE_BASE_URL", raising=False)


@pytest.fixture
def signing_key(monkeypatch):
    key = Ed25519PrivateKey.generate()
    public = base64.b64encode(key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)).decode()
    monkeypatch.setattr(update_service, "UPDATE_SIGNING_PUBLIC_KEYS", {KEY_ID: public})
    return key


@pytest.fixture
def server(signing_key):
    return FakeServer(_sign(signing_key, _payload()))


@pytest.fixture
def data_dir(tmp_path):
    return tmp_path / "updates"


class FakeClock:
    """Monotonic clock for the force-throttle; starts far from 0 so the first check is never throttled."""

    def __init__(self):
        self.now = 10_000.0

    def __call__(self) -> float:
        return self.now


def _service(server, data_dir, *, apply_supported=True, installed="2.0.3", background=None, clock=None, utcnow=None):
    return UpdateService(
        data_dir=data_dir,
        transport=httpx.MockTransport(server.handler),
        installed_version_provider=lambda: (installed, 205),
        apply_supported_provider=lambda: apply_supported,
        run_in_background=background or (lambda fn: fn()),
        monotonic=clock or FakeClock(),
        utcnow=utcnow,
    )


def _history(data_dir):
    path = data_dir / HISTORY_FILE
    if not path.exists():
        return []
    return [json.loads(line)["event"] for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


# ─── check ───────────────────────────────────────────────────────────────────

def test_check_update_available_persists_manifest(server, data_dir):
    result = _service(server, data_dir).check()
    assert result.check_status == "update_available"
    assert result.current_version == "2.0.3"
    assert result.current_build == 205
    assert result.apply_supported is True
    assert result.last_checked_at is not None
    assert (data_dir / LAST_MANIFEST_FILE).is_file()
    assert _history(data_dir) == ["check_ok"]
    request = server.requests[0]
    assert str(request.url).startswith(BASE + "manifest.json?t=")


def test_check_offline(server, data_dir):
    server.offline = True
    result = _service(server, data_dir).check()
    assert result.check_status == "offline"
    assert result.update_available is False
    assert result.last_checked_at is None
    assert _history(data_dir) == ["check_failed"]


@pytest.mark.parametrize("status_code", [404, 500, 503])
def test_check_http_error_is_offline(server, data_dir, status_code):
    server.manifest_status = status_code
    assert _service(server, data_dir).check().check_status == "offline"


def test_check_does_not_follow_redirects(server, data_dir):
    server.manifest_status = 302
    result = _service(server, data_dir).check()
    assert result.check_status == "offline"
    assert all(r.url.host == "kamal-sroor.online" for r in server.requests)
    assert len(server.requests) == 1


def test_check_offline_keeps_last_successful_timestamp(server, data_dir):
    clock = FakeClock()
    service = _service(server, data_dir, clock=clock)
    first = service.check()
    server.offline = True
    clock.now += 61
    second = service.check(force=True)
    assert second.check_status == "offline"
    assert second.update_available is False
    assert second.last_checked_at == first.last_checked_at


def test_check_invalid_signature(signing_key, data_dir):
    server = FakeServer(_sign(Ed25519PrivateKey.generate(), _payload()))
    result = _service(server, data_dir).check()
    assert result.check_status == "invalid_signature"
    assert result.update_available is False
    assert not (data_dir / LAST_MANIFEST_FILE).exists()


def test_check_oversized_manifest_rejected(signing_key, data_dir):
    server = FakeServer(b"{" + b" " * (70 * 1024) + b"}")
    assert _service(server, data_dir).check().check_status == "invalid_signature"


def test_check_disabled_with_placeholder_key_does_not_hit_network(data_dir):
    server = FakeServer(b"{}")
    result = _service(server, data_dir).check()
    assert result.check_status == "disabled"
    assert server.requests == []


def test_check_disabled_with_rejected_base_url_override(server, data_dir, monkeypatch):
    monkeypatch.setenv("UPDATE_BASE_URL", "https://evil.example/updates/")
    result = _service(server, data_dir).check()
    assert result.check_status == "disabled"
    assert server.requests == []


def test_check_uses_allow_listed_base_url_override(server, data_dir, monkeypatch):
    monkeypatch.setenv("UPDATE_BASE_URL", "https://kamal-sroor.online/importflow/updates-staging/")
    server.offline = True
    _service(server, data_dir).check()
    assert server.requests[0].url.path == "/importflow/updates-staging/manifest.json"


def test_check_is_cached_for_one_hour_and_force_refetches(server, data_dir):
    clock = FakeClock()
    service = _service(server, data_dir, clock=clock)
    service.check()
    service.check()
    assert len(server.requests) == 1
    clock.now += 61
    service.check(force=True)
    assert len(server.requests) == 2


def test_force_is_throttled_to_once_per_minute(server, data_dir):
    clock = FakeClock()
    service = _service(server, data_dir, clock=clock)
    service.check(force=True)
    for _ in range(5):
        clock.now += 10
        assert service.check(force=True).check_status == "update_available"  # served from cache
    assert len(server.requests) == 1
    clock.now += 11  # 61 s after the first network check
    service.check(force=True)
    assert len(server.requests) == 2


def test_failed_check_is_not_retried_within_a_minute(server, data_dir):
    clock = FakeClock()
    server.offline = True
    service = _service(server, data_dir, clock=clock)
    assert service.check().check_status == "offline"
    clock.now += 30
    assert service.check(force=True).check_status == "offline"
    assert service.check().check_status == "offline"
    assert len(server.requests) == 1
    server.offline = False
    clock.now += 31
    assert service.check().check_status == "update_available"
    assert len(server.requests) == 2


# ─── anti-replay / expiry ────────────────────────────────────────────────────

def test_highest_seen_is_persisted(server, data_dir):
    _service(server, data_dir).check()
    assert UpdateFileRepository(data_dir).load_highest_seen() == ("2.1.0", 210)


def test_older_manifest_after_newer_is_refused_as_replay(signing_key, server, data_dir):
    clock = FakeClock()
    service = _service(server, data_dir, clock=clock)
    assert service.check().latest_version == "2.1.0"

    server.manifest = _sign(signing_key, _payload(version="2.0.9", build=209))  # replayed older, validly signed
    clock.now += 61
    result = service.check(force=True)
    assert result.check_status == "offline"
    assert result.update_available is False
    assert UpdateFileRepository(data_dir).load_highest_seen() == ("2.1.0", 210)
    history = (data_dir / HISTORY_FILE).read_text(encoding="utf-8")
    assert "replay" in history


def test_replay_is_refused_after_restart(signing_key, server, data_dir):
    _service(server, data_dir).check()
    server.manifest = _sign(signing_key, _payload(version="2.0.9", build=209))
    (data_dir / LAST_MANIFEST_FILE).unlink()
    assert _service(server, data_dir).check().check_status == "offline"


def test_same_version_lower_build_is_replay(signing_key, server, data_dir):
    clock = FakeClock()
    service = _service(server, data_dir, clock=clock)
    service.check()
    server.manifest = _sign(signing_key, _payload(build=200))
    clock.now += 61
    assert service.check(force=True).check_status == "offline"


def test_newer_manifest_raises_highest_seen(signing_key, server, data_dir):
    clock = FakeClock()
    service = _service(server, data_dir, clock=clock)
    service.check()
    server.manifest = _sign(signing_key, _payload(version="2.2.0", build=220))
    clock.now += 61
    assert service.check(force=True).latest_version == "2.2.0"
    assert UpdateFileRepository(data_dir).load_highest_seen() == ("2.2.0", 220)


def test_highest_seen_never_decreases(data_dir):
    repo = UpdateFileRepository(data_dir)
    repo.save_highest_seen("2.1.0", 210)
    repo.save_highest_seen("2.0.9", 999)
    assert repo.load_highest_seen() == ("2.1.0", 210)


def test_download_of_replayed_manifest_is_409(signing_key, server, data_dir):
    UpdateFileRepository(data_dir).save_highest_seen("2.2.0", 220)
    with pytest.raises(HTTPException) as exc:
        _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert exc.value.status_code == 409


def test_expired_manifest_is_offline(signing_key, data_dir):
    server = FakeServer(_sign(signing_key, _payload(expires_at="2026-02-01T00:00:00Z")))
    result = _service(server, data_dir).check()
    assert result.check_status == "offline"
    assert result.update_available is False
    assert not (data_dir / LAST_MANIFEST_FILE).exists()
    assert "expired" in (data_dir / HISTORY_FILE).read_text(encoding="utf-8")


def test_cached_manifest_that_expires_is_offline(signing_key, data_dir):
    from datetime import datetime, timedelta, timezone

    expires = datetime.now(timezone.utc) + timedelta(minutes=30)
    server = FakeServer(_sign(signing_key, _payload(expires_at=expires.isoformat())))
    now = {"t": datetime.now(timezone.utc)}
    service = _service(server, data_dir, utcnow=lambda: now["t"])
    assert service.check().check_status == "update_available"
    now["t"] = expires + timedelta(seconds=1)  # still inside the 1 h cache window
    assert service.check().check_status == "offline"


def test_download_of_expired_manifest_is_409(signing_key, data_dir):
    server = FakeServer(_sign(signing_key, _payload(expires_at="2026-02-01T00:00:00Z")))
    with pytest.raises(HTTPException) as exc:
        _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert exc.value.status_code == 409


def test_download_blocked_when_installed_version_unknown(server, data_dir):
    service = UpdateService(
        data_dir=data_dir,
        transport=httpx.MockTransport(server.handler),
        installed_version_provider=lambda: None,
        apply_supported_provider=lambda: True,
        run_in_background=lambda fn: fn(),
    )
    with pytest.raises(HTTPException) as exc:
        service.start_download("2.1.0", actor="admin")
    assert exc.value.status_code == 409


def test_history_is_capped(data_dir):
    from modules.app_update.repository import HISTORY_MAX_LINES

    repo = UpdateFileRepository(data_dir)
    for i in range(HISTORY_MAX_LINES + 25):
        repo.append_history(f"event_{i}", None, None)
    lines = (data_dir / HISTORY_FILE).read_text(encoding="utf-8").splitlines()
    assert len(lines) == HISTORY_MAX_LINES
    assert json.loads(lines[-1])["event"] == f"event_{HISTORY_MAX_LINES + 24}"
    assert json.loads(lines[0])["event"] == "event_25"


def test_history_detail_is_truncated(data_dir):
    repo = UpdateFileRepository(data_dir)
    repo.append_history("x", None, "d" * 5000)
    entry = json.loads((data_dir / HISTORY_FILE).read_text(encoding="utf-8"))
    assert len(entry["detail"]) == 500


def test_disk_cache_is_reverified_on_load(server, data_dir):
    _service(server, data_dir).check()
    cache_file = data_dir / LAST_MANIFEST_FILE
    stored = json.loads(cache_file.read_text(encoding="utf-8"))
    stored["raw"] = stored["raw"].replace("2.1.0", "9.9.9")
    cache_file.write_text(json.dumps(stored), encoding="utf-8")

    server.offline = True
    fresh = _service(server, data_dir)
    result = fresh.check()
    assert result.check_status == "offline"
    assert result.last_checked_at is None  # tampered cache ignored


def test_disk_cache_used_after_restart(server, data_dir):
    _service(server, data_dir).check()
    server.requests.clear()
    result = _service(server, data_dir).check()
    assert result.check_status == "update_available"
    assert server.requests == []


def test_check_reports_apply_not_supported_in_dev(server, data_dir):
    result = _service(server, data_dir, apply_supported=False).check()
    assert result.check_status == "update_available"
    assert result.apply_supported is False


# ─── download ────────────────────────────────────────────────────────────────

def test_download_hash_match_is_ready(server, data_dir):
    service = _service(server, data_dir)
    service.check()
    status = service.start_download("2.1.0", actor="admin")
    assert status.state == "ready"
    assert status.version == "2.1.0"
    assert status.downloaded_bytes == status.total_bytes == len(INSTALLER_BYTES)
    staged = data_dir / "staging" / INSTALLER_NAME
    assert staged.read_bytes() == INSTALLER_BYTES
    assert not (data_dir / "staging" / (INSTALLER_NAME + ".part")).exists()
    assert _history(data_dir)[-2:] == ["download_started", "download_verified"]
    assert server.paths()[-1] == "/importflow/updates/" + INSTALLER_PATH


def test_download_without_prior_check_fetches_manifest(server, data_dir):
    status = _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert status.state == "ready"
    assert server.paths()[0] == "/importflow/updates/manifest.json"


def test_download_again_when_ready_is_idempotent(server, data_dir):
    service = _service(server, data_dir)
    service.start_download("2.1.0", actor="admin")
    count = len(server.requests)
    assert service.start_download("2.1.0", actor="admin").state == "ready"
    assert len(server.requests) == count


def test_download_hash_mismatch_deletes_file(server, data_dir):
    server.installer = b"X" * len(INSTALLER_BYTES)  # same size, wrong content
    service = _service(server, data_dir)
    status = service.start_download("2.1.0", actor="admin")
    assert status.state == "failed"
    assert status.error_code == "hash_mismatch"
    assert status.error_detail == DETAIL_HASH_MISMATCH
    assert list((data_dir / "staging").iterdir()) == []
    assert "hash_mismatch" in _history(data_dir)


def test_download_short_body_is_hash_mismatch(server, data_dir):
    server.installer = INSTALLER_BYTES[:-10]
    status = _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert status.error_code == "hash_mismatch"
    assert list((data_dir / "staging").iterdir()) == []


def test_download_oversize_aborts(server, data_dir):
    server.installer = INSTALLER_BYTES + b"extra-bytes" * 20000
    status = _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert status.state == "failed"
    assert status.error_code == "size_exceeded"
    assert status.downloaded_bytes <= len(INSTALLER_BYTES)
    assert list((data_dir / "staging").iterdir()) == []


def test_download_http_error_fails_cleanly(server, data_dir):
    server.installer_status = 500
    status = _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert status.state == "failed"
    assert status.error_code == "download_failed"
    assert list((data_dir / "staging").iterdir()) == []


def test_download_after_failure_can_retry(server, data_dir):
    server.installer_status = 500
    service = _service(server, data_dir)
    assert service.start_download("2.1.0", actor="admin").state == "failed"
    server.installer_status = 200
    assert service.start_download("2.1.0", actor="admin").state == "ready"


def test_download_blocked_in_dev_mode(server, data_dir):
    with pytest.raises(HTTPException) as exc:
        _service(server, data_dir, apply_supported=False).start_download("2.1.0", actor="admin")
    assert exc.value.status_code == 400
    assert exc.value.detail == DETAIL_DEV_MODE
    assert server.requests == []


def test_download_other_version_is_409(server, data_dir):
    service = _service(server, data_dir)
    service.check()
    with pytest.raises(HTTPException) as exc:
        service.start_download("2.2.0", actor="admin")
    assert exc.value.status_code == 409
    assert exc.value.detail == DETAIL_NO_UPDATE_FOR_VERSION


def test_download_not_newer_than_installed_is_409(server, data_dir):
    with pytest.raises(HTTPException) as exc:
        _service(server, data_dir, installed="2.1.0").start_download("2.1.0", actor="admin")
    assert exc.value.status_code == 409


def test_download_server_unreachable_is_503(server, data_dir):
    server.offline = True
    with pytest.raises(HTTPException) as exc:
        _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert exc.value.status_code == 503
    assert exc.value.detail == DETAIL_SERVER_UNREACHABLE


def test_download_while_downloading_is_409(server, data_dir):
    pending = []
    service = _service(server, data_dir, background=pending.append)
    assert service.start_download("2.1.0", actor="admin").state == "downloading"
    with pytest.raises(HTTPException) as exc:
        service.start_download("2.1.0", actor="admin")
    assert exc.value.status_code == 409
    assert exc.value.detail == DETAIL_DOWNLOAD_IN_PROGRESS


def test_download_runs_in_a_background_thread_by_default(server, data_dir):
    service = UpdateService(
        data_dir=data_dir,
        transport=httpx.MockTransport(server.handler),
        installed_version_provider=lambda: ("2.0.3", 205),
        apply_supported_provider=lambda: True,
    )
    assert service.start_download("2.1.0", actor="admin").state in {"downloading", "verifying", "ready"}
    for thread in threading.enumerate():
        if thread.name == "app-update-download":
            thread.join(timeout=10)
    assert service.get_status().state == "ready"


# ─── cancel ──────────────────────────────────────────────────────────────────

def test_cancel_without_download_is_409(server, data_dir):
    with pytest.raises(HTTPException) as exc:
        _service(server, data_dir).cancel(actor="admin")
    assert exc.value.status_code == 409
    assert exc.value.detail == DETAIL_NO_DOWNLOAD_RUNNING


def test_cancel_stops_download_and_removes_part(server, data_dir):
    pending = []
    service = _service(server, data_dir, background=pending.append)
    service.start_download("2.1.0", actor="admin")
    status = service.cancel(actor="admin")
    assert status.state == "idle"
    assert status.version is None
    pending[0]()  # the worker starts after cancel: it must not resurrect the job
    assert service.get_status().state == "idle"
    staging = data_dir / "staging"
    assert not staging.exists() or list(staging.iterdir()) == []
    assert "download_cancelled" in _history(data_dir)


# ─── status / history ────────────────────────────────────

def test_status_starts_idle(server, data_dir):
    status = _service(server, data_dir).get_status()
    assert status.state == "idle"
    assert status.downloaded_bytes == 0 and status.total_bytes == 0


def test_history_newest_first_with_limit(data_dir, server):
    repo = UpdateFileRepository(data_dir)
    for i in range(5):
        repo.append_history(f"event_{i}", "2.1.0", None)
    with open(data_dir / HISTORY_FILE, "a", encoding="utf-8") as fh:
        fh.write("not json\n")
    items = _service(server, data_dir).get_history(3).items
    assert [i.event for i in items] == ["event_4", "event_3", "event_2"]


def test_history_empty_when_no_file(server, data_dir):
    assert _service(server, data_dir).get_history(50).items == []


def test_last_result_is_none(server, data_dir):
    result = _service(server, data_dir).get_last_result()
    assert result.result == "none"
    assert result.from_version is None and result.to_version is None


def test_not_implemented_detail_is_gone():
    import modules.app_update.validators as rules

    assert not hasattr(rules, "DETAIL_NOT_IMPLEMENTED")


def test_download_saves_the_staged_manifest(server, data_dir):
    _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert (data_dir / "staging" / "staged_manifest.json").read_bytes() == server.manifest


def test_failed_download_leaves_no_staged_manifest(server, data_dir):
    server.installer = b"X" * len(INSTALLER_BYTES)
    _service(server, data_dir).start_download("2.1.0", actor="admin")
    assert list((data_dir / "staging").iterdir()) == []


def test_default_data_dir_honours_env(tmp_path, monkeypatch):
    from modules.app_update.repository import default_update_data_dir

    monkeypatch.setenv("UPDATE_DATA_DIR", str(tmp_path / "custom"))
    assert default_update_data_dir() == tmp_path / "custom"
    monkeypatch.delenv("UPDATE_DATA_DIR")
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "lad"))
    assert default_update_data_dir() == tmp_path / "lad" / "SorourLogistics" / "updates"
