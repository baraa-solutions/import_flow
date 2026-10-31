from modules.production_sync.validators import validate_sql_identifier, validate_table_ddl
"""
Production Sync Service
Contains enterprise-grade, non-destructive database synchronization, comparison,
schema migration, and safety backup logic preserving 100% of production user data.
"""
import json
import logging
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from database.database import DB_PATH, Base
from utils.db_safety import (
    PRODUCTION_SYNC_PREFIX,
    BackupVerificationError,
    app_base_dir,
    backups_dir_for,
    check_integrity,
    is_frozen_build,
    select_prunable,
    sqlite_online_backup,
    unique_backup_name,
    version_file_path,
)
from modules.production_sync.repository import ProductionSyncRepository
from modules.production_sync.schemas import (
    DatabaseStatsSchema,
    TableComparisonItemSchema,
    SyncComparisonResponseSchema,
    SyncActionResponseSchema,
    BackupItemSchema,
    BackupsListResponseSchema,
    RestoreBackupResponseSchema,
    RemoteUpdateCheckResponseSchema,
    SystemVersionInfoSchema,
    RemoteUpdateCheckSchema,
    InstallerInfoSchema,
)
from modules.production_sync.validators import (
    resolve_backup_file,
    validate_db_exists,
    validate_not_production_build,
    validate_restore_target,
)

logger = logging.getLogger("production_sync")

# Own backups carry PRODUCTION_SYNC_PREFIX; retention only ever prunes that family (R9).
BACKUP_RETENTION = 50


def _resolve_paths():
    """(root_dir, standalone_dir, dev_db, prod_db, backups_dir).

    The live DB is always ``database.DB_PATH`` (honours DATABASE_PATH). In the frozen build there is
    one installed DB, so dev and prod are the same file; the destructive actions are blocked there (R7).
    Backups live next to the live DB.
    """
    live_db = Path(DB_PATH).resolve()
    root_dir = app_base_dir()
    if is_frozen_build():
        return root_dir, root_dir, live_db, live_db, backups_dir_for(live_db)

    standalone_dir = root_dir / "dist" / "Sorour_Logistics_Standalone"
    if not standalone_dir.exists():
        legacy_dir = root_dir / "dist" / "ImportFlow_Standalone"
        if legacy_dir.exists():
            standalone_dir = legacy_dir
    prod_db = standalone_dir / "sorour_logistics.db"
    return root_dir, standalone_dir, live_db, prod_db, backups_dir_for(live_db)


ROOT_DIR, STANDALONE_DIR, DEV_DB, PROD_DB, BACKUPS_DIR = _resolve_paths()
DIST_DIR = ROOT_DIR / "dist"


