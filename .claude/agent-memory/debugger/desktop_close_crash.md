---
name: desktop-close-crash
description: Installed frontend.exe white-screen/hang ~20s then crash on close — window_manager 0.3.9 destroy() (PostQuitMessage) -> AV flutter_windows.dll+0x1d7b0, then 0xC000041D
metadata:
  type: project
---

Signature (Event 1000 / WER AppCrash_frontend.exe): c0000005 at flutter_windows.dll+0x1d7b0 (engine ts 6a4416db),
then ~20 s later c000041d, SAME pid. Older engine 6a8f3f3b: offset 0x1e220. Window is "Not Responding"/white in between.

Cause (verified 2026-10-05): onWindowClose in frontend/lib/main.dart ends with `windowManager.destroy()`, which in
window_manager 0.3.9 is `PostQuitMessage(0)` — the message loop exits while the HWND + Flutter engine are alive, the engine
is torn down afterwards from the window destructor. Minimal app in scratch: destroy() -> 0xC000041D after 20 s every run;
`setPreventClose(false)` + `close()` -> exit 0 in 0.5 s.

Fixed 2026-10-05 (uncommitted at the time): close goes through `closeMainWindowSafely` in
frontend/lib/core/services/app_window_close.dart; runner main.cpp got a `Local\SorourLogisticsFrontend` mutex
(release/profile only). Runner C++ changes can be verified without touching the app: copy main.cpp into a
`flutter create` scratch app (same template window class) and build there.

**Why:** reported by the CTO as "closes by itself / white screen and hangs" (v2.1.2).
**How to apply:** correlate crash times with `backups/psync_*_manual_dev_*.db` (the close handler's backup, written ~1 s
before the crash). Repro: launch a Release frontend.exe, `CloseMainWindow()`, check exit code. Builds from the scratchpad
need a short path (`subst Q:`) — MAX_PATH. This dev machine also runs near commit exhaustion (Win32 1455 / 0xC0000142),
see [[flutter-suite-hang-oom]].
