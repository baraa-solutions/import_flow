"""
Unit tests for Customs Clearance Revised Estimate (التقدير المحدّث للرسوم الجمركية)
and Approved Booking Freight (نولون البوكينج المعتمد).
"""
import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base, get_db
from main import app
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import (
    RevisedEstimateSubmit,
    CustomsDeclaration46Submit,
    ApprovedBookingFreightResponse,
)
from modules.customs_clearance.service import (
    save_revised_estimate_service,
    get_approved_booking_freight_service,
    register_customs_declaration_46_service,
    assess_final_customs_duties_service,
)
from modules.customs_clearance.schemas import FinalDutyAssessmentSubmit
from modules.freight_booking.model import ShipmentBooking


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(app)
    yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def sample_file(db_session):
    imp_file = ImportFile(
        import_file_code="IMP-2026-REV01",
        custom_file_number="FILE-REV-001",
        company_name="Sorour Logistics Import Co",
        supplier_name="Global Tech Supplier",
        current_module="Phase 6 - Customs Preparation",
        current_stage="Customs Preparation",
        progress_percent=85.0,
        is_active=True,
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)
    return imp_file


def test_revised_estimate_submit_schema_validation():
    """Verify RevisedEstimateSubmit schema validation and field types."""
    payload = RevisedEstimateSubmit(
        import_file_id=1,
        revised_exchange_rate=50.25,
        revised_freight_egp=120000.0,
        revised_insurance_egp=15000.0,
        revised_unloading_egp=8000.0,
        revised_duty_rate=5.0,
        revised_extra_fees_egp=4500.0,
        revised_cif_egp=750000.0,
        revised_import_duty_egp=37500.0,
        revised_vat_egp=110250.0,
        revised_total_duties_egp=152250.0,
        revised_has_exemption=False,
        revised_estimate_date=datetime(2026, 11, 1, 10, 0, tzinfo=timezone.utc),
        revised_estimate_by="Customs Specialist",
        revised_estimate_notes="تم تحديث سعر الصرف ونولون البوكينج المعتمد",
        duty_variance_reason="ارتفاع الدولار الجمركي ونولون الشحن الفعلي",
    )
    assert payload.import_file_id == 1
    assert payload.revised_exchange_rate == 50.25
    assert payload.revised_freight_egp == 120000.0
    assert payload.revised_total_duties_egp == 152250.0
    assert payload.duty_variance_reason == "ارتفاع الدولار الجمركي ونولون الشحن الفعلي"


def test_save_revised_estimate_service_all_fields(db_session, sample_file):
    """Test saving all 14 revised estimate fields via save_revised_estimate_service."""
    payload = RevisedEstimateSubmit(
        import_file_id=sample_file.import_file_id,
        revised_exchange_rate=49.50,
        revised_freight_egp=95000.0,
        revised_insurance_egp=12000.0,
        revised_unloading_egp=6000.0,
        revised_duty_rate=5.0,
        revised_extra_fees_egp=3500.0,
        revised_cif_egp=600000.0,
        revised_import_duty_egp=30000.0,
        revised_vat_egp=88200.0,
        revised_total_duties_egp=121700.0,
        revised_has_exemption=True,
        revised_estimate_date=datetime(2026, 11, 1, 9, 30, tzinfo=timezone.utc),
        revised_estimate_by="Logistics Auditor",
        revised_estimate_notes="تقدير محدّث قبل قيد 46",
        duty_variance_reason="تطبيق اتفاقية تجارة تفضيلية",
    )

    record = save_revised_estimate_service(db_session, payload, user="AuditorUser")

    assert record.revised_exchange_rate == 49.50
    assert record.revised_freight_egp == 95000.0
    assert record.revised_insurance_egp == 12000.0
    assert record.revised_unloading_egp == 6000.0
    assert record.revised_duty_rate == 5.0
    assert record.revised_extra_fees_egp == 3500.0
    assert record.revised_cif_egp == 600000.0
    assert record.revised_import_duty_egp == 30000.0
    assert record.revised_vat_egp == 88200.0
    assert record.revised_total_duties_egp == 121700.0
    assert record.revised_has_exemption is True
    assert record.revised_estimate_by == "Logistics Auditor"
    assert record.revised_estimate_notes == "تقدير محدّث قبل قيد 46"
    assert record.duty_variance_reason == "تطبيق اتفاقية تجارة تفضيلية"


def test_revised_estimate_variance_calculation_and_reason(db_session, sample_file):
    """Verify variance calculation between preliminary estimate and revised estimate."""
    # Pre-populate record with initial estimate
    existing = CustomsClearanceRecord(
        clearance_code="CC-2026-TESTVAR",
        import_file_id=sample_file.import_file_id,
        estimated_duty_total=100000.0,
        is_active=True,
    )
    db_session.add(existing)
    db_session.commit()

    payload = RevisedEstimateSubmit(
        import_file_id=sample_file.import_file_id,
        revised_total_duties_egp=115000.0,
        duty_variance_reason="زيادة نولون الشحن وسعر الدولار الجمركي",
    )

    record = save_revised_estimate_service(db_session, payload, user="Specialist")

    assert record.revised_total_duties_egp == 115000.0
    assert record.duty_variance_amount == 15000.0
    assert record.duty_variance_percentage == 15.0
    assert record.duty_variance_reason == "زيادة نولون الشحن وسعر الدولار الجمركي"


