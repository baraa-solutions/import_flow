"""
Sorour Logistics ERP — Production Packaging Script
===================================================
Creates standalone portable packages and distribution bundles for Windows and Web.
Automatically increments the sequential version and build number on every production run.
"""
import os
import shutil
import sys
import zipfile
import hashlib
import json
import subprocess
from datetime import datetime
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent
DIST_DIR = ROOT_DIR / "dist"
STANDALONE_DEST = DIST_DIR / "Sorour_Logistics_Standalone"
DESKTOP_DEST = DIST_DIR / "Sorour_Logistics_Desktop"
WEB_DEST = DIST_DIR / "Sorour_Logistics_Web"

DESKTOP_SRC = ROOT_DIR / "frontend" / "build" / "windows" / "x64" / "runner" / "Release"
WEB_SRC = ROOT_DIR / "frontend" / "build" / "web"
BACKEND_EXE = ROOT_DIR / "dist_backend" / "backend.exe"
APP_ICON_SRC = ROOT_DIR / "installer" / "app_icon.ico"

import version_manager


def safe_copy_file(src: Path, dst: Path) -> bool:
    """Safely copy a file handling open file locks or retry with temporary rename."""
    if not src.exists():
        return False
    try:
        if dst.exists():
            try:
                dst.unlink(missing_ok=True)
            except Exception:
                pass
        shutil.copy2(src, dst)
        return True
    except Exception as e:
        try:
            with open(src, "rb") as fsrc, open(dst, "wb") as fdst:
                shutil.copyfileobj(fsrc, fdst)
            return True
        except Exception as e2:
            print(f"      [WARN] Could not copy {src.name} to {dst.name}: {e2}")
            return False


def clean_dist():
    print(f"[1/5] Preparing clean dist directory: {DIST_DIR}...")
    # Backup current standalone db before cleaning
    if (STANDALONE_DEST / "sorour_logistics.db").exists():
        backup_dir = ROOT_DIR / "backups"
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup_snapshot = backup_dir / f"sorour_logistics_prod_before_pack_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        try:
            safe_copy_file(STANDALONE_DEST / "sorour_logistics.db", backup_snapshot)
        except Exception:
            pass

    if DIST_DIR.exists():
        for item in DIST_DIR.iterdir():
            if item.name in ["releases", "backups"]:
                continue
            if item.is_dir():
                shutil.rmtree(item, ignore_errors=True)
            else:
                try:
                    item.unlink(missing_ok=True)
                except Exception:
                    pass
    else:
        DIST_DIR.mkdir(parents=True, exist_ok=True)

    print(f"[1/5] Prepared dist directory: {DIST_DIR}")


