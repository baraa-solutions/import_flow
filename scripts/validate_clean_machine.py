"""
Sorour Logistics ERP — Clean Machine Deployment Validator
=========================================================
Performs automated pre-flight diagnostics on a target Windows machine
to ensure 100% readiness for running Sorour Logistics ERP.
"""
import os
import sys
import socket
import ctypes
import platform
import argparse
import urllib.request
from pathlib import Path

# Ensure UTF-8 output on Windows consoles
if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

DEFAULT_PORT = 28080


def check_os_arch():
    is_windows = platform.system() == "Windows"
    is_64bit = platform.machine().endswith("64")
    os_release = platform.release()
    os_version = platform.version()

    status = is_windows and is_64bit
    return {
        "item": "نظام التشغيل والمعمارية (OS & 64-bit Architecture)",
        "pass": status,
        "details": f"{platform.system()} {os_release} (Build {os_version}) - 64-bit" if status else f"{platform.system()} (Requires Windows 10/11 64-bit)",
        "fix": "يجب تشغيل البرنامج على نظام Windows 10 أو Windows 11 إصدار 64-bit."
    }


def check_vcredist():
    system32 = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32"
    vcruntime = system32 / "vcruntime140.dll"
    msvcp = system32 / "msvcp140.dll"

    has_vc = vcruntime.exists() and msvcp.exists()
    return {
        "item": "حزم تشغيل مايكروسوفت (Visual C++ 2015-2022 Redistributable)",
        "pass": has_vc,
        "details": f"Found vcruntime140.dll & msvcp140.dll in {system32}" if has_vc else "Missing Visual C++ Redistributable DLLs",
        "fix": "قم بتحميل وتثبيت حزمة VC++ Redistributable 2015-2022 x64 من موقع مايكروسوفت الرسمي."
    }


def check_disk_write():
    local_app_data = Path(os.environ.get("LOCALAPPDATA", str(Path.home())))
    test_file = local_app_data / "_sorour_test_write.tmp"
    can_write = False
    try:
        with open(test_file, "w") as f:
            f.write("OK")
        test_file.unlink(missing_ok=True)
        can_write = True
    except Exception:
        can_write = False

    return {
        "item": "صلاحيات الكتابة بالقرص (AppData Write Permissions)",
        "pass": can_write,
        "details": f"Writable: {local_app_data}" if can_write else f"Permission Denied in {local_app_data}",
        "fix": "تأكد من امتلاك حساب المستخدم صلاحيات الكتابة في مجلد AppData الخاص به."
    }


def check_port_availability(port: int = DEFAULT_PORT):
    # Test if port can be bound or if it's already running the backend
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1.0)
    is_free = False
    is_backend = False

    try:
        sock.bind(("127.0.0.1", port))
        is_free = True
    except OSError:
        # Port is occupied, check if it's our backend
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/v1/health", timeout=1) as res:
                if res.status == 200:
                    is_backend = True
        except Exception:
            pass
    finally:
        sock.close()

    status = is_free or is_backend
    msg = "المنفذ 28080 متاح للتخصيص" if is_free else ("المنفذ 28080 يعمل عليه خادم النظام حالياً (Active)" if is_backend else "المنفذ 28080 محجوز لبرنامج آخر")
    return {
        "item": f"منفذ خادم الباك إند (Port {port} Availability)",
        "pass": status,
        "details": msg,
        "fix": f"تأكد من عدم حجز المنفذ {port} من تطبيق آخر، أو إيقاف التطبيق المشاغل له عبر taskkill."
    }


def check_hardware_resources():
    try:
        import psutil
        ram_gb = psutil.virtual_memory().total / (1024 ** 3)
        cores = psutil.cpu_count(logical=True)
        status = ram_gb >= 3.5 and cores >= 2
        details = f"{ram_gb:.1f} GB RAM, {cores} Logical CPU Cores"
    except ImportError:
        cores = os.cpu_count() or 1
        status = cores >= 2
        details = f"{cores} CPU Cores detected (psutil not installed, RAM unverified)"

    return {
        "item": "مواصفات العتاد والمعالج (CPU & Memory Resources)",
        "pass": status,
        "details": details,
        "fix": "يوصى بذاكرة عشوائية 4 جيجابايت RAM على الأقل ومعالج ثنائي النواة لتجربة سلسة."
    }


def check_server_connectivity(server_ip: str, port: int = DEFAULT_PORT):
    if server_ip in ("127.0.0.1", "localhost"):
        return None  # Local mode already covered by port check

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(3.0)
    reachable = False
    try:
        sock.connect((server_ip, port))
        reachable = True
    except Exception:
        reachable = False
    finally:
        sock.close()

    return {
        "item": f"الاتصال بالخادم الرئيسي (Central Server: {server_ip}:{port})",
        "pass": reachable,
        "details": f"نجح الاتصال بالخادم الرئيسي {server_ip}:{port}" if reachable else f"تعذر الوصول للخادم {server_ip}:{port}",
        "fix": f"تحقق من جدار الحماية (Windows Firewall) على جهاز السيرفر والسماح بالمنفذ {port}، وتأكد من اتصال الجهازين بنفس الشبكة المحلية LAN."
    }


def run_diagnostics(server_ip: str = "127.0.0.1"):
    print("================================================================================")
    print("        Sorour Logistics ERP — Clean Machine Deployment Readiness Check         ")
    print("================================================================================")

    checks = [
        check_os_arch(),
        check_vcredist(),
        check_disk_write(),
        check_port_availability(),
        check_hardware_resources(),
    ]

    remote_check = check_server_connectivity(server_ip)
    if remote_check:
        checks.append(remote_check)

    all_passed = True
    for idx, c in enumerate(checks, 1):
        symbol = "[PASS]" if c["pass"] else "[FAIL]"
        print(f"{idx}. {symbol} {c['item']}")
        print(f"   التفاصيل: {c['details']}")
        if not c["pass"]:
            print(f"   الحل المقترح: {c['fix']}")
            all_passed = False
        print("-" * 80)

    print("================================================================================")
    if all_passed:
        print("[جاهز للتشغيل 100%] الجهاز مستوفٍ لكافة المتطلبات التشغيلية لتثبيت وتشغيل النظام!")
    else:
        print("[تنبيه] هناك متطلبات غير مكتملة، يرجى مراجعة الحلول المقترحة أعلاه قبل التثبيت.")
    print("================================================================================")
    return all_passed


def main():
    parser = argparse.ArgumentParser(description="Sorour Logistics ERP Clean Machine Deployment Validator")
    parser.add_argument("--server", default="127.0.0.1", help="Target server IP for client-server network test (default: 127.0.0.1)")
    args = parser.parse_args()

    success = run_diagnostics(server_ip=args.server)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
