"""
Sorour Logistics ERP — UAT Staging Environment Manager
Creates, seeds, and resets an isolated UAT staging database (`sorour_logistics_uat.db`)
with 100% verified master data (Tariffs, Incoterms, Currencies, Users) and zero operational records.
Ensures zero pollution of production data during end-user acceptance testing.

Safety (update-system-plan A14/R12): the UAT file is ONE explicit --db; it can never be the source or the
live database. --reset overwrites an existing UAT file, so it needs --confirm, a target that is not in use,
and takes a verified pre_migration_ backup of the old UAT copy first.
    python scripts/prepare_uat_environment.py --init  --db sorour_logistics_uat.db
    python scripts/prepare_uat_environment.py --reset --db sorour_logistics_uat.db --confirm
"""
import os
import sys
import sqlite3
import argparse
from pathlib import Path
from typing import List, Optional

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from utils.db_safety import sqlite_online_backup  # noqa: E402
from scripts.db_script_guard import (  # noqa: E402
    UnsafeTargetError,
    add_target_arguments,
    guard_destructive_target,
    is_live_db,
    require_target,
    run_cli_action,
    run_guarded,
)

# Default read-only source, and the conventional UAT file name (pass it explicitly with --db).
PROD_DB = ROOT_DIR / "sorour_logistics.db"
UAT_DB = ROOT_DIR / "sorour_logistics_uat.db"


def _same_file(a: Path, b: Path) -> bool:
    return os.path.normcase(os.path.abspath(a)) == os.path.normcase(os.path.abspath(b))

# Master data tables to preserve during UAT seeding
MASTER_DATA_TABLES = {
    "users",
    "roles",
    "permissions",
    "role_permissions",
    "user_permissions",
    "customs_tariffs",
    "preferential_agreements",
    "fee_codes",
    "incoterms",
    "cost_items",
    "incoterm_responsibilities",
    "currencies",
    "exchange_rates",
    "transport_locations",
    "countries",
    "cities",
    "import_companies",
    "suppliers",
    "external_service_providers",
    "package_types",
    "units_of_measure",
    "clearance_expense_types",
    "demurrage_policies",
    "demurrage_rules",
    "port_demurrage_tariff",
    "projects",
    "expense_catalog",
    "container_specs",
    "step_configs",
    "guide_entries",
    "guide_entry_scopes",
    "alembic_version",
}


