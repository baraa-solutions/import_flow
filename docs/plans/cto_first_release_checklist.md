# CTO checklist: first signed release to the production laptop

> **ملخص:** دي كل الخطوات اليدوية اللي لازم تعملها بنفسك، بالترتيب، قبل أول إصدار يتنشر على Hostinger ويتثبّت على لابتوب الإنتاج.
> ماتنطّش أي خطوة. أول حاجة: نسخة USB من قاعدة بيانات اللابتوب. آخر حاجة: التثبيت اليدوي على اللابتوب، وده بس بعد ما البروفة على الـ VM تنجح.
> المفتاح الخاص (private key) مكانه الـ USB المشفّر والـ password manager وسر GitHub وبس. عمره ما يتحط في الريبو ولا على اللابتوب.

Runbook: `docs/UPDATE_DISTRIBUTION_RUNBOOK.md`. Plan: `docs/plans/update-system-plan.md` (sections 0, 9, 11, 12).
All commands run from the repo root on **your dev machine**, never on the production laptop, unless a step says "on the laptop".
Tick each box in order.

---

## A. Before touching anything

- [ ] **1. USB backup of the laptop database (plan Q3).** On the laptop, close the app and confirm in Task Manager that neither
  `frontend.exe` nor `backend.exe` is running. Copy these **from** the laptop to a USB stick (Explorer is fine):
  - `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\sorour_logistics.db`, plus `-wal` and `-shm` if they exist
  - `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\backups\` (whole folder) and `.env` if present

  Check the copy on the laptop (PowerShell is built in, read-only):
  ```powershell
  Get-FileHash -Algorithm SHA256 "C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\sorour_logistics.db", "E:\laptop-backup-2026-09-24\sorour_logistics.db"
  ```
  Both hashes must match. Store the stick offline.

- [ ] **2. Confirm where the live DB is (plan Q1).** On the laptop, Task Manager -> `backend.exe` -> "Open file location" must be
  `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\`, with `sorour_logistics.db` in it. If it is under `C:\Program Files\`
  or anywhere else, **stop**: the new per-user installer will refuse to install ("database found in a different installation folder")
  and the move needs its own plan (plan section 0.4).

- [ ] **3. Decide the plan gate.** `update-system-plan.md` section 0.5 says R5 (backup gate before apply), R6 (Alembic at startup) and
  R10 (maintenance mode on unknown `alembic_version`) are deferred, and "no installer built from this branch goes to the laptop
  before they land". Today `/apply`, `/stage-local` and `/rollback` return 501. Either wait for those phases, or record your decision
  to bootstrap with the manual procedure (runbook section 8) anyway. Steps 4-17 can go ahead; step 19 (laptop install) depends on this.

## B. Repo changes (dev machine)

- [ ] **4. Apply the `package_production.py` diff.** Agents cannot edit that file. Follow `docs/plans/package_production_diff.md`:
  save "Diff 1" (required) and "Diff 2" (recommended) to files, then:
  ```bash
  git apply --check package_production_diff1.patch && git apply package_production_diff1.patch
  git apply --check package_production_diff2.patch && git apply package_production_diff2.patch
  python scripts/release/bundle_guard.py --iss installer/importflow_setup.iss
  ```
  The guard must print `bundle_guard: PASS`. Commit `package_production.py` only (the patch files stay out of git).
  Without Diff 1, CI fails at the "Bundle Guard (Staged Bundle & Portable Zip)" step on purpose.

- [ ] **5. Remove the stale DB from `dist/`.** Earlier packaging runs left `dist/Sorour_Logistics_Standalone/sorour_logistics.db`
  (it is there today). Move it out of the repo first rather than deleting it, in case it is not just a build copy:
  ```powershell
  New-Item -ItemType Directory -Force D:\secure\stale-dist-db | Out-Null
  Move-Item dist\Sorour_Logistics_Standalone\sorour_logistics.db D:\secure\stale-dist-db\
  ```
  Then this must print `PASS`:
  ```bash
  python scripts/release/bundle_guard.py --iss installer/importflow_setup.iss --dir dist/Sorour_Logistics_Standalone
  ```

- [ ] **6. Generate the Ed25519 signing key (once, offline).** Use the same hash-pinned signer environment as CI. The key id must be
  `k2026a`: CI signs with the signer's default id and the code has a `k2026a` slot.
  ```powershell
  python -m venv $env:TEMP\signer-venv
  & "$env:TEMP\signer-venv\Scripts\python.exe" -m pip install --no-cache-dir --disable-pip-version-check --require-hashes --only-binary :all: --no-deps -r scripts/release/requirements-sign.txt
  & "$env:TEMP\signer-venv\Scripts\python.exe" -I scripts/release/sign_manifest.py --generate-key --key-id k2026a --key-out E:\importflow-signing\importflow_update_k2026a.pem --public-out E:\importflow-signing\importflow_update_k2026a.pub.txt
  ```
  `E:` is an **encrypted USB stick** (BitLocker To Go). The script refuses to overwrite an existing key file. It prints the key id,
  the public key and the exact line for the code. The `.pem` is an **unencrypted** PKCS#8 private key:
  - keep it on that USB and in your password manager (a second offline copy), and in the GitHub secret (step 9) only
  - never in the repo, never in `D:\projects\...`, never on the production laptop, never pasted into chat or an issue
  - `bundle_guard` blocks `*.pem` from every bundle, but that is a last line of defence, not a storage rule

  Then delete the venv: `Remove-Item -Recurse -Force $env:TEMP\signer-venv`.

- [ ] **7. Put the public key in code (a normal reviewed commit; describe it to the backend-developer or do it yourself).**
  In `modules/app_update/service.py`, `UPDATE_SIGNING_PUBLIC_KEYS` currently holds the placeholder
  `"k2026a": "REPLACE_WITH_REAL_ED25519_PUBLIC_KEY_BASE64"`. Replace the placeholder value with the base64 public key printed in
  step 6 (the line the script prints has the form `"k2026a": "<base64>",`). Only the public key goes in code. Also remove the
  `!!! PLACEHOLDER !!!` comment above it. Check it and run the backend tests:
  ```bash
  python -c "from modules.app_update.service import UPDATE_SIGNING_PUBLIC_KEYS as k; print(k)"
  python -m pytest tests/unit -q -W ignore --junitxml=.pytest-report.xml; echo "exit=$?"
  ```
  The printed key must equal the one in `importflow_update_k2026a.pub.txt`, and the exit code must be 0. If the code still holds the
  placeholder or a different key, the "Publish update" workflow stops at "Verify Signed Manifest (Client Code Path)" before uploading anything.

## C. GitHub (repo Settings)

- [x] **8. Environment `production-updates` (already configured).** Repo: https://github.com/baraa-solutions/import_flow (private).
  Settings -> Environments -> `production-updates`:
  - **No "Required reviewers":** GitHub does not offer them for private repos on Free/Team. The approval is the manual
    **"Publish update"** workflow (step 16): nothing reaches the update host until you run it.
  - **Deployment branches and tags:** "Selected branches and tags" with ONE rule: ref type **Branch**, pattern `main`
    ("Publish update" and the `resign` job in `resign_update_manifest.yml` both run from `main`). No `v*` tag rule.
  - Only people with write access can run workflows; optional: a tag ruleset so only you can create `v*` tags.

- [ ] **9. Secret `UPDATE_SIGNING_KEY_ED25519`** as an **environment secret** of `production-updates` (not a repo secret, so only
  jobs in that environment, i.e. "Publish update" and the re-sign job, can read it). Value = the whole content of the `.pem` file, including the `-----BEGIN PRIVATE KEY-----` and
  `-----END PRIVATE KEY-----` lines. From Git Bash, reading straight from the USB so the key never hits the clipboard:
  ```bash
  gh secret set UPDATE_SIGNING_KEY_ED25519 --repo baraa-solutions/import_flow --env production-updates < /e/importflow-signing/importflow_update_k2026a.pem
  gh secret list --repo baraa-solutions/import_flow --env production-updates
  ```

- [x] **10. Hostinger CI access (already done).** Only check that the type and name match what the workflows read:
  - variables: `HOSTINGER_HOST`, `HOSTINGER_USER`, `HOSTINGER_PORT` (optional, default `65002`), `UPDATE_REMOTE_DIR` (optional, default
    `domains/kamal-sroor.online/public_html/importflow/updates`)
  - secrets: `HOSTINGER_SSH_KEY`, `HOSTINGER_KNOWN_HOSTS` (the workflows read the known-hosts line as a **secret**, not a variable)

## D. Hostinger (hPanel File Manager or SFTP, port 65002)

- [ ] **11. Upload `.htaccess` and create `releases/`.** In the folder that serves `https://kamal-sroor.online/importflow/updates/`
  (`public_html/importflow/updates/`; over SFTP it must be the same folder as `UPDATE_REMOTE_DIR`, default
  `domains/kamal-sroor.online/public_html/importflow/updates`):
  - upload `docs/plans/hostinger_htaccess.txt` and rename it to `.htaccess`
  - create the empty folder `releases/`
  - if the Hostinger CDN is on, add a bypass rule for `/importflow/updates/`

  Check:
  ```bash
  curl -sS -o /dev/null -w "%{http_code}\n" https://kamal-sroor.online/importflow/updates/
  curl -sS -o /dev/null -w "%{http_code}\n" https://kamal-sroor.online/importflow/updates/manifest.json
  ```
  Expected: `403` (no directory listing) and `404` (nothing published yet). A `500` means a bad `.htaccess`.

