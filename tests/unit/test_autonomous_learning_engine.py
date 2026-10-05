"""
Unit tests for Autonomous Learning & Self-Building Reference Engine (KB-GUIDE-012 Section 5A)
Tests statistical mining across 6 dimensions, calibrated confidence scoring,
evidence provenance, automated retirement, and promotion/rejection lifecycle.
"""
import json
import pytest
from datetime import datetime, date, timezone, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.experience_guide.model import GuideEntry, GuideEntryScope, AutonomousPatternAuditLog
from modules.experience_guide.schemas import (
    GuideEntryPromoteRequest,
    GuideEntryRejectRequest,
    GuideMatchRequest,
)
from modules.experience_guide.service import ExperienceGuideService
from modules.experience_guide.autonomous_engine import (
    AutonomousLearningEngine,
    CandidatePattern,
    MIN_SAMPLE_SIZE,
    MIN_CONFIDENCE_THRESHOLD,
)
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.freight_booking.model import ShipmentBooking
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.docs_customs_approval.model import DiscrepancyRectificationTicket


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_confidence_formula_calibration():
    """Verify confidence score and level calculations across sample sizes."""
    # N = 1 (below minimum sample size)
    p1 = CandidatePattern("key1", "DELIVERY", "Title", "Content", "warning", "alert", 1, 1, "Evidence", "Reason", [], [])
    score1, level1 = p1.calculate_confidence()
    assert score1 < 0.60
    assert level1 == "LOW"

    # N = 2, 100% consistency (2 / (2 + 1) * 1.0 = 0.667 -> 0.67)
    p2 = CandidatePattern("key2", "DELIVERY", "Title", "Content", "warning", "alert", 2, 2, "Evidence", "Reason", [], [])
    score2, level2 = p2.calculate_confidence()
    assert score2 >= 0.60
    assert score2 == 0.67
    assert level2 == "MEDIUM"

    # N = 5, 100% consistency (5 / 6 * 1.0 = 0.833 -> 0.83)
    p5 = CandidatePattern("key5", "DELIVERY", "Title", "Content", "warning", "alert", 5, 5, "Evidence", "Reason", [], [])
    score5, level5 = p5.calculate_confidence()
    assert score5 >= 0.80
    assert level5 == "HIGH"


def test_autonomous_mining_supplier_delivery_reliability(db_session):
    """Test Dimension 1: Supplier delivery delays mining."""
    # Seed 3 shipments for supplier "Suzhou Acoustic Tech" with delays
    f1 = ImportFile(
        import_file_code="IMP-2026-DELIV-01",
        company_name="Delta Acoustics Egypt",
        supplier_name="Suzhou Acoustic Tech",
        cargo_ready_date=date(2026, 5, 20),
        status="Closed",
        is_active=True,
    )
    f2 = ImportFile(
        import_file_code="IMP-2026-DELIV-02",
        company_name="Delta Acoustics Egypt",
        supplier_name="Suzhou Acoustic Tech",
        cargo_ready_date=date(2026, 6, 25),
        status="Closed",
        is_active=True,
    )
    db_session.add_all([f1, f2])
    db_session.flush()

    # Add POs with expected delivery dates that were exceeded
    po1 = PurchaseOrder(
        po_number="PO-2026-901",
        import_file_id=f1.import_file_id,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        expected_delivery_date=datetime(2026, 5, 10, tzinfo=timezone.utc), # 10 days delay
    )
    po2 = PurchaseOrder(
        po_number="PO-2026-902",
        import_file_id=f2.import_file_id,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        expected_delivery_date=datetime(2026, 6, 15, tzinfo=timezone.utc), # 10 days delay
    )
    db_session.add_all([po1, po2])
    db_session.commit()

    candidates = AutonomousLearningEngine.mine_supplier_delivery_reliability(db_session)
    assert len(candidates) == 1
    cand = candidates[0]
    assert cand.category == "DELIVERY_RELIABILITY"
    assert "Suzhou Acoustic Tech" in cand.title
    assert cand.sample_size == 2
    assert cand.matched_cases == 2
    assert len(cand.contributing_files) == 2


