import os
import sys
import time
import shutil
import json
import io
import zipfile
import sqlite3
import threading
from collections import deque
from datetime import datetime, date, timezone, timedelta
import logging

logger = logging.getLogger(__name__)
from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path

from sqlalchemy.orm import Session
from sqlalchemy import text, event

from modules.system_observability.schemas import (
    SystemMetricsResponse,
    HttpEndpointStat,
    SlowQueryItem,
    RecentRequestItem,
    DatabaseHealthResponse,
    DomainObservabilityResponse,
    DeepHealthCheckResponse,
)

from database.database import DB_PATH as _LIVE_DB_PATH
from utils.db_safety import app_base_dir, backups_dir_for

# R11: runtime paths follow the live DB (DATABASE_PATH / exe folder when frozen), never __file__.
ROOT_DIR = app_base_dir()
DB_PATH = Path(_LIVE_DB_PATH).resolve()
BACKUPS_DIR = backups_dir_for(DB_PATH)

# ==============================================================================
# Native Windows Memory & System Metrics Helpers (Zero External Dependencies)
# ==============================================================================

def get_system_and_process_memory() -> Dict[str, float]:
    result = {
        "process_memory_mb": 0.0,
        "system_memory_percent": 0.0,
    }
    if sys.platform != "win32":
        return result

    try:
        import ctypes
        from ctypes import wintypes

        # 1. System Memory Info
        class MEMORYSTATUSEX(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong),
                ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong),
                ("sullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]

        stat = MEMORYSTATUSEX()
        stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            result["system_memory_percent"] = float(stat.dwMemoryLoad)

        # 2. Process Working Set Info
        class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
            _fields_ = [
                ("cb", wintypes.DWORD),
                ("PageFaultCount", wintypes.DWORD),
                ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t),
                ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t),
            ]

        pmc = PROCESS_MEMORY_COUNTERS()
        pmc.cb = ctypes.sizeof(PROCESS_MEMORY_COUNTERS)
        handle = ctypes.windll.kernel32.OpenProcess(0x0400 | 0x0010, False, os.getpid())
        if handle:
            ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(pmc), pmc.cb)
            ctypes.windll.kernel32.CloseHandle(handle)
            result["process_memory_mb"] = round(pmc.WorkingSetSize / (1024 * 1024), 2)
    except Exception:
        pass

    return result


# ==============================================================================
# In-Memory Metrics Ring Buffer (Thread-Safe)
# ==============================================================================

