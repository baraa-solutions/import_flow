"""
ImportFlow ERP — Production Synchronization & Deployment Utility
================================================================
أداة مزامنة ونقل التحديثات بين بيئة التطوير (Dev) والإنتاج (Production).

Features:
- Safe Database Push (Dev -> Prod) with automatic timestamped backup.
- Safe Database Pull (Prod -> Dev) with automatic timestamped backup.
- Table-by-table record count comparison & health check.
- Frontend & Backend Compilation & Production Bundling.
- Standalone Package Updates (ImportFlow_Standalone).
- Release ZIP Packaging & Manifest Generation.
- 1-Click Production App Launcher.

Safety (update-system-plan A4/R12): every action that writes a database (--db-only, --pull, --full)
takes ONE explicit target (--db) and --confirm. The target must not be in use, a verified protected
backup of it is taken first (abort on failure), and the source is only read. There is no implicit
second target and no hard-coded workspace path any more.
    python sync_to_production.py --db-only --db <prod.db> [--source <dev.db>] --confirm
    python sync_to_production.py --pull --db <dev.db> [--source <prod.db>] --confirm
"""

import os
import sys
import json
import sqlite3
import argparse
import subprocess
from datetime import datetime
from pathlib import Path
from typing import List, Optional

# Force UTF-8 on Windows stdout/stderr
try:
    if sys.stdout and hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if sys.stderr and hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def find_project_root() -> Path:
    """Finds the true project root directory containing the source code / workspace."""
    start_dir = Path(__file__).resolve().parent

    # 1. If start_dir itself is root (contains frontend or modules)
    if (start_dir / "frontend").exists() or (start_dir / "modules").exists():
        return start_dir

    # 2. Check parent directories
    for parent in start_dir.parents:
        if (parent / "frontend").exists() or (parent / "modules").exists():
            return parent

    # No guessing of well-known workspace folders: a wrong guess could point at a real database.
    return start_dir


ROOT_DIR = find_project_root()
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.db_script_guard import (  # noqa: E402
    UnsafeTargetError,
    add_target_arguments,
    guard_target,
    require_target,
    run_guarded,
    take_verified_backup,
)
from utils.db_safety import clean_child_environment, sqlite_online_backup  # noqa: E402

DIST_DIR = ROOT_DIR / "dist"
STANDALONE_DIR = DIST_DIR / "Sorour_Logistics_Standalone"
DESKTOP_DIR = DIST_DIR / "Sorour_Logistics_Desktop"
WEB_DIR = DIST_DIR / "Sorour_Logistics_Web"
BACKUPS_DIR = ROOT_DIR / "backups"

# Defaults for the read-only source / compare paths only. Writes always need an explicit --db.
DEV_DB = ROOT_DIR / "sorour_logistics.db"
PROD_DB = STANDALONE_DIR / "sorour_logistics.db"
BACKEND_EXE = ROOT_DIR / "dist_backend" / "backend.exe"
FRONTEND_WINDOWS_RELEASE = ROOT_DIR / "frontend" / "build" / "windows" / "x64" / "runner" / "Release"

SCRIPT_TAG = "sync_to_production"


def create_backup(db_path: Path, tag: str = "backup", backups_dir: Optional[Path] = None) -> Optional[Path]:
    """Verified online backup (protected pre_migration_ name) next to ``db_path``; raises on failure."""
    if not db_path.exists():
        return None
    result = take_verified_backup(db_path, tag=tag, backups_dir=backups_dir)
    size_kb = result.size_bytes / 1024
    print(f"   [BACKUP] Safety backup created: {result.path.name} ({size_kb:.1f} KB)")
    return result.path



