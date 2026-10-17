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

**Decision 2026-10-06:** the CTO chose to give the contractor **Write on the same repo (branches + PRs) on GitHub
Free, with no branch protection**, against advice. Private forking + fork-PR approval settings were already applied
and left on. Exposure: a Write user can push to main or tags and dispatch workflows, which reaches the
`production-updates` env secrets (UPDATE_SIGNING_KEY_ED25519, HOSTINGER_SSH_KEY, HOSTINGER_KNOWN_HOSTS).

Applied 2026-10-07: ahmedsalahsorour88 = `write` (was `read`). His legacy repo `ahmedsalahsorour88/import_flow` is
PUBLIC and is his `fork` remote: he must never push there. He tends to batch many stacked tasks overnight (23 on
2026-10-06, incl. review-required BE810-T01/T06/T07, and started BEW0-01/05/06) — enforce one-PR-at-a-time and the
review-required stop explicitly in every brief.

Stacked PRs: before `gh pr merge --delete-branch` on a base PR, retarget its dependents with
`gh pr edit <n> --base main` — deleting the base branch via API CLOSES dependents instead of retargeting them
(happened to #23 on 2026-10-07; fixed by recreating the branch ref, reopen, retarget, delete).
CI gate selects tests by changed files and runs with ALLOW_DEV_AUTH_BYPASS=false: contractor "all tests pass" claims
from pr-gate miss callers in other test files — ask for the named tests.

Merge train that works: review with workflows (diff + customs + security, adversarial verify); detect cumulative
branches that all target main (parent = other PR head that is an ancestor) and review only head-diff-from-parent;
merge conflicting approved PRs through one integration branch (Python tests merged per function via AST, never
line-union), run the FULL suite (gate misses callers), then one PR. Merge without --delete-branch when cumulative
dependents exist.

**How to apply:** recommend that the CTO keeps those env secrets out of GitHub between releases (set before Publish,
delete after), and only after he confirms he has an offline copy. Watch main for direct pushes. Review his PRs with
/review-branch and read every diff under `.github/`, `scripts/ci/`, `.githooks/` and the guard tests. Don't enable
`.githooks` on the release machine before reviewing contractor hook changes. Related: [[project-repo-home]].
