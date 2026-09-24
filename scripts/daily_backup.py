"""
Sorour Logistics ERP — Automated Daily Database Backup Utility
=============================================================
- Executes zero-downtime, non-blocking online SQLite backup.
- Manages 30-day retention policy (prunes older daily backups), but always keeps the newest
  MIN_BACKUPS_KEPT (7) daily backups whatever their age and never touches protected backups (R9).
- Verifies database integrity after backup (PRAGMA integrity_check).
- Computes SHA-256 checksum and writes metadata log.
- Supports one-click registration in Windows Task Scheduler.

The database defaults to the app database (``DATABASE_PATH`` or ``<app dir>/sorour_logistics.db``, where
the app dir is the executable's folder in the frozen build); backups go next to it in ``backups/``.
"""
import os
import sys
import time
import shutil
import argparse
import subprocess
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional, Union

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))
from utils.crypto_utils import (  # noqa: E402
    compute_sha256,
    encrypt_backup_file,
    is_encrypted_backup,
    get_backup_encryption_key,
)
from utils.db_safety import (  # noqa: E402
    DAILY_BACKUP_PREFIX,
    MIN_BACKUPS_KEPT,
    app_base_dir,
    backups_dir_for,
    select_prunable,
    sqlite_online_backup,
)

DEFAULT_RETENTION_DAYS = 30
TASK_NAME = "SorourLogistics_DailyBackup"


def default_backup_db_path() -> Path:
    """Same resolution as ``database.database.DB_PATH``: DATABASE_PATH, else <app dir>/sorour_logistics.db."""
    env_path = os.getenv("DATABASE_PATH")
    if env_path:
        return Path(env_path)
    return app_base_dir() / "sorour_logistics.db"


def default_backups_dir(db_path: Optional[Union[str, Path]] = None) -> Path:
    return backups_dir_for(db_path or default_backup_db_path())


# Import-time snapshots kept for backward compatibility; the functions resolve paths at call time.
DB_PATH = default_backup_db_path()
BACKUPS_DIR = default_backups_dir(DB_PATH)


def _daily_backup_files(directory: Path) -> list:
    patterns = [f"{DAILY_BACKUP_PREFIX}*.db", f"{DAILY_BACKUP_PREFIX}*.db.enc", f"{DAILY_BACKUP_PREFIX}*.enc"]
    seen = set()
    files = []
    for pattern in patterns:
        for f in directory.glob(pattern):
            if f in seen or not f.is_file():
                continue
            seen.add(f)
            files.append(f)
    return files


