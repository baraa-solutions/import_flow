---
name: spec
description: Interview the user about a new ImportFlow ERP feature and write a self-contained implementation spec to docs/specs/ before any code is written. Use for large or ambiguous features.
disable-model-invocation: true
argument-hint: "[feature in a few words]"
---

# Feature spec interview

Feature: **$ARGUMENTS**

## 1. Prepare (before asking anything)

- Read the business docs that cover this area: `doc.md`, `docs/01_master_data.md`, the matching
  `docs/phase_XX_*.md` (BP / MD codes), and `.agents/rules/DOMAIN_RULES.md` for customs or landed cost.
- Find the existing modules, endpoints and screens this touches, and the closest existing feature to copy.
- Do not ask the user anything the docs or code already answer.

## 2. Interview (AskUserQuestion, in Egyptian Arabic)

Ask in rounds of 1-4 questions, only about the hard parts, offering concrete options with a recommended
one first. Cover, as relevant:
- Who uses it (role / permission), at which lifecycle stage (GP-002), and what "done" looks like for them.
- Data: which master data it references (by FK), what is required at which stage (GP-001 progressive entry),
  duplicates and uniqueness (GP-003), soft delete / restore, audit trail.
- Money and customs math: which rates come from the HS code, rounding, currency and exchange-rate date.
- UI: which screen, pickers, validations, exports (Excel / PDF), Arabic and English wording.
- Edge cases, failure modes, migration of existing live data, and what is explicitly out of scope.
Stop when every section below can be filled without guessing.

## 3. Write the spec

Save to `docs/specs/<kebab-case-feature>.md` (create the folder if needed), in Arabic prose with English
identifiers:

1. الهدف والمستخدمين — goal, roles, BP / MD codes
2. قواعد العمل — business rules and stage validation
3. البيانات — tables / columns / FKs / constraints / migration
4. الـ API — method, path, permission code, request / response fields, errors
5. الواجهة — screens, widgets, pickers, localization keys, exports
6. الحالات الخاصة — edge cases and failure handling
7. خارج النطاق — out of scope
8. التحقق — backend and frontend tests, plus an end-to-end check that proves the feature works

## 4. Hand off

Show the user the spec path and a 5-line summary. Suggest implementing it in a **fresh session**
("نفّذ docs/specs/<file>.md") so the implementation starts with clean context.
