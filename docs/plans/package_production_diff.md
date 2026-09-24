# `package_production.py` changes for the CTO (Phase 0b, production DB safety)

> **ملخص:** الملف ده فيه الـ diff اللي لازم تطبّقه بإيدك على `package_production.py` (الـ agents ممنوعين يعدّلوه).
> Diff 1 إلزامي: يوقف نسخ قاعدة البيانات جوه الـ bundle (حتى مع `--preserve-data`) ويوقف شحن الـ 3 scripts المدمّرة.
> Diff 2 مُستحسن: يشغّل الـ bundle guard قبل بناء الـ installer والـ zip محلياً. من غير Diff 1، الـ CI هيفشل عند خطوة الـ bundle guard (ودا مقصود).

Spec: `docs/plans/update-system-plan.md` section 0 (audit A1, A3, A4; rules R1, R4).
Everything not shown below stays exactly as it is (launchers, desktop/web copies, zip, `latest_release.json`, `version.json` update, bumping).

## Why

| Audit | Today | After |
|-------|-------|-------|
| A3 | `copy_standalone_package()` copies the repo-root `sorour_logistics.db` into `dist/Sorour_Logistics_Standalone/` (with `--preserve-data`: the full real data; without it, a copy "cleaned" by `clean_and_isolate_databases`). It then ends up in the portable zip and, until Phase 0b, in the installer. | No DB is ever copied. `--preserve-data` / `--keep-operational-data` stop the run with an error instead of being silently ignored. The installed backend creates an empty DB on first run. |
| A4 | `reset_clean_production_db.py`, `clean_and_isolate_databases.py`, `sync_to_production.py` are copied next to the live DB in `{app}`. | Not shipped. `version_manager.py`, `version.json`, `incoterms_data.json` still are. |
| R4 | The installer and zip are built without any check. | (Diff 2) `scripts/release/bundle_guard.py` runs on the `.iss` and the staged folder first; on failure no installer and no zip are built and the run exits 1. |

The installer itself no longer ships a DB either way (`installer/importflow_setup.iss` has no DB `[Files]` line and excludes `*.db*`, `.env*`, keys and these scripts), so Diff 1 closes the portable-zip leak and makes the CI bundle guard pass.

## How to apply

Save each block below to a file and apply from the repo root (the patches are LF; git converts them on apply):

```bash
git apply --check package_production_diff1.patch && git apply package_production_diff1.patch
git apply --check package_production_diff2.patch && git apply package_production_diff2.patch   # optional, on top of diff 1
python scripts/release/bundle_guard.py --iss installer/importflow_setup.iss   # sanity
```

Both patches were checked with `git apply --check` against the current file (diff 2 on top of diff 1).
After applying, delete the stale `dist/Sorour_Logistics_Standalone/sorour_logistics.db` left by earlier packaging runs
(move it somewhere safe first if you are not sure it is only a build copy). `/release-check` reports it as a FAIL until then.

## Diff 1 (required): no database, no destructive scripts