class ObservabilityMetricsBuffer:
    def __init__(self, max_history: int = 1000):
        self._lock = threading.Lock()
        self.start_time = time.time()
        self.recent_requests: deque = deque(maxlen=max_history)
        self.recent_errors: deque = deque(maxlen=200)

        self.total_requests = 0
        self.status_2xx = 0
        self.status_4xx = 0
        self.status_5xx = 0

        # Endpoint path -> { "count": int, "latencies": deque(maxlen=100), "errors": int }
        self.endpoints_stats: Dict[str, Dict[str, Any]] = {}

    def record_request(
        self,
        request_id: str,
        method: str,
        path: str,
        status_code: int,
        duration_ms: float,
        client_ip: Optional[str] = None,
    ):
        now_ts = time.time()
        iso_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

        with self._lock:
            self.total_requests += 1
            if 200 <= status_code < 400:
                self.status_2xx += 1
            elif 400 <= status_code < 500:
                self.status_4xx += 1
            elif status_code >= 500:
                self.status_5xx += 1

            record = {
                "request_id": request_id,
                "timestamp": iso_str,
                "epoch": now_ts,
                "method": method,
                "path": path,
                "status_code": status_code,
                "duration_ms": round(duration_ms, 2),
                "client_ip": client_ip,
            }
            self.recent_requests.append(record)

            if status_code >= 400:
                self.recent_errors.append(record)

            # Route aggregation (normalize parameterized paths like /import-files/12 to /import-files/{id})
            norm_path = path
            parts = path.strip("/").split("/")
            if len(parts) > 1 and parts[-1].isdigit():
                norm_path = "/" + "/".join(parts[:-1]) + "/{id}"

            key = f"{method.upper()} {norm_path}"
            if key not in self.endpoints_stats:
                self.endpoints_stats[key] = {
                    "count": 0,
                    "errors": 0,
                    "latencies": deque(maxlen=100),
                }
            ep = self.endpoints_stats[key]
            ep["count"] += 1
            ep["latencies"].append(duration_ms)
            if status_code >= 400:
                ep["errors"] += 1

    def get_metrics_summary(self) -> SystemMetricsResponse:
        now_ts = time.time()
        uptime_sec = now_ts - self.start_time
        uptime_human = str(timedelta(seconds=int(uptime_sec)))

        with self._lock:
            # 1. RPS over rolling 60-second window
            cutoff_60s = now_ts - 60.0
            reqs_last_60s = sum(1 for r in self.recent_requests if r["epoch"] >= cutoff_60s)
            window_sec = min(uptime_sec, 60.0)
            rps = round(reqs_last_60s / window_sec, 2) if window_sec > 0 else 0.0

            # 2. Percentile Latencies
            all_latencies = sorted(r["duration_ms"] for r in self.recent_requests)
            p50 = 0.0
            p95 = 0.0
            p99 = 0.0
            if all_latencies:
                n = len(all_latencies)
                p50 = all_latencies[int(n * 0.50)]
                p95 = all_latencies[min(int(n * 0.95), n - 1)]
                p99 = all_latencies[min(int(n * 0.99), n - 1)]

            # 3. Top Endpoints
            top_eps: List[HttpEndpointStat] = []
            sorted_eps = sorted(
                self.endpoints_stats.items(),
                key=lambda item: item[1]["count"],
                reverse=True,
            )[:8]

            for ep_key, ep_data in sorted_eps:
                parts = ep_key.split(" ", 1)
                m = parts[0]
                p = parts[1] if len(parts) > 1 else ""
                lats = sorted(ep_data["latencies"])
                ep_p50 = lats[int(len(lats) * 0.50)] if lats else 0.0
                ep_p95 = lats[min(int(len(lats) * 0.95), len(lats) - 1)] if lats else 0.0
                top_eps.append(
                    HttpEndpointStat(
                        method=m,
                        path=p,
                        count=ep_data["count"],
                        p50_ms=round(ep_p50, 2),
                        p95_ms=round(ep_p95, 2),
                        errors=ep_data["errors"],
                    )
                )

            total_reqs = self.total_requests
            tot_errs = self.status_4xx + self.status_5xx
            s_2xx = self.status_2xx
            s_4xx = self.status_4xx
            s_5xx = self.status_5xx

        mem_info = get_system_and_process_memory()

        verdict = "HEALTHY"
        if self.status_5xx > 10:
            verdict = "DEGRADED"

        return SystemMetricsResponse(
            status=verdict,
            uptime_seconds=round(uptime_sec, 1),
            uptime_human=uptime_human,
            process_cpu_percent=0.0,
            process_memory_mb=mem_info["process_memory_mb"],
            system_cpu_percent=0.0,
            system_memory_percent=mem_info["system_memory_percent"],
            requests_per_second=rps,
            total_requests=total_reqs,
            total_errors=tot_errs,
            p50_latency_ms=round(p50, 2),
            p95_latency_ms=round(p95, 2),
            p99_latency_ms=round(p99, 2),
            status_2xx=s_2xx,
            status_4xx=s_4xx,
            status_5xx=s_5xx,
            top_endpoints=top_eps,
        )

    def get_recent_requests(self, limit: int = 50) -> List[RecentRequestItem]:
        with self._lock:
            items = list(self.recent_requests)[-limit:]
        items.reverse()
        return [
            RecentRequestItem(
                request_id=r["request_id"],
                timestamp=r["timestamp"],
                method=r["method"],
                path=r["path"],
                status_code=r["status_code"],
                duration_ms=r["duration_ms"],
                client_ip=r.get("client_ip"),
            )
            for r in items
        ]


