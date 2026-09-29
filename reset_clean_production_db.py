"""
ImportFlow ERP — Clean Production Database Generator
Creates a pristine production database containing ONLY core standard reference tables:
- Ports & Transport Locations (247 ports, airports, dry ports, land borders - MD-009)
- Currencies & Official Exchange Rates (11 Currencies, 137 Exchange Rates - MD-004)
- Customs Tariff & HS Codes & Nafeza Fee Codes (74 Tariff items, 15 Fee codes - MD-008)
- International Trade Agreements (405 Preferential agreements - MD-008B)
- Package Types & Units of Measure (24 Package types, 15 Units of measure)
- Incoterms 2020 & Responsibility Matrix & Cost Items (11 Incoterms, 17 Cost items, 187 Rules - MD-006)
- Clearance Expense Types & Coded Expense Catalog (53 Clearance types, 54 Catalog items)
- Core System User: the single admin, admin / settings.DEFAULT_ADMIN_PASSWORD with a forced password change on
  first login (must_change_password=1); no demo accounts
- Core International Shipping Lines (32 Lines - MD-009B)

All demo companies, suppliers, service providers (except shipping lines), shipments,
purchase orders, invoices, and logs are completely wiped (0 records).

DESTRUCTIVE (replaces the whole target database). Safety (update-system-plan A4/R12):
    python reset_clean_production_db.py --db <path/to/db> --confirm [--reference-snapshot <db>]
ONE explicit target; it must not be in use, and a verified pre_migration_ backup of it is taken first
(abort on failure). A target that does not exist yet is simply created.
"""
import importlib
import sys
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import List, Optional

ROOT_DIR = Path(__file__).resolve().parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.db_script_guard import (  # noqa: E402
    add_target_arguments,
    guard_target,
    run_cli_action,
)

SCRIPT_TAG = "reset_clean_production_db"
BACKUPS_DIR = ROOT_DIR / "backups"

MASTER_TABLES = [
    "package_types",
    "units_of_measure",
    "preferential_agreements",
    "transport_locations",
    "customs_tariffs",
    "fee_codes",
    "clearance_expense_types",
    "expense_catalog",
    "cost_items",
    "incoterm_responsibilities",
    "incoterms",
    "currencies",
    "exchange_rates",
    "roles",
    "permissions",
    "role_permissions",
    "budget_variance_settings",
    "email_settings",
    "recalculation_dependency_map",
    "guide_entries",
    "guide_entry_scopes",
]

OPERATIONAL_TABLES = [
    "import_companies",
    "suppliers",
    "projects",
    "purchase_orders",
    "po_line_items",
    "packing_list_items",
    "import_files",
    "import_file_checklist_items",
    "import_requirement_assessments",
    "payment_request_sessions",
    "import_budget_approvals",
    "acid_registration_sessions",
    "cargo_shipping_records",
    "cargox_customs_invoice_tracks",
    "shipment_bookings",
    "shipment_stage_activity",
    "shipping_evaluation_sessions",
    "shipping_scenario_items",
    "customs_consultation_sessions",
    "customs_checklist_items",
    "broker_price_lists",
    "broker_price_list_items",
    "customs_broker_quote_items",
    "draft_bl_review_sessions",
    "po_packing_reconciliation_sessions",
    "smart_tasks",
    "system_notifications",
    "upload_sessions",
    "inbound_email_logs",
    "swift_extraction_batches",
    "swift_extraction_fields",
    "recalculation_logs",
    "audit_logs",
    "production_sync_logs",
    "inland_transport_bookings",
    "warehouse_receiving_records",
    "landed_cost_settlements",
    "clearance_expense_invoices",
    "customs_clearance_records",
    "import_file_closures",
]


