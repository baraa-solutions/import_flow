---
name: ruling-be67-t01-tariff-permissions
description: BE67-T01 (PR #63) customs_tariff router permissions + route order; no money-math change, approved on money lens
metadata:
  type: project
---

2026-10-09, PR #63 commit 73973614: router-only change (require_permission view/edit, simulate-file -> customs_clearance.update; /export-template and /fee-codes moved above /{tariff_id}). No calc/service change.
The export-template CSV sample rates (14.0 VAT etc.) are pre-existing template rows, never fed into the engine — not a hard-coded-rate violation.

**Why:** keep consistent if a later PR touches the template or claims those literals are rates.
**How to apply:** treat template sample rows as documentation data; flag only if the engine reads them. Related: [[ruling-be67-t04-simulate-file]].