metrics_buffer = ObservabilityMetricsBuffer()


# ==============================================================================
# Slow Query Tracker (SQLAlchemy Event Listener)
# ==============================================================================

class SlowQueryTracker:
    def __init__(self, max_queries: int = 100, threshold_ms: float = 150.0):
        self._lock = threading.Lock()
        self.threshold_ms = threshold_ms
        self.slow_queries: deque = deque(maxlen=max_queries)
        self.total_slow_queries_count = 0

    def record(self, duration_ms: float, statement: str, parameters: Any = None):
        if duration_ms < self.threshold_ms:
            return

        now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        trimmed_stmt = statement.strip()
        if len(trimmed_stmt) > 350:
            trimmed_stmt = trimmed_stmt[:350] + "..."

        param_str = None
        if parameters:
            try:
                param_str = json.dumps(parameters, default=str)
                if len(param_str) > 100:
                    param_str = param_str[:100] + "..."
            except Exception:
                param_str = str(parameters)[:100]

        with self._lock:
            self.total_slow_queries_count += 1
            self.slow_queries.append(
                SlowQueryItem(
                    timestamp=now_str,
                    duration_ms=round(duration_ms, 2),
                    statement=trimmed_stmt,
                    params_summary=param_str,
                )
            )

    def get_recent_slow_queries(self, limit: int = 30) -> List[SlowQueryItem]:
        with self._lock:
            items = list(self.slow_queries)[-limit:]
        items.reverse()
        return items


slow_query_tracker = SlowQueryTracker()


def setup_query_listener(engine):
    """Registers query timing listeners on the SQLAlchemy engine."""
    @event.listens_for(engine, "before_cursor_execute")
    def _before_execute(conn, cursor, statement, parameters, context, executemany):
        context._exec_start_time = time.perf_counter()

    @event.listens_for(engine, "after_cursor_execute")
    def _after_execute(conn, cursor, statement, parameters, context, executemany):
        if hasattr(context, "_exec_start_time"):
            duration_ms = (time.perf_counter() - context._exec_start_time) * 1000.0
            slow_query_tracker.record(duration_ms, statement, parameters)


# ==============================================================================
# Database Health Service
# ==============================================================================

class DatabaseHealthService:
    @staticmethod
    def get_health() -> DatabaseHealthResponse:
        db_exists = DB_PATH.exists()
        db_size_mb = round(DB_PATH.stat().st_size / (1024 * 1024), 2) if db_exists else 0.0

        wal_path = DB_PATH.with_suffix(".db-wal")
        wal_size_mb = round(wal_path.stat().st_size / (1024 * 1024), 2) if wal_path.exists() else 0.0

        journal_mode = "UNKNOWN"
        busy_timeout = 30000
        if db_exists:
            try:
                conn = sqlite3.connect(str(DB_PATH), timeout=5)
                cur = conn.cursor()
                cur.execute("PRAGMA journal_mode;")
                row = cur.fetchone()
                if row:
                    journal_mode = str(row[0]).upper()
                cur.execute("PRAGMA busy_timeout;")
                row = cur.fetchone()
                if row:
                    busy_timeout = int(row[0])
                conn.close()
            except Exception:
                pass

        recent_slow = slow_query_tracker.get_recent_slow_queries(10)

        return DatabaseHealthResponse(
            connected=db_exists,
            engine_type="SQLite (WAL Mode)",
            database_size_mb=db_size_mb,
            wal_size_mb=wal_size_mb,
            journal_mode=journal_mode,
            busy_timeout_ms=busy_timeout,
            lock_wait_events=0,
            slow_queries_count=slow_query_tracker.total_slow_queries_count,
            recent_slow_queries=recent_slow,
        )


