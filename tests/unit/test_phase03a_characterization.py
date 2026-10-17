"""
Phase 3a package T: characterization tests for modules/import_documentation (docs/plans/phase-03a-quality-plan.md §3).

These pin today's behaviour BEFORE the D1/D2 fixes. Tests that document a known bug are
``xfail(strict=True)``: they assert the FIXED behaviour, so they fail on the old code and must be flipped
(xfail marker removed) by the package that fixes the bug.

Service calls go through ``_call`` which passes ``user=`` only when the service already accepts it
(D2 adds a trailing ``user`` keyword to every mutating service).
"""

import inspect
from datetime import date, timedelta

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  (registers every model on Base.metadata)
from database.database import Base
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.import_files.model import ImportFile
from modules.import_documentation.model import (
    AcidRegistrationSession,
    BankingDocumentSession,
    ShipmentDocumentItem,
    CustomsDeclarationDraft,
    DraftBLReviewSession,
    CertificateOfOriginReviewSession,
    InspectionCertificateReviewSession,
    POPackingReconciliationSession,
    InvoiceBLMatchSession,
)
from modules.import_documentation.schemas import (
    AcidRegistrationCreate,
    AcidRegistrationUpdate,
    BankingDocumentCreate,
    CustomsDeclarationCreate,
    DraftBLComparisonRequest,
    DraftBLChecklistItem,
    DraftBLReviewCreate,
    DualApprovalRequest,
    CertificateOfOriginReviewCreate,
    POReconciliationSessionCreate,
    POFinalAdjustmentRequest,
)
import modules.import_documentation.service as service
import modules.import_documentation.repository as repo

ACID_19 = "5281534391023010013"
ACID_19_B = "5281534391023010099"
YEAR = date.today().year


def _call(fn, *args, user="char_user", **kwargs):
    if "user" in inspect.signature(fn).parameters:
        kwargs["user"] = user
    return fn(*args, **kwargs)


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    session.add(
        ImportCompany(
            company_id=1, importer_name="Delta Industrial SAE", vat_id="100-200-300", registration_number="CR-1",
            address="10th of Ramadan", country="Egypt", importer_id="IMP-EG-1", importer_id_expiry=date(2030, 1, 1),
            vat_id_expiry=date(2030, 1, 1), registration_expiry=date(2030, 1, 1),
        )
    )
    session.add(
        Supplier(
            supplier_id=1, supplier_code="SUP-CN-001", company_name="Shanghai Machinery Co",
            supplier_type="Manufacturer", registration_type="Direct", foreign_exporter_id="CN-EXP-1",
            cargox_platform_id="CGX-1", foreign_exporter_country="China", foreign_exporter_country_code="CN",
            address="Shanghai", email="x@example.cn",
        )
    )
    for fid in (1, 2):
        session.add(
            ImportFile(
                import_file_id=fid,
                import_file_code=f"IMP-{YEAR}-000{fid}",
                custom_file_number=f"FILE-{fid}",
                company_id=1,
                company_name="Delta Industrial SAE",
                supplier_id=1,
                supplier_name="Shanghai Machinery Co",
                current_stage="STEP_05",
                progress_percent=30.0,
                is_active=True,
            )
        )
    from modules.currencies.model import Currency
    session.add(Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _acid_payload(**overrides):
    today = date.today()
    data = dict(
        import_file_id=1,
        acid_number=ACID_19,
        importer_name="Delta Industrial SAE",
        importer_tax_id="100-200-300",
        exporter_name="Shanghai Machinery Co",
        exporter_reg_id="CN-EXP-1",
        exporter_country="China",
        proforma_invoice_no="PI-1",
        pol_name="Shanghai",
        pod_name="Alexandria",
        requested_date=today - timedelta(days=4),
        generated_date=today - timedelta(days=2),
        expiry_date=today + timedelta(days=80),
    )
    data.update(overrides)
    return AcidRegistrationCreate(**data)


# 1 -------------------------------------------------------------------------------------------------
def test_01_acid_create_verified_syncs_file_and_advances_step05(db):
    payload = _acid_payload()
    res = _call(service.create_acid_session_service, db, payload)

    assert res.status == "Verified"
    assert res.acid_code == f"ACID-{YEAR}-001"
    assert res.execution_days == 2
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == 1).one()
    assert imp.acid_number == ACID_19
    assert imp.acid_request_date == payload.requested_date
    assert imp.acid_issue_date == payload.generated_date
    assert imp.acid_expiry_date == payload.expiry_date
    assert imp.acid_execution_days == 2
    # STEP_05 -> STEP_06 ran
    assert imp.next_action_code == "NA_STEP06_CONFIRM_BOOKING"
    assert (imp.progress_percent or 0) >= 40.0


