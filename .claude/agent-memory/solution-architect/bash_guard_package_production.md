---
name: bash-guard-package-production
description: Bash guard hook blocks any command line that mentions package_production.py, even read-only grep/sed; use the Grep/Read tools instead
metadata:
  type: feedback
---

The project Bash guard (`.claude/hooks/guard_bash.py`) rejects any Bash command whose text contains `package_production.py`, including read-only `grep`. It treats the file as Track 2 (formal release) only.

**Why:** It is a text match meant to stop packaging runs. It does not tell reading apart from running.

**How to apply:** To inspect that file, use the Grep or Read tool, not Bash. Keep it out of batched Bash commands so the other reads in the batch are not blocked with it.