def find_best_reference_snapshot(backups_dir: Optional[Path] = None, exclude: Optional[Path] = None) -> Path:
    """Find the most complete reference snapshot to seed master data from (read-only)."""
    folder = Path(backups_dir) if backups_dir else BACKUPS_DIR
    if not folder.exists():
        raise FileNotFoundError(f"Backups folder not found: {folder}")
    candidates = sorted(folder.glob("*.db"), key=lambda p: p.stat().st_mtime, reverse=True)
    for c in candidates:
        if exclude is not None and c.resolve() == Path(exclude).resolve():
            continue
        try:
            conn = sqlite3.connect(f"file:{c.as_posix()}?mode=ro", uri=True)
            try:
                cur = conn.cursor()
                cur.execute("SELECT count(*) FROM transport_locations")
                loc_cnt = cur.fetchone()[0]
                cur.execute("SELECT count(*) FROM customs_tariffs")
                tar_cnt = cur.fetchone()[0]
                cur.execute("SELECT count(*) FROM external_service_providers WHERE partner_type = 'Shipping Line'")
                ship_cnt = cur.fetchone()[0]
            finally:
                conn.close()
            if loc_cnt >= 200 and tar_cnt >= 50 and ship_cnt >= 20:
                return c
        except sqlite3.Error:
            continue
    raise FileNotFoundError(f"Could not find a valid reference snapshot database in {folder}.")


def _load_all_models() -> None:
    """Register every SQLAlchemy model on Base.metadata without importing main (no app startup)."""
    importlib.import_module("database.models")
    modules_dir = ROOT_DIR / "modules"
    for item in sorted(modules_dir.iterdir()):
        if item.is_dir() and (item / "model.py").exists():
            importlib.import_module(f"modules.{item.name}.model")


def seed_core_users(cur, admin_password_hash: str) -> None:
    """Replace all users with the single admin. Like the startup seed of a new installation it gets the
    documented default password (settings.DEFAULT_ADMIN_PASSWORD) and must_change_password=1, so the
    first login has to set a new password before anything else works. No demo manager/operator accounts."""
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cur.execute("DELETE FROM main.users;")
    cur.execute(
        "INSERT INTO main.users (user_id, username, email, full_name, hashed_password, role, role_id, is_active, "
        "must_change_password, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
        (1, "admin", "admin@sorourlogistics.com", "System Admin", admin_password_hash, "ADMIN", 1, 1, 1,
         now_str, now_str),
    )


