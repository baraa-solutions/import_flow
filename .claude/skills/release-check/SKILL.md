---
name: release-check
description: Pre-release gate for ImportFlow / Sorour Logistics ERP. Verifies version consistency, release notes, the release tag, the embedded update signing key, the bundle guard (no database / secrets / destructive scripts in the installer or staged bundle), the published signed update manifest, backend boot, and that the local release tests (scripts/release/run_release_tests.py) passed for HEAD, before a release is cut.
disable-model-invocation: true
---

# Release Check

Run this before tagging a release. **Tests run locally only** (GitHub only builds and publishes): first run
`python scripts/release/run_release_tests.py` on the committed release HEAD, then this check. Releases go through the signed-manifest update system
(`docs/plans/update-system-plan.md` section 4, `docs/UPDATE_DISTRIBUTION_RUNBOOK.md`): pushing a `v*` tag builds the installer,
and the CTO then runs Actions → "Publish update" (`publish_update.yml`, the manual approval button) which signs `manifest.json`
and uploads it to `https://kamal-sroor.online/importflow/updates/`.
The retired GitHub flow (`version.json` `installer_url` / `installer_sha256`) is no longer checked.

## Steps

Run every step even if an earlier one fails, then report all results together.

1. **Static + boot checks**

   ```bash
   python .claude/skills/release-check/check_release.py            # includes the network check
   python .claude/skills/release-check/check_release.py --offline  # skips the published-manifest check
   ```

   Output is one `[PASS|WARN|FAIL|INFO] <check>: <detail>` line per check; exit code 1 when any check is FAIL.

   | Check | Meaning |
   |-------|---------|
   | Version consistency | `version.json` == `frontend/pubspec.yaml` == `installer/importflow_setup.iss` `MyAppVersion` (FAIL otherwise). `main.py` reads `version.json`, so it is not compared. |
   | Legacy installer_url | WARN if `version.json` still has `installer_url`: legacy field, the new updater ignores it. INFO when absent. Never blocks. |
   | Release notes | `docs/release_notes/<version>.ar.txt` and `.en.txt` exist. FAIL if either is missing: the tag build stops without them. |
   | Git tag | WARN if `v<version>` does not exist locally yet (normal before step 15 of the CTO checklist). FAIL if it exists but points at a different commit than HEAD. PASS when it tags HEAD. |
   | Signing key | FAIL while `UPDATE_SIGNING_PUBLIC_KEYS` in `modules/app_update/service.py` holds only the placeholder: no installed app could verify a release. PASS prints the usable key ids. |
   | Bundle guard | `scripts/release/bundle_guard.py` (plan section 0, R1/R4) over `installer/importflow_setup.iss`, `dist/Sorour_Logistics_Standalone/` and `dist/releases/*_Windows_Portable.zip`: no `*.db*`, `*.sqlite*`, `.env*`, `*.key`/`*.pem`, `backups/`/`updates/` folder or destructive script. FAIL blocks the release; WARN only means nothing is staged yet. Run alone: `python scripts/release/bundle_guard.py --iss installer/importflow_setup.iss --dir dist/Sorour_Logistics_Standalone`. |
   | Published manifest | Network, skipped with `--offline` (INFO). Fetches `<base URL>/manifest.json` and runs the `verify_manifest.py --url ... --head-only` logic (client verifier, embedded keys, installer HEAD 200 + Content-Length). PASS names the live version (must be <= the local version). WARN if nothing is published yet (HTTP 404), the host is unreachable, or no usable key exists. FAIL if the signature does not verify, the manifest has expired (re-sign), the live version is newer than the local one, or the installer HEAD does not match. |
   | Backend boot | `import main` succeeds against a throwaway database (never touches `sorour_logistics.db`). |
   | Local tests | `.release/tests_<HEAD sha>.json` from `scripts/release/run_release_tests.py` exists for HEAD with 0 failed / 0 errors and a zero exit code for both the backend and the Flutter suite. FAIL otherwise ("run python scripts/release/run_release_tests.py"). |

   Before the first release the Signing key and Release notes checks FAIL by design until the CTO adds the key and the notes
   (`docs/plans/cto_first_release_checklist.md`). A full post-publish check (downloads the installer and hashes it) is
   `python scripts/release/verify_manifest.py --url https://kamal-sroor.online/importflow/updates/`.

2. **Local tests** (only if the "Local tests" check FAILed): run the gate on the committed HEAD, then re-run step 1.

   ```bash
   python scripts/release/run_release_tests.py
   ```

   It refuses when tracked files outside `.claude/` have uncommitted changes, runs the backend pytest suite (scratch
   `DATABASE_PATH`, JUnit counts) and **then** `flutter test -j 2 --timeout 120s` (never both at once: this machine runs out of memory),
   prints both summaries, writes `.release/tests_<HEAD sha>.json` and exits non-zero on any failed test or error.
   Skipped (environment-dependent) tests are fine.

## Report

Reply in Egyptian Arabic with a table: check, result (PASS / WARN / FAIL / INFO), detail.
For the local tests give the backend and Flutter passed / failed / errors / skipped counts from `.release/tests_<sha>.json`.

The release is **blocked** if any step is FAIL or any test fails or errors.
Do not describe the suites as green unless you saw the passing output in this run.
