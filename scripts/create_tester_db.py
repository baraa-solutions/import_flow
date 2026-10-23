"""
Sorour Logistics ERP — Tester Database Builder
Copies an existing database into a NEW file and empties it for a tester, keeping only:

- Master data shown under "البيانات والجداول الأساسية": importing companies, foreign suppliers,
  partners / banks / service providers, ports and transport locations (with countries and cities),
  Incoterms (with cost items and the responsibility matrix), currencies and exchange rates.
- What the app needs to start and sign in: users, roles and permissions, the Alembic revision, system
  parameters, tax rates, step configuration, and fixed lookups (package types, units, container specs,
  clearance expense types, expense catalog).

Everything else is emptied, including projects / cost centres and the customs tariff (HS codes, fee codes,
preferential agreements). Tables not listed in KEEP_TABLES are emptied by default, so a new operational
table can never leak into a tester copy.

The source is only read (SQLite online backup, safe while the app runs). The output must be a new file.

    python scripts/create_tester_db.py --source sorour_logistics.db --out sorour_logistics_tester.db
"""
import argparse
import sqlite3
import sys
from pathlib import Path
from typing import Dict, List, Optional

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.db_script_guard import is_live_db, same_file_fail_closed  # noqa: E402
from utils.db_safety import sqlite_online_backup  # noqa: E402

MASTER_DATA_TABLES = {
    "import_companies",
    "suppliers",
    "external_service_providers",
    "transport_locations",
    "countries",
    "cities",
    "incoterms",
    "incoterm_responsibilities",
    "cost_items",
    "currencies",
    "exchange_rates",
}

SYSTEM_TABLES = {
    "alembic_version",
    "users",
    "roles",
    "permissions",
    "role_permissions",
    "user_permissions",
    "system_parameters",
    "tax_rates",
    "step_configs",
    "recalculation_dependency_map",
    "budget_variance_settings",
    "package_types",
    "units_of_measure",
    "container_specs",
    "clearance_expense_types",
    "expense_catalog",
}

KEEP_TABLES = MASTER_DATA_TABLES | SYSTEM_TABLES


def list_user_tables(conn: sqlite3.Connection) -> List[str]:
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    ).fetchall()
    return [row[0] for row in rows]


def count_rows(conn: sqlite3.Connection, table: str) -> int:
    return conn.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]


def empty_non_kept_tables(conn: sqlite3.Connection) -> Dict[str, int]:
    """Delete every row of every table outside KEEP_TABLES. Returns {table: rows_deleted}."""
    deleted: Dict[str, int] = {}
    conn.execute("PRAGMA foreign_keys = OFF")
    has_sequence = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'sqlite_sequence'"
    ).fetchone()
    for table in list_user_tables(conn):
        if table in KEEP_TABLES:
            continue
        rows = count_rows(conn, table)
        conn.execute(f'DELETE FROM "{table}"')
        if has_sequence:
            conn.execute("DELETE FROM sqlite_sequence WHERE name = ?", (table,))
        deleted[table] = rows
    conn.commit()
    return deleted


def dangling_references(conn: sqlite3.Connection) -> List[tuple]:
    """Rows in kept tables that still point at an emptied table."""
    return conn.execute("PRAGMA foreign_key_check").fetchall()


def build_tester_db(source: Path, out: Path) -> Dict[str, object]:
    if not source.exists():
        raise FileNotFoundError(f"Source database not found: {source}")
    if out.exists():
        raise FileExistsError(f"Output already exists, choose a new file: {out}")
    if same_file_fail_closed(source, out):
        raise ValueError("Output must be a different file from the source")
    if is_live_db(out):
        raise ValueError(f"Refusing to write to a live application database: {out}")

    sqlite_online_backup(source, out)

    conn = sqlite3.connect(out)
    try:
        deleted = empty_non_kept_tables(conn)
        kept = {t: count_rows(conn, t) for t in list_user_tables(conn) if t in KEEP_TABLES}
        dangling = dangling_references(conn)
        integrity = conn.execute("PRAGMA integrity_check").fetchone()[0]
    finally:
        conn.close()

    conn = sqlite3.connect(out)
    try:
        conn.execute("VACUUM")
    finally:
        conn.close()

    return {"deleted": deleted, "kept": kept, "dangling": dangling, "integrity": integrity}


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Create an emptied tester copy of a Sorour Logistics database")
    parser.add_argument("--source", required=True, help="Existing database to copy (read only)")
    parser.add_argument("--out", required=True, help="New database file to create")
    args = parser.parse_args(argv)

    try:
        result = build_tester_db(Path(args.source).resolve(), Path(args.out).resolve())
    except (FileNotFoundError, FileExistsError, ValueError) as error:
        print(f"[ERROR] {error}")
        return 1

    print("Kept tables:")
    for table, rows in sorted(result["kept"].items()):
        print(f"  {table}: {rows}")
    emptied = {t: n for t, n in result["deleted"].items() if n}
    print(f"Emptied {len(result['deleted'])} tables ({sum(emptied.values())} rows removed).")
    for table, rows in sorted(emptied.items()):
        print(f"  {table}: -{rows}")
    if result["dangling"]:
        print(f"[WARN] {len(result['dangling'])} kept row(s) still reference emptied tables:")
        for row in result["dangling"][:20]:
            print(f"  {row}")
    print(f"Integrity check: {result['integrity']}")
    print(f"[SUCCESS] Tester database created: {args.out}")
    return 0 if result["integrity"] == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
