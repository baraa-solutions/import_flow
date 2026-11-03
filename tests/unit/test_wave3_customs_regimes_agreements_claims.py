"""
Unit Tests for Wave 3:
1. Customs Special Regimes (النظم الجمركية المعلقة والمناطق الحرة)
2. Preferential Trade Agreements & Origin Verifications (الاتفاقيات التفضيلية وشهادات المنشأ)
3. Cargo Claims & Legal Reservations (رادار مواعيد المطالبات القانونية وسقوط حق الدعوى والتأمين)
"""

from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
import database.models  # noqa: F401
from modules.import_files.model import ImportFile
from modules.customs_regimes.model import CustomsSpecialRegime
from modules.customs_regimes.schemas import (
    CustomsRegimeCreate,
    CustomsRegimeSettle,
    CustomsRegimeUpdate,
    GuaranteeType,
    RegimeStatus,
    RegimeType,
)
from modules.customs_regimes.service import CustomsRegimesService
from modules.trade_agreements.model import PreferentialOriginVerification
from modules.trade_agreements.schemas import (
    AgreementName,
    CertificateType,
    OriginCriterion,
    SubmissionStatus,
    TradeAgreementCreate,
    TradeAgreementUpdate,
    TradeAgreementVerifyOriginal,
)
from modules.trade_agreements.service import TradeAgreementsService
from modules.legal_claims.model import CargoClaimAndReservation
from modules.legal_claims.schemas import (
    ClaimStatus,
    ClaimType,
    DamageNature,
    LegalClaimCreate,
    LegalClaimSettle,
    LegalClaimUpdate,
    ScheduleSurvey,
)
from modules.legal_claims.service import LegalClaimsService


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy import file for foreign keys
    test_file = ImportFile(
        import_file_code="IMP-2026-00001",
        company_name="Al-Sorour Import Co",
        supplier_name="Global Steel Ltd",
    )
    session.add(test_file)
    session.commit()
    session.refresh(test_file)

    try:
        yield session
    finally:
        session.close()


# =========================================================================
# 1. Customs Special Regimes Tests
# =========================================================================

def test_create_customs_regime_temporary_admission(db_session):
    service = CustomsRegimesService(db_session)
    today = date.today()

    payload = CustomsRegimeCreate(
        import_file_id=1,
        regime_type=RegimeType.TEMPORARY_ADMISSION,
        status=RegimeStatus.ACTIVE,
        customs_office="Dekheila Logistics Hub",
        release_form_number="TR-98214",
        release_date=today,
        guarantee_type=GuaranteeType.LETTER_OF_GUARANTEE,
        guarantee_reference="LG-NBE-55102",
        guarantee_bank="National Bank of Egypt",
        guarantee_amount=250000.0,
        guarantee_currency="EGP",
        guarantee_issue_date=today,
        guarantee_expiry_date=today + timedelta(days=365),
        re_export_deadline=today + timedelta(days=365),
    )

    created = service.create_regime(payload, user_id=1)
    assert created.id is not None
    assert created.regime_code.startswith("REG-")
    assert created.regime_type == RegimeType.TEMPORARY_ADMISSION
    assert created.guarantee_active is True
    assert created.is_expired is False
    assert created.days_until_re_export == 365


def test_customs_regime_validation_guarantee_dates(db_session):
    service = CustomsRegimesService(db_session)
    today = date.today()

    # Guarantee expiry earlier than issue date should raise 422
    payload = CustomsRegimeCreate(
        import_file_id=1,
        regime_type=RegimeType.DRAWBACK,
        guarantee_amount=50000.0,
        guarantee_type=GuaranteeType.CASH_DEPOSIT,
        guarantee_issue_date=today,
        guarantee_expiry_date=today - timedelta(days=10),
    )

    with pytest.raises(HTTPException) as exc:
        service.create_regime(payload)
    assert exc.value.status_code == 422
    assert "earlier than issue date" in exc.value.detail


def test_customs_regime_settle_temporary_admission(db_session):
    service = CustomsRegimesService(db_session)
    today = date.today()

    payload = CustomsRegimeCreate(
        import_file_id=1,
        regime_type=RegimeType.TEMPORARY_ADMISSION,
        status=RegimeStatus.ACTIVE,
        re_export_deadline=today + timedelta(days=180),
    )
    created = service.create_regime(payload)

    settle_payload = CustomsRegimeSettle(
        actual_re_export_date=today,
        re_export_export_declaration_no="EXP-13KM-2026-881",
        notes="All manufactured batches fully re-exported via Alexandria Port.",
    )
    settled = service.settle_regime(created.id, settle_payload, user_id=1)

    assert settled.status == RegimeStatus.SETTLED
    assert settled.is_settled is True
    assert settled.actual_re_export_date == today
    assert settled.re_export_export_declaration_no == "EXP-13KM-2026-881"