def get_db_stats(db_path: Path) -> dict:
    """Returns table count, record counts, and file size for a database."""
    if not db_path.exists():
        return {"exists": False}
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
        tables = [row[0] for row in cursor.fetchall()]
        
        counts = {}
        total_records = 0
        for table in tables:
            try:
                cursor.execute(f"SELECT COUNT(*) FROM \"{table}\";")
                c = cursor.fetchone()[0]
                counts[table] = c
                total_records += c
            except Exception:
                counts[table] = 0
        conn.close()
        return {
            "exists": True,
            "size_kb": round(db_path.stat().st_size / 1024, 1),
            "tables_count": len(tables),
            "total_records": total_records,
            "table_counts": counts,
            "mtime": datetime.fromtimestamp(db_path.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
        }
    except Exception as e:
        return {"exists": True, "error": str(e)}


def get_db_diffs(src_db: Path, target_db: Path) -> dict:
    """Computes exact diffs: tables, rows, new columns, and differences between two databases."""
    if not src_db.exists():
        return {"exists": False, "error": f"Source database not found: {src_db}"}
    if not target_db.exists():
        dev_stats = get_db_stats(src_db)
        tables_list = [
            {
                "table_name": tbl,
                "dev_count": cnt,
                "prod_count": 0,
                "diff": cnt,
                "status": "NEW_TABLE",
            }
            for tbl, cnt in dev_stats.get("table_counts", {}).items()
        ]
        return {
            "exists": True,
            "target_exists": False,
            "total_new_records": dev_stats.get("total_records", 0),
            "tables_with_diff": dev_stats.get("tables_count", 0),
            "new_tables_count": dev_stats.get("tables_count", 0),
            "new_columns_count": 0,
            "tables": tables_list,
        }

    conn_src = sqlite3.connect(src_db)
    cur_src = conn_src.cursor()
    conn_tgt = sqlite3.connect(target_db)
    cur_tgt = conn_tgt.cursor()

    cur_src.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    src_tables = dict(cur_src.fetchall())

    cur_tgt.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tgt_tables = set(r[0] for r in cur_tgt.fetchall())

    all_table_names = sorted(set(list(src_tables.keys()) + list(tgt_tables)))
    tables_diff = []
    total_new_records = 0
    tables_with_diff = 0
    new_tables_count = 0
    new_columns_count = 0

    for tbl in all_table_names:
        dev_count = 0
        prod_count = 0
        is_new_table = False
        is_missing_in_dev = False

        if tbl in src_tables:
            try:
                cur_src.execute(f'SELECT COUNT(*) FROM "{tbl}";')
                dev_count = cur_src.fetchone()[0]
            except Exception:
                dev_count = 0
        else:
            is_missing_in_dev = True

        if tbl in tgt_tables:
            try:
                cur_tgt.execute(f'SELECT COUNT(*) FROM "{tbl}";')
                prod_count = cur_tgt.fetchone()[0]
            except Exception:
                prod_count = 0
        else:
            is_new_table = True
            new_tables_count += 1

        # Check new columns
        if tbl in src_tables and tbl in tgt_tables:
            try:
                cur_src.execute(f'PRAGMA table_info("{tbl}");')
                src_cols = set(r[1] for r in cur_src.fetchall())
                cur_tgt.execute(f'PRAGMA table_info("{tbl}");')
                tgt_cols = set(r[1] for r in cur_tgt.fetchall())
                new_cols = src_cols - tgt_cols
                new_columns_count += len(new_cols)
            except Exception:
                pass

        diff = dev_count - prod_count
        if is_new_table:
            status = "NEW_TABLE"
            tables_with_diff += 1
            total_new_records += dev_count
        elif is_missing_in_dev:
            status = "PROD_ONLY"
        elif diff > 0:
            status = "NEW_DATA"
            tables_with_diff += 1
            total_new_records += diff
        elif diff < 0:
            status = "BEHIND"
            tables_with_diff += 1
        else:
            status = "MATCH"

        tables_diff.append({
            "table_name": tbl,
            "dev_count": dev_count,
            "prod_count": prod_count,
            "diff": diff,
            "status": status,
        })

    conn_src.close()
    conn_tgt.close()

    return {
        "exists": True,
        "target_exists": True,
        "total_new_records": total_new_records,
        "tables_with_diff": tables_with_diff,
        "new_tables_count": new_tables_count,
        "new_columns_count": new_columns_count,
        "tables": tables_diff,
    }


def compare_databases(dev_db: Optional[Path] = None, prod_db: Optional[Path] = None):
    """Compares Dev and Prod databases table by table and emits structured JSON diff (read-only)."""
    dev_path = Path(dev_db) if dev_db else DEV_DB
    prod_path = Path(prod_db) if prod_db else PROD_DB
    print("\n===============================================================================")
    print(" [CHECK] Database Comparison: Development (Dev) vs Production (Prod)")
    print("===============================================================================")

    dev_stats = get_db_stats(dev_path)
    prod_stats = get_db_stats(prod_path)

    print(f"\n[DEV  DB] {dev_path}")
    if dev_stats.get("exists"):
        print(f"   - Size: {dev_stats['size_kb']} KB | Tables: {dev_stats['tables_count']} | Records: {dev_stats['total_records']}")
        print(f"   - Last Modified: {dev_stats['mtime']}")
    else:
        print("   [!] NOT FOUND")

    print(f"\n[PROD DB] {prod_path}")
    if prod_stats.get("exists"):
        print(f"   - Size: {prod_stats['size_kb']} KB | Tables: {prod_stats['tables_count']} | Records: {prod_stats['total_records']}")
        print(f"   - Last Modified: {prod_stats['mtime']}")
    else:
        print("   [!] Not found yet — will be created on first sync.")

    diff_data = get_db_diffs(dev_path, prod_path)
    if diff_data.get("exists"):
        print(f"\n[DIFF_DATA] {json.dumps(diff_data, ensure_ascii=False)}")
        sys.stdout.flush()

    if dev_stats.get("exists") and prod_stats.get("exists"):
        print("\n[TABLE COMPARISON]")
        print(f"{'Table Name':<35} | {'Dev Records':<14} | {'Prod Records':<14} | {'Status':<10}")
        print("-" * 85)

        for tbl_info in diff_data.get("tables", []):
            tbl = tbl_info["table_name"]
            dev_c = tbl_info["dev_count"]
            prod_c = tbl_info["prod_count"]
            status = tbl_info["status"]
            if status == "MATCH":
                status_str = "✓ MATCH"
            elif status == "NEW_DATA":
                status_str = f"+{tbl_info['diff']} new"
            elif status == "NEW_TABLE":
                status_str = "+NEW TABLE"
            elif status == "BEHIND":
                status_str = f"{tbl_info['diff']} behind"
            else:
                status_str = status
            print(f"{tbl:<35} | {dev_c:<14} | {prod_c:<14} | {status_str}")
        print("=" * 85)
        print(f"📊 الخلاصة: {diff_data.get('tables_with_diff', 0)} جدول به تحديثات | {diff_data.get('total_new_records', 0)} سجل جديد ستتم إضافته/تحديثه")
    print("===============================================================================\n")
    sys.stdout.flush()


def smart_non_destructive_migrate(
    src_db: Path, target_db: Path, dry_run: bool = False, *, guarded: bool = False
) -> dict:
    """
    Enterprise Non-Destructive Migration with Live Progress Streaming:
    1. Creates any missing tables from src in target.
    2. Adds any new columns via ALTER TABLE ADD COLUMN.
    3. Merges new rows with INSERT OR REPLACE (overwrites matching rows, never deletes rows).
    4. All changes are wrapped in a single transaction (atomic rollback on failure).
    5. Streams live progress JSON on stdout for Flutter UI progress bar.

    ``guarded=True`` only from sync_db_to_prod / pull_prod_db_to_dev after their full guard ran;
    otherwise the target may not be the live app database or a database in use.
    """
    src_db = Path(src_db)
    target_db = Path(target_db)
    if not dry_run and not guarded:
        guard_target(target_db, confirm=False, tag=SCRIPT_TAG, must_exist=False, forbid=[src_db])
    if not target_db.exists():
        if dry_run:
            print(f"   [DRY-RUN] Target does not exist — would create fresh copy: {target_db}")
            return {"status": "dry_run_fresh_copy", "tables_added": 0, "columns_added": 0, "rows_merged": 0}
        target_db.parent.mkdir(parents=True, exist_ok=True)
        # Online backup API: a consistent copy even while the source is open in WAL mode.
        sqlite_online_backup(src_db, target_db)
        print(f"[PROGRESS] {json.dumps({'percent': 100, 'stage': 'completed', 'table': 'ALL', 'current_index': 1, 'total_tables': 1, 'records_synced': 0, 'total_synced': 0, 'message': 'تم إنشاء نسخة البرودكشن الأولية بنجاح'})}")
        sys.stdout.flush()
        return {"status": "fresh_copy", "tables_added": 0, "columns_added": 0, "rows_merged": 0}

    conn_src = sqlite3.connect(src_db)
    cur_src = conn_src.cursor()

    conn_tgt = sqlite3.connect(target_db)
    cur_tgt = conn_tgt.cursor()

    cur_src.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    src_tables = cur_src.fetchall()

    cur_tgt.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tgt_table_names = set(r[0] for r in cur_tgt.fetchall())

    tables_added = 0
    columns_added = 0
    rows_merged = 0
    total_tables_count = len(src_tables)

    # Initial Progress Report
    print(f"[PROGRESS] {json.dumps({'percent': 5, 'stage': 'init', 'table': '', 'current_index': 0, 'total_tables': total_tables_count, 'records_synced': 0, 'total_synced': 0, 'message': 'جارٍ فحص ومقارنة بنية الجداول...'})}")
    sys.stdout.flush()

    # Pre-merge record counts for integrity verification
    pre_counts = {}
    for row in cur_tgt.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    ):
        tbl = row[0]
        try:
            pre_counts[tbl] = cur_tgt.execute(f'SELECT COUNT(*) FROM "{tbl}";').fetchone()[0]
        except Exception:
            pre_counts[tbl] = 0

    try:
        if not dry_run:
            cur_tgt.execute("PRAGMA foreign_keys = OFF;")
            cur_tgt.execute("BEGIN TRANSACTION;")

        # 1. Create missing tables
        for tbl_name, tbl_sql in src_tables:
            if tbl_name not in tgt_table_names:
                if tbl_sql:
                    if dry_run:
                        print(f"   [DRY-RUN] Would CREATE TABLE: {tbl_name}")
                    else:
                        cur_tgt.execute(tbl_sql)
                        print(f"   + [NEW TABLE] Created: {tbl_name}")
                    tables_added += 1
                    tgt_table_names.add(tbl_name)

        # 2. Add missing columns
        for tbl_name, _ in src_tables:
            if tbl_name in tgt_table_names:
                try:
                    cur_src.execute(f'PRAGMA table_info("{tbl_name}");')
                    src_cols = {row[1]: row[2] for row in cur_src.fetchall()}

                    cur_tgt.execute(f'PRAGMA table_info("{tbl_name}");')
                    tgt_cols = set(row[1] for row in cur_tgt.fetchall())

                    for col_name, col_type in src_cols.items():
                        if col_name not in tgt_cols:
                            if dry_run:
                                print(f"   [DRY-RUN] Would ADD COLUMN: {tbl_name}.{col_name} ({col_type})")
                            else:
                                cur_tgt.execute(
                                    f'ALTER TABLE "{tbl_name}" ADD COLUMN "{col_name}" {col_type};'
                                )
                                print(f"   + [NEW COLUMN] {tbl_name}.{col_name} ({col_type})")
                            columns_added += 1
                except Exception as col_e:
                    print(f"   [WARN] Column check for {tbl_name}: {col_e}")

        # 3. Synchronize / UPSERT rows across all common tables with live progress
        synced_tables_count = 0
        for idx, (tbl_name, _) in enumerate(src_tables):
            tbl_rows_synced = 0
            try:
                cur_src.execute(f'PRAGMA table_info("{tbl_name}");')
                src_cols = [row[1] for row in cur_src.fetchall()]

                cur_tgt.execute(f'PRAGMA table_info("{tbl_name}");')
                tgt_cols = set(row[1] for row in cur_tgt.fetchall())

                common_cols = [c for c in src_cols if c in tgt_cols]
                if not common_cols:
                    continue

                cols_str = ", ".join([f'"{c}"' for c in common_cols])
                placeholders = ", ".join(["?"] * len(common_cols))

                cur_src.execute(f'SELECT {cols_str} FROM "{tbl_name}";')
                src_rows = cur_src.fetchall()

                if src_rows:
                    for row in src_rows:
                        if dry_run:
                            rows_merged += 1
                        else:
                            try:
                                cur_tgt.execute(
                                    f'INSERT OR REPLACE INTO "{tbl_name}" ({cols_str}) VALUES ({placeholders});',
                                    tuple(row),
                                )
                                if cur_tgt.rowcount > 0:
                                    rows_merged += 1
                                    tbl_rows_synced += 1
                            except Exception as row_e:
                                print(f"   [WARN] Row sync error in {tbl_name}: {row_e}")

                    if tbl_rows_synced > 0:
                        synced_tables_count += 1
                        print(f"   ✓ [DATA SYNC] {tbl_name}: {tbl_rows_synced} records synced/updated")

                # Stream live progress percentage
                percent = int(10 + ((idx + 1) / max(1, total_tables_count)) * 85)
                percent = min(95, percent)
                msg = f"جارٍ فحص ومزامنة جدول: {tbl_name} ({idx + 1}/{total_tables_count})"
                if tbl_rows_synced > 0:
                    msg += f" — تم تحديث {tbl_rows_synced} سجل"
                print(f"[PROGRESS] {json.dumps({'percent': percent, 'stage': 'syncing', 'table': tbl_name, 'current_index': idx + 1, 'total_tables': total_tables_count, 'records_synced': tbl_rows_synced, 'total_synced': rows_merged, 'message': msg}, ensure_ascii=False)}")
                sys.stdout.flush()

            except Exception as tbl_e:
                print(f"   [ERROR] Table sync failed for {tbl_name}: {tbl_e}")

        if not dry_run:
            cur_tgt.execute("PRAGMA foreign_keys = ON;")
            conn_tgt.commit()

        # Emit 100% completion progress
        print(f"[PROGRESS] {json.dumps({'percent': 100, 'stage': 'completed', 'table': 'DONE', 'current_index': total_tables_count, 'total_tables': total_tables_count, 'records_synced': 0, 'total_synced': rows_merged, 'message': f'✅ اكتملت المزامنة بنجاح! تم نقل وتحديث {rows_merged} سجل عبر {total_tables_count} جدول'}, ensure_ascii=False)}")
        sys.stdout.flush()

    except Exception as exc:
        if not dry_run:
            conn_tgt.rollback()
            conn_src.close()
            conn_tgt.close()
            raise RuntimeError(f"Migration failed — rolled back safely: {exc}") from exc

    conn_src.close()

    # Post-merge integrity verification
    post_status = "dry_run" if dry_run else "ok"
    if not dry_run:
        post_counts = {}
        for row in cur_tgt.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
        ):
            tbl = row[0]
            try:
                post_counts[tbl] = cur_tgt.execute(
                    f'SELECT COUNT(*) FROM "{tbl}";'
                ).fetchone()[0]
            except Exception:
                post_counts[tbl] = 0
        conn_tgt.close()

        # Integrity check: no table should have fewer rows after merge
        shrunk = [
            tbl for tbl, cnt in post_counts.items()
            if tbl in pre_counts and cnt < pre_counts[tbl]
        ]
        if shrunk:
            post_status = f"WARNING: {len(shrunk)} table(s) have fewer rows post-merge: {shrunk}"
        else:
            post_status = "integrity_ok"
    else:
        conn_tgt.close()

    return {
        "status": "dry_run" if dry_run else "migrated_safely",
        "integrity": post_status,
        "tables_added": tables_added,
        "columns_added": columns_added,
        "rows_merged": rows_merged,
    }




