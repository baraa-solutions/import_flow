# Update System: Phase 2 (migrations) + Phase 5 (apply / rollback / stage-local): implementation spec

> Source plan: `docs/plans/update-system-plan.md` (§0 R5/R6/R8/R10, §4.5, §4.6, §4.8, §5, §6, §11, §12). This spec overrides the plan wherever the two differ; every difference has its reason written next to it.
> Two backend developers work in parallel. **Dev A** does Phase 2, **Dev B** does Phase 5. Their file lists don't overlap (§7). No Flutter change is required.

## Decisions (CTO-delegated, 2026-09-24)

Recorded as relayed by `importflow-lead`. They close the open questions in §9.

1. **Q1 accepted.** Stage-local (USB) ignores `expires_at` and `highest_seen`. The Ed25519 signature, the schema rules, the sha256/size checks and "newer than installed" are still required.
2. **Q2 accepted.** After a rollback, `/check` offers the version you rolled back from again. There is no "skip this version" option for now.
3. **Q3 accepted.** If pre-fetching the previous installer fails, the download still ends in `ready`. A `previous_download_failed` history event is recorded, and rollback then returns 409 with the manual-rollback detail.

## 0. Constraints found in the code

| # | Fact (file) | Consequence |
|---|---|---|
| K1 | `backend_runner.py` watchdog: `os._exit` about 3 s after `frontend.exe` disappears. Flutter calls `exit(0)` 800 ms after a 202 (`app_update_providers.dart`). | Every step of `/apply` and `/rollback`, including launching the installer, finishes **before** the 202 is returned. Nothing runs in the background after the response. |
| K2 | `.iss` `StopRunningApp`: `taskkill /F /IM backend.exe /T` (and the same for `frontend.exe`). The installer is a child process of `backend.exe`. | `/T` kills Setup inside its own PrepareToInstall, so the update silently doesn't happen. **Remove `/T` from both lines.** Matching by image name already kills both PyInstaller onefile processes. |
| K3 | `scripts/daily_backup.perform_backup` always names files `daily_backup_*`, prunes, and syncs offsite. | The R5 pre-update backup uses `utils.db_safety.sqlite_online_backup` directly with the protected prefix `pre_update_`. `perform_backup` is not used for R5. |
| K4 | Update state lives in `%LOCALAPPDATA%\SorourLogistics\updates`, which is shared by the frozen app and `python main.py` on the same Windows user. | The post-update marker is evaluated only when `is_apply_supported()` is true **and** the marker's `app_dir`/`db_path` equal the current process's. |
| K5 | Alembic chain `d70d67c34bda → … → d3e4f5a6b7c8`: single head `d3e4f5a6b7c8`. The repo DB and the laptop DB have no `alembic_version` table. | Baseline `e1f2a3b4c5d6`, down_revision `d3e4f5a6b7c8`, no-op. |
| K6 | `main.py` runs `SchemaUpgradeService.execute_safe_startup_upgrade` at import time. `is_maintenance_mode()` is process-wide. | Phase 2 needs no `main.py` change. Phase 5 reads the migration outcome through `is_maintenance_mode()`/`maintenance_reason()` only, which is why the two phases are independent. |
| K7 | A downgrade install is allowed by Inno. PrepareToInstall takes its own `pre_install_` backup every time. | A rollback install is safe with respect to the DB file. |

---

## A) Phase 2: migrations (Dev A)

### A.1 `utils/db_safety.py` (Dev A, **first commit, lands before B starts using it**)
Add only:
```python
PRE_INSTALL_PREFIX = "pre_install_"; PRE_UPDATE_PREFIX = "pre_update_"
PRE_MIGRATION_PREFIX = "pre_migration_"; PRE_RESTORE_PREFIX = "pre_restore_"
# PROTECTED_BACKUP_PREFIXES rebuilt from these four (same values, same order)

def quick_check(db_path: PathLike) -> str:
    """First row of PRAGMA quick_check ('ok' when healthy). Never creates the file; FileNotFoundError if missing."""
```

