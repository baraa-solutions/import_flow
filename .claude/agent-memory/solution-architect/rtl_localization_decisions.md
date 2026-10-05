---
name: rtl-localization-decisions
description: Arabic RTL plan (2026-09-29) - root cause, proposed design decisions, non-obvious Flutter traps (icon double-flip, bidi minus sign, test locale)
metadata:
  type: project
---

RTL plan proposed 2026-09-29 (not yet approved or implemented; check git before relying on this).

Root cause found: MaterialApp in frontend/lib/main.dart has no supportedLocales or localizationsDelegates,
so `locale: ar` resolves to en_US. MaterialApp's own Localizations widget then inserts
Directionality(LTR), which overrides the outer Directionality(rtl) wrapper in main.dart. Every
`Localizations.localeOf` or `Directionality.of` check under MaterialApp comes out as English/LTR.
`context.l10n` still works because AppLocalizationsProvider sits above MaterialApp. The
localization is hand-written (not gen-l10n), and flutter_localizations/intl are not dependencies.

Proposed decisions:
- Fix at the root by adding flutter_localizations and supportedLocales [en, ar]. Do not rewrite the
  ~200 `isAr` call sites.
- Keep Western digits. Use Locale('ar'), not ar_EG.
- Codes (HS, ACID, container, B/L, SWIFT/IBAN) and signed numbers are LTR islands.
- PDF (`pw.`) exports stay independent of Flutter Directionality.
- Add a per-file ratchet guard test (modelled on test/no_bare_dio_test.dart) for non-directional
  EdgeInsets/Alignment/Border patterns.

Traps:
- Material Icons arrow_back/forward, chevron_left/right, navigate_*, first/last_page and *_ios have
  matchTextDirection=true, so they mirror automatically. core/widgets/directional_icon.dart
  flips them again (a double flip). Only keyboard_arrow_* and keyboard_double_arrow_* need a manual flip.
- In RTL, "-1,250.00" renders as "1,250.00-" and "10 - 20" renders reversed. Numeric cells need
  textDirection LTR.
- Existing widget tests pump a bare MaterialApp(locale: ar) and assert English (for example
  pl07_customs_duty_simulation_test.dart). They encode the bug.

**Why:** the CTO wants full Arabic RTL. Future plans in this area should reuse these decisions and
not re-audit from scratch.
**How to apply:** before planning any localization or UI-direction work, check whether the phase-1
wiring has landed (grep supportedLocales in main.dart) and reuse these decisions.
