---
name: single-language-stale-tests
description: Post single-language-storage (phases A/B/C, 2026-09-29) test failures are usually stale Arabic/legacy fixtures, plus OpenBLAS OOM in the corrupt-DB subprocess test
metadata:
  type: project
---

After the single-language storage rollout (docs/plans/single-language-storage-plan.md, CTO rules 1-3),
tests that assert Arabic system-written text or legacy column layouts fail. Classify before fixing:
- Backend notes/status written by services are English now (rule 1): update the assertion, don't revert the service.
- Flutter ImportFileModel: `current_module` = step ("STEP_xx ..."), `current_stage` = phase title; coded rows
  carry currentStepCode/currentPhaseId/currentStageCode/nextActionCode. Phase titles for coded rows come from
  SystemMessageRenderer.phaseTitle (backend PHASES_DEFINITION), not DisplayNameResolver. Old fixtures that put the
  phase in currentModule and the step in currentStage (old customs_clearance convention) are stale.
- `test_import_main_on_corrupt_db_boots_in_maintenance_mode` "OpenBLAS error: Memory allocation still failed" =
  commit-memory exhaustion in the full run (same machine issue as [[flutter-suite-hang-oom]]); passes alone. The test now
  sets OPENBLAS_NUM_THREADS=1 for its subprocess.

**Why:** 2026-09-30 release gate on 699db0f had 3 backend + 4 flutter failures; all real ones were stale tests, 2 flutter ones never reproduced.
**How to apply:** check `git log -S"<old string>"` on the product line; if the change came from a phase A/B/C commit, update the test.
