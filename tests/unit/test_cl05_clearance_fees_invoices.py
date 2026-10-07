import pytest
from datetime import datetime, timezone, date
from fastapi import HTTPException
from fastapi.testclient import TestClient

from main import app
from database.database import get_db
from modules.import_files.model import ImportFile
from modules.customs_clearance.model import CustomsClearanceRecord, ClearanceExpenseInvoice
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.smart_tasks.model import SmartTask
from modules.customs_clearance.schemas import ClearanceExpenseInvoiceCreate
from modules.customs_clearance.service import (
    record_clearance_invoice_service,
    get_clearance_invoices_by_file_service,
    delete_clearance_invoice_service,
)

client = TestClient(app)

@pytest.fixture
def db_session():
    db = next(get_db())
    try:
        yield db
    finally:
        db.close()

@pytest.fixture
def sample_clearance_setup(db_session):
    # Unique suffix to avoid collisions
    suffix = datetime.now().strftime("%f")
    imp_file = ImportFile(
        import_file_code=f"IMP-2026-TEST-CL05-{suffix}",
        company_name="Delta Industrial Machinery LLC",
        supplier_name="Bavaria Tech GmbH",
        port_of_discharge="El Dekheila Port",
        form46_no=f"DEC-46-CL05-{suffix}",
        form46_status="REGISTERED",
        customs_duty_paid_amount=165801.50,
        customs_release_permit_no=f"REL-2026-{suffix}",
        is_customs_released=True,
        current_module="Phase 7 - Customs Clearance & Inspection",
        current_stage="Customs Released (تم الإفراج الجمركي النهائي وبدء النقل)",
        progress_percent=95.0,
        next_action="حجز شاحنات النقل الداخلي (TR-01)",
        owner="Kamal",
    )
    db_session.add(imp_file)
    db_session.commit()
    db_session.refresh(imp_file)

    clearance = CustomsClearanceRecord(
        clearance_code=f"CLR-2026-CL05-{suffix}",
        import_file_id=imp_file.import_file_id,
        declaration_46_no=imp_file.form46_no,
        customs_office_name="El Dekheila Port Customs",
        broker_name="مكتب الصفا للتخليص الجمركي",
        payment_status="Paid & Verified",
        status="Final Release Granted",
        duty_paid_amount=165801.50,
        release_permit_no=imp_file.customs_release_permit_no,
        dispatch_authorized=True,
        owner="Kamal",
    )
    db_session.add(clearance)
    db_session.commit()
    db_session.refresh(clearance)

    return imp_file, clearance


def test_record_clearance_invoice_success_and_aggregates(db_session, sample_clearance_setup):
    imp_file, clearance = sample_clearance_setup

    # Invoice 1: Customs Broker Fees
    inv1_payload = ClearanceExpenseInvoiceCreate(
        import_file_id=imp_file.import_file_id,
        customs_clearance_id=clearance.customs_clearance_id,
        invoice_number="INV-BRK-8801",
        invoice_date=datetime.now(timezone.utc),
        provider_name="مكتب الصفا للتخليص الجمركي",
        expense_category="Customs Broker Fees (أتعاب التخليص الجمركي)",
        currency="EGP",
        amount_egp=8500.0,
        vat_included=True,
        vat_amount=1190.0,
        wht_deducted=True,
        wht_amount=255.0,
        allocation_rule="Value-Based",
        notes="أتعاب التخليص الشاملة لشهادة 46",
    )
    inv1 = record_clearance_invoice_service(db_session, inv1_payload, current_user="Kamal")
    assert inv1.invoice_id is not None
    assert inv1.invoice_code.startswith("CLI-")
    assert inv1.net_payable_egp == 9435.0 # 8500 + 1190 - 255

    # Invoice 2: Port Dues & Wharfage
    inv2_payload = ClearanceExpenseInvoiceCreate(
        import_file_id=imp_file.import_file_id,
        customs_clearance_id=clearance.customs_clearance_id,
        invoice_number="REC-PORT-7744",
        invoice_date=datetime.now(timezone.utc),
        provider_name="هيئة ميناء الإسكندرية / الدخيلة",
        expense_category="Port Dues & Wharfage (نولون الميناء ورسوم الرصيف)",
        currency="EGP",
        amount_egp=12400.0,
        vat_included=False,
        vat_amount=0.0,
        wht_deducted=False,
        wht_amount=0.0,
        allocation_rule="Weight-Based",
    )
    inv2 = record_clearance_invoice_service(db_session, inv2_payload, current_user="Kamal")
    assert inv2.net_payable_egp == 12400.0

    # Verify clearance record aggregates
    db_session.refresh(clearance)
    assert clearance.clearance_invoices_count == 2
    assert clearance.total_clearance_expenses_egp == 21835.0 # 9435 + 12400
    assert clearance.total_port_expenses_egp == 12400.0

    # Verify import file sync
    db_session.refresh(imp_file)
    assert imp_file.total_clearance_expenses_egp == 21835.0
    assert imp_file.clearance_invoices_status == "Invoices Logged & Verified"
    assert imp_file.progress_percent >= 96.0


