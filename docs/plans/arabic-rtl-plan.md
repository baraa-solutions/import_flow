# Arabic RTL — plan (2026-09-29)

Root cause: `MaterialApp` has no `supportedLocales`/delegates → `ar` falls back to en_US and MaterialApp's own
Directionality forces LTR (overrides the outer RTL wrapper in main.dart). 194 `localeOf=='ar'` checks (84 files) and 65
`Directionality.of` checks are always false today.

Phase 1 (2–3 d): add `flutter_localizations`; `AppLocalizations.supportedLocales` + Global* delegates in MaterialApp;
drop the outer Directionality; `fontFamilyFallback`; fix `DirectionalIcon` double-flip; shell (sidebar, top bar, tabs,
tables, dropdowns, text fields with an LTR option), login, dashboard.
Phase 2 (6–9 d, per module): directional EdgeInsets/Alignment/Border/Positioned (~300 hazards), LTR islands for HS /
ACID / container / B/L / SWIFT / IBAN and signed numbers, LTR wrap for document replicas, 268 English literals → l10n.
Phase 3 (3–4 d): export language decision, main.dart error strings, digit style in Material widgets, guard baseline.
Tests: locale wiring, directional icon, shell RTL layout, LTR islands, ratchet guard test on non-directional APIs.
Decisions needed: exports follow UI language? ship phases 1+2 together or accept interim misalignment?
Details: .claude/agent-memory/solution-architect/rtl_localization_decisions.md
