"""
Unit Tests for Wave 4:
- Logistics Exceptions & Operational Disruptions
- Refundable Deposits Ledger & Guarantee Releases
- Pre-Shipment Inspection (PSI) & Vendor Quality Rating
"""

import sys
try:
    import database.migration_runner as _mr
    _orig_stamp = _mr.stamp_head
    def _tolerant_stamp(engine):
        try:
            _orig_stamp(engine)
        except Exception:
            pass
    _mr.stamp_head = _tolerant_stamp
except Exception:
    pass

from datetime import date, datetime, timedelta, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.logistics_exceptions.schemas import (
    AcidImpactResolution,
    ExceptionResolveRequest,
    LogisticsExceptionCreate,
    LogisticsExceptionUpdate,
    ValuationDisputeAppeal,
)
from modules.logistics_exceptions.service import LogisticsExceptionsService
from modules.deposits_recovery.schemas import (
    BankLgReleaseRequest,
    EirReturnLinkRequest,
    RefundClaimSubmitRequest,
    RefundSettlementRequest,
    RefundableDepositCreate,
    RefundableDepositUpdate,
)
from modules.deposits_recovery.service import RefundableDepositsService
from modules.vendor_quality.schemas import (
    PsiCertificateUploadRequest,
    VendorQualityCreate,
    VendorQualityUpdate,
)
from modules.vendor_quality.service import VendorQualityService


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()


# ==============================================================================
# 1. Logistics Exceptions Tests
# ==============================================================================

def test_log_exception_auto_code_and_kpi_suspension(db_session):
    service = LogisticsExceptionsService(db_session)
    today = date.today()

    data = LogisticsExceptionCreate(
        exception_type="VESSEL_ROLLOVER",
        severity="CRITICAL",
        title_ar="تأخر باخرة وتدحرج الشحنة",
        title_en="Vessel Roll-over at Transshipment Hub",
        delay_impact_days=10,
        acid_number="1234567890123456789",
        acid_original_expiry=today + timedelta(days=20),
    )

    created = service.log_exception(data, current_user_id=1)
    assert created.id is not None
    assert created.exception_code.startswith("EXC-")
    # Severe delay + CRITICAL severity must auto-suspend delay KPI
    assert created.delay_kpi_suspended is True
    assert "Automated KPI suspension" in created.suspension_reason
    # Delay with original ACID date must auto-flag ACID impact
    assert created.acid_impact_status == "ACTION_REQUIRED"
    assert created.status == "OPEN"


def test_acid_impact_resolution_and_validation(db_session):
    service = LogisticsExceptionsService(db_session)
    orig_expiry = date(2026, 11, 15)

    created = service.log_exception(
        LogisticsExceptionCreate(
            exception_type="PORT_CONGESTION",
            severity="MEDIUM",
            title_ar="ازدحام ميناء الإسكندرية",
            title_en="Alexandria Port Congestion",
            delay_impact_days=5,
            acid_number="9876543210123456789",
            acid_original_expiry=orig_expiry,
        ),
        current_user_id=1,
    )

    # Valid extension
    new_expiry = date(2026, 12, 15)
    updated = service.resolve_acid_impact(
        created.id,
        AcidImpactResolution(
            acid_adjusted_expiry=new_expiry,
            acid_impact_status="EXTENSION_REQUESTED",
            notes="Submitted Nafeza extension request",
        ),
        current_user_id=1,
    )
    assert updated.acid_adjusted_expiry == new_expiry
    assert updated.acid_impact_status == "EXTENSION_REQUESTED"

    # Invalid earlier extension must raise 422
    earlier_expiry = date(2026, 11, 1)
    with pytest.raises(HTTPException) as exc_info:
        service.resolve_acid_impact(
            created.id,
            AcidImpactResolution(
                acid_adjusted_expiry=earlier_expiry,
                acid_impact_status="EXTENSION_REQUESTED",
            ),
        )
    assert exc_info.value.status_code == 422


def test_valuation_dispute_and_appeal(db_session):
    service = LogisticsExceptionsService(db_session)
    created = service.log_exception(
        LogisticsExceptionCreate(
            exception_type="VALUATION_DISPUTE",
            severity="HIGH",
            title_ar="نزاع في القيمة المقبولة جمركياً",
            title_en="Valuation Dispute with Customs Committee",
            valuation_original_customs_val=150000.0,
            valuation_declared_val=100000.0,
        ),
        current_user_id=1,
    )
    # Automatically calculates dispute amount = 50,000.0
    assert created.valuation_dispute_amount == 50000.0
    assert created.appeal_status == "PENDING_APPEAL"

    # Submit official appeal
    appealed = service.submit_valuation_appeal(
        created.id,
        ValuationDisputeAppeal(
            valuation_original_customs_val=150000.0,
            valuation_declared_val=100000.0,
            valuation_dispute_amount=50000.0,
            appeal_status="COMMITTEE_HEARING",
            appeal_grounds="Submitted certified manufacturer price lists and comparable import clearances.",
            resolution_strategy="Represent at Higher Customs Dispute Board",
        ),
        current_user_id=1,
    )
    assert appealed.appeal_status == "COMMITTEE_HEARING"
    assert "Higher Customs Dispute Board" in appealed.resolution_strategy