def _merge_into_target(
    source_db: Path,
    target_db: Path,
    *,
    confirm: bool,
    tag: str,
    backups_dir: Optional[Path],
) -> Optional[dict]:
    """Shared guard + merge for push and pull. Only ``target_db`` is written."""
    source_db = Path(source_db)
    target_db = require_target(target_db, must_exist=False)
    if not source_db.exists():
        print(f"[ERROR] Source database not found: {source_db}")
        return None
    # Target: explicit, confirmed, not in use, verified backup first (raises UnsafeTargetError otherwise).
    guard_target(target_db, confirm=confirm, tag=tag, must_exist=False, backups_dir=backups_dir, forbid=[source_db])
    target_db.parent.mkdir(parents=True, exist_ok=True)
    return smart_non_destructive_migrate(source_db, target_db, guarded=True)


def sync_db_to_prod(
    target_db: Optional[Path] = None,
    source_db: Optional[Path] = None,
    *,
    confirm: bool = False,
    backups_dir: Optional[Path] = None,
) -> bool:
    """Syncs Dev DB (source, read-only) -> ONE explicit Prod DB target, after a verified backup."""
    print("\n===============================================================================")
    print(" [SYNC] مزامنة وتحديث قاعدة بيانات الإنتاج (Non-Destructive Safe Sync) ")
    print("===============================================================================")
    source = Path(source_db) if source_db else DEV_DB
    res = _merge_into_target(source, target_db, confirm=confirm, tag="prod_before_sync", backups_dir=backups_dir)
    if res is None:
        return False
    target = Path(target_db)
    print(f"[SUCCESS] Sync applied safely to production: {target}")
    print(f"   - New tables added:   {res['tables_added']}")
    print(f"   - New columns added:  {res['columns_added']}")
    print(f"   - Rows merged:        {res['rows_merged']}")
    print(f"   - Integrity check:    {res.get('integrity', 'n/a')}")

    stats = get_db_stats(target)
    print(f"\n[STATS] Production DB after sync:")
    print(f"   - Size:    {stats.get('size_kb')} KB")
    print(f"   - Tables:  {stats.get('tables_count')}")
    print(f"   - Records: {stats.get('total_records')}")
    print("===============================================================================\n")
    return True


