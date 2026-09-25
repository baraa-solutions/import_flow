# Update Distribution & Rollback Runbook (single production laptop)

> **ملخص سريع:**
> - فيه لابتوب إنتاج **واحد** بس، والبرنامج متثبّت per-user في `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\` وقاعدة البيانات جنبه.
> - الاختبارات بتتعمل **على جهازك بس** قبل الـ tag: `python scripts/release/run_release_tests.py` وبعدها `/release-check`. GitHub بيبني وبينشر بس.
> - الإصدار الجديد بيتعمل **بـ tag بس** (`vX.Y.Z`). الـ tag بيبني (حوالي 15 دقيقة) ويعمل GitHub Release بس، **ومش بينشر حاجة** على سيرفر التحديثات.
> - النشر زرار يدوي: Actions -> **"Publish update"** -> Run workflow -> تكتب الـ tag. الضغطة دي هي الموافقة (الريبو private على GitHub Free/Team، فمفيش "Required reviewers").
> - الـ workflow ده بيوقّع الـ manifest بمفتاح Ed25519 وبيرفع الـ installer الأول على Hostinger (`https://kamal-sroor.online/importflow/updates/`)، وبعدين الـ manifest آخر حاجة.
> - الـ manifest فيه `expires_at` (90 يوم). فيه workflow شهري بيعيد توقيعه تلقائي لما يقرّب ينتهي (من `main` بس).
> - الـ installer **عمره ما بيلمس قاعدة البيانات**. قبل التثبيت بيقفل البرنامج، وبياخد نسخة من الـ DB في `backups\pre_install_*`، ولو النسخة فشلت بيلغي التثبيت.
> - على لابتوب الإنتاج **ممنوع**: تشغيل Python أو أي script، نسخ قاعدة بيانات من برّه فوق قاعدة اللابتوب، أو تثبيت installer قديم.
> - أول تثبيت (bootstrap) بيتعمل بإيدك مرة واحدة بس، وبعد بروفة على VM. الخطوات بالترتيب في `docs/plans/cto_first_release_checklist.md`.

Spec: `docs/plans/update-system-plan.md`. First-release steps: `docs/plans/cto_first_release_checklist.md`.
This runbook replaces the old multi-workstation / GitHub-download runbook. The old `scripts/publish_release.py`,
`version.json` `installer_url`, and the GitHub-raw update check are **not** part of the update path any more.

---

## 1. Topology