def test_customs_regime_settle_validation_failure(db_session):
    service = CustomsRegimesService(db_session)
    payload = CustomsRegimeCreate(
        import_file_id=1,
        regime_type=RegimeType.TEMPORARY_ADMISSION,
        status=RegimeStatus.ACTIVE,
    )
    created = service.create_regime(payload)

    # Empty settlement payload for TEMPORARY_ADMISSION should fail
    settle_payload = CustomsRegimeSettle()
    with pytest.raises(HTTPException) as exc:
        service.settle_regime(created.id, settle_payload)
    assert exc.value.status_code == 422
    assert "requires actual re-export date" in exc.value.detail


def test_customs_regime_soft_delete(db_session):
    service = CustomsRegimesService(db_session)
    payload = CustomsRegimeCreate(
        import_file_id=1,
        regime_type=RegimeType.FREE_ZONE,
        status=RegimeStatus.ACTIVE,
    )
    created = service.create_regime(payload)
    assert service.delete_regime(created.id, user_id=1) is True

    with pytest.raises(HTTPException) as exc:
        service.get_regime(created.id)
    assert exc.value.status_code == 404


# =========================================================================
# 2. Preferential Trade Agreements Tests
# =========================================================================

def test_create_trade_agreement_with_provisional_escrow(db_session):
    service = TradeAgreementsService(db_session)
    today = date.today()

    payload = TradeAgreementCreate(
        import_file_id=1,
        agreement_name=AgreementName.EUR1,
        certificate_type=CertificateType.EUR1,
        certificate_number="EUR1-DE-2026-90412",
        issuing_country="Germany",
        issuing_authority="Hamburg Chamber of Commerce",
        issuing_date=today,
        validity_months=4,
        submission_status=SubmissionStatus.COPY_SUBMITTED,
        has_original_received=False,
        provisional_escrow_required=True,
        provisional_escrow_amount=85000.0,
        provisional_escrow_receipt="ESC-RCP-2026-0041",
        provisional_escrow_deadline=today + timedelta(days=10),
        direct_transport_compliant=True,
        rules_of_origin_criterion=OriginCriterion.SUFFICIENT_PROCESSING,
    )

    created = service.create_verification(payload, user_id=1)
    assert created.id is not None
    assert created.verification_code.startswith("POV-")
    assert created.expiry_date is not None
    assert created.is_escrow_at_risk is True  # 10 days <= 15 days threshold
    assert created.provisional_escrow_amount == 85000.0


def test_trade_agreement_verify_original_receipt(db_session):
    service = TradeAgreementsService(db_session)
    today = date.today()

    payload = TradeAgreementCreate(
        import_file_id=1,
        agreement_name=AgreementName.COMESA,
        certificate_type=CertificateType.FORM_A,
        certificate_number="CMS-KE-2026-118",
        issuing_country="Kenya",
        issuing_date=today - timedelta(days=20),
        validity_months=6,
        provisional_escrow_required=True,
        provisional_escrow_amount=40000.0,
        provisional_escrow_deadline=today + timedelta(days=40),
    )
    created = service.create_verification(payload)

    verify_payload = TradeAgreementVerifyOriginal(
        original_received_date=today,
        provisional_escrow_refunded=True,
        refund_date=today,
        verification_notes="Original stamped certificate inspected and escrow release voucher signed.",
    )
    verified = service.verify_original(created.id, verify_payload, user_id=1)

    assert verified.has_original_received is True
    assert verified.submission_status == SubmissionStatus.ORIGINAL_SUBMITTED
    assert verified.provisional_escrow_refunded is True
    assert verified.is_escrow_at_risk is False


def test_trade_agreement_validation_dates(db_session):
    service = TradeAgreementsService(db_session)
    today = date.today()

    payload = TradeAgreementCreate(
        import_file_id=1,
        agreement_name=AgreementName.GAFTA,
        certificate_type=CertificateType.ARAB_LEAGUE,
        certificate_number="GFT-SA-2026-77",
        issuing_country="Saudi Arabia",
        issuing_date=today,
        expiry_date=today - timedelta(days=5),  # Earlier than issue date
    )

    with pytest.raises(HTTPException) as exc:
        service.create_verification(payload)
    assert exc.value.status_code == 422
    assert "earlier than issuing date" in exc.value.detail


# =========================================================================
# 3. Cargo Claims & Legal Reservations Tests
# =========================================================================

def test_create_latent_damage_claim_auto_deadlines(db_session):
    service = LegalClaimsService(db_session)
    today = date.today()

    payload = LegalClaimCreate(
        import_file_id=1,
        claim_type=ClaimType.CARRIER_DAMAGE,
        damage_nature=DamageNature.LATENT,
        delivery_date=today,
        target_party="Maersk Line Egypt Agency",
        claimed_amount=12500.0,
        claimed_currency="USD",
        notes="Hidden saltwater ingress discovered upon unsealing container at warehouse.",
    )

    created = service.create_claim(payload, user_id=1)
    assert created.id is not None
    assert created.claim_code.startswith("CLM-")
    # Egyptian Maritime Law Art. 244: 3 days for latent notice
    assert created.latent_notice_deadline == today + timedelta(days=3)
    # 1-year time-bar
    assert created.time_bar_statute_of_limitations_date == today + timedelta(days=365)
    assert created.days_until_time_bar == 365
    assert created.urgency_level == "NORMAL"
    assert created.is_time_barred is False


