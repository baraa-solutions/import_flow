# 🧭 AI Workflow — how any AI agent works on ImportFlow ERP (Antigravity, Claude, Gemini, Copilot)

> اقرأ الملف ده قبل أي مهمة. القواعد التفصيلية في `CORE_RULES.md` و`DOMAIN_RULES.md` وskill `ui-screen-standards`.
> اللغة مع المستخدم: عربي مصري. الكود والـ DB والـ API والملفات: English فقط.

## 1. The loop (every task)

1. **Understand** — restate the goal in 1-2 lines. Find the business rule (BP-xxx / MD-xxx in `docs/phase_*.md`,
   `docs/01_master_data.md`). Classify: one file / one layer / cross-layer (backend + Flutter + schema).
2. **Read before writing** — open the module's 6 files (`modules/<m>/{model,schemas,repository,service,validators,router}.py`)
   and the Flutter feature (`frontend/lib/features/<f>/{models,providers,screens,widgets}`). Follow the existing pattern;
   reuse shared helpers (`modules/common/*`, `frontend/lib/core/widgets/*`) instead of writing new ones.
3. **Plan the contract first** for cross-layer work: method, path, request/response fields, permission code,
   error codes. Backend and Flutter must agree on field names (compare `schemas.py` with the Dart `fromJson/toJson`).
4. **Write the change** (rules in section 4) + **tests in the same change**.
5. **Run the tests for what you touched** (section 3), one file at a time.
6. **Self-review the diff** (section 5) before saying "done".
7. **Report** in Arabic: what changed (files), test results with real numbers, open questions.
   Append a short entry to `history/YYYY-MM-DD.md` (append-only, never overwrite).

Never: commit/push/tag unless the user asks; bump versions or edit `version.json` (Track 1); run `package_production.py`;
edit `.env` or any `*.db`; run destructive SQL; `git reset --hard` / `git clean` / `git stash` (shared between worktrees).

## 2. Run the project locally (Track 1 — dev and manual testing)

Prerequisites: Python 3.12 (`pip install -r requirements.txt`), Flutter 3.44.6 (`cd frontend && flutter pub get`).

**Safe testing on a copy (recommended for any experiment):**
```cmd
copy sorour_logistics.db %TEMP%\dev_copy.db
set DATABASE_PATH=%TEMP%\dev_copy.db
python -m uvicorn main:app --host 127.0.0.1 --port 28080 --reload
```
```cmd
cd frontend
flutter run -d windows          :: or: flutter run -d chrome --web-port 3000
```
The app talks to `http://127.0.0.1:28080` (`frontend/lib/core/constants/api_constants.dart`).
Hot reload: `r`, hot restart: `R`, quit: `q`.

**On the real dev database** (only when the user wants it): back it up first —
`python scripts/daily_backup.py --test` — then `python main.py` (or `Launch_Track1_Dev.bat`).

Warnings:
- `import main` / starting the backend runs schema upgrades and writes snapshots for the DB that `DATABASE_PATH`
  points at → probes, scripts and tests always use a scratch copy.
- The Production Sync screen (`modules/production_sync`) ignores `DATABASE_PATH` and writes the real DBs: never click it
  while testing.
- Port 28080 busy → `taskkill /f /im backend.exe` (an installed copy may be running).
- Default admin on a fresh DB: `admin` / initial password, forced change on first login.

## 3. Tests

```cmd
:: backend — one file at a time, read counts from the XML (console summary is suppressed after import main)
set DATABASE_PATH=%TEMP%\test_copy.db
python -m pytest tests/unit/test_<module>.py -q -p no:cacheprovider --junitxml=%TEMP%\r.xml
:: frontend
cd frontend && flutter test test/<file>_test.dart -j 1
cd frontend && flutter analyze lib/features/<feature>
```
- Full suites (~4,970 backend tests ≈ 40 min; ~2,100 Flutter ≈ 16 min at `-j 2`) only before a release:
  `python scripts/release/run_release_tests.py`. Never run pytest and flutter test at the same time (memory).
- A test that pins old wrong behaviour (fabricated data, missing permission) is updated with a comment saying why;
  never weaken an assertion just to go green.

## 4. How to write the code (focus here)

**Backend**
- Router → Service → Repository. Router = HTTP + `Depends(require_permission("<module>.<action>"))` on EVERY route;
  the code must exist in `modules/auth/seed_rbac.py` (a test checks it). Business logic only in the service.
- Acting user = the logged-in user (`current_user.username`). Never trust `approved_by` / `reviewer_name` from the body.
- One commit per request for the main entity; side effects (tasks, notifications, lifecycle) after it via
  `errors.best_effort`. No `except Exception: pass`.
- Business errors → `HTTPException` 4xx with Arabic message (coded: `detail={code, message, ...}`, register the code in
  `modules/common/system_messages.py`). Never let a `ValueError` become a 500.
- Statuses are server-owned: validate transitions; a client cannot send `status="Approved"`.
- Money / customs: rates come from the tariff (HS code), currency tables or `system_parameters` — never hard-coded
  (no 48.5, 50, 14%, 0.02 in code). VAT base = CIF + import duty. Round only final money values.
- **No fabricated data**: if a rate, price, ACID, HS code, company, quantity or date is unknown, leave it null and
  require it. Never invent a default that looks real.
- Schema change → Alembic migration; new column on an existing table → `server_default` or backfill. Response schemas
  tolerate legacy rows (`modules/common/legacy_rows.py`): one old row must never 500 a list.
- Soft delete only; master data by FK; audit fields via helpers; Python 3.12 imports for every annotation name.

**Flutter**
- Colours only `AppTheme`; buttons `AppButton`; reference pickers `SearchableDropdownField<T>`; every string in the 3
  l10n files (`app_localizations.dart`, `_ar.dart`, `_en.dart`); RTL with `EdgeInsetsDirectional` / `AlignmentDirectional`.
- Every mutation → `ref.invalidate(...)`; screens load fresh data on open; backend errors shown as SnackBar
  (`ApiErrorText.of(e)` shows the coded message).
- Unknown values stay unknown: no `?? 50.0` rates, `?? 0.0` money shown as real, or `.first` auto-selected in a new form.
- Text inputs keep a stable `TextEditingController` (no Key/initialValue rebuild per keystroke). Decimal inputs accept
  decimals; display may round, stored values do not.
- Exports via `FileSaveHelper.exportAndSaveFile` with the name `[Stage] - [File Code].[ext]`.
- No money math the backend owns. Split screens > ~1,500 lines into `widgets/`.

## 5. Self-review checklist before "done"

- [ ] Every new/changed route has a permission; the code exists in the catalog.
- [ ] No hard-coded rate/price/date/ID; no fabricated defaults; no secrets.
- [ ] Backend field names = Flutter `fromJson/toJson` keys; new error codes registered (backend + Flutter catalogs).
- [ ] Tests added for the change and for each bug fixed; touched test files run green (real numbers in the report).
- [ ] `python -c "import main"` works (scratch `DATABASE_PATH`); `flutter analyze` clean for touched folders.
- [ ] Only files the task needs were changed; no edits to `.env`, `*.db`, `version.json`.
- [ ] `history/YYYY-MM-DD.md` entry appended.
