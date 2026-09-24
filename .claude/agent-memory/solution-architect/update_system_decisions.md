---
name: update-system-decisions
description: In-app updater / Alembic startup decisions (Phases 2 and 5) and the non-obvious process-lifecycle traps behind them
metadata:
  type: project
---

Decisions from the Phase 2 and Phase 5 spec (2026-09-24): docs/plans/update-system-phase2-5-spec.md. The CTO delegated three decisions: stage-local ignores expiry, rollback re-offers the version, and a failed pre-fetch does not block the update.

- The backend exits about 3 s after frontend.exe dies (watchdog in backend_runner.py). The Flutter app calls exit(0) 800 ms after a 202 response. So all apply/rollback work, including the installer launch, must finish BEFORE the response. Nothing may run in the background after a 202.
  **Why:** any work left to run after the 202 is killed when the backend exits.
- The installer is launched as a child of backend.exe, so `taskkill /T` on backend.exe or frontend.exe in `.iss` StopRunningApp would kill Setup itself. /T was removed; matching by image name already kills both PyInstaller onefile processes.
- Rollback never downloads during the request, because the download can outlast Dio's 180 s timeout. The download job pre-fetches `manifest.previous` into `updates/installers/`. Each applied installer is kept there as the next rollback target.
- The applied manifest's raw bytes are stored in pending_update.json and then last_result.json. Rollback re-verifies the signature and ignores expiry and highest_seen. The latest checked manifest is never used for rollback.
- `%LOCALAPPDATA%\SorourLogistics\updates` is shared between the frozen app and source runs on the same Windows user. The marker is evaluated only when apply_supported is true and the marker's app_dir and db_path match the current process.
- Alembic startup order:
  1. preflight (R10: an unknown revision means maintenance mode before any write)
  2. snapshot
  3. pre_migration backup for unstamped or behind DBs
  4. upgrade for stamped DBs
  5. create_all and additive columns
  6. `stamp head` for fresh or unstamped DBs
  Rule: models must equal head schema. The baseline is e1f2a3b4c5d6, with down_revision d3e4f5a6b7c8.

**How to apply:** future updater, installer or migration plans must keep these invariants. Link: [[auth-enforcement-decisions]].