def test_clearance_invoices_landed_cost_settlement_sync(db_session, sample_clearance_setup):
    imp_file, clearance = sample_clearance_setup

    # Create a pre-existing LandedCostSettlementRecord
    suffix = datetime.now().strftime("%f")
    settlement = LandedCostSettlementRecord(
        settlement_code=f"LCS-TEST-{suffix}",
        import_file_id=imp_file.import_file_id,
        incoterm_code="FOB",
        expense_invoices=[],
        total_fob_egp=500000.0,
        total_expenses_egp=0.0,
        total_landed_cost_egp=500000.0,
        status="Draft",
    )
    db_session.add(settlement)
    db_session.commit()

    # Record handling invoice
    payload = ClearanceExpenseInvoiceCreate(
        import_file_id=imp_file.import_file_id,
        customs_clearance_id=clearance.customs_clearance_id,
        invoice_number="INV-STEV-3321",
        provider_name="شركة الإسكندرية لتداول الحاويات والبضائع",
        expense_category="Stevedoring & Handling (العتالة وتفريغ الحاويات)",
        currency="EGP",
        amount_egp=4200.0,
        vat_included=True,
        vat_amount=588.0,
        wht_deducted=False,
        wht_amount=0.0,
    )
    inv = record_clearance_invoice_service(db_session, payload, current_user="Kamal")
    assert inv.net_payable_egp == 4788.0

    # Verify synchronization into LandedCostSettlementRecord
    db_session.refresh(settlement)
    assert len(settlement.expense_invoices) >= 1
    found_item = next((i for i in settlement.expense_invoices if i.get("invoice_no") == "INV-STEV-3321"), None)
    assert found_item is not None
    assert found_item["net_payable_egp"] == 4788.0
    assert settlement.total_expenses_egp == 4200.0
    assert settlement.status == "Draft"


def test_clearance_invoices_sync_recalculates_calculated_settlement(db_session, sample_clearance_setup):
    """When settlement is Calculated, adding a clearance invoice recalculates settlement totals via engine."""
    imp_file, clearance = sample_clearance_setup
    suffix = datetime.now().strftime("%f")
    settlement = LandedCostSettlementRecord(
        settlement_code=f"LCS-CALC-{suffix}",
        import_file_id=imp_file.import_file_id,
        incoterm_code="FOB",
        expense_invoices=[],
        item_landed_costs=[{
            "line_no": 1,
            "item_code": "ITM-001",
            "item_name": "Test Machinery",
            "qty": 5,
            "fob_unit_egp": 10000.0,
            "gross_weight_kg": 500.0,
            "cbm": 2.5,
        }],
        total_fob_egp=50000.0,
        total_expenses_egp=0.0,
        total_landed_cost_egp=50000.0,
        status="Calculated",
    )
    db_session.add(settlement)
    db_session.commit()

    payload = ClearanceExpenseInvoiceCreate(
        import_file_id=imp_file.import_file_id,
        customs_clearance_id=clearance.customs_clearance_id,
        invoice_number=f"INV-CALC-{suffix}",
        provider_name="مكتب الصفا للتخليص الجمركي",
        expense_category="Customs Broker Fees (أتعاب التخليص الجمركي)",
        currency="EGP",
        amount_egp=5000.0,
    )
    inv = record_clearance_invoice_service(db_session, payload, current_user="Kamal")
    assert inv.amount_egp == 5000.0

    db_session.refresh(settlement)
    assert settlement.status == "Calculated"
    assert settlement.total_expenses_egp == 5000.0
    assert settlement.total_landed_cost_egp == 55000.0
    assert len(settlement.item_landed_costs) == 1
    assert settlement.item_landed_costs[0]["total_landed_cost_egp"] == 55000.0


