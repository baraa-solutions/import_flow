# ImportFlow ERP — End-User Update System Plan

> **ملخص سريع:** لما المستخدم يفتح البرنامج على اللابتوب، الباك إند يسأل `https://kamal-sroor.online/importflow/updates/manifest.json`
> (Hostinger، ملفات static على HTTPS). الـ manifest موقّع بمفتاح Ed25519 والمفتاح العام مزروع في البرنامج، وفيه SHA-256 للـ installer.
> لو فيه إصدار أحدث، يظهر شريط فيه "تحديث متاح vX" و"إيه الجديد". لما المستخدم يضغط، الباك إند ينزّل الـ installer ويتأكد من البصمة،
> وياخد نسخة احتياطية من قاعدة البيانات بـ `scripts/daily_backup.py`، وبعدين يشغّل الـ installer (باك إند + فلاتر مع بعض) والبرنامج يفتح تاني.
> أول تشغيل بعد التحديث بيعمل Alembic migration، ولو فشلت، التراجع بيكون باسترجاع النسخة الاحتياطية وتثبيت الإصدار اللي قبله.
> الريبو **private**، فالتوكن مش هيتشحن مع البرنامج أبداً. الـ CI بيرفع على Hostinger بـ SFTP بمفتاح SSH مخصص. الـ installer بيترفع الأول والـ manifest آخر حاجة.
> **شرط قبل النشر العام:** الـ installer حالياً بيشحن `sorour_logistics.db` وبيكتب فوق قاعدة اللابتوب (Critical). لازم ده يتصلح في Phase 0 قبل أي حاجة تانية.

Scope: end-user update of the single production laptop only. `production_sync` (dev->prod DB sync) is **out of scope, to be retired separately**.
The exception is §0: production_sync's destructive routes get disabled in the production build.
Everything below is a plan. Nothing here is executed in Track 1; CI/Hostinger/signing steps are Track 2.

---

## 0. Production database safety (overrides everything below)

> **الأولوية المطلقة (قرار الـ CTO):** قاعدة بيانات الإنتاج على اللابتوب ممنوع تفقد أو يتكتب فوقها أي بيانات. أي حاجة في الخطة تتعارض مع القسم ده، القسم ده هو اللي بيكسب.

