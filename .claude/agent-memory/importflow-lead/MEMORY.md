# importflow-lead memory

## Project state (as of 2026-09-23)
- CI (`build_and_release.yml`) was red on main from 2026-08-28 (last green: c6a2f66, v1.0.58) through
  2026-09-23: 97 consecutive failures at step "Run Backend Pytest Suite". Cause: backend failed to import on
  Python 3.12 (missing typing/schema imports) plus environment-dependent tests. Check with `/ci-status`.
- Consequence: no GitHub Release after v1.0.60 was published, while `version.json` on main advertised newer
  versions -> in-app update downloads 404. `/release-check` flags this ("Installer published").
- Auth gap closed and committed 2026-09-24 (406dba5; router-level get_current_user, 9 public routes); Phase-2 auth items in history/2026-09-24.md. Tests use a conftest seam
  (`_dev_bypass_fallback_user` -> transient ADMIN); `test_route_auth_coverage.py` guards new routes.
- Flutter pinned to 3.44.6 (pubspec + CI) in 0b9db72; flutter test green (perf tag skipped by default).
  This laptop has NO Visual Studio -> `flutter build windows` impossible. UI review/screens are done on the WEB build via
  `scripts/app_review/capture_web.py` (Playwright, scratch backend); results in docs/app-review/ (screenshots local-only).
- DANGER: modules/production_sync ignores DATABASE_PATH and always targets the real root/dist DBs — never click its
  buttons in automated runs, even with a scratch backend.
- Locale bug: main.dart has no supportedLocales -> localeOf = en_US, Arabic users see English in ~84 files.
- Update system (2026-09-25, commits 8e07f18..50679a1): DB safety phase 0, app_update check/download/apply/rollback/USB,
  Alembic startup runner (baseline e1f2a3b4c5d6), Hostinger signed publishing. Sandbox rehearsal PASSED 2026-09-25 (run 6, kit at D:\importflow_rehearsal). NOT yet released: pending
  CTO checklist (docs/plans/cto_first_release_checklist.md), and the laptop second-DB question.
- Never run pytest and `flutter test -j 4` at the same time on this machine (out of memory → false failures).
- Any `import main` without DATABASE_PATH now stamps the dev DB (backup first) — always use a scratch DATABASE_PATH.
- `import main` runs SchemaUpgradeService on DATABASE_PATH and writes snapshots to `backups/`: always point
  DATABASE_PATH at a scratch copy for probes.
- Auto-updater runs the downloaded installer with no SHA-256 / signature verification.

- [Single-laptop deployment](project_deployment_single_laptop.md) — prod = one standalone laptop; external backup needed; stay on Flutter desktop

## Working conventions
- User: CTO, prefers Egyptian Arabic, wants to stay on the current branch, Opus 5.5 at medium effort for agents.
- Track 1 daily work: never bump versions or touch `version.json` / `package_production.py`.
- Full backend suite: 2006 tests, ~39 min on 2026-09-25 (was ~8 min / 930 on 2026-09-23); flutter test ~18 min.
- Subagents stop at 40 turns: on branch-wide reviews (>10k-line diff) give each reviewer a file subset or a report budget.
- Known inconsistency (not fixed yet): ADMIN/MANAGER role checks mix case-sensitive and `.upper()` compares (modules/auth).
- [Production laptop layout](project_production_laptop_layout.md) — per-user install path, DB/backups location, leftover dev scripts
- [Parallel sessions](feedback_parallel_sessions.md) — CTO may run /simplify in the same worktree; verify foreign edits before commit
- Clean-machine lessons (2026-09-25): ship the MSVC runtime next to frontend.exe (CMake), never launch via VBScript,
  and start Setup/backend with clean_child_environment() (PyInstaller _PYI_* inheritance reuses the old _MEI → no migrations).