### A.2 `database/migration_runner.py` (new)
```python
BASELINE_REVISION = "e1f2a3b4c5d6"

class DbState(str, Enum):
    FRESH = "fresh"            # no user tables (sqlite_% ignored)
    UNSTAMPED = "unstamped"    # user tables, alembic_version missing or empty
    AT_HEAD = "at_head"        # exactly 1 row == head
    BEHIND = "behind"          # exactly 1 row, known to the script dir, != head
    UNKNOWN = "unknown"        # >1 row, or revision not in the bundled script dir (R10)

@dataclass(frozen=True)
class DbStateReport:
    state: DbState
    current_revision: Optional[str]
    head_revision: str

@dataclass(frozen=True)
class MigrationResult:
    state: DbState
    action: Literal["none", "upgraded", "stamped", "refused"]
    from_revision: Optional[str]
    to_revision: Optional[str]
    backup_file: Optional[str]      # pre_migration_* file name, if taken

def alembic_script_location() -> Path
    # frozen: Path(sys._MEIPASS) / "alembic"   (NOT app_base_dir(): the scripts are bundled data)
    # source: REPO_ROOT / "alembic"
def build_alembic_config(connection: Optional[Connection] = None) -> Config
    # Config() with no ini file; set_main_option("script_location", str(alembic_script_location()));
    # cfg.attributes["connection"] = connection; cfg.attributes["configure_logger"] = False
def get_head_revision() -> str            # RuntimeError if the script dir has != 1 head
def inspect_db_state(engine: Engine) -> DbStateReport     # read-only; raises on a corrupt DB
def take_pre_migration_backup(db_path: Path, backups_dir: Path, report: DbStateReport) -> BackupResult
    # name: f"pre_migration_{report.current_revision or 'unstamped'}_to_{report.head_revision}_{%Y%m%d_%H%M%S}.db"
    # (+ _N suffix on collision); uses sqlite_online_backup (verified, sha256); raises on any failure
def upgrade_to_head(engine: Engine) -> str   # with engine.begin() as conn: command.upgrade(build_alembic_config(conn), "head")
def stamp_head(engine: Engine) -> str        # same, command.stamp(..., "head")
```
- `inspect_db_state` uses `ScriptDirectory.from_config(cfg).get_revision(rev)`. Any exception while resolving the revision means `UNKNOWN`.
- Non-SQLite engines: `inspect_db_state` is still used, but the backup is skipped and logged (backups are SQLite-only). Today's behaviour is otherwise unchanged.
- Use `transaction_per_migration=True` in env.py so `alembic_version` advances one revision at a time.

### A.3 Startup order in `database/schema_upgrade_service.py` (`execute_safe_startup_upgrade`)
```
0. report = inspect_db_state(engine)              exception -> _fail("preflight ...")
   UNKNOWN -> _fail("R10: database revision <rev> is unknown to this version") and RETURN before any write
             (no snapshot, no create_all, no master data, no email rotation, no last-seen write)
1. auto_pre_upgrade snapshot (existing, version-change only; unchanged)
2. state in {UNSTAMPED, BEHIND} and DB has data -> take_pre_migration_backup   failure -> _fail, RETURN
3. BEHIND -> upgrade_to_head                                                   failure -> _fail, RETURN (no restore, R8)
4. create_all + additive ALTER (existing)
5. state in {FRESH, UNSTAMPED} -> stamp_head    failure -> _fail, RETURN
6. master data, email rotation, last-seen version (existing)
```
- `result["migration"] = asdict(MigrationResult)`. `_fail` stays the only place that enters maintenance mode.
- Why an unstamped DB gets `stamp head` after create_all rather than `stamp baseline` + upgrade: create_all makes the schema equal the current models. The rule from now on is **models == head schema**, enforced in review and by the linter. Head == baseline in the bootstrap release, so the laptop's one-time stamp is exactly the baseline. Post-baseline revisions must be written defensively (check a column exists before adding it) and use `batch_alter_table`.
- Rollback is always "restore backup". `downgrade()` is never called by code.

### A.4 `alembic/env.py`
- Run `fileConfig` only if `config.config_file_name` is set **and** `config.attributes.get("configure_logger", True)`.
- URL: `config.attributes.get("url") or database.database.DATABASE_URL`, which honours `DATABASE_PATH`. `alembic.ini`'s `sqlalchemy.url` is never read; add a comment in env.py saying so. `alembic.ini` itself is unchanged.
- Online mode: if `config.attributes.get("connection")` is present, configure with it. Otherwise create `create_engine(url, poolclass=NullPool)`.
- Keep `render_as_batch=True`. Add `transaction_per_migration=True`.

### A.5 `alembic/versions/e1f2a3b4c5d6_update_system_baseline.py` (new)
`revision="e1f2a3b4c5d6"`, `down_revision="d3e4f5a6b7c8"`, `upgrade()`/`downgrade()` = `pass`, docstring "stamp target for legacy unstamped DBs (update-system plan §5)". It must pass `utils/migration_linter.py`.

### A.6 `build_backend_exe.py`
- Refactor to `build_pyinstaller_command() -> List[str]` so it can be tested. `build_backend()` calls it.
- Add:
  - `--add-data f"{ROOT_DIR/'alembic'}{os.pathsep}alembic"`
  - `--collect-submodules alembic`
  - `--collect-submodules mako` (alembic imports mako at load)
  - hidden import `database.migration_runner`
- Keep the "code only" rule: no `*.db`, `.env` or `alembic.ini` data. The `alembic/__pycache__` folder being copied is harmless.

### A.7 Phase 2 tests (Dev A)
`tests/unit/test_migration_runner.py` (temp DBs, `DATABASE_PATH` from conftest, never the repo DB):
1. Fresh DB: state FRESH. After startup, `alembic_version == head`, and no `pre_migration_*` file.
2. Legacy unstamped DB with rows (create tables from metadata minus `alembic_version`, insert rows):
   - a `pre_migration_unstamped_to_<head>_*.db` exists, `integrity_check == ok`, with the same row counts
   - after startup, stamped at head, and the rows are intact