```diff
--- a/package_production.py
+++ b/package_production.py
@@ -23,7 +23,6 @@
 DESKTOP_SRC = ROOT_DIR / "frontend" / "build" / "windows" / "x64" / "runner" / "Release"
 WEB_SRC = ROOT_DIR / "frontend" / "build" / "web"
 BACKEND_EXE = ROOT_DIR / "dist_backend" / "backend.exe"
-DB_SRC = ROOT_DIR / "sorour_logistics.db"
 APP_ICON_SRC = ROOT_DIR / "installer" / "app_icon.ico"
 
 import version_manager
@@ -103,24 +102,20 @@
     else:
         print(f"[WARN] backend.exe not found at {BACKEND_EXE}")
 
-    # 3. Copy Database to Standalone Destination
-    prod_db_file = STANDALONE_DEST / "sorour_logistics.db"
-    if DB_SRC.exists():
-        safe_copy_file(DB_SRC, prod_db_file)
-        if "--keep-operational-data" in sys.argv or "--preserve-data" in sys.argv:
-            print(f"      Included FULL real operational sorour_logistics.db into {STANDALONE_DEST} (Preserved real operational data)")
-        else:
-            # Only clean operational demo data from the standalone release copy, NEVER the dev source database
-            import clean_and_isolate_databases
-            clean_and_isolate_databases.clean_database(prod_db_file)
-            print(f"      Included clean master sorour_logistics.db into {STANDALONE_DEST}")
+    # 3. The database is NEVER bundled (docs/plans/update-system-plan.md section 0, A1/A3/R1).
+    #    The installed backend creates an empty DB on first run; an existing laptop DB is never replaced.
+    if "--keep-operational-data" in sys.argv or "--preserve-data" in sys.argv:
+        print("[ERROR] --preserve-data / --keep-operational-data are no longer supported: the database is never bundled.")
+        return False
 
     # 4. Copy App Icon & Sync Tools
     if APP_ICON_SRC.exists():
         safe_copy_file(APP_ICON_SRC, STANDALONE_DEST / "app_icon.ico")
         print(f"      Included app_icon.ico into {STANDALONE_DEST}")
 
-    for util_file in ["sync_to_production.py", "version_manager.py", "version.json", "reset_clean_production_db.py", "clean_and_isolate_databases.py", "incoterms_data.json"]:
+    # Destructive maintenance scripts (reset_clean_production_db.py, clean_and_isolate_databases.py,
+    # sync_to_production.py) are never shipped (plan section 0, A4/R4).
+    for util_file in ["version_manager.py", "version.json", "incoterms_data.json"]:
         if (ROOT_DIR / util_file).exists():
             safe_copy_file(ROOT_DIR / util_file, STANDALONE_DEST / util_file)
             print(f"      Included {util_file} into {STANDALONE_DEST}")
```

## Diff 2 (recommended, apply after Diff 1): guard before the installer and zip are built

```diff
--- a/package_production.py
+++ b/package_production.py
@@ -255,6 +255,16 @@
     version = version_info.get("version", "1.0.4")
     build_no = version_info.get("build_number", 1)
     
+    # 0. Bundle guard (plan section 0, R4): never build an installer or zip that ships data or secrets
+    guard = subprocess.run([
+        sys.executable, str(ROOT_DIR / "scripts" / "release" / "bundle_guard.py"),
+        "--iss", str(ROOT_DIR / "installer" / "importflow_setup.iss"),
+        "--dir", str(STANDALONE_DEST),
+    ])
+    if guard.returncode != 0:
+        print("[ERROR] Bundle guard failed: installer and portable zip were NOT built.")
+        return False
+
     # 1. Compile Inno Setup if ISCC is available
     iscc_paths = [
         r"C:\Users\Hp\AppData\Local\Programs\Inno Setup 6\ISCC.exe",
@@ -340,6 +350,7 @@
             with open(standalone_version_json, "w", encoding="utf-8") as f:
                 json.dump(version_data, f, indent=2, ensure_ascii=False)
             print(f"      [SUCCESS] Updated dist/Sorour_Logistics_Standalone/version.json with installer_url")
+    return True
 
 
 def main():
@@ -379,9 +390,9 @@
     s2 = copy_desktop_release()
     s3 = copy_web_release()
     s4 = create_production_launchers()
-    compile_installer_and_zip(version_info)
-
-    if s1 and s2 and s4:
+    s5 = compile_installer_and_zip(version_info) if s1 else False
+
+    if s1 and s2 and s4 and s5:
         print("================================================================================")
         print(f"[SUCCESS] Production release v{version} (Build {build_no}) created at: {DIST_DIR}")
         print("================================================================================")
```

Notes on Diff 2:
- `compile_installer_and_zip()` now returns `True`/`False`, and `main()` fails when the guard fails (previously its result was ignored).
- In CI the workflow also runs the guard itself (before packaging on the `.iss`, and after packaging on the staged folder and the portable zip, before Inno Setup is installed), so CI is protected with or without Diff 2.