def test_autonomous_mining_carrier_transit_accuracy(db_session):
    """Test Dimension 2: Carrier transit accuracy per route."""
    b1 = ShipmentBooking(
        booking_code="BKG-MSC-01",
        shipping_line_name="MSC",
        pol_name="Shanghai Port",
        pod_name="Alexandria Port",
        transit_time_days=25,
        atd=datetime(2026, 3, 1, tzinfo=timezone.utc),
        eta=datetime(2026, 4, 3, tzinfo=timezone.utc), # 33 days -> +8 days variance
    )
    b2 = ShipmentBooking(
        booking_code="BKG-MSC-02",
        shipping_line_name="MSC",
        pol_name="Ningbo Port",
        pod_name="Alexandria Port",
        transit_time_days=25,
        atd=datetime(2026, 4, 1, tzinfo=timezone.utc),
        eta=datetime(2026, 5, 2, tzinfo=timezone.utc), # 31 days -> +6 days variance
    )
    db_session.add_all([b1, b2])
    db_session.commit()

    candidates = AutonomousLearningEngine.mine_carrier_transit_accuracy(db_session)
    assert len(candidates) == 1
    cand = candidates[0]
    assert cand.category == "TRANSIT_TIME_ACCURACY"
    assert "MSC" in cand.title
    assert cand.sample_size == 2


def test_autonomous_mining_reconciliation_failures(db_session):
    """Test Dimension 3: Recurring documentation/reconciliation discrepancy failures."""
    f1 = ImportFile(
        import_file_code="IMP-2026-REC-01",
        company_name="Delta Acoustics Egypt",
        supplier_name="Shenzhen Audio Ltd",
        status="In Progress",
        is_active=True,
    )
    f2 = ImportFile(
        import_file_code="IMP-2026-REC-02",
        company_name="Delta Acoustics Egypt",
        supplier_name="Shenzhen Audio Ltd",
        status="Closed",
        is_active=True,
    )
    db_session.add_all([f1, f2])
    db_session.flush()

    t1 = DiscrepancyRectificationTicket(
        ticket_code="TCK-REC-01",
        import_file_id=f1.import_file_id,
        issue_category="Weight Discrepancy",
        description="Gross weight discrepancy between PL and BL",
        status="Resolved",
    )
    t2 = DiscrepancyRectificationTicket(
        ticket_code="TCK-REC-02",
        import_file_id=f2.import_file_id,
        issue_category="Weight Discrepancy",
        description="Weight mismatch on invoice",
        status="Resolved",
    )
    db_session.add_all([t1, t2])
    db_session.commit()

    candidates = AutonomousLearningEngine.mine_reconciliation_failures(db_session)
    assert len(candidates) == 1
    cand = candidates[0]
    assert cand.category == "RECONCILIATION_FAILURES"
    assert "Shenzhen Audio Ltd" in cand.title
    assert cand.severity == "critical"  # Weight discrepancy classified as critical


def test_autonomous_mining_documentation_risk(db_session):
    """Test Dimension 6: Regulatory inspections & Red Channel holds per HS Code."""
    f1 = ImportFile(
        import_file_code="IMP-2026-REG-01",
        company_name="Delta Acoustics Egypt",
        supplier_name="Vendor A",
        hs_code="8518",
        product_category="Loudspeakers",
        status="Closed",
        is_active=True,
    )
    f2 = ImportFile(
        import_file_code="IMP-2026-REG-02",
        company_name="Delta Acoustics Egypt",
        supplier_name="Vendor B",
        hs_code="8518",
        product_category="Loudspeakers",
        status="Closed",
        is_active=True,
    )
    db_session.add_all([f1, f2])
    db_session.flush()

    c1 = CustomsClearanceRecord(
        clearance_code="CLR-REG-01",
        import_file_id=f1.import_file_id,
        channel_type="Red Channel",
        is_sample_drawn=True,
        regulatory_bodies=["GOEIC", "NTRA"],
        inspection_result="Conforming",
    )
    c2 = CustomsClearanceRecord(
        clearance_code="CLR-REG-02",
        import_file_id=f2.import_file_id,
        channel_type="Red Channel",
        is_sample_drawn=True,
        regulatory_bodies=["GOEIC"],
        inspection_result="Conforming",
    )
    db_session.add_all([c1, c2])
    db_session.commit()

    candidates = AutonomousLearningEngine.mine_documentation_risk_correlations(db_session)
    assert len(candidates) == 1
    cand = candidates[0]
    assert cand.category == "DOCUMENTATION_RISK"
    assert "8518" in cand.title
    assert cand.sample_size == 2