3. Stamped at head: action `none`. A spy on `upgrade_to_head` isn't called, and no pre_migration backup is taken.
4. Stamped at `d3e4f5a6b7c8`: BEHIND. Backup is taken, then upgrade to `e1f2a3b4c5d6`. `sqlite_master.sql` is identical before and after, excluding `alembic_version`.
5. **R10:** `alembic_version = 'ffffffffffff'`:
   - maintenance mode is on
   - the DB file's sha256 is unchanged byte for byte
   - no backups dir is created
   - master data isn't synced (spy)
   - `POST` on a write route returns 503 (reuse the `test_main_app_returns_503_for_writes_in_maintenance` pattern)
6. Two rows in `alembic_version`: UNKNOWN, maintenance mode.
7. `sqlite_online_backup` raises during the pre_migration backup: maintenance mode, and `alembic_version` is not created.
8. `upgrade_to_head` raises: maintenance mode, the backup file is present, and the DB is not replaced (no auto restore).
9. Second startup after (2): AT_HEAD, no new pre_migration file.
10. With `sys.frozen`/`sys._MEIPASS` monkeypatched, `alembic_script_location() == MEIPASS/alembic`.
11. Script dir has exactly one head, `== BASELINE_REVISION`. The baseline's `down_revision == "d3e4f5a6b7c8"`. `migration_linter` passes on `alembic/versions/`.
12. env.py honours `DATABASE_PATH`: subprocess `python -m alembic -c alembic.ini stamp head` with env `DATABASE_PATH=<tmp>`. The tmp DB is stamped, and the repo DB's mtime is unchanged.
13. `is_protected_backup("pre_migration_x.db")` is true, and `_prune_snapshots` never deletes it.

Plus:
- `tests/unit/test_build_backend_exe.py`: the command contains the add-data/collect/hidden-import items from A.6, and no `--add-data` with a `.db`, `.env` or `.ini` source.
- Existing `test_db_safety_startup.py` and `test_schema_upgrade_service.py` stay green. Update any assertion on the exact failure reason for a corrupt DB, which now fails in preflight.

---

## B) Phase 5: apply / stage-local / rollback / last-result / post-update check (Dev B)

### B.1 Files and layout (all under the existing update data dir)
```
updates/
  staging/<file>.exe (+ .part)            existing
  staging/staged_manifest.json            NEW: raw signed envelope that verified the staged installer
  installers/<file>.exe                   NEW: verified installers kept for rollback (newest 3 by version)
  logs/install_<version>.log, rollback_<version>.log   NEW (mkdir before launch: Inno doesn't create dirs)
  pending_update.json                     NEW marker (atomic write)
  last_result.json                        NEW (atomic write)
  last_manifest.json, highest_seen.json, update_history.jsonl   existing
```
`pending_update.json` / `last_result.json` schema:
```json
{"schema":1, "kind":"update|rollback", "from_version":"2.1.0", "to_version":"2.1.1",
 "app_dir":"C:\\...\\Sorour Logistics", "db_path":"C:\\...\\sorour_logistics.db",
 "backup_file":"pre_update_v2.1.0_to_v2.1.1_20261001_101500.db", "backup_sha256":"<64hex>",
 "backup_created_at":"2026-10-01T08:15:00+00:00", "installer_file":"Sorour_Logistics_Setup_v2.1.1.exe",
 "installer_sha256":"<64hex>", "install_log":"...\\logs\\install_2.1.1.log", "manifest_raw":"<envelope str>",
 "aside_file":null, "started_at":"...", "actor":"admin",
 // last_result.json only:
 "result":"success|failed", "code":null|"installer_not_completed|migration_failed|db_check_failed|unexpected_version|client_version_mismatch",
 "detail":null|"<Arabic>", "finished_at":"...", "client_checked":false}
```
For `kind=rollback`:
- `from_version` is the failed version and `to_version` is the previous one
- `backup_file` is the backup that was restored
- `aside_file` is `pre_restore_failed_v<from>_<ts>.db`
- `manifest_raw` is copied from the update being rolled back

### B.2 State machine (in-memory, one `RLock`; the states are the existing `UpdateState` literal)
```
idle|failed --download--> downloading -> verifying -> ready | failed        (Phase 3, + previous pre-fetch B.6)
idle|failed|ready --stage-local--> verifying -> ready          errors: back to prior state, staging cleared
ready --apply--> verifying(re-hash) -> backing_up -> installing   errors: failed(error_code) ; process then killed by Setup
idle|failed|ready --rollback--> backing_up -> installing          errors: failed(error_code)
BUSY = {downloading, verifying, backing_up, installing}: apply/stage-local/rollback -> 409
```
- **Recovery after restart:** `_recover_staged_state()`, called lazily at the start of `get_status/apply`.
  - Condition: state is `idle`, `staged_manifest.json` re-verifies, its version is newer than installed, and `staging/<file>` exists with `size == size_bytes`.
  - Result: state becomes `ready` with that version. The hash is checked at apply time.