## E. The release

- [ ] **12. Bump the version (Track 2).** This updates `version.json`, `pubspec.yaml`, the `.iss` (`MyAppVersion`, `OutputBaseFilename`),
  `main.py`, `main.dart`, `home_screen.dart`, `main.cpp` and `api_constants.dart`:
  ```bash
  python version_manager.py bump patch
  python version_manager.py get
  ```
  Use `bump minor` instead if you want e.g. `2.1.0`. Below, `X.Y.Z` is the printed version.

- [ ] **13. Release notes.** Create both files (UTF-8, one note per line, `#` lines ignored, max 50 notes of 500 characters). CI fails
  without them:
  ```
  docs/release_notes/X.Y.Z.ar.txt
  docs/release_notes/X.Y.Z.en.txt
  ```

- [ ] **14. Commit, then run the local tests and the gate on that commit.** GitHub does not run the test suites.
  Commit the bump, the release notes and the step 4/7 changes (merge them to `main`). Then, with no uncommitted changes to tracked files:
  ```bash
  python scripts/release/run_release_tests.py
  python .claude/skills/release-check/check_release.py
  ```
  `run_release_tests.py` runs the backend suite, then `flutter test -j 4` (one after the other), prints both summaries, writes
  `.release/tests_<HEAD sha>.json` and must exit 0 (skips are fine, a failing test is not). In `/release-check`, "Local tests" must
  PASS; "Git tag" WARNs until step 15. Note: `/release-check` WARNs about the legacy `version.json` `installer_url`; that path is
  retired (see "Inconsistencies" below). A push to `main` publishes nothing.