def test_full_autonomous_cycle_detection_and_matching(db_session):
    """Test full cycle execution, note creation, provenance and contextual matching."""
    service = ExperienceGuideService(db_session)

    # Seed 2 shipments with Landed Cost variance
    f1 = ImportFile(
        import_file_code="IMP-2026-COST-01",
        company_name="Delta Acoustics Egypt",
        supplier_name="Global Shipper",
        port_of_discharge="Dekheila Port",
        actual_landed_cost_variance_pct=15.0,
        actual_landed_cost_variance_egp=12000.0,
        status="Closed",
        is_active=True,
    )
    f2 = ImportFile(
        import_file_code="IMP-2026-COST-02",
        company_name="Delta Acoustics Egypt",
        supplier_name="Global Shipper",
        port_of_discharge="Dekheila Port",
        actual_landed_cost_variance_pct=18.0,
        actual_landed_cost_variance_egp=15000.0,
        status="Closed",
        is_active=True,
    )
    db_session.add_all([f1, f2])
    db_session.commit()

    # Run autonomous learning
    result = service.recalculate_autonomous()
    assert result.patterns_detected >= 1

    # Check generated GuideEntry
    entries = service.list_entries(source_type="SYSTEM_INFERRED")
    assert len(entries) >= 1
    cost_entry = next(e for e in entries if e.pattern_category == "COST_VARIANCE")
    assert cost_entry.source_type == "SYSTEM_INFERRED"
    assert cost_entry.status == "ACTIVE"
    assert cost_entry.confidence_score is not None
    assert cost_entry.confidence_score >= 0.60
    assert cost_entry.sample_size == 2
    assert cost_entry.is_system_inferred is True

    # Check Audit Log
    logs = service.get_autonomous_audit_logs()
    assert len(logs) >= 1
    assert any(l.action == "DETECTED_NEW" for l in logs)

    # Check Provenance
    prov = service.get_entry_provenance(cost_entry.entry_id)
    assert prov.entry_id == cost_entry.entry_id
    assert len(prov.contributing_files) == 2
    assert "Dekheila Port" in (prov.reason_why or "")

    # Match against active shipment for Dekheila Port
    match_res = service.match_shipment(GuideMatchRequest(destination_port="Dekheila Port"))
    assert len(match_res.matched_entries) >= 1
    assert any(e.entry_id == cost_entry.entry_id for e in match_res.matched_entries)