### B.3 `POST /apply` (`system.update`), `UpdateService.apply(version: str, actor: str, db: Optional[Session]) -> ApplyResponse`
All steps run synchronously, in this order (K1):
1. `ensure_apply_supported`, which fails with 400 `DETAIL_DEV_MODE`. Then `_recover_staged_state()`.
2. Under the lock:
   - state busy → 409 `DETAIL_UPDATE_BUSY`
   - state not `ready`, or `self._version != version` → 409 `"التحديث غير جاهز للتثبيت"`
3. `manifest = verifier.verify(repo.load_staged_manifest())`. Mismatch or failure → state `failed`, 409 "not ready". Also require `manifest.version == version` and `is_newer(version, installed)`.
4. State `verifying`. **Re-hash #1:** size and sha256 of `staging/<file>` against the manifest. Mismatch → delete the file, state `failed` with `hash_mismatch`, history `hash_mismatch`, 422 `DETAIL_HASH_MISMATCH`.
5. State `backing_up`. `enter_maintenance_mode("update: pre-update backup and install")`. **R5 gate:**
   - Disk space: `shutil.disk_usage(backups_dir).free >= 2 * db_size + 50 MB`
   - `res = sqlite_online_backup(DB_PATH, backups_dir / pre_update_backup_name(installed, version, now))`. The name is `pre_update_v{from}_to_v{to}_{%Y%m%d_%H%M%S}.db` (+ `_N` on collision). The helper already runs `integrity_check` and deletes a bad copy.
   - Sidecar `<name>.json` {sha256, size_bytes, integrity, created_at, from_version, to_version}.
   - **Any exception, including low disk space:**
     - `clear_maintenance_mode()`
     - state `failed` with `backup_failed`
     - history `backup_failed` (detail = exception class)
     - **no marker, launcher not called**
     - return 500 `"فشل النسخ الاحتياطي، تم إلغاء التحديث"`
   - On success: history `backup_ok` with `detail = <backup file name only>`. Flutter's `RollbackCandidate` depends on this.
6. `installer = repo.promote_installer(file)`: `os.replace` from staging to `installers/`, then `prune_installers(keep=3)`. Only files matching `^Sorour_Logistics_Setup_v\d+\.\d+\.\d+\.exe$` are considered for pruning.
7. Write the marker (`kind=update`, all fields from B.1, `manifest_raw = staged manifest`). Audit `UPDATE_APPLY` via `self._audit(db, …)`.
8. **Re-hash #2** of `installers/<file>` just before launch. This is the TOCTOU guard that covers the backup window. Mismatch → delete the file, delete the marker, clear maintenance, state `failed`, 422 `DETAIL_HASH_MISMATCH`. The backup is kept.
9. `cmd = build_installer_command(installer, app_base_dir(), repo.install_log_path("install", version))`, then `pid = self._launcher(cmd, installer.parent)`.
   - Exception → delete the marker, `clear_maintenance_mode()`, state `failed` with `launch_failed`, history `launch_failed`, 500 `"تعذّر تشغيل برنامج التثبيت، تم إلغاء التحديث ولم يتغير أي شيء"`.
10. State `installing`, history `install_launched` (detail `pid=<n>`). Return **202** `{"state":"installing","backup_file":"<name>","backup_created_at":"<iso>"}`. Maintenance mode stays on until Setup kills the process.

**Exact installer command** (`validators.build_installer_command(installer: Path, app_dir: Path, log_path: Path) -> str`). It is a single string, and every path is quoted the way Inno's docs show:
```
"<installer>" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RELAUNCH=1 /DIR="<app_dir>" /LOG="<log_path>"
```
- `/DIR` pins the install to the folder the running `backend.exe`/DB live in. The install path has a space: `...\Programs\Sorour Logistics`.
- Raise `ValueError` if any path contains `"`.

**Default launcher** (`service.launch_installer_detached(command: str, cwd: Path) -> int`):
- `subprocess.Popen(command, cwd=cwd, stdin/stdout/stderr=DEVNULL, close_fds=True, creationflags=DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_BREAKAWAY_FROM_JOB)`
- On `OSError` with winerror 5 (breakaway not allowed), retry once without `CREATE_BREAKAWAY_FROM_JOB`.
- Returns the pid.
- Injected as `UpdateService(launcher=...)`. Tests use `FakeLauncher`, which records `(command, cwd)`, returns 4242, and can be set to raise.

**`.iss` change (Dev B):** in `StopRunningApp`, use `'/F /IM frontend.exe'` and `'/F /IM backend.exe'` with **no `/T`**. Add a comment explaining K2.

### B.4 Post-update health check
`UpdateService.evaluate_pending_update() -> Optional[dict]` runs once per process. It is called from `get_update_service()` right after the singleton is created, and from `get_last_result()` as a safety net.
- Do nothing if `not apply_supported`, if there is no marker, or if the marker's `app_dir`/`db_path` differ from the current ones. In that last case, log a warning and keep the marker (K4).
- Classification is a pure function in validators: `classify_post_update(marker, installed_version, maintenance: bool, maintenance_reason: str, quick: str) -> (result, code, detail)`. First match wins:

