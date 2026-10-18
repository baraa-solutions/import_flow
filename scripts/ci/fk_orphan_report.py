"""
Foreign Key Orphan Report (BEX-T16).

Runs read-only SQLite PRAGMA foreign_key_check across all tables in the specified
database to detect orphaned rows before and during production releases.
"""

import argparse
import os
from pathlib import Path
import sqlite3
import sys
from typing import Any, Dict, List, Optional


def check_foreign_keys(db_path: Path) -> List[Dict[str, Any]]:
    """
    Executes PRAGMA foreign_key_check on the specified SQLite database file.
    Returns a list of dicts with keys: table, rowid, parent_table, fkid.
    """
    if not db_path.exists():
        raise FileNotFoundError(f"Database file not found: {db_path}")

    # Connect in read-only mode to prevent any accidental writes
    uri = f"file:{db_path.resolve().as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    try:
        cursor = conn.cursor()
        cursor.execute("PRAGMA foreign_key_check;")
        raw_rows = cursor.fetchall()
        violations = []
        for r in raw_rows:
            # SQLite PRAGMA foreign_key_check returns:
            # (table, rowid, parent, fkid)
            violations.append({
                "table": r[0],
                "rowid": r[1],
                "parent_table": r[2],
                "fkid": r[3],
            })
        return violations
    finally:
        conn.close()


def generate_report(db_path: Path, strict: bool = True) -> int:
    """
    Runs foreign key check and prints human-readable table of violations.
    Returns 0 if no violations found, or 1 if violations exist.
    """
    print(f"==================================================")
    print(f" SQLite Foreign Key Integrity Check (BEX-T16)")
    print(f" Target Database: {db_path}")
    print(f"==================================================")

    try:
        violations = check_foreign_keys(db_path)
    except Exception as exc:
        print(f"ERROR: Failed to run foreign key check: {exc}", file=sys.stderr)
        return 2

    if not violations:
        print("Status: PASSED")
        print("Orphaned rows / FK violations: 0")
        print("All foreign key constraints are valid.")
        return 0

    print("Status: FAILED - Foreign key violations detected!")
    print(f"Total orphaned rows: {len(violations)}")
    print("-" * 70)
    print(f"{'Table':<30} | {'RowID':<10} | {'Parent Table':<20} | {'FK ID':<5}")
    print("-" * 70)
    for v in violations:
        print(f"{v['table']:<30} | {v['rowid']:<10} | {str(v['parent_table']):<20} | {v['fkid']:<5}")
    print("-" * 70)

    return 1 if strict else 0


def main():
    parser = argparse.ArgumentParser(description="Check SQLite database for foreign key violations")
    default_db = os.getenv("DATABASE_PATH", "sorour_logistics.db")
    parser.add_argument(
        "--db",
        type=Path,
        default=Path(default_db),
        help=f"Path to SQLite database file (default: {default_db})",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        default=True,
        help="Exit with code 1 if violations are found (default: True)",
    )
    args = parser.parse_args()

    exit_code = generate_report(args.db, strict=args.strict)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
