"""
Sorour Logistics ERP — Automated Database Restore Utility
=========================================================
- Restores database from an authentic backup file.
- Verifies integrity of backup (PRAGMA integrity_check) before proceeding.
- Uses SQLite Online Backup API to safely restore data without file-lock collisions.
- Validates restored database integrity post-restoration.

Safety (docs/plans/update-system-plan.md A15 / R12):
- the target is ONE explicit ``--db`` path, and ``--confirm`` is required;
- the restore is refused while the backend (backend.exe / uvicorn) holds the target;
- before anything is overwritten, the current target gets a verified, protected ``pre_restore_`` backup;
  if that backup fails, nothing is restored.

Usage:
    python scripts/restore_database.py --list [--db <path>]
    python scripts/restore_database.py --backup <file.db|file.db.enc> --db <target.db> --confirm
"""
import sys
import shutil
import tempfile
import argparse
import sqlite3
from pathlib import Path
from datetime import datetime
from typing import List, Optional

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))
from utils.crypto_utils import (  # noqa: E402
    is_encrypted_backup,
    decrypt_backup_file,
)
from utils.db_safety import backups_dir_for, default_db_path, sqlite_online_backup  # noqa: E402
from scripts.db_script_guard import (  # noqa: E402
    PRE_RESTORE_BACKUP_PREFIX,
    UnsafeTargetError,
    add_target_arguments,
    guard_destructive_target,
    guard_programmatic_target,
    require_target,
    run_guarded,
)


def verify_sqlite_integrity(db_path: Path) -> bool:
    if not db_path.exists():
        return False
    try:
        conn = sqlite3.connect(db_path)
        try:
            res = conn.execute("PRAGMA integrity_check;").fetchone()[0]
        finally:
            conn.close()
        return res == "ok"
    except sqlite3.Error as e:
        print(f"[ERROR] Integrity check exception: {e}")
        return False


def _guard_restore_target(
    backup_file: Path, target_db: Path, *, confirm: bool, backups_dir: Optional[Path]
) -> None:
    """Refuse unsafe restores; back up an existing target first (protected pre_restore_ name)."""
    if target_db.resolve() == backup_file.resolve():
        raise UnsafeTargetError("The backup file and the target database are the same file.")
    if not target_db.exists():
        # Nothing to overwrite; still never recreate the live DB behind the app's back without confirm.
        if not confirm:
            guard_programmatic_target(target_db, must_exist=False)
        return
    if not confirm:
        raise UnsafeTargetError(
            f"Refusing to overwrite the existing database {target_db} without confirmation (--confirm)."
        )
    guard_destructive_target(
        target_db,
        confirm=True,
        tag="restore",
        backup_prefix=PRE_RESTORE_BACKUP_PREFIX,
        backups_dir=backups_dir,
    )


