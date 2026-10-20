"""
DB-safety guarantees of backend_runner.py now that frontend.exe starts backend.exe itself.

S1  single instance: the lock is taken BEFORE `from main import app` (which runs the startup upgrade);
    a second instance exits 0 without importing main, and the lock is released on exit.
S2  the frontend watchdog never exits while the startup upgrade is running.
"""
import os
import subprocess
import sys
import threading
import uuid
from pathlib import Path

import pytest

import backend_runner as br

PROJECT_DIR = Path(__file__).resolve().parents[2]
windows_only = pytest.mark.skipif(sys.platform != "win32", reason="named mutex is Windows only")


class StopLoop(Exception):
    pass


# ------------------------------------------------------------------------------------------------
# S1 lock primitives
# ------------------------------------------------------------------------------------------------
@windows_only
def test_named_mutex_blocks_a_second_holder_and_is_released():
    name = f"Local\\ImportFlowTest_{uuid.uuid4().hex}"
    first = br.acquire_named_mutex(name)
    assert first is not None and first.kind == "mutex"
    try:
        assert br.acquire_named_mutex(name) is None
    finally:
        first.release()
    assert first.released
    again = br.acquire_named_mutex(name)
    assert again is not None
    again.release()


def test_lock_file_blocks_a_second_holder_and_is_released(tmp_path):
    path = tmp_path / "backend.lock"
    first = br.acquire_lock_file(path)
    assert first is not None and first.kind == "file"
    try:
        assert br.acquire_lock_file(path) is None
    finally:
        first.release()
    first.release()  # idempotent
    again = br.acquire_lock_file(path)
    assert again is not None
    again.release()
    assert path.exists(), "the lock file is never deleted"


@windows_only
def test_frozen_windows_uses_the_mutex(monkeypatch, tmp_path):
    calls = []
    monkeypatch.setattr(br, "acquire_named_mutex", lambda name: calls.append(name) or "MUTEX")
    monkeypatch.setattr(br, "acquire_lock_file", lambda path: pytest.fail("lock file used"))

    assert br.acquire_single_instance_lock(tmp_path, frozen=True) == "MUTEX"
    assert calls == ["Local\\SorourLogisticsBackend"]


def test_mutex_failure_falls_back_to_the_app_lock_file(monkeypatch, tmp_path):
    def broken(name):
        raise OSError(5, "denied")

    monkeypatch.setattr(br, "acquire_named_mutex", broken)
    lock = br.acquire_single_instance_lock(tmp_path, frozen=True, platform="win32")
    try:
        assert lock is not None and lock.kind == "file"
        assert Path(lock.description) == tmp_path / "backend.lock"
        assert br.acquire_lock_file(tmp_path / "backend.lock") is None
    finally:
        lock.release()


def test_dev_and_non_windows_use_a_lock_file_outside_the_repo(monkeypatch, tmp_path):
    monkeypatch.setattr(br, "acquire_named_mutex", lambda name: pytest.fail("mutex used in dev"))
    monkeypatch.setattr(br.tempfile, "gettempdir", lambda: str(tmp_path))

    lock = br.acquire_single_instance_lock(PROJECT_DIR, frozen=False)
    try:
        assert lock.kind == "file"
        assert Path(lock.description).parent == tmp_path
        assert br.acquire_single_instance_lock(PROJECT_DIR, frozen=False) is None
    finally:
        lock.release()
    assert not (PROJECT_DIR / "backend.lock").exists()


# ------------------------------------------------------------------------------------------------
# S1 run()
# ------------------------------------------------------------------------------------------------
def _run(tmp_path, lock_factory, **kwargs):
    events = kwargs.pop("events", [])
    kwargs.setdefault("frozen", False)
    kwargs.setdefault("import_app", lambda: events.append("import_main") or "APP")
    kwargs.setdefault("serve", lambda app: events.append(("serve", app)))
    return br.run(app_dir=tmp_path, lock_factory=lock_factory, **kwargs)


def _capture_watchdog(events, seen):
    """start_watchdog stub that records the startup Event run() hands to the watchdog."""
    def start(event):
        seen["started"] = event
        events.append("watchdog")
    return start