| Condition | result / code | `detail` (Arabic, shown in the SnackBar) |
|---|---|---|
| `installed == marker.from_version` | failed / `installer_not_completed` | `"لم يكتمل تثبيت الإصدار {to}، والبرنامج ما زال على الإصدار {from}. بياناتك لم تتغير. سجل التثبيت: {install_log}"` |
| `installed != marker.to_version` | failed / `unexpected_version` | `"الإصدار المثبت {installed} غير المتوقع ({to})."` |
| `is_maintenance_mode()` | failed / `migration_failed` | `"تم تثبيت الإصدار {to} لكن ترقية قاعدة البيانات فشلت والنظام في وضع القراءة فقط. يمكنك التراجع للإصدار السابق."` |
| `quick_check(DB_PATH) != "ok"` (or it raises) | failed / `db_check_failed` | `"فحص سلامة قاعدة البيانات بعد التحديث فشل. يمكنك التراجع للإصدار السابق."` |
| otherwise | success / null | null |

- Write `last_result.json` = marker + {result, code, detail, finished_at, client_checked:false}, **then** delete the marker. History: `post_update_ok`/`post_update_failed` (or `rollback_ok`/`rollback_failed` when `kind=rollback`).

**`GET /last-result`**: `get_last_result(client_version: Optional[str]) -> LastResultResponse`. The router reads `Header(None, alias="X-Client-Version")`.
- No `last_result.json`: `{"result":"none"}`.
- If `result == success`, `kind == update`, `not client_checked`, and `client_version` is present: set `client_checked=true`. If `client_version != to_version`, the result becomes failed with `client_version_mismatch` and detail `"واجهة البرنامج لم تتحدث (الإصدار {client}) بينما الخادم على الإصدار {to}."`. Persist it.
- Response (additive to §6; the existing Flutter already parses these fields):
  `{result, from_version, to_version, finished_at, detail, kind, backup_file, backup_created_at}`.

### B.5 `POST /rollback` (`system.update`): `rollback(backup_file: str, confirm: bool, actor: str, db: Optional[Session]) -> RollbackResponse`
The service does these checks in order. **Nothing is changed until check 8 passes:**
1. `ensure_apply_supported` → 400 dev-mode. `confirm is not True` → 400 `"يجب تأكيد التراجع أولاً"`.
2. State busy → 409 `"توجد عملية تحديث جارية حالياً"`. Run `evaluate_pending_update()`.
3. `last = repo.load_last_result()`. It must have `kind == "update"`, and `manifest_raw` must re-verify its **signature**. Expiry and `highest_seen` are deliberately ignored here: the manifest is old by design.
   - No such result → 409 `"لا توجد نسخة سابقة متاحة للتراجع"`.
4. `installed == last.from_version` → 409 `"البرنامج ما زال على الإصدار السابق، لا حاجة للتراجع"`.
5. `manifest.previous` must be present with `previous.version == last.from_version`, else 409 "لا توجد نسخة سابقة متاحة للتراجع".
6. `validate_backup_filename(backup_file)`:
   - regex `^pre_update_v\d+\.\d+\.\d+_to_v\d+\.\d+\.\d+_\d{8}_\d{6}(?:_\d+)?\.db$`, no separators
   - it must equal `last.backup_file`
   - otherwise 409 `"النسخة الاحتياطية المطلوبة لا تخص آخر تحديث"`
   - Path = `backups_dir_for(DB_PATH) / backup_file`. Check that its resolved parent equals the backups dir.
7. The backup file exists, its `sha256 == last.backup_sha256`, and `check_integrity == "ok"`. Otherwise 422 `"النسخة الاحتياطية تالفة"`.
8. `installers/<previous.filename>` exists with the same size and sha256 as `previous.installer`. Otherwise 409 `"ملف تثبيت الإصدار السابق غير متوفر على الجهاز. استخدم خطة التراجع اليدوية"`. No download happens in this request (K1).

Changes, only after all eight checks pass:

9. State `backing_up`. `enter_maintenance_mode("rollback in progress")`. `engine.dispose()` (injected `dispose_engine`).
10. **Copy aside:** `sqlite_online_backup(DB_PATH, backups/pre_restore_failed_v{installed}_{ts}.db)`. The `pre_restore_` prefix makes it protected (R9).
    - Failure → clear maintenance, state `failed`, 500 `"تعذّر حفظ نسخة من قاعدة البيانات الحالية، تم إلغاء التراجع"`.
11. **Restore:** `sqlite_online_backup(backup, DB_PATH, overwrite=True)`, then `check_integrity(DB_PATH) == "ok"`. This is the same primitive `scripts/restore_database.py` uses.
    - Failure → **maintenance stays on**, state `failed` with `restore_failed`, 500 `"فشل استرجاع قاعدة البيانات. النظام في وضع القراءة فقط، تواصل مع الدعم الفني"`.
12. Marker `kind=rollback`:
    - `from=installed`, `to=previous.version`
    - `backup_file`, `aside_file`, `manifest_raw` (copied from `last`)
    - `install_log = logs/rollback_<prev>.log`
