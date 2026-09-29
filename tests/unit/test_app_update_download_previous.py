"""
Pre-fetch of the previous installer during a download (spec §B.6, Decision 3): kept in installers/ for rollback,
skipped when already present or when previous != installed, and never blocking the update when it fails.
"""
import httpx
import pytest

from app_update_testkit import (
    NEW_INSTALLER,
    NEW_VERSION,
    OLD_INSTALLER,
    OLD_VERSION,
    events,
    history,
    installer_name,
    make_env,
    payload,
    sign,
)
from modules.app_update.repository import UpdateFileRepository
from utils.db_safety import clear_maintenance_mode

NEW_PATH = f"/importflow/updates/releases/{NEW_VERSION}/{installer_name(NEW_VERSION)}"
OLD_PATH = f"/importflow/updates/releases/{OLD_VERSION}/{installer_name(OLD_VERSION)}"


@pytest.fixture(autouse=True)
def _no_maintenance_leak():
    clear_maintenance_mode()
    yield
    clear_maintenance_mode()


@pytest.fixture
def env(tmp_path, monkeypatch):
    return make_env(tmp_path, monkeypatch)


class Server:
    def __init__(self, manifest: bytes):
        self.manifest = manifest
        self.old_installer = OLD_INSTALLER
        self.old_status = 200
        self.requests = []

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request.url.path)
        if request.url.path.endswith("/manifest.json"):
            return httpx.Response(200, content=self.manifest)
        if request.url.path == NEW_PATH:
            return httpx.Response(200, content=NEW_INSTALLER)
        if request.url.path == OLD_PATH:
            return httpx.Response(self.old_status, content=self.old_installer)
        return httpx.Response(404)


def _service(env, server, installed=OLD_VERSION):
    return env.service(installed=installed, transport=httpx.MockTransport(server.handler))


def test_prefetch_when_missing(env):
    server = Server(sign(env.key, payload()))
    status = _service(env, server).start_download(NEW_VERSION, actor="admin")
    assert status.state == "ready"
    # the rollback copy is its own phase: `ready` reports the new installer only, never the sum of both files
    assert status.total_bytes == len(NEW_INSTALLER)
    assert status.downloaded_bytes == status.total_bytes
    assert status.phase is None
    kept = env.data_dir / "installers" / installer_name(OLD_VERSION)
    assert kept.read_bytes() == OLD_INSTALLER
    assert not (env.data_dir / "installers" / (installer_name(OLD_VERSION) + ".part")).exists()
    assert OLD_PATH in server.requests
    assert events(env.data_dir)[-2:] == ["download_verified", "previous_downloaded"]
    # the staged manifest is saved once the job is ready
    assert (env.data_dir / "staging" / "staged_manifest.json").read_bytes() == server.manifest


def test_skip_when_present(env):
    env.keep_previous_installer()
    server = Server(sign(env.key, payload()))
    status = _service(env, server).start_download(NEW_VERSION, actor="admin")
    assert status.state == "ready"
    assert status.total_bytes == len(NEW_INSTALLER)
    assert OLD_PATH not in server.requests
    assert "previous_downloaded" not in events(env.data_dir)


def test_refetch_when_present_with_wrong_hash(env):
    env.keep_previous_installer(data=b"Z" * len(OLD_INSTALLER))
    server = Server(sign(env.key, payload()))
    assert _service(env, server).start_download(NEW_VERSION, actor="admin").state == "ready"
    assert (env.data_dir / "installers" / installer_name(OLD_VERSION)).read_bytes() == OLD_INSTALLER


def test_skip_when_previous_is_not_the_installed_version(env):
    server = Server(sign(env.key, payload(previous=("2.0.1", OLD_INSTALLER))))
    status = _service(env, server, installed=OLD_VERSION).start_download(NEW_VERSION, actor="admin")
    assert status.state == "ready"
    assert not any("/releases/2.0.1/" in p for p in server.requests)
    assert not (env.data_dir / "installers").exists() or list((env.data_dir / "installers").iterdir()) == []


def test_skip_without_previous_block(env):
    server = Server(sign(env.key, payload(previous=None)))
    assert _service(env, server).start_download(NEW_VERSION, actor="admin").state == "ready"
    assert OLD_PATH not in server.requests