def copy_standalone_package():
    print(f"[2/5] Creating All-In-One Standalone Portable Package (No Python Required)...")
    if not DESKTOP_SRC.exists() or not (DESKTOP_SRC / "frontend.exe").exists():
        print(f"[ERROR] Windows release binary not found at {DESKTOP_SRC}")
        return False

    STANDALONE_DEST.mkdir(parents=True, exist_ok=True)

    # 1. Copy desktop files
    for item in DESKTOP_SRC.iterdir():
        dest = STANDALONE_DEST / item.name
        if item.is_dir():
            shutil.copytree(item, dest, dirs_exist_ok=True)
        else:
            safe_copy_file(item, dest)
    
    # 2. Copy backend.exe
    if BACKEND_EXE.exists():
        safe_copy_file(BACKEND_EXE, STANDALONE_DEST / "backend.exe")
        print(f"      Included backend.exe into {STANDALONE_DEST}")
    else:
        print(f"[WARN] backend.exe not found at {BACKEND_EXE}")

    # 3. The database is NEVER bundled (docs/plans/update-system-plan.md section 0, A1/A3/R1).
    #    The installed backend creates an empty DB on first run; an existing laptop DB is never replaced.
    if "--keep-operational-data" in sys.argv or "--preserve-data" in sys.argv:
        print("[ERROR] --preserve-data / --keep-operational-data are no longer supported: the database is never bundled.")
        return False

    # 4. Copy App Icon & Sync Tools
    if APP_ICON_SRC.exists():
        safe_copy_file(APP_ICON_SRC, STANDALONE_DEST / "app_icon.ico")
        print(f"      Included app_icon.ico into {STANDALONE_DEST}")

    # Destructive maintenance scripts (reset_clean_production_db.py, clean_and_isolate_databases.py,
    # sync_to_production.py) are never shipped (plan section 0, A4/R4).
    for util_file in ["version_manager.py", "version.json", "incoterms_data.json"]:
        if (ROOT_DIR / util_file).exists():
            safe_copy_file(ROOT_DIR / util_file, STANDALONE_DEST / util_file)
            print(f"      Included {util_file} into {STANDALONE_DEST}")

    # 5. Create Standalone Silent VBS Launcher (0 Terminal Windows)
    vbs_launcher = r'''Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
strPath = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = strPath

' 1. Free Port 28080 silently
WshShell.Run "cmd /c for /f ""tokens=5"" %p in ('netstat -ano ^| findstr "":28080""') do taskkill /f /pid %p", 0, True

' 2. Start Embedded Backend Server invisibly in background (0 = hidden)
If fso.FileExists(strPath & "\backend.exe") Then
    WshShell.Run Chr(34) & strPath & "\backend.exe" & Chr(34), 0, False
End If

' 3. Wait 1.2s for backend server ready
WScript.Sleep 1200

' 4. Start Native Windows Desktop App and WAIT until closed (1 = normal window, True = wait for exit)
If fso.FileExists(strPath & "\frontend.exe") Then
    WshShell.Run Chr(34) & strPath & "\frontend.exe" & Chr(34), 1, True
End If

' 5. When frontend is closed by the user, terminate backend.exe cleanly and silently
WshShell.Run "taskkill /f /im backend.exe", 0, True
'''
    vbs_file = STANDALONE_DEST / "Launch_Sorour_Logistics.vbs"
    with open(vbs_file, "w", encoding="utf-8") as f:
        f.write(vbs_launcher)

    # 6. Create Standalone Batch Launcher
    launcher_content = """@echo off
title Sorour Logistics ERP
setlocal

:: 1. Free Port 28080 if occupied
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":28080"') do taskkill /f /pid %%p >nul 2>&1

:: 2. Start Embedded Backend Engine (Silent Mode)
if exist "%~dp0backend.exe" (
    start "" "%~dp0backend.exe"
)

:: 3. Wait for API Server
ping 127.0.0.1 -n 2 >nul 2>&1

:: 4. Launch Desktop Client (.EXE)
start "" "%~dp0frontend.exe"
exit /b 0
"""
    standalone_launcher = STANDALONE_DEST / "Sorour_Logistics_App.bat"
    with open(standalone_launcher, "w", encoding="utf-8") as f:
        f.write(launcher_content)

    # Backward compatibility alias
    try:
        with open(STANDALONE_DEST / "Launch_ImportFlow.vbs", "w", encoding="utf-8") as f:
            f.write(vbs_launcher)
    except Exception:
        pass

    print(f"      Created Silent Launcher: {vbs_file}")
    return True


def copy_desktop_release():
    print(f"[3/5] Packaging Windows Desktop Release Client from {DESKTOP_SRC}...")
    if not DESKTOP_SRC.exists() or not (DESKTOP_SRC / "frontend.exe").exists():
        print(f"[ERROR] Windows release binary not found at {DESKTOP_SRC}")
        return False
    shutil.copytree(DESKTOP_SRC, DESKTOP_DEST, dirs_exist_ok=True)
    print(f"      Copied desktop client to: {DESKTOP_DEST}")
    return True


def copy_web_release():
    print(f"[4/5] Packaging Web Release from {WEB_SRC}...")
    if not WEB_SRC.exists():
        print(f"[WARN] Web release build not found at {WEB_SRC}, skipping web packaging.")
        return True
    shutil.copytree(WEB_SRC, WEB_DEST, dirs_exist_ok=True)
    print(f"      Copied web release to: {WEB_DEST}")
    return True


