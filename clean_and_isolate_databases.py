"""
Sorour Logistics ERP — Clean Production Database Isolator & Wiper
===================================================================
Enforces the mandatory rule:
Every new production release MUST be completely clean and empty of any user/operational records (0 records),
preserving ONLY core master reference tables:
  1. Ports & Transport Locations (transport_locations, countries, cities)
  2. HS Codes & Egyptian Customs Tariffs (customs_tariffs, fee_codes, preferential_agreements)
  3. Incoterms 2020 & Responsibility Matrix & Cost Items (incoterms, cost_items, incoterm_responsibilities)
  4. Currencies & Exchange Rates (currencies, exchange_rates)
  5. System Core & RBAC Users (users, container_specs, package_types, units_of_measure, clearance_expense_types)

DESTRUCTIVE (wipes every non-master table). Safety (update-system-plan A4/R12):
    python clean_and_isolate_databases.py --db <path/to/db> --confirm
ONE explicit target (no candidate loop); it must not be in use, and a verified pre_migration_ backup is
taken first (abort on failure). ``clean_database(path)`` without confirm refuses the live app database.
"""
import sys
import sqlite3
from pathlib import Path
from typing import List, Optional

# Force UTF-8 stdout/stderr on Windows
try:
    if sys.stdout and hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if sys.stderr and hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT_DIR = Path(__file__).resolve().parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.db_script_guard import add_target_arguments, guard_target, run_cli_action  # noqa: E402

SCRIPT_TAG = "clean_and_isolate_databases"

PRESERVED_TABLES = {
    "transport_locations",
    "countries",
    "cities",
    "customs_tariffs",
    "fee_codes",
    "preferential_agreements",
    "incoterms",
    "cost_items",
    "incoterm_responsibilities",
    "currencies",
    "exchange_rates",
    "users",
    "container_specs",
    "package_types",
    "units_of_measure",
    "clearance_expense_types",
    "external_service_providers",
    "alembic_version",
}


def clean_database(db_path: Path, *, confirm: bool = False, backups_dir: Optional[Path] = None) -> bool:
    """Wipe operational tables of ``db_path`` only.

    confirm=True: in-use check + verified backup first. confirm=False (e.g. a fresh bundle copy):
    raises UnsafeTargetError for the live app database or a database in use.
    """
    db_path = Path(db_path)
    if not db_path.exists():
        return False
    guard_target(db_path, confirm=confirm, tag=SCRIPT_TAG, backups_dir=backups_dir)
    print(f"\n=======================================================")
    print(f" [CLEAN] Wiping Operational & Demo Data in: {db_path.name}")
    print(f"=======================================================")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # Disable foreign keys temporarily for clean wipe
    cur.execute("PRAGMA foreign_keys = OFF;")

    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    all_tables = [row[0] for row in cur.fetchall()]

    wiped_count = 0
    for tbl in all_tables:
        if tbl not in PRESERVED_TABLES:
            try:
                cur.execute(f'DELETE FROM "{tbl}";')
                wiped_count += 1
            except Exception as e:
                print(f"   [WARN] Could not wipe table {tbl}: {e}")
            try:
                cur.execute(f'DELETE FROM sqlite_sequence WHERE name="{tbl}";')
            except Exception:
                pass

    conn.commit()
    cur.execute("PRAGMA foreign_keys = ON;")
    cur.execute("VACUUM;")
    conn.commit()

    print(f"   [OK] Wiped {wiped_count} operational tables to 0 records.")
    print(f"   [OK] Preserved {len(PRESERVED_TABLES)} master data tables intact.")

    # Integrity verification
    print("   --- Preserved Master Data Counts ---")
    for tbl in sorted(PRESERVED_TABLES):
        if tbl in all_tables:
            try:
                cur.execute(f'SELECT COUNT(*) FROM "{tbl}";')
                cnt = cur.fetchone()[0]
                print(f"   * {tbl:<30}: {cnt:>5} records")
            except Exception:
                pass

    conn.close()
    return True


def main(argv: Optional[List[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Wipe operational data of ONE database, keeping master tables.")
    add_target_arguments(parser, target_help="Database file to clean")
    args = parser.parse_args(argv)

    def _run(target: Path, backups_dir: Optional[Path]):
        print("\n===============================================================================")
        print("  [RULE] Mandatory Clean Production Database Enforcement")
        print("  All operational data wiped | Ports, HS Codes, Incoterms, Currencies Preserved")
        print("===============================================================================")
        clean_database(target, confirm=True, backups_dir=backups_dir)
        print(f"\n[SUCCESS] {target} cleansed strictly according to release rules!")
        return True

    return run_cli_action(args, _run)


if __name__ == "__main__":
    sys.exit(main())
