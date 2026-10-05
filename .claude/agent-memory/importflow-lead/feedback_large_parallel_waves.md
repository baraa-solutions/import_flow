---
name: feedback-large-parallel-waves
description: Lessons from the 2026-10-05 phases 2-10 review wave (~15 parallel agents) - machine limits, stalled agents, shell escaping, central registry pattern
metadata:
  type: feedback
---

Running ~15 agents in one worktree works if each owns disjoint files and shared files have one owner.

- **Machine:** 24 GB RAM but only a 6 GB pagefile, so commit memory (not RAM) runs out. A RAM watchdog
  (scratchpad ram_watchdog.ps1: kill the largest pytest/flutter_tester when commit < 800 MB) keeps the laptop alive
  but kills test runs (exit 127, no junit). Tell agents: run tests one file at a time in the foreground, never wait on
  background runs. Suggested to the CTO: enlarge the pagefile.
- **Stalled agents:** agents waiting on a killed background shell never wake up (3 sat idle ~3 h). Check file mtimes;
  if idle > 30 min, launch a fresh agent with "inventory what is done, finish the rest" — the old one may resume
  later and collide, so tell the new one to re-read files before editing.
- **Shell escaping:** the Bash tool turns `\n` inside heredoc/python -c into a real newline; agents broke boot and
  l10n files this way. Tell agents to use the Edit tool for code, never sed/heredoc writes.
- **Shared files pattern that worked:** devs never edit modules/common, seed_rbac, docs/*.json; they raise plain
  `{code, message, ...}` dicts and append needs to docs/plans/review-shared-needs.md; the lead registers RBAC codes
  immediately and runs one backend + one Flutter registry agent at the end. l10n: pre-insert per-group marker blocks
  in the three app_localizations files.
- **Agents may commit on their own** (one did): put "do not commit" in every brief.

**Why:** CTO wants maximum parallel throughput ([[feedback-speed-parallel]]) without freezing the laptop.
**How to apply:** reuse this setup for the next review wave (master data, settings, reports).