def test_clearance_invoice_locked_settlement_blocks_record_and_delete(db_session, sample_clearance_setup):
    """When settlement is Approved or Closed, creating or deleting a clearance invoice raises 409 CC_SETTLEMENT_LOCKED."""
    imp_file, clearance = sample_clearance_setup

    # First record an invoice while no settlement is locked
    payload = ClearanceExpenseInvoiceCreate(
        import_file_id=imp_file.import_file_id,
        customs_clearance_id=clearance.customs_clearance_id,
        invoice_number="INV-BEFORE-LOCK-1",
        provider_name="مكتب الصفا للتخليص الجمركي",
        expense_category="Customs Broker Fees (أتعاب التخليص الجمركي)",
        currency="EGP",
        amount_egp=2000.0,
    )
    inv = record_clearance_invoice_service(db_session, payload, current_user="Kamal")
    assert inv.invoice_id is not None

    # Now create an Approved settlement
    suffix = datetime.now().strftime("%f")
    settlement = LandedCostSettlementRecord(
        settlement_code=f"LCS-APPR-{suffix}",
        import_file_id=imp_file.import_file_id,
        incoterm_code="FOB",
        expense_invoices=[{"invoice_no": inv.invoice_number, "amount_egp": 2000.0}],
        total_fob_egp=100000.0,
        total_expenses_egp=2000.0,
        total_landed_cost_egp=102000.0,
        status="Approved",
    )
    db_session.add(settlement)
    db_session.commit()

    # Attempt to record new clearance invoice -> 409 CC_SETTLEMENT_LOCKED
    payload2 = ClearanceExpenseInvoiceCreate(
        import_file_id=imp_file.import_file_id,
        customs_clearance_id=clearance.customs_clearance_id,
        invoice_number="INV-LOCKED-TEST",
        provider_name="هيئة الميناء",
        expense_category="Port Dues & Wharfage (نولون الميناء ورسوم الرصيف)",
        currency="EGP",
        amount_egp=3000.0,
    )
    with pytest.raises(HTTPException) as exc_info:
        record_clearance_invoice_service(db_session, payload2, current_user="Kamal")
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "CC_SETTLEMENT_LOCKED"
    assert exc_info.value.detail["settlement_code"] == settlement.settlement_code
    assert exc_info.value.detail["settlement_status"] == "Approved"

    # Attempt to delete existing clearance invoice -> 409 CC_SETTLEMENT_LOCKED
    with pytest.raises(HTTPException) as exc_info_del:
        delete_clearance_invoice_service(db_session, inv.invoice_id, current_user="Kamal")
    assert exc_info_del.value.status_code == 409
    assert exc_info_del.value.detail["code"] == "CC_SETTLEMENT_LOCKED"
    assert exc_info_del.value.detail["settlement_code"] == settlement.settlement_code
    assert exc_info_del.value.detail["settlement_status"] == "Approved"

    # Verify invoice is still active
    db_session.refresh(inv)
    assert inv.is_active is True

    # Test with Closed status
    settlement.status = "Closed"
    db_session.commit()

    with pytest.raises(HTTPException) as exc_info_closed:
        record_clearance_invoice_service(db_session, payload2, current_user="Kamal")
    assert exc_info_closed.value.status_code == 409
    assert exc_info_closed.value.detail["code"] == "CC_SETTLEMENT_LOCKED"
    assert exc_info_closed.value.detail["settlement_status"] == "Closed"

    # Verify settlement rows and totals untouched
    db_session.refresh(settlement)
    assert len(settlement.expense_invoices) == 1
    assert settlement.total_expenses_egp == 2000.0


