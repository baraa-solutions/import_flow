---
name: feedback-parallel-sessions
description: The CTO may run a second Claude session (e.g. /simplify) in the same worktree; check for foreign edits before committing
metadata:
  type: feedback
---

The CTO sometimes runs another team/session in the same worktree at the same time (2026-09-25: a `/simplify` pass edited ~40
files including DB-safety code while my agents were working). He accepted those edits.

**Why:** unexplained edits can silently weaken production-DB safety code or mix with my agents' changes in one file.
**How to apply:** before every commit, compare `git status` with what my agents reported; if foreign edits exist, say so, and
before committing them run a diff review focused on DB-safety rules (plan §0) plus the full suites. Never revert them myself.

Update 2026-09-25: the CTO asked me to own `/simplify` myself — it is now a step in my operating loop (after implement,
before review; see .claude/agents/importflow-lead.md), so he no longer needs a second team for it.
