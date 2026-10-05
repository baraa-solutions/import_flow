"""
ImportFlow ERP — Standalone Backend Entrypoint
Runs FastAPI with Uvicorn inside PyInstaller bundle or local python.

DB safety (frontend.exe now starts backend.exe itself):
  S1  Single instance. `from main import app` runs SchemaUpgradeService (backup + Alembic) at import
      time, before uvicorn binds the port, so two backend.exe started together (double-clicked
      shortcut) would both migrate the same database. `run()` therefore takes a single-instance lock
      BEFORE importing main: a Windows named mutex when frozen, otherwise (dev / non-Windows / mutex
      failure) an exclusive lock on a lock file. A second instance logs one line and exits 0.
      The lock is held for the process lifetime; the OS drops it if the process dies.
  S2  The frontend watchdog never exits while the startup upgrade runs: it only acts once
      `startup_done` is set (after `from main import app` returned), then keeps its 3 s behaviour.
      It watches the frontend.exe that started this backend through a process handle (parent chain:
      python child -> PyInstaller bootloader -> frontend.exe). Only when no such ancestor is found
      (started by hand / an old launcher) does it fall back to polling `tasklist`: spawning tasklist
      every 3 s failed under memory pressure (0xC0000142 / WinError 8 in backend_server.log).
  S3  The frozen backend drops the PyInstaller onefile bootloader state (_PYI_*, _MEIPASS*) from its
      own environment before anything can spawn a child. Otherwise Setup -> frontend.exe -> the NEW
      backend.exe inherits it and reuses the OLD _MEI extraction (old alembic/versions: no migration).
"""
import sys
import os
import asyncio
import hashlib
import tempfile
import threading
import time
import warnings
from pathlib import Path
from typing import Callable, Dict, Optional, Tuple

from utils.db_safety import app_base_dir, is_frozen_build, reset_pyinstaller_environment

# Suppress deprecation warnings on Windows
warnings.filterwarnings("ignore", category=DeprecationWarning)

MUTEX_NAME = "Local\\SorourLogisticsBackend"
LOCK_FILE_NAME = "backend.lock"
ERROR_ALREADY_EXISTS = 183
WATCHDOG_POLL_SECONDS = 3.0
WATCHDOG_GRACE_SECONDS = 120.0
DEFAULT_PORT = int(os.getenv("PORT", "28080"))
FRONTEND_IMAGE_NAME = "frontend.exe"
TASKLIST_FRONTEND = ["tasklist", "/FI", f"IMAGENAME eq {FRONTEND_IMAGE_NAME}"]
FRONTEND_ANCESTOR_MAX_DEPTH = 4


class SafeLogStream:
    def __init__(self, file_path=None):
        self.file_path = file_path
        self._file = None
        if file_path:
            try:
                self._file = open(file_path, "a", encoding="utf-8")
            except Exception:
                self._file = None

    def write(self, message):
        if self._file:
            try:
                self._file.write(message)
                self._file.flush()
            except Exception:
                pass

    def flush(self):
        if self._file:
            try:
                self._file.flush()
            except Exception:
                pass

    def isatty(self):
        return False


# ------------------------------------------------------------------------------------------------
# S1 single-instance lock
# ------------------------------------------------------------------------------------------------
class InstanceLock:
    """A held single-instance lock. `release()` is idempotent."""

    def __init__(self, kind: str, release_fn: Callable[[], None], description: str):
        self.kind = kind
        self.description = description
        self._release_fn = release_fn
        self._released = False

    @property
    def released(self) -> bool:
        return self._released

    def release(self) -> None:
        if self._released:
            return
        self._released = True
        self._release_fn()


def acquire_named_mutex(name: str = MUTEX_NAME):
    """Windows named mutex. Returns an InstanceLock, None if another process holds it,
    or raises OSError when the mutex cannot be created (caller falls back to the lock file)."""
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateMutexW.restype = wintypes.HANDLE
    kernel32.CreateMutexW.argtypes = (wintypes.LPVOID, wintypes.BOOL, wintypes.LPCWSTR)
    kernel32.CloseHandle.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)

    handle = kernel32.CreateMutexW(None, False, name)
    error = ctypes.get_last_error()
    if not handle:
        raise OSError(error, f"CreateMutexW({name}) failed")
    if error == ERROR_ALREADY_EXISTS:
        kernel32.CloseHandle(handle)
        return None
    # The named object lives while any handle to it is open: holding the handle is the lock.
    return InstanceLock("mutex", lambda: kernel32.CloseHandle(handle), name)


