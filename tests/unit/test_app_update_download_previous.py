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
    assert status.total_bytes == len(NEW_INSTALLER) + len(OLD_INSTALLER)
    assert status.downloaded_bytes == status.total_bytes
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
