"""
Post-update health check and GET /last-result (spec §B.4): pending_update.json -> last_result.json once per process,
first matching row of the classification table wins, client-version check flips a success exactly once.
"""
import json

import pytest

import modules.app_update.service as update_service
from app_update_testkit import BACKUP_NAME, NEW_VERSION, OLD_VERSION, events, make_env
from modules.app_update.repository import LAST_RESULT_FILE, PENDING_FILE, UpdateFileRepository
from modules.app_update.validators import classify_post_update
from utils.db_safety import clear_maintenance_mode, enter_maintenance_mode


@pytest.fixture(autouse=True)
def _no_maintenance_leak():
    clear_maintenance_mode()
    yield
    clear_maintenance_mode()


@pytest.fixture
def env(tmp_path, monkeypatch):
    return make_env(tmp_path, monkeypatch)


def _last(env) -> dict:
    return json.loads((env.data_dir / LAST_RESULT_FILE).read_text(encoding="utf-8"))


# ─── classification table ────────────────────────────────────────────────────

def test_installer_not_completed(env):
    marker = env.marker()
    result = env.service(installed=OLD_VERSION).evaluate_pending_update()
    assert (result["result"], result["code"]) == ("failed", "installer_not_completed")
    assert result["detail"] == (
        f"لم يكتمل تثبيت الإصدار {NEW_VERSION}، والبرنامج ما زال على الإصدار {OLD_VERSION}. "
        f"بياناتك لم تتغير. سجل التثبيت: {marker['install_log']}"
    )
    assert events(env.data_dir)[-1] == "post_update_failed"


def test_unexpected_version(env):
    env.marker()
    result = env.service(installed="2.0.9").evaluate_pending_update()
    assert (result["result"], result["code"]) == ("failed", "unexpected_version")
    assert result["detail"] == f"الإصدار المثبت 2.0.9 غير المتوقع ({NEW_VERSION})."


def test_migration_failed_when_in_maintenance(env):
    env.marker()
    enter_maintenance_mode("R10: database revision ffff is unknown")
    result = env.service(installed=NEW_VERSION).evaluate_pending_update()
    assert (result["result"], result["code"]) == ("failed", "migration_failed")
    assert "ترقية قاعدة البيانات فشلت" in result["detail"] and NEW_VERSION in result["detail"]


@pytest.mark.parametrize("quick", ["corrupt", "raise"])
def test_db_check_failed(env, monkeypatch, quick):
    env.marker()
    if quick == "raise":
        def boom(path):
            raise OSError("unreadable")
        monkeypatch.setattr(update_service, "quick_check", boom)
    else:
        monkeypatch.setattr(update_service, "quick_check", lambda path: "*** in database main ***")
    result = env.service(installed=NEW_VERSION).evaluate_pending_update()
    assert (result["result"], result["code"]) == ("failed", "db_check_failed")
    assert result["detail"] == "فحص سلامة قاعدة البيانات بعد التحديث فشل. يمكنك التراجع للإصدار السابق."


def test_success(env):
    marker = env.marker()
    result = env.service(installed=NEW_VERSION).evaluate_pending_update()
    assert (result["result"], result["code"], result["detail"]) == ("success", None, None)
    assert result["client_checked"] is False
    assert result["finished_at"]
    for key, value in marker.items():
        assert result[key] == value  # last_result = marker + outcome
    assert not (env.data_dir / PENDING_FILE).exists()
    assert _last(env)["result"] == "success"
    assert events(env.data_dir)[-1] == "post_update_ok"


def test_first_matching_row_wins():
    marker = {"from_version": "2.0.3", "to_version": "2.1.0", "install_log": "L"}
    assert classify_post_update(marker, "2.0.3", True, "x", "bad")[1] == "installer_not_completed"
    assert classify_post_update(marker, "9.9.9", True, "x", "bad")[1] == "unexpected_version"
    assert classify_post_update(marker, None, False, "", "ok")[1] == "unexpected_version"
    assert classify_post_update(marker, "2.1.0", True, "x", "bad")[1] == "migration_failed"
    assert classify_post_update(marker, "2.1.0", False, "", "bad")[1] == "db_check_failed"
    assert classify_post_update(marker, "2.1.0", False, "", "ok") == ("success", None, None)


# ─── when the marker is ignored ──────────────────────────────────────────────

def test_marker_for_another_db_path_is_ignored_and_kept(env):
    env.marker(db_path=str(env.tmp / "other" / "sorour_logistics.db"))
    service = env.service(installed=NEW_VERSION)
    assert service.evaluate_pending_update() is None
    assert (env.data_dir / PENDING_FILE).exists()
    assert not (env.data_dir / LAST_RESULT_FILE).exists()
    assert service.get_last_result().result == "none"


def test_marker_for_another_app_dir_is_ignored_and_kept(env):
    env.marker(app_dir=str(env.tmp / "Another Install"))
    assert env.service(installed=NEW_VERSION).evaluate_pending_update() is None
    assert (env.data_dir / PENDING_FILE).exists()


def test_apply_not_supported_ignores_the_marker(env):
    env.marker()
    service = env.service(installed=NEW_VERSION, apply_supported=False)
    assert service.evaluate_pending_update() is None
    assert service.get_last_result().result == "none"
    assert (env.data_dir / PENDING_FILE).exists()


