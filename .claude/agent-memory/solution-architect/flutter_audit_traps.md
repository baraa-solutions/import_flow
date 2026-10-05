---
name: flutter-audit-traps
description: Traps found auditing Flutter features against backend schemas (silent key drops, fabricated defaults, swallowed lookups)
metadata:
  type: project
---

Flutter-vs-backend contract mismatches are silent: Pydantic schemas ignore unknown keys, so a Flutter payload with wrong
names saves backend defaults (2026-10-05, phase 3: invoice-BL session stored FULLY_MATCHED/score 0 and skipped the sync).

**Why:** no 422 is raised, tests pin the Flutter model to itself, so the bug only shows in data.
**How to apply:** in every Flutter audit, script-diff `json['…']` keys in models/payloads against the `*Create`/`*Response`
field names; also grep for 10+ digit literals, sample company names, and `'Kamal'` (fabricated ACID / reviewer defaults
were found in phase 3); check `catch` blocks that return null on lookups (they turn 500 into "no record" then upsert).
Backend error helper for SnackBars is `ApiErrorText.of(l10n, e)` in `core/localization/api_error_text.dart`.