| Piece | Where | Notes |
|-------|-------|-------|
| Production laptop | one Windows machine, user `Hp` | Runs `backend.exe` + `frontend.exe` from a single Inno Setup install. Nobody develops on it. |
| Install folder `{app}` | `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\` | Per-user install (`PrivilegesRequired=lowest`, `DefaultDirName={autopf}\Sorour Logistics`). |
| Live database | `{app}\sorour_logistics.db` (+ `-wal`, `-shm`) | Never a Setup file, so Setup never ships, replaces or deletes it. |
| Pre-install backups | `{app}\backups\pre_install_<old version>_<yyyymmdd_hhnnss>\` | Written by the installer before every install (section 5). |
| Update data | `C:\Users\Hp\AppData\Local\SorourLogistics\updates\` | `last_manifest.json`, `update_history.jsonl`, `staging\` (downloads). Override: env `UPDATE_DATA_DIR`. |
| Update host | `https://kamal-sroor.online/importflow/updates/` (Hostinger, static files) | Only allowed host in code (`modules/app_update/validators.py`). No credentials on the laptop. |
| CI | Private repo `baraa-solutions/import_flow` (https://github.com/baraa-solutions/import_flow). GitHub Actions only build and publish (tests run locally, `scripts/release/run_release_tests.py`): `build_and_release.yml` (build), `publish_update.yml` ("Publish update", manual), `resign_update_manifest.yml` (monthly) | The signing key and SFTP key live only in the secrets of environment `production-updates`. |

Hosted layout (`UPDATE_REMOTE_DIR`, default `domains/kamal-sroor.online/public_html/importflow/updates`):

```
importflow/updates/
  .htaccess                                   <- docs/plans/hostinger_htaccess.txt
  manifest.json                               <- signed envelope, replaced atomically, served no-store
  releases/<X.Y.Z>/Sorour_Logistics_Setup_v<X.Y.Z>.exe   <- newest 3 versions kept (rollback)
```

## 2. Trust model (why a hacked host cannot push a build)

- `manifest.json` is one JSON envelope `{key_id, signature, signed}`. `signed` is a JSON **string**; the signature is
  Ed25519 over its exact UTF-8 bytes.
- The app trusts only the public keys embedded in `modules/app_update/service.py` `UPDATE_SIGNING_PUBLIC_KEYS`
  (`key_id -> base64 raw 32-byte key`). While that map holds the placeholder, `/check` reports `check_status="disabled"`.
- The signed payload carries `version`, `build_number`, `released_at`, **`expires_at` (required)**, `mandatory`,
  `min_supported_version`, `db_schema_revision`, `release_notes {ar, en}`, `installer {path, size_bytes, sha256}` and an
  optional **`previous {version, installer {path, size_bytes, sha256}}`** (the release that was live before, for rollback).
- Client rules: `installer.path` must be `releases/<X.Y.Z>/<name>.exe` (relative; no `..`, no `://`); redirects are never
  followed; manifest max 64 KB; an expired manifest or one older than the highest version+build already seen is refused
  (anti-replay). **Consequence: you cannot "roll back" by publishing an older manifest. Fix forward with a new version.**
- Installer integrity is the SHA-256 in the signed payload. The installer itself is not Authenticode-signed, so a manual
  install shows SmartScreen ("More info" -> "Run anyway"), which is only acceptable after the hash check in section 8.

## 3. Release pipeline (build on tag, publish by button)

The repo is private on GitHub Free/Team, where environments have **no "Required reviewers"**. The approval is therefore a
manual button: a tag push only builds; publishing to the update host happens only when you run **"Publish update"**.

### 2.9 Tests run locally (`scripts/release/run_release_tests.py`)

GitHub does **not** run the test suites (no push/fix/re-push cycles). Before tagging, on the committed release HEAD:

```bash
python scripts/release/run_release_tests.py
```

It refuses when tracked files outside `.claude/` have uncommitted changes, runs the backend pytest suite (scratch
`DATABASE_PATH`) and **then** `flutter test -j 4` (never both at once: the dev machine runs out of memory otherwise),
prints both summaries, writes `.release/tests_<HEAD sha>.json` (git-ignored) and exits non-zero on any failed test or error.
Skipped (environment-dependent) tests are fine. `/release-check` ("Local tests") requires that file, green, for HEAD.

### 3.0 `.github/workflows/build_and_release.yml` (tag `v*` or `workflow_dispatch`)

A push to `main` builds nothing. This workflow holds **no publish secrets** (no signing key, no SFTP key, no environment).

| Job | Runner | Secrets | What it does |
|-----|--------|---------|--------------|
| `build-and-release` | windows | none | No test suites (they ran locally, section 2.9). `build_backend_exe.py`, `flutter build windows --release`, **bundle guard on the `.iss`**, `package_production.py --no-bump`, **bundle guard on the staged folder + portable zip**, then Inno Setup (`ISCC`). Reads `version.json`, requires `docs/release_notes/<ver>.ar.txt` and `.en.txt`, reads the Alembic head, and runs `build_manifest.py` -> `dist/update/manifest.unsigned.json`. Uploads artifact `update-payload` (installer + unsigned manifest, kept 30 days). |
| `release` | ubuntu | `GITHUB_TOKEN` | Tag runs only. Creates the (private-repo) GitHub Release with the installer, portable zip and `version.json`. Audit record only; the laptop never downloads from GitHub. |

### 3.0.1 `.github/workflows/publish_update.yml` ("Publish update", `workflow_dispatch` only)

Run it **from `main` only** and type the tag. Inputs: `tag` (required, `vX.Y.Z`), `mandatory`, `min_supported_version`,
`expires_days` (default 90). Environment `production-updates` (deployment rule: branch `main` only; env secrets
`UPDATE_SIGNING_KEY_ED25519`, `HOSTINGER_SSH_KEY`, `HOSTINGER_KNOWN_HOSTS`; env vars `HOSTINGER_HOST` / `HOSTINGER_PORT` /
`HOSTINGER_USER`). Three jobs, so no secret ever shares a runner with unhashed `pip install`s; any failure stops before
clients can see anything:

**`sign`** (environment `production-updates`, `contents: read` + `actions: read`)
1. Guard: the run's ref is `refs/heads/main`; `tag` looks like `vX.Y.Z`, exists, and equals `v` + `version.json` at `refs/tags/<tag>`.
2. Finds the latest **successful tag-push** (`event == push`) `build_and_release.yml` run for the tag's commit and downloads
   its `update-payload` artifact (by run id). No green build = nothing to publish.
3. Creates an isolated signer venv from `scripts/release/requirements-sign.txt` (`--require-hashes --only-binary :all: --no-deps`);
   nothing else is installed in this job.
4. Fetches the live `manifest.json` (404 = first release) to build the signed `previous` block.
5. Signs: `python -I scripts/release/sign_manifest.py --in ... --out ... --installer ... --expires-days N [--mandatory]
   [--min-supported-version X.Y.Z] [--previous-from-manifest live-manifest.json]`. The key is only in this step's env.
6. Uploads artifact `signed-update` (manifest + installer, 30 days) and `signed-manifest-<tag>` (audit copy, 90 days).

**`verify`** (no environment, no secrets)
7. Checks out `refs/tags/<tag>`, installs `requirements.txt`, runs `verify_manifest.py --manifest ... --installer ...` = the
   ManifestVerifier and embedded public keys **of the release being shipped**. A placeholder or wrong public key stops here.
   Hands the verified installer sha256 / size / path to `upload`.

**`upload`** (environment `production-updates`; no checkout, no Python, no pip: shell, `sftp`, `curl`, `sha256sum` only)
8. Re-checks the artifact installer against the verified facts; writes the SSH credentials (0600, pinned host key,
   `StrictHostKeyChecking yes`); installer -> `releases/<ver>/<file>.part` -> `posix-rename`.
9. Public HTTPS check of the installer: HEAD `Content-Length` and full-download SHA-256 must match the verified facts.
10. Manifest -> `manifest.json.tmp` -> `posix-rename` to `manifest.json` (**last**), then re-download and byte-compare.
11. Prunes `releases/` to the newest 3 versions (warning only), then shreds the SSH key at once (an `always()` step is the backstop).

`publish` and the re-sign job share the concurrency group `production-updates-publish`, so they never race.

### 3.1 Cutting a release (Track 2 only, CTO)

Daily work is Track 1 (`docs/DEV_WORKFLOW.md`): no version bumps, no packaging. A release is a deliberate Track 2 step.

1. Bump the version on a release commit. `version_manager.py` updates `version.json`, `frontend/pubspec.yaml`,
   `installer/importflow_setup.iss` (`MyAppVersion`, `OutputBaseFilename`), `main.py`, `main.dart`, `home_screen.dart`,
   `main.cpp`, `api_constants.dart`:
   ```bash
   python version_manager.py bump patch      # or: bump minor | bump major
   python version_manager.py get             # prints: Current version: vX.Y.Z (Build N)
   ```
   The tag build runs `package_production.py --no-bump`, so the version in the commit is the version that ships.
2. Write the release notes (UTF-8, one note per line; blank lines and `#` lines ignored; a leading `- `, `* ` or `• ` is
   stripped; max 50 notes of 500 characters per language):
   ```
   docs/release_notes/X.Y.Z.ar.txt
   docs/release_notes/X.Y.Z.en.txt
   ```
3. Commit (or merge to `main`) the release commit. Then, on that committed HEAD, run the local tests and the gate:
   ```bash
   python scripts/release/run_release_tests.py            # backend, then flutter; must exit 0
   python .claude/skills/release-check/check_release.py   # "Local tests" must PASS; no FAIL except "Git tag" before tagging
   ```
4. Tag **that commit** (the one the tests ran on) and push the tag:
   ```bash
   git tag vX.Y.Z
   git push company main vX.Y.Z
   ```
   Wait until Actions -> "Build & Release Sorour Logistics" for the tag is **green** (~15 min, build only; nothing is published yet).
5. Actions -> **"Publish update"** -> **Run workflow** -> "Use workflow from": **`main`** -> type the tag
   (`vX.Y.Z`) -> **Run workflow**. This click is the approval. The run must end green.
6. Verify from any dev machine (section 7).

**Mandatory update / `min_supported_version`:** set them as inputs of the same "Publish update" run (step 5). Use mandatory
only for security fixes or breaking DB changes. They do not require a rebuild.

## 4. Manifest expiry and the monthly re-sign (`.github/workflows/resign_update_manifest.yml`)

- Every manifest expires (`expires_at`, default released_at + 90 days, max 365). An expired manifest is refused by the app:
  no update is offered, the app keeps working.
- Schedule: 06:00 UTC on the 1st of each month. Job `check` (no secrets) reads `expires_at` from the live manifest and runs
  the re-sign only when fewer than 45 days remain (or `force`), roughly every second month. There is no approval step
  (no required reviewers on a private Free/Team repo); the environment's branch rule limits it to `main`.
- Job `resign` (environment `production-updates`, **main only**) re-verifies the live manifest with the signing key,
  changes **only** `expires_at` (now + 90 days), verifies with the client code path (`--head-only` installer check),
  re-fetches the live manifest and refuses to replace it if it changed meanwhile, then `manifest.json.tmp` -> `posix-rename`.
- Manual run: Actions -> "Re-sign Update Manifest" -> Run workflow (branch `main`), inputs `force`, `expires_days`, `threshold_days`.
- If a scheduled re-sign failed (host down, key problem), fix the cause and run the workflow manually with `force = true`.

Manual re-sign fallback (CI unavailable; key from the offline USB):

```bash
curl -sS -o live-manifest.json "https://kamal-sroor.online/importflow/updates/manifest.json"
python -I scripts/release/sign_manifest.py --resign live-manifest.json --out manifest.json --key-file E:\importflow_update_k2026a.pem --expires-days 90
python scripts/release/verify_manifest.py --manifest manifest.json --url https://kamal-sroor.online/importflow/updates/ --head-only
```

Upload `manifest.json` as `manifest.json.tmp` in the updates folder (hPanel File Manager or SFTP port 65002), rename it to
`manifest.json` (replace), then check it with `verify_manifest.py --url ... --expect-manifest manifest.json`.

## 5. Installer DB-safety rules (`installer/importflow_setup.iss`)

Enforced by `scripts/release/bundle_guard.py` (CI, `/release-check`) and `tests/unit/test_installer_safety.py`.

- **R1** The installer never ships, replaces or deletes `*.db`, `*.db-wal`, `*.db-shm`, `*.db-journal`, `*.sqlite*`, `.env*`,
  keys (`*.key`, `*.pem`, `*.pfx`, `*.p12`), `backups\` or `updates\`. The wildcard `[Files]` source excludes all of them plus the
  destructive scripts. There is no `[UninstallDelete]`. `[InstallDelete]` removes only four legacy scripts by exact name
  (`reset_clean_production_db.py`, `clean_and_isolate_databases.py`, `sync_to_production.py`, `seed.py`).
- **R2** `PrepareToInstall` (before any file is written):
  1. if `{app}\sorour_logistics.db` is missing but a database exists in another install folder (other install mode,
     registry app path, Program Files) -> **abort** ("database found in a different installation folder");
  2. if there is no database anywhere -> fresh install, nothing to back up (the backend creates an empty DB on first run);
  3. otherwise `taskkill` `frontend.exe` + `backend.exe`, wait up to 10 s until both are gone, copy `.db` (+ `-wal`, `-shm` if present)
     to `{app}\backups\pre_install_<installed version>_<yyyymmdd_hhnnss>\`, compare sizes, and **abort the whole install** on any failure.
     Silent installs abort with exit code 7.
- **R3** Uninstall leaves the database, `.env`, `backups\` and `updates\` on disk (`[Dirs]` with `uninsneveruninstall`).
- Install mode is always per-user: an upgrade can never switch to all-users and land next to an empty database.
- `/RELAUNCH=1` on a silent install restarts the app after the update (used by the in-app apply).

`bundle_guard.py` usage (read-only; exit 0 clean, 1 forbidden content, 2 bad input):

```bash
python scripts/release/bundle_guard.py --iss installer/importflow_setup.iss --dir dist/Sorour_Logistics_Standalone --zip dist/releases/Sorour_Logistics_vX.Y.Z_Windows_Portable.zip
```

## 6. In-app update flow (laptop)

Backend owns the logic (`/api/v1/app-update/*`), Flutter the UI. No route accepts a URL.

| Step | Route | Permission | Status today |
|------|-------|------------|--------------|
| Check (after login, then every 24 h; cache 1 h) | `GET /check?force=` | any logged-in user | **works**. `check_status`: `up_to_date`, `update_available`, `offline`, `invalid_signature`, `disabled` (placeholder key) |
| Download to `updates\staging\` (hash while streaming, `.part` -> final name) | `POST /download`, `GET /status`, `POST /cancel` | `system.update` (ADMIN) | **works** (frozen, Inno-installed build only; dev mode returns 400) |
| Apply: re-hash, verified DB backup, `pending_update.json`, launch installer `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1` | `POST /apply` | `system.update` | **not yet: returns 501 "غير متاح بعد"** (plan Phase 5) |
| USB: verify a `manifest.json` + `.exe` picked from disk, then same apply | `POST /stage-local` | `system.update` | **not yet: 501** |
| Rollback to the signed `previous` installer + restore the pre-update backup | `POST /rollback` | `system.update` | **not yet: 501** |
| Post-update result, history | `GET /last-result`, `GET /history` | any user / `system.update` | `last-result` always `none` until Phase 5 |

Until Phase 5 lands, installation is the manual procedure in section 8. After Phase 5, the admin clicks the banner ->
"install now"; the app backs up the DB, closes, the installer runs silently (its own pre-install backup too), and the app restarts.

Plan gates that are still open (update-system-plan.md section 0.5 "Delivery status"): **R5** (backup + `integrity_check` gate
before apply), **R6** (Alembic migrations at startup) and **R10** (maintenance mode on an unknown `alembic_version`). The plan
says no installer from this branch goes to the laptop before they land; the CTO decides when that condition is met.

## 7. Verifying a release (dev machine, never the laptop)

```bash
# published manifest: signature with the embedded keys, expiry, HEAD + full download sha256 of the installer
python scripts/release/verify_manifest.py --url https://kamal-sroor.online/importflow/updates/

# ... and byte-identical to the audit artifact downloaded from the run (signed-manifest-vX.Y.Z)
python scripts/release/verify_manifest.py --url https://kamal-sroor.online/importflow/updates/ --expect-manifest manifest.json

# local manifest + local installer (e.g. before a USB install)
python scripts/release/verify_manifest.py --manifest manifest.json --installer Sorour_Logistics_Setup_vX.Y.Z.exe
```

Exit code 0 = OK. The output prints `version`, `build`, `mandatory`, installer path, size, `sha256`, `expires_at` and `previous`.
`--public-key KEY_ID=BASE64` replaces the embedded keys (key-rotation rehearsal only).

## 8. Manual install and USB fallback

Use this for the one-time bootstrap, while `/apply` returns 501, or when the laptop is offline.

On a dev machine:

1. Download the installer from `https://kamal-sroor.online/importflow/updates/releases/<ver>/Sorour_Logistics_Setup_v<ver>.exe`
   and `manifest.json` from the updates folder.
2. `python scripts/release/verify_manifest.py --manifest manifest.json --installer Sorour_Logistics_Setup_v<ver>.exe` must print `OK`.
   Write down the `sha256` it prints.
3. Copy the `.exe` (and `manifest.json`) to a USB stick.

On the laptop (no Python, no scripts):

4. **Back up first** (section 10). Close the app; in Task Manager neither `frontend.exe` nor `backend.exe` may be running.
5. PowerShell (built-in, read-only): the hash must equal the one from step 2, otherwise stop.
   ```powershell
   Get-FileHash -Algorithm SHA256 "E:\Sorour_Logistics_Setup_v<ver>.exe"
   ```
6. Run the installer (SmartScreen: "More info" -> "Run anyway"). Keep the default folder
   `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\`. If Setup aborts with a backup or "different installation folder"
   message, **stop and call the CTO**; nothing was changed.
7. Check: `{app}\backups\pre_install_<old version>_<timestamp>\sorour_logistics.db` exists; the app starts, you can log in, the
   version shown is `<ver>`, and recent records (last shipments / files) are present.

After Phase 5 the same USB pair can be loaded in-app with "update from file" (`POST /stage-local`), which verifies the signature and hash itself.

## 9. Rollback

Prefer **fix forward** (new version, new tag) whenever the database is fine: it loses no data and needs no laptop surgery.
Clients refuse an older manifest, so rollback never happens through the host.

Rollback is a CTO-only procedure (until `POST /rollback` exists):

1. Decide whether the DB must be restored. Restoring the pre-install backup **loses every record entered since the update**.
   If the new version only has a UI/logic bug and the DB is fine, reinstall the previous version and keep the current DB.
2. Take the section 10 backup of the current state (the "failed" DB) to USB.
3. Get the previous installer: its version, path and `sha256` are in the signed `previous` block of the current manifest
   (`verify_manifest.py` prints `previous=<ver>`; the file stays in `releases/` for the newest 3 versions). On a dev machine,
   after `verify_manifest.py --manifest manifest.json` printed `OK`, read the expected hash from that same file and compare:
   ```powershell
   ((Get-Content manifest.json -Raw | ConvertFrom-Json).signed | ConvertFrom-Json).previous.installer
   Get-FileHash -Algorithm SHA256 .\Sorour_Logistics_Setup_v<previous>.exe
   ```
   (An older release's own signed manifest is usually expired, so `verify_manifest.py` would reject it.) Only versions
   published on the update host are DB-safe; never use an installer from anywhere else (section 11).
4. Close the app and run the previous installer. Its `PrepareToInstall` also stores the current DB in
   `backups\pre_install_<new version>_<timestamp>\`.
5. Only if the DB must be restored, with the app closed:
   - rename the current `sorour_logistics.db`, `sorour_logistics.db-wal`, `sorour_logistics.db-shm` in `{app}` to `*.failed-<yyyymmdd>`
     (a stale `-wal` next to a restored DB can corrupt it);
   - copy the files from `{app}\backups\pre_install_<previous version>_<timestamp>\` (the backup the failed update made) into `{app}`.
   This is the **only** database copy ever made onto the laptop, and it always comes from the laptop's own `backups\` folder.
6. Start the app, log in, check the version and the data. Keep the `*.failed-*` files until the fix-forward release is installed.

## 10. Backup before any manual action

With the app closed (Task Manager: no `frontend.exe`, `backend.exe`), copy **from** the laptop to a USB stick:

- `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\sorour_logistics.db` and, if present, `-wal`, `-shm`
- `...\Sorour Logistics\backups\` (whole folder) and `.env` if present
- `C:\Users\Hp\AppData\Local\SorourLogistics\updates\update_history.jsonl`

Check the copy (sizes, or `Get-FileHash` on both sides). Label the stick with the date and version.

## 11. Never do on the production laptop

| Never | Why |
|-------|-----|
| Run `python`, `pip`, or any repo script (`*.py`, `*.bat`, `*.ps1` maintenance tools, `package_production.py`, `restore_database.py`, `reset_clean_production_db.py`, `clean_*`, `sync_to_production.py`, `seed.py`) | Several of them wipe tables, replace the DB or reseed demo users (plan audit A4, A13-A15). The laptop runs only the installed binaries. |
| Copy a database onto the laptop (from the dev machine, a `dist\` folder, a zip, another PC, a USB stick) | It silently replaces real operational data. Only the rollback step 5 restore from the laptop's own `backups\` is allowed. |
| Install an old installer (anything built before the first Hostinger release, any GitHub Releases / `dist\releases` / portable-zip build, v2.0.3 and older) | Installers before Phase 0b ship `sorour_logistics.db` and **overwrite the live database** (audit A1). Rollback uses only a verified `previous` release from the update host. |
| Install a file whose SHA-256 was not checked against a verified manifest | Integrity comes only from the signed manifest. |
| Switch to an all-users / Program Files install, or install into another folder | The data lives in the per-user `{app}`; Setup aborts if it finds the DB elsewhere, and you would be looking at an empty database. |
| Delete or "clean up" `backups\` or `updates\` | They hold the pre-install backups rollback depends on. |
| Put a `.env` with `ALLOW_DEV_AUTH_BYPASS=true`, `DATABASE_PATH` or `UPDATE_BASE_URL` on the laptop | Changes auth, the DB location or the update host outside of any review. |
| Use the portable zip on the laptop | It is not the installed product and bypasses the installer's backup and DB checks. |

## 12. Troubleshooting

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| "Publish update" fails at "Verify Signed Manifest" with "no usable public key" | `UPDATE_SIGNING_PUBLIC_KEYS` still the placeholder, or not the key in the secret | Put the right public key in code (checklist step 5), new version, new tag. |
| "tag vA != version.json vB" | Tagged a commit without the version bump | Delete the tag (`git push origin :refs/tags/vA`), bump, re-tag. |
| "Release notes missing" | `docs/release_notes/<ver>.{ar,en}.txt` absent | Nothing was published. Add both files in a new commit, delete the tag (`git push origin :refs/tags/vX.Y.Z`, `git tag -d vX.Y.Z`) and tag the new commit. |
| "Publish update" fails at "Find Build Run For The Tag" | The tag's build is still running, failed, or older than the 30-day artifact retention | Wait for / fix the build (re-run it on the tag), then run "Publish update" again. |
| "Publish update" fails at "Guard Ref And Tag" | Run from another branch or a tag, typo in the tag, or `version.json` at the tag differs | Run from `main` and type the exact tag. |
| "HOSTINGER_* is not configured" | Variable/secret missing or not visible to the environment | `HOSTINGER_HOST`, `HOSTINGER_USER`, optional `HOSTINGER_PORT` (default 65002) are **variables**; `HOSTINGER_SSH_KEY`, `HOSTINGER_KNOWN_HOSTS` are **secrets**. |
| Public HEAD `Content-Length` mismatch | CDN/compression on `.exe`, or `.htaccess` missing | Check `.htaccess`, add a CDN bypass for `/importflow/updates/`. |
| App shows no update although one is published | Manifest expired, placeholder key in the installed build, older manifest than already seen, or offline | `verify_manifest.py --url ...`; re-sign if expired. |
| Setup aborts: "could not back up the database" | App still running or disk full | Close the app / free disk, retry. Nothing was changed. |
| Setup aborts: "database found in a different installation folder" | An older install lives under Program Files or another path | Stop. Do not move files by hand; CTO plans a supervised move (plan section 0.4). |

## 13. Signing-key rotation (summary)

`UPDATE_SIGNING_PUBLIC_KEYS` has room for two keys. Release N ships with {old, new} and is still signed with old; release N+1 is
signed with new; release N+2 drops old. A manifest signed with a new `key_id` has no `previous` block (the signer ignores a live
manifest it cannot verify with the current key).
Generate a new key with `sign_manifest.py --generate-key --key-id <new id> --key-out <path>` (it refuses to overwrite a file).

Note: both workflows call `sign_manifest.py` **without `--key-id`**, so CI always signs as `k2026a` (`DEFAULT_KEY_ID`). Switching
to a new key needs a reviewed change that passes `--key-id <new id>` in `publish_update.yml` and `resign_update_manifest.yml`,
together with the new `UPDATE_SIGNING_KEY_ED25519` value. The re-sign job fails (by design) while the live manifest still carries
the old `key_id`; publish the first new-key release before the next re-sign is due.