# ==============================================================================
# Domain Logistics Radar Service
# ==============================================================================

class DomainRadarService:
    @staticmethod
    def get_radar(db: Session) -> DomainObservabilityResponse:
        now_utc = datetime.now(timezone.utc)
        seven_days_later = now_utc + timedelta(days=7)

        # 1. Expiring ACIDs (< 7 days)
        expiring_acids = []
        today_date = now_utc.date()
        try:
            from modules.import_documentation.model import AcidRegistrationSession
            sessions = (
                db.query(AcidRegistrationSession)
                .filter(
                    AcidRegistrationSession.expiry_date != None,
                    AcidRegistrationSession.expiry_date <= (today_date + timedelta(days=7)),
                    AcidRegistrationSession.is_active == True,
                )
                .limit(20)
                .all()
            )
            for s in sessions:
                exp_d = s.expiry_date
                if isinstance(exp_d, datetime):
                    days_left = (exp_d.date() - today_date).days
                elif isinstance(exp_d, date):
                    days_left = (exp_d - today_date).days
                else:
                    days_left = 0
                expiring_acids.append({
                    "acid_id": s.acid_id,
                    "acid_number": s.acid_number,
                    "days_remaining": days_left,
                    "proforma_invoice": getattr(s, "proforma_invoice_no", getattr(s, "proforma_invoice_number", "")),
                    "is_expired": days_left < 0,
                })
        except Exception as e:
            logger.warning(f"Error checking expiring ACIDs: {e}")

        # 2. Demurrage Risks (< 48h / Overdue)
        demurrage_risks = []
        try:
            from modules.demurrage_detention.model import DemurrageTracking
            dt_records = (
                db.query(DemurrageTracking)
                .filter(
                    DemurrageTracking.is_active == True,
                    DemurrageTracking.status != "Closed",
                )
                .limit(20)
                .all()
            )
            for d in dt_records:
                cntrs = d.containers if isinstance(d.containers, list) else []
                if cntrs:
                    for c in cntrs:
                        c_no = c.get("container_no") or c.get("container_number") or d.tracking_code
                        free_d = c.get("demurrage_days", 0)
                        dem_usd = c.get("demurrage_fx", 0.0)
                        demurrage_risks.append({
                            "tracking_id": d.tracking_id,
                            "container_number": c_no,
                            "free_days_remaining": free_d,
                            "accrued_demurrage_usd": dem_usd,
                        })
                else:
                    demurrage_risks.append({
                        "tracking_id": d.tracking_id,
                        "container_number": getattr(d, "tracking_code", "UNKNOWN"),
                        "free_days_remaining": 0,
                        "accrued_demurrage_usd": getattr(d, "total_demurrage_fx", 0.0),
                    })
        except Exception as e:
            logger.warning(f"Error checking demurrage risks: {e}")

        # 3. Stuck Shipments (> 10 days inactive)
        stuck_shipments = []
        ten_days_ago = now_utc - timedelta(days=10)
        try:
            from modules.import_files.model import ImportFile
            stuck_files = (
                db.query(ImportFile)
                .filter(
                    ImportFile.is_active == True,
                    ImportFile.status.notin_(["CLOSED", "CANCELLED"]),
                    ImportFile.updated_at != None,
                    ImportFile.updated_at <= ten_days_ago,
                )
                .limit(15)
                .all()
            )
            for f in stuck_files:
                stuck_shipments.append({
                    "file_id": getattr(f, "import_file_id", getattr(f, "file_id", 0)),
                    "file_code": getattr(f, "import_file_code", getattr(f, "file_code", "UNKNOWN")),
                    "current_stage": getattr(f, "current_stage", "IN_PROGRESS"),
                    "last_updated": f.updated_at.strftime("%Y-%m-%d") if f.updated_at else "",
                })
        except Exception as e:
            logger.warning(f"Error checking stuck shipments: {e}")

        # 4. Last Backup Status
        last_backup_time = None
        last_backup_status = "NO_BACKUPS_FOUND"
        last_backup_file = None
        last_backup_size_mb = 0.0

        if BACKUPS_DIR.exists():
            backup_files = sorted(
                BACKUPS_DIR.glob("daily_backup_*.db"),
                key=lambda p: p.stat().st_mtime,
                reverse=True,
            )
            if backup_files:
                latest = backup_files[0]
                mtime = datetime.fromtimestamp(latest.stat().st_mtime, tz=timezone.utc)
                last_backup_time = mtime.strftime("%Y-%m-%d %H:%M:%S UTC")
                last_backup_file = latest.name
                last_backup_size_mb = round(latest.stat().st_size / (1024 * 1024), 2)
                age_hours = (now_utc - mtime).total_seconds() / 3600.0
                if age_hours <= 26.0:
                    last_backup_status = "HEALTHY"
                else:
                    last_backup_status = "OVERDUE"

        return DomainObservabilityResponse(
            expiring_acids_count=len(expiring_acids),
            expiring_acids=expiring_acids,
            demurrage_risks_count=len(demurrage_risks),
            demurrage_risks=demurrage_risks,
            stuck_shipments_count=len(stuck_shipments),
            stuck_shipments=stuck_shipments,
            last_backup_timestamp=last_backup_time,
            last_backup_status=last_backup_status,
            last_backup_file=last_backup_file,
            last_backup_size_mb=last_backup_size_mb,
        )