# 2 -------------------------------------------------------------------------------------------------
def test_02_acid_duplicate_per_file_on_update_is_400_arabic(db):
    _call(service.create_acid_session_service, db, _acid_payload())
    other = _call(service.create_acid_session_service, db, _acid_payload(import_file_id=2, acid_number=ACID_19_B))

    with pytest.raises(HTTPException) as exc:
        _call(service.update_acid_session_service, db, other.acid_id, AcidRegistrationUpdate(import_file_id=1))
    assert exc.value.status_code == 400
    assert "لا يمكن حفظ طلب ACID جديد" in exc.value.detail
    assert f"ACID-{YEAR}-001" in exc.value.detail


# 3 -------------------------------------------------------------------------------------------------
def test_03_tracker_buckets_15_14_0_and_released(db):
    today = date.today()
    db.query(ImportFile).delete()
    specs = [(11, 15, False), (12, 14, False), (13, 0, False), (14, 3, True)]
    for fid, days, released in specs:
        db.add(
            ImportFile(
                import_file_id=fid,
                import_file_code=f"IMP-T-{fid}",
                company_name="Delta",
                supplier_name="Shanghai",
                acid_number=ACID_19,
                acid_issue_date=today + timedelta(days=days) - timedelta(days=90),
                acid_expiry_date=today + timedelta(days=days),
                is_customs_released=released,
                is_active=True,
            )
        )
    db.commit()

    summary = service.get_acid_tracker_service(db)
    by_file = {i.import_file_id: i for i in summary.items}

    assert by_file[11].status == "Valid" and by_file[11].days_remaining == 15 and by_file[11].alert_required is False
    assert by_file[11].validity_percentage == 16.7
    assert by_file[12].status == "Expiring Soon" and by_file[12].days_remaining == 14 and by_file[12].alert_required is True
    assert by_file[13].status == "Expired" and by_file[13].days_remaining == 0 and by_file[13].alert_required is True
    assert by_file[14].status == "Customs Released" and by_file[14].alert_required is False
    assert by_file[14].validity_percentage == 100.0
    assert (summary.total_acids_count, summary.valid_count, summary.expiring_soon_count) == (4, 1, 1)
    assert (summary.expired_count, summary.customs_released_count, summary.pending_issue_count) == (1, 1, 0)


# 4 -------------------------------------------------------------------------------------------------
def test_04_banking_create_with_reference_received_and_syncs_form4(db):
    req = date.today() - timedelta(days=10)
    rec = req + timedelta(days=5)
    res = _call(
        service.create_banking_document_service,
        db,
        BankingDocumentCreate(
            import_file_id=1, bank_name="National Bank", doc_reference_number="F4-123",
            amount=1000.0, request_date=req, received_date=rec,
        ),
    )
    assert res.status == "Received"
    assert res.execution_days == 5
    assert res.bank_doc_code == f"FORM4-{YEAR}-001"
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == 1).one()
    assert imp.form4_no == "F4-123"
    assert imp.form4_request_date == req
    assert imp.form4_received_date == rec
    assert imp.form4_execution_days == 5


# 5 -------------------------------------------------------------------------------------------------
_SNAPSHOT = {
    "shipper": "abcdefghij",
    "consignee": "abcdefghij",
    "booking_no": "BK-777",
    "acid_number": ACID_19,
    "total_gross_weight_kg": 1000.0,
    "total_net_weight_kg": 1000.0,
}