@pytest.mark.parametrize("failure", ["http_500", "hash_mismatch", "oversize"])
def test_failure_is_non_blocking(env, failure):
    server = Server(sign(env.key, payload()))
    if failure == "http_500":
        server.old_status = 500
    elif failure == "hash_mismatch":
        server.old_installer = b"X" * len(OLD_INSTALLER)
    else:
        server.old_installer = OLD_INSTALLER + b"more" * 5000
    status = _service(env, server).start_download(NEW_VERSION, actor="admin")
    assert status.state == "ready"  # Decision 3
    assert status.error_code is None
    assert status.phase is None
    assert status.downloaded_bytes == status.total_bytes == len(NEW_INSTALLER)
    assert (env.data_dir / "staging" / installer_name(NEW_VERSION)).read_bytes() == NEW_INSTALLER
    installers = env.data_dir / "installers"
    assert not (installers / installer_name(OLD_VERSION)).exists()
    assert not (installers / (installer_name(OLD_VERSION) + ".part")).exists()
    failed = [e for e in history(env.data_dir) if e["event"] == "previous_download_failed"]
    assert len(failed) == 1 and failed[0]["version"] == OLD_VERSION


def test_clear_staging_keeps_installers(env):
    repo = UpdateFileRepository(env.data_dir)
    kept = env.keep_previous_installer()
    repo.ensure_staging_dir()
    (repo.staging_dir / "x.exe.part").write_bytes(b"x")
    repo.save_staged_manifest(b"{}")
    repo.clear_staging()
    assert list(repo.staging_dir.iterdir()) == []
    assert kept.read_bytes() == OLD_INSTALLER


def test_new_download_does_not_touch_kept_installers(env):
    kept = env.keep_previous_installer()
    other = env.repo.installer_path(installer_name("1.9.0"))
    other.write_bytes(b"older")
    server = Server(sign(env.key, payload()))
    assert _service(env, server).start_download(NEW_VERSION, actor="admin").state == "ready"
    assert kept.read_bytes() == OLD_INSTALLER and other.read_bytes() == b"older"


def test_cancel_during_prefetch_cancels_the_job(env):
    server = Server(sign(env.key, payload()))
    service = _service(env, server)
    original = server.handler

    def cancelling_handler(request):
        if request.url.path == OLD_PATH:
            service.cancel(actor="admin")
        return original(request)

    service._transport = httpx.MockTransport(cancelling_handler)
    service.start_download(NEW_VERSION, actor="admin")
    assert service.get_status().state == "idle"
    assert not (env.data_dir / "staging" / installer_name(NEW_VERSION)).exists()
    assert not (env.data_dir / "installers" / (installer_name(OLD_VERSION) + ".part")).exists()


# ─── progress phases: installer -> rollback_copy -> None ─────────────────────

PIECE = 4096


def _pieces(data: bytes, on_resume):
    """Yield `data` in PIECE-sized parts; `on_resume` runs after the service consumed the first part."""
    yield data[:PIECE]
    on_resume()
    for start in range(PIECE, len(data), PIECE):
        yield data[start:start + PIECE]