def test_second_instance_exits_quietly_without_importing_main(tmp_path, capsys):
    path = tmp_path / "backend.lock"
    holder = br.acquire_lock_file(path)  # the first instance
    events = []
    try:
        code = _run(tmp_path, lambda app_dir, frozen: br.acquire_lock_file(path), events=events,
                    start_watchdog=lambda e: events.append("watchdog"))
    finally:
        holder.release()

    assert code == 0
    assert events == [], "a second instance must not import main, start the watchdog or serve"
    assert "another backend instance is already running" in capsys.readouterr().out


def test_lock_is_taken_before_main_import_and_released_after_serve(tmp_path):
    path = tmp_path / "backend.lock"
    events = []
    seen = {}
    held = {}

    def lock_factory(app_dir, frozen):
        events.append("lock")
        held["lock"] = br.acquire_lock_file(path)
        return held["lock"]

    def import_app():
        assert not seen["started"].is_set(), "startup_done must not be set while main is imported"
        events.append("import_main")
        return "APP"

    def serve(app):
        assert seen["started"].is_set(), "startup_done must be set before serving"
        assert br.acquire_lock_file(path) is None, "lock must be held while serving"
        events.append("serve")

    code = _run(tmp_path, lock_factory, events=events, import_app=import_app, serve=serve,
                start_watchdog=_capture_watchdog(events, seen))

    assert code == 0
    assert events == ["lock", "watchdog", "import_main", "serve"]
    assert held["lock"].released
    after = br.acquire_lock_file(path)
    assert after is not None
    after.release()


def test_lock_is_released_when_startup_fails(tmp_path):
    path = tmp_path / "backend.lock"
    held = {}
    seen = {}

    def lock_factory(app_dir, frozen):
        held["lock"] = br.acquire_lock_file(path)
        return held["lock"]

    def failing_import():
        raise RuntimeError("boom")

    with pytest.raises(RuntimeError):
        _run(tmp_path, lock_factory, import_app=failing_import, start_watchdog=_capture_watchdog([], seen))

    assert held["lock"].released
    assert not seen["started"].is_set()


def test_each_run_gets_its_own_startup_event(tmp_path):
    first, second = {}, {}
    for seen in (first, second):
        _run(tmp_path, lambda app_dir, frozen: br.acquire_lock_file(tmp_path / "x.lock"),
             start_watchdog=_capture_watchdog([], seen))
    assert first["started"] is not second["started"]


def test_dev_run_does_not_start_the_watchdog_by_default(tmp_path, monkeypatch):
    monkeypatch.setattr(br.threading, "Thread", lambda *a, **k: pytest.fail("watchdog thread started in dev"))
    code = _run(tmp_path, lambda app_dir, frozen: br.acquire_lock_file(tmp_path / "x.lock"))
    assert code == 0


def test_frozen_run_starts_the_watchdog_thread_by_default(tmp_path, monkeypatch):
    monkeypatch.setattr(br, "_prepare_frozen_process", lambda app_dir: None)
    monkeypatch.setattr(br, "reset_pyinstaller_environment", lambda: None)
    started = []
    monkeypatch.setattr(br, "start_watchdog_thread", lambda event: started.append(event))
    code = _run(tmp_path, lambda app_dir, frozen: br.acquire_lock_file(tmp_path / "x.lock"), frozen=True)
    assert code == 0
    assert len(started) == 1 and started[0].is_set()


def test_run_defaults_come_from_db_safety(tmp_path, monkeypatch):
    seen = {}
    monkeypatch.setattr(br, "is_frozen_build", lambda: False)
    monkeypatch.setattr(br, "app_base_dir", lambda: tmp_path)

    def lock_factory(app_dir, frozen):
        seen["args"] = (app_dir, frozen)
        return br.acquire_lock_file(tmp_path / "x.lock")

    code = br.run(lock_factory=lock_factory, import_app=lambda: "APP", serve=lambda app: None)
    assert code == 0
    assert seen["args"] == (tmp_path, False)