def test_human_promotion_and_rejection_workflow(db_session):
    """Test promoting inferred note to CONFIRMED and rejecting to REJECTED."""
    service = ExperienceGuideService(db_session)

    # Create dummy SYSTEM_INFERRED entry
    entry = GuideEntry(
        title="تأخير شحن افتراضي",
        content="ملاحظة مستنتجة آلياً للتجربة.",
        entry_type="alert",
        severity="warning",
        department="Autonomous Engine",
        source_type="SYSTEM_INFERRED",
        status="ACTIVE",
        confidence_score=0.75,
        confidence_level="MEDIUM",
        sample_size=3,
        is_active=True,
    )
    db_session.add(entry)
    db_session.commit()
    db_session.refresh(entry)

    # 1. Promote
    promoted = service.promote_inferred_entry(
        entry.entry_id,
        GuideEntryPromoteRequest(
            promoted_by="Eng. Ahmed",
            edited_title="معتمد: تأخير شحن مؤكد",
            edited_severity="critical",
        ),
    )
    assert promoted.status == "CONFIRMED"
    assert promoted.is_confirmed is True
    assert promoted.confirmed_by == "Eng. Ahmed"
    assert promoted.title == "معتمد: تأخير شحن مؤكد"
    assert promoted.severity == "critical"

    # Verify audit log recorded HUMAN_PROMOTED
    logs = service.get_autonomous_audit_logs(entry_id=entry.entry_id)
    assert any(l.action == "HUMAN_PROMOTED" for l in logs)

    # 2. Create another entry to reject
    entry2 = GuideEntry(
        title="استنتاج خاطئ",
        content="نمط غير دقيق.",
        entry_type="alert",
        severity="info",
        source_type="SYSTEM_INFERRED",
        status="ACTIVE",
        is_active=True,
    )
    db_session.add(entry2)
    db_session.commit()
    db_session.refresh(entry2)

    # Reject
    rejected = service.reject_inferred_entry(
        entry2.entry_id,
        GuideEntryRejectRequest(
            rejected_by="Eng. Ahmed",
            rejection_reason="تم الاتفاق مع المورد على تجاوز هذا التأخير بعقد جديد.",
        ),
    )
    assert rejected.status == "REJECTED"
    assert rejected.is_active is False
    assert rejected.rejected_by == "Eng. Ahmed"
    assert "بعقد جديد" in (rejected.rejection_reason or "")

    # Ensure rejected notes are NEVER surfaced in match_shipment
    match_res = service.match_shipment(GuideMatchRequest())
    assert not any(e.entry_id == entry2.entry_id for e in match_res.matched_entries)


def test_auto_retirement_when_confidence_degrades(db_session):
    """Test that notes falling below threshold are automatically retired to ARCHIVED."""
    service = ExperienceGuideService(db_session)

    # Create an active system-inferred entry with a pattern key scope
    entry = GuideEntry(
        title="نمط قديم مؤقت",
        content="تفاصيل النمط.",
        entry_type="alert",
        severity="warning",
        source_type="SYSTEM_INFERRED",
        status="ACTIVE",
        confidence_score=0.85,
        confidence_level="HIGH",
        sample_size=4,
        is_active=True,
    )
    db_session.add(entry)
    db_session.flush()

    scope = GuideEntryScope(
        guide_entry_id=entry.entry_id,
        scope_type="pattern_key",
        scope_value="SEASONAL_EFFECTS:MONTH:99", # Non-existent month
    )
    db_session.add(scope)
    db_session.commit()

    # Run autonomous cycle: pattern is no longer found in active data
    res = service.recalculate_autonomous()
    assert res.patterns_archived >= 1

    # Reload entry
    refreshed = service.get_entry(entry.entry_id)
    assert refreshed.status == "ARCHIVED"
    assert refreshed.is_active is False

    # Check audit log recorded AUTO_RETIRED
    logs = service.get_autonomous_audit_logs(entry_id=entry.entry_id)
    assert any(l.action == "AUTO_RETIRED" for l in logs)


# ── Single-language storage (Phase B): coded guide entries ───────────────────
def _has_arabic(text):
    return any("؀" <= ch <= "ۿ" for ch in (text or ""))


