"""
Child processes must never inherit our PyInstaller onefile bootloader state (_PYI_*, _MEIPASS*).

Sandbox rehearsal bug: Setup (started by app_update with the backend's environment) relaunched frontend.exe,
which started the NEW backend.exe with the old _PYI_* vars. Same path + old _MEI folder still on disk -> the new
bootloader reused the OLD extraction: new code, old alembic/versions, migrations never ran.

Fixed at the source (the frozen backend_runner resets its own os.environ at startup, see
test_backend_runner_safety.py) plus an explicit env= on the installer launch (critical path).
"""
import os
import sys
import time

import pytest

import modules.app_update.service as update_service
from utils.db_safety import PYINSTALLER_RESET_ENV, clean_child_environment, reset_pyinstaller_environment

PYI_ENV = {
    "_PYI_APPLICATION_HOME_DIR": r"C:\Users\x\AppData\Local\Temp\_MEI12345",
    "_PYI_ARCHIVE_FILE": r"C:\app\backend.exe",
    "_PYI_PARENT_PROCESS_LEVEL": "1",
    "_PYI_SPLASH_IPC": "0",
    "_MEIPASS2": r"C:\Users\x\AppData\Local\Temp\_MEI12345",
    "_pyi_lowercase_variant": "x",
    "_meipass_lower": "x",
}


def _assert_clean(env):
    assert not [k for k in env if k.upper().startswith(("_PYI_", "_MEIPASS"))]
    assert env[PYINSTALLER_RESET_ENV] == "1"


# ─── helper ──────────────────────────────────────────────────────────────────

def test_clean_child_environment_drops_pyinstaller_state_and_keeps_the_rest():
    base = {"PATH": r"C:\Windows", "SystemRoot": r"C:\Windows", "UPDATE_DATA_DIR": "d", **PYI_ENV}
    env = clean_child_environment(base)
    _assert_clean(env)
    assert env["PATH"] == r"C:\Windows" and env["SystemRoot"] == r"C:\Windows" and env["UPDATE_DATA_DIR"] == "d"
    assert set(env) == {"PATH", "SystemRoot", "UPDATE_DATA_DIR", PYINSTALLER_RESET_ENV}


def test_clean_child_environment_does_not_mutate_the_source():
    base = dict(PYI_ENV)
    clean_child_environment(base)
    assert base == PYI_ENV


def test_clean_child_environment_overrides_an_inherited_reset_flag_of_any_case():
    env = clean_child_environment({"pyinstaller_reset_environment": "0", "PYINSTALLER_RESET_ENVIRONMENT": "0"})
    assert env == {PYINSTALLER_RESET_ENV: "1"}


def test_clean_child_environment_keeps_lookalike_names():
    env = clean_child_environment({"PYI_X": "1", "MEIPASS": "1", "X_PYI_Y": "1"})
    assert {"PYI_X", "MEIPASS", "X_PYI_Y"} <= set(env)


def test_clean_child_environment_defaults_to_os_environ_at_call_time(monkeypatch):
    monkeypatch.setenv("_PYI_ARCHIVE_FILE", r"C:\app\backend.exe")
    monkeypatch.setenv("IMPORTFLOW_ENV_PROBE", "kept")
    env = clean_child_environment()
    _assert_clean(env)
    assert env["IMPORTFLOW_ENV_PROBE"] == "kept"
    assert os.environ["_PYI_ARCHIVE_FILE"] == r"C:\app\backend.exe"  # our own process is untouched


def test_reset_pyinstaller_environment_works_in_place():
    env = {"PATH": "p", "Pyinstaller_Reset_Environment": "0", **PYI_ENV}
    assert reset_pyinstaller_environment(env) is None
    assert env == {"PATH": "p", PYINSTALLER_RESET_ENV: "1"}


def test_reset_pyinstaller_environment_defaults_to_os_environ(monkeypatch):
    monkeypatch.setenv(PYINSTALLER_RESET_ENV, "0")  # recorded, so teardown removes it again
    monkeypatch.setenv("_PYI_ARCHIVE_FILE", r"C:\app\backend.exe")
    reset_pyinstaller_environment()
    assert "_PYI_ARCHIVE_FILE" not in os.environ
    assert os.environ[PYINSTALLER_RESET_ENV] == "1"


# ─── installer launch (app_update) ───────────────────────────────────────────

class _FakeProc:
    pid = 4242


def _with_pyi_env(monkeypatch):
    for key, value in PYI_ENV.items():
        monkeypatch.setenv(key, value)


def test_installer_launch_passes_a_clean_environment(monkeypatch, tmp_path):
    _with_pyi_env(monkeypatch)
    calls = []

    def fake_popen(command, **kwargs):
        calls.append(kwargs)
        return _FakeProc()

    monkeypatch.setattr(update_service.subprocess, "Popen", fake_popen)
    assert update_service.launch_installer_detached('"C:/setup.exe" /VERYSILENT', tmp_path) == 4242
    _assert_clean(calls[0]["env"])
    assert calls[0]["env"]["PATH"] == os.environ["PATH"]


def test_installer_launch_retry_without_breakaway_also_passes_a_clean_environment(monkeypatch, tmp_path):
    _with_pyi_env(monkeypatch)
    calls = []

    def fake_popen(command, **kwargs):
        calls.append(kwargs)
        if len(calls) == 1:
            error = OSError("access denied")
            error.winerror = 5
            raise error
        return _FakeProc()

    monkeypatch.setattr(update_service.subprocess, "Popen", fake_popen)
    assert update_service.launch_installer_detached("cmd", tmp_path) == 4242
    assert len(calls) == 2
    for kwargs in calls:
        _assert_clean(kwargs["env"])


@pytest.mark.skipif(os.name != "nt", reason="detached launch flags are Windows-only")
def test_real_detached_child_sees_no_pyinstaller_state(monkeypatch, tmp_path):
    """End to end: a real process started by launch_installer_detached dumps the env it received."""
    _with_pyi_env(monkeypatch)
    out = tmp_path / "child_env.txt"
    script = tmp_path / "dump_env.py"
    script.write_text(
        "import os, sys\n"
        "open(sys.argv[1], 'w', encoding='utf-8').write('\\n'.join(sorted(os.environ)))\n",
        encoding="utf-8",
    )
    update_service.launch_installer_detached(f'"{sys.executable}" "{script}" "{out}"', tmp_path)
    for _ in range(100):
        if out.exists() and out.stat().st_size:
            break
        time.sleep(0.1)
    keys = [line for line in out.read_text(encoding="utf-8").splitlines() if line]
    assert keys, "child did not write its environment"
    assert not [k for k in keys if k.upper().startswith(("_PYI_", "_MEIPASS"))]
    assert PYINSTALLER_RESET_ENV in {k.upper() for k in keys}