# ------------------------------------------------------------------------------------------------
# S3 PyInstaller environment
# ------------------------------------------------------------------------------------------------
PYI_ENV = {
    "_PYI_APPLICATION_HOME_DIR": r"C:\Temp\_MEI1",
    "_PYI_ARCHIVE_FILE": r"C:\app\backend.exe",
    "_PYI_PARENT_PROCESS_LEVEL": "1",
    "_MEIPASS2": r"C:\Temp\_MEI1",
}


def _set_pyi_env(monkeypatch):
    monkeypatch.setenv("PYINSTALLER_RESET_ENVIRONMENT", "0")  # recorded, so teardown removes it again
    for key, value in PYI_ENV.items():
        monkeypatch.setenv(key, value)


def test_frozen_startup_cleans_the_pyinstaller_environment_before_the_lock(tmp_path, monkeypatch):
    _set_pyi_env(monkeypatch)
    monkeypatch.setattr(br, "_prepare_frozen_process", lambda app_dir: None)
    seen = {}

    def lock_factory(app_dir, frozen):
        seen["env"] = dict(os.environ)
        return br.acquire_lock_file(tmp_path / "x.lock")

    code = _run(tmp_path, lock_factory, frozen=True, start_watchdog=lambda e: None)
    assert code == 0
    for env in (seen["env"], os.environ):
        assert not [k for k in env if k.upper().startswith(("_PYI_", "_MEIPASS"))]
        assert env["PYINSTALLER_RESET_ENVIRONMENT"] == "1"


def test_dev_run_leaves_the_environment_alone(tmp_path, monkeypatch):
    _set_pyi_env(monkeypatch)
    _run(tmp_path, lambda app_dir, frozen: br.acquire_lock_file(tmp_path / "x.lock"))
    assert os.environ["_PYI_ARCHIVE_FILE"] == PYI_ENV["_PYI_ARCHIVE_FILE"]
    assert os.environ["PYINSTALLER_RESET_ENVIRONMENT"] == "0"


def test_tasklist_check_runs_without_a_shell(monkeypatch):
    calls = []

    def fake_check_output(cmd, **kwargs):
        calls.append((cmd, kwargs))
        return b"frontend.exe   1234 Console   1   10,000 K"

    monkeypatch.setattr(subprocess, "check_output", fake_check_output)
    assert br.is_frontend_running() is True
    cmd, kwargs = calls[0]
    assert cmd == ["tasklist", "/FI", "IMAGENAME eq frontend.exe"]
    assert not kwargs.get("shell")
    monkeypatch.setattr(subprocess, "check_output", lambda cmd, **kw: b"INFO: No tasks are running")
    assert br.is_frontend_running() is False


def test_second_backend_process_exits_before_importing_main(tmp_path):
    """Real process: while the dev lock is held, `python backend_runner.py` exits 0 at once."""
    lock_path = br.default_lock_file_path(PROJECT_DIR, frozen=False)
    holder = br.acquire_lock_file(lock_path)
    if holder is None:
        pytest.skip("a dev backend_runner is running on this checkout")
    env = dict(os.environ)
    env["DATABASE_PATH"] = str(tmp_path / "must_not_be_created.db")  # safety net if the lock ever fails
    try:
        result = subprocess.run([sys.executable, str(PROJECT_DIR / "backend_runner.py")], cwd=str(PROJECT_DIR),
                                env=env, capture_output=True, text=True, timeout=60)
    finally:
        holder.release()

    assert result.returncode == 0, result.stderr
    assert "another backend instance is already running" in result.stdout
    assert not (tmp_path / "must_not_be_created.db").exists(), "main was imported by the second instance"


# ------------------------------------------------------------------------------------------------
# S2 watchdog
# ------------------------------------------------------------------------------------------------
class FakeTime:
    def __init__(self, max_ticks, on_tick=None):
        self.now = 1000.0
        self.ticks = 0
        self.max_ticks = max_ticks
        self.on_tick = on_tick

    def sleep(self, seconds):
        if self.ticks >= self.max_ticks:
            raise StopLoop()
        self.ticks += 1
        self.now += seconds
        if self.on_tick:
            self.on_tick(self.ticks)

    def clock(self):
        return self.now