- [ ] **15. Tag the tested commit and push the tag.** The tag must equal `v` + `version.json` version, or "Publish update" stops.
  The tag push only builds (~15 min, no test suites) and creates the GitHub Release; it publishes nothing.
  ```bash
  git tag vX.Y.Z
  git push company main vX.Y.Z
  ```

- [ ] **16. Publish (this is the approval).** Wait until Actions -> "Build & Release Sorour Logistics" -> the tag run is **green**.
  Then Actions -> **"Publish update"** -> **Run workflow** -> "Use workflow from": **`main`** -> type the tag
  `vX.Y.Z` in `tag` (leave `mandatory` off and `min_supported_version` empty for this first release, `expires_days` 90) ->
  **Run workflow**. All three jobs (`sign`, `verify`, `upload`) must end green. It picks the latest successful tag-push build of
  that tag (artifacts are kept 30 days). Download the artifact `signed-manifest-vX.Y.Z` from the "Publish update" run (the audit
  copy of what was published).

- [ ] **17. Verify the published release from the dev machine.**
  ```bash
  python scripts/release/verify_manifest.py --url https://kamal-sroor.online/importflow/updates/ --expect-manifest manifest.json
  ```
  (`manifest.json` = the file from the `signed-manifest-vX.Y.Z` artifact.) It must print `OK signature` with `version=X.Y.Z`,
  an `expires_at` about 90 days out, and `OK public ... (HEAD + download sha256)`, with exit code 0. The first release has no
  `previous=` (nothing was live before).

## F. VM rehearsal, then the laptop