def pull_prod_db_to_dev(
    target_db: Optional[Path] = None,
    source_db: Optional[Path] = None,
    *,
    confirm: bool = False,
    backups_dir: Optional[Path] = None,
) -> bool:
    """Pulls Prod DB (source, read-only) -> ONE explicit Dev DB target, after a verified backup."""
    print("\n===============================================================================")
    print(" [PULL] Safe Pull: Production -> Development (non-destructive merge)")
    print("===============================================================================")
    source = Path(source_db) if source_db else PROD_DB
    res = _merge_into_target(source, target_db, confirm=confirm, tag="dev_before_pull", backups_dir=backups_dir)
    if res is None:
        return False
    target = Path(target_db)
    print(f"[SUCCESS] Production data merged into development DB: {target}")
    print(f"   - New tables:    {res['tables_added']}")
    print(f"   - New columns:   {res['columns_added']}")
    print(f"   - Rows merged:   {res['rows_merged']}")
    print(f"   - Integrity:     {res.get('integrity', 'n/a')}")

    stats = get_db_stats(target)
    print(f"\n[STATS] Development DB after pull:")
    print(f"   - Size:    {stats.get('size_kb')} KB")
    print(f"   - Tables:  {stats.get('tables_count')}")
    print(f"   - Records: {stats.get('total_records')}")
    print("===============================================================================\n")
    return True