def acquire_lock_file(path: Path):
    """Exclusive non-blocking lock on byte 0 of `path` (msvcrt on Windows, fcntl elsewhere).
    Returns an InstanceLock, or None if another process holds the lock. The file is never deleted
    (deleting it would let a third process lock a new inode while the first still runs)."""
    path = Path(path)
    fd = os.open(str(path), os.O_RDWR | os.O_CREAT, 0o644)
    try:
        if sys.platform == "win32":
            import msvcrt

            os.lseek(fd, 0, os.SEEK_SET)
            msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
        else:
            import fcntl

            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(fd)
        return None

    def _release() -> None:
        try:
            if sys.platform == "win32":
                import msvcrt

                os.lseek(fd, 0, os.SEEK_SET)
                msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
            else:
                import fcntl

                fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)

    return InstanceLock("file", _release, str(path))


def default_lock_file_path(app_dir: Path, frozen: bool) -> Path:
    """{app}\\backend.lock for the installed app; a per-checkout file in the temp dir for dev runs
    (keeps the repo clean)."""
    if frozen:
        return Path(app_dir) / LOCK_FILE_NAME
    digest = hashlib.sha256(str(Path(app_dir).resolve()).lower().encode("utf-8")).hexdigest()[:16]
    return Path(tempfile.gettempdir()) / f"sorour_backend_{digest}.lock"


def acquire_single_instance_lock(app_dir: Path, frozen: bool, platform: str = sys.platform,
                                 mutex_name: str = MUTEX_NAME, lock_path: Optional[Path] = None):
    """Named mutex for the frozen Windows app, lock file otherwise or when the mutex fails.
    Returns the held InstanceLock, or None when another backend instance already runs."""
    if frozen and platform == "win32":
        try:
            return acquire_named_mutex(mutex_name)
        except OSError as exc:
            print(f"[backend_runner] named mutex unavailable ({exc}); using the lock file")
    return acquire_lock_file(lock_path or default_lock_file_path(app_dir, frozen))


# ------------------------------------------------------------------------------------------------
# S2 frontend watchdog
# ------------------------------------------------------------------------------------------------
def is_frontend_running() -> bool:
    import subprocess

    flags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    output = subprocess.check_output(TASKLIST_FRONTEND, creationflags=flags).decode("utf-8", errors="ignore")
    return "frontend.exe" in output


def find_ancestor_pid(process_table: Dict[int, Tuple[int, str]], start_pid: int,
                      image_name: str = FRONTEND_IMAGE_NAME,
                      max_depth: int = FRONTEND_ANCESTOR_MAX_DEPTH) -> Optional[int]:
    """Nearest ancestor of `start_pid` whose image is `image_name` (case-insensitive), or None.
    `process_table` maps pid -> (parent pid, image name). Stops on a missing parent, a cycle
    or after `max_depth` hops."""
    wanted = image_name.lower()
    seen = {start_pid}
    pid = start_pid
    for _ in range(max_depth):
        entry = process_table.get(pid)
        if entry is None:
            return None
        parent = entry[0]
        if parent <= 0 or parent in seen:
            return None
        seen.add(parent)
        parent_entry = process_table.get(parent)
        if parent_entry is None:
            return None
        if parent_entry[1].lower() == wanted:
            return parent
        pid = parent
    return None


