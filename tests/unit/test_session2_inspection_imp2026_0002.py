"""
Unit test asserting full lifecycle of Customs Inspection & GOEIC Sampling (CL-01)
for Shipment IMP-2026-0002 (Monorail Orascom).
"""

from datetime import datetime, timezone
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import database.models
from database.database import Base
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsInspectionSamplingSubmit
from modules.customs_clearance.service import record_customs_inspection_sampling_service


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_shipment_2_inspection_sampling_lifecycle(db_session):
    # 1. Setup ImportFile at STEP_14 / Form 46 Registered
    imp_file = ImportFile(
        import_file_code="IMP-2026-0002",
        company_name="ECO ASSOCIATES",
        supplier_name="Alstom Rail",
        current_step_code="STEP_14",
        current_module="STEP_14 Clearance Follow-up",
        current_stage_code="PHASE_5",
        progress_percent=86.0,
        form46_no="DEC-46-2026-0002",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()

    # 2. Setup existing clearance record
    clr = CustomsClearanceRecord(
        clearance_code="CLR-2026-0001",
        import_file_id=imp_file.import_file_id,
        declaration_46_no="DEC-46-2026-0002",
        status="Under Customs Clearance",
        owner="Kamal",
    )
    db_session.add(clr)
    db_session.commit()

    # 3. Execute CL-01 inspection & sampling
    payload = CustomsInspectionSamplingSubmit(
        import_file_id=imp_file.import_file_id,
        inspection_date=datetime(2026, 9, 16, 11, 0, tzinfo=timezone.utc),
        inspection_type="Technical & Regulatory Sampling",
        inspection_yard="ALEXANDRIA_BERTH_42",
        inspector_name="Eng. Mohamed Nabil (GOEIC Committee)",
        inspection_result="Conforming",
        is_sample_drawn=True,
        sampling_date=datetime(2026, 9, 16, 11, 30, tzinfo=timezone.utc),
        sampling_record_no="SMP-2026-0014",
        sample_test_status="Samples Under Testing",
        sampled_regulatory_bodies=["GOEIC", "INDUSTRIAL_CONTROL"],
        goeic_certificate_no="GOEIC-MR-2026-7701",
        lab_service_fees=3200.0,
    )

    record = record_customs_inspection_sampling_service(
        db=db_session,
        payload=payload,
        user="Customs Broker",
    )
    db_session.refresh(imp_file)

    assert imp_file.progress_percent >= 88.0
    assert record.is_sample_drawn is True
    assert record.inspection_result == "Conforming"
    assert record.sampling_record_no == "SMP-2026-0014"
    assert record.goeic_certificate_no == "GOEIC-MR-2026-7701"
    assert record.lab_service_fees == 3200.0
