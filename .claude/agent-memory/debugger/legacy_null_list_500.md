---
name: legacy-null-list-500
description: List endpoint 500 = ResponseValidationError on NULL in a non-Optional response field; startup ADD COLUMN leaves old rows NULL; hand-seeded SQL fakes it
metadata:
  type: project
---

A list endpoint returning 500 with `ResponseValidationError ... 'input': None` comes from one of two causes:
1. **Real legacy shape:** the startup upgrade (schema_upgrade_service step 4b, `add_column_ddl`) adds a column that
   has only a Python `default=` (no `server_default`) as nullable with no DEFAULT, so pre-existing rows read NULL.
   Fix on read with `modules/common/legacy_rows.LegacyRowTolerantModel` as the Response base (already used by
   customs clearance, warehouse receiving and freight booking).
2. **Seed artifact:** raw INSERT scripts skip ORM defaults (e.g. created_at, created_by, status), which the app always writes.

**Why:** in the 2026-10-05 screenshot run, 4 lists 500'd in both builds; only some fields were real legacy shapes.
**How to apply:** classify each failing field with `git log --reverse -S"    <col> = Column" -- <model.py>`
compared with the table's creation commit. A later column means legacy data can hit it. Also check whether
an update path keeps an explicit null on a nullable column. In seed scripts, fill the audit columns, or the
capture shows false 500s.
Second cause of the same symptom: a Response that inherits from the Create/Base schema re-runs input rules on
read (ACID exactly 19 digits, amount gt=0, nested TierRateItem from_day>=1). Fix with `@read_model` from the same
module; it keeps validators declared on the Response class itself. Money/rate fields are never default-filled;
declare them `Optional[float]` (lead decision, 2026-10-05: never show a fabricated 1.0 FX rate or 0.0 amount).
Gotcha: Git Bash rewrites `/api/...` arguments into Windows paths; set `MSYS_NO_PATHCONV=1`.