def windows_process_table() -> Dict[int, Tuple[int, str]]:
    """pid -> (parent pid, image name) from a Toolhelp32 snapshot (no child process)."""
    import ctypes
    from ctypes import wintypes

    TH32CS_SNAPPROCESS = 0x00000002
    INVALID_HANDLE_VALUE = wintypes.HANDLE(-1).value

    class PROCESSENTRY32W(ctypes.Structure):
        _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
                    ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_size_t),
                    ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                    ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", ctypes.c_long),
                    ("dwFlags", wintypes.DWORD), ("szExeFile", wintypes.WCHAR * 260)]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel32.CreateToolhelp32Snapshot.argtypes = (wintypes.DWORD, wintypes.DWORD)
    kernel32.Process32FirstW.argtypes = (wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W))
    kernel32.Process32NextW.argtypes = (wintypes.HANDLE, ctypes.POINTER(PROCESSENTRY32W))
    kernel32.CloseHandle.argtypes = (wintypes.HANDLE,)

    snapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if not snapshot or snapshot == INVALID_HANDLE_VALUE:
        raise ctypes.WinError(ctypes.get_last_error())
    table: Dict[int, Tuple[int, str]] = {}
    try:
        entry = PROCESSENTRY32W()
        entry.dwSize = ctypes.sizeof(PROCESSENTRY32W)
        more = kernel32.Process32FirstW(snapshot, ctypes.byref(entry))
        while more:
            table[int(entry.th32ProcessID)] = (int(entry.th32ParentProcessID), entry.szExeFile)
            more = kernel32.Process32NextW(snapshot, ctypes.byref(entry))
    finally:
        kernel32.CloseHandle(snapshot)
    return table


class ProcessHandleWatch:
    """Holds a handle on one process (so its pid cannot be recycled under us) and reports whether it
    still runs: OpenProcess once, then GetExitCodeProcess (+ a zero-timeout wait) on every tick."""

    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    SYNCHRONIZE = 0x00100000
    STILL_ACTIVE = 259
    WAIT_TIMEOUT = 0x102

    def __init__(self, pid: int):
        import ctypes
        from ctypes import wintypes

        self.pid = pid
        self._ctypes = ctypes
        k = ctypes.WinDLL("kernel32", use_last_error=True)
        k.OpenProcess.restype = wintypes.HANDLE
        k.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
        k.GetExitCodeProcess.restype = wintypes.BOOL
        k.GetExitCodeProcess.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD))
        k.WaitForSingleObject.restype = wintypes.DWORD
        k.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
        k.CloseHandle.argtypes = (wintypes.HANDLE,)
        self._k = k
        self._code = wintypes.DWORD()
        handle = k.OpenProcess(self.PROCESS_QUERY_LIMITED_INFORMATION | self.SYNCHRONIZE, False, pid)
        if not handle:
            raise ctypes.WinError(ctypes.get_last_error())
        self._handle = handle

    def is_running(self) -> bool:
        if not self._k.GetExitCodeProcess(self._handle, self._ctypes.byref(self._code)):
            raise self._ctypes.WinError(self._ctypes.get_last_error())
        if self._code.value != self.STILL_ACTIVE:
            return False
        # A process may exit with code 259 itself: the wait state is authoritative.
        return self._k.WaitForSingleObject(self._handle, 0) == self.WAIT_TIMEOUT

    def close(self) -> None:
        if self._handle:
            self._k.CloseHandle(self._handle)
            self._handle = None


def select_frontend_check(platform: str = sys.platform,
                          own_pid: Optional[int] = None,
                          process_table: Optional[Callable[[], Dict[int, Tuple[int, str]]]] = None,
                          open_watch: Optional[Callable[[int], ProcessHandleWatch]] = None,
                          fallback: Optional[Callable[[], bool]] = None) -> Callable[[], bool]:
    """The watchdog's "is the frontend still running?" check: a handle on the frontend.exe that
    started this backend when it can be found, otherwise the old tasklist poll. Never raises."""
    fallback = fallback or is_frontend_running
    if platform != "win32":
        return fallback
    try:
        table = (process_table or windows_process_table)()
        frontend_pid = find_ancestor_pid(table, own_pid if own_pid is not None else os.getpid())
        if frontend_pid is None:
            print("[backend_runner] watchdog: no frontend.exe ancestor; polling tasklist")
            return fallback
        watch = (open_watch or ProcessHandleWatch)(frontend_pid)
    except Exception as exc:  # noqa: BLE001 - any failure keeps the old behaviour
        print(f"[backend_runner] watchdog: frontend handle unavailable ({exc}); polling tasklist")
        return fallback
    print(f"[backend_runner] watchdog: watching frontend.exe pid {frontend_pid}")
    return watch.is_running


