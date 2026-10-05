---
description: Execute one planned task by id (e.g. /run-task FE03-T02) after checking it exists and is fully specified
---

1. Read `.agents/rules/GUARDRAILS.md` (if present), then `.agents/rules/TASK_INTAKE.md`, and apply the intake gate to the task id
   (or description) the user gave. If the gate says STOP, report to the user in Egyptian Arabic and end here.
2. Read the task's full section in its report: Files to change, Steps, Acceptance criteria, Tests to add, Out of scope.
3. Open every cited file and confirm the problem still exists. If it is already fixed, report it and end here.
4. Create the branch `fix/<task-id-lowercase>` from the latest `main`.
5. Change only the files the task lists. Note any unrelated problem in your final message and leave it unfixed.
6. Add the tests from "Tests to add", then follow `.agents/workflows/pre-pr-check.md`. If that file does not exist yet,
   run `flutter analyze` and `flutter test` on the touched feature/test files (frontend), or `pytest <touched test files>
   --junitxml=<scratch>.xml` with a scratch `DATABASE_PATH` (backend). Record the exact counts.
7. Set the task's status in its `TASKS.md` from `todo` to `done (<branch>)`.
8. Commit with Conventional Commits in English, with no AI attribution. Push the branch and open a PR to `main`.
   Do not merge it.
9. Report in Egyptian Arabic: files changed, the exact test counts, and anything skipped and why.