13. History `rollback_restored` (detail = backup_file). Audit `UPDATE_ROLLBACK` through a fresh `SessionLocal()`, so the entry is written into the restored DB.
14. Re-hash the previous installer, then launch it with `build_installer_command(prev_installer, app_dir, rollback log)`.
    - Failure → delete the marker. **Maintenance stays on:** the new binary must not write to the restored older DB. State `failed`, 500 `"تم استرجاع قاعدة البيانات لكن تعذّر تشغيل برنامج التثبيت السابق. شغّله يدوياً من: {path}"`.
15. State `installing`, history `rollback_launched`. Return **202** `{"state":"installing","restored_from":"<backup_file>","aside_file":"<name>"}`.

### B.6 Pre-fetching the previous installer (Phase 3 download worker change)
After the main installer verifies (state still `verifying`):
- **Condition:** `manifest.previous` exists, `previous.version == installed`, and `installers/<previous.filename>` is missing or has the wrong hash.
- **Download:** stream `previous.installer` into `installers/<file>.part`, with the same size cap and sha256 check, then `os.replace`. Add its size to `total_bytes` at job start.
- **On failure:** delete the part file, history `previous_download_failed`, **state still becomes `ready`**. The update is not blocked; rollback will return 409 plus the manual path (Decision 3).
- **On success:** history `previous_downloaded`.
- **On ready:** `repo.save_staged_manifest(manifest.raw)`.
- `clear_staging()` never touches `installers/`.

### B.7 `POST /stage-local` (`system.update`): `stage_local(manifest_path, installer_path, actor, db) -> UpdateStatusResponse`
1. Dev-mode 400. Busy 409 `DETAIL_UPDATE_BUSY`.
2. `validators.validate_local_file(path, suffix, max_bytes) -> Path`:
   - absolute, exists, regular file (not a dir or symlink) → else 400 `"الملف غير موجود"`
   - suffix `.json` / `.exe`, case-insensitive → else 400 `"نوع الملف غير مدعوم"`
   - manifest ≤ 64 KB, installer ≤ 1 GB → else 400 `"حجم الملف أكبر من المسموح"`
   - Schema fields get `max_length=1024`.
3. `manifest = verifier.verify(bytes)` → `ManifestError` → 422 `"توقيع ملف الإصدار غير صالح"`. Expiry and `highest_seen` are **not** enforced (Decision 1). `not is_newer(manifest.version, installed)` → 409 `"الإصدار ليس أحدث من المثبت"`.
4. `clear_staging()`, then stream the source to `staging/<manifest.installer.filename>.part` **while hashing the bytes being written**, so the copy is what gets verified. If the size or sha differ from the manifest: delete the part file, 422 `"بصمة ملف التثبيت غير مطابقة"`. Otherwise `os.replace` to the final name.
5. `save_staged_manifest(raw)`, `_remember_manifest(manifest, now)`, `save_highest_seen`. State `ready`, version, downloaded = total = size. History `staged_local` (detail = filename). Audit `UPDATE_STAGE_LOCAL`. Return 200 status.

### B.8 Schema, router and validator deltas (Dev B)
- **schemas.py:**
  - `ApplyResponse{state: Literal["installing"], backup_file: str, backup_created_at: datetime}`
  - `RollbackResponse{state: Literal["installing"], restored_from: str, aside_file: str}`
  - `LastResultResponse` + `kind: Optional[Literal["update","rollback"]]`, `backup_file: Optional[str]`, `backup_created_at: Optional[datetime]`
  - `StageLocalRequest` fields: `max_length=1024`
- **router.py:**
  - apply, stage-local and rollback get `db: Session = Depends(get_db)`
  - rollback passes `payload.confirm`
  - apply/rollback use `response_model=ApplyResponse/RollbackResponse`
  - last-result reads `X-Client-Version`
- **validators.py:**
  - all new `DETAIL_*` constants above; delete `DETAIL_NOT_IMPLEMENTED`
  - `pre_update_backup_name`, `validate_backup_filename`, `validate_local_file`, `build_installer_command`, `classify_post_update`, `INSTALLER_FILE_RE`
- **repository.py:**
  - `save/load/clear_pending`, `save/load_last_result`, `save/load_staged_manifest`
  - `installers_dir`, `promote_installer`, `installer_path`, `prune_installers(keep=3)`, `install_log_path(kind, version)`
  - all writes go through `_atomic_write_text`
- **`UpdateService.__init__` new injectables** (defaults in brackets):
  - `db_path` (`Path(DB_PATH)`)
  - `backups_dir` (`backups_dir_for(db_path)`)
  - `app_dir_provider` (`app_base_dir`)
  - `launcher` (`launch_installer_detached`)
  - `dispose_engine` (`engine.dispose`)
  - `disk_free` (`lambda p: shutil.disk_usage(p).free`)
  - `session_factory` (`SessionLocal`)

### B.9 Phase 5 tests (Dev B)
All tests use temp DBs and temp data dirs, `FakeLauncher`, `httpx.MockTransport`, and a test Ed25519 key. They clear maintenance mode in teardown.

