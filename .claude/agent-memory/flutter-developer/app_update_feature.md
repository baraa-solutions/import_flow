---
name: app-update-feature
description: In-app update UI (features/app_update) — backend owns download/verify/install; provider/widget layout, exit guard, test fakes, open contract gaps
metadata:
  type: project
---

`frontend/lib/features/app_update/` (built 2026-09-24 against plan `docs/plans/update-system-plan.md` §6) replaced
the old production_sync auto-updater + SystemUpdateBanner. Flutter never downloads or hashes: it calls
`/api/v1/app-update/*` via dioProvider and shows state.

- Providers: `updateCheckProvider` (FutureProvider), `updateStatusProvider` (StateNotifier, chained one-shot Timer
  poll only while downloading/verifying/backing_up; `updatePollIntervalProvider`, ms in tests), pure
  `resolveBannerMode` / `resolveUpdateIndicator` (models/update_indicator.dart) + clock provider.
- Redesign 2026-09-29 (plan docs/plans/update-notice-redesign-plan.md, Option 1): `UpdateNotifierHost` (zero-size,
  mounted outside focus mode) owns the 24 h recheck Timer.periodic, mandatory auto-dialog (once/version) and the
  admin "ready" SnackBar (once per user+version, SharedPreferences). `UpdateBanner` is a pure view;
  `UpdateIndicatorPill(compact:)` is the always-visible sidebar state.
- Snooze = `updateSnoozeProvider` (providers/update_snooze_providers.dart): prefs key `app_update_snooze_<userId>`
  = `version|isoUtc`, one-shot expiry Timer, `retainOnly(latest)` awaits the async load first (race with check),
  `switchUser` via `ref.listen(updateUserIdProvider)` resets memory only (keys are per user; a snooze must survive
  logout/login and session expiry). Tests override `updateUserIdProvider`
  (never build real authProvider) and call `SharedPreferences.setMockInitialValues` in setUp.
- Status `phase` (installer | rollback_copy): rollback copy is state `verifying` with its own bytes/total. Download
  sizes go through `displayTotalBytes(installerSizeBytes:)` (older backends summed both files -> 212 MB).
- Widget tests with 24 h timers: end each test with `pumpWidget(SizedBox())` so ProviderScope timers are disposed
  before the pending-timer check; `tester.pump(Duration(hours: 24))` drives the recheck / expiry timers.
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
- `updateStatusProvider` watches `updateUserIdProvider`: logout disposes the notifier + poll timer, nothing is
  fetched while signed out, and mid-download errors are retried only for network/5xx (`isTransientUpdateError`);
  a 401 poll loop re-triggered session expiry every second (review 2026-09-29).
- Host freshness: re-fetch only a provider that exists AND is not loading (the sidebar pill builds before the host
  and creates the check provider in the same frame; a bare `ref.exists` caused a double GET).
- Home mount (2026-09-29): host + PostUpdateNotice are keyed FIRST children of the content Stack. In the Column
  they were re-created on focus toggle only when a conditional child sits after them (tab bar with 2+ tabs):
  unkeyed Column children survive via bottom-up matching otherwise, so remount tests must open a 2nd tab.
  The pill is on its own line above the version row in the 235-px sidebar footer (next to the port badge it overflowed), compact dot in
  the rail; AppUpdatePanel is in `_showSystemInfoDialog` (content wrapped in SingleChildScrollView).
  `test/home_update_mount_test.dart` pumps the real HomeScreen: end with runAsync + pumpAndSettle, then
  `pumpWidget(SizedBox())` + `pump(1s)` or the dashboard's zero-delay Dio timers stay pending. Tests that mount
  HomeScreen need `SharedPreferences.setMockInitialValues({})` (aiAssistantProvider, snooze).