def test_schedule_joint_survey(db_session):
    service = LegalClaimsService(db_session)
    today = date.today()

    payload = LegalClaimCreate(
        import_file_id=1,
        claim_type=ClaimType.PORT_DAMAGE,
        damage_nature=DamageNature.APPARENT,
        delivery_date=today,
        target_party="Alexandria Container Terminal (Dekheila)",
        claimed_amount=45000.0,
    )
    created = service.create_claim(payload)

    survey_payload = ScheduleSurvey(
        survey_date=today + timedelta(days=2),
        surveyor_company="Bureau Veritas Egypt",
        notes="Joint inspection scheduled with terminal representative.",
    )
    scheduled = service.schedule_survey(created.id, survey_payload, user_id=1)

    assert scheduled.survey_requested is True
    assert scheduled.status == ClaimStatus.SURVEY_SCHEDULED
    assert scheduled.surveyor_company == "Bureau Veritas Egypt"


def test_settle_claim_and_validation(db_session):
    service = LegalClaimsService(db_session)
    today = date.today()

    payload = LegalClaimCreate(
        import_file_id=1,
        claim_type=ClaimType.INSURANCE_RECOVERY,
        damage_nature=DamageNature.APPARENT,
        delivery_date=today - timedelta(days=30),
        target_party="Misr Insurance Company",
        claimed_amount=20000.0,
    )
    created = service.create_claim(payload)

    # Negative settlement amount should fail
    with pytest.raises((HTTPException, ValueError)):
        LegalClaimSettle(
            settled_amount=-500.0,
            settlement_date=today,
        )

    # Valid settlement
    good_settle = LegalClaimSettle(
        settled_amount=18500.0,
        settlement_date=today,
        notes="Settlement cheque received in full and final discharge.",
    )
    settled = service.settle_claim(created.id, good_settle, user_id=1)
    assert settled.status == ClaimStatus.SETTLED
    assert settled.settled_amount == 18500.0


def test_time_bar_radar_urgency_levels(db_session):
    service = LegalClaimsService(db_session)
    today = date.today()

    # Case 1: Critical <= 7 days
    crit_payload = LegalClaimCreate(
        import_file_id=1,
        claim_type=ClaimType.CARRIER_SHORTAGE,
        damage_nature=DamageNature.APPARENT,
        delivery_date=today - timedelta(days=360),
        time_bar_statute_of_limitations_date=today + timedelta(days=5),
        target_party="MSC Mediterranean Shipping Co",
        claimed_amount=5000.0,
    )
    crit = service.create_claim(crit_payload)
    assert crit.urgency_level == "CRITICAL_7_DAYS"
    assert crit.is_time_barred is False

    # Case 2: Expired / Time-Barred
    exp_payload = LegalClaimCreate(
        import_file_id=1,
        claim_type=ClaimType.CARRIER_DAMAGE,
        damage_nature=DamageNature.APPARENT,
        delivery_date=today - timedelta(days=400),
        time_bar_statute_of_limitations_date=today - timedelta(days=35),
        target_party="Hapag-Lloyd Egypt",
        claimed_amount=3000.0,
    )
    exp = service.create_claim(exp_payload)
    assert exp.urgency_level == "EXPIRED"
    assert exp.is_time_barred is True


if __name__ == '__main__':
    engine = create_engine('sqlite:///:memory:')
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    test_file = ImportFile(
        import_file_code='IMP-2026-00001',
        company_name='Al-Sorour Import Co',
        supplier_name='Global Steel Ltd',
    )
    session.add(test_file)
    session.commit()

    test_funcs = [
        test_create_customs_regime_temporary_admission,
        test_customs_regime_validation_guarantee_dates,
        test_customs_regime_settle_temporary_admission,
        test_customs_regime_settle_validation_failure,
        test_customs_regime_soft_delete,
        test_create_trade_agreement_with_provisional_escrow,
        test_trade_agreement_verify_original_receipt,
        test_trade_agreement_validation_dates,
        test_create_latent_damage_claim_auto_deadlines,
        test_schedule_joint_survey,
        test_settle_claim_and_validation,
        test_time_bar_radar_urgency_levels,
    ]

    passed = 0
    for fn in test_funcs:
        try:
            fn(session)
            print(f'PASS: {fn.__name__}')
            passed += 1
        except Exception as e:
            print(f'FAIL: {fn.__name__}: {e}')

    print(f'\\nRESULT: {passed}/{len(test_funcs)} unit tests passed successfully!')