def restore_database(
    backup_file: Path,
    target_db: Path,
    *,
    confirm: bool = False,
    backups_dir: Optional[Path] = None,
) -> bool:
    """Restore ``backup_file`` into ``target_db``.

    Overwriting an existing target requires ``confirm=True`` and first takes a verified pre_restore_
    backup of it (raises UnsafeTargetError when refused, before anything is written).
    """
    backup_file = Path(backup_file)
    target_db = require_target(target_db, must_exist=False)
    print("================================================================================")
    print("           Sorour Logistics ERP — Database Disaster Recovery Restore            ")
    print("================================================================================")
    print(f" Source Backup : {backup_file}")
    print(f" Target DB     : {target_db}")

    if not backup_file.exists():
        print(f"[FAIL] Backup file does not exist: {backup_file}")
        return False

    temp_decrypt_dir = None
    try:
        source_to_restore = backup_file
        # 0. Detect and decrypt if AES-256-GCM sealed backup
        if is_encrypted_backup(backup_file) or backup_file.name.endswith(".enc"):
            print("[0/4] Authenticated AES-256-GCM encrypted backup detected.")
            print("      Decrypting using local encryption key...")
            # Private local temp folder: never next to the .enc, which may sit in a cloud-synced folder.
            temp_decrypt_dir = Path(tempfile.mkdtemp(prefix="sorour_restore_"))
            temp_decrypted_path = temp_decrypt_dir / "decrypted_restore_source.db"
            try:
                decrypt_backup_file(backup_file, temp_decrypted_path)
                source_to_restore = temp_decrypted_path
                print("      Decryption: SUCCESS (authenticated signature valid)")
            except Exception as e:
                print(f"[FAIL] Decryption failed: {e}")
                return False

        # 1. Pre-restore backup verification
        print("[1/4] Verifying source backup file integrity...")
        if not verify_sqlite_integrity(source_to_restore):
            print("[FAIL] Source backup integrity check failed or file is corrupted.")
            return False
        print("      Integrity: PASS (ok)")

        # 2. Safety: target not in use, verified pre_restore_ backup of the current target
        print("[2/4] Checking the target and backing up the current database...")
        _guard_restore_target(backup_file, target_db, confirm=confirm, backups_dir=backups_dir)

        # 3. Perform online restoration (one transaction on the target: a failure leaves it unchanged)
        print(f"[3/4] Performing online restoration to {target_db.name}...")
        try:
            sqlite_online_backup(source_to_restore, target_db, overwrite=target_db.exists())
            print("      Restoration completed successfully.")
        except Exception as e:
            print(f"[FAIL] Error during restore operation: {e}")
            return False

        # 4. Post-restore target database verification
        print("[4/4] Verifying restored target database...")
        if not verify_sqlite_integrity(target_db):
            print("[FAIL] Post-restoration target integrity check failed.")
            return False
        print("      Post-restore Integrity: PASS (ok)")

        print("================================================================================")
        print("[SUCCESS] Database successfully restored and verified 100% healthy.")
        print("================================================================================")
        return True
    finally:
        # Secure cleanup of temporary decrypted database copy
        if temp_decrypt_dir is not None:
            shutil.rmtree(temp_decrypt_dir, ignore_errors=True)


def list_available_backups(backups_dir: Optional[Path] = None):
    backups_dir = Path(backups_dir) if backups_dir else backups_dir_for(default_db_path())
    print(f"Available backups in {backups_dir}:")
    if not backups_dir.exists():
        print("  No backups directory found.")
        return
    seen = set()
    all_files = []
    for f in list(backups_dir.glob("*.db")) + list(backups_dir.glob("*.enc")):
        if f.name not in seen:
            seen.add(f.name)
            all_files.append(f)

    files = sorted(all_files, key=lambda f: f.stat().st_mtime, reverse=True)
    if not files:
        print("  No backup files found.")
        return
    for f in files:
        size_mb = f.stat().st_size / (1024 * 1024)
        mtime = datetime.fromtimestamp(f.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
        enc_label = " [ENCRYPTED - AES-256-GCM]" if (f.name.endswith(".enc") or is_encrypted_backup(f)) else ""
        print(f"  - {f.name} ({size_mb:.2f} MB){enc_label} - {mtime}")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Sorour Logistics ERP Database Restore Utility")
    parser.add_argument("--backup", type=str, help="Path to the backup file (.db or .db.enc) to restore from")
    parser.add_argument("--list", action="store_true", help="List available backups (next to --db, or the app DB)")
    add_target_arguments(parser, target_help="Database file to restore into")
    args = parser.parse_args(argv)

    if args.list:
        if args.backups_dir:
            folder = Path(args.backups_dir)
        elif args.db:
            folder = backups_dir_for(args.db)
        else:
            folder = None
        list_available_backups(folder)
        return 0

    if not args.backup:
        print("[ERROR] Please provide --backup <path> or use --list to view available backups.", file=sys.stderr)
        return 1

    def _run():
        require_target(args.db, must_exist=False)
        if not args.confirm:
            raise UnsafeTargetError("A restore overwrites the target database: pass --confirm to proceed.")
        return restore_database(
            Path(args.backup),
            Path(args.db),
            confirm=True,
            backups_dir=Path(args.backups_dir) if args.backups_dir else None,
        )

    return run_guarded(_run)


if __name__ == "__main__":
    sys.exit(main())
