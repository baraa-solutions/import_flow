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
    kwargs.setdefault("import_app", lambda: events.append("import_main") or "APP")
    kwargs.setdefault("serve", lambda app: events.append(("serve", app)))
    return br.run(frozen=False, app_dir=tmp_path, lock_factory=lock_factory, **kwargs)


def test_second_instance_exits_quietly_without_importing_main(tmp_path, capsys):
    path = tmp_path / "backend.lock"
    holder = br.acquire_lock_file(path)  # the first instance
    events = []
    started = threading.Event()
    try:
        code = _run(tmp_path, lambda app_dir, frozen: br.acquire_lock_file(path), events=events,
                    start_watchdog=lambda e: events.append("watchdog"), started=started)
    finally:
        holder.release()

    assert code == 0
    assert events == [], "a second instance must not import main, start the watchdog or serve"
    assert not started.is_set()
    assert "another backend instance is already running" in capsys.readouterr().out


def test_lock_is_taken_before_main_import_and_released_after_serve(tmp_path):
    path = tmp_path / "backend.lock"
    events = []
    started = threading.Event()
    held = {}

    def lock_factory(app_dir, frozen):
        events.append("lock")
        held["lock"] = br.acquire_lock_file(path)
        return held["lock"]

    def serve(app):
        assert started.is_set(), "startup_done must be set before serving"
        assert br.acquire_lock_file(path) is None, "lock must be held while serving"
        events.append("serve")

    code = _run(tmp_path, lock_factory, events=events, serve=serve,
                start_watchdog=lambda e: events.append("watchdog"), started=started)

    assert code == 0
    assert events == ["lock", "watchdog", "import_main", "serve"]
    assert held["lock"].released
    after = br.acquire_lock_file(path)
    assert after is not None
    after.release()


def test_lock_is_released_when_startup_fails(tmp_path):
    path = tmp_path / "backend.lock"
    held = {}
    started = threading.Event()

    def lock_factory(app_dir, frozen):
        held["lock"] = br.acquire_lock_file(path)
        return held["lock"]

    def failing_import():
        raise RuntimeError("boom")

    with pytest.raises(RuntimeError):
        _run(tmp_path, lock_factory, import_app=failing_import, started=started)

    assert held["lock"].released
    assert not started.is_set()


def test_dev_run_does_not_start_the_watchdog_by_default(tmp_path, monkeypatch):
    monkeypatch.setattr(br.threading, "Thread", lambda *a, **k: pytest.fail("watchdog thread started in dev"))
    code = _run(tmp_path, lambda app_dir, frozen: br.acquire_lock_file(tmp_path / "x.lock"),
                started=threading.Event())
    assert code == 0


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
