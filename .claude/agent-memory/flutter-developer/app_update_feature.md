---
name: app-update-feature
description: In-app update UI (features/app_update) — backend owns download/verify/install; provider/widget layout, exit guard, test fakes, open contract gaps
metadata:
  type: project
---

`frontend/lib/features/app_update/` (built 2026-09-24 against plan `docs/plans/update-system-plan.md` §6) replaced
the old production_sync auto-updater + SystemUpdateBanner. Flutter never downloads or hashes: it calls
`/api/v1/app-update/*` via dioProvider and shows state.

- Providers: `updateCheckProvider` (FutureProvider, re-fetched by UpdateBanner on mount + 24 h Timer.periodic in
  widget state, NOT in the provider, so tests have no pending timers), `updateStatusProvider` (StateNotifier,
  chained one-shot Timer poll only while downloading/verifying/backing_up; interval via
  `updatePollIntervalProvider`, override to ms in tests), `resolveBannerMode` pure function + clock provider.
- Mount freshness without a double GET: capture `ref.exists(provider)` in `initState` (before build creates it) and
  only invalidate / `refresh()` post-frame when it already existed; a provider first created by the build (or
  the StatusNotifier constructor) already fetches. Widget tests assert `checkCalls` / `statusCalls` for this.
- `rollbackCandidateProvider` deliberately calls `service.lastResult()` itself instead of watching the shared
  (non-autoDispose) `lastUpdateResultProvider`: watching would reuse a cached/errored last-result on dialog open.
- `appExitProvider` wraps `exit(0)` and skips under FLUTTER_TEST / web; widget tests override it with a counter.
- Admin gate = `canInstallUpdatesProvider` (user.isAdmin) as proxy for `system.update`; 403 -> localized
  `updateNoPermission` (backend 403 detail is English), other errors show backend `detail`.
- Test fake: `frontend/test/helpers/fake_app_update_service.dart` (`implements AppUpdateService`, status sequence).
- Contract gap: `last-result` has no `backup_file`; rollback candidate is read from optional
  `last-result.backup_file` or newest history `backup_ok` event detail. Confirm with backend before relying on it.
- `last-result.kind` ("update" | "rollback", null on older backends): rollback is offered only when
  `UpdateLastResult.allowsRollback` (kind != rollback) — enforced in `RollbackCandidate.resolve`, the candidate
  provider, the panel button and the failed-update SnackBar action. Rollback results get their own messages.
- ProductionSyncScreen opens the full panel via `showAppUpdatePanelDialog` (header had no room; embedding the
  panel risked overflow in its 800x600 widget tests).

**Why:** the old updater launched installers after a size check only; the new trust model lives in the backend.
**How to apply:** extend these providers/widgets for update work; never add Dio downloads or crypto in Dart.
