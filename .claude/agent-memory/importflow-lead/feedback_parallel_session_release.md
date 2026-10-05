---
name: feedback-parallel-session-release
description: When another Claude session works in the same worktree, commit only own files by path and let the CTO decide which session releases
metadata:
  type: feedback
---

On 2026-10-05 a second session reviewed phases 2-10 in the same worktree while this session finished Phase 1. The CTO chose
"2.3.0 for Phase 1 only", then stopped it: "هنرفع كله مره واحده في السيشن التانيه" (release everything at once from the other session).

**Why:** two sessions releasing from one branch race on version bumps, gates and tags; the boot hook also fails on the other
session's half-written files, which is not ours to fix.

**How to apply:** detect foreign edits (git status outside own scope, new docs/plans files); commit own files by explicit path;
never touch or "fix" the other session's files; ask the CTO which session owns the release; run gates in a clean detached worktree.
Kill only own orphaned processes (a stale `flutter test` from a subagent held the Flutter lock and froze the gate for an hour).
Related: [[feedback-parallel-sessions]], [[feedback-speed-parallel]].