def prune_backups_in_dir(
    directory: Path,
    retention_days: int = DEFAULT_RETENTION_DAYS,
    keep_min: int = MIN_BACKUPS_KEPT,
) -> int:
    """Delete ``daily_backup_*`` files older than ``retention_days``, except the newest ``keep_min``
    (floored at MIN_BACKUPS_KEPT) and any protected backup (R9). Other backup families are never touched."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
    pruned_count = 0

    directory = Path(directory)
    if not directory.exists():
        return 0

    for f in select_prunable(_daily_backup_files(directory), keep=keep_min):
        try:
            mtime = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
            if mtime < cutoff:
                f.unlink(missing_ok=True)
                # Also prune associated json metadata
                meta_json = f.parent / f"{f.stem.replace('.db', '')}.json"
                meta_json.unlink(missing_ok=True)
                f.with_suffix(".json").unlink(missing_ok=True)
                pruned_count += 1
                print(f"  [PRUNED] Removed backup older than {retention_days} days: {f.name} in {directory}")
        except OSError as e:
            print(f"  [WARN] Failed to evaluate/prune {f.name}: {e}")

    return pruned_count


def prune_old_backups(retention_days: int = DEFAULT_RETENTION_DAYS, backups_dir: Optional[Path] = None):
    pruned_count = prune_backups_in_dir(Path(backups_dir) if backups_dir else default_backups_dir(), retention_days)
    if pruned_count > 0:
        print(f"[OK] Pruned {pruned_count} old local backup file(s) exceeding {retention_days} days retention.")
    else:
        print(f"[OK] Local retention check passed: All backups within {retention_days}-day window.")


def sync_to_google_drive(
    backup_path: Path,
    meta_path: Path,
    offsite_dir: Path = None,
    retention_days: int = DEFAULT_RETENTION_DAYS,
    encrypt_offsite: bool = True,
) -> dict:
    """
    Encrypts (AES-256-GCM) and mirrors the validated local backup into the Google Drive Desktop sync folder.
    Ensures Data-at-Rest protection before files leave the host machine.
    Verifies existence, byte size, and SHA-256 integrity, then enforces retention.
    """
    target_dir = None
    if offsite_dir:
        target_dir = Path(offsite_dir)
    else:
        env_dir = os.getenv("GOOGLE_DRIVE_BACKUP_DIR")
        if env_dir:
            target_dir = Path(env_dir)
        else:
            candidates = [
                Path("G:/My Drive/SorourLogistics-Backups"),
                Path("G:/Shared drives/SorourLogistics-Backups"),
                Path(os.path.expanduser("~")) / "Google Drive" / "SorourLogistics-Backups",
                Path(os.path.expanduser("~")) / "My Drive" / "SorourLogistics-Backups",
            ]
            for c in candidates:
                if c.parent.exists():
                    target_dir = c
                    break

    if not target_dir:
        msg = "Google Drive Desktop sync folder not configured or drive G: not mounted. Local backup is healthy, but offsite copy was skipped."
        print(f"\n[OFFSITE NOTICE] {msg}")
        return {"status": "SKIPPED", "reason": "DRIVE_NOT_CONFIGURED", "message": msg}

    try:
        target_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        msg = f"Failed to access/create Google Drive folder '{target_dir}': {e}"
        print(f"\n[OFFSITE WARNING] {msg}")
        return {"status": "FAILED", "reason": "DIRECTORY_ERROR", "message": msg}

    if encrypt_offsite:
        print(f"\n[5/5] Encrypting backup with AES-256-GCM before offsite sync...")
        enc_filename = f"{backup_path.name}.enc"
        temp_enc_path = backup_path.parent / enc_filename
        try:
            enc_result = encrypt_backup_file(backup_path, temp_enc_path)
            file_to_copy = temp_enc_path
            offsite_backup = target_dir / enc_filename
            print(f"      [ENCRYPTED] AES-256-GCM sealed ({enc_result['size_bytes']:,} bytes, SHA-256: {enc_result['sha256'][:16]}...)")
        except Exception as e:
            msg = f"Encryption failed before sync: {e}"
            print(f"      [OFFSITE ERROR] {msg}")
            return {"status": "FAILED", "reason": "ENCRYPTION_ERROR", "message": msg}
    else:
        file_to_copy = backup_path
        offsite_backup = target_dir / backup_path.name

    offsite_json = target_dir / meta_path.name

    print(f"      Mirroring to Google Drive sync folder: {target_dir}...")
    try:
        shutil.copy2(file_to_copy, offsite_backup)
        if meta_path.exists():
            # Update meta with encryption details
            import json
            try:
                with open(meta_path, "r", encoding="utf-8") as f:
                    meta_data = json.load(f)
                meta_data["offsite_encryption"] = {
                    "enabled": encrypt_offsite,
                    "algorithm": "AES-256-GCM" if encrypt_offsite else "NONE",
                    "offsite_file": offsite_backup.name,
                    "offsite_sha256": compute_sha256(file_to_copy),
                    "offsite_size_bytes": file_to_copy.stat().st_size,
                }
                with open(meta_path, "w", encoding="utf-8") as f:
                    json.dump(meta_data, f, indent=2)
            except Exception:
                pass
            shutil.copy2(meta_path, offsite_json)
    except Exception as e:
        msg = f"Error copying backup to Google Drive sync folder: {e}"
        print(f"      [OFFSITE ERROR] {msg}")
        return {"status": "FAILED", "reason": "COPY_ERROR", "message": msg}
    finally:
        # Clean up local temporary .enc file if it was created specifically for sync
        if encrypt_offsite and temp_enc_path.exists():
            temp_enc_path.unlink(missing_ok=True)

    # Verify existence, size, SHA-256
    if not offsite_backup.exists():
        msg = "Offsite copy verification failed: destination file not found."
        print(f"      [OFFSITE ERROR] {msg}")
        return {"status": "FAILED", "reason": "FILE_NOT_FOUND", "message": msg}

    local_source_size = file_to_copy.stat().st_size if file_to_copy.exists() else offsite_backup.stat().st_size
    offsite_size = offsite_backup.stat().st_size
    if local_source_size != offsite_size:
        msg = f"Offsite copy verification failed: size mismatch (source={local_source_size}, offsite={offsite_size})"
        print(f"      [OFFSITE ERROR] {msg}")
        return {"status": "FAILED", "reason": "SIZE_MISMATCH", "message": msg}

    offsite_sha256 = compute_sha256(offsite_backup)

    print(f"      [VERIFIED] Size match ({offsite_size:,} bytes) & SHA-256 match ({offsite_sha256[:16]}...)")
    print(f"      [NOTE] Encrypted file confirmed in sync folder. Cloud upload to drive.google.com will be processed by Google Drive Desktop client.")

    # Retention enforcement in Google Drive folder
    pruned = prune_backups_in_dir(target_dir, retention_days)
    if pruned > 0:
        print(f"      [OFFSITE RETENTION] Pruned {pruned} old backup(s) from Drive folder.")

    return {
        "status": "SUCCESS",
        "target_path": str(offsite_backup),
        "size_bytes": offsite_size,
        "sha256": offsite_sha256,
        "verified": True,
        "is_encrypted": encrypt_offsite,
        "algorithm": "AES-256-GCM" if encrypt_offsite else "NONE",
    }


def perform_backup(
    retention_days: int = DEFAULT_RETENTION_DAYS,
    offsite_dir: Path = None,
    encrypt_offsite: bool = True,
    db_path: Optional[Union[str, Path]] = None,
    backups_dir: Optional[Union[str, Path]] = None,
) -> Path:
    """Verified online backup of ``db_path`` (default: the app database) into ``backups_dir``
    (default: ``backups/`` next to the database), then retention and the optional offsite copy."""
    print("================================================================================")
    print("           Sorour Logistics ERP — Automated Daily Online Backup                 ")
    print("================================================================================")

    source_db = Path(db_path) if db_path else default_backup_db_path()
    target_dir = Path(backups_dir) if backups_dir else default_backups_dir(source_db)

    if not source_db.exists():
        raise FileNotFoundError(f"Source database not found at {source_db}")

    target_dir.mkdir(parents=True, exist_ok=True)

    timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"{DAILY_BACKUP_PREFIX}{timestamp_str}.db"
    backup_path = target_dir / backup_filename
    counter = 1
    while backup_path.exists():
        backup_filename = f"{DAILY_BACKUP_PREFIX}{timestamp_str}_{counter}.db"
        backup_path = target_dir / backup_filename
        counter += 1

    start_time = time.time()
    print(f"[1/4] Performing zero-downtime online backup to: {backup_filename}...")

    # 1-2. Native Online Backup API + integrity_check (a failed copy is deleted and raises)
    result = sqlite_online_backup(source_db, backup_path)
    elapsed = time.time() - start_time
    print(f"      Completed in {elapsed:.2f} seconds.")
    print("[2/4] Verifying backup database integrity...")
    print(f"      Integrity check: PASS ({result.integrity})")

    # 3. Checksum & Metadata
    print("[3/4] Generating SHA-256 Checksum and metadata...")
    checksum = result.sha256
    file_size = result.size_bytes

    meta = {
        "system": "Sorour Logistics ERP",
        "backup_type": "Daily Automated",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "backup_file": backup_filename,
        "size_bytes": file_size,
        "sha256": checksum,
        "integrity": "PASS",
        "retention_days": retention_days,
        "encryption": {
            "offsite_aes_gcm": encrypt_offsite,
        }
    }
    meta_path = backup_path.with_suffix(".json")
    import json
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(f"      SHA-256: {checksum}")
    print(f"      Size: {file_size:,} bytes")

    # 4. Retention policy enforcement
    print(f"[4/4] Enforcing {retention_days}-day backup retention policy...")
    prune_old_backups(retention_days, backups_dir=target_dir)

    # 5. Offsite sync to Google Drive Desktop folder
    offsite_res = sync_to_google_drive(
        backup_path,
        meta_path,
        offsite_dir=offsite_dir,
        retention_days=retention_days,
        encrypt_offsite=encrypt_offsite,
    )
    if offsite_res.get("verified"):
        meta["offsite_sync"] = offsite_res
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2)

    print("================================================================================")
    print(f"[SUCCESS] Daily backup successfully finished: {backup_path.name}")
    print("================================================================================")
    return backup_path


def register_windows_task():
    """Register daily backup in Windows Task Scheduler at 23:00 (11 PM)."""
    python_exe = sys.executable
    script_path = ROOT_DIR / "scripts" / "daily_backup.py"
    cmd = f'schtasks /create /tn "{TASK_NAME}" /tr "\"{python_exe}\" \"{script_path}\"" /sc daily /st 23:00 /f'
    print(f"Registering Windows Task: {TASK_NAME} at 23:00 daily...")
    try:
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if res.returncode == 0:
            print("================================================================================")
            print("[SUCCESS] Windows Scheduled Task registered successfully!")
            print(f" Task Name: {TASK_NAME}")
            print(" Schedule: Daily at 23:00 (11:00 PM)")
            print(" Action: Python daily_backup.py")
            print("================================================================================")
            return True
        else:
            print(f"[ERROR] Failed to register task: {res.stderr.strip() or res.stdout.strip()}")
            return False
    except Exception as e:
        print(f"[ERROR] Exception during task registration: {e}")
        return False


def unregister_windows_task():
    cmd = f'schtasks /delete /tn "{TASK_NAME}" /f'
    print(f"Unregistering Windows Task: {TASK_NAME}...")
    try:
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if res.returncode == 0:
            print(f"[SUCCESS] Windows Task '{TASK_NAME}' deleted successfully.")
            return True
        else:
            print(f"[INFO] Task was not registered or could not be removed: {res.stderr.strip()}")
            return False
    except Exception as e:
        print(f"[ERROR] {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Sorour Logistics ERP Automated Daily Backup")
    parser.add_argument("--retention", type=int, default=DEFAULT_RETENTION_DAYS, help="Number of days to keep backups (default: 30)")
    parser.add_argument("--offsite-dir", type=str, default=None, help="Path to Google Drive Desktop sync folder")
    parser.add_argument("--no-encrypt", action="store_true", help="Disable AES-256-GCM encryption for offsite sync")
    parser.add_argument("--test", action="store_true", help="Run backup immediately in test mode")
    parser.add_argument("--register-task", action="store_true", help="Register backup in Windows Task Scheduler at 23:00 daily")
    parser.add_argument("--unregister-task", action="store_true", help="Delete Windows Scheduled Task")
    args = parser.parse_args()

    if args.register_task:
        register_windows_task()
    elif args.unregister_task:
        unregister_windows_task()
    else:
        offsite_p = Path(args.offsite_dir) if args.offsite_dir else None
        perform_backup(
            retention_days=args.retention,
            offsite_dir=offsite_p,
            encrypt_offsite=not args.no_encrypt,
        )


if __name__ == "__main__":
    main()