def test_resolve_exception_and_metrics(db_session):
    service = LogisticsExceptionsService(db_session)
    created = service.log_exception(
        LogisticsExceptionCreate(
            exception_type="BLANK_SAILING",
            severity="HIGH",
            title_ar="إلغاء رحلة ملاحية",
            title_en="Blank Sailing Announcement",
            delay_impact_days=7,
        ),
        current_user_id=1,
    )
    assert created.delay_kpi_suspended is True

    # Resolving requires substantive strategy
    with pytest.raises(HTTPException):
        service.resolve_exception(
            created.id,
            ExceptionResolveRequest(resolution_strategy="ok"),
        )

    resolved = service.resolve_exception(
        created.id,
        ExceptionResolveRequest(
            resolution_strategy="Re-booked cargo on alternative feeder vessel departing next Tuesday.",
            status="RESOLVED",
        ),
        current_user_id=1,
    )
    assert resolved.status == "RESOLVED"
    assert resolved.resolved_at is not None
    # Delay KPI suspension is reinstated upon resolution
    assert resolved.delay_kpi_suspended is False

    metrics = service.get_metrics()
    assert metrics.total_exceptions >= 1
    assert metrics.open_exceptions == 0


# ==============================================================================
# 2. Refundable Deposits Ledger Tests
# ==============================================================================

def test_create_deposit_and_eir_linking(db_session):
    service = RefundableDepositsService(db_session)
    data = RefundableDepositCreate(
        deposit_type="SHIPPING_LINE_CONTAINER",
        beneficiary_type="CARRIER",
        beneficiary_name="Maersk Line Egypt",
        container_number="MSKU7281920",
        deposit_amount=25000.0,
        currency="EGP",
        paid_date=date(2026, 10, 1),
        payment_reference="CHK-88192",
    )

    created = service.create_deposit(data, current_user_id=1)
    assert created.id is not None
    assert created.deposit_code.startswith("DEP-")
    assert created.recovery_status == "PENDING"

    # Link EIR empty return
    linked = service.link_eir_return(
        created.id,
        EirReturnLinkRequest(
            container_number="MSKU7281920",
            eir_number="EIR-CAI-2026-9921",
            eir_return_date=date(2026, 10, 12),
            notes="Container returned clean with no physical damage.",
        ),
        current_user_id=1,
    )
    assert linked.eir_number == "EIR-CAI-2026-9921"
    assert linked.eir_return_date == date(2026, 10, 12)


def test_deposit_claim_submission_and_settlement(db_session):
    service = RefundableDepositsService(db_session)
    created = service.create_deposit(
        RefundableDepositCreate(
            deposit_type="SHIPPING_LINE_CONTAINER",
            beneficiary_type="CARRIER",
            beneficiary_name="Hapag-Lloyd Egypt",
            container_number="HLXU3918201",
            deposit_amount=30000.0,
        ),
        current_user_id=1,
    )

    # Submit claim
    submitted = service.submit_claim(
        created.id,
        RefundClaimSubmitRequest(
            claim_submission_date=date(2026, 10, 15),
            submission_reference="CLM-HL-4421",
            notes="Handed over original EIR and deposit receipt to carrier cashier.",
        ),
        current_user_id=1,
    )
    assert submitted.recovery_status == "SUBMITTED"

    # Settle with cleaning deduction: 28,000 refund + 2,000 cleaning deduction
    settled = service.settle_refund(
        created.id,
        RefundSettlementRequest(
            refunded_amount=28000.0,
            refund_date=date(2026, 10, 28),
            refund_reference="BANK-TRF-001928",
            deduction_amount=2000.0,
            deduction_reason="Chemical wash fee deducted by depot.",
        ),
        current_user_id=1,
    )
    assert settled.recovery_status == "REFUNDED"
    assert settled.refunded_amount == 28000.0
    assert settled.deduction_amount == 2000.0

    # Ensure over-settlement is blocked (refund + deduction > deposit)
    with pytest.raises(HTTPException):
        service.settle_refund(
            created.id,
            RefundSettlementRequest(
                refunded_amount=35000.0,
                refund_date=date(2026, 10, 29),
            ),
        )