def test_05_draft_bl_compare_golden_matrix(db, monkeypatch):
    monkeypatch.setattr(service, "_build_system_bl_snapshot", lambda _db, _fid: dict(_SNAPSHOT))
    res = service.compare_draft_bl_service(
        db,
        DraftBLComparisonRequest(
            import_file_id=1,
            draft_fields={
                "shipper": "abcdefghik",        # ratio 0.90 >= 0.85 -> MATCH
                "consignee": "abcdefxyzw",      # ratio 0.60, critical -> BLOCKING
                "booking_no": "",               # critical, explicitly empty -> BLOCKING
                "acid_number": ACID_19,         # strict text MATCH
                "total_gross_weight_kg": 1005,  # 0.5 % -> MATCH
                "total_net_weight_kg": 1006,    # 0.6 % -> MISMATCH_MINOR / WARNING
                # vessel_name absent: non-critical missing -> WARNING
            },
        ),
    )
    m = {r["field_key"]: r for r in res["comparison_matrix"]}
    assert [r["field_key"] for r in res["comparison_matrix"]][:3] == ["shipper", "consignee", "notify_party"]
    assert len(res["comparison_matrix"]) == 20
    assert (m["shipper"]["match_status"], m["shipper"]["severity"]) == ("MATCH", "NONE")
    assert (m["consignee"]["match_status"], m["consignee"]["severity"]) == ("MISMATCH_CRITICAL", "BLOCKING")
    assert (m["booking_no"]["match_status"], m["booking_no"]["severity"]) == ("MISSING_IN_DRAFT", "BLOCKING")
    assert (m["vessel_name"]["match_status"], m["vessel_name"]["severity"]) == ("MISSING_IN_DRAFT", "WARNING")
    assert (m["acid_number"]["match_status"], m["acid_number"]["severity"]) == ("MATCH", "NONE")
    assert (m["total_gross_weight_kg"]["match_status"], m["total_gross_weight_kg"]["severity"]) == ("MATCH", "NONE")
    assert (m["total_net_weight_kg"]["match_status"], m["total_net_weight_kg"]["severity"]) == ("MISMATCH_MINOR", "WARNING")
    assert m["total_net_weight_kg"]["tolerance_pct"] == 0.6

    assert res["has_blocking_mismatch"] is True
    assert len(res["blocking_reasons"]) == len(res["blocking_reasons_coded"]) == 2
    assert res["blocking_reasons_coded"] == [
        {"code": "DOC_DRAFT_BLOCKING_CRITICAL_MISMATCH", "params": {"field_enum_draft_bl_field": "CONSIGNEE"}},
        {"code": "DOC_DRAFT_BLOCKING_FIELD_EMPTY", "params": {"field_enum_draft_bl_field": "BOOKING_NO"}},
    ]
    checklist = {c["field_key"]: c for c in res["checklist_data"]}
    assert checklist["consignee"]["status"] == "Incorrect"
    assert checklist["booking_no"]["status"] == "Missing"
    assert res["open_discrepancies_count"] == 2  # consignee + net weight
    assert res["status"] == "REVISION_REQUIRED"
    assert [r["item"] for r in res["revision_report_data"]] == [
        "Consignee Name, Address & Phone", "Net Weight (KG)",
    ]


# 6 -------------------------------------------------------------------------------------------------
def _review_row(db, **overrides):
    data = dict(
        bl_review_code=f"BL-REV-{YEAR}-0001",
        import_file_id=1,
        draft_bl_number="MEDU1234567",
        booking_no="BK-777",
        status="REVIEWED_PENDING_APPROVAL",
        stage="Stage 4: Dual Approval",
        open_discrepancies_count=0,
        system_snapshot_data=dict(_SNAPSHOT),
        is_active=True,
    )
    data.update(overrides)
    row = DraftBLReviewSession(**data)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _checklist_item(status, **kw):
    return DraftBLChecklistItem(
        field_key="vessel_name", field_label_ar="اسم الباخرة", field_label_en="Vessel Name",
        source_entity="Final Booking", system_value="MSC ANNA", draft_value="MSC ANA", status=status, **kw,
    )


def test_06_checklist_incorrect_needs_reason_then_sets_revision(db):
    review = _review_row(db)
    with pytest.raises(HTTPException) as exc:
        _call(service.update_draft_bl_checklist_service, db, review.bl_review_id, [_checklist_item("Incorrect")])
    assert exc.value.status_code == 400

    updated = _call(
        service.update_draft_bl_checklist_service,
        db,
        review.bl_review_id,
        [_checklist_item("Incorrect", required_correction="Fix vessel to MSC ANNA", reason="Typo")],
    )
    assert updated.status == "REVISION_REQUIRED"
    assert updated.stage == "Stage 2: Revision Required"
    assert updated.open_discrepancies_count == 1
    assert "Fix vessel to MSC ANNA" in updated.correction_request_letter
    assert "BK-777" in updated.correction_request_letter