def exit_cleanly() -> None:
    # WAL checkpoint before the hard exit (A17). WAL commits are atomic either way; this only
    # folds the -wal file back into the DB so the file on disk is self-contained.
    try:
        from database.database import DB_PATH
        from utils.db_safety import checkpoint_wal
        checkpoint_wal(DB_PATH)
    except Exception as exc:  # noqa: BLE001 - never block shutdown
        print(f"[backend_runner] WAL checkpoint skipped: {exc}")
    os._exit(0)


def frontend_watchdog(started: threading.Event,
                      frontend_running: Callable[[], bool] = is_frontend_running,
                      exit_fn: Callable[[], None] = exit_cleanly,
                      sleep: Callable[[float], None] = time.sleep,
                      clock: Callable[[], float] = time.time,
                      poll_seconds: float = WATCHDOG_POLL_SECONDS,
                      grace_seconds: float = WATCHDOG_GRACE_SECONDS) -> None:
    """Shuts the backend down when frontend.exe exits (or never shows up within the grace period).
    Never acts before `started` is set: exiting mid-Alembic would interrupt the startup upgrade."""
    frontend_seen = False
    grace_until: Optional[float] = None
    while True:
        sleep(poll_seconds)
        try:
            running = frontend_running()
        except Exception as exc:  # noqa: BLE001 - check hiccup: try again next tick
            print(f"[backend_runner] watchdog check failed: {exc}")
            continue
        if running:
            frontend_seen = True
        if not started.is_set():
            continue  # startup upgrade still running: never exit here
        if grace_until is None:
            grace_until = clock() + grace_seconds
        if running:
            continue
        if frontend_seen:
            # Frontend was running and has now closed
            exit_fn()
            return
        if clock() > grace_until:
            # Frontend never launched within the grace period after startup
            exit_fn()
            return


def start_watchdog_thread(started: threading.Event) -> None:
    """Default watchdog starter for the frozen app. The check is chosen inside the thread, so the
    process snapshot never delays startup."""
    def _watch() -> None:
        frontend_watchdog(started, frontend_running=select_frontend_check())

    threading.Thread(target=_watch, name="frontend-watchdog", daemon=True).start()


# ------------------------------------------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------------------------------------------
def _import_app():
    from main import app

    return app


def _serve(app) -> None:
    import uvicorn

    # log_config=None prevents the isatty crash in windowed mode
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=DEFAULT_PORT,
        log_config=None,
        use_colors=False,
        access_log=False,
    )


def _prepare_frozen_process(app_dir: Path) -> None:
    os.chdir(app_dir)
    sys.path.insert(0, str(app_dir))
    if hasattr(sys, "_MEIPASS"):
        sys.path.insert(0, str(sys._MEIPASS))
    # Safe logging stream for windowed/noconsole mode
    safe_stream = SafeLogStream(app_dir / "backend_server.log")
    sys.stdout = safe_stream
    sys.stderr = safe_stream
    sys.stdin = SafeLogStream()


def run(frozen: Optional[bool] = None,
        app_dir: Optional[Path] = None,
        lock_factory: Callable[..., Optional[InstanceLock]] = acquire_single_instance_lock,
        import_app: Callable[[], object] = _import_app,
        serve: Callable[[object], None] = _serve,
        start_watchdog: Optional[Callable[[threading.Event], None]] = None) -> int:
    """`start_watchdog` defaults to `start_watchdog_thread` when frozen and to none in dev."""
    if frozen is None:
        frozen = is_frozen_build()
    if app_dir is None:
        app_dir = app_base_dir()
    if start_watchdog is None and frozen:
        start_watchdog = start_watchdog_thread

    if frozen:
        reset_pyinstaller_environment()  # S3: before anything can spawn a child

    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

    if frozen:
        _prepare_frozen_process(app_dir)
    elif str(app_dir) not in sys.path:
        sys.path.insert(0, str(app_dir))

    # S1: the lock comes BEFORE `from main import app` (which runs the startup upgrade).
    lock = lock_factory(app_dir, frozen)
    if lock is None:
        print("[backend_runner] another backend instance is already running; exiting without touching the database")
        return 0

    try:
        startup_done = threading.Event()  # set once `from main import app` (startup upgrade) returned
        if start_watchdog is not None:
            start_watchdog(startup_done)

        app = import_app()
        startup_done.set()  # S2: from here on the watchdog may shut the process down
        serve(app)
        return 0
    finally:
        lock.release()


if __name__ == "__main__":
    sys.exit(run())