class PausingServer(Server):
    """Snapshots the service status when each installer is requested and again mid-stream."""

    def __init__(self, manifest: bytes):
        super().__init__(manifest)
        self.service = None
        self.at_request = {}
        self.mid_stream = {}
        self.on_old_request = None

    def handler(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path in (NEW_PATH, OLD_PATH):
            self.requests.append(path)
            key = "installer" if path == NEW_PATH else "rollback_copy"
            self.at_request[key] = self.service.get_status()
            if path == OLD_PATH and self.on_old_request is not None:
                self.on_old_request()
            data = NEW_INSTALLER if path == NEW_PATH else self.old_installer
            status_code = 200 if path == NEW_PATH else self.old_status

            def snap():
                self.mid_stream[key] = self.service.get_status()

            return httpx.Response(status_code, content=_pieces(data, snap))
        return super().handler(request)


@pytest.fixture
def small_chunks(monkeypatch):
    import modules.app_update.service as update_service

    monkeypatch.setattr(update_service, "DOWNLOAD_CHUNK_BYTES", PIECE)


def _pausing_service(env, server):
    service = _service(env, server)
    server.service = service
    return service


def test_phase_sequence_installer_then_rollback_copy_then_none(env, small_chunks):
    server = PausingServer(sign(env.key, payload()))
    service = _pausing_service(env, server)
    status = service.start_download(NEW_VERSION, actor="admin")

    installer = server.at_request["installer"]
    assert (installer.state, installer.phase) == ("downloading", "installer")
    assert installer.total_bytes == len(NEW_INSTALLER)
    assert installer.downloaded_bytes == 0
    mid = server.mid_stream["installer"]
    assert mid.phase == "installer" and mid.total_bytes == len(NEW_INSTALLER)
    assert 0 < mid.downloaded_bytes < len(NEW_INSTALLER)

    copy = server.at_request["rollback_copy"]
    assert (copy.state, copy.phase) == ("verifying", "rollback_copy")
    assert copy.downloaded_bytes == 0  # the progress restarts, no offset of the new installer
    assert copy.total_bytes == len(OLD_INSTALLER)
    mid = server.mid_stream["rollback_copy"]
    assert (mid.state, mid.phase) == ("verifying", "rollback_copy")
    assert mid.total_bytes == len(OLD_INSTALLER)
    assert 0 < mid.downloaded_bytes < len(OLD_INSTALLER)

    assert (status.state, status.phase) == ("ready", None)
    assert status.downloaded_bytes == status.total_bytes == len(NEW_INSTALLER)
    assert service.get_status() == status


def test_no_rollback_copy_phase_when_previous_is_kept(env, small_chunks):
    env.keep_previous_installer()
    server = PausingServer(sign(env.key, payload()))
    status = _pausing_service(env, server).start_download(NEW_VERSION, actor="admin")
    assert set(server.at_request) == {"installer"}
    assert server.at_request["installer"].phase == "installer"
    assert (status.state, status.phase, status.total_bytes) == ("ready", None, len(NEW_INSTALLER))


def test_cancel_during_rollback_copy_phase_returns_to_idle(env, small_chunks):
    server = PausingServer(sign(env.key, payload()))
    service = _pausing_service(env, server)
    cancelled = {}

    def cancel_now():
        cancelled["response"] = service.cancel(actor="admin")

    server.on_old_request = cancel_now
    service.start_download(NEW_VERSION, actor="admin")

    assert server.at_request["rollback_copy"].phase == "rollback_copy"
    response = cancelled["response"]
    assert (response.state, response.phase) == ("idle", None)
    assert response.downloaded_bytes == response.total_bytes == 0
    final = service.get_status()
    assert (final.state, final.phase, final.error_code) == ("idle", None, None)
    assert not (env.data_dir / "staging" / installer_name(NEW_VERSION)).exists()
    assert not (env.data_dir / "installers" / (installer_name(OLD_VERSION) + ".part")).exists()
    assert not (env.data_dir / "installers" / installer_name(OLD_VERSION)).exists()


def test_failed_rollback_copy_still_ends_ready_with_installer_bytes(env, small_chunks):
    server = PausingServer(sign(env.key, payload()))
    server.old_installer = b"X" * len(OLD_INSTALLER)  # hash mismatch on the rollback copy
    status = _pausing_service(env, server).start_download(NEW_VERSION, actor="admin")
    assert server.at_request["rollback_copy"].phase == "rollback_copy"
    assert (status.state, status.phase, status.error_code) == ("ready", None, None)
    assert status.downloaded_bytes == status.total_bytes == len(NEW_INSTALLER)
    assert "previous_download_failed" in events(env.data_dir)


def test_failed_installer_download_clears_the_phase(env, small_chunks):
    server = PausingServer(sign(env.key, payload()))
    original = server.handler

    def broken_new(request):
        if request.url.path == NEW_PATH:
            return httpx.Response(500)
        return original(request)

    service = _service(env, server)
    server.service = service
    service._transport = httpx.MockTransport(broken_new)
    status = service.start_download(NEW_VERSION, actor="admin")
    assert (status.state, status.phase, status.error_code) == ("failed", None, "download_failed")