def create_production_launchers():
    print(f"[5/5] Generating Root Production Launchers in dist/...")

    # Root Dist Launcher
    root_launcher_content = """@echo off
title Sorour Logistics ERP Production
setlocal

echo ===============================================================================
echo             Sorour Logistics ERP - Production Standalone Launcher
echo ===============================================================================
echo.

if exist "%~dp0Sorour_Logistics_Standalone\\Launch_Sorour_Logistics.vbs" (
    start "" "%~dp0Sorour_Logistics_Standalone\\Launch_Sorour_Logistics.vbs"
    echo Application launched silently!
    exit /b 0
)

if exist "%~dp0Sorour_Logistics_Standalone\\Sorour_Logistics_App.bat" (
    start "" "%~dp0Sorour_Logistics_Standalone\\Sorour_Logistics_App.bat"
    exit /b 0
)

if exist "%~dp0ImportFlow_Standalone\\Launch_ImportFlow.vbs" (
    start "" "%~dp0ImportFlow_Standalone\\Launch_ImportFlow.vbs"
    exit /b 0
)

echo [ERROR] Sorour_Logistics_Standalone directory or launcher not found!
pause
exit /b 1
"""
    root_launcher = DIST_DIR / "Start_Sorour_Logistics_Production.bat"
    with open(root_launcher, "w", encoding="utf-8") as f:
        f.write(root_launcher_content)
    
    # Backward compatibility alias
    with open(DIST_DIR / "Start_ImportFlow_Production.bat", "w", encoding="utf-8") as f:
        f.write(root_launcher_content)

    print(f"      Generated: {root_launcher}")
    return True


def compile_installer_and_zip(version_info: dict):
    releases_dir = DIST_DIR / "releases"
    releases_dir.mkdir(parents=True, exist_ok=True)
    version = version_info.get("version", "1.0.4")
    build_no = version_info.get("build_number", 1)

    # 0. Bundle guard (plan section 0, R4): never build an installer or zip that ships data or secrets
    guard = subprocess.run([
        sys.executable, str(ROOT_DIR / "scripts" / "release" / "bundle_guard.py"),
        "--iss", str(ROOT_DIR / "installer" / "importflow_setup.iss"),
        "--dir", str(STANDALONE_DEST),
    ])
    if guard.returncode != 0:
        print("[ERROR] Bundle guard failed: installer and portable zip were NOT built.")
        return False

    # 1. Compile Inno Setup if ISCC is available
    iscc_paths = [
        r"C:\Users\Hp\AppData\Local\Programs\Inno Setup 6\ISCC.exe",
        r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        r"C:\Program Files\Inno Setup 6\ISCC.exe",
    ]
    iscc = next((p for p in iscc_paths if Path(p).exists()), None)
    setup_name = f"Sorour_Logistics_Setup_v{version}.exe"
    if iscc:
        iss_file = ROOT_DIR / "installer" / "importflow_setup.iss"
        print(f"[6/6] Compiling Setup Installer ({setup_name}) with Inno Setup...")
        res = subprocess.run([iscc, str(iss_file)], capture_output=True, text=True)
        if res.returncode == 0:
            print(f"      [SUCCESS] Generated: {releases_dir / setup_name}")
        else:
            print(f"      [WARN] ISCC: {res.stderr}")
            
    # 2. Compile Portable ZIP
    zip_name = f"Sorour_Logistics_v{version}_Windows_Portable.zip"
    zip_dest = releases_dir / zip_name
    print(f"[6/6] Compiling Portable ZIP ({zip_name})...")
    with zipfile.ZipFile(zip_dest, "w", zipfile.ZIP_DEFLATED) as zipf:
        for file_path in STANDALONE_DEST.rglob("*"):
            if file_path.is_file():
                arcname = file_path.relative_to(STANDALONE_DEST.parent)
                zipf.write(file_path, arcname)
    size_mb = round(zip_dest.stat().st_size / (1024 * 1024), 2)
    print(f"      [SUCCESS] Generated: {zip_dest} ({size_mb} MB)")
    
    # 3. Update latest_release.json
    with open(zip_dest, "rb") as f:
        sha256_hash = hashlib.sha256(f.read()).hexdigest()
    release_info = {
        "version": version,
        "build_number": build_no,
        "release_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "app_name": "Sorour Logistics ERP",
        "packages": {
            "setup_exe": {
                "filename": setup_name,
                "path": str(releases_dir / setup_name)
            },
            "portable_zip": {
                "filename": zip_name,
                "size_mb": size_mb,
                "sha256": sha256_hash,
                "path": str(zip_dest)
            },
            "standalone_folder": {
                "path": str(STANDALONE_DEST),
                "launcher": str(STANDALONE_DEST / "Launch_Sorour_Logistics.vbs")
            }
        }
    }
    with open(releases_dir / "latest_release.json", "w", encoding="utf-8") as f:
        json.dump(release_info, f, indent=2, ensure_ascii=False)
    print(f"      [SUCCESS] Updated {releases_dir / 'latest_release.json'}")

    # 4. Update version.json with installer_url for in-app auto-update
    installer_path = releases_dir / setup_name
    installer_size_mb = 0.0
    if installer_path.exists():
        installer_size_mb = round(installer_path.stat().st_size / (1024 * 1024), 2)

    version_json_path = ROOT_DIR / "version.json"
    if version_json_path.exists():
        with open(version_json_path, "r", encoding="utf-8") as f:
            version_data = json.load(f)

        version_data["installer_url"] = (
            f"https://github.com/ahmedsalahsorour88/import_flow/releases/download/v{version}/{setup_name}"
        )
        version_data["installer_filename"] = setup_name
        version_data["installer_size_mb"] = installer_size_mb

        with open(version_json_path, "w", encoding="utf-8") as f:
            json.dump(version_data, f, indent=2, ensure_ascii=False)
        print(f"      [SUCCESS] Updated version.json with installer_url for v{version} ({installer_size_mb} MB)")

        # Also update the copy inside dist/Sorour_Logistics_Standalone/
        standalone_version_json = STANDALONE_DEST / "version.json"
        if standalone_version_json.exists():
            with open(standalone_version_json, "w", encoding="utf-8") as f:
                json.dump(version_data, f, indent=2, ensure_ascii=False)
            print(f"      [SUCCESS] Updated dist/Sorour_Logistics_Standalone/version.json with installer_url")
    return True


