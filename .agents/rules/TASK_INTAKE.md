# Task intake gate (Antigravity and any external AI agent)

This gate runs **before any code is written**, every time the user asks for a task.
It sits after `.agents/rules/GUARDRAILS.md` (when present) and before `AI_WORKFLOW.md`.

## Where tasks live

| Area | Checklist | Detailed spec |
|---|---|---|
| Frontend (`FE01..FE10`, `FEX`) | `docs/plans/frontend-review/TASKS.md` | linked report section in `docs/plans/frontend-review/*.md` |
| Backend / accounting (`BE..`, `BEX`, `ACC1..ACC3`) | `docs/plans/backend-review/TASKS.md` | linked report section in `docs/plans/backend-review/*.md` |

## Step 0: sync check (every task, before Step 1)

The review side posts merges, merge commits pushed to your branches, rule changes and answers on GitHub
(issue #12 and your PRs). Rule files change on `main`. Check both before starting any task:

```
gh issue view 12 --repo baraa-solutions/import_flow --comments
gh search prs --repo baraa-solutions/import_flow --author @me --review changes_requested --state open
git fetch origin
git diff --stat HEAD origin/main -- AGENTS.md .agents/ .antigravityrules .claude/ docs/plans/
```

- Unread instruction, a "changes requested" review, or a merge commit on one of your branches: handle it first,
  and `git pull` that branch before touching it.
- Rule files changed: pull `origin/main`, re-read `AGENTS.md`, `GUARDRAILS.md`, this file and the changed files.
- Then branch from the latest `origin/main`. First comment of the PR: `Sync check done at <time>: issue #12 read,
  rules at origin/main <short hash>`.

## Step 1: find the task

- If the user gives a **task id** (e.g. `FE03-T02`), search both `TASKS.md` files and the report files for that exact id.
- If the user describes work **in free text**, search both `TASKS.md` files and the reports for a task that covers it
  (same screen / module / problem). Show the user the matching id(s) and confirm which one before starting.

## Step 2: check that the task is explained

A task counts as **explained** only if its report section has all of these:

1. Title and Severity
2. Files to change (exact paths)
3. Steps
4. Acceptance criteria
5. Tests to add
6. Depends on (may be "none")

## Step 3: decide

| Situation | What you do |
|---|---|
| Task found, fully explained, every dependency is `done`, not marked review-required | Start, following `AI_WORKFLOW.md` and `.agents/workflows/run-task.md`. |
| Task **not found** in any `TASKS.md` / report | **STOP. Write no code.** Tell the user (in Egyptian Arabic) "التاسك دي مش موجودة في الخطة". Offer a draft spec in the format above. Add it only after the user says yes, appended to the right `TASKS.md` with status `proposed`. A `proposed` task is not executed until the owner changes it to `todo`. |
| Task found but **not fully explained** (any item of Step 2 missing or vague) | **STOP. Write no code.** List exactly which items are missing and ask the user to complete them, or propose the missing parts for approval. |
| A dependency is not `done` | **STOP.** Name the dependency and its status. |
| Marked `review required` / `needs senior review` (migration, money math, auth, permissions) | **STOP.** Tell the user it needs the senior team, not an external agent. |
| Code already fixed (the problem no longer exists at the cited `file:line`) | **STOP.** Report it with evidence and suggest marking the task `done (already fixed)`. |

## Never

- Never invent a task, widen its scope, or merge two tasks without the user's approval.
- Never change a task's Steps or Acceptance criteria to make your work pass.
- Never set a task to `done` unless every acceptance criterion is met and the tests were run with real numbers.