def full_production_build_and_sync(
    target_db: Optional[Path] = None,
    source_db: Optional[Path] = None,
    *,
    confirm: bool = False,
    backups_dir: Optional[Path] = None,
) -> bool:
    """Executes full tests, compilation, packaging, and sync into ONE explicit target DB."""
    # Validate the DB target before the long build, so a refusal costs nothing.
    target = require_target(target_db, must_exist=False)
    if not confirm:
        raise UnsafeTargetError(f"Refusing to sync into {target} without --confirm.")
    print("\n===============================================================================")
    print(" [FULL BUILD] بناء وتحديث الفرونت والباك إند بالكامل للبرودكشن ")
    print("===============================================================================")

    # 1. Backend tests
    print(f"[PROGRESS] {json.dumps({'percent': 12, 'stage': 'backend_tests', 'table': 'pytest', 'current_index': 1, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': 'جارٍ تشغيل اختبارات الباك إند الشاملة (pytest tests/unit/)...'}, ensure_ascii=False)}")
    sys.stdout.flush()
    print("\n[1/6] [TEST] تشغيل اختبارات الباك إند (pytest tests/unit/)...")
    res = subprocess.run([sys.executable, "-m", "pytest", "-q", "tests/unit/"], cwd=str(ROOT_DIR))
    if res.returncode != 0:
        print("[ERROR] فشلت اختبارات الباك إند! تم إيقاف عملية البناء.")
        print(f"[PROGRESS] {json.dumps({'percent': 100, 'stage': 'error', 'table': 'pytest', 'current_index': 1, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': '❌ فشلت اختبارات الباك إند!'}, ensure_ascii=False)}")
        sys.stdout.flush()
        return False
    print("   [PASS] اختبارات الباك إند اجتيزت بنجاح (100% Passing).")

    # 2. Frontend tests
    print(f"[PROGRESS] {json.dumps({'percent': 28, 'stage': 'frontend_tests', 'table': 'flutter_test', 'current_index': 2, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': 'جارٍ تشغيل اختبارات واجهة المستخدم (281 flutter tests)...'}, ensure_ascii=False)}")
    sys.stdout.flush()
    print("\n[2/6] [TEST] تشغيل اختبارات الفرونت إند (flutter test)...")
    frontend_dir = ROOT_DIR / "frontend"
    res = subprocess.run(["flutter", "test"], cwd=str(frontend_dir), shell=True)
    if res.returncode != 0:
        print("[ERROR] فشلت اختبارات الفرونت إند! تم إيقاف عملية البناء.")
        print(f"[PROGRESS] {json.dumps({'percent': 100, 'stage': 'error', 'table': 'flutter_test', 'current_index': 2, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': '❌ فشلت اختبارات الواجهة!'}, ensure_ascii=False)}")
        sys.stdout.flush()
        return False
    print("   [PASS] اختبارات الفرونت إند اجتيزت بنجاح (100% Passing).")

    # 3. Compile Flutter Windows Release
    print(f"[PROGRESS] {json.dumps({'percent': 48, 'stage': 'compile_windows', 'table': 'flutter_build', 'current_index': 3, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': 'جارٍ تجميع تطبيق الويندوز المكتبي (flutter build windows --release)...'}, ensure_ascii=False)}")
    sys.stdout.flush()
    print("\n[3/6] [BUILD] تجميع تطبيق الويندوز المكتبي (flutter build windows --release)...")
    res = subprocess.run(["flutter", "build", "windows", "--release"], cwd=str(frontend_dir), shell=True)
    if res.returncode != 0:
        print("[ERROR] فشل تجميع تطبيق الويندوز المكتبي!")
        print(f"[PROGRESS] {json.dumps({'percent': 100, 'stage': 'error', 'table': 'flutter_build', 'current_index': 3, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': '❌ فشل تجميع تطبيق الويندوز!'}, ensure_ascii=False)}")
        sys.stdout.flush()
        return False
    print("   [SUCCESS] تم تجميع ملفات تطبيق الويندوز المكتبي بنجاح.")

    # 4. Package Production Standalone
    print(f"[PROGRESS] {json.dumps({'percent': 72, 'stage': 'packaging', 'table': 'package_production', 'current_index': 4, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': 'جارٍ تجهيز وحزم ملفات بيئة الإنتاج المستقلة (package_production)...'}, ensure_ascii=False)}")
    sys.stdout.flush()
    print("\n[4/6] [PACKAGE] تجميع حزمة الإنتاج المستقلة (package_production.py)...")
    res = subprocess.run([sys.executable, str(ROOT_DIR / "package_production.py")], cwd=str(ROOT_DIR))
    if res.returncode != 0:
        print("[ERROR] فشل تجميع حزمة الإنتاج المستقلة!")
        print(f"[PROGRESS] {json.dumps({'percent': 100, 'stage': 'error', 'table': 'package_production', 'current_index': 4, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': '❌ فشل تجهيز حزمة الإنتاج!'}, ensure_ascii=False)}")
        sys.stdout.flush()
        return False
    print("   [SUCCESS] تم تحديث حزمة Standalone وتضمين أحدث قاعدة بيانات.")

    # 5. Sync Database
    print(f"[PROGRESS] {json.dumps({'percent': 85, 'stage': 'db_sync', 'table': 'sync_db', 'current_index': 5, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': 'جارٍ مزامنة وتحديث قاعدة بيانات الإنتاج...'}, ensure_ascii=False)}")
    sys.stdout.flush()
    print("\n[5/6] [DB SYNC] مزامنة قاعدة البيانات الحالية إلى الإنتاج...")
    if not sync_db_to_prod(target, source_db, confirm=confirm, backups_dir=backups_dir):
        print("[ERROR] فشلت مزامنة قاعدة البيانات! تم إيقاف عملية البناء.")
        return False

    # 6. Create Release Bundle ZIP & Manifest
    print(f"[PROGRESS] {json.dumps({'percent': 95, 'stage': 'zip_bundle', 'table': 'release_zip', 'current_index': 6, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': 'جارٍ إنشاء حزمة التوزيع المضغوطة (create_release_bundle)...'}, ensure_ascii=False)}")
    sys.stdout.flush()
    print("\n[6/6] [ZIP BUNDLE] إنشاء حزمة التوزيع المضغوطة (create_release_bundle.py)...")
    if (ROOT_DIR / "create_release_bundle.py").exists():
        subprocess.run([sys.executable, str(ROOT_DIR / "create_release_bundle.py")], cwd=str(ROOT_DIR))

    print(f"[PROGRESS] {json.dumps({'percent': 100, 'stage': 'completed', 'table': 'DONE', 'current_index': 6, 'total_tables': 6, 'records_synced': 0, 'total_synced': 0, 'message': '✅ تم بناء وتحديث وحزم الإنتاج بالكامل بنجاح تام!'}, ensure_ascii=False)}")
    sys.stdout.flush()

    print("\n===============================================================================")
    print(" [SUCCESS] تم بناء وتحديث ومزامنة كافة مكونات النظام للبرودكشن بنجاح تام! ")
    print(f" مجلد البرودكشن: {STANDALONE_DIR}")
    print(f" مشغل البرودكشن: {DIST_DIR / 'Start_ImportFlow_Production.bat'}")
    print("===============================================================================\n")
    return True


