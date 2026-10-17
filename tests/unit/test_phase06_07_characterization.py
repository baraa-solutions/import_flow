"""
Phases 6-7 (customs preparation / clearance) characterization tests (plan T-1..T-8).

They pin the money outputs that the 06-07 quality wave must keep identical
(`docs/plans/phase-06-07-quality-plan.md` section 2). T-3 pins the CL-03 fix: a generic PUT after CL-02
keeps the development fee and the customs service fees in `total_duty_payable` (before the fix it dropped them).
"""

from datetime import datetime, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401 - registers every SQLAlchemy model
from database.database import Base
from modules.common import enum_codes
from modules.customs_clearance.model import ClearanceExpenseInvoice, CustomsClearanceRecord
from modules.customs_clearance.schemas import (
    ClearanceExpenseInvoiceCreate,
    CustomsClearanceUpdate,
    CustomsDutyPaymentSubmit,
    FinalDutyAssessmentSubmit,
)
from modules.customs_clearance.service import (
    assess_final_customs_duties_service,
    delete_clearance_invoice_service,
    get_clearance_invoices_by_file_service,
    record_clearance_invoice_service,
    record_customs_duty_payment_service,
    update_customs_clearance_service,
)
from modules.customs_clearance_quotations.schemas import (
    CustomsClearanceQuotationCreate,
    CustomsClearanceQuotationUpdate,
    CustomsClearanceRFQCreate,
)
from modules.customs_clearance_quotations.service import (
    add_quotation_service,
    create_rfq_service,
    update_quotation_service,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.import_files.model import ImportFile


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _import_file(db, code="IMP-0607-CHAR") -> ImportFile:
    imp = ImportFile(
        import_file_code=code,
        company_name="Char Co",
        supplier_name="Char Supplier",
        form46_no="46-CHAR-001",
        progress_percent=50.0,
        owner="tester",
        is_active=True,
    )
    db.add(imp)
    db.commit()
    db.refresh(imp)
    return imp


def _clearance(db, imp: ImportFile, **fields) -> CustomsClearanceRecord:
    values = dict(
        clearance_code=f"CLR-CHAR-{imp.import_file_id}",
        import_file_id=imp.import_file_id,
        declaration_46_no="46-CHAR-001",
        customs_office_name="Alexandria Port Customs",
        status="Inspection & Sampling Recorded",
        owner="tester",
    )
    values.update(fields)
    rec = CustomsClearanceRecord(**values)
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec


def _provider(db, provider_id: int, name: str) -> ExternalServiceProvider:
    p = ExternalServiceProvider(
        provider_id=provider_id, partner_code=f"ESP-{provider_id:04d}", partner_name=name, partner_type="Customs Broker"
    )
    db.add(p)
    db.commit()
    return p


ALL_COMPONENTS = dict(
    import_duty_amount=50000.10,
    vat_amount=77000.25,
    schedule_tax_amount=5000.0,
    development_fee_amount=1000.33,
    customs_service_fees=12500.0,
    wht_amount=2000.0,
    lab_service_fees=1500.0,
)
COMPONENT_SUM = round(sum(ALL_COMPONENTS.values()), 2)


def _assess(db, imp, **overrides):
    payload = dict(
        import_file_id=imp.import_file_id,
        nafeza_claim_number="CLM-CHAR-001",
        cif_base_amount=500000.0,
        customs_exchange_rate=48.6,
        **ALL_COMPONENTS,
    )
    payload.update(overrides)
    return assess_final_customs_duties_service(db, FinalDutyAssessmentSubmit(**payload), user="tester")


# ─── T-1 / T-2: CL-02 golden totals ──────────────────────────────────────────

def test_t1_cl02_total_sums_all_seven_components(db):
    imp = _import_file(db)
    _clearance(db, imp)
    rec = _assess(db, imp)
    assert rec.total_duty_payable == COMPONENT_SUM
    assert rec.actual_duty_total == COMPONENT_SUM


def test_t1_cl02_override_wins_rounded(db):
    imp = _import_file(db)
    _clearance(db, imp, estimated_duty_total=140000.0)
    rec = _assess(db, imp, actual_duty_total=149000.004)
    assert rec.total_duty_payable == 149000.0
    assert rec.actual_duty_total == 149000.0
    assert rec.duty_variance_amount == round(149000.0 - 140000.0, 2)
    assert rec.duty_variance_percentage == round(9000.0 / 140000.0 * 100, 2)


def test_t2_override_differs_from_components_both_kept(db):
    imp = _import_file(db)
    _clearance(db, imp)
    rec = _assess(db, imp, actual_duty_total=100.0)
    # Each component is stored as sent; the totals carry the override (CL-19: accepted, pinned).
    assert rec.import_duty_amount == ALL_COMPONENTS["import_duty_amount"]
    assert rec.development_fee_amount == ALL_COMPONENTS["development_fee_amount"]
    assert rec.customs_service_fees == ALL_COMPONENTS["customs_service_fees"]
    assert rec.total_duty_payable == 100.0
    assert rec.actual_duty_total == 100.0


# ─── T-3: generic PUT after CL-02 ────────────────────────────────────────────

def test_t3_put_after_cl02_keeps_dev_fee_and_service_fees(db):
    imp = _import_file(db)
    _clearance(db, imp)
    rec = _assess(db, imp)
    updated = update_customs_clearance_service(db, rec.customs_clearance_id, CustomsClearanceUpdate(notes="x"))
    # CL-03: one duty-total function for create / PUT / CL-02 -> all seven components.
    # (Before the fix the PUT summed five and dropped development_fee_amount + customs_service_fees.)
    assert updated.total_duty_payable == COMPONENT_SUM
    assert updated.actual_duty_total == COMPONENT_SUM


def test_t3b_notes_only_put_keeps_the_cl02_override(db):
    imp = _import_file(db)
    _clearance(db, imp)
    rec = _assess(db, imp, actual_duty_total=100.0)
    updated = update_customs_clearance_service(db, rec.customs_clearance_id, CustomsClearanceUpdate(notes="x"))
    # Assessed record: a PUT never writes the assessed totals.
    assert updated.total_duty_payable == 100.0
    assert updated.actual_duty_total == 100.0


def test_t3c_component_put_on_assessed_record_is_409(db):
    imp = _import_file(db)
    _clearance(db, imp)
    rec = _assess(db, imp, actual_duty_total=100.0)
    with pytest.raises(HTTPException) as exc:
        update_customs_clearance_service(db, rec.customs_clearance_id, CustomsClearanceUpdate(vat_amount=1.0))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "CC_ASSESSED_COMPONENTS_LOCKED"
    db.refresh(rec)
    assert rec.vat_amount == ALL_COMPONENTS["vat_amount"]
    assert rec.total_duty_payable == 100.0


def test_t3d_put_before_assessment_sums_seven_components(db):
    imp = _import_file(db)
    rec = _clearance(db, imp, development_fee_amount=10.0)
    updated = update_customs_clearance_service(db, rec.customs_clearance_id,
                                               CustomsClearanceUpdate(customs_service_fees=5.0, vat_amount=1.25))
    assert updated.total_duty_payable == 16.25
    assert updated.actual_duty_total == 16.25


# ─── T-4: CL-03 variance on the unrounded amount ─────────────────────────────

def test_t4_cl03_variance_unrounded_amount_pct_rounded(db):
    imp = _import_file(db)
    _clearance(
        db,
        imp,
        estimated_duty_total=999.9,
        import_duty_amount=1000.1,
        total_duty_payable=1000.1,
        actual_duty_total=1000.1,
        assessment_status="Assessed",
        payment_status="Payment Requested",
        nafeza_claim_number="CLM-CHAR-T4",
    )
    rec = record_customs_duty_payment_service(
        db,
        CustomsDutyPaymentSubmit(
            import_file_id=imp.import_file_id,
            bank_receipt_no="RCP-CHAR-1",
            sadad_number="SAD-CHAR-1",
            paying_bank_name="CIB",
            duty_paid_amount=1000.1,
        ),
        user="tester",
    )
    assert rec.duty_variance_amount == 1000.1 - 999.9  # not rounded
    assert rec.duty_variance_amount != 0.2
    assert rec.duty_variance_percentage == round((1000.1 - 999.9) / 999.9 * 100, 2)


# ─── T-5: invoice FX path and net formula ────────────────────────────────────

def test_t5_invoice_fx_and_net_formula_vat_included_still_adds(db):
    imp = _import_file(db)
    _clearance(db, imp)
    inv = record_clearance_invoice_service(
        db,
        ClearanceExpenseInvoiceCreate(
            import_file_id=imp.import_file_id,
            invoice_number="INV-FX-1",
            provider_name="Broker X",
            expense_category="BROKER_FEES",
            currency="USD",
            amount_fx=100.55,
            exchange_rate=48.37,
            amount_egp=0.0,
            vat_included=True,
            vat_amount=680.9,
            wht_amount=97.27,
        ),
        current_user="tester",
    )
    expected_egp = round(100.55 * 48.37, 2)
    assert inv.amount_egp == expected_egp
    assert inv.net_payable_egp == round(expected_egp + 680.9 - 97.27, 2)


# ─── T-6: category split ─────────────────────────────────────────────────────

CATEGORY_BUCKET = {
    "BROKER_FEES": "clearance",
    "OTHER_CLEARANCE": "clearance",
    "PORT_DUES_WHARFAGE": "port",
    "STORAGE_DEMURRAGE": "port",
    "STEVEDORING_HANDLING": "handling",
    "INSPECTION_WEIGHING": "other",
    "LABORATORY_TESTING": "other",
}


@pytest.mark.parametrize("code", sorted(CATEGORY_BUCKET))
@pytest.mark.parametrize("legacy", [False, True], ids=["code", "legacy_label"])
def test_t6_category_split(db, code, legacy):
    assert set(CATEGORY_BUCKET) == set(enum_codes.codes(enum_codes.CLEARANCE_EXPENSE_CATEGORY))
    imp = _import_file(db)
    rec = _clearance(db, imp)
    category = code
    if legacy:
        # A row stored before normalization: the bilingual legacy label.
        category = next(
            label for label, c in enum_codes.legacy_labels()[enum_codes.CLEARANCE_EXPENSE_CATEGORY].items()
            if c == code and "(" in label
        )
    db.add(ClearanceExpenseInvoice(
        invoice_code=f"CLI-CHAR-{code}",
        import_file_id=imp.import_file_id,
        customs_clearance_id=rec.customs_clearance_id,
        invoice_number="N1",
        provider_name="Provider",
        expense_category=category,
        amount_egp=1000.0,
        net_payable_egp=1000.0,
        created_by="tester",
        updated_by="tester",
    ))
    db.commit()

    summary = get_clearance_invoices_by_file_service(db, imp.import_file_id)
    buckets = {
        "clearance": summary.total_clearance_fees_egp,
        "port": summary.total_port_dues_egp,
        "handling": summary.total_handling_stevedoring_egp,
        "other": summary.total_other_expenses_egp,
    }
    expected = {k: (1000.0 if k == CATEGORY_BUCKET[code] else 0.0) for k in buckets}
    assert buckets == expected
    assert summary.net_payable_egp == 1000.0


def test_t6_record_aggregates_split(db):
    imp = _import_file(db)
    rec = _clearance(db, imp)
    for i, code in enumerate(sorted(CATEGORY_BUCKET)):
        record_clearance_invoice_service(
            db,
            ClearanceExpenseInvoiceCreate(
                import_file_id=imp.import_file_id,
                customs_clearance_id=rec.customs_clearance_id,
                invoice_number=f"INV-{i}",
                provider_name="Provider",
                expense_category=code,
                amount_egp=100.0 * (i + 1),
            ),
            current_user="tester",
        )
    db.refresh(rec)
    amounts = {code: 100.0 * (i + 1) for i, code in enumerate(sorted(CATEGORY_BUCKET))}
    assert rec.clearance_invoices_count == 7
    assert rec.total_clearance_expenses_egp == round(sum(amounts.values()), 2)
    assert rec.total_port_expenses_egp == amounts["PORT_DUES_WHARFAGE"] + amounts["STORAGE_DEMURRAGE"]
    assert rec.total_handling_expenses_egp == amounts["STEVEDORING_HANDLING"]


# ─── T-7: settlement snapshot rows ───────────────────────────────────────────

def test_t7_settlement_snapshot_after_create_and_delete(db):
    # BEW0-06 (docs/plans/backend-review/README.md section 6; be-09-review.md BE09-T04 steps 2-3): the snapshot no
    # longer hand-sums net_payable_egp; the header is the landed-cost engine result over all rows, which counts
    # each row at amount_egp (ex-VAT, pre-WHT). net_payable_egp stays on the row as an extra key only.
    # Rows therefore carry amount_egp, as every real settlement row does.
    imp = _import_file(db)
    rec = _clearance(db, imp)
    settlement = LandedCostSettlementRecord(
        settlement_code="LCS-CHAR-1",
        import_file_id=imp.import_file_id,
        expense_invoices=[
            {"invoice_no": "FRT-1", "category": "Freight", "amount_egp": 100.0, "net_payable_egp": 100.0},
            {"invoice_no": "OLD", "category": "Clearance / Old", "amount_egp": 55.0, "net_payable_egp": 55.0},
        ],
        total_expenses_egp=155.0,
    )
    db.add(settlement)
    db.commit()

    inv = record_clearance_invoice_service(
        db,
        ClearanceExpenseInvoiceCreate(
            import_file_id=imp.import_file_id,
            customs_clearance_id=rec.customs_clearance_id,
            invoice_number="INV-SNAP-1",
            provider_name="Port Authority",
            expense_category="PORT_DUES_WHARFAGE",
            amount_egp=1200.0,
            vat_amount=168.0,
        ),
        current_user="tester",
    )
    db.refresh(settlement)
    rows = settlement.expense_invoices
    assert [r["invoice_no"] for r in rows] == ["FRT-1", "INV-SNAP-1"]
    assert rows[1]["category"] == "Clearance / Port Dues & Wharfage"
    assert rows[1]["amount_egp"] == 1200.0
    assert rows[1]["net_payable_egp"] == 1368.0
    # Freight 100 + clearance amount_egp 1,200; the 168 VAT is not landed cost (BE09-T04 step 3).
    assert settlement.total_expenses_egp == round(100.0 + 1200.0, 2)

    delete_clearance_invoice_service(db, inv.invoice_id, current_user="tester")
    db.refresh(settlement)
    assert [r["invoice_no"] for r in settlement.expense_invoices] == ["FRT-1"]
    assert settlement.total_expenses_egp == 100.0


# ─── T-8: quotation totals and RFQ metrics ───────────────────────────────────

def test_t8_quote_total_lowest_fastest_and_status_flip(db):
    _provider(db, 1, "Broker One")
    _provider(db, 2, "Broker Two")
    rfq = create_rfq_service(db, CustomsClearanceRFQCreate(title="RFQ char", port_name="Alexandria Port"))
    assert rfq.status == "Draft"
    assert rfq.lowest_clearance_cost == 0.0

    q1 = add_quotation_service(db, rfq.rfq_id, CustomsClearanceQuotationCreate(
        provider_id=1, provider_name="Broker One", clearance_fee=3500.0, inland_transport_fee=7000.0,
        inspection_fee=1500.0, port_expenses=2000.0, miscellaneous_fee=500.0, estimated_turnaround_days=3,
    ))
    assert q1.total_cost == 14500.0
    q2 = add_quotation_service(db, rfq.rfq_id, CustomsClearanceQuotationCreate(
        provider_id=2, provider_name="Broker Two", clearance_fee=3000.0, inland_transport_fee=6500.0,
        inspection_fee=1200.0, port_expenses=1800.0, miscellaneous_fee=500.0, estimated_turnaround_days=4,
    ))
    assert q2.total_cost == 13000.0

    db.refresh(rfq)
    assert rfq.status == "Quotations Received"
    assert rfq.lowest_clearance_cost == 13000.0
    assert rfq.fastest_turnaround_days == 3

    updated = update_quotation_service(db, q1.quotation_id, CustomsClearanceQuotationUpdate(clearance_fee=500.0))
    assert updated.total_cost == 11500.0
    db.refresh(rfq)
    assert rfq.lowest_clearance_cost == 11500.0