def test_runs_once_per_process(env):
    env.marker()
    service = env.service(installed=NEW_VERSION)
    assert service.evaluate_pending_update()["result"] == "success"
    env.marker(to_version="2.2.0")  # a marker appearing later in the same process is not evaluated
    assert service.evaluate_pending_update() is None
    assert (env.data_dir / PENDING_FILE).exists()


# ─── ordering: last_result.json first, then delete the marker ───────────────

def test_marker_deleted_only_after_last_result_written(env, monkeypatch):
    env.marker()
    real_clear = UpdateFileRepository.clear_pending
    seen = {}

    def spy_clear(self):
        seen["last_result_on_disk"] = (self.data_dir / LAST_RESULT_FILE).is_file()
        real_clear(self)

    monkeypatch.setattr(UpdateFileRepository, "clear_pending", spy_clear)
    env.service(installed=NEW_VERSION).evaluate_pending_update()
    assert seen == {"last_result_on_disk": True}


def test_marker_kept_when_last_result_cannot_be_written(env, monkeypatch):
    env.marker()

    def fail(self, result):
        raise OSError("disk full")

    monkeypatch.setattr(UpdateFileRepository, "save_last_result", fail)
    with pytest.raises(OSError):
        env.service(installed=NEW_VERSION).evaluate_pending_update()
    assert (env.data_dir / PENDING_FILE).exists()


def test_singleton_evaluates_right_after_creation(env, monkeypatch):
    env.marker()
    monkeypatch.setattr(update_service, "_service", None)
    monkeypatch.setattr(update_service, "UpdateService", lambda: env.service(installed=NEW_VERSION))
    service = update_service.get_update_service()
    assert not (env.data_dir / PENDING_FILE).exists()
    assert _last(env)["result"] == "success"
    assert update_service.get_update_service() is service


# ─── GET /last-result ────────────────────────────────────────────────────────

def test_last_result_none_without_files(env):
    result = env.service(installed=NEW_VERSION).get_last_result("2.1.0")
    assert result.model_dump() == {
        "result": "none", "from_version": None, "to_version": None, "finished_at": None, "detail": None,
        "kind": None, "backup_file": None, "backup_created_at": None,
    }


def test_last_result_returns_backup_fields_and_kind(env):
    env.marker()
    result = env.service(installed=NEW_VERSION).get_last_result()  # safety-net evaluation
    assert result.result == "success"
    assert result.kind == "update"
    assert result.from_version == OLD_VERSION and result.to_version == NEW_VERSION
    assert result.backup_file == BACKUP_NAME
    assert result.backup_created_at.isoformat() == "2026-10-01T08:15:00+00:00"
    assert result.finished_at is not None


def test_client_mismatch_flips_to_failed_exactly_once(env):
    env.marker()
    service = env.service(installed=NEW_VERSION)
    first = service.get_last_result(client_version=OLD_VERSION)
    assert first.result == "failed"
    assert first.detail == f"واجهة البرنامج لم تتحدث (الإصدار {OLD_VERSION}) بينما الخادم على الإصدار {NEW_VERSION}."
    stored = _last(env)
    assert stored["client_checked"] is True and stored["code"] == "client_version_mismatch"
    # later calls, even with the right client version, never flip it again
    second = service.get_last_result(client_version=NEW_VERSION)
    assert second.result == "failed"
    assert events(env.data_dir).count("client_version_mismatch") == 1


def test_matching_client_marks_checked_and_stays_success(env):
    env.marker()
    service = env.service(installed=NEW_VERSION)
    assert service.get_last_result(client_version=NEW_VERSION).result == "success"
    assert _last(env)["client_checked"] is True
    assert service.get_last_result(client_version=OLD_VERSION).result == "success"  # already checked


def test_no_client_header_leaves_it_unchecked(env):
    env.marker()
    service = env.service(installed=NEW_VERSION)
    assert service.get_last_result(client_version=None).result == "success"
    assert _last(env)["client_checked"] is False


def test_non_semver_client_header_is_ignored(env):
    env.marker()
    service = env.service(installed=NEW_VERSION)
    assert service.get_last_result(client_version="<script>").result == "success"
    assert _last(env)["client_checked"] is False


def test_client_check_only_for_successful_updates(env):
    env.marker()
    service = env.service(installed=OLD_VERSION)  # installer_not_completed
    result = service.get_last_result(client_version="9.9.9")
    assert result.result == "failed"
    assert _last(env)["code"] == "installer_not_completed"
    assert _last(env)["client_checked"] is False


def test_malformed_last_result_is_none(env):
    env.repo.save_last_result({"result": "weird", "kind": "update"})
    assert env.service(installed=NEW_VERSION).get_last_result().result == "none"


# ─── only system.update holders acknowledge the client check (review item 5) ─

def test_caller_without_system_update_sees_the_result_but_never_flips_it(env):
    env.marker()
    service = env.service(installed=NEW_VERSION)
    seen = service.get_last_result(client_version=OLD_VERSION, can_acknowledge=False)
    assert seen.result == "success"
    stored = _last(env)
    assert stored["client_checked"] is False and stored["result"] == "success"
    assert "client_version_mismatch" not in events(env.data_dir)
    # an admin's client later performs the one-time check
    assert service.get_last_result(client_version=OLD_VERSION, can_acknowledge=True).result == "failed"
    assert _last(env)["client_checked"] is True