def _watch(started, running, fake, exits):
    br.frontend_watchdog(started, frontend_running=running, exit_fn=lambda: exits.append(fake.ticks),
                         sleep=fake.sleep, clock=fake.clock)


def test_watchdog_never_exits_while_startup_upgrade_runs():
    started = threading.Event()
    exits = []
    fake = FakeTime(max_ticks=200)  # 600 s, far beyond the 120 s grace period
    states = iter([True] + [False] * 500)  # frontend seen, then closed during the migration

    with pytest.raises(StopLoop):
        _watch(started, lambda: next(states), fake, exits)
    assert exits == []


def test_watchdog_exits_after_startup_when_frontend_closed_during_it():
    started = threading.Event()
    exits = []
    fake = FakeTime(max_ticks=50, on_tick=lambda n: started.set() if n == 10 else None)
    states = iter([True, True] + [False] * 100)

    _watch(started, lambda: next(states), fake, exits)
    assert exits == [10], "exit on the first tick after startup_done"


def test_watchdog_keeps_running_while_frontend_is_alive_then_exits_on_close():
    started = threading.Event()
    started.set()
    exits = []
    fake = FakeTime(max_ticks=100)
    states = iter([True] * 20 + [False] * 100)

    _watch(started, lambda: next(states), fake, exits)
    assert exits == [21]


def test_watchdog_grace_period_starts_after_startup():
    started = threading.Event()
    exits = []
    fake = FakeTime(max_ticks=500, on_tick=lambda n: started.set() if n == 100 else None)

    _watch(started, lambda: False, fake, exits)
    # startup done at tick 100 (300 s), grace 120 s = 40 ticks of 3 s -> exit at tick 141
    assert exits == [141]


def test_watchdog_survives_a_failing_process_check():
    started = threading.Event()
    started.set()
    exits = []
    fake = FakeTime(max_ticks=10)
    results = iter([OSError("tasklist"), True, False])

    def running():
        value = next(results)
        if isinstance(value, Exception):
            raise value
        return value

    _watch(started, running, fake, exits)
    assert exits == [3]



# ------------------------------------------------------------------------------------------------
# S2 watchdog check: handle on the frontend.exe that started us, tasklist only as a fallback
# ------------------------------------------------------------------------------------------------
# python child (300) -> PyInstaller bootloader backend.exe (200) -> frontend.exe (100) -> explorer (4)
PYI_TREE = {300: (200, "backend.exe"), 200: (100, "backend.exe"), 100: (4, "frontend.exe"),
            4: (0, "explorer.exe")}


def test_find_ancestor_pid_walks_through_the_pyinstaller_bootloader():
    assert br.find_ancestor_pid(PYI_TREE, 300) == 100
    assert br.find_ancestor_pid({300: (100, "x"), 100: (1, "FrontEnd.EXE")}, 300) == 100


@pytest.mark.parametrize("table, start", [
    ({300: (200, "backend.exe"), 200: (7, "wscript.exe"), 7: (0, "explorer.exe")}, 300),  # old .vbs launcher
    ({300: (200, "backend.exe")}, 300),  # parent already gone
    ({300: (300, "backend.exe")}, 300),  # self-parent (pid reuse)
    ({300: (200, "a"), 200: (300, "b")}, 300),  # cycle
    ({}, 300),  # own pid missing from the snapshot
])
def test_find_ancestor_pid_returns_none_without_a_frontend_ancestor(table, start):
    assert br.find_ancestor_pid(table, start) is None


def test_find_ancestor_pid_respects_max_depth():
    chain = {5: (4, "b"), 4: (3, "b"), 3: (2, "b"), 2: (1, "b"), 1: (0, "frontend.exe")}
    assert br.find_ancestor_pid(chain, 5, max_depth=3) is None
    assert br.find_ancestor_pid(chain, 5, max_depth=4) == 1


