---
name: production-sync-retired
description: Dev->prod DB sync, pull, full build and launch were removed from the Flutter production_sync feature; only read-only compare, stats, backups (+restore, manual snapshot) remain
metadata:
  type: project
---

CTO decision 2026-09-24: the product never syncs a dev DB into production. `LocalProcessSyncService`
(io/web), `ProductionSyncService` and `ProductionSyncNotifier` no longer have syncDevToProd / pullProdToDev /
fullBuildAndSync / launchProductionApp; their buttons and l10n keys are gone. `sync_to_production.py` now needs
`--db` + `--confirm` for writes; `--compare` stays read-only and is still used.

**Why:** a dev->prod sync button in a shipped product can overwrite the only production database.
**How to apply:** don't re-add write actions to production_sync; updates go through features/app_update
([[app-update-feature]]). Restore-from-backup was left in place (not in the retirement brief).

Test pitfall: never assert on the machine's real `sorour_logistics.db` / project root in Flutter tests (clean CI
runners have none, and the release runner allows only skips). `LocalProcessSyncService.getDbStats(path)` takes a
path, so tests write a temp file under `Directory.systemTemp.createTempSync` and pass that.
