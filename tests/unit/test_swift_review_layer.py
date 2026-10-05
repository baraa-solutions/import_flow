"""
Unit Tests for SWIFT Extraction Review Layer (Extraction Review Layer and State Machine)
"""
import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi import HTTPException

from database.database import Base
from modules.financial_approval.model import (
    PaymentRequestSession,
    SwiftExtractionBatch,
    SwiftExtractionField,
    OcrCorrectionsLog,
)
from modules.financial_approval.schemas import (
    SwiftFieldUpdateRequest,
    SwiftBatchConfirmRequest,
    SwiftBatchReconcileRequest,
)
import modules.financial_approval.service as service


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    pay = PaymentRequestSession(
        payment_id=10,
        payment_code="PAY-2026-010",
        title="Payment for Textile Shipment",
        supplier_id=1,
        supplier_name="SUZHOU YUHENG TEXTILE CO.,LTD",
        beneficiary_name="SUZHOU YUHENG TEXTILE CO.,LTD",
        bank_name="CHINA CONSTRUCTION BANK",
        swift_code="PCBCCNBJJSS",
        iban_account_no="32250198613609841015",
        requested_amount=43704.0,
        currency_code="USD",
        exchange_rate=50.0,
        requested_amount_egp=2185200.0,
        due_date=date(2026, 8, 20),
        request_date=date(2026, 8, 10),
        # Phase 2 quality (FA-02 / FA-18): only Approved requests are matched and reconciled.
        status="Approved",
        is_active=True,
    )
    session.add(pay)
    session.commit()

    yield session
    session.close()


REAL_SWIFT_SAMPLE = """
(1:F01ARAIEGCXXXXX.SN...ISN.）(2:I103CITIUS33XXXXN)(3:(108:XXXXX))(4:
:2O/TRANSACTION REFERENCE NUMBER
FT/26228/KZ70Q
:2BB/BANKOPERATIONCODE
:CRED
:B2A/Value Date,CCY,Amount
260818U5D43704,00
:5OK/ORDERING CUST
/EG780057004001017153610010101
SCAS FOR CONSTRUCTION AND FINISHING
ROAD18
EGYPT,44 ROAD 18
SARIAT EL MAADICAIRO
57A/Accountwith Bank
PCBCCNBJJSS
59/BeneficiaryCustomer
/32250198613609841015
SUZHOU YUHENG TEXTILE CO.,LTD
16 KANGSHENG ROAD ZHITANG TOWN
CHANGSHU CITY SUZHOU CHINA
7O/DETAILS OFPAYMENT
EG0010040 PI NO.YH20260730.6
ALL DOCUMENTS SHOULD BE TRADED
THROUGH AAIB
ZA/DETAILS OF CHARGES
:SHA
"""