class _FakeWatch:
    def __init__(self, pid):
        self.pid = pid

    def is_running(self):
        return True


def _no_tasklist():
    pytest.fail("tasklist fallback used although the frontend handle is available")


def test_select_frontend_check_uses_the_frontend_handle():
    opened = []

    def open_watch(pid):
        opened.append(pid)
        return _FakeWatch(pid)

    check = br.select_frontend_check(platform="win32", own_pid=300, process_table=lambda: PYI_TREE,
                                     open_watch=open_watch, fallback=_no_tasklist)
    assert opened == [100]
    assert check() is True


@pytest.mark.parametrize("process_table, open_watch", [
    (lambda: {300: (7, "backend.exe"), 7: (0, "wscript.exe")}, _FakeWatch),  # no frontend ancestor
    (lambda: (_ for _ in ()).throw(OSError(8, "Not enough memory resources")), _FakeWatch),  # snapshot failed
    (lambda: PYI_TREE, lambda pid: (_ for _ in ()).throw(PermissionError(5, "Access is denied"))),  # OpenProcess failed
])
def test_select_frontend_check_falls_back_to_tasklist(process_table, open_watch):
    def fallback():
        return True

    check = br.select_frontend_check(platform="win32", own_pid=300, process_table=process_table,
                                     open_watch=open_watch, fallback=fallback)
    assert check is fallback


def test_select_frontend_check_off_windows_keeps_the_old_check():
    def fallback():
        return False

    assert br.select_frontend_check(platform="linux", fallback=fallback) is fallback


def test_watchdog_thread_uses_the_selected_check(monkeypatch):
    started = threading.Event()
    seen = []
    monkeypatch.setattr(br, "select_frontend_check", lambda: "the-check")
    monkeypatch.setattr(br, "frontend_watchdog", lambda ev, frontend_running: seen.append((ev, frontend_running)))
    br.start_watchdog_thread(started)
    for _ in range(100):
        if seen:
            break
        threading.Event().wait(0.02)
    assert seen == [(started, "the-check")]


@windows_only
def test_process_handle_watch_follows_a_real_process():
    child = subprocess.Popen([sys.executable, "-c", "import sys; sys.stdin.read()"], stdin=subprocess.PIPE)
    try:
        watch = br.ProcessHandleWatch(child.pid)
        assert watch.is_running() is True
        child.stdin.close()
        child.wait(timeout=30)
        assert watch.is_running() is False
        watch.close()
    finally:
        if child.poll() is None:
            child.kill()


@windows_only
def test_windows_process_table_sees_this_process_and_its_parent():
    table = br.windows_process_table()
    assert table[os.getpid()][0] == os.getppid()
    assert table[os.getpid()][1].lower().startswith("python")


@windows_only
def test_frontend_ancestor_is_found_through_a_real_process_chain(tmp_path):
    """Real chain: a copy of python named frontend.exe starts python, which reports its frontend ancestor."""
    import shutil

    fake_frontend = tmp_path / "frontend.exe"
    shutil.copy(sys.executable, fake_frontend)
    for dll in Path(sys.executable).parent.glob("python*.dll"):
        shutil.copy(dll, tmp_path / dll.name)
    code = ("import subprocess, sys; "
            f"r = subprocess.run([{sys.executable!r}, '-c', "
            "'import os, backend_runner as b; print(b.find_ancestor_pid(b.windows_process_table(), os.getpid()))'], "
            "capture_output=True, text=True); print(r.stdout.strip(), r.stderr[-300:]); import os; print(os.getpid())")
    env = dict(os.environ)
    env["PYTHONPATH"] = str(PROJECT_DIR) + os.pathsep + env.get("PYTHONPATH", "")
    env["PYTHONHOME"] = str(Path(sys.executable).parent) if not env.get("PYTHONHOME") else env["PYTHONHOME"]
    result = subprocess.run([str(fake_frontend), "-c", code], capture_output=True, text=True, env=env, timeout=60)
    lines = result.stdout.split()
    assert result.returncode == 0, result.stderr
    assert lines[0] == lines[-1], result.stdout + result.stderr
