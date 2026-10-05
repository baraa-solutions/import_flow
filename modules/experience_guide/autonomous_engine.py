"""
Autonomous Learning & Self-Building Reference Engine (محرك التعلم الذاتي وبناء المرجعية التلقائي)
Module: KB-GUIDE-012 Section 5A
Autonomously mines historical and operational shipment data across 6 dimensions,
derives operational reference knowledge, computes statistical confidence, tracks provenance,
and manages the lifecycle (detection, continuous update, automated retirement).
"""
import json
import logging
from datetime import datetime, timezone, date
from typing import List, Dict, Any, Optional, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, and_, desc

from modules.experience_guide.model import GuideEntry, GuideEntryScope, AutonomousPatternAuditLog
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.freight_booking.model import ShipmentBooking
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.docs_customs_approval.model import DiscrepancyRectificationTicket
from modules.common import enum_codes
from modules.common.system_messages import SysMsg, msg, render_en

logger = logging.getLogger(__name__)

# Minimum thresholds for autonomous surfacing (Section 5A.3)
MIN_SAMPLE_SIZE = 2
MIN_CONFIDENCE_THRESHOLD = 0.60

# Language-independent defaults (single-language storage): codes / ISO-like values, never UI text.
DEFAULT_DISCREPANCY_CATEGORY = "Other"  # one of the ticket issue_category values
DEFAULT_PRODUCT_CATEGORY = "GENERAL_CARGO"
DEFAULT_REGULATORY_BODY = "GOEIC"

_GUIDE_PARTS = {"title": "title", "content": "body", "evidence_summary": "evidence", "reason_why": "reason"}


def guide_texts(m: SysMsg, **english_overrides: Any) -> Dict[str, str]:
    """English render of a guide message for the legacy text columns.

    ``english_overrides`` replace params for the English text only (for example the month NAME for the
    ``month`` number param); ``m.params`` keeps the language-independent values the UI localizes.
    """
    params = dict(m.params)
    params.update(english_overrides)
    return {field: render_en(m.code, params, part) for field, part in _GUIDE_PARTS.items()}


class CandidatePattern:
    """Represents a statistically discovered operational pattern."""
    def __init__(
        self,
        pattern_key: str,
        category: str,
        title: str,
        content: str,
        severity: str,
        entry_type: str,
        sample_size: int,
        matched_cases: int,
        evidence_summary: str,
        reason_why: str,
        contributing_files: List[Dict[str, Any]],
        scopes: List[Tuple[str, str]],
        msg: Optional[SysMsg] = None,
    ):
        self.msg = msg
        self.pattern_key = pattern_key
        self.category = category
        self.title = title
        self.content = content
        self.severity = severity
        self.entry_type = entry_type
        self.sample_size = sample_size
        self.matched_cases = matched_cases
        self.evidence_summary = evidence_summary
        self.reason_why = reason_why
        self.contributing_files = contributing_files
        self.scopes = scopes

    def calculate_confidence(self) -> Tuple[float, str]:
        """
        Calibrated confidence formula:
        Consistency = matched_cases / sample_size
        Sample Factor = N / (N + 1.0)
        Confidence = min(0.98, (N / (N + 1.0)) * Consistency)
        """
        if self.sample_size < 1:
            return 0.0, "LOW"
        consistency = self.matched_cases / self.sample_size
        sample_factor = self.sample_size / (self.sample_size + 1.0)
        score = round(min(0.98, sample_factor * consistency), 2)
        if score >= 0.80:
            level = "HIGH"
        elif score >= 0.65:
            level = "MEDIUM"
        else:
            level = "LOW"
        return score, level


