from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class HttpEndpointStat(BaseModel):
    path: str
    method: str
    count: int = 0
    p50_ms: float = 0.0
    p95_ms: float = 0.0
    errors: int = 0


class SystemMetricsResponse(BaseModel):
    status: str = "HEALTHY"
    uptime_seconds: float = 0.0
    uptime_human: str = "0h 0m"
    process_cpu_percent: float = 0.0
    process_memory_mb: float = 0.0
    system_cpu_percent: float = 0.0
    system_memory_percent: float = 0.0
    requests_per_second: float = 0.0
    total_requests: int = 0
    total_errors: int = 0
    p50_latency_ms: float = 0.0
    p95_latency_ms: float = 0.0
    p99_latency_ms: float = 0.0
    status_2xx: int = 0
    status_4xx: int = 0
    status_5xx: int = 0
    top_endpoints: List[HttpEndpointStat] = Field(default_factory=list)


class SlowQueryItem(BaseModel):
    timestamp: str
    duration_ms: float
    statement: str
    params_summary: Optional[str] = None


class RecentRequestItem(BaseModel):
    request_id: str
    timestamp: str
    method: str
    path: str
    status_code: int
    duration_ms: float
    client_ip: Optional[str] = None


class DatabaseHealthResponse(BaseModel):
    connected: bool = True
    engine_type: str = "SQLite"
    database_size_mb: float = 0.0
    wal_size_mb: float = 0.0
    journal_mode: str = "WAL"
    busy_timeout_ms: int = 30000
    lock_wait_events: int = 0
    slow_queries_count: int = 0
    recent_slow_queries: List[SlowQueryItem] = Field(default_factory=list)


class DomainObservabilityResponse(BaseModel):
    expiring_acids_count: int = 0
    expiring_acids: List[Dict[str, Any]] = Field(default_factory=list)
    demurrage_risks_count: int = 0
    demurrage_risks: List[Dict[str, Any]] = Field(default_factory=list)
    stuck_shipments_count: int = 0
    stuck_shipments: List[Dict[str, Any]] = Field(default_factory=list)
    last_backup_timestamp: Optional[str] = None
    last_backup_status: str = "UNKNOWN"
    last_backup_file: Optional[str] = None
    last_backup_size_mb: float = 0.0


class DeepHealthCheckResponse(BaseModel):
    verdict: str  # HEALTHY, DEGRADED, CRITICAL
    timestamp: str
    database_write_probe: bool = False
    database_write_latency_ms: float = 0.0
    database_integrity: str = "ok"
    free_disk_space_gb: float = 0.0
    disk_status: str = "OK"
    backup_freshness: str = "OK"
    ocr_status: str = "UNKNOWN"  # OK, PARTIAL, UNAVAILABLE (smart_document_upload.ocr_pipeline.ocr_self_check)
    ocr_engines: List[str] = Field(default_factory=list)
    issues: List[str] = Field(default_factory=list)


class DailyReportResponse(BaseModel):
    report_date: str
    generated_at: str
    headline_verdict: str  # ALL_NORMAL, NEEDS_ATTENTION, DEGRADED
    headline_message: str  # e.g., "✅ All normal" or "⚠️ 2 items need attention"
    needs_attention_items: List[str] = Field(default_factory=list)
    markdown_content: str
    html_content: str
    delivered_channels: List[str] = Field(default_factory=list)
    report_file: Optional[str] = None
    summary_data: Dict[str, Any] = Field(default_factory=dict)


class DailyReportHistoryItem(BaseModel):
    report_date: str
    filename: str
    headline_verdict: str
    headline_message: str
    needs_attention_count: int = 0
    generated_at: str
    file_size_bytes: int = 0

