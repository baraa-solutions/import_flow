---
name: project-external-contributor-guardrails
description: External vibe coder on Antigravity (2026-10-05); Claude hooks don't protect him; guardrails.py + PR Checks + GitHub Free limits
metadata:
  type: project
---

From 2026-10-05 an external "vibe coder" using Google Antigravity works on the repo. Antigravity reads `AGENTS.md`
and `.agents/rules/*.md` (12k chars per file) but runs none of `.claude/hooks`.

Tool-agnostic guardrails: `scripts/ci/guardrails.py` (pre-commit / pre-push / pr-gate), `.githooks/` (opt-in via
`git config core.hooksPath .githooks`), `.github/workflows/pr_checks.yml` (Backend gate + Flutter analyze; full suites
on label `full-tests`), `.github/CODEOWNERS`, `.agents/rules/GUARDRAILS.md`.

**Why:** the org is on GitHub Free with a private repo, so branch protection, rulesets and required CODEOWNERS reviews
are unavailable (API 403). A Write collaborator could push to main or push a `v*` tag; the publish workflow now
checks the triggering actor (kamalsroor1) and that the tag is on main, but Write = push to main still bypasses
everything.

**How to apply:** the contractor gets Read + fork PRs (or the org upgrades to Team). Review his PRs with
/review-branch and read every diff under `.github/`, `scripts/ci/`, `.githooks/` and the guard tests. Don't enable
`.githooks` on the release machine before reviewing contractor hook changes. Related: [[project-repo-home]].