# 7 -------------------------------------------------------------------------------------------------
def test_07_dual_approval_importer_then_broker_is_final_and_runs_workflow(db):
    review = _review_row(db)
    _call(
        service.process_dual_approval_service, db,
        DualApprovalRequest(bl_review_id=review.bl_review_id, role="importer", action="Approved", approved_by="alice"),
        user="alice",
    )
    final = _call(
        service.process_dual_approval_service, db,
        DualApprovalRequest(bl_review_id=review.bl_review_id, role="customs_broker", action="Approved", approved_by="bob"),
        user="bob",
    )
    assert final.status == "FINAL"
    assert final.stage == "Stage 5: Final"
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == 1).one()
    assert imp.bl_number == "MEDU1234567"
    assert (imp.progress_percent or 0) >= 65.0


# 8 -------------------------------------------------------------------------------------------------
def _coo_payload(**overrides):
    data = dict(
        import_file_id=1, certificate_type="EUR.1", certificate_number="EUR1-1",
        exporter_name="Shanghai Machinery Co", importer_name="Delta Industrial SAE", country_of_origin="China",
        comparison_matrix=[{"field_key": "origin", "match_status": "MISMATCH"}],
        has_discrepancies=True, is_draft=False, override_reason=None,
    )
    data.update(overrides)
    return CertificateOfOriginReviewCreate(**data)


def test_08_coo_certified_with_discrepancies_and_no_override_is_400(db):
    with pytest.raises(HTTPException) as exc:
        _call(service.create_coo_review_service, db, _coo_payload(status="Verified"))
    assert exc.value.status_code == 400


# 9 -------------------------------------------------------------------------------------------------
def test_09_po_reconciliation_session_duplicate_active_is_400(db):
    first = _call(service.create_po_reconciliation_session_service, db, POReconciliationSessionCreate(import_file_id=1, currency="USD"))
    assert first.session_code == f"REC-{YEAR}-0001"
    with pytest.raises(HTTPException) as exc:
        _call(service.create_po_reconciliation_session_service, db, POReconciliationSessionCreate(import_file_id=1, currency="USD"))
    assert exc.value.status_code == 400
    assert first.session_code in exc.value.detail


# 10 ------------------------------------------------------------------------------------------------
def test_10_po_final_adjustments_variance_rounding_and_totals(db):
    req = POFinalAdjustmentRequest(
        import_file_id=1,
        final_invoice_number="INV-77",
        items=[
            dict(
                item_code="A1", description="Widget", initial_quantity=100, final_quantity=110,
                initial_unit_price=10.0, final_unit_price=10.5,
                initial_gross_weight_kg=100.0, final_gross_weight_kg=101.234,
                final_net_weight_kg=90.556, final_cbm=1.23456,
            ),
            dict(
                item_code="B2", description="Gadget", initial_quantity=3, final_quantity=2,
                unit_price=7.0, final_gross_weight_kg=10.0, final_net_weight_kg=9.0, final_cbm=0.1,
            ),
        ],
    )
    res = _call(service.reconcile_po_final_adjustments_service, db, req)
    a, b = res["items"]
    assert (a["variance_percentage"], a["price_variance_percentage"], a["weight_variance_percentage"]) == (10.0, 5.0, 1.23)
    assert (b["variance_percentage"], b["price_variance_percentage"], b["weight_variance_percentage"]) == (-33.33, 0.0, 0.0)
    assert b["unit_price"] == b["final_unit_price"] == 7.0
    assert res["total_items_count"] == 2
    assert res["total_final_amount"] == 1169.0  # 110*10.5 + 2*7
    assert res["total_gross_weight_kg"] == 111.23
    assert res["total_net_weight_kg"] == 99.56
    assert res["total_cbm"] == 1.335
    imp = db.query(ImportFile).filter(ImportFile.import_file_id == 1).one()
    assert imp.pi_number == "INV-77"
    # ImportFile has no total_amount column: the service's `imp_file.total_amount = ...` is never persisted.
    assert "total_amount" not in ImportFile.__table__.columns


# 11 ------------------------------------------------------------------------------------------------
def _seed_code_row(db, model, code_attr, code, **extra):
    db.add(model(**{code_attr: code}, **extra))
    db.commit()


_ACID_EXTRA = dict(
    acid_number="PENDING", importer_name="x", importer_tax_id="x", exporter_name="x", exporter_reg_id="x",
    exporter_country="x", proforma_invoice_no="x", pol_name="x", pod_name="x", expiry_date=date.today(),
)

