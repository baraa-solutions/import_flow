import pytest
from datetime import datetime, timezone
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsClearanceCreate, DutyPaymentSubmit
from modules.customs_clearance.service import (
    create_customs_clearance_service,
    submit_duty_payment_service,
)
from modules.smart_document_upload.extractors.customs_clearance import CustomsClearanceExtractor

@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy import file
    imp_file = ImportFile(
        import_file_code="IMP-2026-0099",
        company_name="Archi Brands for Trading",
        supplier_name="UAB Narbutas International",
        is_active=True,
    )
    session.add(imp_file)
    session.commit()
    session.refresh(imp_file)

    yield session
    session.close()

def test_customs_clearance_extractor_nafeza_duty():
    extractor = CustomsClearanceExtractor()
    sample_text = """
    منظومة نافذة - كشف حساب الرسوم والضرائب الجمركية
    رقم الشهادة الجمركية 46 ك.م: 4620260819001
    رقم إذن السداد: NAF-PAY-88992
    المركز اللوجستي: جمرك الدخيلة الإسكندرية
    القيمة الجمركية CIF: 623000.00
    سعر الدولار الجمركي: 48.75
    ضريبة الوارد: 62300.00
    ضريبة القيمة المضافة: 95942.00
    ضريبة الجدول: 6230.00
    أرباح تجارية وصناعية: 6230.00
    رسم تنمية: 1500.00
    رسوم الخدمات الجمركية: 4500.00
    المبلغ الإجمالي المطلوب سداده: 176702.00
    """

    res = extractor.extract(sample_text, {})
    assert res["declaration_no"] == "4620260819001"
    assert res["assessment_reference"] == "NAF-PAY-88992"
    assert "الدخيلة" in res["customs_office_name"]
    assert res["import_duty"] == 62300.0
    assert res["vat_amount"] == 95942.0
    assert res["schedule_tax"] == 6230.0
    assert res["wht_amount"] == 6230.0
    assert res["development_fee"] == 1500.0
    assert res["lab_service_fees"] == 4500.0
    assert res["total_taxes"] == 176702.0

def test_customs_clearance_variance_calculation(db_session):
    create_schema = CustomsClearanceCreate(
        import_file_id=1,
        declaration_46_no="46-2026-TEST",
        customs_office_name="Alexandria Port Customs",
        import_duty_amount=60000.0,
        vat_amount=90000.0,
        schedule_tax_amount=5000.0,
        wht_amount=5000.0,
        lab_service_fees=3000.0,
        estimated_duty_total=160000.0,
        free_days_allowed=14,
        delivery_order_number="DO-MAERSK-9988",
    )

    record = create_customs_clearance_service(db_session, create_schema)
    assert record.total_duty_payable == 163000.0
    assert record.estimated_duty_total == 160000.0
    assert record.actual_duty_total == 163000.0
    assert record.duty_variance_amount == 3000.0
    assert record.duty_variance_percentage == 1.88
    assert record.free_days_allowed == 14
    assert record.delivery_order_number == "DO-MAERSK-9988"

    # Now test payment submission with actual Nafeza ledger
    payment_submit = DutyPaymentSubmit(
        bank_receipt_no="RCPT-CIB-2026-7788",
        paying_bank_name="Commercial International Bank (CIB)",
        payment_date=datetime(2026, 8, 23, 10, 0, tzinfo=timezone.utc),
        actual_duty_total=165000.0,
        estimated_duty_total=160000.0,
        duty_variance_reason="فارق في سعر صرف الدولار الجمركي ومصروفات معمل إضافية",
        nafeza_assessment_json={"nafeza_bill_no": "NAF-88992", "duty": 62000.0, "vat": 93000.0},
    )

    paid_record = submit_duty_payment_service(db_session, record.customs_clearance_id, payment_submit)
    assert paid_record.payment_status == "Paid & Verified"
    assert paid_record.status == "Duty Paid"
    assert paid_record.bank_receipt_no == "RCPT-CIB-2026-7788"
    # CL-05/07: the legacy actual_duty_total is the paid amount; it no longer overwrites the assessed total,
    # and the client cannot move the estimate, so the variance stays the assessed one.
    assert paid_record.duty_paid_amount == 165000.0
    assert paid_record.actual_duty_total == 163000.0
    assert paid_record.duty_variance_amount == 3000.0
    assert paid_record.duty_variance_percentage == 1.88
    assert "الدولار الجمركي" in paid_record.duty_variance_reason
    assert paid_record.nafeza_assessment_json["nafeza_bill_no"] == "NAF-88992"