def test_documentation_risk_is_coded_with_regulatory_body_codes(db_session):
    files = []
    for i in range(2):
        f = ImportFile(import_file_code=f"IMP-HS-{i}", company_name="C", supplier_name="S", hs_code="8518",
                       status="Closed", is_active=True)
        db_session.add(f)
        db_session.flush()
        files.append(f)
    db_session.add_all([
        CustomsClearanceRecord(clearance_code="CLR-HS-0", import_file_id=files[0].import_file_id,
                               channel_type="Red Channel", is_sample_drawn=True,
                               regulatory_bodies=["الهيئة القومية لسلامة الغذاء (NFSA)"]),
        CustomsClearanceRecord(clearance_code="CLR-HS-1", import_file_id=files[1].import_file_id,
                               channel_type="Red Channel", is_sample_drawn=True, regulatory_bodies=["GOEIC"]),
    ])
    db_session.commit()

    cand = AutonomousLearningEngine.mine_documentation_risk_correlations(db_session)[0]
    assert cand.msg.code == "GUIDE_HS_LAB_INSPECTION"
    assert cand.msg.params == {
        "hs_code": "8518", "product_category": "GENERAL_CARGO", "regulatory_bodies_enum_regulatory_body": "GOEIC, NFSA", "shipment_count": 2,
    }
    assert "National Food Safety Authority (NFSA)" in cand.content  # English labels in the stored text
    for text in (cand.title, cand.content, cand.evidence_summary, cand.reason_why):
        assert text and not _has_arabic(text)


def test_seasonal_pattern_uses_month_number_param(db_session):
    for i in range(2):
        db_session.add(ImportFile(import_file_code=f"IMP-JUL-{i}", company_name="C", supplier_name="S",
                                  file_opening_date=date(2026, 7, 5 + i), status="Closed", is_active=True))
    db_session.commit()
    cands = [c for c in AutonomousLearningEngine.mine_seasonal_congestion_effects(db_session) if c.category == "SEASONAL_EFFECTS"]
    assert len(cands) == 1
    cand = cands[0]
    assert cand.msg.code == "GUIDE_SEASONAL_CONGESTION"
    assert cand.msg.params == {"month": 7, "shipment_count": 2}
    assert cand.title == "Seasonal shipment congestion in July"


def test_full_cycle_persists_code_and_user_edit_clears_it(db_session):
    service = ExperienceGuideService(db_session)
    for i in range(2):
        db_session.add(ImportFile(import_file_code=f"IMP-CV-{i}", company_name="C", supplier_name="S",
                                  port_of_discharge="Dekheila Port", actual_landed_cost_variance_pct=15.0 + i,
                                  actual_landed_cost_variance_egp=1000.0, status="Closed", is_active=True))
    db_session.commit()
    service.recalculate_autonomous()

    entry = db_session.query(GuideEntry).filter(GuideEntry.pattern_category == "COST_VARIANCE").one()
    assert entry.msg_code == "GUIDE_PORT_COST_VARIANCE"
    assert entry.msg_params["port_name"] == "Dekheila Port"
    assert entry.msg_params["shipment_count"] == 2
    assert not _has_arabic(entry.title + entry.content + entry.evidence_summary + entry.reason_why)

    # promote without edits keeps the code; an edited title replaces the system message
    service.promote_inferred_entry(entry.entry_id, GuideEntryPromoteRequest(promoted_by="qa"))
    db_session.refresh(entry)
    assert entry.msg_code == "GUIDE_PORT_COST_VARIANCE"


def test_promote_with_edited_title_clears_code(db_session):
    service = ExperienceGuideService(db_session)
    for i in range(2):
        db_session.add(ImportFile(import_file_code=f"IMP-CE-{i}", company_name="C", supplier_name="S",
                                  port_of_discharge="Sokhna Port", actual_landed_cost_variance_pct=15.0 + i,
                                  actual_landed_cost_variance_egp=1000.0, status="Closed", is_active=True))
    db_session.commit()
    service.recalculate_autonomous()
    entry = db_session.query(GuideEntry).filter(GuideEntry.pattern_category == "COST_VARIANCE").one()
    service.promote_inferred_entry(entry.entry_id, GuideEntryPromoteRequest(promoted_by="qa", edited_title="Sokhna cost check"))
    db_session.refresh(entry)
    assert entry.title == "Sokhna cost check"
    assert entry.msg_code is None and entry.msg_params is None
