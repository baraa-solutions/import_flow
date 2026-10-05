# Update notice redesign — plan (2026-09-29, v2.1.2 code)

## Current "Remind me later" (facts)
- In-memory only (`updateBannerDismissedProvider`, app_update_providers.dart:63), global (not per version), 24 h window,
  shared by banner and dialog; lost on app restart; survives logout (next user inherits it).
- Mandatory updates: no "Remind me later", dialog cannot be closed, auto-opens once per version.
- A running download continues in the backend; nothing announces "ready" while snoozed.
- Bugs: snooze can last ~48 h (mode not recomputed until the 24 h recheck timer); global snooze hides a newer optional
  version; focus mode unmounts the banner (no mandatory dialog, no recheck); ready never announced; UI gates on
  `isAdmin` while backend gates on `system.update`.
- Size bug: `/status` total = new installer + pre-fetched rollback installer (service.py:882-884); rollback download shows
  as an indeterminate "Verifying…".

## Recommended design (Option 1)
1. Sidebar version pill (always visible, never snoozed): available / mandatory / downloading % / ready / failed; click → dialog.
2. "Updates" section in the About/system-info dialog (existing `AppUpdatePanel`): check now, update from file, rollback.
3. Slim banner only for mandatory, un-snoozed optional, and ready (admins).
4. One-time "update ready" SnackBar with an Install action.
5. `UpdateNotifierHost` always mounted (outside focus mode): recheck timer, mandatory auto-dialog, ready SnackBar.
6. Snooze persisted per version in SharedPreferences; new version clears it; exact 24 h timer.
7. Backend: optional `phase` (`installer` | `rollback_copy`) in the status; total = installer only; determinate
   "Preparing rollback copy" bar.
Alternatives: bell-panel entry (touches notifications feature), or restyle banner only (keeps bugs 3–4).
Effort ≈ 3 dev-days (backend 0.5, Flutter 2.5). Open: what non-admins see; permission-based UI gating.
