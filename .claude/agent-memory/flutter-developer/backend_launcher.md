---
name: backend-launcher
description: How frontend.exe starts/waits for/recovers/stops the local backend.exe (BackendLauncher, BackendStartupGate, Toolhelp32 helpers, launcher.log) and the traps around it
metadata:
  type: project
---

frontend.exe is the launch target for shortcuts and the post-update relaunch (the VBScript launcher is being
retired, 2026-09-25), so it must start backend.exe itself. The backend has its own single-instance mutex.

- `core/services/backend_launcher.dart`: `BackendLauncher` (injectable health checker / starter / lister(imageName) /
  killer / file-exists / clock / log / parent env), `backendLauncherProvider` (default `BackendLauncher.disabled()` =
  ready, so tests and web never start anything). `backendStartupProvider` (notifier) is the ONLY thing that calls
  `ensureRunning` at startup and `retry()`; main.dart just overrides the provider. Status = starting/ready/failed(+reason).
- /health counts as OURS only if `system == 'Sorour Logistics ERP'`; a non-5xx reply without it = foreign
  program on the port -> failed(portInUse). 5xx without marker = down (keep polling). maintenance_mode = up.
- Process detection by FULL path (`<exeDir>\backend.exe`, both PyInstaller onefile processes): Toolhelp32 snapshot
  filtered by image name, then QueryFullProcessImageName on those only (`backend_process_control_ffi.dart`; own
  bindings, package:win32 5.x lacks Toolhelp32). `dart.library.ffi` conditional export keeps web builds clean.
  No tasklist/taskkill (console flash, and /IM kills other installs). Window close uses `killOwnBackend()`.
- Only the user's Retry (`restartIfStuck`) kills an alive-but-unhealthy backend.exe; automatic re-runs just wait.
  A started backend.exe that vanishes from the list is restarted (max 3 starts per attempt).
- The bare health Dio stays IN main.dart (no_bare_dio allow-list); don't move `Dio(` into the service.
- `BackendRecoveryInterceptor` (first in both Dio clients) re-runs the launcher on connectionError/Timeout once ready.
- Gate trap: after first ready, ALWAYS return the same `Stack([child, if (!ready) ...overlay])`. Switching between
  `child` and `Stack([child, ...])` reparents the child and drops its state (open tabs/unsaved forms).
- launcher.log: `FileLauncherLog` keeps one RandomAccessFile open, tracks size in memory, rotates once to .1 at
  200 KB, fsyncs only on `flush()` (READY/FAILED/kill). Tests must `close()` it (Windows can't delete open files).
  Test double `_MemoryLog` lives in the test file, not lib/.
- backend.exe is PyInstaller onefile: start it with `includeParentEnvironment: false` + the env from
  `sanitizeBackendEnvironment` (drops `_PYI_*`/`_MEIPASS*`, sets PYINSTALLER_RESET_ENVIRONMENT=1). Setup relaunched
  frontend.exe with the OLD backend's env, so the new backend reused the old _MEI dir (old Alembic files).
  Log removed key names only. Windows arg quoting: `cmd /c "set > \"x\""` breaks; use relative, unquoted targets.
- Tests: `_Harness` fakes /health, the process table, start and kill (optional healthCheck override); fake clock
  whose `delay` advances `now` instantly; widget tests need two `pump()`s. Real Win32 tests in
  `test/backend_process_control_test.dart` (`@TestOn('windows')`). Dio interceptor tests: fake HttpClientAdapter.
- Edit trap: `'$exeDir\backend.exe'` silently became a backspace escape (test guards it); use `p.windows` for paths.

**How to apply:** any change to app startup, the relaunch path, window close, or pre-login / connection-error handling.