# ==============================================================================
# Deep Health Probe Service
# ==============================================================================

class DeepHealthProbeService:
    @staticmethod
    def run_probe(db: Session) -> DeepHealthCheckResponse:
        now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        issues: List[str] = []

        # 1. Database Write Probe
        write_probe = False
        write_lat_ms = 0.0
        try:
            t0 = time.perf_counter()
            # Ensure heartbeat probe table exists
            db.execute(
                text(
                    "CREATE TABLE IF NOT EXISTS system_health_heartbeat "
                    "(id INTEGER PRIMARY KEY, probed_at TEXT, probe_status TEXT);"
                )
            )
            db.execute(
                text(
                    "INSERT OR REPLACE INTO system_health_heartbeat (id, probed_at, probe_status) "
                    "VALUES (1, :probed_at, 'OK');"
                ),
                {"probed_at": now_iso},
            )
            db.commit()
            write_lat_ms = (time.perf_counter() - t0) * 1000.0
            write_probe = True
        except Exception as e:
            db.rollback()
            issues.append(f"Database write probe failed: {str(e)}")

        # 2. SQLite Quick Integrity Check
        integrity_res = "ok"
        try:
            res = db.execute(text("PRAGMA quick_check;")).fetchone()
            if res and res[0] != "ok":
                integrity_res = str(res[0])
                issues.append(f"Database integrity check failed: {integrity_res}")
        except Exception as e:
            integrity_res = f"ERROR: {str(e)}"
            issues.append(integrity_res)

        # 3. Disk Space Check
        free_gb = 0.0
        disk_status = "OK"
        try:
            usage = shutil.disk_usage(str(DB_PATH.parent))
            free_gb = round(usage.free / (1024 * 1024 * 1024), 2)
            if free_gb < 2.0:
                disk_status = "CRITICAL"
                issues.append(f"Low disk space: {free_gb} GB remaining (< 2.0 GB)")
            elif free_gb < 5.0:
                disk_status = "WARNING"
                issues.append(f"Tight disk space: {free_gb} GB remaining (< 5.0 GB)")
        except Exception as e:
            issues.append(f"Disk check failed: {e}")

        # 4. Backup Freshness Check
        backup_freshness = "UNKNOWN"
        if BACKUPS_DIR.exists():
            backups = sorted(
                BACKUPS_DIR.glob("daily_backup_*.db"),
                key=lambda p: p.stat().st_mtime,
                reverse=True,
            )
            if backups:
                latest = backups[0]
                mtime = datetime.fromtimestamp(latest.stat().st_mtime, tz=timezone.utc)
                age_hours = (datetime.now(timezone.utc) - mtime).total_seconds() / 3600.0
                if age_hours <= 26.0:
                    backup_freshness = "UP_TO_DATE"
                else:
                    backup_freshness = "OVERDUE"
                    issues.append(f"Latest automated backup is {age_hours:.1f} hours old (> 26h)")
            else:
                backup_freshness = "MISSING"
                issues.append("No automated backups found in backups directory")
        else:
            backup_freshness = "MISSING"
            issues.append("Backups directory does not exist")

        # 5. OCR bundle (image / scanned-PDF reading). Only the installed build must ship RapidOCR; a dev
        #    machine without it is not an issue.
        ocr_status, ocr_engines = DeepHealthProbeService.check_ocr(issues)

        # 6. Overall Verdict
        if not write_probe or integrity_res != "ok" or disk_status == "CRITICAL":
            verdict = "CRITICAL"
        elif issues:
            verdict = "DEGRADED"
        else:
            verdict = "HEALTHY"

        return DeepHealthCheckResponse(
            verdict=verdict,
            timestamp=now_iso,
            database_write_probe=write_probe,
            database_write_latency_ms=round(write_lat_ms, 2),
            database_integrity=integrity_res,
            free_disk_space_gb=free_gb,
            disk_status=disk_status,
            backup_freshness=backup_freshness,
            ocr_status=ocr_status,
            ocr_engines=ocr_engines,
            issues=issues,
        )

    @staticmethod
    def check_ocr(issues: List[str]) -> Tuple[str, List[str]]:
        """OCR readiness; appends an issue when the frozen backend.exe lacks its bundled RapidOCR + Arabic model."""
        try:
            from modules.smart_document_upload.ocr_pipeline import OCR_STATUS_OK, ocr_self_check

            report = ocr_self_check()
        except Exception as e:
            issues.append(f"OCR self-check failed: {e}")
            return "UNKNOWN", []
        if report["frozen"] and report["status"] != OCR_STATUS_OK:
            issues.append(
                f"OCR bundle incomplete ({report['status']}): rapidocr_installed={report['rapidocr_installed']}, "
                f"rapidocr_models={report['rapidocr_models_present']}, "
                f"arabic_rec_model={report['arabic_rec_model_present']}"
            )
        return report["status"], list(report["engines"])


