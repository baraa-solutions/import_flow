---
name: feedback-speed-parallel
description: CTO wants maximum parallelism and the long full test gate only at the end of a batch of work, not after every phase
metadata:
  type: feedback
---

Run big work with several developers in parallel (split backend by module groups with disjoint files) and do NOT
run the ~45-minute full release gate between phases; agents run only their own module tests, and the full gate
runs once at the end (before a release).

**Why:** 2026-09-29 the CTO stopped a running full gate: "مش عاجبني بياخد وقت كبير اوي", "التيست ممكن نخليه ف الاخر".

**How to apply:** split into 3-4 agents with a shared-file rule (one owner per shared file, others report missing
codes instead of editing); targeted tests per agent; full `run_release_tests.py` only when a release is prepared
or the CTO asks. Related: [[feedback-parallel-sessions]].
