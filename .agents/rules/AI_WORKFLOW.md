# 🧭 AI Workflow — how any AI agent works on ImportFlow ERP (Antigravity, Claude, Gemini, Copilot)

> اقرأ الملف ده قبل أي مهمة. القواعد التفصيلية في `CORE_RULES.md` و`DOMAIN_RULES.md` وskill `ui-screen-standards`.
> اللغة مع المستخدم: عربي مصري. الكود والـ DB والـ API والملفات: English فقط.

## 1. The loop (every task)

0. **Sync with main** (section 2) before anything else.
1. **Understand** — restate the goal in 1-2 lines. Find the business rule (BP-xxx / MD-xxx in `docs/phase_*.md`,
   `docs/01_master_data.md`). Classify: one file / one layer / cross-layer (backend + Flutter + schema).
2. **Read before writing** — open the module's 6 files (`modules/<m>/{model,schemas,repository,service,validators,router}.py`)
   and the Flutter feature (`frontend/lib/features/<f>/{models,providers,screens,widgets}`). Follow the existing pattern;
   reuse shared helpers (`modules/common/*`, `frontend/lib/core/widgets/*`) instead of writing new ones.
3. **Plan the contract first** for cross-layer work: method, path, request/response fields, permission code,
   error codes. Backend and Flutter must agree on field names (compare `schemas.py` with the Dart `fromJson/toJson`).
4. **Write the change** (rules in section 6) + **tests in the same change**.
5. **Run the tests for what you touched** (section 5), one file at a time.
6. **Self-review the diff** (section 7) before saying "done".
7. **Report** in Arabic: what changed (files), test results with real numbers, open questions.
   Append a short entry to `history/YYYY-MM-DD.md` (append-only, never overwrite).

Never: commit/push/tag unless the user asks (Git rules: section 2); bump versions or edit `version.json` (Track 1); run `package_production.py`;
edit `.env` or any `*.db`; run destructive SQL; `git reset --hard` / `git clean` / `git stash` (shared between worktrees).

## 2. Git: sync before every task, pull / push rules

Remotes: `company` = https://github.com/baraa-solutions/import_flow (source of truth, PRs and releases);
`origin` = legacy fork, do not push there.

**Before starting ANY task (mandatory):**
```cmd
git status                         :: must be clean, or ask the user what to do with local changes
git fetch company --prune
git switch main && git pull --ff-only company main
git switch -c <type>/<short-task-name>     :: e.g. fix/po-numeric-inputs, feat/settlement-export
```
If you continue an existing task branch instead: `git fetch company` then `git merge company/main` into it (or
`git rebase company/main` if the branch was never pushed) and resolve conflicts BEFORE writing new code. Run the
touched tests after merging.

**While working:** small commits per logical change, Conventional Commits in English
(`feat(scope): ...`, `fix(scope): ...`, `docs(scope): ...`, `test(scope): ...`, `chore(scope): ...`).
No AI attribution anywhere (no "Co-Authored-By", no "Generated with ..."). Never commit `.env`, `*.db`, build
outputs, scratch files (`.tmp_*`, `*.pkg*_files.txt`) or local agent folders.

**Push rules:**
- Commit / push only when the user asks. Push your own branch: `git push -u company <branch>`.
- Never push to `main` directly, never force-push (`--force` / `--force-with-lease`), never rewrite pushed history,
  never delete remote branches or tags.
- `main` changes only through a Pull Request on `company` (`gh pr create --base main`), merged after the checks pass.
- Before opening a PR: `git fetch company && git merge company/main` again, re-run the touched tests.
- Tags (`vX.Y.Z`) are created only during a formal release (Track 2, `docs/UPDATE_DISTRIBUTION_RUNBOOK.md`) on the
  merged `main` commit, after `/release-check` passes.
- Several sessions/agents may share a worktree: never `git stash`, `git reset --hard` or `git clean`; stage files
  by path (`git add <paths>`), not `git add -A`.

## 3. Run the project locally as a developer (Track 1)

**First-time setup**
```cmd
git clone https://github.com/baraa-solutions/import_flow.git
cd import_flow
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env            :: fill local values; never commit .env
cd frontend && flutter pub get && cd ..
```
Tooling: Python 3.12, Flutter 3.44.6 (pinned), Visual Studio with "Desktop development with C++" for
`flutter run -d windows`.

**Daily run (one click):** `Launch_Track1_Dev.bat` — backup + backend + Flutter with hot reload.

**Daily run (manual, two terminals):**
```cmd
:: terminal 1 - backend on http://127.0.0.1:28080 (auto-reload on save)
python scripts/daily_backup.py --test
python -m uvicorn main:app --host 127.0.0.1 --port 28080 --reload
```
```cmd
:: terminal 2 - Flutter desktop app
cd frontend
flutter run -d windows
```
Sign in with a local user (fresh DB: `admin` + initial password, forced change on first login).
After pulling new code: `pip install -r requirements.txt` and `flutter pub get` again; the backend applies
migrations on start.

## 4. Run on a scratch copy (experiments and manual testing)

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

## 5. Tests

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

## 6. How to write the code (focus here)

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

## 7. Self-review checklist before "done"

- [ ] Every new/changed route has a permission; the code exists in the catalog.
- [ ] No hard-coded rate/price/date/ID; no fabricated defaults; no secrets.
- [ ] Backend field names = Flutter `fromJson/toJson` keys; new error codes registered (backend + Flutter catalogs).
- [ ] Tests added for the change and for each bug fixed; touched test files run green (real numbers in the report).
- [ ] `python -c "import main"` works (scratch `DATABASE_PATH`); `flutter analyze` clean for touched folders.
- [ ] Only files the task needs were changed; no edits to `.env`, `*.db`, `version.json`.
- [ ] `history/YYYY-MM-DD.md` entry appended.
