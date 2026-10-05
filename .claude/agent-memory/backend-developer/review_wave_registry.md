---
name: review-wave-registry
description: How shared message codes / enum sets / system parameters are registered centrally, and the guard tests that catch unregistered codes
metadata:
  type: project
---

Central registries (owner: modules/common): `system_messages.CATALOG` (+ `python -m modules.common.system_messages`
regenerates docs/system_message_codes.json), `enum_codes.LABELS_EN/_LEGACY` (+ `python -m modules.common.enum_codes`),
`system_parameters.DEFAULT_PARAMETERS` (seeded insert-only on every startup by `MasterDataSyncService.sync_all`: no
migration needed for a new key; tests counting seeded rows use `len(sp.DEFAULT_PARAMETERS)`).

- `tests/unit/test_review_wave_codes.py` AST-scans modules for plain-dict codes (`detail={"code"}`, `message_code=`,
  `msg_code`, `*_error(...)`, `_message(...)`, module constants and IfExp resolved). A module that adds a new coded
  error fails it until the code is registered. Non-message codes go to `NOT_MESSAGE_CODES` (PASSWORD_CHANGE_REQUIRED).
- Contract params = template placeholders only; Flutter parity test demands every placeholder is consumed in ar+en,
  so one call site shape per code. Multi-shape call sites get a variant code (`*_EXPECTED`, `SETTLEMENT_COST_ALREADY_APPROVED`)
  and an entry in `KNOWN_PARAM_GAPS` until the module switches.
- Registering an enum type flips module delegations: `financial_approval.validators.normalize_payment_type` switches to
  `enum_codes.normalize` once PAYMENT_TYPE exists (keep alias parity). Every new enum type breaks the Flutter
  `enum_codes_parity_test.dart` until `domain_enum_labels.dart` maps it (or lists it as backend-only).
- Other agents add codes mid-task (SDU_NO_SHIPPING_RECORD appeared during the 2026-10-05 wave): rerun the scan last.

**Why:** the review wave left ~100 codes as plain dicts; the scan keeps the catalog complete from now on.
**How to apply:** when adding coded errors in a module, register them in the same change or the scan test fails.