### 0.1 Where the data actually lives on the installed laptop (evidence)
Evidence is from code; "verify" items need a 2-minute check on the laptop (§0.6 Q1–Q3).
- **DB file:** `database/database.py:9-14`: when frozen, `BASE_DIR = Path(sys.executable).parent`, so `DB_PATH = $DATABASE_PATH or {app}\sorour_logistics.db`.
  `backend_runner.py:47-49` also `chdir`s to `{app}`. `{app}` = `{autopf}\Sorour Logistics` (`importflow_setup.iss:21,30-31`):
  - per-user install (`PrivilegesRequired=lowest`) → `%LOCALAPPDATA%\Programs\Sorour Logistics\`
  - admin install → `C:\Program Files\Sorour Logistics\`. This is not writable by a non-elevated `asInvoker` process, so if the app works there, it was installed per-user, UAC is off, or the ACLs were changed. **Verify.**
  - `DATABASE_PATH` can't come from `.env` in the frozen build (see next bullet), so only a system/user environment variable could override it.
- **`.env` / `SECRET_KEY`: not persisted in the frozen build (inferred, verify).** `settings.py:9-10` uses `Path(__file__).parent`. In a PyInstaller `--onefile` build
  (`build_backend_exe.py:96`) that path is the temp extraction dir `%TEMP%\_MEIxxxx`, which is deleted on exit. As a result:
  - `SECRET_KEY` is regenerated on **every backend start**, so tokens die at restart. This is not data loss.
  - an `.env` placed in `{app}` is **ignored**, which means `ALLOW_DEV_AUTH_BYPASS` falls back to its safe default `false`
  - the same bug applies to `utils/crypto_utils.py:24-25` (`BACKUP_ENCRYPTION_KEY` is regenerated per process, so an encrypted backup made by the frozen backend could never be decrypted)
  - it also applies to `database/schema_upgrade_service.py:31,59` (`backups_dir = _MEIPASS\backups`, so **the automatic startup snapshots land in a temp dir and vanish**)
  - and to `main.py:443,500` (`version.json` isn't found, so the backend reports default versions)
- **Uninstaller:** there is no `[InstallDelete]`/`[UninstallDelete]`. The DB entry has `uninsneveruninstall` (`.iss:47`). `.env`, `backups\`, `*-wal`/`*-shm`, and the
  `sorour_logistics_backup_*.db` copies are not installed by Setup, so uninstall **keeps** them. The danger is the **next install**: it overwrites the kept DB (A1).
- **Possible second "production" DB:** `docs/DEV_WORKFLOW.md` says the developer is the real user on one machine and Track 1 runs on the repo-root `sorour_logistics.db`.
  If the laptop also runs Track 1, the real data may be in the repo checkout, not `{app}`. **Verify (Q1).**

### 0.2 Audit: every path that can overwrite, delete, truncate, restore or wipe the DB

| # | Location | Trigger on the laptop | Impact | Fix (phase 0 unless noted) |
|---|----------|-----------------------|--------|-----------------------------|
| A1 | `installer/importflow_setup.iss:47` `Source: ...sorour_logistics.db; Flags: ignoreversion` | Every install, re-install and in-app update | **Critical.** The live DB is replaced by the build-time DB. A stale `-wal`/`-shm` from the old DB stays next to the new file and can corrupt it. | Delete the line. The backend creates an empty DB on first run (`create_all` + master-data sync). Add a `[Code]` guard: abort the install if `{app}\sorour_logistics.db` exists and the package contains any `*.db`. |
| A2 | `.iss:58-70` pre-install `FileCopy(.db)` only | Every install | The backup misses committed transactions still in `-wal`. It is not verified, lives in `{app}` root, and a failure is silently ignored. | `PrepareToInstall`: taskkill `frontend.exe`/`backend.exe` → wait → copy `.db`+`-wal`+`-shm` to `{app}\backups\pre_install_<ver>_<ts>\` → compare sizes → **return an error (abort install) if any copy fails**. |
| A3 | `package_production.py:106-116` copies the root DB into the bundle (full real data with `--preserve-data`) | Track 2 packaging | Real data gets inside a public installer, and A1 then overwrites the laptop with it | Remove the DB copy entirely (CTO applies the diff; the guard blocks agents) + CI bundle guard (R4). |
| A4 | `package_production.py:123` ships `reset_clean_production_db.py`, `clean_and_isolate_databases.py`, `sync_to_production.py` into `{app}` | Manual `python <script>` in `{app}` (if Python is installed) | `reset_clean_production_db.py:136-143` **unlinks the DB** or `drop_all`, then `:199` `DELETE FROM users`. `clean_and_isolate_databases.py:77` wipes every non-master table. `sync_to_production.py:317` copies a DB over the target (it also has a hard-coded `C:/Users/Hp/Desktop/ImportFlow`, `:53`). | Stop shipping them. Add a guard at the top of each: refuse unless `--target <path> --i-understand-this-destroys-data` is passed **and** a verified backup succeeds first. |
| A5 | `modules/production_sync/service.py:34-53` frozen path resolution | – | When frozen, `root_dir == exe_dir`, so **`DEV_DB == PROD_DB == live DB`** (`:43-51`), and `DATABASE_PATH` is ignored | Covered by A6–A9. Retire production_sync separately. |
| A6 | `production_sync/router.py:129-142` → `service.py:549-571` `POST /restore` | Any ADMIN, one click (no confirmation dialog) | `shutil.copy2(backup, live_db)` while the engine holds open connections and a `-wal` exists, which risks corruption. **Path escape:** `:557-559` accepts **any absolute path** (`Path(filename)`) if the name is not found in `backups\`. | **Frozen build: route returns 403** "غير متاح في نسخة الإنتاج" (R7). Remove the `alt_path` branch now in any case. |
| A7 | `router.py:72-97` `POST /sync-to-prod`, `POST /pull-to-dev` → `service.py:422-520`, `_smart_non_destructive_migrate:173-330` | Any ADMIN, one click, no confirmation | In frozen mode it merges the DB into itself. `pull-to-dev` uses `INSERT OR REPLACE` on every table (`:293`, `preserve_target_user_data=False`), which rewrites every row. If the target is missing, `copy2` a whole DB (`:183-186`). | **Frozen build: 403** (R7) |
| A8 | `service.py:124-139,163` `_cleanup_old_backups(max_keep=50)` globs **all `*.db` in `backups\`** | Every production_sync backup/sync/restore | Deletes `daily_backup_*`, `auto_pre_upgrade_*`, pre-install and pre-update backups (the ones rollback depends on) | Only prune files carrying its own tag prefix. Never touch protected prefixes (R9). Frozen: backup route stays allowed but pruning is limited to its own tag. |
| A9 | `router.py:100-113` `POST /backup` uses `shutil.copy` | ADMIN | A plain copy of a WAL DB can be inconsistent (not destructive) | Switch to the SQLite online backup API (`perform_backup`). |
| A10 | `database/schema_upgrade_service.py:67-103` startup snapshot via `copy2` + keeps 15 | **Every backend start** | In the frozen build it is written to `_MEIPASS\backups` (temp, lost). In dev, a copy is not an online backup. After 15 restarts the snapshot from before an upgrade is pruned. | Write it next to the DB (`Path(DB_PATH).parent / "backups"`), use the online backup API + `integrity_check`, snapshot **only when the code version ≠ the last-seen version**, and never prune protected prefixes (R9). |
| A11 | `schema_upgrade_service.py:105-136` `create_all` + `ALTER TABLE ADD COLUMN` | Every start | Additive only, so no data loss. A failure is just printed and startup continues half-migrated. | Keep it additive. On failure → maintenance mode (R8). |
| A12 | `database/master_data_sync_service.py:170-174` Incoterm responsibilities | Every start | **Overwrites user-edited** `responsible_party/included_in_incoterm/notes` with seed values (business data regresses silently) | Insert-missing only, never update existing rows. Other syncs are insert-only; `:34-75` seeds users only when the table is empty (OK). |
| A13 | `execute_user_database_updates.py:16-21,598-605` (`DELETE FROM import_companies/suppliers/external_service_providers/cargox_*`), `populate_all_world_transport_locations.py:10-14,388` (`DELETE FROM projects`), `clean_transport_locations.py:39`, `update_db_schema.py:282-302` (`DROP TABLE`) | Manual `python` run in the repo (Track 1 box). They loop over **every** candidate DB, including the repo root. | **Critical if the laptop is also the dev box (Q1).** They wipe companies, suppliers, projects. | Not shipped in the installer. Add the same `--target --i-understand...` + verified-backup guard. Remove the multi-candidate loops (explicit single target only). |
| A14 | `scripts/prepare_uat_environment.py:69-90` | Manual | It copies the prod DB to UAT and then wipes the UAT copy. If the paths are misconfigured it could wipe prod. | Assert `target != DB_PATH` (resolved) before any DELETE. |
| A15 | `scripts/restore_database.py:44-105` | Manual | Overwrites the live DB (uses the online backup API, verifies integrity) | Take a verified backup of the current DB first, refuse while `backend.exe` is running, and require `--confirm`. |
| A16 | `scripts/daily_backup.py:36-63,239` retention | Scheduled task / manual | Deletes only `daily_backup_*` older than 30 days (OK). `:239` deletes a **failed** new backup (OK). | Keep. Add a floor: never delete the newest 7, whatever their age. |
| A17 | `backend_runner.py:60-84` watchdog `os._exit(0)`; launcher `taskkill /f /im backend.exe` (`package_production.py:151`) | Every app close | A hard kill mid-transaction is safe in WAL mode (atomic commit). No loss. | Keep. Add `PRAGMA wal_checkpoint(PASSIVE)` on clean shutdown (nice-to-have). |
| A18 | Future `app_update` rollback (§4.5) | ADMIN | Restore loses data entered since the update | Manual + confirm only, current DB copied aside first, never automatic (R8). |

### 0.3 Defense-in-depth rules (the implementation must satisfy all; each has a test)
- **R1** The installer never ships, overwrites or deletes `*.db`, `*.db-wal`, `*.db-shm`, `.env`, `backups\`, `updates\`. No `[InstallDelete]`/`[UninstallDelete]` may match them.
- **R2** The installer takes a pre-install file-level backup of `.db`+`-wal`+`-shm` after killing both processes, and **aborts on failure** (A2).
- **R3** Uninstall keeps all data (`uninsneveruninstall` isn't needed any more because the DB is no longer a Setup file, so Setup never owns it).
- **R4** CI and `/release-check` fail if the staged bundle contains `*.db*`, `.env*`, `*.pem`, `*.key`, or any script listed in A4/A13.
- **R5** Before an update is applied: `perform_backup` (online API) + `PRAGMA integrity_check == ok` + SHA-256 recorded. **Any failure aborts the update.**
- **R6** Migrations: take a verified backup first, then run. The baseline is **stamp-only** (no DDL). Non-additive changes only through reviewed Alembic revisions using `batch_alter_table`;
  `utils/migration_linter.py` (already bans unguarded `DROP TABLE`) runs in CI on `alembic/versions/`.
- **R7** In the frozen (production) build, `POST /production-sync/{sync-to-prod,pull-to-dev,restore}` return **403** with detail "غير متاح في نسخة الإنتاج".
  Detection: `settings.IS_PRODUCTION_BUILD = getattr(sys, "frozen", False)`. It can't be overridden by env.
- **R8** No automatic restore, ever. On migration or integrity failure the backend starts in **maintenance mode** (read-only: only health/auth/app-update routes). Restore is a manual, confirmed action
  that first copies the current DB aside.
- **R9** Retention never deletes protected backups: prefixes `pre_install_`, `pre_update_`, `pre_migration_`, `pre_restore_`, and at least the newest 7 `daily_backup_*`.
  Every pruner uses one shared `is_protected_backup(path)` helper.
- **R10** Startup refuses writes on a DB **newer than the code**: `alembic_version` not in the bundled script directory → maintenance mode.
- **R11** All runtime paths are anchored to `Path(sys.executable).parent` when frozen (DB, backups, `.env`, `version.json`, the encryption key), never `__file__` (fixes §0.1).
- **R12** Destructive root scripts (A4, A13, A14, A15) require an explicit single `--target`, the `--i-understand-this-destroys-data` flag, a successful verified backup, and
  refuse to run while `backend.exe` holds the DB.

### 0.4 DB location decision
**Keep the DB in `{app}` for now. Don't move it.** Moving it touches the one file that must not break, and every benefit (a clean Program Files install) can wait.
Once R1–R12 are in and tested, a later, separate change can move it to `%LOCALAPPDATA%\SorourLogistics\data\`:
1. verified backup
2. copy with the online backup API to the new path
3. `integrity_check` + row counts per table must match
4. write a pointer file `{app}\data_location.json`
5. keep the old file renamed `sorour_logistics.db.migrated-<ts>` (never delete it)
6. the next start reads the pointer, and falls back to the old path if the new one is missing

### 0.5 Safety test suite (`tests/unit/test_db_safety_*.py`, `frontend/` not involved)
- `test_db_safety_installer.py`: parse `.iss` and assert:
  - no `[Files]` source matches `*.db*`/`.env`
  - no `[InstallDelete]`/`[UninstallDelete]` matches data
  - `PrepareToInstall` exists and returns an error on copy failure (R1–R3)
- `test_db_safety_bundle_guard.py`: the guard script fails on a temp bundle containing `x.db` / `.env` / `reset_clean_production_db.py` (R4)
- `test_db_safety_production_sync.py`: with `IS_PRODUCTION_BUILD` patched true, `sync-to-prod`/`pull-to-dev`/`restore` return 403. `restore` with an absolute path is rejected in dev too. `_cleanup_old_backups` never deletes protected prefixes (R7, R9, A6).
- `test_db_safety_retention.py`: every pruner (`daily_backup`, `schema_upgrade_service`, production_sync) keeps protected files and the newest 7 daily backups (R9)
- `test_db_safety_startup.py`, all on temp DB copies:
  - snapshot path is next to `DB_PATH`
  - snapshot only on version change
  - integrity-check failure → maintenance mode
  - unknown `alembic_version` → maintenance mode, and no write succeeds (R8, R10, A10)
- `test_db_safety_master_data.py`: user-edited incoterm responsibility survives `sync_all()` (A12)
- `test_db_safety_frozen_paths.py`: with `sys.frozen`/`sys.executable` patched, settings/crypto/schema-upgrade/version paths resolve under the exe dir (R11)
- `test_db_safety_scripts.py`: each destructive script exits non-zero without the flags, and with them but a failing backup (R12)
- `test_app_update_backup_gate.py`: `apply` aborts and doesn't launch the installer when `perform_backup` raises or `integrity_check != ok` (R5)

**Delivery status (2026-09-24):** Phase 0 shipped R1-R4, R7-R9, R11, R12 with their tests. R5 (`test_app_update_backup_gate.py`),
R6 (Alembic via `migration_runner`) and R10 (unknown `alembic_version` → maintenance) are deliberately deferred: R6/R10 ship in
Phase 2 (backup + migrations) and R5 in Phase 5 (apply/rollback). No installer built from this branch goes to the laptop before they land.

### 0.6 Questions the CTO must answer before Phase 0 code lands (2-minute checks on the laptop)
- **Q1** Where is the real DB? Task Manager → `backend.exe` → "Open file location", and check for `sorour_logistics.db` there. Is Track 1 (`python main.py` from a repo checkout) also used on this laptop?
- **Q2** Does `{app}\backups\` contain `auto_pre_upgrade_*` files? If none do, that confirms A10/§0.1 (the startup snapshots have been going to temp).
- **Q3** Take a manual copy of `{app}\sorour_logistics.db` (with the app closed) to USB **today**, before any installer from this plan runs.

---

## 1. Goal & business rules

When the app starts on the production laptop (one standalone Windows machine: `backend.exe` + `frontend.exe` from one Inno Setup installer), it checks a
signed release manifest. If a newer version exists, it shows the version and the release notes. On the user's click it downloads the installer, verifies
SHA-256 against the signed manifest, takes a verified DB backup, runs the installer silently (backend and Flutter ship together; an old Flutter against
a new backend gets 401 after the auth change), then relaunches. The first backend start runs DB migrations. A failed start has a documented rollback
path. Constraints: `ALLOW_DEV_AUTH_BYPASS=false` on the laptop; no secrets in the app or the installer; Track 1 never bumps versions or packages.
This is cross-cutting infrastructure, not a GP-002 business stage. No BP/MD codes apply.

## 2. Current state and failure modes

| # | Where | What happens today | Failure mode |
|---|-------|--------------------|--------------|
| C1 | `installer/importflow_setup.iss:47` | `Source: ...\sorour_logistics.db; Flags: ignoreversion` | **Critical.** Every install or update overwrites the laptop's operational DB with the DB bundled at build time. With `--preserve-data` (`package_production.py:106-111`) the bundle is the developer's **full real DB** (users, financials). If published publicly, that is a data leak. In CI (no DB in the repo) ISCC fails on a missing source. |
| C2 | `.github/workflows/build_and_release.yml:3-9,76-78` | Releases on **every push to main**; runs `package_production.py` **without `--no-bump`** (`package_production.py:351-362`) | CI bumps the version in its own checkout (never committed). The tag doesn't match the repo. CI was red for weeks, so there has been no GitHub Release since v1.0.60. |
| C3 | `version.json` (repo root) + `package_production.py:321-347` | `installer_url` points at `github.com/.../releases/download/v2.0.3/...` | The version gets advertised before its asset exists. That link returns 404. On a **private** repo, anonymous downloads always return 404 anyway. |
| C4 | `modules/production_sync/service.py:765,849` | Update check reads `raw.githubusercontent.com/.../main/version.json` | The private repo returns 404. `except: pass` then reports "up to date" (`:827-837`). The app never learns about updates. |
| C5 | `frontend/.../widgets/system_update_banner.dart:59-81` + `main.py:434-493` | Banner compares Flutter `clientVersion` with the **local** backend `version.json` | This only detects a Flutter/backend mismatch. It never discovers a new release. |
| C6 | `frontend/.../services/auto_updater_service.dart:52-111` | Downloads to `%TEMP%` and runs `Process.start(installer, ['/SILENT','/NORESTART'])` | **No SHA-256, no signature check.** Anything served at the URL gets executed. The only check is size under 1 KB. |
| C7 | `main.py:496-532` | Public `GET /api/v1/system/download-installer` serves the newest `dist/releases/*.exe` or **redirects to `installer_url` from version.json** | This is an unauthenticated 200 MB binary endpoint and an open redirect driven by a file. The installed laptop has no `dist/releases`. |
| C8 | `modules/production_sync/service.py:737-751` | SSRF allow-list is a prefix check on user-supplied `remote_url`; `urllib` follows redirects | A redirect escapes the allow-list, and any logged-in user can trigger it. (It is retired with production_sync. The new design takes no URL from the client.) |
| C9 | `main.py:361-367`, `database/schema_upgrade_service.py:105-136` | Startup = file copy + `create_all` + additive `ALTER TABLE ADD COLUMN` | Alembic never runs at startup. `alembic/env.py:33` uses `alembic.ini:89` (`./sorour_logistics.db`) and ignores `DATABASE_PATH`. `alembic/` is not bundled in `backend.exe` (`build_backend_exe.py:91-109`). Non-additive changes (rename, NOT NULL, data fixes) have no path. |
| C10 | `scripts/daily_backup.py:30,200` | `perform_backup()` hard-codes `ROOT_DIR/sorour_logistics.db` | It is not importable from `backend.exe` and not parameterised by `DATABASE_PATH`. |
| C11 | `installer/importflow_setup.iss:55` | `[Run] ... skipifsilent` | A silent update never relaunches the app. |
| C12 | `build_and_release.yml:43,93` | `subosito/flutter-action@v2`, `softprops/action-gh-release@v2` pinned by tag | Supply-chain risk. The job has `contents: write`. |
| C13 | `main.py:174,380,411` | Version `"2.0.3"` hard-coded 3× | Drift against `version.json`. |
| C14 | `frontend/.../login_screen.dart:119-128,389-412`; `database/master_data_sync_service.py:48-68` | Demo chips with `admin123/manager123/operator123`; fixed seed passwords | These become public knowledge once the installer is public. Low impact because the backend binds to 127.0.0.1, but they must go before public hosting. |

## 3. Distribution host (private repo)

| Option | Security | Setup effort (1 laptop) | Failure modes |
|--------|----------|-------------------------|---------------|
| **(a)** CI pushes assets + manifest to a separate **public releases-only GitHub repo** | Good. No source is exposed, integrity comes from the signed manifest, and the cross-repo push needs a PAT/deploy key in Actions. | Low | GitHub rate limits and redirects to `objects.githubusercontent.com` (allow-list must include it). The 2 GB asset limit is fine. |
| **(b)** Fine-grained read-only PAT on the laptop (DPAPI / Credential Manager), app calls the private Releases API | Weakest. A token on the endpoint can read **all source** in the repo (Contents:read is needed for assets). Tokens expire (max 1 year), so rotation means touching the laptop. A stolen laptop means leaked source. | Medium | Token expiry silently stops updates. Asset download needs an `Accept: application/octet-stream` + redirect dance. |
| **(c) Hostinger shared hosting — static HTTPS files (RECOMMENDED)** | Good. No credential on the laptop. SFTP key only lives in Actions secrets. Integrity comes from Ed25519 + SHA-256, not from the host. | Low (one-time hPanel checklist, §9) | Host down means "update check failed" and the app keeps working. The account password could leak, but a forged installer still fails signature verification. |

**Recommendation: (c).** Base URL **`https://kamal-sroor.online/importflow/updates/`** (docroot `public_html/importflow/updates/`).
Use a path, not a subdomain: SSL already covers the domain, and it needs no DNS or extra certificate. A subdomain (`updates.kamal-sroor.online`) is an easy later move because
the base URL is one constant.

**Files can be public.** Integrity does not depend on the transport or on secrecy. It holds because every client verifies the Ed25519 signature on the manifest
and the SHA-256 of the installer. The installer must contain no secrets, and that holds **only after Phase 0**:
- Not in git: `.env`, `*.db`, keys. A grep for `sk-`, `AIza`, `ghp_`, `github_pat_`, `PRIVATE KEY` in `*.py/*.dart/*.json/*.yaml` found nothing. `settings.py` generates
  `SECRET_KEY` / `ADMIN_INITIAL_PASSWORD` **at runtime** on the target machine.
- **Currently violated:** the installer bundles `sorour_logistics.db` (C1). The installer also ships `sync_to_production.py` and `reset_clean_production_db.py`
  (`package_production.py:123`); the latter contains the fixed demo passwords. Phase 0 removes both and adds a CI guard.
- HTTP Basic Auth or an unguessable path is **not needed**. It is optional defence-in-depth. Adding it later means putting a credential in the app, and that goes against
  "no secrets in the app". Recommendation: don't add it.

## 4. Target architecture

### 4.1 Hosted layout
```
public_html/importflow/updates/
  .htaccess
  manifest.json                  <- signed envelope, replaced atomically, no-store
  releases/2.1.0/Sorour_Logistics_Setup_v2.1.0.exe
  releases/2.0.9/...             <- keep the last 3 for rollback
```

### 4.2 Manifest (single file, signature inside, so one atomic rename)
```json
{
  "key_id": "k2026a",
  "signature": "<base64 Ed25519 over the exact UTF-8 bytes of 'signed'>",
  "signed": "{\"schema\":1,\"app\":\"sorour-logistics\",\"channel\":\"stable\",\"version\":\"2.1.0\",\"build_number\":210,
             \"released_at\":\"2026-10-01T10:00:00Z\",\"min_supported_version\":\"2.1.0\",\"mandatory\":false,
             \"db_schema_revision\":\"<alembic head>\",
             \"release_notes\":{\"ar\":[\"...\"],\"en\":[\"...\"]},
             \"installer\":{\"path\":\"releases/2.1.0/Sorour_Logistics_Setup_v2.1.0.exe\",\"size_bytes\":212654321,
                            \"sha256\":\"<64 hex>\"},
             \"previous\":{\"version\":\"2.0.9\",\"path\":\"releases/2.0.9/...exe\",\"sha256\":\"...\",\"size_bytes\":0}}"
}
```
Rules enforced by the client:
- The signature is verified with a public key **embedded in code** (`UPDATE_SIGNING_PUBLIC_KEYS = {key_id: base64}`, two slots for rotation).
- `installer.path` must be **relative**. The client builds the URL as `BASE_URL + path` and rejects `://`, `..`, and leading `/`.
- The client never offers a version at or below the installed one (no downgrade or freeze attack via the manifest). Rollback is a separate explicit path (§4.5).
- `mandatory = mandatory OR installed < min_supported_version`.
- No secrets and no absolute URLs in the manifest.

Signing key: Ed25519 private key in the GitHub Actions secret `UPDATE_SIGNING_KEY_ED25519`, gated by environment `production-updates`, plus an offline copy
held by the CTO (password manager + USB) for manual releases. Rotation: release N trusts {old, new}, N+1 is signed with new, and N+2 drops old.

### 4.3 Release pipeline (Track 2, CI)
Split into two workflows:
- `ci.yml` (new): on PR/push. Runs pytest (Py 3.12) and `flutter test`. **Never publishes.**
- `build_and_release.yml` (rewritten): trigger **only** `push: tags: ['v*']` + `workflow_dispatch`. Has two jobs.
  1. `build` (windows-latest, `permissions: contents: read`):
     - checkout
     - assert tag == `version.json.version`
     - `check_release.py` static gates
     - tests
     - `build_backend_exe.py`
     - `flutter build windows --release`
     - `package_production.py --no-bump`
     - guard: fail if `dist/Sorour_Logistics_Standalone` contains `*.db`, `.env`, `*.pem`, `*.key`, or `sync_to_production.py` / `reset_clean_production_db.py`
     - ISCC
     - `scripts/release/build_manifest.py`: size + sha256, writes an unsigned `signed` payload
     - upload-artifact
  2. `publish` (ubuntu-latest, `environment: production-updates` with CTO as required reviewer, `needs: build`):
     - download artifact
     - sign manifest (`build_manifest.py --sign`, key from secret, key file in `$RUNNER_TEMP`, shredded after)
     - SFTP publish (§4.4)
     - public verification: `curl` manifest + installer from `BASE_URL`, run `scripts/release/verify_manifest.py` (same code path as the client)
     - create a **private** GitHub Release as the audit record (optional)
  All actions pinned by full commit SHA with a `# vX.Y.Z` comment.

### 4.4 Atomic publish over SFTP (Hostinger)
Secrets/vars:
- secret `HOSTINGER_SSH_KEY` (dedicated ed25519, CI only)
- variables `HOSTINGER_HOST`, `HOSTINGER_PORT` (=65002), `HOSTINGER_USER`, `HOSTINGER_KNOWN_HOSTS` (pinned host key, no `StrictHostKeyChecking=no`)
- variable `UPDATE_REMOTE_DIR` (=`public_html/importflow/updates`)

The account username and host do not go into any repo file other than this plan.
```bash
# sketch — publish job
install -m600 /dev/null ~/.ssh/id && echo "$HOSTINGER_SSH_KEY" > ~/.ssh/id
echo "$HOSTINGER_KNOWN_HOSTS" > ~/.ssh/known_hosts
R=$UPDATE_REMOTE_DIR; V=$VERSION; F=Sorour_Logistics_Setup_v$V.exe
sftp -i ~/.ssh/id -P "$HOSTINGER_PORT" -b - "$HOSTINGER_USER@$HOSTINGER_HOST" <<EOF
-mkdir $R/releases/$V
put dist/releases/$F $R/releases/$V/$F.part
rename $R/releases/$V/$F.part $R/releases/$V/$F
EOF
# 1) verify what clients will actually receive (bypasses any CDN cache)
curl -fsS "$BASE_URL/releases/$V/$F?nocache=$RUN_ID" -o /tmp/check.exe
test "$(sha256sum /tmp/check.exe | cut -d' ' -f1)" = "$EXPECTED_SHA256"
# 2) manifest LAST: upload temp, then rename in the same directory (atomic on the server FS)
sftp ... <<EOF
put manifest.json $R/manifest.json.tmp
rename $R/manifest.json.tmp $R/manifest.json
EOF
# note: OpenSSH sftp 'rename' fails if target exists -> use 'posix-rename' (OpenSSH server extension; verify on Hostinger), else rm+rename (tiny window: client sees 404 -> 'check failed', harmless)
# 3) prune: keep newest 3 dirs under releases/
```
Shared-hosting limits:
- SFTP has no PHP upload cap, so a ~200 MB installer is fine. The **hPanel File Manager may cap uploads**; if it rejects the file, use FileZilla over SFTP.
- Bandwidth is trivial (one laptop, ~200 MB per release).
- Inodes and disk are bounded by pruning to 3 releases.

### 4.5 Client update flow (backend owns the logic, Flutter owns the UI)
Why backend: Python already has `cryptography`/`httpx`, it owns the DB for the backup, and all trust decisions live in one tested place. Flutter needs no crypto dependency.

1. **Check.** On app start (after login) and every 24 h, Flutter calls `GET /api/v1/app-update/check`. The backend fetches `BASE_URL/manifest.json?t=<ts>`
   with `httpx` (`follow_redirects=False`, 10 s timeout, 64 KB max body), verifies the signature, compares with the installed `version.json`, and caches the verified
   manifest for 1 h in memory plus on disk (`%LOCALAPPDATA%\SorourLogistics\updates\last_manifest.json`).
2. **Notice.** The banner shows "update available vX" and a dialog lists release notes in the UI language, the size, and whether the update is mandatory.
3. **Download** (`POST /download`): streams to `...\updates\staging\<file>.part`, hashing while streaming, and aborts if bytes exceed `size_bytes`.
   On mismatch it deletes the file (`422`). On match it renames to the final name, and the state becomes `ready`. Flutter polls `GET /status` for progress.
4. **Apply** (`POST /apply`):
   - re-hash the staged file (TOCTOU guard)
   - `perform_backup(db_path=DB_PATH, backups_dir=<backups>/pre_update)`: SQLite online backup API + `PRAGMA integrity_check` + SHA-256. If it fails, **abort** and don't install.
   - the currently installed installer is not kept on disk; the marker records `previous` from the manifest, and rollback downloads and verifies it when needed.
   - write `pending_update.json` {from_version, to_version, backup_file, backup_sha256, started_at}
   - append to `update_history.jsonl` and `audit_logs`
   - spawn the installer detached (`DETACHED_PROCESS|CREATE_BREAKAWAY_FROM_JOB`) with
     `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1 /LOG="...\updates\logs\install_<ver>.log"`
   - return `202`. Flutter shows "installing, the app will restart" and calls `exit(0)`. The installer's `PrepareToInstall` taskkills `frontend.exe` / `backend.exe`.
5. **Install.** Inno replaces binaries. It never touches `*.db`, `.env`, `backups\`, or `updates\` (Phase 0). `[Run]` relaunches the app when `/RELAUNCH=1`.
6. **First start / migration.** The backend runs startup in this order:
   1. (existing) WAL checkpoint + snapshot
   2. **Alembic `upgrade head`** for stamped DBs
   3. existing `create_all` + additive columns as a safety net
   4. master data sync
   5. unstamped DB (today's laptop): after step 3, `stamp head` (baseline)
   On migration error the backend starts in **maintenance mode**: only `/health`, auth, and `/api/v1/app-update/*` respond, and the others return `503` "قاعدة البيانات تحتاج استرجاع".
7. **Post-update health check.** If `pending_update.json` exists: the version must equal `to_version`, the migration must be OK, `PRAGMA quick_check` must be OK, and Flutter's `clientVersion`
   must equal the backend's version (Flutter sends `X-Client-Version`). On success: log, delete the marker, and Flutter shows a one-time "updated to vX" SnackBar via `GET /last-result`.
   On failure: `last-result` = failed, and Flutter shows the rollback screen.
8. **Rollback** (`POST /rollback`, admin, explicit confirmation):
   1. download + verify the `previous` installer from the cached manifest
   2. stop DB access and copy the current DB aside (`failed_<ver>_<ts>.db`)
   3. restore `backup_file` (integrity + sha check), reusing `scripts/restore_database.py` logic
   4. run the previous installer with `/RELAUNCH=1`
   The restore **loses data entered since the update**, so the dialog shows the backup timestamp.
   The offline fallback is the USB path below with the old installer.

### 4.6 Offline / GitHub-or-Hostinger unreachable / USB
- Check fails: `check_status = offline`. No banner and no error SnackBar. The About/System section shows "last successful check: …". The app works normally.
  A mandatory update **cannot be enforced offline**, and that is accepted (the app is local-only).
- **USB fallback** (`POST /stage-local`): the user picks `manifest.json` + the `.exe` with `FilePicker` (open dialog). The backend verifies signature + hash, copies both to
  staging, and from then on it is the same `apply` flow. The same trust model applies, so USB media can't inject an unsigned build.

### 4.7 Optional vs mandatory; version compatibility
- Optional: dismissible banner ("remind me later"), which returns after 24 h or on the next app start.
- Mandatory (`mandatory` or installed < `min_supported_version`): non-dismissible dialog after login, with only "install now" and "sign out". Use it only for security fixes and
  breaking backend/DB changes.
- Backend and frontend always ship in one installer, so their version must be equal. `/api/v1/system/version` keeps its current fields for the
  pre-login compatibility check. It stops advertising `installer_url` / `local_download_url` (they stay present but empty for one release, then get removed).
- DB schema: the manifest carries `db_schema_revision`. At startup the backend refuses (maintenance mode) a DB whose `alembic_version` is not known to its
  own script directory. That covers "old binary on newer DB" after a half-done rollback.

### 4.8 Dev-mode guard (Track 1)
`apply`, `download`, `stage-local`, and `rollback` return `400` "التحديث التلقائي غير متاح في وضع التطوير" unless `sys.frozen` **and** `unins000.exe` exists next to
`backend.exe`. `check` still works (it reports `apply_supported=false`). This means `python main.py` can never install over the dev tree.

### 4.9 Security summary
- No update route accepts a URL. The base URL is a code constant; `.env` `UPDATE_BASE_URL` override is allowed only if the scheme is `https` and the host is in
  the code allow-list `{kamal-sroor.online}`. No redirects are followed.
- Integrity comes from Ed25519 (manifest) + SHA-256 (installer). Transport is not trusted.
- Permissions: `check`/`status`/`last-result` need any authenticated user. `download`/`apply`/`cancel`/`stage-local`/`rollback`/`history` need **`system.update`** (new, ADMIN only).
- `GET /api/v1/system/download-installer` gets **removed** (public binary + open redirect, C7).
- Optional Authenticode: not required for integrity. It only removes SmartScreen prompts on manual installs. Defer (see decisions).

### 4.10 Observability
- `%LOCALAPPDATA%\SorourLogistics\updates\update_history.jsonl` (outside the DB, so it survives a DB restore), one line per event:
  check_ok/failed, download_started/verified/hash_mismatch, backup_ok/failed, install_launched, post_update_ok/failed, rollback_*.
- `audit_logs` entry for user actions (download, apply, rollback) with the username.
- Inno log `...\updates\logs\install_<ver>.log`.
- `GET /history` shows the last 50 entries on the System screen.

## 5. Data model
No new tables (the update history is deliberately file-based so it survives DB restore).
**Alembic:** one no-op **baseline revision** `e1f2a3b4c5d6_update_system_baseline.py` (down_revision = current head `d3e4f5a6b7c8`) as the stamp target.
`alembic/env.py` must take the URL from `database.database.DATABASE_URL` (honours `DATABASE_PATH`). `alembic/` + `alembic.ini` get bundled into `backend.exe`
(`--add-data`); the runner sets `script_location` from `sys._MEIPASS` when frozen.

## 6. API contract — new router `modules/app_update/router.py`, prefix `/api/v1/app-update`, `dependencies=[Depends(get_current_user)]`

| Method + path | Permission | Request | Response 2xx | Errors (status, Arabic `detail`) |
|---|---|---|---|---|
| GET `/check?force=bool` | authenticated | – | 200 `UpdateCheckResponse`: `current_version:str, current_build:int, latest_version:str\|null, latest_build:int\|null, update_available:bool, mandatory:bool, release_notes:{ar:[str],en:[str]}, released_at:datetime\|null, installer_size_bytes:int\|null, check_status: up_to_date\|update_available\|offline\|invalid_signature\|disabled, last_checked_at:datetime\|null, apply_supported:bool` | none: failures map to `check_status` |
| GET `/status` | authenticated | – | 200 `UpdateStatusResponse`: `state: idle\|downloading\|verifying\|ready\|backing_up\|installing\|failed, version:str\|null, downloaded_bytes:int, total_bytes:int, error_code:str\|null, error_detail:str\|null` | – |
| POST `/download` | `system.update` | `{version: str}` (regex `^\d+\.\d+\.\d+$`, must equal the cached verified manifest version) | 202 `UpdateStatusResponse` | 409 "لا يوجد تحديث متاح لهذا الإصدار"; 409 "جاري تنزيل التحديث بالفعل"; 503 "تعذّر الاتصال بخادم التحديثات"; 400 dev-mode |
| POST `/cancel` | `system.update` | – | 200 status | 409 "لا توجد عملية تنزيل جارية" |
| POST `/apply` | `system.update` | `{version: str}` | 202 `{state:"installing", backup_file:str}` | 409 "التحديث غير جاهز للتثبيت"; 422 "الملف الذي تم تنزيله غير مطابق للبصمة الرقمية وتم حذفه"; 500 "فشل النسخ الاحتياطي، تم إلغاء التحديث"; 400 dev-mode |
| POST `/stage-local` | `system.update` | `{manifest_path: str, installer_path: str}` (existing files, `.json` / `.exe`, installer ≤ 1 GB) | 200 status (`ready`) | 422 "توقيع ملف الإصدار غير صالح"; 422 "بصمة ملف التثبيت غير مطابقة"; 400 "الملف غير موجود"; 409 "الإصدار ليس أحدث من المثبت" |
| POST `/rollback` | `system.update` | `{confirm: true, backup_file: str}` (must be the marker's or listed pre-update backup) | 202 `{state:"installing", restored_from:str}` | 409 "لا توجد نسخة سابقة متاحة للتراجع"; 422 "النسخة الاحتياطية تالفة"; 400 dev-mode |
| GET `/last-result` | authenticated | – | 200 `{result: none\|success\|failed, from_version, to_version, finished_at, detail}` | – |
| GET `/history?limit=50` | `system.update` | limit 1–200 | 200 `{items:[{ts, event, version, detail}]}` | – |

New permission in `modules/auth/seed_rbac.py` `PERMISSIONS_CATALOG`:
`{"code":"system.update","module":"system","action":"update","en":"Install System Updates","ar":"تنزيل وتثبيت تحديثات النظام","desc":"Can download, install and roll back application updates"}`, granted to ADMIN only.
Removed: `GET /api/v1/system/download-installer` (and its entry in the public allow-list + `tests/unit/test_route_auth_coverage.py:37`).

## 7. Backend work (backend-developer)
Reference patterns: `modules/system_observability/` (system module without its own tables), `modules/production_sync/router.py` (router shape),
`tests/unit/test_version_and_updates_api.py`, `tests/unit/test_schema_upgrade_service.py`.
- `modules/app_update/model.py`: none/empty docstring (no tables). `schemas.py`: models from §6. `validators.py`: version regex, relative-path check,
  base-URL allow-list, dev-mode guard, backup-file whitelist. `repository.py`: file I/O for `last_manifest.json`, `pending_update.json`, `update_history.jsonl`
  (the "DB" of this module). `service.py`: `ManifestVerifier` (Ed25519 via `cryptography`), `UpdateService` (check/download thread/apply/rollback/stage-local,
  state machine with a lock). `router.py`: HTTP only.
- `settings.py`: `UPDATE_BASE_URL` (default constant), `UPDATE_DATA_DIR` (default `%LOCALAPPDATA%\SorourLogistics\updates`).
- `scripts/daily_backup.py`: `perform_backup(..., db_path: Path | None = None, backups_dir: Path | None = None)` with defaults unchanged (the CLI is unchanged).
  Add `scripts/__init__.py` and a PyInstaller hidden import so `backend.exe` can import it.
- `database/migration_runner.py` (new): `run_startup_migrations(engine) -> MigrationResult` (upgrade/stamp/baseline logic, maintenance flag).
  `database/schema_upgrade_service.py`: call it in the order in §4.5 step 6. `alembic/env.py`: URL from `DATABASE_URL`. New baseline revision.
- `main.py`: include `app_update` router; maintenance-mode middleware; delete `download-installer`; replace the hard-coded `"2.0.3"` (×3) with `get_installed_version()`.
- `build_backend_exe.py`: `--add-data alembic;alembic`, `--add-data alembic.ini;.`, hidden imports for `modules.app_update.*`, `scripts.daily_backup`.
- `requirements.txt`: pin `cryptography` explicitly (it is currently only transitive).
- Release tooling (CI owner, Python): `scripts/release/build_manifest.py` (build + sign), `scripts/release/verify_manifest.py` (shares `ManifestVerifier`).

## 8. Frontend work (flutter-developer)
Reference: the existing dialog/banner UX in `frontend/lib/features/production_sync/widgets/system_update_banner.dart`, rebuilt to standards
(`AppButton`, `AppTheme`, `context.l10n`; no `ElevatedButton`, `Colors.*`, or raw hex colours; no hard-coded Arabic).
- New `frontend/lib/features/app_update/`:
  - `models/update_models.dart` (`UpdateCheckResult`, `UpdateStatus`, `UpdateLastResult`, `UpdateHistoryItem`, fromJson with null-safety)
  - `services/app_update_service.dart` (uses `dioProvider`, base `.../api/v1/app-update`; no second Dio, no download in Dart)
  - `providers/app_update_providers.dart`: `updateCheckProvider` (FutureProvider, refetched on mount + 24 h timer), `updateStatusProvider`
    (polls `/status` every 1 s only while `downloading|verifying|backing_up`), `lastUpdateResultProvider`, `updateBannerDismissedProvider`
    (with a timestamp); `ref.invalidate(updateCheckProvider)` after download/apply/rollback
  - `widgets/update_banner.dart`, `widgets/update_dialog.dart` (release notes, size, progress, mandatory mode `barrierDismissible:false`)
  - `widgets/update_rollback_dialog.dart`
  - `widgets/update_from_file_button.dart` (`FilePicker.pickFiles` for manifest + exe; open dialog, not `FileSaveHelper`, because nothing is exported)
  - `apply`: on 202, show a "restarting" overlay and call `exit(0)` after 800 ms. Backend errors go to a SnackBar with `detail`.
- `frontend/lib/features/home/home_screen.dart:394`: swap `SystemUpdateBanner` for `UpdateBanner` and add a one-time post-update SnackBar from `lastUpdateResultProvider`.
- Delete `frontend/lib/features/production_sync/services/auto_updater_service.dart` and `.../widgets/system_update_banner.dart`. In
  `.../providers/production_sync_provider.dart`, remove **only** `autoUpdaterServiceProvider` and `DownloadProgressState/Notifier/Provider` (lines 13-15, 36-156).
  Nothing else in production_sync changes.
- Localization (`frontend/lib/core/localization/app_localizations{,_ar,_en}.dart`) new keys:
  `updateAvailableBanner(version)`, `updateMandatoryBanner(version)`, `updateWhatsNew`, `updateSize(mb)`, `updateInstallNow`, `updateRemindLater`,
  `updateDownloading(done,total)`, `updateVerifying`, `updateBackingUp`, `updateInstalling`, `updateCancel`, `updateSucceeded(version)`,
  `updateFailed`, `updateRollback`, `updateRollbackWarning(backupTime)`, `updateFromFile`, `updateCheckOffline(lastChecked)`, `updateDevModeDisabled`.
- Login: gate the demo quick-login chips (`login_screen.dart:119-128,389-412`) behind `kDebugMode`. This is a prerequisite for public hosting (Phase 0).
- No pickers of reference data, so no `SearchableDropdownField` needed.

## 9. CTO one-time setup checklist (Hostinger + GitHub)
1. hPanel → Advanced → **SSH Access**: enable SSH (port 65002).
2. On your own machine: `ssh-keygen -t ed25519 -C "importflow-ci" -f importflow_ci` (no passphrase, CI only). hPanel → SSH Access → **SSH keys** → add
   `importflow_ci.pub`. Test it: `sftp -P 65002 -i importflow_ci u910151740@145.79.20.98`.
3. `ssh-keyscan -p 65002 kamal-sroor.online` → compare the fingerprint with hPanel, then save it as the Actions variable `HOSTINGER_KNOWN_HOSTS`.
4. File Manager: create `public_html/importflow/updates/releases/`. Add `public_html/importflow/updates/.htaccess`:
   ```apache
   Options -Indexes
   AddType application/json .json
   AddType application/octet-stream .exe
   <FilesMatch "\.(part|tmp)$">
     Require all denied
   </FilesMatch>
   <Files "manifest.json">
     Header set Cache-Control "no-store, max-age=0"
   </Files>
   <FilesMatch "\.exe$">
     Header set Cache-Control "public, max-age=31536000, immutable"
     Header set X-Content-Type-Options "nosniff"
   </FilesMatch>
   ```
   If the Hostinger CDN is on, add a bypass rule for `/importflow/updates/manifest.json` (the client also adds `?t=`).
5. Generate the signing key (offline):
   `python scripts/release/build_manifest.py --generate-key` → prints the public key (goes into code) and writes a private key file. Store the private key in a password
   manager + USB, and put it in the GitHub secret `UPDATE_SIGNING_KEY_ED25519`.
6. GitHub → Settings → Environments → `production-updates`: required reviewer = CTO. Secrets: `HOSTINGER_SSH_KEY`, `UPDATE_SIGNING_KEY_ED25519`.
   Variables: `HOSTINGER_HOST`, `HOSTINGER_PORT`, `HOSTINGER_USER`, `HOSTINGER_KNOWN_HOSTS`, `UPDATE_REMOTE_DIR`.
7. **Manual fallback if CI fails:**
   - build locally with `package_production.py --no-bump` (never `--preserve-data`)
   - `build_manifest.py --sign --key-file <usb>`
   - upload the `.exe` into `releases/<ver>/` **first**, check `https://kamal-sroor.online/importflow/updates/releases/<ver>/<file>` downloads, and run
     `verify_manifest.py --url` against it
   - **then** upload `manifest.json` (File Manager → upload as `manifest.json.tmp` → rename)
   - if File Manager rejects the 200 MB file, use FileZilla/SFTP on port 65002

## 10. File ownership

| backend-developer | flutter-developer | CI / release (backend-developer, separate commits) |
|---|---|---|
| `modules/app_update/*` (new, 6 files) | `frontend/lib/features/app_update/**` (new) | `.github/workflows/build_and_release.yml` (rewrite) |
| `settings.py`, `main.py` | `frontend/lib/features/home/home_screen.dart` | `.github/workflows/ci.yml` (new) |
| `database/migration_runner.py` (new), `database/schema_upgrade_service.py` | `frontend/lib/features/production_sync/providers/production_sync_provider.dart` (updater parts only) | `scripts/release/build_manifest.py`, `scripts/release/verify_manifest.py` (new) |
| `alembic/env.py`, `alembic/versions/e1f2a3b4c5d6_update_system_baseline.py` (new) | delete `.../production_sync/services/auto_updater_service.dart`, `.../widgets/system_update_banner.dart`, `frontend/test/auto_updater_service_test.dart` | `installer/importflow_setup.iss` |
| `scripts/daily_backup.py`, `scripts/__init__.py` (new) | `frontend/lib/core/localization/app_localizations{,_ar,_en}.dart` | `.claude/skills/release-check/check_release.py` + `SKILL.md` |
| `modules/auth/seed_rbac.py`, `build_backend_exe.py`, `requirements.txt` | `frontend/lib/features/auth/.../login_screen.dart` (demo chips) | `docs/UPDATE_DISTRIBUTION_RUNBOOK.md` (rewrite for the single laptop) |
| `tests/unit/test_route_auth_coverage.py`, `tests/unit/test_version_and_updates_api.py` | | |

Shared file: `package_production.py`. It is blocked by the Bash guard and is Track 2 only. The **user/CTO edits it** (backend-developer supplies the exact diff):
- stop copying the DB into `Sorour_Logistics_Standalone`
- drop `sync_to_production.py` / `reset_clean_production_db.py` / `clean_and_isolate_databases.py` from the util list
- stop writing `installer_url` into `version.json`
- write `dist/releases/release_info.json` {version, build, filename, size, sha256} for `build_manifest.py`

Order: the Phase 1 API contract is frozen before flutter-developer starts Phase 3. `version.json` and `pubspec.yaml` are **not touched** (Track 1).

## 11. Test plan
Backend (`tests/unit/`, pytest, network mocked with `httpx.MockTransport`, temp dirs, never the real DB):
- `test_app_update_manifest.py`
  - valid signature
  - tampered payload
  - wrong key_id
  - absolute/`..` installer path rejected
  - version ≤ installed ignored
  - mandatory via `min_supported_version`
- `test_app_update_service.py`
  - check offline → `offline`
  - download hash match → `ready`
  - mismatch → file deleted + 422
  - oversize abort
  - apply aborts when backup fails
  - apply writes marker + calls a mocked launcher with the exact args
  - dev-mode guard
  - stage-local happy/invalid
  - rollback restores + verifies
- `test_app_update_router.py`
  - 401 without token
  - 403 without `system.update` on download/apply/rollback/history
  - 200 for check/status for OPERATOR
  - no endpoint accepts a URL parameter
- `test_migration_runner.py`
  - fresh DB → create_all + stamp
  - unstamped legacy DB → stamp baseline
  - stamped DB → upgrade
  - unknown revision → maintenance mode
  - `DATABASE_PATH` honoured
- `test_daily_backup_paths.py`: `perform_backup(db_path, backups_dir)` writes there, integrity OK, CLI defaults unchanged.
- Update `test_route_auth_coverage.py` (remove download-installer) and `test_version_and_updates_api.py`.
- `tests/unit/test_release_manifest_tools.py`: `build_manifest.py` sign → `verify_manifest.py` accepts; one-byte change rejects.

Frontend (`frontend/test/`):
- `app_update_models_test.dart`: fromJson, nulls, notes by locale
- `app_update_providers_test.dart`
  - banner hidden when offline/up-to-date
  - mandatory not dismissible
  - polling stops at `ready`/`failed`
  - invalidate after apply
- `update_size_format_test.dart`: bytes → "202.8 MB" in ar/en
- `update_localization_test.dart`: all new keys exist in ar + en
- Keep `no_bare_dio_test.dart` green (the updater must use `dioProvider`).

Gates:
- `/release-check` extended:
  - `version.json` has **no** `installer_url`
  - tag == version
  - bundle guard (no `*.db` / `.env`)
  - the manifest at `BASE_URL` verifies and its installer HEAD returns 200 with the right `Content-Length`
- **Dry run on a clean Windows VM** (Hyper-V/Sandbox) before the first public release:
  1. install vN manually
  2. create data
  3. publish vN+1 to a **staging path** (`/importflow/updates-staging/`, a second base URL allowed only in a debug build)
  4. update from the app
  5. verify data, version, and the migration
  6. roll back
  7. verify the restored data
  8. pull the network → check shows offline
  9. USB path

## 12. Phased rollout (small commits)

DB safety (§0) comes first. No installer is built or run until Phase 0 is merged and its safety suite is green.

| Phase | Content | Owner | Risk |
|---|---|---|---|
| **0 — Production DB safety** (§0) | **0a (backend, Track 1 code):** R7 frozen-build 403 on sync/pull/restore + remove `restore` absolute-path branch (A6); scoped pruning + shared `is_protected_backup` (A8, R9); online backup in `/backup` (A9); `schema_upgrade_service` snapshot next to DB, only on version change, online API + integrity (A10); master-data insert-only (A12); R11 frozen path anchoring in `settings.py`, `utils/crypto_utils.py`, `schema_upgrade_service.py`, `main.py`; R12 guards in destructive scripts (A4, A13–A15); `daily_backup` floor of 7 (A16); `settings.IS_PRODUCTION_BUILD`; the full §0.5 suite. **0b (installer/packaging, Track 2 files, reviewed diff):** `.iss` remove DB `[Files]` line + `PrepareToInstall` verified 3-file backup with abort (A1, A2, R1–R3); `package_production.py` diff for the CTO (no DB copy, no destructive scripts) (A3, A4); bundle guard script `scripts/release/check_bundle.py` (R4). | backend-developer (0a, 0b); CTO applies `package_production.py` | **Live DB:** 0a changes only which files get pruned and when snapshots are taken, never the DB itself. The CTO does Q3 (USB copy) before anything runs on the laptop. |
| **1 — Release hygiene** | CI: tag-only trigger, `--no-bump`, bundle guard step, pin actions by SHA, `ci.yml`, migration linter step. `.iss` `[Run]` relaunch on `/RELAUNCH=1`. Demo chips behind `kDebugMode`. Stop advertising `installer_url` in the next Track 2 release. | backend-developer (CI), flutter-developer (chips) | none on data |
| **2 — Backup + migrations** | `daily_backup` params, `migration_runner` (backup first, stamp-only baseline, maintenance mode, R10), alembic env + baseline, bundling + tests | backend-developer | First start stamps the baseline only (no DDL). The VM rehearsal runs on a copy of the real DB first. |
| **3 — Backend update core** | `modules/app_update` check/verify/download/status + `system.update` + tests | backend-developer | read-only |
| **4 — Flutter UI** | new feature folder, banner/dialog/progress, remove the old updater, l10n, tests | flutter-developer | none |
| **5 — Apply, post-check, rollback, USB** | apply (R5 gate)/last-result/rollback (R8, manual)/stage-local/history + Flutter dialogs + tests | backend-developer, then flutter-developer | the installer launch path is only testable on the VM |
| **6 — Release tooling + hosting** | `build_manifest.py`/`verify_manifest.py`, publish job, CTO checklist §9, release-check gates, runbook rewrite | backend-developer (CI) + CTO | `.htaccess`/CDN caching → curl check in the publish job |
| **7 — Bootstrap** | After Q3 (USB copy): manually install the first updater-capable version on the laptop. The VM dry-run (§11), including an upgrade over an install with a populated DB, must pass first. | CTO | one manual install; DB untouched by Setup (R1) |

Phase 0 file ownership:
- backend-developer:
  - `modules/production_sync/{router,service}.py`
  - `database/schema_upgrade_service.py`, `database/master_data_sync_service.py`
  - `settings.py`, `utils/crypto_utils.py`, `main.py`
  - `scripts/daily_backup.py`, `scripts/restore_database.py`, `scripts/prepare_uat_environment.py`
  - `reset_clean_production_db.py`, `clean_and_isolate_databases.py`, `sync_to_production.py`
  - `execute_user_database_updates.py`, `populate_all_world_transport_locations.py`, `clean_transport_locations.py`, `update_db_schema.py`
  - `installer/importflow_setup.iss`, `scripts/release/check_bundle.py` (new)
  - `tests/unit/test_db_safety_*.py` (new)
- flutter-developer: none in Phase 0. If a restore/sync button now returns 403, the SnackBar already shows `detail`, so no Flutter change is needed.
- CTO: `package_production.py` (diff supplied, the agent guard blocks edits).

## 13. Risks & open questions

Risks:
- **Live DB:** the first run of `migration_runner` on the production DB. Mitigations: pre-run backup, baseline stamp only (no DDL), and the VM rehearsal on a copy of the real DB.
- **Backward compatibility:** the old installed app polls `/system/version` + `production-sync/installer-info` (GitHub, 404). It never auto-updates, hence Phase 6. Removing
  `download-installer` breaks only the old updater, which is already broken.
- Frozen `settings.py` writes `.env` next to `__file__`, which under PyInstaller onefile is the temp `_MEIPASS` dir. Verify where the laptop's `.env`/`SECRET_KEY` actually
  persists before Phase 0, so the installer never touches it and a restart doesn't rotate secrets.
- SQLite migrations on non-additive changes: write them with `batch_alter_table`. Rollback is always "restore backup", never `alembic downgrade`.
- Hostinger SSH shell differences (`posix-rename`, `sha256sum`): the publish job verifies over public HTTPS, so it doesn't depend on the shell.

Decisions for the CTO (recommended option first):
1. Hosting: **(c) Hostinger static + Ed25519** vs (a) public releases-only repo vs (b) PAT on the laptop. Recommended: (c).
2. URL: **`https://kamal-sroor.online/importflow/updates/`** vs `updates.kamal-sroor.online`. Recommended: path now.
3. Publish approval: **required reviewer on the `production-updates` environment** vs fully automatic on tag. Recommended: reviewer.
4. Authenticode signing: **defer** (Ed25519 already protects the update path) vs Azure Trusted Signing (~USD 10/month) now to avoid SmartScreen on manual installs.
5. Who may install: **`system.update` = ADMIN only** vs any logged-in user. On a single-user laptop, ADMIN only is still simple.
6. Mandatory updates: **only for security/breaking-DB releases, set by hand in the tag's release notes** vs always mandatory.
7. Rollback automation: **manual, confirmed rollback button** vs automatic restore on migration failure. Recommended: manual, because automatic restore can silently discard data.