- [ ] **18. VM rehearsal (Windows Sandbox or Hyper-V, never the laptop).**
  1. Install the version the laptop runs today (v2.0.3) in the VM, with the same per-user default folder.
  2. Close it and replace the VM's `sorour_logistics.db` with the **copy from the step 1 USB** (VM only).
  3. Start it, log in, note some recent records.
  4. Close it and run the new `Sorour_Logistics_Setup_vX.Y.Z.exe` (downloaded from the update host, hash-checked as in step 20).
  5. Check: `backups\pre_install_2.0.3_<timestamp>\sorour_logistics.db` exists with the same size as the DB before, the app starts,
     login works, the version is X.Y.Z, and the records from 3. are all there.
  6. In the app, the update check reports up to date (`GET /api/v1/app-update/check` -> `check_status: up_to_date`); disconnect the
     network and check again -> `offline`, and the app keeps working.
  7. Uninstall in the VM and confirm the DB, `.env` and `backups\` are still on disk.

  If any point fails, stop and do not go to step 19.

- [ ] **19. Fresh USB backup right before the install.** Repeat step 1 (new folder on the stick, with today's date).

- [ ] **20. One-time manual bootstrap install on the laptop** (only if steps 3, 18 and 19 are done). The laptop's current build still
  uses the retired GitHub check and cannot update itself, so this first install is manual (runbook section 8):
  1. On the dev machine: download `https://kamal-sroor.online/importflow/updates/releases/X.Y.Z/Sorour_Logistics_Setup_vX.Y.Z.exe`,
     run `python scripts/release/verify_manifest.py --manifest manifest.json --installer Sorour_Logistics_Setup_vX.Y.Z.exe`
     (must print `OK installer`), note the `sha256`, and copy the `.exe` to the USB stick.
  2. On the laptop: close the app (no `frontend.exe`/`backend.exe` in Task Manager), then
     ```powershell
     Get-FileHash -Algorithm SHA256 "E:\Sorour_Logistics_Setup_vX.Y.Z.exe"
     ```
     The hash must equal the noted `sha256`.
  3. Run it (SmartScreen: "More info" -> "Run anyway"), keep the default folder `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\`.
     If Setup aborts, stop: nothing was changed; see runbook section 12.
  4. Check `...\Sorour Logistics\backups\pre_install_2.0.3_<timestamp>\sorour_logistics.db` exists, the app starts, login works, the
     version is X.Y.Z, recent records are there, and the update check says up to date.

  On the laptop: no Python, no scripts, no copying databases onto it, no older installers (runbook section 11).

- [ ] **21. Afterwards.** Keep both USB backups. On the 1st of each month `Re-sign Update Manifest` runs from `main` and re-signs by
  itself when fewer than 45 days remain before `expires_at` (roughly every second month). No approval step; check that it ends green.
  Every later release: push tag -> wait for the green build -> Actions -> "Publish update" -> Run workflow -> type the tag.

---

## Inconsistencies found while writing this (for the lead)

- `/release-check` (`.claude/skills/release-check/check_release.py`) still gates on `version.json` `installer_url` / `installer_filename`
  and a HEAD to that GitHub URL (checks 2-4 in its docstring). The update path no longer uses them, and after any version bump they
  FAIL because `installer_url` is never updated by `version_manager.py`. The plan (section 11 "Gates") wants the opposite:
  no `installer_url`, tag == version, and a check of the manifest at `BASE_URL`.
- `package_production.py` still writes `installer_url` into the staged `version.json`, and `package_production_diff.md` does not remove it
  or add `dist/releases/release_info.json`, although plan section 10 lists both. CI does not need `release_info.json` (it passes `--installer`).
- Plan section 4.4 / 9 list `HOSTINGER_KNOWN_HOSTS` as a **variable** and `UPDATE_REMOTE_DIR` as `public_html/importflow/updates`; the
  workflows read `secrets.HOSTINGER_KNOWN_HOSTS` and default to `domains/kamal-sroor.online/public_html/importflow/updates`.
- Plan section 9 step 5 shows `build_manifest.py --generate-key` without `--key-out`; both scripts require `--key-out`
  (exit code 2 otherwise).
- Plan section 4.2 shows a flat `previous {version, path, sha256, size_bytes}`; the signer writes the nested
  `previous {version, installer {path, size_bytes, sha256}}` (it still reads the flat form).
- Plan section 4.3 has `publish` sign with `build_manifest.py --sign`; the workflow uses the stand-alone `sign_manifest.py` (as intended
  by the later security review). The plan's `ci.yml` does not exist (tests run locally: `run_release_tests.py` + `/release-check`),
  and there is no "assert tag == version in the build job": the tag check runs
  only in "Publish update" (`publish_update.yml`), after the full build.
- Neither workflow passes `--key-id`, so CI always signs as `k2026a`; key rotation (plan section 4.2) needs a workflow change.
- Plan section 4.3/4.4 put `publish` in the tag workflow behind a required reviewer. Private repos on Free/Team have no required
  reviewers, so publishing is the separate manual `publish_update.yml`; `mandatory` / `min_supported_version` / `expires_days` are its inputs.
- The `release` job body still advertises "Safe In-Place Auto-Update ... SQLite schema auto-migration"; startup Alembic (R6) is not
  implemented yet and `/apply` returns 501.
