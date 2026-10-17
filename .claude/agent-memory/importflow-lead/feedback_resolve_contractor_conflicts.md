---
name: feedback-resolve-contractor-conflicts
description: CTO wants the lead to resolve merge conflicts with main on contractor PRs itself instead of sending them back
metadata:
  type: feedback
---

When an approved contractor PR conflicts with main, resolve it myself (scratch worktree from the PR head, merge
company/main, resolve, run the related tests + boot, push the merge commit to the contractor's branch), then merge.
Do not bounce conflicts back to the contractor.

**Why:** CTO said so on 2026-10-08 ("لو في كونفلكت مع الـ main صلحه انت") — conflicts are mostly shared registries
(system_messages.py, message codes JSON, Dart catalogs, api_error_text.dart) and round-trips slow the merge train.

**How to apply:** registries = keep both sides; duplicated helpers = keep main's canonical one; check for semantic
breaks (tests of an already-merged PR vs a schema the new PR tightens; backend code without Dart catalog entry) and fix
them in the same merge commit. Tell the contractor on issue #12 which branches got a merge commit so he pulls.
Related: [[project-external-contributor-guardrails]].
