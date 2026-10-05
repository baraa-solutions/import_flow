---
name: settlement-form-pitfalls
description: financial_settlement feature - create-payload rules, test seams, legacy overrides that block signature changes
metadata:
  type: project
---

- Create payload goes through `buildSettlementCreatePayload` + `toCreateJson()` (widgets/settlement_form_dialog.dart): never send `amount_egp`, never invent weight/CBM/currency/rate; backend computes money.
- Existing `test/clo02_actual_landed_cost_test.dart` overrides `approveActualLandedCost(required String approvedBy)`; making that param nullable breaks the override. Keep the signature, just do not send `approved_by`.
- Provider tests: `ProviderContainer(overrides: [dioProvider.overrideWithValue(Dio()..httpClientAdapter = stub)])` works without a backend.
- `ApiErrorText.of(l10n, e)` already renders `detail` dicts (code -> catalog, else `message`); use it instead of `$e`.
- Comparison screen once called a non-existent `/financial-settlements` (plural) path; the router prefix is `/financial-settlement`.
**Why:** Phase 9 quality plan FE-01..11. **How to apply:** any new settlement/landed-cost UI.
