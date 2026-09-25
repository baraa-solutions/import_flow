"""
Sorour Logistics ERP — Background Service & Health Manager
CLI tool to manage and monitor the background FastAPI backend service on Windows.
"""
import os
import sys
import time
import shutil
import argparse
import subprocess
import urllib.request
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = ROOT_DIR / "scripts"
VBS_LAUNCHER = SCRIPTS_DIR / "start_backend_service.vbs"
PORT = 28080
HEALTH_URL = f"http://127.0.0.1:{PORT}/api/v1/health"


def get_backend_pid():
    """Find PID of process listening on port 28080."""
    try:
        output = subprocess.check_output(f'netstat -ano | findstr ":{PORT}"', shell=True, text=True)
        for line in output.strip().splitlines():
            if "LISTENING" in line:
                parts = line.strip().split()
                return int(parts[-1])
    except Exception:
        pass
    return None


def is_backend_healthy():
    """Check if FastAPI returns HTTP 200 on the public health endpoint."""
    try:
        with urllib.request.urlopen(HEALTH_URL, timeout=2) as response:
            return response.status == 200
    except Exception:
        return False


def status_service():
    pid = get_backend_pid()
    healthy = is_backend_healthy()
    print("================================================================================")
    print("           Sorour Logistics ERP — Backend Service Status                        ")
    print("================================================================================")
    if pid and healthy:
        print(f" [STATUS]  RUNNING (Active & Healthy)")
        print(f" [PID]     {pid}")
        print(f" [PORT]    {PORT} (http://127.0.0.1:{PORT})")
        print(f" [HEALTH]  HTTP 200 OK (Swagger Docs Accessible)")
    elif pid and not healthy:
        print(f" [STATUS]  STARTING / UNRESPONSIVE (Port listening on PID {pid}, waiting for HTTP response)")
    else:
        print(f" [STATUS]  STOPPED (No process listening on port {PORT})")
    print("================================================================================")
    return pid is not None and healthy


def start_service():
    print(f"Starting Sorour Logistics Backend Service on port {PORT}...")
    if is_backend_healthy():
        print(f"[ALREADY RUNNING] Backend service is already active on PID {get_backend_pid()}.")
        return True

    if VBS_LAUNCHER.exists():
        subprocess.run(["wscript.exe", str(VBS_LAUNCHER)], check=True)
    else:
        # Fallback to python subprocess if VBS is missing
        subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "main:app", "--host", "127.0.0.1", f"--port={PORT}", "--no-access-log"],
            cwd=str(ROOT_DIR),
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        )

    # Wait up to 5 seconds for health
    for _ in range(10):
        time.sleep(0.5)
        if is_backend_healthy():
            print(f"[SUCCESS] Backend service started and healthy on PID {get_backend_pid()}!")
            return True

    print("[WARN] Backend service launched, but health check is taking longer to respond.")
    return False


def stop_service():
    pid = get_backend_pid()
    if not pid:
        print(f"[STOPPED] No backend service was listening on port {PORT}.")
        return True

    print(f"Stopping Backend Service on PID {pid}...")
    try:
        subprocess.run(f"taskkill /f /pid {pid}", shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.5)
        print("[SUCCESS] Backend service stopped successfully.")
        return True
    except Exception as e:
        print(f"[ERROR] Failed to terminate PID {pid}: {e}")
        return False


def get_startup_shortcut_path():
    appdata = os.environ.get("APPDATA")
    if appdata:
        return Path(appdata) / r"Microsoft\Windows\Start Menu\Programs\Startup\Sorour_Logistics_Backend.vbs"
    return None


def install_startup():
    shortcut_path = get_startup_shortcut_path()
    if not shortcut_path:
        print("[ERROR] Could not determine Windows Startup folder.")
        return False

    shortcut_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(VBS_LAUNCHER, shortcut_path)
    print("================================================================================")
    print(f"[SUCCESS] Windows Auto-Startup Configured!")
    print(f" - Startup file: {shortcut_path}")
    print(f" - The backend will now automatically start silently when Windows boots.")
    print("================================================================================")
    return True


def uninstall_startup():
    shortcut_path = get_startup_shortcut_path()
    if shortcut_path and shortcut_path.exists():
        shortcut_path.unlink()
        print(f"[SUCCESS] Removed startup shortcut: {shortcut_path}")
    else:
        print("[INFO] Auto-startup was not installed.")
    return True


def main():
    parser = argparse.ArgumentParser(description="Sorour Logistics ERP Background Service Manager")
    parser.add_argument("action", choices=["status", "start", "stop", "restart", "install-startup", "uninstall-startup"], help="Service action to perform")
    args = parser.parse_args()

    if args.action == "status":
        status_service()
    elif args.action == "start":
        start_service()
    elif args.action == "stop":
        stop_service()
    elif args.action == "restart":
        stop_service()
        time.sleep(1)
        start_service()
    elif args.action == "install-startup":
        install_startup()
    elif args.action == "uninstall-startup":
        uninstall_startup()


if __name__ == "__main__":
    main()
