---
description: Run the ImportFlow guardrails before saying "done" or opening a Pull Request
---

1. Make sure the local guards are on: `git config core.hooksPath .githooks`
2. Sync with main: `git fetch` then merge `<company remote>/main` into the task branch and resolve conflicts.
3. Run the backend gate (boot check, single Alembic head, auth/catalog guard tests, tests of the touched modules):
   `python scripts/ci/guardrails.py pr-gate`
4. For every Flutter feature folder you touched: `cd frontend && flutter analyze lib/features/<feature>` and
   `flutter test test/<the matching test file>.dart -j 1`
5. If anything fails: fix the code (never weaken or delete a test), then repeat from step 3.
6. Review your own diff against `.agents/rules/GUARDRAILS.md` and the checklist in `.agents/rules/AI_WORKFLOW.md`
   section 7. List every protected path you touched; the owner must review those.
7. Append a short entry to `history/YYYY-MM-DD.md` (append-only).
8. Report to the user in Egyptian Arabic: files changed, the exact numbers each command printed, open questions.
   Push your branch and open a PR to `main` only when the user asks.