CODE_CASES = [
    ("ACID", 3, repo.generate_acid_code, AcidRegistrationSession, "acid_code", _ACID_EXTRA),
    ("FORM4", 3, repo.generate_bank_doc_code, BankingDocumentSession, "bank_doc_code", dict(bank_name="B")),
    ("DOC", 3, repo.generate_shipment_doc_code, ShipmentDocumentItem, "document_code", dict(doc_name="Inv", doc_number="1")),
    ("BL-REV", 4, repo.generate_bl_review_code, DraftBLReviewSession, "bl_review_code", dict(import_file_id=1)),
    ("COO", 4, repo.generate_coo_review_code, CertificateOfOriginReviewSession, "coo_review_code",
     dict(import_file_id=1, exporter_name="e", importer_name="i", country_of_origin="c")),
    ("INSP", 4, repo.generate_inspection_review_code, InspectionCertificateReviewSession, "inspection_review_code",
     dict(import_file_id=1)),
    ("REC", 4, repo.generate_po_reconciliation_session_code, POPackingReconciliationSession, "session_code",
     dict(import_file_id=1)),
    ("MATCH", 4, repo.generate_invoice_bl_match_session_code, InvoiceBLMatchSession, "session_code",
     dict(import_file_id=1)),
]


@pytest.mark.parametrize("prefix,pad,gen,model,code_attr,extra", CODE_CASES, ids=[c[0] for c in CODE_CASES])
def test_11_code_generation_golden(db, prefix, pad, gen, model, code_attr, extra):
    assert gen(db) == f"{prefix}-{YEAR}-{1:0{pad}d}"
    _seed_code_row(db, model, code_attr, f"{prefix}-{YEAR}-{7:0{pad}d}", **extra)
    assert gen(db) == f"{prefix}-{YEAR}-{8:0{pad}d}"


# Known bugs: assert the FIXED behaviour (xfail strict until the fixing package flips them) -------------
# DOC-04a fixed by D2: xfail removed.
def test_doc04a_draft_bl_create_never_auto_approves(db):
    saved = _call(
        service.create_draft_bl_review_service,
        db,
        DraftBLReviewCreate(
            import_file_id=1,
            draft_bl_number="MEDU1234567",
            checklist_data=[_checklist_item("Correct").model_dump()],
        ),
    )
    assert saved.status != "APPROVED"
    assert saved.status == "REVIEWED_PENDING_APPROVAL"


# DOC-06 fixed by D2: xfail removed.
def test_doc06_coo_critical_mismatch_without_override_is_400(db):
    with pytest.raises(HTTPException) as exc:
        _call(
            service.create_coo_review_service,
            db,
            _coo_payload(status="Correction Requested", has_critical_mismatch=True),
        )
    assert exc.value.status_code == 400


# DOC-09 fixed by D2: xfail removed.
def test_doc09_po_reconciliation_create_after_delete(db):
    first = _call(service.create_po_reconciliation_session_service, db, POReconciliationSessionCreate(import_file_id=1, currency="USD"))
    _call(service.delete_po_reconciliation_session_service, db, first.session_id)
    again = _call(
        service.create_po_reconciliation_session_service, db,
        POReconciliationSessionCreate(import_file_id=1, currency="USD", final_invoice_number="INV-2"),
    )
    assert again.is_active is True
    assert again.final_invoice_number == "INV-2"


# DOC-10 fixed by D1 (repository.generate_customs_declaration_code): xfail removed.
def test_doc10_second_dec46_gets_next_code(db):
    first = _call(service.create_customs_declaration_service, db, CustomsDeclarationCreate(import_file_id=1, acid_number=ACID_19))
    second = _call(service.create_customs_declaration_service, db, CustomsDeclarationCreate(import_file_id=2, acid_number=ACID_19))
    assert first.declaration_code == f"DEC46-{YEAR}-001"
    assert second.declaration_code == f"DEC46-{YEAR}-002"


# DOC-05c fixed by D1 (generate_bl_review_code via next_yearly_code): xfail removed.
def test_doc05c_bl_review_code_after_version_suffix(db):
    _review_row(db, bl_review_code=f"BL-REV-{YEAR}-0001")
    _review_row(db, bl_review_code=f"BL-REV-{YEAR}-0001-v2", version_number=2)
    assert repo.generate_bl_review_code(db) == f"BL-REV-{YEAR}-0002"