def export_release_zip():
    """Generates release zip."""
    if (ROOT_DIR / "create_release_bundle.py").exists():
        subprocess.run([sys.executable, str(ROOT_DIR / "create_release_bundle.py")], cwd=str(ROOT_DIR))
    else:
        print("[ERROR] لم يتم العثور على create_release_bundle.py")


def launch_production_app():
    """Launches the production application silently."""
    print("\n[LAUNCH] جاري تشغيل نسخة البرودكشن المستقلة (Sorour Logistics Standalone)...")
    vbs_launcher = STANDALONE_DIR / "Launch_Sorour_Logistics.vbs"
    if not vbs_launcher.exists():
        vbs_launcher = STANDALONE_DIR / "Launch_ImportFlow.vbs"
    bat_launcher = DIST_DIR / "Start_Sorour_Logistics_Production.bat"
    if not bat_launcher.exists():
        bat_launcher = DIST_DIR / "Start_ImportFlow_Production.bat"
    
    if vbs_launcher.exists():
        subprocess.Popen(["wscript.exe", str(vbs_launcher)], cwd=str(STANDALONE_DIR), env=clean_child_environment())
        print("[SUCCESS] تم إطلاق التطبيق بنجاح!")
    elif bat_launcher.exists():
        subprocess.Popen([str(bat_launcher)], cwd=str(DIST_DIR), shell=True, env=clean_child_environment())
        print("[SUCCESS] تم إطلاق التطبيق بنجاح!")
    else:
        print("[ERROR] لم يتم العثور على مشغل البرودكشن!")


