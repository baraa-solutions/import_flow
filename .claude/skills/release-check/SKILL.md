---
name: release-check
description: Pre-release gate for ImportFlow / Sorour Logistics ERP. Verifies version consistency, release notes, the release tag, the embedded update signing key, the bundle guard (no database / secrets / destructive scripts in the installer or staged bundle), the published signed update manifest, backend boot, and runs the full backend + frontend test suites before a release is cut.
disable-model-invocation: true
---

# Release Check

Run this before tagging a release. Releases go through the signed-manifest update system
(`docs/plans/update-system-plan.md` section 4, `docs/UPDATE_DISTRIBUTION_RUNBOOK.md`): pushing a `v*` tag builds the installer,
and the `publish` job (after CTO approval) signs `manifest.json` and uploads it to `https://kamal-sroor.online/importflow/updates/`.
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
   | Release notes | `docs/release_notes/<version>.ar.txt` and `.en.txt` exist. FAIL if either is missing: the CI build job stops without them. |
   | Git tag | WARN if `v<version>` does not exist locally yet (normal before step 15 of the CTO checklist). FAIL if it exists but points at a different commit than HEAD. PASS when it tags HEAD. |
   | Signing key | FAIL while `UPDATE_SIGNING_PUBLIC_KEYS` in `modules/app_update/service.py` holds only the placeholder: no installed app could verify a release. PASS prints the usable key ids. |
   | Bundle guard | `scripts/release/bundle_guard.py` (plan section 0, R1/R4) over `installer/importflow_setup.iss`, `dist/Sorour_Logistics_Standalone/` and `dist/releases/*_Windows_Portable.zip`: no `*.db*`, `*.sqlite*`, `.env*`, `*.key`/`*.pem`, `backups/`/`updates/` folder or destructive script. FAIL blocks the release; WARN only means nothing is staged yet. Run alone: `python scripts/release/bundle_guard.py --iss installer/importflow_setup.iss --dir dist/Sorour_Logistics_Standalone`. |
   | Published manifest | Network, skipped with `--offline` (INFO). Fetches `<base URL>/manifest.json` and runs the `verify_manifest.py --url ... --head-only` logic (client verifier, embedded keys, installer HEAD 200 + Content-Length). PASS names the live version (must be <= the local version). WARN if nothing is published yet (HTTP 404), the host is unreachable, or no usable key exists. FAIL if the signature does not verify, the manifest has expired (re-sign), the live version is newer than the local one, or the installer HEAD does not match. |
   | Backend boot | `import main` succeeds against a throwaway database (never touches `sorour_logistics.db`). |

   Before the first release the Signing key and Release notes checks FAIL by design until the CTO adds the key and the notes
   (`docs/plans/cto_first_release_checklist.md`). A full post-publish check (downloads the installer and hashes it) is
   `python scripts/release/verify_manifest.py --url https://kamal-sroor.online/importflow/updates/`.

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

Reply in Egyptian Arabic with a table: check, result (PASS / WARN / FAIL / INFO), detail.
For test suites give passed / failed / errored counts and name every failing test.

The release is **blocked** if any step is FAIL or any test fails or errors.
Do not describe the suites as green unless you saw the passing output in this run.