def test_form46_with_revised_estimate_fields(db_session, sample_file):
    """Verify registering Form 46 updates both Declaration 46 and revised estimate fields."""
    d46_payload = CustomsDeclaration46Submit(
        import_file_id=sample_file.import_file_id,
        declaration_46_no="46-2026-ALX-99881",
        customs_office_name="Alexandria Port Customs",
        channel_type="Green Channel",
        revised_exchange_rate=49.80,
        revised_freight_egp=110000.0,
        revised_total_duties_egp=135000.0,
        revised_has_exemption=False,
        duty_variance_reason="فروق نولون وتأمين",
    )

    record = register_customs_declaration_46_service(db_session, d46_payload, user="BrokerUser")

    assert record.declaration_46_no == "46-2026-ALX-99881"
    assert record.channel_type == "Green Channel"
    assert record.revised_exchange_rate == 49.80
    assert record.revised_freight_egp == 110000.0
    assert record.revised_total_duties_egp == 135000.0
    assert record.duty_variance_reason == "فروق نولون وتأمين"


def test_approved_booking_freight_with_confirmed_booking(db_session, sample_file):
    """Test reading approved booking freight when a ShipmentBooking exists."""
    # Pre-create clearance record with exchange rate
    record = CustomsClearanceRecord(
        clearance_code="CC-2026-BKTEST",
        import_file_id=sample_file.import_file_id,
        revised_exchange_rate=50.0,
        is_active=True,
    )
    db_session.add(record)

    # Create active confirmed booking
    booking = ShipmentBooking(
        booking_code="BK-2026-0001",
        import_file_id=sample_file.import_file_id,
        status="Confirmed",
        shipping_line_name="Maersk Line",
        freight_forwarder_name="Apex Logistics",
        bill_of_lading_no="MSK123456789",
        freight_terms="Collect",
        total_freight_cost_usd=2500.0,
        is_active=True,
    )
    db_session.add(booking)
    db_session.commit()

    res = get_approved_booking_freight_service(db_session, sample_file.import_file_id)

    assert res["has_booking"] is True
    assert res["booking_id"] == booking.booking_id
    assert res["booking_code"] == "BK-2026-0001"
    assert res["booking_status"] == "Confirmed"
    assert res["shipping_line_name"] == "Maersk Line"
    assert res["bill_of_lading_no"] == "MSK123456789"
    assert res["total_freight_cost_usd"] == 2500.0
    assert res["freight_cost_egp"] == 125000.0  # 2500 * 50.0
    assert res["exchange_rate_used"] == 50.0
    assert res["source"] == "ShipmentBooking"


def test_approved_booking_freight_empty_when_no_booking(db_session, sample_file):
    """Test reading approved booking freight when no booking exists returns has_booking=False."""
    res = get_approved_booking_freight_service(db_session, sample_file.import_file_id)
    assert res["has_booking"] is False
    assert res["total_freight_cost_usd"] == 0.0
    assert res["freight_cost_egp"] is None


def test_api_save_revised_estimate_endpoint(client, sample_file):
    """Test POST /api/v1/customs-clearance/revised-estimate HTTP endpoint."""
    payload = {
        "import_file_id": sample_file.import_file_id,
        "revised_exchange_rate": 50.10,
        "revised_freight_egp": 85000.0,
        "revised_total_duties_egp": 140000.0,
        "revised_has_exemption": False,
        "duty_variance_reason": "فروق أسعار صرف",
        "revised_estimate_notes": "تسجيل عبر الواجهة",
    }

    response = client.post("/api/v1/customs-clearance/revised-estimate", json=payload)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["revised_exchange_rate"] == 50.10
    assert data["revised_freight_egp"] == 85000.0
    assert data["revised_total_duties_egp"] == 140000.0
    assert data["duty_variance_reason"] == "فروق أسعار صرف"
    assert data["revised_estimate_notes"] == "تسجيل عبر الواجهة"


def test_api_approved_booking_freight_endpoint(client, db_session, sample_file):
    """Test GET /api/v1/customs-clearance/approved-booking-freight/{import_file_id} HTTP endpoint."""
    booking = ShipmentBooking(
        booking_code="BK-2026-API-01",
        import_file_id=sample_file.import_file_id,
        status="Sailed",
        shipping_line_name="CMA CGM",
        total_freight_cost_usd=3000.0,
        is_active=True,
    )
    db_session.add(booking)
    db_session.commit()

    response = client.get(f"/api/v1/customs-clearance/approved-booking-freight/{sample_file.import_file_id}")
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["has_booking"] is True
    assert data["booking_code"] == "BK-2026-API-01"
    assert data["shipping_line_name"] == "CMA CGM"
    assert data["total_freight_cost_usd"] == 3000.0

    # Test alias route /booking-freight/{import_file_id}
    response_alias = client.get(f"/api/v1/customs-clearance/booking-freight/{sample_file.import_file_id}")
    assert response_alias.status_code == 200, response_alias.text
    data_alias = response_alias.json()
    assert data_alias["has_booking"] is True
    assert data_alias["booking_code"] == "BK-2026-API-01"