# ==============================================================================
# Diagnostics Bundle Generator Service (Sanitized Support Package)
# ==============================================================================

class DiagnosticsBundleService:
    @staticmethod
    def generate_zip_bundle(db: Session) -> bytes:
        metrics = metrics_buffer.get_metrics_summary().model_dump()
        db_health = DatabaseHealthService.get_health().model_dump()
        radar = DomainRadarService.get_radar(db).model_dump()
        deep_health = DeepHealthProbeService.run_probe(db).model_dump()
        recent_reqs = [r.model_dump() for r in metrics_buffer.get_recent_requests(50)]

        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("system_metrics.json", json.dumps(metrics, indent=2))
            zf.writestr("database_health.json", json.dumps(db_health, indent=2))
            zf.writestr("domain_radar.json", json.dumps(radar, indent=2))
            zf.writestr("deep_health_check.json", json.dumps(deep_health, indent=2))
            zf.writestr("recent_traffic.json", json.dumps(recent_reqs, indent=2))

            # System Environment Info (Sanitized)
            env_info = {
                "python_version": sys.version,
                "platform": sys.platform,
                "server_time_utc": datetime.now(timezone.utc).isoformat(),
                "db_path": str(DB_PATH),
                "is_frozen": getattr(sys, "frozen", False),
            }
            zf.writestr("system_environment.json", json.dumps(env_info, indent=2))

        buf.seek(0)
        return buf.getvalue()