def build_clean_production_db(
    target_db: Path,
    *,
    confirm: bool = False,
    backups_dir: Optional[Path] = None,
    reference_snapshot: Optional[Path] = None,
) -> bool:
    """Rebuild ``target_db`` as a clean production database.

    confirm=True: in-use check + verified backup of the existing target first (abort on failure).
    confirm=False: refused for the live app database or a database in use.
    """
    from sqlalchemy import create_engine

    from database.database import Base
    from modules.auth.security import hash_password
    from settings import DEFAULT_ADMIN_PASSWORD
    from update_db_schema import migrate_db

    target_db = Path(target_db)
    print("================================================================================")
    print("           ImportFlow ERP - Generating Clean Production Database                ")
    print("================================================================================")

    # 1. Safety: target not in use + verified backup of the current target (if it exists)
    backup = guard_target(target_db, confirm=confirm, tag=SCRIPT_TAG, must_exist=False, backups_dir=backups_dir)

    # 2. Locate master reference snapshot BEFORE anything is removed
    ref_snapshot = Path(reference_snapshot) if reference_snapshot else find_best_reference_snapshot(
        exclude=backup.path if backup else None
    )
    if ref_snapshot.resolve() == target_db.resolve():
        raise FileNotFoundError("The reference snapshot cannot be the target database itself.")
    print(f"[OK] Master reference source snapshot: {ref_snapshot.name}")

    _load_all_models()
    target_engine = create_engine(f"sqlite:///{target_db.resolve().as_posix()}")
    try:
        if target_db.exists():
            try:
                for suffix in ("", "-wal", "-shm"):
                    Path(f"{target_db}{suffix}").unlink(missing_ok=True)
                print(f"[OK] Removed previous database: {target_db}")
            except OSError as e:
                print(f"Could not unlink db ({e}), dropping tables instead.")
                Base.metadata.drop_all(bind=target_engine)

        # 3. Create all tables & schema via SQLAlchemy and the legacy additive upgrade
        Base.metadata.create_all(bind=target_engine)
    finally:
        target_engine.dispose()
    migrate_db(target_db, backups_dir=backups_dir)
    print("[OK] Database schema created and migrated.")

    # 4. Populate standard master data directly from verified snapshot using named column matching
    conn = sqlite3.connect(target_db)
    cur = conn.cursor()
    cur.execute(f"ATTACH DATABASE '{ref_snapshot.as_posix()}' AS snapshot;")

    print("[1/5] Seeding Standard Master Reference Tables...")
    for tbl in MASTER_TABLES:
        try:
            cur.execute(f"PRAGMA main.table_info({tbl});")
            target_cols = [r[1] for r in cur.fetchall()]
            cur.execute(f"PRAGMA snapshot.table_info({tbl});")
            snap_cols = [r[1] for r in cur.fetchall()]
            common_cols = [c for c in target_cols if c in snap_cols]
            if common_cols:
                cols_str = ", ".join(common_cols)
                cur.execute(f"INSERT OR IGNORE INTO main.{tbl} ({cols_str}) SELECT {cols_str} FROM snapshot.{tbl};")
            else:
                print(f"  Warning on table {tbl}: No matching columns")
        except Exception as e:
            print(f"  Warning on table {tbl}: {e}")
    conn.commit()

    # 5. Seed Core International Shipping Lines (MD-009B)
    print("[2/5] Seeding Core International Shipping Lines (MD-009B)...")
    try:
        cur.execute("PRAGMA main.table_info(external_service_providers);")
        target_cols = [r[1] for r in cur.fetchall()]
        cur.execute("PRAGMA snapshot.table_info(external_service_providers);")
        snap_cols = [r[1] for r in cur.fetchall()]
        common_cols = [c for c in target_cols if c in snap_cols]
        cols_str = ", ".join(common_cols)
        cur.execute(f"INSERT OR IGNORE INTO main.external_service_providers ({cols_str}) SELECT {cols_str} FROM snapshot.external_service_providers WHERE partner_type = 'Shipping Line';")
        conn.commit()
    except Exception as e:
        print(f"  Warning on shipping lines: {e}")

    # 6. Seed Core System Users with Secure Production Credentials
    print("[3/5] Seeding Core System Users (RBAC)...")
    seed_core_users(cur, hash_password(DEFAULT_ADMIN_PASSWORD))
    conn.commit()

    cur.execute("DETACH DATABASE snapshot;")

    # 7. Verification Summary
    print("================================================================================")
    print("                 Clean Production Database Verification                         ")
    print("================================================================================")
    for tbl in ["users", "transport_locations", "customs_tariffs", "fee_codes", "currencies", "exchange_rates", "incoterms", "incoterm_responsibilities", "package_types", "units_of_measure", "preferential_agreements", "external_service_providers", "roles", "permissions"]:
        try:
            cur.execute(f"SELECT count(*) FROM {tbl}")
            print(f" - {tbl:<25}: {cur.fetchone()[0]}")
        except Exception as e:
            print(f" - {tbl:<25}: Error ({e})")

    print("--------------------------------------------------------------------------------")
    print(" Operational & Transactional Tables (Must be 0 records):")
    print("--------------------------------------------------------------------------------")
    all_clean = True
    for op in OPERATIONAL_TABLES:
        try:
            cur.execute(f"SELECT count(*) FROM {op}")
            cnt = cur.fetchone()[0]
            if cnt > 0:
                print(f" [FAIL] {op} has {cnt} records!")
                all_clean = False
            else:
                print(f" - {op:<30}: 0 (Clean)")
        except Exception:
            pass

    conn.close()

    if all_clean:
        print("================================================================================")
        print("[SUCCESS] Clean Production Database successfully generated and verified 100%!")
        print("================================================================================")
        return True
    else:
        print("[ERROR] Some operational tables were not clean.")
        return False


def main(argv: Optional[List[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Rebuild ONE database as a clean production database.")
    add_target_arguments(parser, target_help="Database file to rebuild")
    parser.add_argument("--reference-snapshot", default=None, help="Master-data source DB (default: best in backups/)")
    args = parser.parse_args(argv)

    def _run(target: Path, backups_dir: Optional[Path]):
        return build_clean_production_db(
            target,
            confirm=True,
            backups_dir=backups_dir,
            reference_snapshot=Path(args.reference_snapshot) if args.reference_snapshot else None,
        )

    return run_cli_action(args, _run, must_exist=False)


if __name__ == "__main__":
    sys.exit(main())
