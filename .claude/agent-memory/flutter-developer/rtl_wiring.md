---
name: rtl-wiring
description: Arabic RTL phase 1 (2026-09-29) - AppLocales wiring, localizedApp test helper, DirectionalIcon rule, LTR islands, rtl guard ratchet, digits finding, InkWell radius trap
metadata:
  type: project
---

Phase 1 of docs/plans/arabic-rtl-plan.md landed on feat/update-notice-rtl-p1 (2026-09-29; check git before relying on it).
This supersedes the "bare MaterialApp(locale: ar) = en_US" trap in [[flutter-344-pitfalls]] for the REAL app. Bare test
MaterialApps still fall back to en_US.

- `core/localization/app_locales.dart`: `AppLocales.supportedLocales` [en, ar] + Global* delegates; main.dart passes both
  and has no outer Directionality. Tests: `test/helpers/localized_app.dart` `localizedApp(home:, locale:)` mirrors main.dart.
- Digits: plain `ar` gives Western digits in Material (formatDecimal, pageRowsInfoTitle, time "2:05 م"); `ar_EG` gives
  Arabic-Indic. Never switch to ar_EG.
- DirectionalIcon: glyphs with `IconData.matchTextDirection` (arrow_*, chevron_*, navigate_*, first/last_page) are mirrored
  by Icon itself; only keyboard_(double_)arrow_*, double_arrow, menu_open are flipped manually. Never swap
  `rtl ? chevron_left : chevron_right` by hand: it double-flips. Icon inserts its own Transform, so tests must look for
  Transforms ABOVE the Icon.
- LTR islands: `CustomTextField(textDirection:)`, `CopyableText(textDirection:)`, `EnterpriseColumn(isNumeric: true)`.
  EnterpriseColumn.alignment is now AlignmentGeometry (default AlignmentDirectional.centerStart).
- `InkWell.borderRadius` is a physical BorderRadius: use `BorderRadiusDirectional...resolve(Directionality.of(context))`.
- Guard: test/rtl_directional_guard_test.dart + test/rtl_directional_baseline.json (per-file ratchet; fails on growth AND on
  shrink). Regenerate: `UPDATE_RTL_BASELINE=1 flutter test test/rtl_directional_guard_test.dart`.
- HomeScreen widget tests need `SharedPreferences.setMockInitialValues({})` (aiAssistantProvider reads prefs);
  sidebar_localization_test / inquiries_hub_navigation_test lack it and fail at HEAD.

**Why:** the RTL fix is at the root; phase 2 (per-module hazards, 268 literals) builds on these pieces.
**How to apply:** use localizedApp for any Arabic widget test; use the directional APIs or the guard fails.
