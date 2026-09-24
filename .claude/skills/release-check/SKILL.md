---
name: release-check
description: Pre-release gate for ImportFlow / Sorour Logistics ERP. Verifies version consistency, installer metadata, the bundle guard (no database / secrets / destructive scripts in the installer or staged bundle), backend boot, and runs the full backend + frontend test suites before a release is cut.
disable-model-invocation: true
---

# Release Check

Run this before bumping the version or pushing a release tag
(the CI workflow builds and publishes a GitHub Release when a `v*` tag is pushed, or on manual dispatch).

## Steps

Run every step even if an earlier one fails, then report all results together.

1. **Static + boot checks**

   ```bash
   python .claude/skills/release-check/check_release.py
   ```

   - Version identical in `version.json`, `frontend/pubspec.yaml`, `main.py`, `installer/importflow_setup.iss`
   - `installer_url` / `installer_filename` point at the same version as `version.json`
   - `installer_sha256` present (WARN only until the auto-updater verifies it)
   - Bundle guard (`scripts/release/bundle_guard.py`, plan section 0 R1/R4): `installer/importflow_setup.iss`,
     `dist/Sorour_Logistics_Standalone/` and any `dist/releases/*_Windows_Portable.zip` contain no `*.db*`,
     `*.sqlite*`, `.env*`, `*.key`/`*.pem`, `backups/`/`updates/` folder, or destructive script
     (`reset_clean_production_db.py`, `clean_and_isolate_databases.py`, `sync_to_production.py`, ...).
     FAIL blocks the release; WARN only means nothing is staged yet - re-run after packaging.
     Run it alone with `python scripts/release/bundle_guard.py --iss installer/importflow_setup.iss --dir dist/Sorour_Logistics_Standalone`.
   - `import main` succeeds against a throwaway database (never touches `sorour_logistics.db`)

2. **Backend tests** — run on Python 3.12, the same version CI uses:

   ```bash
   python -m pytest tests -q -W ignore --junitxml=.pytest-report.xml; echo "pytest exit=$?"
   ```

   Once `import main` has run, pytest's final "N passed" summary line does not reach the
   console, so never judge the result from the console tail. Use the exit code
   (0 = all passed) and read the counts from `.pytest-report.xml`
   (`tests`, `failures`, `errors`, `skipped` on the `<testsuite>` element), then delete the file.

3. **Frontend tests**

   ```bash
   cd frontend && flutter test
   ```

## Report

Reply in Egyptian Arabic with a table: check, result (PASS / WARN / FAIL), detail.
For test suites give passed / failed / errored counts and name every failing test.

The release is **blocked** if any step is FAIL or any test fails or errors.
Do not describe the suites as green unless you saw the passing output in this run.
