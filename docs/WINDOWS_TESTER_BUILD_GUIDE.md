# 🧪 Windows Tester Build Guide — v2.4.0 (for the AI agent on the Windows machine)

> **الغرض:** بناء نسخة تجربة من Sorour Logistics ERP **v2.4.0 (Build 211)** على جهاز Windows، وتشغيلها على
> **نسخة فاضية من قاعدة البيانات** فيها البيانات الأساسية بس، من غير ما نلمس النسخة الحقيقية ولا نبعت أي تحديث للعملاء.
>
> **To the agent:** follow the steps in order. Stop and ask the user when a step fails or a check does not match.
> Do not improvise around a failed safety check.

---

## 0. 🛑 Safety rules (non-negotiable)

1. **Never modify the live database.** It is `sorour_logistics.db` in the installed app folder
   (`%LOCALAPPDATA%\Programs\Sorour Logistics\` for the per-user install) or in a dev checkout root.
   It is only ever used as the **read-only `--source`** of `create_tester_db.py`.
2. **Always run `package_production.py` with `--no-bump`.** Without it the script raises the version
   (2.4.0 → 2.4.1) and edits five tracked files.
3. **No git writes:** no commit, push, tag or PR from this machine. No `publish_update.yml`, no upload to the
   update host. This build is for local testing only.
4. **Do not run the installer** (`Sorour_Logistics_Setup_v2.4.0.exe`) on a machine that runs the real
   production app: it upgrades the real install. Use the **portable** folder (step 5).
5. The portable launcher frees port **28080** (it kills whatever listens there). **Close the production app
   first** and tell the user before starting the tester build.

---

## 1. Prerequisites (one-time)

| Tool | Version | Check |
|---|---|---|
| Git | any | `git --version` |
| Python | **3.12** (same as CI; not 3.13 / 3.14) | `py -3.12 --version` |
| Flutter | **3.44.6** (same as CI) | `flutter --version` |
| Visual Studio 2022 Build Tools | workload "Desktop development with C++" | `flutter doctor` → Visual Studio ✓ |
| Inno Setup | 6 | `"%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"` exists |

If something is missing, install it and re-run the check. Flutter must be on `PATH`.

---

## 2. Get the code (main = v2.4.0)

```powershell
git clone https://github.com/baraa-solutions/import_flow.git
cd import_flow
git checkout main
git pull
```

Verify the version **before** building:

```powershell
python -c "import json; v=json.load(open('version.json', encoding='utf-8')); print(v['version'], v['build_number'])"
```

Expected: `2.4.0 211`. If not, stop and ask.

---

## 3. Python and Flutter dependencies

```powershell
py -3.12 -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r requirements.txt "pydantic[email]" email-validator pyinstaller
cd frontend
flutter config --enable-windows-desktop
flutter pub get
cd ..
```

Quick backend sanity check (uses a throwaway database, never the live one):

```powershell
$env:DATABASE_PATH = "$env:TEMP\importflow_boot_check.db"
python -c "import main; print('boot ok')"
Remove-Item Env:DATABASE_PATH
```

Expected last line: `boot ok`.

---

## 4. Build (20–40 minutes)

```powershell
python package_production.py --no-bump --compile-all
```

Expected at the end: `[SUCCESS] Production release v2.4.0 (Build 211) created at: ...\dist`

Check the outputs:

- `dist\Sorour_Logistics_Standalone\` (contains `frontend.exe`, `backend.exe`, `Sorour_Logistics_App.bat`)
- `dist\releases\Sorour_Logistics_Setup_v2.4.0.exe`
- `dist\releases\Sorour_Logistics_v2.4.0_Windows_Portable.zip`

Then confirm `git status` shows **no modified tracked files** (`version.json`, `pubspec.yaml`, … must be
unchanged). If they changed, the build ran without `--no-bump`: stop and tell the user.

---

## 5. Tester folder + emptied database

### 5.1 Copy the portable build to its own folder

```powershell
$TesterDir = "C:\SorourTester_v2.4.0"
Copy-Item -Recurse dist\Sorour_Logistics_Standalone $TesterDir
```

### 5.2 Create the emptied tester database

The source is the real database (read only, the script uses the SQLite online backup and never writes to it).
The output is a **new** file inside the tester folder, named `sorour_logistics.db` so the tester
`backend.exe` uses it.

```powershell
python scripts\create_tester_db.py `
  --source "$env:LOCALAPPDATA\Programs\Sorour Logistics\sorour_logistics.db" `
  --out "$TesterDir\sorour_logistics.db"
```

Adjust `--source` if the real database lives elsewhere (ask the user). The script refuses an existing
`--out` file and refuses to write to a live application database.

**What the copy keeps** (rows are printed by the script):

| Kept | Tables |
|---|---|
| الشركات المستوردة | `import_companies` |
| دليل الموردين الأجانب | `suppliers` |
| الشركاء والبنوك ومقدمو الخدمات | `external_service_providers` |
| الموانئ والمنافذ الجمركية | `transport_locations`, `countries`, `cities` |
| الشروط التجارية الدولية | `incoterms`, `incoterm_responsibilities`, `cost_items` |
| العملات وأسعار الصرف | `currencies`, `exchange_rates` |
| Sign-in and system | `users`, `roles`, `permissions`, `role_permissions`, `user_permissions`, `alembic_version`, `system_parameters`, `tax_rates`, `step_configs`, `recalculation_dependency_map`, `budget_variance_settings` |
| Fixed lookups | `package_types`, `units_of_measure`, `container_specs`, `clearance_expense_types`, `expense_catalog` |

**Emptied:** everything else, including **projects / cost centres** and the **customs tariff**
(`customs_tariffs`, `fee_codes`, `preferential_agreements`), import files, POs, invoices, settlements,
notifications and logs.

> Note: on every start the app re-seeds a small built-in baseline (about 10 tariff lines, 4 fee codes,
> 4 agreements). So after the first launch the tariff explorer shows those ~10 lines, not zero. This is
> expected.

Expected script output ends with `Integrity check: ok` and `[SUCCESS] Tester database created`.
If it prints `[WARN] ... still reference emptied tables`, copy the warning lines into the report.

---

## 6. Run the tester build

1. Tell the user the production app will be closed, then close it (tray icon / window).
2. Start `C:\SorourTester_v2.4.0\Sorour_Logistics_App.bat`.
3. The window title must read **Sorour Logistics ERP (v2.4.0)**.
4. Sign in with an existing user (users were kept).

To go back to production: close the tester app, then start the production app as usual.

---

## 7. What to test (v2.4.0)

- **Stage notes and attachments:** add a note with an image, a PDF and a file with an **Arabic name**; download
  it (name must stay Arabic); delete your own note; a different non-admin user must **not** be able to delete it.
- **New operational tracks:** customs abandonment radar, port terminal storage, re-export / destruction,
  inspection appeals, broker custody settlement, container deposit ledger (open each, create one record).
- **New screens:** custody release, expense catalog, formal letters, smart document upload hub, system parameters.
- **Comprehensive dossier report:** open for a new import file, export.
- **Branding:** Sorour logo in the top bar, watermark on login and startup screens.
- **Master data screens:** companies, suppliers, partners, ports, Incoterms, currencies show the kept data;
  projects is empty.

---

## 8. Report back to the user

Send one short report with:

1. Toolchain versions (`py -3.12 --version`, `flutter --version` first line).
2. Build result: success / failure + the last 30 lines of output on failure.
3. Output files with sizes (`dist\releases\*`).
4. The `create_tester_db.py` summary (kept table counts, emptied count, integrity line, any `[WARN]`).
5. Test results per item in section 7: ✅ / ❌ + short description and a screenshot for each ❌.
6. Confirmation that `git status` is clean and nothing was pushed.
