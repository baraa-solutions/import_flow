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
  This laptop has NO Visual Studio -> `flutter build windows` impossible; app-review (docs/prompts/app-review.md) blocked on it.
- Locale bug: main.dart has no supportedLocales -> localeOf = en_US, Arabic users see English in ~84 files.
- `import main` runs SchemaUpgradeService on DATABASE_PATH and writes snapshots to `backups/`: always point
  DATABASE_PATH at a scratch copy for probes.
- Auto-updater runs the downloaded installer with no SHA-256 / signature verification.

- [Single-laptop deployment](project_deployment_single_laptop.md) — prod = one standalone laptop; external backup needed; stay on Flutter desktop

## Working conventions
- User: CTO, prefers Egyptian Arabic, wants to stay on the current branch, Opus 5.5 at medium effort for agents.
- Track 1 daily work: never bump versions or touch `version.json` / `package_production.py`.
- Full backend suite takes ~8 minutes (930 tests on 2026-09-23).