def test_get_clearance_invoices_summary_and_delete(db_session, sample_clearance_setup):
    imp_file, clearance = sample_clearance_setup

    payload = ClearanceExpenseInvoiceCreate(
        import_file_id=imp_file.import_file_id,
        customs_clearance_id=clearance.customs_clearance_id,
        invoice_number="INV-TEST-DEL-1",
        provider_name="معامل الرقابة على الصادرات",
        expense_category="Laboratory & Testing Fees (رسوم التحاليل المعملية)",
        currency="EGP",
        amount_egp=3100.0,
    )
    inv = record_clearance_invoice_service(db_session, payload, current_user="Kamal")

    # Get summary
    summary = get_clearance_invoices_by_file_service(db_session, imp_file.import_file_id)
    assert summary.invoices_count >= 1
    assert summary.total_amount_egp >= 3100.0

    # Delete invoice
    deleted = delete_clearance_invoice_service(db_session, inv.invoice_id, current_user="Kamal")
    assert deleted is True

    # Check summary after delete
    summary_after = get_clearance_invoices_by_file_service(db_session, imp_file.import_file_id)
    assert all(i.invoice_id != inv.invoice_id for i in summary_after.invoices)


def test_cl05_rest_api_endpoints(sample_clearance_setup):
    imp_file, clearance = sample_clearance_setup

    # POST invoice
    post_data = {
        "import_file_id": imp_file.import_file_id,
        "customs_clearance_id": clearance.customs_clearance_id,
        "invoice_number": "INV-API-9900",
        "provider_name": "مكتب النيل للتخليص الملاحي",
        "expense_category": "Customs Broker Fees (أتعاب التخليص الجمركي)",
        "currency": "EGP",
        "amount_egp": 6000.0,
        "vat_included": True,
        "vat_amount": 840.0,
        "wht_deducted": True,
        "wht_amount": 180.0,
    }
    res = client.post("/api/v1/customs-clearance/invoices", json=post_data)
    assert res.status_code == 201, res.text
    data = res.json()
    assert data["invoice_code"].startswith("CLI-")
    assert data["net_payable_egp"] == 6660.0
    invoice_id = data["invoice_id"]

    # GET summary
    res_get = client.get(f"/api/v1/customs-clearance/invoices/by-file/{imp_file.import_file_id}")
    assert res_get.status_code == 200
    summary = res_get.json()
    assert summary["invoices_count"] >= 1
    assert summary["net_payable_egp"] >= 6660.0

    # DELETE invoice
    res_del = client.delete(f"/api/v1/customs-clearance/invoices/{invoice_id}")
    assert res_del.status_code == 200
    assert res_del.json()["status"] == "success"


def test_cl05_invoice_creates_exactly_one_coded_notification(db_session, sample_clearance_setup):
    """Phase B review: recording a CL-05 invoice saves the invoice and emits exactly one coded notification."""
    from modules.notifications.model import SystemNotification

    imp_file, clearance = sample_clearance_setup
    payload = ClearanceExpenseInvoiceCreate(
        import_file_id=imp_file.import_file_id,
        customs_clearance_id=clearance.customs_clearance_id,
        invoice_number="INV-PORT-NOTIF-1",
        invoice_date=datetime.now(timezone.utc),
        provider_name="Alexandria Port Authority",
        expense_category="PORT_DUES_WHARFAGE",
        currency="EGP",
        amount_egp=1200.0,
    )
    inv = record_clearance_invoice_service(db_session, payload, current_user="Kamal")
    assert inv.invoice_id is not None
    assert db_session.query(ClearanceExpenseInvoice).filter(ClearanceExpenseInvoice.invoice_id == inv.invoice_id).count() == 1

    notifs = db_session.query(SystemNotification).filter(
        SystemNotification.entity_type == "ImportFile",
        SystemNotification.entity_id == imp_file.import_file_id,
        SystemNotification.msg_code == "CC_CLEARANCE_INVOICE_RECORDED",
    ).all()
    assert len(notifs) == 1
    n = notifs[0]
    assert n.msg_params["invoice_number"] == "INV-PORT-NOTIF-1"
    assert n.msg_params["import_file_code"] == imp_file.import_file_code
    assert "INV-PORT-NOTIF-1" in n.message
