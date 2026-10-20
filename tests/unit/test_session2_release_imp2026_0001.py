"""
Unit test asserting full lifecycle of Customs Duty Assessment, Payment, and Final Release
for Shipment IMP-2026-0001 (CL-02 -> CL-03 -> CL-04).
"""

from datetime import datetime, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models
from database.database import Base
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import (
    FinalDutyAssessmentSubmit,
    CustomsDutyPaymentSubmit,
    CustomsFinalReleaseSubmit,
)
from modules.customs_clearance.service import (
    assess_final_customs_duties_service,
    record_customs_duty_payment_service,
    issue_final_customs_release_service,
)
from modules.smart_tasks.model import SmartTask


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_shipment_1_customs_release_lifecycle(db_session):
    # 1. Setup ImportFile at STEP_15 / Inspection Done
    imp_file = ImportFile(
        import_file_code="IMP-2026-0001",
        company_name="ECO ASSOCIATES",
        supplier_name="Global Chillers Ltd",
        current_step_code="STEP_15",
        current_module="STEP_15 Drawing Samples / Shortage",
        current_stage_code="PHASE_5",
        progress_percent=88.0,
        delivery_order_no="DO-MAEU-2026-0001",
        form46_no="DEC-46-2026-0001",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()

    # 2. Setup existing clearance record
    clr = CustomsClearanceRecord(
        clearance_code="CLR-2026-0002",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="DEC-46-2026-0001",
        declaration_46_date=datetime(2026, 9, 14, 10, 0, tzinfo=timezone.utc),
        inspection_result="Conforming",
        is_sample_drawn=True,
        sampling_record_no="SMP-2026-0012",
        goeic_certificate_no="GOEIC-ALX-2026-9901",
        lab_service_fees=2450.0,
        status="Inspection & Sampling Recorded",
        owner="Kamal",
    )
    db_session.add(clr)
    db_session.commit()

    # 3. Assess final duties (CL-02)
    assess_payload = FinalDutyAssessmentSubmit(
        import_file_id=imp_file.import_file_id,
        cif_base_amount=97000.0,
        customs_exchange_rate=48.50,
        import_duty_amount=94090.0,
        vat_amount=671802.6,
        schedule_tax_amount=0.0,
        wht_amount=47045.0,
        development_fee_amount=141135.0,
        customs_service_fees=2500.0,
        lab_service_fees=2450.0,
        actual_duty_total=959022.6,
        nafeza_claim_number="CLM-ALX-2026-0001",
        nafeza_claim_date=datetime(2026, 9, 16, 9, 30, tzinfo=timezone.utc),
    )
    record = assess_final_customs_duties_service(db_session, assess_payload, user="Customs Broker")
    db_session.refresh(imp_file)
    assert record.total_duty_payable == 959022.6
    assert imp_file.progress_percent >= 90.0

    # 4. Pay duties (CL-03)
    payment_payload = CustomsDutyPaymentSubmit(
        import_file_id=imp_file.import_file_id,
        bank_receipt_no="RCPT-CBE-2026-9812",
        sadad_number="SADAD-2026-00451",
        paying_bank_name="National Bank of Egypt (NBE)",
        payment_date=datetime(2026, 9, 16, 11, 0, tzinfo=timezone.utc),
        payment_method="Sadad Electronic / E-Finance",
        duty_paid_amount=959022.6,
    )
    record = record_customs_duty_payment_service(db_session, payment_payload, user="Finance Officer")
    assert record.duty_paid_amount == 959022.6
    assert record.sadad_number == "SADAD-2026-00451"

    # 5. Issue final release (CL-04)
    release_payload = CustomsFinalReleaseSubmit(
        import_file_id=imp_file.import_file_id,
        clearance_id=record.customs_clearance_id,
        release_permit_no="REL-ALX-2026-0091",
        release_date=datetime(2026, 9, 16, 14, 0, tzinfo=timezone.utc),
        release_officer_name="Counselor Ahmed El-Sayed",
        release_type="Unconditional Final Release",
        gate_pass_number="GP-ALX-2026-1102",
        transport_instructions="Dispatch under seal to plant.",
    )
    record = issue_final_customs_release_service(db_session, release_payload, user="Customs Broker")
    db_session.refresh(imp_file)

    assert imp_file.progress_percent >= 95.0
    assert record.status in ("Final Release Granted", "Released")
    assert record.release_permit_no == "REL-ALX-2026-0091"
    assert record.gate_pass_number == "GP-ALX-2026-1102"