class AutonomousLearningEngine:
    """
    Statistically mines closed and active shipments across 6 operational categories.
    """

    @classmethod
    def mine_supplier_delivery_reliability(cls, db: Session) -> List[CandidatePattern]:
        """
        Dimension 1: Delivery reliability per supplier.
        Compares contractual PO delivery date vs actual cargo ready date / departure date.
        """
        patterns: List[CandidatePattern] = []
        try:
            # Query shipments linked to suppliers with delivery dates
            files = db.query(ImportFile).filter(
                ImportFile.supplier_name.isnot(None),
                ImportFile.is_active == True,
            ).all()

            # Group by supplier_name
            supplier_files: Dict[str, List[ImportFile]] = {}
            for f in files:
                name = (f.supplier_name or "").strip()
                if len(name) >= 3:
                    supplier_files.setdefault(name, []).append(f)

            for supplier_name, file_list in supplier_files.items():
                if len(file_list) < MIN_SAMPLE_SIZE:
                    continue

                total_shipments = len(file_list)
                delayed_files: List[Dict[str, Any]] = []
                total_delay_days = 0

                for f in file_list:
                    # Check linked PO expected delivery date vs cargo ready date
                    po = db.query(PurchaseOrder).filter(PurchaseOrder.import_file_id == f.import_file_id).first()
                    expected_date: Optional[date] = None
                    if po and po.expected_delivery_date:
                        expected_date = po.expected_delivery_date.date() if isinstance(po.expected_delivery_date, datetime) else po.expected_delivery_date

                    actual_date = f.cargo_ready_date

                    delay = 0
                    if expected_date and actual_date:
                        delta = (actual_date - expected_date).days
                        if delta > 0:
                            delay = delta
                    elif f.vessel_name or f.bl_number:
                        # Check freight booking departure delay
                        booking = db.query(ShipmentBooking).filter(ShipmentBooking.import_file_id == f.import_file_id).first()
                        if booking and booking.departure_delay_days and booking.departure_delay_days > 2:
                            delay = booking.departure_delay_days

                    if delay >= 3:
                        total_delay_days += delay
                        delayed_files.append({
                            "import_file_id": f.import_file_id,
                            "import_file_code": f.import_file_code,
                            "metric_measured": f"+{delay} days delay",
                            "expected_date": str(expected_date) if expected_date else None,
                            "actual_date": str(actual_date) if actual_date else None,
                            "file_status": f.status,
                        })

                if len(delayed_files) >= MIN_SAMPLE_SIZE:
                    avg_delay = round(total_delay_days / len(delayed_files), 1)
                    pct = int(round((len(delayed_files) / total_shipments) * 100))
                    pattern_key = f"DELIVERY_RELIABILITY:SUPPLIER:{supplier_name.lower()}"
                    guide_msg = msg(
                        "GUIDE_SUPPLIER_DELAY",
                        supplier_name=supplier_name,
                        avg_delay_days=avg_delay,
                        frequency_pct=pct,
                        delayed_count=len(delayed_files),
                        total_shipment_count=total_shipments,
                    )
                    texts = guide_texts(guide_msg)
                    title, content = texts["title"], texts["content"]
                    evidence_summary, reason_why = texts["evidence_summary"], texts["reason_why"]
                    severity = "critical" if avg_delay >= 10 else "warning"

                    patterns.append(CandidatePattern(
                        pattern_key=pattern_key,
                        category="DELIVERY_RELIABILITY",
                        title=title,
                        content=content,
                        severity=severity,
                        entry_type="alert",
                        sample_size=total_shipments,
                        matched_cases=len(delayed_files),
                        evidence_summary=evidence_summary,
                        reason_why=reason_why,
                        contributing_files=delayed_files,
                        msg=guide_msg,
                        scopes=[("supplier", supplier_name), ("pattern_key", pattern_key)],
                    ))
        except Exception as e:
            logger.warning("Error mining supplier delivery reliability: %s", e)
        return patterns

    @classmethod
    def mine_carrier_transit_accuracy(cls, db: Session) -> List[CandidatePattern]:
        """
        Dimension 2: Transit time accuracy per carrier & route (POL - POD).
        Compares quoted transit days vs actual voyage duration.
        """
        patterns: List[CandidatePattern] = []
        try:
            bookings = db.query(ShipmentBooking).filter(
                ShipmentBooking.shipping_line_name.isnot(None),
                ShipmentBooking.shipping_line_name != "",
            ).all()

            # Group by (carrier, pod_name)
            carrier_routes: Dict[Tuple[str, str], List[ShipmentBooking]] = {}
            for b in bookings:
                c = (b.shipping_line_name or "").strip()
                pod = (b.pod_name or "Alexandria Port").strip()
                if len(c) >= 2:
                    carrier_routes.setdefault((c, pod), []).append(b)

            for (carrier, pod), b_list in carrier_routes.items():
                if len(b_list) < MIN_SAMPLE_SIZE:
                    continue

                total_shipments = len(b_list)
                delayed_transits: List[Dict[str, Any]] = []
                total_extra_days = 0

                for b in b_list:
                    quoted_transit = b.transit_time_days or 0
                    actual_transit = 0
                    if b.atd and b.eta:
                        actual_transit = (b.eta - b.atd).days
                    elif b.departure_delay_days and b.departure_delay_days > 2:
                        actual_transit = quoted_transit + b.departure_delay_days

                    extra = actual_transit - quoted_transit if quoted_transit > 0 else (b.departure_delay_days or 0)
                    if extra >= 3:
                        total_extra_days += extra
                        imp_code = "SHP-UNKNOWN"
                        if b.import_file_id:
                            f = db.query(ImportFile).filter(ImportFile.import_file_id == b.import_file_id).first()
                            if f:
                                imp_code = f.import_file_code
                        delayed_transits.append({
                            "booking_id": b.booking_id,
                            "import_file_id": b.import_file_id,
                            "import_file_code": imp_code,
                            "metric_measured": f"+{extra} days transit variance",
                            "carrier": carrier,
                            "route": f"{b.pol_name or 'POL'} -> {pod}",
                            "quoted_transit": quoted_transit,
                            "actual_transit": actual_transit,
                        })

                if len(delayed_transits) >= MIN_SAMPLE_SIZE:
                    avg_extra = round(total_extra_days / len(delayed_transits), 1)
                    pattern_key = f"TRANSIT_TIME_ACCURACY:LINE:{carrier.lower()}:POD:{pod.lower()}"
                    guide_msg = msg(
                        "GUIDE_TRANSIT_DEVIATION",
                        carrier_name=carrier,
                        port_name=pod,
                        avg_extra_days=avg_extra,
                        delayed_count=len(delayed_transits),
                        total_shipment_count=total_shipments,
                    )
                    texts = guide_texts(guide_msg)
                    title, content = texts["title"], texts["content"]
                    evidence_summary, reason_why = texts["evidence_summary"], texts["reason_why"]

                    patterns.append(CandidatePattern(
                        pattern_key=pattern_key,
                        category="TRANSIT_TIME_ACCURACY",
                        title=title,
                        content=content,
                        severity="warning",
                        entry_type="alert",
                        sample_size=total_shipments,
                        matched_cases=len(delayed_transits),
                        evidence_summary=evidence_summary,
                        reason_why=reason_why,
                        contributing_files=delayed_transits,
                        msg=guide_msg,
                        scopes=[("shipping_line", carrier), ("destination_port", pod), ("pattern_key", pattern_key)],
                    ))
        except Exception as e:
            logger.warning("Error mining carrier transit accuracy: %s", e)
        return patterns

    @classmethod
    def mine_reconciliation_failures(cls, db: Session) -> List[CandidatePattern]:
        """
        Dimension 3: Recurring reconciliation failures and documentation errors per supplier.
        """
        patterns: List[CandidatePattern] = []
        try:
            tickets = db.query(DiscrepancyRectificationTicket).all()
            if not tickets:
                return patterns

            # Group tickets by import_file_id -> supplier
            supplier_tickets: Dict[str, List[DiscrepancyRectificationTicket]] = {}
            for t in tickets:
                f = db.query(ImportFile).filter(ImportFile.import_file_id == t.import_file_id).first()
                if f and f.supplier_name:
                    s_name = f.supplier_name.strip()
                    supplier_tickets.setdefault(s_name, []).append(t)

            for supplier_name, t_list in supplier_tickets.items():
                if len(t_list) < MIN_SAMPLE_SIZE:
                    continue

                categories = [t.issue_category for t in t_list if t.issue_category]
                most_common_cat = max(set(categories), key=categories.count) if categories else DEFAULT_DISCREPANCY_CATEGORY

                evidence_files: List[Dict[str, Any]] = []
                for t in t_list:
                    f = db.query(ImportFile).filter(ImportFile.import_file_id == t.import_file_id).first()
                    evidence_files.append({
                        "ticket_id": t.ticket_id,
                        "import_file_id": t.import_file_id,
                        "import_file_code": f.import_file_code if f else "Unknown",
                        "metric_measured": f"Discrepancy: {t.issue_category}",
                        "description": t.description,
                        "status": t.status,
                    })

                total_supplier_files = db.query(ImportFile).filter(
                    ImportFile.supplier_name.ilike(f"%{supplier_name}%"),
                    ImportFile.is_active == True,
                ).count() or len(t_list)

                pattern_key = f"RECONCILIATION_FAILURES:SUPPLIER:{supplier_name.lower()}"
                guide_msg = msg(
                    "GUIDE_SUPPLIER_DOC_ERRORS",
                    supplier_name=supplier_name,
                    category=most_common_cat,
                    mismatch_count=len(t_list),
                )
                texts = guide_texts(guide_msg)
                title, content = texts["title"], texts["content"]
                evidence_summary, reason_why = texts["evidence_summary"], texts["reason_why"]

                patterns.append(CandidatePattern(
                    pattern_key=pattern_key,
                    category="RECONCILIATION_FAILURES",
                    title=title,
                    content=content,
                    severity="critical" if "hs code" in most_common_cat.lower() or "weight" in most_common_cat.lower() else "warning",
                    entry_type="alert",
                    sample_size=max(total_supplier_files, len(t_list)),
                    matched_cases=len(t_list),
                    evidence_summary=evidence_summary,
                    reason_why=reason_why,
                    contributing_files=evidence_files,
                    msg=guide_msg,
                    scopes=[("supplier", supplier_name), ("pattern_key", pattern_key)],
                ))
        except Exception as e:
            logger.warning("Error mining reconciliation failures: %s", e)
        return patterns

    @classmethod
    def mine_cost_variance_patterns(cls, db: Session) -> List[CandidatePattern]:
        """
        Dimension 4: Cost variance patterns (estimated vs actual landed costs).
        """
        patterns: List[CandidatePattern] = []
        try:
            files_with_variance = db.query(ImportFile).filter(
                ImportFile.actual_landed_cost_variance_pct.isnot(None),
                ImportFile.actual_landed_cost_variance_pct > 5.0,
                ImportFile.is_active == True,
            ).all()

            # Group by destination_port
            port_files: Dict[str, List[ImportFile]] = {}
            for f in files_with_variance:
                port = (f.port_of_discharge or "Alexandria Port").strip()
                port_files.setdefault(port, []).append(f)

            for port, f_list in port_files.items():
                if len(f_list) < MIN_SAMPLE_SIZE:
                    continue

                total_port_files = db.query(ImportFile).filter(
                    ImportFile.port_of_discharge.ilike(f"%{port}%"),
                    ImportFile.is_active == True,
                ).count() or len(f_list)

                variances = [f.actual_landed_cost_variance_pct for f in f_list if f.actual_landed_cost_variance_pct]
                avg_var = round(sum(variances) / len(variances), 1)

                evidence_files = [{
                    "import_file_id": f.import_file_id,
                    "import_file_code": f.import_file_code,
                    "metric_measured": f"+{f.actual_landed_cost_variance_pct:.1f}% Landed Cost Variance",
                    "variance_egp": f.actual_landed_cost_variance_egp,
                    "status": f.status,
                } for f in f_list]

                pattern_key = f"COST_VARIANCE:PORT:{port.lower()}"
                guide_msg = msg(
                    "GUIDE_PORT_COST_VARIANCE",
                    port_name=port,
                    avg_variance_pct=avg_var,
                    shipment_count=len(f_list),
                )
                texts = guide_texts(guide_msg)
                title, content = texts["title"], texts["content"]
                evidence_summary, reason_why = texts["evidence_summary"], texts["reason_why"]

                patterns.append(CandidatePattern(
                    pattern_key=pattern_key,
                    category="COST_VARIANCE",
                    title=title,
                    content=content,
                    severity="critical" if avg_var >= 20.0 else "warning",
                    entry_type="alert",
                    sample_size=total_port_files,
                    matched_cases=len(f_list),
                    evidence_summary=evidence_summary,
                    reason_why=reason_why,
                    contributing_files=evidence_files,
                    msg=guide_msg,
                    scopes=[("destination_port", port), ("pattern_key", pattern_key)],
                ))
        except Exception as e:
            logger.warning("Error mining cost variance patterns: %s", e)
        return patterns

    @classmethod
    def mine_seasonal_congestion_effects(cls, db: Session) -> List[CandidatePattern]:
        """
        Dimension 5: Seasonal & Timing slowdown effects (e.g. Q3 peak season, Q1 holiday cycles).
        """
        patterns: List[CandidatePattern] = []
        try:
            closed_files = db.query(ImportFile).filter(
                ImportFile.status.in_(["Closed", "In Progress"]),
                ImportFile.is_active == True,
            ).all()

            # Group files by month of opening/creation
            month_shipments: Dict[int, List[ImportFile]] = {}
            for f in closed_files:
                dt = f.file_opening_date or (f.created_at.date() if f.created_at else None)
                if dt:
                    month_shipments.setdefault(dt.month, []).append(f)

            # Months with a known seasonal congestion (holidays / Chinese New Year / Q3 peak / year-end closures).
            congestion_months = {1, 2, 7, 8, 9, 12}

            for month, f_list in month_shipments.items():
                if month not in congestion_months or len(f_list) < MIN_SAMPLE_SIZE:
                    continue

                evidence_files = [{
                    "import_file_id": f.import_file_id,
                    "import_file_code": f.import_file_code,
                    "metric_measured": f"Opened in month {month}",
                    "status": f.status,
                } for f in f_list]

                pattern_key = f"SEASONAL_EFFECTS:MONTH:{month}"
                # ``month`` param = month number (the UI renders the localized month name).
                guide_msg = msg("GUIDE_SEASONAL_CONGESTION", month=month, shipment_count=len(f_list))
                texts = guide_texts(guide_msg)
                title, content = texts["title"], texts["content"]
                evidence_summary, reason_why = texts["evidence_summary"], texts["reason_why"]

                patterns.append(CandidatePattern(
                    pattern_key=pattern_key,
                    category="SEASONAL_EFFECTS",
                    title=title,
                    content=content,
                    severity="info",
                    entry_type="info",
                    sample_size=len(f_list),
                    matched_cases=len(f_list),
                    evidence_summary=evidence_summary,
                    reason_why=reason_why,
                    contributing_files=evidence_files,
                    msg=guide_msg,
                    scopes=[("season_timing", f"Month-{month}"), ("pattern_key", pattern_key)],
                ))
        except Exception as e:
            logger.warning("Error mining seasonal effects: %s", e)
        return patterns

    @classmethod
    def mine_documentation_risk_correlations(cls, db: Session) -> List[CandidatePattern]:
        """
        Dimension 6: Regulatory inspections & Red Channel holds per HS Code and Product Category.
        """
        patterns: List[CandidatePattern] = []
        try:
            records = db.query(CustomsClearanceRecord).filter(
                or_(
                    CustomsClearanceRecord.channel_type.ilike("%red%"),
                    CustomsClearanceRecord.is_sample_drawn == True,
                )
            ).all()

            if not records:
                return patterns

            # Group by HS Code
            hs_records: Dict[str, List[Tuple[CustomsClearanceRecord, ImportFile]]] = {}
            for r in records:
                f = db.query(ImportFile).filter(ImportFile.import_file_id == r.import_file_id).first()
                if f and f.hs_code:
                    code = f.hs_code.strip()
                    hs_records.setdefault(code, []).append((r, f))

            for hs_code, pairs in hs_records.items():
                if len(pairs) < MIN_SAMPLE_SIZE:
                    continue

                total_hs_files = db.query(ImportFile).filter(
                    ImportFile.hs_code == hs_code,
                    ImportFile.is_active == True,
                ).count() or len(pairs)

                first_file = pairs[0][1]
                prod_cat = first_file.product_category or DEFAULT_PRODUCT_CATEGORY

                # Extract regulatory bodies
                all_bodies = set()
                for r, _ in pairs:
                    if r.regulatory_bodies and isinstance(r.regulatory_bodies, list):
                        all_bodies.update(r.regulatory_bodies)
                body_codes = sorted(
                    {str(b) for b in (enum_codes.normalize_list(enum_codes.REGULATORY_BODY, list(all_bodies)) or [])}
                ) or [DEFAULT_REGULATORY_BODY]
                bodies_str = ", ".join(body_codes)

                evidence_files = [{
                    "clearance_id": r.customs_clearance_id,
                    "import_file_id": f.import_file_id,
                    "import_file_code": f.import_file_code,
                    "metric_measured": f"{r.channel_type} - Sample: {r.is_sample_drawn}",
                    "regulatory_bodies": r.regulatory_bodies,
                    "inspection_result": r.inspection_result,
                } for r, f in pairs]

                pattern_key = f"DOCUMENTATION_RISK:HS:{hs_code}"
                guide_msg = msg(
                    "GUIDE_HS_LAB_INSPECTION",
                    hs_code=hs_code,
                    product_category=prod_cat,
                    regulatory_bodies_enum_regulatory_body=bodies_str,
                    shipment_count=len(pairs),
                )
                texts = guide_texts(guide_msg)
                title, content = texts["title"], texts["content"]
                evidence_summary, reason_why = texts["evidence_summary"], texts["reason_why"]

                patterns.append(CandidatePattern(
                    pattern_key=pattern_key,
                    category="DOCUMENTATION_RISK",
                    title=title,
                    content=content,
                    severity="warning",
                    entry_type="alert",
                    sample_size=total_hs_files,
                    matched_cases=len(pairs),
                    evidence_summary=evidence_summary,
                    reason_why=reason_why,
                    contributing_files=evidence_files,
                    msg=guide_msg,
                    scopes=[("hs_code", hs_code), ("product_category", prod_cat), ("pattern_key", pattern_key)],
                ))
        except Exception as e:
            logger.warning("Error mining documentation risk correlations: %s", e)
        return patterns

    @classmethod
    def run_full_autonomous_cycle(
        cls,
        db: Session,
        trigger_import_file_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Executes continuous statistical mining across all 6 dimensions,
        evaluates confidence against threshold, updates existing notes,
        auto-retires degraded notes, and records audit logs.
        """
        now = datetime.now(timezone.utc)
        all_candidates: List[CandidatePattern] = []

        all_candidates.extend(cls.mine_supplier_delivery_reliability(db))
        all_candidates.extend(cls.mine_carrier_transit_accuracy(db))
        all_candidates.extend(cls.mine_reconciliation_failures(db))
        all_candidates.extend(cls.mine_cost_variance_patterns(db))
        all_candidates.extend(cls.mine_seasonal_congestion_effects(db))
        all_candidates.extend(cls.mine_documentation_risk_correlations(db))

        patterns_detected = 0
        patterns_updated = 0
        patterns_archived = 0

        active_pattern_keys = set()

        for cand in all_candidates:
            confidence, confidence_level = cand.calculate_confidence()
            active_pattern_keys.add(cand.pattern_key)

            # Query existing entry by pattern_key scope
            existing_scope = (
                db.query(GuideEntryScope)
                .filter(
                    GuideEntryScope.scope_type == "pattern_key",
                    GuideEntryScope.scope_value == cand.pattern_key,
                )
                .first()
            )

            existing_entry = existing_scope.guide_entry if existing_scope else None

            if existing_entry:
                # If human rejected it, NEVER override human rejection
                if existing_entry.status == "REJECTED":
                    continue

                prev_conf = existing_entry.confidence_score

                # If confidence dropped below threshold or sample size < MIN_SAMPLE_SIZE
                if confidence < MIN_CONFIDENCE_THRESHOLD or cand.sample_size < MIN_SAMPLE_SIZE:
                    if existing_entry.status != "CONFIRMED":
                        # Auto-retire
                        existing_entry.status = "ARCHIVED"
                        existing_entry.is_active = False
                        existing_entry.confidence_score = confidence
                        existing_entry.confidence_level = confidence_level
                        existing_entry.sample_size = cand.sample_size
                        existing_entry.last_recalculated_at = now
                        patterns_archived += 1

                        # Audit log
                        db.add(AutonomousPatternAuditLog(
                            entry_id=existing_entry.entry_id,
                            pattern_key=cand.pattern_key,
                            trigger_import_file_id=trigger_import_file_id,
                            action="AUTO_RETIRED",
                            previous_confidence=prev_conf,
                            new_confidence=confidence,
                            sample_size=cand.sample_size,
                            change_summary=f"Confidence dropped to {confidence:.2f} (< {MIN_CONFIDENCE_THRESHOLD}). Auto-retired.",
                            created_at=now,
                        ))
                else:
                    # Update active or confirmed entry
                    existing_entry.confidence_score = confidence
                    existing_entry.confidence_level = confidence_level
                    existing_entry.sample_size = cand.sample_size
                    existing_entry.evidence_summary = cand.evidence_summary
                    existing_entry.contributing_files_json = json.dumps(cand.contributing_files, ensure_ascii=False)
                    existing_entry.reason_why = cand.reason_why
                    existing_entry.last_recalculated_at = now
                    # Do not overwrite title/content if user confirmed/edited
                    if existing_entry.status != "CONFIRMED":
                        existing_entry.title = cand.title
                        existing_entry.content = cand.content
                        existing_entry.msg_code = cand.msg.code if cand.msg else None
                        existing_entry.msg_params = cand.msg.params if cand.msg else None
                        existing_entry.severity = cand.severity
                        existing_entry.status = "ACTIVE"
                        existing_entry.is_active = True

                    patterns_updated += 1

                    if prev_conf is None or abs((prev_conf or 0.0) - confidence) >= 0.05:
                        db.add(AutonomousPatternAuditLog(
                            entry_id=existing_entry.entry_id,
                            pattern_key=cand.pattern_key,
                            trigger_import_file_id=trigger_import_file_id,
                            action="CONFIDENCE_UPDATED",
                            previous_confidence=prev_conf,
                            new_confidence=confidence,
                            sample_size=cand.sample_size,
                            change_summary=f"Confidence recalculated: {prev_conf or 0.0:.2f} -> {confidence:.2f} across {cand.sample_size} shipments.",
                            created_at=now,
                        ))
            else:
                # New entry candidate - only surface if meets minimum thresholds
                if confidence >= MIN_CONFIDENCE_THRESHOLD and cand.sample_size >= MIN_SAMPLE_SIZE:
                    new_entry = GuideEntry(
                        title=cand.title,
                        content=cand.content,
                        entry_type=cand.entry_type,
                        severity=cand.severity,
                        department="Autonomous Reference Engine",
                        created_by="Autonomous Engine (Section 5A)",
                        is_active=True,
                        source_type="SYSTEM_INFERRED",
                        status="ACTIVE",
                        pattern_category=cand.category,
                        confidence_score=confidence,
                        confidence_level=confidence_level,
                        sample_size=cand.sample_size,
                        evidence_summary=cand.evidence_summary,
                        contributing_files_json=json.dumps(cand.contributing_files, ensure_ascii=False),
                        reason_why=cand.reason_why,
                        msg_code=cand.msg.code if cand.msg else None,
                        msg_params=cand.msg.params if cand.msg else None,
                        first_detected_at=now,
                        last_recalculated_at=now,
                    )
                    db.add(new_entry)
                    db.flush()

                    # Add scopes
                    for st, sv in cand.scopes:
                        db.add(GuideEntryScope(
                            guide_entry_id=new_entry.entry_id,
                            scope_type=st,
                            scope_value=sv,
                        ))

                    patterns_detected += 1

                    db.add(AutonomousPatternAuditLog(
                        entry_id=new_entry.entry_id,
                        pattern_key=cand.pattern_key,
                        trigger_import_file_id=trigger_import_file_id,
                        action="DETECTED_NEW",
                        previous_confidence=None,
                        new_confidence=confidence,
                        sample_size=cand.sample_size,
                        change_summary=f"New operational pattern detected with confidence {confidence:.2f} ({confidence_level}) on sample of {cand.sample_size} shipments.",
                        created_at=now,
                    ))

        # Check existing SYSTEM_INFERRED notes whose pattern is no longer observed
        old_inferred = (
            db.query(GuideEntry)
            .filter(
                GuideEntry.source_type == "SYSTEM_INFERRED",
                GuideEntry.status == "ACTIVE",
            )
            .all()
        )
        for old in old_inferred:
            p_scope = next((s for s in old.scopes if s.scope_type == "pattern_key"), None)
            if p_scope and p_scope.scope_value not in active_pattern_keys:
                old.status = "ARCHIVED"
                old.is_active = False
                old.last_recalculated_at = now
                patterns_archived += 1
                db.add(AutonomousPatternAuditLog(
                    entry_id=old.entry_id,
                    pattern_key=p_scope.scope_value,
                    trigger_import_file_id=trigger_import_file_id,
                    action="AUTO_RETIRED",
                    previous_confidence=old.confidence_score,
                    new_confidence=0.0,
                    sample_size=old.sample_size or 0,
                    change_summary="Pattern no longer present in active sample. Auto-retired.",
                    created_at=now,
                ))

        db.commit()

        summary = (
            f"Autonomous Cycle Completed: {patterns_detected} new patterns detected, "
            f"{patterns_updated} patterns updated, {patterns_archived} patterns auto-retired."
        )
        logger.info(summary)
        return {
            "status": "success",
            "patterns_detected": patterns_detected,
            "patterns_updated": patterns_updated,
            "patterns_archived": patterns_archived,
            "summary": summary,
        }