def create_uat_database(
    target_db: Optional[Path] = None,
    source_db: Optional[Path] = None,
    *,
    force: bool = False,
    confirm: bool = False,
    backups_dir: Optional[Path] = None,
) -> bool:
    """Clones master data from ``source_db`` (read-only) into ONE explicit UAT ``target_db`` and
    truncates its operational tables.

    The target may never be the source or the live app database (A14). Overwriting an existing target
    (``force``) requires ``confirm=True``, a target that is not in use, and a verified backup first.
    """
    source = Path(source_db) if source_db else PROD_DB
    target = require_target(target_db, must_exist=False)

    if not source.exists():
        print(f"[ERROR] Source database {source} not found.")
        return False
    if _same_file(target, source) or is_live_db(target):
        raise UnsafeTargetError(
            f"Refusing to use {target} as the UAT database: it is the source or the live database."
        )

    if target.exists() and not force:
        print(f"[INFO] UAT database {target.name} already exists. Use --reset to reinitialize.")
        return True
    if target.exists():
        # Reset: the old UAT copy is overwritten, so the full guard (in use + verified backup) applies.
        guard_destructive_target(target, confirm=confirm, tag="uat_reset", backups_dir=backups_dir, forbid=[source])

    print("================================================================================")
    print("      Sorour Logistics ERP — Preparing Isolated UAT Staging Database            ")
    print("================================================================================")
    print(f" [1/4] Cloning live schema and baseline from: {source.name} -> {target.name}...")
    # Online backup API: consistent copy of the (possibly open, WAL-mode) source; one transaction on target.
    sqlite_online_backup(source, target, overwrite=target.exists())

    # Belt and braces (A14): never run the DELETEs below against anything but the UAT copy.
    if _same_file(target, source) or is_live_db(target):
        raise UnsafeTargetError(f"UAT target {target} resolved to the source/live database; aborting.")

    conn = sqlite3.connect(target)
    cursor = conn.cursor()

    print(" [2/4] Truncating operational tables to ensure 0 mock contamination...")
    cursor.execute("PRAGMA foreign_keys = OFF;")
    existing_tables = [r[0] for r in cursor.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
    truncated_count = 0
    operational_tables = [t for t in existing_tables if t not in MASTER_DATA_TABLES and t != "sqlite_sequence"]
    for table in operational_tables:
        cursor.execute(f'DELETE FROM "{table}";')
        if "sqlite_sequence" in existing_tables:
            cursor.execute("DELETE FROM sqlite_sequence WHERE name = ?;", (table,))
        truncated_count += 1

    cursor.execute("PRAGMA foreign_keys = ON;")
    conn.commit()
    print(f"       Purged {truncated_count} operational tables cleanly.")

    print(" [3/4] Verifying Master Data record counts in UAT database...")
    counts_summary = {}
    for table in MASTER_DATA_TABLES:
        if table in existing_tables:
            count = cursor.execute(f'SELECT COUNT(*) FROM "{table}";').fetchone()[0]
            counts_summary[table] = count
            print(f"       • Table {table:<30}: {count} rows")

    print(" [4/4] Running SQLite integrity and foreign key validation...")
    integrity = cursor.execute("PRAGMA integrity_check;").fetchall()
    fk_check = cursor.execute("PRAGMA foreign_key_check;").fetchall()
    conn.close()

    if integrity != [('ok',)]:
        print(f"[ERROR] Integrity check failed: {integrity}")
        return False
    if fk_check:
        print(f"[WARN] Foreign key check reported violations: {fk_check}")

    print("================================================================================")
    print(f" [SUCCESS] UAT STAGING DATABASE READY: {target}")
    print(" - Zero operational shipments (0 records)")
    print(" - Full Egyptian Customs Tariffs & Incoterms preserved")
    print(f" - Zero risk to the source database ({source.name}): it is only read")
    print("================================================================================")
    return True


def reset_uat_database(
    target_db: Optional[Path] = None,
    source_db: Optional[Path] = None,
    *,
    confirm: bool = False,
    backups_dir: Optional[Path] = None,
) -> bool:
    """Resets the UAT database from a fresh master baseline (backs up the old UAT copy first)."""
    print("Resetting UAT database...")
    return create_uat_database(target_db, source_db, force=True, confirm=confirm, backups_dir=backups_dir)


def status_uat(uat_db: Optional[Path] = None):
    uat_path = Path(uat_db) if uat_db else UAT_DB
    if not uat_path.exists():
        print(f"[STATUS] UAT Database ({uat_path.name}) DOES NOT EXIST. Run `py scripts/prepare_uat_environment.py --init --db <uat.db>`")
        return False

    conn = sqlite3.connect(uat_path)
    cursor = conn.cursor()
    existing_tables = [r[0] for r in cursor.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]

    print("================================================================================")
    print("              Sorour Logistics ERP — UAT Environment Status                     ")
    print("================================================================================")
    print(f" File Location : {uat_path}")
    print(f" Size          : {uat_path.stat().st_size:,} bytes")
    print("--------------------------------------------------------------------------------")
    print(" Operational Tables (Must be 0 for clean testing):")
    clean = True
    operational_tables = [t for t in existing_tables if t not in MASTER_DATA_TABLES and t != "sqlite_sequence"]
    for t in operational_tables[:8]:
        if t in existing_tables:
            cnt = cursor.execute(f"SELECT COUNT(*) FROM {t};").fetchone()[0]
            status_str = "[CLEAN]" if cnt == 0 else f"[DATA PRESENT: {cnt}]"
            if cnt > 0:
                clean = False
            print(f"  {status_str:<20} {t:<30}: {cnt} rows")

    print("--------------------------------------------------------------------------------")
    print(" Master Data Tables (Baseline):")
    for t in ["users", "customs_tariffs", "incoterms", "currencies", "import_companies"]:
        if t in existing_tables:
            cnt = cursor.execute(f"SELECT COUNT(*) FROM {t};").fetchone()[0]
            print(f"  [SEEDED]             {t:<30}: {cnt} rows")

    conn.close()
    print("================================================================================")
    return clean


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Sorour Logistics ERP UAT Staging Manager")
    parser.add_argument("--init", action="store_true", help="Initialize the UAT database (--db) if it does not exist")
    parser.add_argument("--reset", action="store_true", help="Force reset the UAT database (--db) to a clean baseline")
    parser.add_argument("--status", action="store_true", help="Inspect UAT database row counts (read-only)")
    parser.add_argument("--source", default=None, help=f"Master-data source DB, only read (default: {PROD_DB.name})")
    add_target_arguments(parser, target_help="The UAT database file to create or reset")

    args = parser.parse_args(argv)
    source = Path(args.source) if args.source else None
    backups_dir = Path(args.backups_dir) if args.backups_dir else None

    if args.reset:
        def _reset(target: Path, _backups_dir: Optional[Path]):
            return reset_uat_database(target, source, confirm=True, backups_dir=_backups_dir)
        return run_cli_action(args, _reset, must_exist=False)
    if args.init:
        # Creating a brand-new UAT file destroys nothing; an existing file is left untouched.
        return run_guarded(lambda: create_uat_database(
            require_target(args.db, must_exist=False), source, force=False, backups_dir=backups_dir
        ))
    status_uat(Path(args.db) if args.db else None)
    return 0


if __name__ == "__main__":
    sys.exit(main())