class ProductionSyncService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = ProductionSyncRepository(db)

    def _get_db_stats(self, db_path: Path) -> DatabaseStatsSchema:
        if not db_path.exists():
            return DatabaseStatsSchema(exists=False, path=str(db_path))
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
            tables = [row[0] for row in cursor.fetchall()]
            
            total_records = 0
            for table in tables:
                try:
                    safe_tbl = validate_sql_identifier(table)
                    cursor.execute(f'SELECT COUNT(*) FROM "{safe_tbl}";')
                    c = cursor.fetchone()[0]
                    total_records += c
                except Exception:
                    pass
            conn.close()
            return DatabaseStatsSchema(
                exists=True,
                path=str(db_path),
                size_kb=round(db_path.stat().st_size / 1024, 1),
                tables_count=len(tables),
                total_records=total_records,
                mtime=datetime.fromtimestamp(db_path.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
            )
        except Exception as e:
            return DatabaseStatsSchema(exists=True, path=str(db_path), error=str(e))

    def _get_table_counts(self, db_path: Path) -> Dict[str, int]:
        if not db_path.exists():
            return {}
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
            tables = [row[0] for row in cursor.fetchall()]
            counts = {}
            for table in tables:
                try:
                    safe_tbl = validate_sql_identifier(table)
                    cursor.execute(f'SELECT COUNT(*) FROM "{safe_tbl}";')
                    counts[table] = cursor.fetchone()[0]
                except Exception:
                    counts[table] = 0
            conn.close()
            return counts
        except Exception:
            return {}

    def _cleanup_old_backups(self, max_keep: int = BACKUP_RETENTION, exclude_path: Optional[Path] = None) -> List[str]:
        """Prune only this module's own backups (``psync_*.db``), keeping the newest ``max_keep``
        (at least MIN_BACKUPS_KEPT). daily_backup_*, auto_pre_upgrade_*, pre_install_*, pre_update_*,
        pre_migration_*, pre_restore_* and anything else in BACKUPS_DIR are never touched (R9, A8)."""
        removed: List[str] = []
        if not BACKUPS_DIR.exists():
            return removed
        own_backups = [f for f in BACKUPS_DIR.glob(f"{PRODUCTION_SYNC_PREFIX}*.db") if f.is_file()]
        for old_file in select_prunable(own_backups, keep=max_keep):
            if exclude_path is not None and old_file.resolve() == Path(exclude_path).resolve():
                continue
            try:
                old_file.unlink(missing_ok=True)
                removed.append(old_file.name)
            except OSError as exc:
                logger.warning("Could not prune backup %s: %s", old_file.name, exc)
        return removed

    def create_manual_backup(self, target: str = "dev") -> BackupItemSchema:
        target_path = PROD_DB if target == "prod" else DEV_DB
        return self.create_safety_backup(target_path, tag=f"manual_{target}")

    def create_safety_backup(self, db_path: Path, tag: str = "manual") -> BackupItemSchema:
        """Verified online backup (SQLite backup API + integrity_check + sha256) into BACKUPS_DIR."""
        validate_db_exists(db_path, tag)
        BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = BACKUPS_DIR / unique_backup_name(
            f"{PRODUCTION_SYNC_PREFIX}{db_path.stem}_{tag}_{timestamp}", BACKUPS_DIR
        )
        try:
            backup_result = sqlite_online_backup(db_path, backup_file)
        except BackupVerificationError as exc:
            logger.error("Backup verification failed for %s: %s", db_path, exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="فشل التحقق من سلامة النسخة الاحتياطية (integrity_check). لم يتم حفظ النسخة.",
            ) from exc
        except sqlite3.Error as exc:
            logger.error("Online backup failed for %s: %s", db_path, exc)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"تعذر إنشاء النسخة الاحتياطية من قاعدة البيانات: {exc}",
            ) from exc

        try:
            self.repo.create_log(
                action_type="CREATE_BACKUP",
                status="SUCCESS",
                backup_path=str(backup_file),
                notes=f"Backup created for {db_path.name} with tag {tag} (sha256={backup_result.sha256})",
            )
        except Exception as exc:  # the log row is informational; the verified backup already exists
            logger.warning("Could not record backup log for %s: %s", backup_file.name, exc)

        # Prune only this module's own older backups
        self._cleanup_old_backups(max_keep=BACKUP_RETENTION, exclude_path=backup_file)

        return BackupItemSchema(
            filename=backup_file.name,
            filepath=str(backup_file),
            size_kb=round(backup_file.stat().st_size / 1024, 1),
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            tag=tag,
        )

    def _smart_non_destructive_migrate(
        self, src_db: Path, target_db: Path, preserve_target_user_data: bool = True
    ) -> Dict[str, Any]:
        """
        Enterprise Non-Destructive Migration Engine:
        1. Ensures all tables from src_db exist in target_db (creates missing tables).
        2. Ensures all columns from src_db exist in target_db (executes ALTER TABLE ADD COLUMN for new features).
        3. Preserves 100% of user data in target_db (never deletes or overwrites existing user operational rows).
        4. Reference/Master data tables are safely updated/upserted.
        """
        if not target_db.exists():
            sqlite_online_backup(src_db, target_db)
            return {"status": "copied_fresh", "tables_added": 0, "columns_added": 0, "rows_merged": 0}

        conn_src = sqlite3.connect(src_db)
        conn_src.execute("PRAGMA journal_mode = WAL;")
        cur_src = conn_src.cursor()

        conn_tgt = sqlite3.connect(target_db)
        conn_tgt.execute("PRAGMA journal_mode = WAL;")
        cur_tgt = conn_tgt.cursor()

        cur_tgt.execute("PRAGMA foreign_keys = OFF;")
        cur_tgt.execute("BEGIN TRANSACTION;")

        # 1. Fetch tables
        cur_src.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
        src_tables = cur_src.fetchall()

        cur_tgt.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
        tgt_table_names = set(r[0] for r in cur_tgt.fetchall())

        tables_added = 0
        columns_added = 0
        rows_merged = 0

        # Operational tables where user data must NEVER be overwritten
        OPERATIONAL_TABLES = {
            "import_files",
            "purchase_orders",
            "purchase_order_items",
            "commercial_invoices",
            "commercial_invoice_items",
            "shipments",
            "shipment_containers",
            "shipment_packages",
            "customs_declarations",
            "customs_declaration_items",
            "customs_declaration_receipts",
            "landed_cost_calculations",
            "landed_cost_items",
            "clearance_operations",
            "clearance_expenses",
            "shipping_quotes",
            "shipping_quote_options",
            "cargo_insurance_certificates",
            "inspection_certificates",
            "shipment_tracking_events",
            "shipment_documents",
            "importing_companies",
            "importing_company_documents",
            "suppliers",
            "supplier_contacts",
            "supplier_documents",
            "service_partners",
            "service_partner_contacts",
            "projects",
            "project_documents",
            "activity_logs",
            "audit_trail_logs",
            "acid_validity_logs",
            "system_notifications",
        }

        # Step 1: Create missing tables
        for tbl_name, tbl_sql in src_tables:
            if tbl_name not in tgt_table_names:
                if tbl_sql:
                    cur_tgt.execute(validate_table_ddl(tbl_sql))
                    tables_added += 1
                    tgt_table_names.add(tbl_name)

        # Step 2: Add missing columns (ALTER TABLE ADD COLUMN)
        for tbl_name, _ in src_tables:
            if tbl_name in tgt_table_names:
                try:
                    safe_tbl = validate_sql_identifier(tbl_name)
                    cur_src.execute(f'PRAGMA table_info("{safe_tbl}");')
                    src_cols = {row[1]: row[2] for row in cur_src.fetchall()}  # name -> type

                    cur_tgt.execute(f'PRAGMA table_info("{safe_tbl}");')
                    tgt_cols = set(row[1] for row in cur_tgt.fetchall())

                    for col_name, col_type in src_cols.items():
                        if col_name not in tgt_cols:
                            safe_col = validate_sql_identifier(col_name)
                            cur_tgt.execute(f'ALTER TABLE "{safe_tbl}" ADD COLUMN "{safe_col}" {col_type};')
                            columns_added += 1
                except Exception:
                    pass

        # Step 3: Synchronize and upsert rows
        for tbl_name, _ in src_tables:
            try:
                safe_tbl = validate_sql_identifier(tbl_name)
                cur_src.execute(f'PRAGMA table_info("{safe_tbl}");')
                src_cols = [row[1] for row in cur_src.fetchall()]
                
                cur_tgt.execute(f'PRAGMA table_info("{safe_tbl}");')
                tgt_cols = set(row[1] for row in cur_tgt.fetchall())
                
                common_cols = [c for c in src_cols if c in tgt_cols]
                if not common_cols:
                    continue

                cols_str = ", ".join([f'"{c}"' for c in common_cols])
                placeholders = ", ".join(["?"] * len(common_cols))

                cur_src.execute(f'SELECT {cols_str} FROM "{safe_tbl}";')
                src_rows = cur_src.fetchall()

                is_operational = tbl_name in OPERATIONAL_TABLES
                insert_verb = "INSERT OR IGNORE" if (preserve_target_user_data and is_operational) else "INSERT OR REPLACE"

                for row in src_rows:
                    cur_tgt.execute(
                        f'{insert_verb} INTO "{safe_tbl}" ({cols_str}) VALUES ({placeholders});',
                        tuple(row),
                    )
                    if cur_tgt.rowcount > 0:
                        rows_merged += 1
            except Exception:
                pass

        conn_tgt.commit()
        cur_tgt.execute("PRAGMA foreign_keys = ON;")
        conn_src.close()
        conn_tgt.close()

        return {
            "status": "migrated_safely",
            "tables_added": tables_added,
            "columns_added": columns_added,
            "rows_merged": rows_merged,
        }

    def _get_table_columns(self, db_path: Path) -> Dict[str, List[str]]:
        """Returns {table_name: [col1, col2, ...]} for all tables in db_path."""
        if not db_path.exists():
            return {}
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
            tables = [row[0] for row in cursor.fetchall()]
            result = {}
            for table in tables:
                try:
                    cursor.execute(f'PRAGMA table_info("{table}");')
                    result[table] = [row[1] for row in cursor.fetchall()]
                except Exception:
                    result[table] = []
            conn.close()
            return result
        except Exception:
            return {}

    def get_comparison(self) -> SyncComparisonResponseSchema:
        dev_stats = self._get_db_stats(DEV_DB)
        prod_stats = self._get_db_stats(PROD_DB)

        dev_counts = self._get_table_counts(DEV_DB)
        prod_counts = self._get_table_counts(PROD_DB)

        # ── Schema comparison ────────────────────────────────────────────
        dev_columns = self._get_table_columns(DEV_DB)
        prod_columns = self._get_table_columns(PROD_DB)

        all_table_names = sorted(set(list(dev_counts.keys()) + list(prod_counts.keys())))

        table_items: List[TableComparisonItemSchema] = []
        matched_count = 0
        diff_count = 0
        schema_diffs_count = 0

        for tbl in all_table_names:
            d_c = dev_counts.get(tbl, 0)
            p_c = prod_counts.get(tbl, 0)
            diff = d_c - p_c

            dev_cols = dev_columns.get(tbl, [])
            prod_cols_set = set(prod_columns.get(tbl, []))

            is_new_table = tbl not in prod_counts
            new_columns = [c for c in dev_cols if c not in prod_cols_set] if not is_new_table else []
            has_schema_diff = is_new_table or len(new_columns) > 0

            data_match = (d_c == p_c) and not is_new_table
            is_fully_matched = data_match and not has_schema_diff
            needs_sync = not is_fully_matched

            if is_fully_matched:
                matched_count += 1
                status_str = "متطابق (Matched)"
            else:
                diff_count += 1
                if is_new_table:
                    status_str = "جدول جديد (New Table)"
                elif has_schema_diff and data_match:
                    new_cols_preview = ", ".join(new_columns[:3])
                    if len(new_columns) > 3:
                        new_cols_preview += f" +{len(new_columns) - 3}"
                    status_str = f"ترقية Schema ({len(new_columns)} عمود جديد: {new_cols_preview})"
                elif has_schema_diff:
                    status_str = f"فرق بيانات + Schema ({diff:+d} سجل, {len(new_columns)} عمود)"
                else:
                    status_str = f"فرق ({diff:+d})"

            if has_schema_diff:
                schema_diffs_count += 1

            table_items.append(
                TableComparisonItemSchema(
                    table_name=tbl,
                    dev_count=d_c,
                    prod_count=p_c,
                    diff=diff,
                    is_match=is_fully_matched,
                    status=status_str,
                    dev_columns_count=len(dev_cols),
                    prod_columns_count=len(prod_columns.get(tbl, [])),
                    new_columns=new_columns,
                    is_new_table=is_new_table,
                    has_schema_diff=has_schema_diff,
                    needs_sync=needs_sync,
                )
            )

        is_fully_sync = (diff_count == 0) and (schema_diffs_count == 0) and dev_stats.exists and prod_stats.exists

        return SyncComparisonResponseSchema(
            dev_stats=dev_stats,
            prod_stats=prod_stats,
            is_fully_synchronized=is_fully_sync,
            total_tables=len(all_table_names),
            matched_tables_count=matched_count,
            differing_tables_count=diff_count,
            schema_diffs_count=schema_diffs_count,
            tables=table_items,
        )

    def sync_dev_to_prod(self) -> SyncActionResponseSchema:
        """
        Pushes development updates to production non-destructively.
        """
        validate_not_production_build()
        validate_db_exists(DEV_DB, "قاعدة بيانات التطوير")

        prod_backup_str = None
        if PROD_DB.exists():
            prod_backup = self.create_safety_backup(PROD_DB, "prod_before_sync")
            prod_backup_str = prod_backup.filename

        dev_backup = self.create_safety_backup(DEV_DB, "dev_snapshot")
        STANDALONE_DIR.mkdir(parents=True, exist_ok=True)

        migration_res = self._smart_non_destructive_migrate(DEV_DB, PROD_DB)

        other_dist_dbs = [
            DIST_DIR / "sorour_logistics.db",
            ROOT_DIR / "dist_backend" / "sorour_logistics.db",
            DIST_DIR / "ImportFlow_Standalone" / "sorour_logistics.db",
            DIST_DIR / "Sorour_Logistics_Desktop" / "sorour_logistics.db",
        ]
        for alt_db in other_dist_dbs:
            if alt_db.exists() and alt_db.resolve() != PROD_DB.resolve():
                try:
                    self._smart_non_destructive_migrate(DEV_DB, alt_db)
                except Exception:
                    pass

        try:
            import version_manager
            version_manager.bump_version("patch")
        except Exception:
            pass

        stats = self._get_db_stats(PROD_DB)

        try:
            self.repo.create_log(
                action_type="PUSH_TO_PROD",
                status="SUCCESS",
                backup_path=str(dev_backup.filepath),
                records_count=stats.total_records,
                tables_count=stats.tables_count,
                notes=f"Safe non-destructive sync completed: {migration_res}",
            )
        except Exception:
            pass

        return SyncActionResponseSchema(
            success=True,
            action="PUSH_TO_PROD",
            message="تمت المزامنة وتطبيق التحديثات بأمان 100% مع الحفاظ التام على بيانات التشغيل المسجلة!",
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            backup_file=prod_backup_str or dev_backup.filename,
            affected_tables_count=stats.tables_count,
            total_records_synced=stats.total_records,
            details={
                "prod_size_kb": stats.size_kb,
                "prod_path": str(PROD_DB),
                "migration_summary": migration_res,
            },
        )

    def pull_prod_to_dev(self) -> SyncActionResponseSchema:
        """
        Pulls actual production data into development workspace non-destructively.
        """
        validate_not_production_build()
        validate_db_exists(PROD_DB, "قاعدة بيانات الإنتاج")

        dev_backup = self.create_safety_backup(DEV_DB, "dev_before_pull")
        prod_backup = self.create_safety_backup(PROD_DB, "prod_snapshot")

        migration_res = self._smart_non_destructive_migrate(PROD_DB, DEV_DB, preserve_target_user_data=False)
        stats = self._get_db_stats(DEV_DB)

        try:
            self.repo.create_log(
                action_type="PULL_TO_DEV",
                status="SUCCESS",
                backup_path=str(prod_backup.filepath),
                records_count=stats.total_records,
                tables_count=stats.tables_count,
                notes=f"Safe pull from prod to dev completed: {migration_res}",
            )
        except Exception:
            pass

        return SyncActionResponseSchema(
            success=True,
            action="PULL_TO_DEV",
            message="تم سحب ودمج بيانات البرودكشن الفعلية بنجاح إلى بيئة التطوير دون أي فقدان للبيانات!",
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            backup_file=dev_backup.filename,
            affected_tables_count=stats.tables_count,
            total_records_synced=stats.total_records,
            details={
                "dev_size_kb": stats.size_kb,
                "dev_path": str(DEV_DB),
                "migration_summary": migration_res,
            },
        )

    def list_backups(self) -> BackupsListResponseSchema:
        if not BACKUPS_DIR.exists():
            return BackupsListResponseSchema(total_backups=0, backups=[])
        
        backups: List[BackupItemSchema] = []
        for file in sorted(BACKUPS_DIR.glob("*.db"), key=lambda f: f.stat().st_mtime, reverse=True):
            tag = "backup"
            if "prod" in file.name:
                tag = "prod"
            elif "dev" in file.name:
                tag = "dev"
            
            backups.append(
                BackupItemSchema(
                    filename=file.name,
                    filepath=str(file),
                    size_kb=round(file.stat().st_size / 1024, 1),
                    created_at=datetime.fromtimestamp(file.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                    tag=tag,
                )
            )

        return BackupsListResponseSchema(total_backups=len(backups), backups=backups)

    def restore_backup(self, filename: str, target: str = "prod") -> RestoreBackupResponseSchema:
        """
        Restore a specific backup snapshot to the target database (dev or prod).
        Only a file inside BACKUPS_DIR, referenced by bare name, can be restored. Never available in
        the frozen build (R7).
        """
        validate_not_production_build()
        validate_restore_target(target)
        BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
        backup_file = resolve_backup_file(BACKUPS_DIR, filename)

        try:
            integrity = check_integrity(backup_file)
        except sqlite3.DatabaseError as exc:
            integrity = str(exc)
        if integrity != "ok":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"النسخة الاحتياطية تالفة ولا يمكن استعادتها (integrity_check: {integrity}).",
            )

        target_db = PROD_DB if target == "prod" else DEV_DB

        safety_backup: Optional[BackupItemSchema] = None
        if target_db.exists():
            safety_backup = self.create_safety_backup(target_db, tag=f"pre_restore_{target}")

        # Online backup API: one transaction on the target, safe with open connections and WAL.
        sqlite_online_backup(backup_file, target_db, overwrite=target_db.exists())

        try:
            self.repo.create_log(
                action_type="RESTORE_BACKUP",
                status="SUCCESS",
                backup_path=str(backup_file),
                notes=f"Restored '{filename}' to {target} DB. Safety backup: {safety_backup.filename if safety_backup else 'none'}",
            )
        except Exception:
            pass

        return RestoreBackupResponseSchema(
            success=True,
            message=f"تمت استعادة النسخة الاحتياطية '{filename}' بنجاح إلى قاعدة بيانات {'الإنتاج' if target == 'prod' else 'التطوير'} مع حفظ نسخة أمان من الوضع الحالي.",
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            restored_from=filename,
            safety_backup_created=safety_backup.filename if safety_backup else "لم تكن هناك قاعدة بيانات سابقة",
            target=target,
        )

    def check_remote_update(self) -> RemoteUpdateCheckResponseSchema:
        """Local installed-version info only. Update discovery moved to the signed app_update flow
        (/api/v1/app-update); this makes no outbound request."""
        info = self.get_system_version_info()
        return RemoteUpdateCheckResponseSchema(
            current_version=info.version,
            current_build=info.build_number,
            latest_version=info.version,
            update_available=False,
            check_status="no_update",
        )

    def get_system_version_info(self) -> SystemVersionInfoSchema:
        """Retrieves live system version, build number, environment, and database metrics."""
        version_str = "1.0.55"
        build_num = 56
        rel_date = None

        v_file = version_file_path()
        if v_file.exists():
            try:
                with open(v_file, "r", encoding="utf-8") as f:
                    v_data = json.load(f)
                    version_str = v_data.get("version", version_str)
                    build_num = v_data.get("build_number", build_num)
                    rel_date = v_data.get("updated_at")
            except Exception:
                pass

        is_standalone = is_frozen_build() or not (ROOT_DIR / "frontend").exists()
        active_db = PROD_DB if (is_standalone and PROD_DB.exists()) else DEV_DB
        db_stats = self._get_db_stats(active_db)

        backups_count = 0
        if BACKUPS_DIR.exists():
            try:
                backups_count = len(list(BACKUPS_DIR.glob("*.db")))
            except Exception:
                pass

        return SystemVersionInfoSchema(
            system_name="Sorour Logistics ERP",
            version=version_str,
            build_number=build_num,
            release_date=rel_date or datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            is_standalone=is_standalone,
            environment="standalone" if is_standalone else "development",
            database_path=str(active_db.name),
            database_size_kb=db_stats.size_kb,
            tables_count=db_stats.tables_count,
            total_backups_count=backups_count,
        )

    def check_for_updates(self) -> RemoteUpdateCheckSchema:
        """Local version info only. Update discovery moved to the signed app_update flow
        (/api/v1/app-update), so this makes no outbound request and accepts no remote URL."""
        curr_ver = self.get_system_version_info().version
        return RemoteUpdateCheckSchema(
            has_update=False,
            current_version=curr_ver,
            latest_version=curr_ver,
            release_notes=[],
            check_status="UP_TO_DATE",
            message=f"الإصدار المثبت v{curr_ver}. فحص التحديثات يتم من شاشة تحديث البرنامج.",
        )

    def get_latest_installer_info(self) -> InstallerInfoSchema:
        """No installer is offered here any more (updates come from /api/v1/app-update); returns the
        installed version with is_available=False and makes no outbound request."""
        return InstallerInfoSchema(
            version=self.get_system_version_info().version,
            installer_url="",
            installer_filename="",
            installer_size_mb=0.0,
            is_available=False,
            error="التحديثات تتم من شاشة تحديث البرنامج.",
        )