- **`tests/unit/test_app_update_backup_gate.py` (R5):**
  - `sqlite_online_backup` raises → 500 detail, launcher not called, no marker, maintenance cleared, state `failed/backup_failed`, history `backup_failed`
  - `BackupVerificationError` → same outcome
  - low disk space → same outcome
- **`test_app_update_apply.py`:**
  - happy path:
    - the exact command string with `/DIR="…Sorour Logistics"`
    - `cwd` is `installers/`
    - marker fields
    - backup `pre_update_v2.0.3_to_v2.1.0_*.db` has integrity ok and its sidecar sha matches
    - history order `backup_ok` (detail = the file name only) then `install_launched`
    - audit row
    - 202 body
  - re-hash #1 mismatch → 422, file deleted, no backup
  - re-hash #2 mismatch (FakeLauncher swaps bytes in a backup hook) → 422, marker removed
  - not ready → 409
  - version mismatch → 409
  - busy → 409
  - dev-mode → 400, launcher not called
  - launcher raises → 500, marker removed, maintenance cleared, backup kept
  - recovery: a new service instance with a staged file and `staged_manifest.json` becomes `ready` and applies
  - installers pruning keeps 3 and never touches non-matching files
  - `build_installer_command` rejects a path containing `"`
- **`test_app_update_post_update.py`:**
  - each row of the B.4 table
  - marker with a different `db_path` is ignored and kept
  - `apply_supported=False` ignores the marker
  - the marker is deleted only after `last_result.json` is written
  - client mismatch flips to failed exactly once (`client_checked`)
  - `last-result` returns `backup_file`/`backup_created_at`/`kind`
  - no files → `none`
- **`test_app_update_rollback.py`:**
  - happy path:
    - rows inserted after the backup are gone from the live DB
    - `pre_restore_failed_v2.1.0_*.db` contains them and is protected
    - `kind=rollback` marker
    - launcher called with the previous installer
    - 202 body
    - maintenance on
  - error cases: `confirm=false` 400; name traversal `..\\x.db` 409; name ≠ last 409; sha mismatch 422; integrity fail 422; previous installer missing 409 and the **DB sha is unchanged**; no `previous` 409; already on the previous version 409; tampered `manifest_raw` 409; an expired manifest is still accepted
  - aside fails → 500, DB unchanged, maintenance cleared
  - restore fails → 500, maintenance stays on
  - launch fails → 500 with the path, maintenance stays on
  - post-rollback evaluation gives `rollback` success
- **`test_app_update_stage_local.py`:**
  - happy path → ready, then apply works
  - bad signature 422; hash mismatch 422; size mismatch 422
  - not newer 409; missing 400; wrong suffix 400; too large 400 (patch the cap)
  - dev-mode 400; busy 409
  - the hash is computed over the written copy
  - an expired manifest is accepted (Decision 1)
- **`test_app_update_download_previous.py`:**
  - pre-fetch when missing; skip when present
  - skip when `previous.version != installed`
  - failure is non-blocking (`ready` + history `previous_download_failed`, Decision 3)
  - `clear_staging` keeps `installers/`
- **`test_app_update_router.py`:**
  - delete `test_later_phase_routes_are_501_for_admin`
  - apply/rollback return 202 with a stubbed service
  - `X-Client-Version` is forwarded
  - 403s for OPERATOR stay
  - update the `/rollback` sample body to a valid name
- **`test_installer_safety.py`:** `StopRunningApp` contains no `/T`.

---

## C) Clean-VM rehearsal (Windows Sandbox) and real-DB copy

**C.0 Get a copy of the real laptop DB. This is read-only on the laptop.**
1. On the laptop:
   - close the app, then check in Task Manager that neither `frontend.exe` nor `backend.exe` is running
   - `set DATABASE_PATH` and `reg query HKCU\Environment /v DATABASE_PATH`: record whether an override exists
   - `where /r C:\Users\Hp sorour_logistics.db`: list every DB with its size and modified time. This finds the second DB left by the source run.
