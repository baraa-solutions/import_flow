"""
ImportFlow ERP — System Observability Alert Dispatcher
======================================================
Implements proactive Push Alert delivery across:
1. Windows Desktop Toast Notifications (PowerShell / WinRT) & WebSocket broadcast.
2. Email Notifications (SMTP outbound dispatcher / Outlook / offline audit log).

Condition Mapping:
- Daily backup missing/failed (>26h)           -> Toast + Email (High, 1h cooldown)
- Free disk space < 5GB                        -> Toast + Email (High, 1h cooldown)
- Free disk space < 2GB                        -> Toast (Critical, repeat until resolved)
- DB deep health verdict != HEALTHY            -> Toast + Email (High, 1h cooldown)
- ACID expiring within 7 days                  -> Email daily digest (Medium, 24h cooldown)
- Demurrage free-time < 48h                    -> Email daily digest (Medium, 24h cooldown)
- Shipment stuck in same stage > 10 days       -> Email daily digest (Low-Med, 24h cooldown)
- Slow query rate spikes (>10/hr)              -> Email daily digest (Low, 24h cooldown)
"""

import os
import sys
import json
import logging
import smtplib
import subprocess
import threading
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
from pathlib import Path
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from sqlalchemy.orm import Session

from database.database import DB_PATH as _LIVE_DB_PATH
from modules.common.system_messages import SysMsg, msg as sys_msg, render_en
from utils.db_safety import app_base_dir, backups_dir_for

# R11: runtime paths next to the executable (frozen) / repo root (dev); backups next to the live DB.
ROOT_DIR = app_base_dir()
BACKUPS_DIR = backups_dir_for(_LIVE_DB_PATH)
LOGS_DIR = ROOT_DIR / "logs"
ALERTS_LOG_FILE = LOGS_DIR / "alerts.log"
TOAST_SCRIPT_PATH = ROOT_DIR / "scripts" / "send_windows_toast.ps1"

logger = logging.getLogger("importflow.alerts")


class AlertPayload:
    def __init__(
        self,
        condition_key: str,
        title: Optional[str],
        message: Optional[str],
        severity: str,
        channels: List[str],
        target_tab: str,
        details: Optional[Dict[str, Any]] = None,
        msg: Optional[SysMsg] = None,
    ):
        # Single-language storage: system alerts carry a message code; title/message default to the
        # English render (toast, email, alerts.log and the stored notification text stay English).
        self.msg = msg
        self.condition_key = condition_key
        self.title = title if title is not None else (render_en(msg.code, msg.params, "title") if msg else "")
        self.message = message if message is not None else (render_en(msg.code, msg.params, "body") if msg else "")
        self.severity = severity  # CRITICAL, HIGH, MEDIUM, LOW
        self.channels = channels  # ['TOAST', 'EMAIL']
        self.target_tab = target_tab  # deep-health, domain-radar, telemetry
        self.details = details or {}
        self.created_at = datetime.now(timezone.utc)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "condition_key": self.condition_key,
            "title": self.title,
            "message": self.message,
            "severity": self.severity,
            "channels": self.channels,
            "target_tab": self.target_tab,
            "details": self.details,
            "msg_code": self.msg.code if self.msg else None,
            "msg_params": self.msg.params if self.msg else None,
            "created_at": self.created_at.isoformat(),
        }