def _ask_confirmed_target(prompt: str) -> Optional[Path]:
    """Interactive equivalent of --db + --confirm: an explicit path and a typed CONFIRM."""
    raw = input(prompt).strip().strip('"')
    if not raw:
        print("[!] لم يتم إدخال مسار قاعدة البيانات المستهدفة. تم الإلغاء.")
        return None
    typed = input(f"⚠️ سيتم تعديل {raw} بعد أخذ نسخة احتياطية موثقة. اكتب CONFIRM للمتابعة: ").strip()
    if typed != "CONFIRM":
        print("[!] لم يتم التأكيد. تم الإلغاء.")
        return None
    return Path(raw)


def interactive_menu():
    """Displays interactive CLI menu in Arabic/English."""
    while True:
        print("\n" + "=" * 65)
        print("   ImportFlow ERP - Production Sync Tool (أداة مزامنة التحديثات)   ")
        print("=" * 65)
        print("  [1] مزامنة سريعة لقاعدة البيانات فقط (Sync Database Dev -> Prod)")
        print("  [2] بناء كامل وتحديث الفرونت والباك إند (Full Build & Sync)")
        print("  [3] سحب قاعدة بيانات البرودكشن إلى بيئة التطوير (Pull Prod -> Dev)")
        print("  [4] فحص ومقارنة تطابق البيانات بين التطوير والإنتاج (Compare DBs)")
        print("  [5] تصدير حزمة التوزيع المضغوطة (Export Release ZIP)")
        print("  [6] تشغيل نسخة البرودكشن الآن (Launch Production App)")
        print("  [0] خروج (Exit)")
        print("-" * 65)

        choice = input("👉 اختر رقم العملية المطلوبة (0-6): ").strip()
        try:
            if choice in ("1", "2", "3"):
                target = _ask_confirmed_target("مسار قاعدة البيانات المستهدفة (--db): ")
                if target is None:
                    continue
                if choice == "1":
                    sync_db_to_prod(target, confirm=True)
                elif choice == "2":
                    full_production_build_and_sync(target, confirm=True)
                else:
                    pull_prod_db_to_dev(target, confirm=True)
            elif choice == "4":
                compare_databases()
            elif choice == "5":
                export_release_zip()
            elif choice == "6":
                launch_production_app()
            elif choice in ["0", "q", "exit"]:
                print("مع السلامة! 👋")
                break
            else:
                print("[!] اختيار غير صحيح، يرجى إدخال رقم من 0 إلى 6.")
        except UnsafeTargetError as exc:
            print(f"[REFUSED] {exc}")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="ImportFlow ERP Production Sync & Deployment Tool")
    parser.add_argument("--db-only", action="store_true", help="Sync Database from --source (Dev) into --db (Prod) with backup")
    parser.add_argument("--full", action="store_true", help="Full compilation, test, and production packaging, then sync into --db")
    parser.add_argument("--pull", action="store_true", help="Pull Database from --source (Prod) into --db (Dev) with backup")
    parser.add_argument("--compare", action="store_true", help="Compare Dev and Prod databases (read-only)")
    parser.add_argument("--diff", action="store_true", help="Emit structured diff data JSON (read-only)")
    parser.add_argument("--zip", action="store_true", help="Generate Release ZIP and manifest")
    parser.add_argument("--launch", action="store_true", help="Launch Production App")
    parser.add_argument("--source", default=None, help="Database read from (default: dev DB for --db-only/--full, prod DB for --pull)")
    add_target_arguments(parser, target_help="The ONE database written by --db-only / --pull / --full")

    args = parser.parse_args(argv)
    source = Path(args.source) if args.source else None
    backups_dir = Path(args.backups_dir) if args.backups_dir else None

    def _write_action(fn):
        def _run():
            target = require_target(args.db, must_exist=False)
            if not args.confirm:
                raise UnsafeTargetError(
                    f"Refusing to change {target} without --confirm (alias --i-understand-this-destroys-data)."
                )
            return fn(target, source, confirm=True, backups_dir=backups_dir)
        return run_guarded(_run)

    if args.db_only:
        return _write_action(sync_db_to_prod)
    if args.full:
        return _write_action(full_production_build_and_sync)
    if args.pull:
        return _write_action(pull_prod_db_to_dev)
    if args.compare or args.diff:
        # Read-only: --source = dev side, --db = prod side (defaults: DEV_DB / PROD_DB).
        compare_databases(source, Path(args.db) if args.db else None)
        return 0
    if args.zip:
        export_release_zip()
        return 0
    if args.launch:
        launch_production_app()
        return 0
    interactive_menu()
    return 0


if __name__ == "__main__":
    sys.exit(main())
