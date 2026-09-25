from typing import List, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Response, Header
from sqlalchemy.orm import Session
from database.database import get_db
from modules.users.model import User
from modules.auth.router import get_current_user, require_admin

from modules.system_observability.schemas import (
    SystemMetricsResponse,
    DatabaseHealthResponse,
    DomainObservabilityResponse,
    DeepHealthCheckResponse,
    RecentRequestItem,
    DailyReportResponse,
    DailyReportHistoryItem,
)
from modules.system_observability.daily_report_service import DailyReportService
from modules.system_observability.service import (
    metrics_buffer,
    DatabaseHealthService,
    DomainRadarService,
    DeepHealthProbeService,
    DiagnosticsBundleService,
)

router = APIRouter(
    prefix="/api/v1/system",
    tags=["System Observability, Telemetry & Health Monitoring"],
    dependencies=[Depends(get_current_user)],
)


@router.get("/observability/metrics", response_model=SystemMetricsResponse)
def get_system_metrics(
    current_user: User = Depends(get_current_user),
):
    """Returns live aggregated system metrics, RPS, percentiles, and top endpoints."""
    return metrics_buffer.get_metrics_summary()


@router.get("/observability/database", response_model=DatabaseHealthResponse)
def get_database_health(
    current_user: User = Depends(get_current_user),
):
    """Returns database size, WAL status, busy timeout, and slow query log."""
    return DatabaseHealthService.get_health()


@router.get("/observability/domain-radar", response_model=DomainObservabilityResponse)
def get_domain_radar(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns logistics domain operational risks: expiring ACIDs, demurrage, stuck files."""
    return DomainRadarService.get_radar(db)


@router.get("/health/deep", response_model=DeepHealthCheckResponse, dependencies=[Depends(require_admin)])
def run_deep_health_check(
    db: Session = Depends(get_db),
):
    """Executes an active write probe, database quick check, disk space, and backup freshness verification."""
    return DeepHealthProbeService.run_probe(db)


@router.get("/observability/recent-traffic", response_model=List[RecentRequestItem])
def get_recent_traffic(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
):
    """Returns recent requests with their correlation ID, status code, and latency."""
    return metrics_buffer.get_recent_requests(limit=limit)


@router.get("/observability/export-bundle")
def export_diagnostics_bundle(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Generates and downloads a complete, sanitized system diagnostics and health archive (ZIP)."""
    zip_bytes = DiagnosticsBundleService.generate_zip_bundle(db)
    filename = "sorour_logistics_diagnostics_bundle.zip"
    return Response(
        content=zip_bytes,
        media_type="application/zip",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )


# ==============================================================================
# Alert Dispatcher Endpoints (Push Notifications: Toast & Email)
# ==============================================================================

from modules.system_observability.alert_dispatcher import alert_dispatcher, AlertPayload


@router.post("/observability/alerts/evaluate")
def evaluate_system_alerts(
    force: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Evaluates all 8 health and domain conditions and dispatches alerts via Toast & Email."""
    results = alert_dispatcher.evaluate_all(db, force=force)
    return {
        "status": "success",
        "evaluated_at": datetime.now(timezone.utc).isoformat(),
        "total_conditions_evaluated": 8,
        "alerts_triggered_count": len([r for r in results if r.get("dispatched")]),
        "results": results,
    }


@router.post("/observability/alerts/test-trigger")
def trigger_test_alert(
    title: str = "تنبيه اختباري (Test Alert)",
    message: str = "تم تفعيل قناة الإشعارات بنجاح عبر نظام Observability.",
    channel: str = "TOAST",  # TOAST, EMAIL, BOTH
    severity: str = "HIGH",
    target_tab: str = "deep-health",
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Dispatches a test alert to verify delivery channel functionality."""
    channels = ["TOAST", "EMAIL"] if channel == "BOTH" else [channel]
    payload = AlertPayload(
        condition_key="TEST_ALERT",
        title=title,
        message=message,
        severity=severity,
        channels=channels,
        target_tab=target_tab,
    )
    res = alert_dispatcher.dispatch_alert(payload, db=db, force=True)
    return {
        "status": "success",
        "dispatched_channels": res.get("channels", []),
        "details": res,
    }


@router.get("/observability/alerts/history")
def get_alert_history(
    current_user: User = Depends(get_current_user),
):
    """Returns recent toast and email alert history and active cooldown states."""
    return {
        "total_toasts_sent": len(alert_dispatcher.toast_history),
        "recent_toasts": alert_dispatcher.toast_history[-20:],
        "total_emails_sent": len(alert_dispatcher.email_history),
        "recent_emails": alert_dispatcher.email_history[-20:],
        "cooldown_active": {
            k: v.isoformat() for k, v in alert_dispatcher._last_fired.items()
        },
    }


@router.post("/observability/alerts/reset-cooldown")
def reset_alert_cooldown(
    condition_key: str = None,
    current_user: User = Depends(require_admin),
):
    """Resets cooldown timers for alert conditions."""
    alert_dispatcher.reset_cooldown(condition_key)
    return {"status": "success", "message": "Alert cooldowns reset successfully."}


# ==============================================================================
# Daily Observability Report Endpoints
# ==============================================================================

@router.get("/observability/daily-report/latest", response_model=DailyReportResponse)
def get_latest_daily_report(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns today's consolidated observability report (generating it if not present)."""
    return DailyReportService.generate_report(db, deliver=False)


@router.post("/observability/daily-report/generate", response_model=DailyReportResponse)
def trigger_daily_report_generation(
    deliver: bool = True,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Manually triggers daily report generation and delivery via email and toast."""
    return DailyReportService.generate_report(db, deliver=deliver)


@router.get("/observability/daily-report/history", response_model=List[DailyReportHistoryItem])
def get_daily_report_history(
    limit: int = 30,
    current_user: User = Depends(get_current_user),
):
    """Returns a list of past daily reports stored in logs/daily-reports/."""
    return DailyReportService.list_history_reports(limit=limit)