2. Copy `sorour_logistics.db` together with `-wal`/`-shm` from `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\`, **and each other DB found**, to an encrypted USB. The app must be closed while copying. Never copy into the repo.
3. On the dev box: open a copy and run `PRAGMA integrity_check`. Record the row counts of the key tables (users, import_files, suppliers, purchase_orders), which is baseline evidence. Decide with the CTO which DB is the real one. The installer only ever uses `{app}\`, and `DATABASE_PATH` must be unset unless that is intended.

**C.1 Sandbox setup:** enable the "Windows Sandbox" feature. Create a `.wsb` with:
- a `MappedFolder` (ReadOnly=true) → `C:\Rehearsal` holding the old 2.0.3 installer, vN (the first updater-capable build), vN+1 (a throwaway build with one harmless additive post-baseline revision, never merged), vN+1-broken (a revision that raises), their signed `manifest.json` files, and the DB copy
- `Networking=Enable` only for the online pass

The per-user install path in the sandbox is `C:\Users\WDAGUtilityAccount\AppData\Local\Programs\Sorour Logistics\`.

**C.2 Checklist.** Every step records pass or fail, with the relevant log line or file as evidence.
1. Install **2.0.3** (the old installer). Close the app. Replace `{app}\sorour_logistics.db` with the **copy** of the real DB (delete any `-wal`/`-shm`). Launch, log in, and confirm the real data is visible. This reproduces the laptop.
2. Record the DB sha256 and row counts. Install **vN manually** (interactive). Check:
   - `backups\pre_install_2.0.3_*\` has the DB, and its size matches
   - `backups\pre_migration_unstamped_to_e1f2a3b4c5d6_*.db` exists
   - `alembic_version = e1f2a3b4c5d6`
   - row counts are unchanged
   - `backend_server.log` has no CRITICAL line; `/health` shows `maintenance_mode:false`
3. Create new data in vN: one import file and one supplier.
4. Update **vN → vN+1** from the app, using "update from file" with the mapped folder (and, in the online pass, the staging base URL). Check:
   - `backups\pre_update_vN_to_vN+1_*.db` + `.json`
   - `updates\installers\` holds the vN installer (pre-fetched when online)
   - Setup survives the backend exiting (the `/T` fix) and the app **relaunches by itself**
   - `updates\logs\install_<ver>.log` exists
   - the "updated to vN+1" SnackBar appears once
   - the data from step 3 is present and `alembic_version` = the vN+1 head
5. Failure path: install **vN → vN+1-broken**. Expect the failure SnackBar and a 503 on writes (maintenance mode). **Roll back** from the dialog. Check:
   - `pre_restore_failed_v*` exists
   - the app relaunches as vN
   - the data equals the state from step 3
   - `last-result` shows a rollback success
   - `/check` offers vN+1-broken again (Decision 2)
6. R10: open a vN+1-stamped DB copy with the vN binary (copy it over, then start). Expect maintenance mode and the DB sha unchanged.
7. Offline: disable networking. The check shows offline, there is no banner, and the app still works.
8. Tampering: a manifest with one byte changed → 422 signature error. A different `.exe` → 422 hash error.
9. Uninstall, then check that `sorour_logistics.db`, `backups\` and `%LOCALAPPDATA%\SorourLogistics\updates\` are still there.
10. Note the time the pre-update backup takes on the real DB size. If it is over 30 s, raise it before bootstrap.

A Sandbox discards everything on close. Never map the USB read-write, and never copy the real DB out of the sandbox.

---

## 7. File ownership (no overlap)

| Dev A (Phase 2) | Dev B (Phase 5) |
|---|---|
| `utils/db_safety.py` (**first commit**, A.1) | `modules/app_update/{service,repository,validators,schemas,router}.py` |
| `database/migration_runner.py` (new) | `installer/importflow_setup.iss` (remove `/T` only) |
| `database/schema_upgrade_service.py` | `tests/unit/test_app_update_{backup_gate,apply,post_update,rollback,stage_local,download_previous}.py` (new) |
| `alembic/env.py`, `alembic/versions/e1f2a3b4c5d6_update_system_baseline.py` (new) | `tests/unit/test_app_update_router.py`, `tests/unit/test_app_update_service.py` (download-worker changes), `tests/unit/test_installer_safety.py` |
| `build_backend_exe.py` | |
| `tests/unit/test_migration_runner.py`, `test_build_backend_exe.py` (new); `test_db_safety_startup.py`, `test_schema_upgrade_service.py` | |

- **Order:** Dev A lands A.1 (constants + `quick_check`) first, about 15 minutes of work. After that, the two developers are independent.
- **Untouched:** `main.py`, `settings.py`, `version.json`, `package_production.py`.
- **flutter-developer:** no required change. Optionally, show a rollback-specific success text when `kind == "rollback"`.

## 8. Risks

- **Live DB:** the first vN start stamps the laptop DB. That is DDL for `alembic_version` only, done after both the verified `pre_install_` and `pre_migration_` backups. Rehearsed in C.2 step 2 on the real copy.
- **SQLite DDL is non-transactional under pysqlite**, so a failing revision can leave a half-applied change. The mitigations are maintenance mode, the pre_migration backup, and a manual rollback. Never an automatic restore.
- **An old dev DB stamped at a pre-baseline revision** would replay old migrations and probably fail into maintenance mode. That only affects dev boxes; the laptop DB is unstamped.
- **Running `python main.py` on the repo DB** stamps it the first time after Phase 2. This is expected, and a backup is taken first.
- **Two processes on one DB with different code** (via `DATABASE_PATH`): the older one enters maintenance mode (R10). Nothing is destroyed.
- **Performance:** two full-DB copies per update (auto snapshot + pre_update) plus one pre_migration copy when the schema changes. All are online-API copies. Measure in C.2 step 10.

## 9. Open questions

None remaining. Q1–Q3 (stage-local freshness, re-offer after rollback, previous-installer pre-fetch failure) are resolved in "Decisions (CTO-delegated, 2026-09-24)" at the top.
