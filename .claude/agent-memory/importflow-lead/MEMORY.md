# importflow-lead memory

## Project state
- Update system live (v2.1.x → v2.2.0 published 2026-10-05). Sandbox E2E harness: D:\importflow_rehearsal\sandbox\run_e2e.ps1
  (old 1.0.58 → Setup wizard → in-app update from staging https://kamal-sroor.online/importflow/rehearsal/, rehearsal key only).
- Phase 1 review committed (ff2f522..06d4ead, version bump 2.3.0 in be74861) but not released; phases 2-10 review wave
  (2026-10-05) is uncommitted except 4d22473. Tracker: docs/plans/review-coverage.md; next: master data, settings, reports.
- Auth: router-level get_current_user + per-route require_permission; tests use the conftest seam
  (`_dev_bypass_fallback_user`); `test_route_auth_coverage.py` + `test_permission_codes_in_catalog.py` guard routes.
- Old installs may have no admin: break-glass admin in sync_system_users; support tool scripts/support/promote_user_to_admin.bat.
- DANGER: modules/production_sync ignores DATABASE_PATH and targets the real root/dist DBs — never click it in automated runs.
- Every `import main` stamps / snapshots the DB it points at: always use a scratch DATABASE_PATH for probes.
- run_release_tests.py in a fresh worktree: flutter pub get rewrites generated_plugin* EOLs -> gate refuses; `git add` them and rerun.
- Flutter pinned to 3.44.6; VS 2026 installed. Web UI capture: `scripts/app_review/capture_web.py` (sidebar is now on the right).
- [Single-laptop deployment](project_deployment_single_laptop.md) — prod = one standalone laptop; external backup needed
- [Production laptop layout](project_production_laptop_layout.md) — per-user install path, DB/backups location, leftover dev scripts
- [Repo home](project_repo_home.md) — source of truth is private baraa-solutions/import_flow; origin is legacy
- [External contributor guardrails](project_external_contributor_guardrails.md) — Antigravity vibe coder; GitHub Free = no branch protection

## Working conventions
- User: CTO, Egyptian Arabic, stays on the current branch; agents at medium effort.
- Track 1 daily work: never bump versions or touch `version.json` / `package_production.py`.
- Test baseline 2026-10-05: backend ~4,970 tests ~40 min; flutter ~2,100 tests ~16 min (-j 2). Never run both at once.
- Clean-machine lessons: ship the MSVC runtime next to frontend.exe, never launch via VBScript, start Setup/backend with
  clean_child_environment() (PyInstaller _PYI_* inheritance reuses the old _MEI → no migrations).
- [Parallel sessions](feedback_parallel_sessions.md) — CTO may run /simplify in the same worktree; verify foreign edits before commit
- [Parallel session release](feedback_parallel_session_release.md) — commit own files by path; CTO picks which session releases
- [Speed + parallel](feedback_speed_parallel.md) — split work across parallel agents; full test gate only at the end
- [Large parallel waves](feedback_large_parallel_waves.md) — pagefile/commit limit + watchdog, stalled agents, Edit-tool-only, shared registry pattern