class AlertDispatcher:
    """
    Central alert evaluator and multi-channel dispatcher with anti-spam cooldowns.
    """
    def __init__(self):
        self._last_fired: Dict[str, datetime] = {}
        self._lock = threading.Lock()
        self.toast_history: List[Dict[str, Any]] = []
        self.email_history: List[Dict[str, Any]] = []

    def get_cooldown_seconds(self, condition_key: str) -> int:
        """Standardized cooldown rules per condition."""
        if condition_key == "DISK_SPACE_CRITICAL":
            return 900  # 15 minutes for critical disk space
        elif condition_key in ("BACKUP_OVERDUE", "OFFSITE_BACKUP_OVERDUE", "DISK_SPACE_WARNING", "DB_HEALTH_UNHEALTHY"):
            return 3600  # 1 hour for operational high alerts
        else:
            return 86400  # 24 hours for daily digest alerts (ACID, Demurrage, Stuck, Slow queries)

    def can_fire(self, condition_key: str) -> bool:
        with self._lock:
            last = self._last_fired.get(condition_key)
            if not last:
                return True
            cooldown = self.get_cooldown_seconds(condition_key)
            elapsed = (datetime.now(timezone.utc) - last).total_seconds()
            return elapsed >= cooldown

    def mark_fired(self, condition_key: str):
        with self._lock:
            self._last_fired[condition_key] = datetime.now(timezone.utc)

    def reset_cooldown(self, condition_key: Optional[str] = None):
        with self._lock:
            if condition_key:
                self._last_fired.pop(condition_key, None)
            else:
                self._last_fired.clear()

    # ── Channel 1: Windows Desktop Toast Notification ──────────────

    def send_toast(self, payload: AlertPayload) -> bool:
        """Triggers native Windows Toast / Balloon and broadcasts via WebSocket."""
        success = False
        # 1. Native Windows Notification
        if sys.platform == "win32" and TOAST_SCRIPT_PATH.exists():
            try:
                cmd = [
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(TOAST_SCRIPT_PATH),
                    "-Title",
                    f"[{payload.severity}] {payload.title}",
                    "-Message",
                    payload.message,
                    "-Urgency",
                    payload.severity,
                ]
                proc = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                if proc.returncode == 0 and ("TOAST_SUCCESS" in proc.stdout or "BALLOON_SUCCESS" in proc.stdout):
                    success = True
            except Exception as e:
                logger.warning(f"Native Windows toast invocation failed: {e}")

        # 2. WebSocket Push to connected Flutter desktop clients
        try:
            from modules.notifications.websocket_manager import websocket_manager
            import asyncio
            ws_msg = {
                "type": "SYSTEM_ALERT",
                "alert": payload.to_dict(),
            }
            # Schedule broadcast if loop running, or best effort
            try:
                loop = asyncio.get_event_loop()
                if loop.is_running():
                    loop.create_task(websocket_manager.broadcast(ws_msg))
            except Exception:
                pass
            success = True
        except Exception:
            pass

        # Record history
        record = {
            "channel": "TOAST",
            "condition_key": payload.condition_key,
            "title": payload.title,
            "message": payload.message,
            "severity": payload.severity,
            "target_tab": payload.target_tab,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "delivered": success,
        }
        self.toast_history.append(record)
        self._write_to_alerts_log("TOAST", payload, success)
        return success

    # ── Channel 2: Email Alert & Daily Digest ──────────────────────

    def send_email(self, payload: AlertPayload, db: Optional[Session] = None) -> bool:
        """Sends email via SMTP or writes formatted alert to audit log if offline."""
        smtp_host = os.getenv("ALERT_SMTP_HOST") or os.getenv("SMTP_HOST")
        smtp_port = int(os.getenv("ALERT_SMTP_PORT") or os.getenv("SMTP_PORT") or "587")
        smtp_user = os.getenv("ALERT_SMTP_USER") or os.getenv("SMTP_USER")
        smtp_pass = os.getenv("ALERT_SMTP_PASSWORD") or os.getenv("SMTP_PASSWORD")
        recipient = os.getenv("ALERT_RECIPIENT_EMAIL") or "admin@sorourlogistics.com"
        sender = os.getenv("ALERT_EMAIL_FROM") or "alerts@sorourlogistics.com"

        email_sent = False
        delivery_mode = "OFFLINE_AUDIT_LOG"

        # Attempt live SMTP if configured
        if smtp_host and smtp_user and smtp_pass:
            try:
                msg = MIMEMultipart("alternative")
                msg["Subject"] = f"[{payload.severity}] ImportFlow Alert: {payload.title}"
                msg["From"] = f"ImportFlow System Watchdog <{sender}>"
                msg["To"] = recipient

                plain_text = (
                    f"ImportFlow ERP — System Alert\n"
                    f"============================\n"
                    f"Severity: {payload.severity}\n"
                    f"Condition: {payload.condition_key}\n"
                    f"Time: {payload.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}\n"
                    f"Target Tab: {payload.target_tab}\n\n"
                    f"Details:\n{payload.message}\n\n"
                    f"Action Required: Please open the Observability Dashboard -> {payload.target_tab} tab.\n"
                )
                html_text = f"""
                <div style="font-family: Arial, sans-serif; max-width: 600px; padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
                    <h2 style="color: {'#C0392B' if payload.severity in ('CRITICAL', 'HIGH') else '#E67E22'}; margin-top: 0;">
                        [{payload.severity}] {payload.title}
                    </h2>
                    <p><strong>Time:</strong> {payload.created_at.strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
                    <p><strong>Condition:</strong> {payload.condition_key}</p>
                    <div style="background-color: #f8f9fa; padding: 15px; border-left: 4px solid #3498DB; margin: 15px 0;">
                        <p style="margin: 0; font-size: 15px;">{payload.message}</p>
                    </div>
                    <p><strong>Action:</strong> Open the <em>System Observability -> {payload.target_tab}</em> tab on your desktop client.</p>
                </div>
                """
                msg.attach(MIMEText(plain_text, "plain", "utf-8"))
                msg.attach(MIMEText(html_text, "html", "utf-8"))

                with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as server:
                    server.starttls()
                    server.login(smtp_user, smtp_pass)
                    server.send_message(msg)
                email_sent = True
                delivery_mode = "SMTP_SENT"
            except Exception as e:
                logger.warning(f"SMTP delivery failed: {e}. Falling back to offline alert log.")

        # Persist to database notifications if session is available
        if db is not None:
            try:
                from modules.notifications.model import SystemNotification
                wrapper = sys_msg(
                    "ALERT_DISPATCHED",
                    severity_enum_alert_severity=payload.severity,
                    alert_title=payload.title,
                    alert_message=payload.message,
                    target_tab=payload.target_tab,
                )
                # The alert's own code is stored when it has one (the UI renders it localized);
                # otherwise the generic ALERT_DISPATCHED wrapper, whose render equals the stored text.
                coded = payload.msg or wrapper
                notif = SystemNotification(
                    title=render_en(wrapper.code, wrapper.params, "title")[:200],
                    message=render_en(wrapper.code, wrapper.params, "body"),
                    msg_code=coded.code,
                    msg_params=coded.params,
                    severity="CRITICAL" if payload.severity == "CRITICAL" else "WARNING",
                    category="SYSTEM",
                    target_role="ADMIN",
                    is_read=False,
                )
                db.add(notif)
                db.commit()
            except Exception:
                db.rollback()

        # Record history
        record = {
            "channel": "EMAIL",
            "condition_key": payload.condition_key,
            "title": payload.title,
            "message": payload.message,
            "severity": payload.severity,
            "target_tab": payload.target_tab,
            "recipient": recipient,
            "delivery_mode": delivery_mode,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "delivered": email_sent or delivery_mode == "OFFLINE_AUDIT_LOG",
        }
        self.email_history.append(record)
        self._write_to_alerts_log(f"EMAIL ({delivery_mode})", payload, True)
        return True

    def _write_to_alerts_log(self, channel_tag: str, payload: AlertPayload, success: bool):
        try:
            LOGS_DIR.mkdir(parents=True, exist_ok=True)
            iso = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
            line = f"[{iso}] [{channel_tag}] [{payload.severity}] {payload.condition_key}: {payload.title} - {payload.message}\n"
            with open(ALERTS_LOG_FILE, "a", encoding="utf-8") as f:
                f.write(line)
        except Exception:
            pass

    # ── Evaluation & Dispatch Pipeline ─────────────────────────────

    def dispatch_alert(self, payload: AlertPayload, db: Optional[Session] = None, force: bool = False) -> Dict[str, Any]:
        """Dispatches an alert to its mapped channels respecting cooldowns."""
        if not force and not self.can_fire(payload.condition_key):
            return {
                "condition_key": payload.condition_key,
                "dispatched": False,
                "reason": "COOLDOWN_ACTIVE",
            }

        delivered_channels = []
        if "TOAST" in payload.channels:
            if self.send_toast(payload):
                delivered_channels.append("TOAST")

        if "EMAIL" in payload.channels:
            if self.send_email(payload, db):
                delivered_channels.append("EMAIL")

        self.mark_fired(payload.condition_key)

        return {
            "condition_key": payload.condition_key,
            "dispatched": True,
            "severity": payload.severity,
            "channels": delivered_channels,
            "title": payload.title,
            "target_tab": payload.target_tab,
        }

    def evaluate_all(
        self,
        db: Session,
        force: bool = False,
        disk_free_gb_override: Optional[float] = None,
        backup_age_hours_override: Optional[float] = None,
        offsite_age_hours_override: Optional[float] = None,
        probe_override: Optional[Dict[str, Any]] = None,
    ) -> List[Dict[str, Any]]:
        """
        Runs deep health and domain radar probes, evaluates all conditions (including offsite backup),
        and fires mapped alerts for any detected failure state.
        """
        results = []

        # 1. Probe Evaluation
        from modules.system_observability.service import DeepHealthProbeService, DomainRadarService, slow_query_tracker

        probe_res = DeepHealthProbeService.run_probe(db)
        radar_res = DomainRadarService.get_radar(db)

        # Allow test overrides for Part B failure verification
        free_gb = disk_free_gb_override if disk_free_gb_override is not None else probe_res.free_disk_space_gb
        verdict = probe_override.get("verdict", probe_res.verdict) if probe_override else probe_res.verdict
        probe_issues = probe_override.get("issues", probe_res.issues) if probe_override else probe_res.issues

        # Calculate local backup age
        backup_age = 0.0
        if backup_age_hours_override is not None:
            backup_age = backup_age_hours_override
        else:
            backups_dir = BACKUPS_DIR
            if backups_dir.exists():
                b_files = sorted(backups_dir.glob("daily_backup_*.db"), key=lambda p: p.stat().st_mtime, reverse=True)
                if b_files:
                    mtime = datetime.fromtimestamp(b_files[0].stat().st_mtime, tz=timezone.utc)
                    backup_age = (datetime.now(timezone.utc) - mtime).total_seconds() / 3600.0
                else:
                    backup_age = 999.0
            else:
                backup_age = 999.0

        # Calculate offsite backup age (Google Drive Desktop sync folder)
        offsite_age = None
        if offsite_age_hours_override is not None:
            offsite_age = offsite_age_hours_override
        else:
            env_offsite = os.getenv("GOOGLE_DRIVE_BACKUP_DIR")
            offsite_dir = None
            if env_offsite and Path(env_offsite).exists():
                offsite_dir = Path(env_offsite)
            else:
                candidates = [
                    BACKUPS_DIR / "sandbox_drive" / "SorourLogistics-Backups",
                    Path("G:/My Drive/SorourLogistics-Backups"),
                    Path(os.path.expanduser("~")) / "Google Drive" / "SorourLogistics-Backups",
                ]
                for c in candidates:
                    if c.exists():
                        offsite_dir = c
                        break

            if offsite_dir and offsite_dir.exists():
                offsite_files = sorted(offsite_dir.glob("daily_backup_*.db"), key=lambda p: p.stat().st_mtime, reverse=True)
                if offsite_files:
                    mtime = datetime.fromtimestamp(offsite_files[0].stat().st_mtime, tz=timezone.utc)
                    offsite_age = (datetime.now(timezone.utc) - mtime).total_seconds() / 3600.0
                else:
                    offsite_age = 999.0

        # ── Rule 1: Local Backup missing/failed (>26h) ──────────────
        if backup_age > 26.0:
            payload = AlertPayload(
                condition_key="BACKUP_OVERDUE",
                title=None,
                message=None,
                msg=sys_msg("ALERT_BACKUP_OVERDUE", hours=round(backup_age, 1)),
                severity="HIGH",
                channels=["TOAST", "EMAIL"],
                target_tab="deep-health",
                details={"backup_age_hours": backup_age},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))

        # ── Rule 1b: Offsite Backup missing/failed (>26h) ───────────
        if offsite_age is not None and offsite_age > 26.0:
            payload = AlertPayload(
                condition_key="OFFSITE_BACKUP_OVERDUE",
                title=None,
                message=None,
                msg=sys_msg("ALERT_OFFSITE_BACKUP_OVERDUE", hours=round(offsite_age, 1)),
                severity="HIGH",
                channels=["TOAST", "EMAIL"],
                target_tab="deep-health",
                details={"offsite_age_hours": offsite_age},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))

        # ── Rule 2 & 3: Disk Space (< 2GB Critical, < 5GB Warning) ──
        if free_gb < 2.0:
            payload = AlertPayload(
                condition_key="DISK_SPACE_CRITICAL",
                title=None,
                message=None,
                msg=sys_msg("ALERT_DISK_CRITICAL", free_gb=round(free_gb, 2)),
                severity="CRITICAL",
                channels=["TOAST"],
                target_tab="deep-health",
                details={"free_gb": free_gb},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))
        elif free_gb < 5.0:
            payload = AlertPayload(
                condition_key="DISK_SPACE_WARNING",
                title=None,
                message=None,
                msg=sys_msg("ALERT_DISK_LOW", free_gb=round(free_gb, 2)),
                severity="HIGH",
                channels=["TOAST", "EMAIL"],
                target_tab="deep-health",
                details={"free_gb": free_gb},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))

        # ── Rule 4: DB deep health check verdict != HEALTHY ─────────
        if verdict != "HEALTHY":
            payload = AlertPayload(
                condition_key="DB_HEALTH_UNHEALTHY",
                title=None,
                message=None,
                msg=sys_msg(
                    "ALERT_DB_HEALTH_DEGRADED",
                    verdict_enum_db_health_verdict=str(verdict),
                    issues=", ".join(str(i) for i in probe_issues) if probe_issues else "Unknown issues",
                ),
                severity="HIGH",
                channels=["TOAST", "EMAIL"],
                target_tab="deep-health",
                details={"verdict": verdict, "issues": probe_issues},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))

        # ── Rule 5: ACID expiring within 7 days ─────────────────────
        if radar_res.expiring_acids_count > 0:
            acid_codes = [a["acid_number"] for a in radar_res.expiring_acids[:5]]
            payload = AlertPayload(
                condition_key="ACID_EXPIRING",
                title=None,
                message=None,
                msg=sys_msg(
                    "ALERT_ACID_EXPIRY_RADAR",
                    count=radar_res.expiring_acids_count,
                    acid_numbers=", ".join(str(a) for a in acid_codes),
                ),
                severity="MEDIUM",
                channels=["EMAIL"],
                target_tab="domain-radar",
                details={"count": radar_res.expiring_acids_count, "acids": acid_codes},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))

        # ── Rule 6: Demurrage free-time < 48h ───────────────────────
        if radar_res.demurrage_risks_count > 0:
            cntrs = [d["container_number"] for d in radar_res.demurrage_risks[:5]]
            payload = AlertPayload(
                condition_key="DEMURRAGE_RISK",
                title=None,
                message=None,
                msg=sys_msg(
                    "ALERT_DEMURRAGE_RISK",
                    count=radar_res.demurrage_risks_count,
                    container_numbers=", ".join(str(c) for c in cntrs),
                ),
                severity="MEDIUM",
                channels=["EMAIL"],
                target_tab="domain-radar",
                details={"count": radar_res.demurrage_risks_count, "containers": cntrs},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))

        # ── Rule 7: Shipment stuck in same stage > 10 days ──────────
        if radar_res.stuck_shipments_count > 0:
            stuck_codes = [s["file_code"] for s in radar_res.stuck_shipments[:5]]
            payload = AlertPayload(
                condition_key="STUCK_SHIPMENT",
                title=None,
                message=None,
                msg=sys_msg(
                    "ALERT_STUCK_SHIPMENTS",
                    count=radar_res.stuck_shipments_count,
                    import_file_codes=", ".join(str(c) for c in stuck_codes),
                ),
                severity="MEDIUM",
                channels=["EMAIL"],
                target_tab="domain-radar",
                details={"count": radar_res.stuck_shipments_count, "files": stuck_codes},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))

        # ── Rule 8: Slow query rate spikes (> 10/hour) ──────────────
        slow_count = slow_query_tracker.total_slow_queries_count
        if slow_count >= 10:
            payload = AlertPayload(
                condition_key="SLOW_QUERY_SPIKE",
                title=None,
                message=None,
                msg=sys_msg("ALERT_SLOW_QUERY_SPIKE", count=slow_count),
                severity="LOW",
                channels=["EMAIL"],
                target_tab="telemetry",
                details={"total_slow_queries": slow_count},
            )
            results.append(self.dispatch_alert(payload, db=db, force=force))

        return results


alert_dispatcher = AlertDispatcher()
