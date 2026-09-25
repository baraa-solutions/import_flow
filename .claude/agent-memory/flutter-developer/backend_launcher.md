---
name: backend-launcher
description: How frontend.exe starts/waits for/recovers the local backend.exe (BackendLauncher + BackendStartupGate + Win32 process helpers) and the traps around it
metadata:
  type: project
---

frontend.exe is the launch target for shortcuts and the post-update relaunch (the VBScript launcher is being
retired, 2026-09-25), so it must start backend.exe itself. The backend has its own single-instance mutex.

- `core/services/backend_launcher.dart`: `BackendLauncher` (injectable health checker / starter / process lister /
  killer / file-exists / `LauncherClock`), `backendLauncherProvider` (default `BackendLauncher.disabled()` = ready,
  so tests and web never start anything), `backendStartupProvider`, `recoverBackendOnConnectionError`.
- /health counts as OURS only if `system == 'Sorour Logistics ERP'`; a non-5xx reply without it = foreign
  program on the port -> failed(portInUse). 5xx without marker = down (keep polling). maintenance_mode = up.
- Process detection by FULL path (`<exeDir>\backend.exe`, both PyInstaller onefile processes) via Win32
  (`backend_process_control_ffi.dart`, EnumProcesses + QueryFullProcessImageName, TerminateProcess). Exported
  through a `dart.library.ffi` conditional export so web builds never see dart:ffi. `win32`/`ffi` are direct deps.
  No tasklist (it flashed a console).
- Only the user's Retry (`restartIfStuck`) kills an alive-but-unhealthy backend.exe; automatic re-runs just wait.
- The bare health Dio stays IN main.dart (no_bare_dio allow-list); don't move `Dio(` into the service.
- `api_client.dart` onError (both clients) calls `recoverBackendOnConnectionError` for connectionError/Timeout
  only when status is ready.
- Gate trap: after first ready, ALWAYS return the same `Stack([child, if (!ready) ...overlay])`. Switching between
  `child` and `Stack([child, ...])` reparents the child and drops its state (open tabs/unsaved forms).
- Diagnostics: every decision goes to an injected `LauncherLog` (`launcher_log.dart`); prod writes
  %LOCALAPPDATA%\SorourLogistics\logs\launcher.log (200 KB, one .1 rotation). Tests use `MemoryLauncherLog`.
  A started backend.exe that vanishes from the process list is restarted (max 3 starts per attempt).
- backend.exe is PyInstaller onefile: start it with `includeParentEnvironment: false` + the env from
  `sanitizeBackendEnvironment` (drops `_PYI_*`/`_MEIPASS*`, sets PYINSTALLER_RESET_ENVIRONMENT=1). Setup relaunched
  frontend.exe with the OLD backend's env, so the new backend reused the old _MEI dir (old Alembic files).
  Log removed key names only. Windows arg quoting: `cmd /c "set > \"x\""` breaks; use relative, unquoted targets.
- Tests: fake clock whose `delay` advances `now` instantly; widget tests need two `pump()`s. Real Win32 smoke
  tests in `test/backend_process_control_test.dart` (`@TestOn('windows')`).
- Python-heredoc edit trap: `'$exeDir\backend.exe'` silently became a backspace escape; verify with `od -c`.

**How to apply:** any change to app startup, the relaunch path, or pre-login / connection-error handling.