def main():
    # Automatically bump version unless --no-bump is explicitly provided
    if "--no-bump" in sys.argv:
        version_info = version_manager.get_current_version_info()
    else:
        bump_type = "patch"
        if "--major" in sys.argv:
            bump_type = "major"
        elif "--minor" in sys.argv:
            bump_type = "minor"
        elif "--build-only" in sys.argv:
            bump_type = "build_only"
        version_info = version_manager.bump_version(bump_type)

    version = version_info.get("version", "1.0.4")
    build_no = version_info.get("build_number", 1)

    print("================================================================================")
    print(f"       Sorour Logistics ERP (v{version} - Build {build_no}) - Production Packaging       ")
    print("================================================================================")
    
    # Compile Standalone Backend Executable if requested or if missing
    if "--compile-all" in sys.argv or "--compile-backend" in sys.argv or not BACKEND_EXE.exists():
        print(f"[*] Compiling Standalone Backend Executable (backend.exe)...")
        import build_backend_exe
        if build_backend_exe.build_backend() is False:
            print("[!] Backend build refused or failed (see messages above). Aborting packaging so a stale backend.exe is not shipped.")
            sys.exit(1)

    # Compile Flutter desktop release if requested or if frontend/build does not match
    if "--compile-all" in sys.argv or "--compile-flutter" in sys.argv or not DESKTOP_SRC.exists():
        print(f"[*] Compiling Flutter Desktop Release (v{version} - Build {build_no})...")
        subprocess.run(["flutter", "build", "windows", "--release"], cwd=ROOT_DIR / "frontend", check=True, shell=True)

    clean_dist()
    s1 = copy_standalone_package()
    s2 = copy_desktop_release()
    s3 = copy_web_release()
    s4 = create_production_launchers()
    s5 = compile_installer_and_zip(version_info) if s1 else False

    if s1 and s2 and s4 and s5:
        print("================================================================================")
        print(f"[SUCCESS] Production release v{version} (Build {build_no}) created at: {DIST_DIR}")
        print("================================================================================")
        return True
    else:
        print("[ERROR] Packaging failed.")
        return False


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