def test_swift_review_layer_full_lifecycle(db_session):
    # 1. Extraction for review -> status must be EXTRACTED_PENDING_REVIEW
    batch_resp = service.extract_swift_for_review_service(
        db=db_session,
        raw_text=REAL_SWIFT_SAMPLE,
        filename="swift_sample.txt",
        file_type="Text File",
    )
    assert batch_resp.status == "EXTRACTED_PENDING_REVIEW"
    assert batch_resp.batch_id > 0
    assert batch_resp.batch_code.startswith("SWF-")
    assert len(batch_resp.fields) >= 15
    assert batch_resp.all_mandatory_valid is True

    # 2. Field accuracy verification
    field_map = {f.field_key: f for f in batch_resp.fields}
    assert float(field_map["amount"].final_value) == 43704.0
    assert field_map["currency"].final_value == "USD"
    assert field_map["transaction_reference"].final_value == "FT/26228/KZ70Q"
    assert "SUZHOU YUHENG TEXTILE" in field_map["beneficiary_name"].final_value
    assert field_map["beneficiary_account_or_iban"].final_value == "32250198613609841015"

    # 3. Security Guard: matching before review confirmation MUST fail with 403
    with pytest.raises(HTTPException) as exc_info:
        service.match_reviewed_batch_service(db_session, batch_resp.batch_id)
    assert exc_info.value.status_code == 403

    # 4. Security Guard: reconciling before review confirmation MUST fail with 403
    with pytest.raises(HTTPException) as exc_info:
        service.reconcile_reviewed_batch_service(
            db_session,
            batch_resp.batch_id,
            SwiftBatchReconcileRequest(payment_id=10),
        )
    assert exc_info.value.status_code == 403

    # 5. Field editing and Audit log
    updated = service.update_swift_batch_field_service(
        db=db_session,
        batch_id=batch_resp.batch_id,
        field_key="amount",
        payload=SwiftFieldUpdateRequest(value="43704.00", user_name="ahmed_sorour"),
    )
    amt_fld = next(f for f in updated.fields if f.field_key == "amount")
    assert amt_fld.is_edited_by_user is True
    assert amt_fld.final_value == "43704.00"
    assert amt_fld.confidence_score == 1.0

    # 6. Test empty mandatory validation block
    service.update_swift_batch_field_service(
        db=db_session,
        batch_id=batch_resp.batch_id,
        field_key="beneficiary_name",
        payload=SwiftFieldUpdateRequest(value="", user_name="tester"),
    )
    with pytest.raises(HTTPException) as exc_info:
        service.confirm_swift_batch_review_service(
            db=db_session,
            batch_id=batch_resp.batch_id,
            payload=SwiftBatchConfirmRequest(user_name="tester"),
        )
    assert exc_info.value.status_code == 400
    assert "Mandatory fields are missing" in exc_info.value.detail

    # 7. Re-extract single field to restore original parsed value
    restored = service.re_extract_single_field_service(
        db=db_session,
        batch_id=batch_resp.batch_id,
        field_key="beneficiary_name",
    )
    ben_fld = next(f for f in restored.fields if f.field_key == "beneficiary_name")
    assert "SUZHOU YUHENG TEXTILE" in ben_fld.final_value
    assert restored.all_mandatory_valid is True

    # 8. Confirm review -> transitions to REVIEWED_CONFIRMED
    confirm_resp = service.confirm_swift_batch_review_service(
        db=db_session,
        batch_id=batch_resp.batch_id,
        payload=SwiftBatchConfirmRequest(user_name="ahmed_sorour"),
    )
    assert confirm_resp.success is True
    assert confirm_resp.status == "REVIEWED_CONFIRMED"
    assert confirm_resp.confirmed_fields["amount"] == "43704.00"

    # 9. Now matching is UNLOCKED
    match_resp = service.match_reviewed_batch_service(db_session, batch_resp.batch_id)
    assert match_resp.success is True
    assert match_resp.matched_payment_request is not None
    assert match_resp.matched_payment_request["payment_id"] == 10
    assert match_resp.matched_payment_request["confidence_score"] >= 80

    # 10. Reconcile against matched payment request
    pay_reconciled = service.reconcile_reviewed_batch_service(
        db=db_session,
        batch_id=batch_resp.batch_id,
        payload=SwiftBatchReconcileRequest(
            payment_id=10,
            notes="Matched and verified via SWIFT extraction review layer",
        ),
    )
    assert pay_reconciled.status == "Paid"
    assert pay_reconciled.swift_reference_no == "FT/26228/KZ70Q"
    assert pay_reconciled.swift_transferred_amount == 43704.0
    assert pay_reconciled.swift_variance_status == "Matched"
    assert pay_reconciled.swift_variance_amount == 0.0

    # Batch status in DB should now be RECONCILED
    batch_in_db = db_session.query(SwiftExtractionBatch).filter_by(batch_id=batch_resp.batch_id).first()
    assert batch_in_db.status == "RECONCILED"
    assert batch_in_db.matched_payment_id == 10