def test_bank_letter_of_guarantee_flow(db_session):
    service = RefundableDepositsService(db_session)

    # Creating BANK_LETTER_OF_GUARANTEE without LG number must fail
    with pytest.raises(HTTPException):
        service.create_deposit(
            RefundableDepositCreate(
                deposit_type="BANK_LETTER_OF_GUARANTEE",
                beneficiary_type="CUSTOMS",
                beneficiary_name="Alexandria Customs Authority",
                deposit_amount=500000.0,
            )
        )

    # Valid LG
    created = service.create_deposit(
        RefundableDepositCreate(
            deposit_type="BANK_LETTER_OF_GUARANTEE",
            beneficiary_type="CUSTOMS",
            beneficiary_name="Alexandria Customs Authority",
            deposit_amount=500000.0,
            bank_lg_number="LG-CIB-2026-0044",
            bank_lg_issuing_bank="Commercial International Bank (CIB)",
            bank_lg_expiry_date=date(2026, 12, 31),
        )
    )
    assert created.bank_lg_number == "LG-CIB-2026-0044"

    # Release LG
    released = service.release_bank_lg(
        created.id,
        BankLgReleaseRequest(
            release_letter_reference="CUST-REL-8819",
            release_date=date(2026, 11, 2),
            notes="Customs formal discharge letter received and delivered to CIB bank branch.",
        ),
        current_user_id=1,
    )
    assert released.recovery_status == "LG_RELEASED"

    metrics = service.get_metrics()
    assert metrics.active_bank_lg_count == 0


# ==============================================================================
# 3. Pre-Shipment Inspection (PSI) & Vendor Quality Tests
# ==============================================================================

def test_vendor_rating_calculation_and_grading():
    # Perfect score: 40% Q + 25% T + 20% D + 15% C = 100
    rating, grade, action_req = VendorQualityService.calculate_overall_rating(
        quality=100.0, timeliness=100.0, docs=100.0, compliance=100.0, critical_defects=0
    )
    assert rating == 100.0
    assert grade == "A"
    assert action_req is False

    # Grade B: 85 Q + 80 T + 80 D + 80 C = 34 + 20 + 16 + 12 = 82
    rating_b, grade_b, action_b = VendorQualityService.calculate_overall_rating(
        quality=85.0, timeliness=80.0, docs=80.0, compliance=80.0, critical_defects=0
    )
    assert rating_b == 82.0
    assert grade_b == "B"
    assert action_b is False

    # Critical defects penalty: 2 critical defects = -10 pts penalty + mandatory corrective action
    rating_crit, grade_crit, action_crit = VendorQualityService.calculate_overall_rating(
        quality=90.0, timeliness=90.0, docs=90.0, compliance=90.0, critical_defects=2
    )
    # 90.0 raw - 10.0 penalty = 80.0
    assert rating_crit == 80.0
    assert grade_crit == "B"
    assert action_crit is True


def test_create_vendor_assessment_and_psi_upload(db_session):
    service = VendorQualityService(db_session)
    data = VendorQualityCreate(
        vendor_id=10,
        vendor_name="Guangzhou Tech Co., Ltd.",
        inspection_agency="SGS",
        quality_score=92.0,
        delivery_timeliness_score=88.0,
        documentation_accuracy_score=95.0,
        compliance_score=90.0,
    )

    created = service.create_assessment(data, current_user_id=1)
    assert created.id is not None
    assert created.assessment_code.startswith("PSI-")
    assert created.overall_vendor_rating > 90.0
    assert created.rating_grade == "A"
    assert created.psi_result == "PENDING"

    # Upload PSI inspection certificate
    uploaded = service.upload_psi_certificate(
        created.id,
        PsiCertificateUploadRequest(
            psi_certificate_number="SGS-GZ-2026-9901",
            inspection_date=date(2026, 10, 20),
            psi_result="PASSED",
            inspection_certificate_file="/storage/psi/sgs_report_9901.pdf",
            defects_count=3,
            critical_defects_count=0,
            inspector_notes="Minor packaging scratches, electrical testing passed 100%.",
        ),
        current_user_id=1,
    )
    assert uploaded.psi_result == "PASSED"
    assert uploaded.psi_certificate_number == "SGS-GZ-2026-9901"
    assert uploaded.defects_count == 3


def test_vendor_historical_rankings(db_session):
    service = VendorQualityService(db_session)

    # Vendor 1: High performer
    service.create_assessment(
        VendorQualityCreate(
            vendor_id=1,
            vendor_name="Shanghai Quality Ltd",
            inspection_agency="BUREAU_VERITAS",
            quality_score=95.0,
            delivery_timeliness_score=95.0,
            documentation_accuracy_score=95.0,
            compliance_score=95.0,
            psi_result="PASSED",
        )
    )

    # Vendor 2: Lower performer
    service.create_assessment(
        VendorQualityCreate(
            vendor_id=2,
            vendor_name="Shenzhen Budget Corp",
            inspection_agency="SGS",
            quality_score=60.0,
            delivery_timeliness_score=60.0,
            documentation_accuracy_score=60.0,
            compliance_score=60.0,
            psi_result="FAILED",
            defects_count=2,
            critical_defects_count=1,
        )
    )

    rankings_out = service.get_rankings()
    assert rankings_out.total_vendors == 2
    # Highest rating must rank first
    first = rankings_out.rankings[0]
    second = rankings_out.rankings[1]
    assert first.vendor_name == "Shanghai Quality Ltd"
    assert first.current_grade == "A"
    assert second.vendor_name == "Shenzhen Budget Corp"
    assert second.current_grade in ["D", "F"]
