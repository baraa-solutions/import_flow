"""
Phase 3a package D2 regression tests: modules/import_documentation/service.py
(DOC-02, 03, 04, 05, 06, 07, 09, 11, 13, 15, 18, 19, 25-pin).
"""
from datetime import date, timedelta

import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main  # noqa: F401  (registers every model on Base.metadata)
from database.database import Base
import modules.currencies.model as curr_models
import modules.incoterms.model as inc_models
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder, POLineItem, PackingListItem
from modules.import_documentation.model import (
    DraftBLReviewSession,
    POPackingReconciliationSession,
    AcidRegistrationSession,
)
from modules.import_documentation.schemas import (
    AcidRegistrationCreate,
    AcidRegistrationUpdate,
    CertificateOfOriginReviewCreate,
    CertificateOfOriginReviewUpdate,
    DraftBLComparisonRequest,
    DraftBLReviewCreate,
    DraftBLReviewUpdate,
    DualApprovalRequest,
    InspectionCertificateReviewCreate,
    InvoiceBLMatchSessionCreate,
    InvoiceBLSyncRequest,
    NewDraftVersionRequest,
    POExtractAndCompareRequest,
    POFinalAdjustmentRequest,
    POReconciliationItem,
    POReconciliationSessionCreate,
)
from modules.cargo_shipping.model import CargoShippingRecord
from modules.docs_customs_approval.model import CustomsDocumentApproval
import modules.import_documentation.service as service
from modules.import_documentation.validators import acid_flags


ACID_REQUIRED = dict(importer_name="Importer Co", importer_tax_id="123456789", exporter_name="Exporter Co",
                     exporter_reg_id="DE1", exporter_country="Germany", proforma_invoice_no="PI-1",
                     pol_name="Hamburg", pod_name="Alexandria")


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    session.add(ImportFile(import_file_id=1, import_file_code="IMP-T-001", company_name="Importer Co",
                           supplier_name="Exporter Co", is_active=True))
    session.add(ImportFile(import_file_id=2, import_file_code="IMP-T-002", company_name="Other", supplier_name="Supp2", is_active=True))
    session.add(ImportFile(import_file_id=3, import_file_code="IMP-T-DEL", company_name="Del", supplier_name="Del", is_active=False))
    session.add(curr_models.Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
    session.add(curr_models.Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True))
    session.commit()
    yield session
    session.close()
    engine.dispose()


def _po(db, po_id, file_id, status="DRAFT"):
    db.add(PurchaseOrder(po_id=po_id, po_number=f"PO-T-{po_id}", import_file_id=file_id, project_id=1, company_id=1,
                         supplier_id=1, incoterm_id=1, currency_id=1, status=status, version=1, is_active=True))
    db.add(POLineItem(item_id=po_id * 10, po_id=po_id, description_ar="item", quantity=10, unit_price=1.0, total_price=10.0))
    db.add(PackingListItem(packing_item_id=po_id * 10, po_id=po_id, hs_code="940130", item_code="X",
                           qty_pkg=5, total_gross_weight_kg=50))
    db.commit()


def _adj_item(**kw):
    base = dict(item_code="X", description="item", initial_quantity=10, final_quantity=12, unit_price=1.0,
                final_unit_price=1.005, initial_unit_price=1.0, final_gross_weight_kg=60.0, final_packages_count=7)
    base.update(kw)
    return base  # dict: valid for POReconciliationItem and D1's POFinalAdjustmentItem


# --- DOC-02 -------------------------------------------------------------------------------------------------
def test_doc02_foreign_po_line_gives_400(db):
    _po(db, 1, 1)
    _po(db, 2, 2)
    req = POFinalAdjustmentRequest(import_file_id=1, final_invoice_number="INV-1", items=[_adj_item(po_item_id=20)])
    with pytest.raises(HTTPException) as exc:
        service.reconcile_po_final_adjustments_service(db, req, user="alice")
    assert exc.value.status_code == 400
    assert db.get(POLineItem, 20).quantity == 10


def test_doc02_cancelled_po_line_gives_400(db):
    _po(db, 1, 1, status="CANCELLED")
    req = POFinalAdjustmentRequest(import_file_id=1, final_invoice_number="INV-1", items=[_adj_item(po_item_id=10)])
    with pytest.raises(HTTPException) as exc:
        service.reconcile_po_final_adjustments_service(db, req)
    assert exc.value.status_code == 400


def test_doc02_updates_line_bumps_version_once_and_leaves_packing_row(db):
    _po(db, 1, 1)
    req = POFinalAdjustmentRequest(import_file_id=1, final_invoice_number="INV-1",
                                   items=[_adj_item(po_item_id=10, final_quantity=12)])
    res = service.reconcile_po_final_adjustments_service(db, req, user="alice")
    line = db.get(POLineItem, 10)
    po = db.get(PurchaseOrder, 1)
    pack = db.get(PackingListItem, 10)
    assert float(line.quantity) == 12
    assert float(line.total_price) == 12.06  # round(12 * 1.005, 2)
    assert po.version == 2 and po.updated_by == "alice"
    assert float(pack.qty_pkg) == 5 and float(pack.total_gross_weight_kg) == 50  # untouched without packing_item_id
    assert res["total_final_amount"] == 12.06
    assert res["total_final_amount_by_currency"] == {"USD": 12.06}
    assert res["items"][0]["variance_percentage"] == 20.0


def test_doc02_duplicate_po_line_rejected(db):
    _po(db, 1, 1)
    req = POFinalAdjustmentRequest(import_file_id=1, final_invoice_number="INV-1",
                                   items=[_adj_item(po_item_id=10), _adj_item(po_item_id=10, final_quantity=12)])
    with pytest.raises(HTTPException) as exc:
        service.reconcile_po_final_adjustments_service(db, req, user="alice")
    assert exc.value.status_code == 400
    assert "مكرر" in exc.value.detail


def test_be03_t01_po_final_adjustment_single_line_and_packing(db):
    # PO line item_id=11, qty 100, unit_price 2.5, total 250.00; packing row 21 (same PO), qty_pcs 1000.
    po = PurchaseOrder(po_id=10, po_number="PO-T-10", import_file_id=1, project_id=1, company_id=1,
                       supplier_id=1, incoterm_id=1, currency_id=1, status="DRAFT", version=1, is_active=True)
    db.add(po)
    line = POLineItem(item_id=11, po_id=10, description_ar="item11", quantity=100, unit_price=2.5, total_price=250.0)
    pack = PackingListItem(packing_item_id=21, po_id=10, hs_code="940130", item_code="X",
                           qty_pkg=10, total_gross_weight_kg=100)
    db.add(line)
    db.add(pack)
    db.commit()

    # Request:
    # {po_item_id:11, final_quantity:98, final_unit_price:2.5} and
    # {po_item_id:11, packing_item_id:21, final_quantity:1000, final_unit_price:2.5, final_gross_weight_kg:500}
    req = POFinalAdjustmentRequest(
        import_file_id=1,
        final_invoice_number="INV-FINAL-1",
        items=[
            _adj_item(po_item_id=11, final_quantity=98, final_unit_price=2.5, unit_price=2.5),
            _adj_item(po_item_id=11, packing_item_id=21, final_quantity=1000, final_unit_price=2.5,
                      unit_price=2.5, final_gross_weight_kg=500.0, final_packages_count=15),
        ],
    )
    res = service.reconcile_po_final_adjustments_service(db, req, user="alice")

    db.refresh(line)
    db.refresh(po)
    db.refresh(pack)

    assert line.quantity == 98
    assert line.total_price == 245.00
    assert po.total_amount_fob == 245.00
    assert pack.total_gross_weight_kg == 500.0
    assert pack.qty_pkg == 15
    assert po.total_packages_count == 15
    assert res["total_final_amount"] == 245.00
    assert res["total_gross_weight_kg"] == 500.0
    assert res["total_final_amount_by_currency"] == {"USD": 245.00}


def test_be03_t01_multi_po_weight_aggregation_with_and_without_packing(db):
    # PO 10 has packing row 21; PO 20 has NO packing row.
    po1 = PurchaseOrder(po_id=10, po_number="PO-T-10", import_file_id=1, project_id=1, company_id=1,
                        supplier_id=1, incoterm_id=1, currency_id=1, status="DRAFT", version=1, is_active=True)
    po2 = PurchaseOrder(po_id=20, po_number="PO-T-20", import_file_id=1, project_id=1, company_id=1,
                        supplier_id=1, incoterm_id=1, currency_id=1, status="DRAFT", version=1, is_active=True)
    line1 = POLineItem(item_id=11, po_id=10, description_ar="line1", quantity=10, unit_price=2.0, total_price=20.0, gross_weight_kg=10.0)
    pack1 = PackingListItem(packing_item_id=21, po_id=10, hs_code="940130", item_code="X", qty_pkg=1, total_gross_weight_kg=15.0)
    line2 = POLineItem(item_id=21, po_id=20, description_ar="line2", quantity=5, unit_price=4.0, total_price=20.0, gross_weight_kg=8.0)
    db.add_all([po1, po2, line1, pack1, line2])
    db.commit()

    req = POFinalAdjustmentRequest(
        import_file_id=1,
        final_invoice_number="INV-MULTI-1",
        items=[
            _adj_item(po_item_id=11, final_quantity=10, final_unit_price=2.0, unit_price=2.0, final_gross_weight_kg=10.0),
            _adj_item(po_item_id=11, packing_item_id=21, final_gross_weight_kg=25.0, final_packages_count=2),
            _adj_item(po_item_id=21, final_quantity=5, final_unit_price=4.0, unit_price=4.0, final_gross_weight_kg=12.0),
        ],
    )
    res = service.reconcile_po_final_adjustments_service(db, req, user="alice")

    # PO 10 takes 25.0 from packing row; PO 20 takes 12.0 from line item -> total 37.0
    assert res["total_gross_weight_kg"] == 37.0
    assert res["total_final_amount"] == 40.0
    assert res["total_final_amount_by_currency"] == {"USD": 40.0}


def test_doc02_negative_value_rejected(db):
    _po(db, 1, 1)
    with pytest.raises((HTTPException, ValidationError)):
        req = POFinalAdjustmentRequest(import_file_id=1, final_invoice_number="INV-1", items=[_adj_item(po_item_id=10, final_quantity=-1)])
        service.reconcile_po_final_adjustments_service(db, req)


def test_doc02_inactive_import_file_gives_404(db):
    req = POFinalAdjustmentRequest(import_file_id=3, final_invoice_number="INV-1", items=[])
    with pytest.raises(HTTPException) as exc:
        service.reconcile_po_final_adjustments_service(db, req)
    assert exc.value.status_code == 404


# --- DOC-03 -------------------------------------------------------------------------------------------------
def test_doc03_snapshot_has_no_placeholders(db):
    snap = service._build_system_bl_snapshot(db, 2)
    assert snap["acid_number"] is None
    assert snap["booking_no"] is None
    assert snap["vessel_name"] is None and snap["voyage_number"] is None
    assert snap["hs_codes"] == []
    assert "Phone" not in (snap["consignee"] or "")


def test_doc03_coo_template_lists_missing_fields(db):
    res = service.generate_coo_draft_template_service(db, 2, "EUR.1")
    missing = res.template_data["missing_fields"]
    assert "acid_number" in missing and "hs_code" in missing
    assert "7595528271" not in str(res.template_data)
    assert "SHANGHAI" not in str(res.template_data)


def test_doc03_inspection_template_has_no_sample_parties(db):
    res = service.generate_inspection_draft_template_service(db, 2, "SGS", "COC")
    data = res.template_data
    assert "Narbutas" not in str(data) and "Archi brands" not in str(data)
    assert data["inspected_items"] == []
    assert {"acid_number", "hs_code", "invoice_number", "invoice_amount"} <= set(data["missing_fields"])


def test_doc03_coo_certified_without_origin_gives_400(db):
    schema = CertificateOfOriginReviewCreate(import_file_id=2, certificate_number="C-1",
                                             comparison_matrix=[{"field_key": "x", "match_status": "MATCH"}])
    with pytest.raises(HTTPException) as exc:
        service.create_coo_review_service(db, schema, user="alice")
    assert exc.value.status_code == 400


# --- DOC-04 -------------------------------------------------------------------------------------------------
def _clean_review(db, file_id=1, **kw):
    payload = DraftBLReviewCreate(import_file_id=file_id, draft_bl_number="MEDU123", comparison_matrix=[{"k": 1}], **kw)
    return service.create_draft_bl_review_service(db, payload, user="alice")


def _importer_approves(db, review, user="importer-user"):
    return service.process_dual_approval_service(
        db, DualApprovalRequest(bl_review_id=review.bl_review_id, role="importer", action="Approved", approved_by="x"), user=user)


def test_doc04_create_never_auto_approves(db):
    review = _clean_review(db, status="APPROVED", approved_by="Kamal", importer_approval_status="Approved")
    assert review.status == "REVIEWED_PENDING_APPROVAL"
    assert review.importer_approval_status == "Pending"
    assert review.approved_by is None
    assert db.get(ImportFile, 1).bl_number is None


def test_doc04_put_ignores_status_and_final_gives_409(db):
    review = _clean_review(db)
    updated = service.update_draft_bl_review_service(db, review.bl_review_id, DraftBLReviewUpdate(status="FINAL", vessel_name="V1"), user="bob")
    assert updated.status == "REVIEWED_PENDING_APPROVAL" and updated.vessel_name == "V1"
    _importer_approves(db, review)
    service.approve_draft_bl_service(db, review.bl_review_id, user="boss")
    with pytest.raises(HTTPException) as exc:
        service.update_draft_bl_review_service(db, review.bl_review_id, DraftBLReviewUpdate(vessel_name="V2"), user="bob")
    assert exc.value.status_code == 409


def test_doc04_same_user_cannot_hold_both_roles(db):
    review = _clean_review(db)
    service.process_dual_approval_service(db, DualApprovalRequest(bl_review_id=review.bl_review_id, role="importer", action="Approved", approved_by="x"), user="alice")
    with pytest.raises(HTTPException) as exc:
        service.process_dual_approval_service(db, DualApprovalRequest(bl_review_id=review.bl_review_id, role="customs_broker", action="Approved", approved_by="y"), user="alice")
    assert exc.value.status_code == 409


def test_doc04_dual_approval_final_runs_workflow_and_blocks_reapproval(db):
    review = _clean_review(db)
    req = dict(bl_review_id=review.bl_review_id, action="Approved", approved_by="client-name")
    service.process_dual_approval_service(db, DualApprovalRequest(role="importer", **req), user="alice")
    final = service.process_dual_approval_service(db, DualApprovalRequest(role="customs_broker", **req), user="bob")
    assert final.status == "FINAL"
    assert final.importer_approved_by == "alice" and final.broker_approved_by == "bob"
    assert db.get(ImportFile, 1).bl_number == "MEDU123"
    with pytest.raises(HTTPException) as exc:
        service.process_dual_approval_service(db, DualApprovalRequest(role="importer", **req), user="carol")
    assert exc.value.status_code == 409


def test_doc04_invalid_action_rejected(db):
    review = _clean_review(db)
    bad = DualApprovalRequest.model_construct(bl_review_id=review.bl_review_id, role="importer", action="Maybe", approved_by="x", notes=None)
    with pytest.raises(HTTPException) as exc:
        service.process_dual_approval_service(db, bad, user="a")
    assert exc.value.status_code == 422


def test_doc04_create_on_inactive_file_gives_400(db):
    with pytest.raises(HTTPException) as exc:
        _clean_review(db, file_id=3)
    assert exc.value.status_code == 400


# --- DOC-05 -------------------------------------------------------------------------------------------------
def test_doc05_new_version_keeps_bl_number_and_only_from_latest(db):
    review = _clean_review(db)
    v2 = service.create_new_draft_version_service(db, NewDraftVersionRequest(parent_session_id=review.bl_review_id, draft_fields={}), user="a")
    assert v2.draft_bl_number == "MEDU123"
    assert v2.bl_review_code == f"{review.bl_review_code}-v2" and v2.version_number == 2
    with pytest.raises(HTTPException) as exc:
        service.create_new_draft_version_service(db, NewDraftVersionRequest(parent_session_id=review.bl_review_id, draft_fields={}), user="a")
    assert exc.value.status_code == 409
    v3 = service.create_new_draft_version_service(db, NewDraftVersionRequest(parent_session_id=v2.bl_review_id, draft_fields={}), user="a")
    assert v3.bl_review_code == f"{review.bl_review_code}-v3"


# --- DOC-06 -------------------------------------------------------------------------------------------------
def test_doc06_coo_critical_mismatch_needs_override_whatever_status(db):
    schema = CertificateOfOriginReviewCreate(
        import_file_id=1, certificate_number="C-1", country_of_origin="Germany", status="Correction Requested",
        has_discrepancies=False, comparison_matrix=[{"field_key": "importer_name", "match_status": "MISMATCH_CRITICAL", "severity": "BLOCKING"}],
    )
    with pytest.raises(HTTPException) as exc:
        service.create_coo_review_service(db, schema, user="alice")
    assert exc.value.status_code == 400


def test_doc06_draft_never_overwrites_certified(db):
    certified = CertificateOfOriginReviewCreate(import_file_id=1, certificate_number="C-1", country_of_origin="Germany",
                                                override_reason="Invoice number confirmed by phone",
                                                comparison_matrix=[{"field_key": "x", "match_status": "MATCH"}])
    saved = service.create_coo_review_service(db, certified, user="alice")
    assert saved.status == "Approved" and saved.reviewed_by == "alice"
    assert saved.comparison_matrix != [{"field_key": "x", "match_status": "MATCH"}]  # server matrix, not the client's"
    draft = CertificateOfOriginReviewCreate(import_file_id=1, certificate_number="C-2", is_draft=True,
                                            comparison_matrix=[{"field_key": "x", "match_status": "MATCH"}])
    with pytest.raises(HTTPException) as exc:
        service.create_coo_review_service(db, draft, user="alice")
    assert exc.value.status_code == 409


def test_doc06_inspection_client_status_ignored(db):
    schema = InspectionCertificateReviewCreate(import_file_id=1, status="Approved", has_discrepancies=False,
                                               comparison_matrix=[{"field_key": "acid", "match_status": "MISMATCH_MINOR"}])
    with pytest.raises(HTTPException) as exc:
        service.create_inspection_review_service(db, schema, user="a")
    assert exc.value.status_code == 400
    schema.override_reason = "Lab report accepted"
    saved = service.create_inspection_review_service(db, schema, user="a")
    assert saved.status == "Discrepancy_Accepted"


# --- DOC-07 / DOC-08 ----------------------------------------------------------------------------------------
def test_doc07_put_missing_coo_gives_404(db):
    with pytest.raises(HTTPException) as exc:
        service.update_coo_review_service(db, 999, CertificateOfOriginReviewUpdate(certificate_number="X"))
    assert exc.value.status_code == 404


def test_doc07_missing_invoice_bl_session_gives_404(db):
    with pytest.raises(HTTPException) as exc:
        service.get_invoice_bl_match_session_service(db, 999)
    assert exc.value.status_code == 404


# --- DOC-09 -------------------------------------------------------------------------------------------------
def test_doc09_recreate_after_delete_reactivates_row(db):
    first = service.create_po_reconciliation_session_service(db, POReconciliationSessionCreate(import_file_id=1, currency="USD", final_invoice_number="A"), user="a")
    service.delete_po_reconciliation_session_service(db, first.session_id, user="a")
    again = service.create_po_reconciliation_session_service(db, POReconciliationSessionCreate(import_file_id=1, currency="USD", final_invoice_number="B"), user="b")
    assert again.session_id == first.session_id and again.is_active and again.final_invoice_number == "B"
    assert db.query(POPackingReconciliationSession).count() == 1


# --- DOC-11 -------------------------------------------------------------------------------------------------
def test_doc11_failing_lifecycle_does_not_block_following_steps(db, monkeypatch):
    import modules.lifecycle_board.service as lc

    def boom(**kwargs):
        raise RuntimeError("lifecycle down")

    monkeypatch.setattr(lc, "advance_lifecycle_step_service", boom)
    review = _clean_review(db)
    _importer_approves(db, review)
    service.approve_draft_bl_service(db, review.bl_review_id, user="boss")
    from modules.notifications.model import SystemNotification
    assert db.query(SystemNotification).filter(SystemNotification.msg_code == "DOC_DRAFT_BL_REVIEWED").count() == 1
    assert db.get(ImportFile, 1).bl_number == "MEDU123"


# --- DOC-13 -------------------------------------------------------------------------------------------------
def _seed_codes(db):
    if not db.query(curr_models.Currency).filter_by(currency_code="USD").first():
        db.add(curr_models.Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True))
    if not db.query(inc_models.Incoterm).filter_by(incoterm_code="FOB").first():
        db.add(inc_models.Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True))
    db.commit()


def _cert_payload(**kw):
    base = dict(import_file_id=1, is_draft=False, invoice_data={"invoice_number": "INV-9", "currency": "USD"},
                bl_data={"draft_bl_number": "BL-9"}, notes="ok")
    base.update(kw)
    return InvoiceBLMatchSessionCreate(**base)


def test_doc13_bad_incoterm_gives_400_and_writes_nothing(db):
    _seed_codes(db)
    with pytest.raises(HTTPException) as exc:
        service.create_invoice_bl_match_session_service(db, _cert_payload(invoice_data={"invoice_number": "INV-9", "incoterm": "XXX"}), user="a")
    assert exc.value.status_code == 400
    db.rollback()
    assert db.get(ImportFile, 1).pi_number is None


def test_doc13_certify_stores_incoterm_code_on_file(db):
    _seed_codes(db)
    service.create_invoice_bl_match_session_service(
        db, _cert_payload(invoice_data={"invoice_number": "INV-9", "incoterm": "fob", "currency": "USD", "total_amount": 5}), user="a")
    db.expire_all()
    imp = db.get(ImportFile, 1)
    assert imp.incoterm_code == "FOB" and imp.pi_number == "INV-9"


def test_review3_draft_never_overwrites_certified_invoice_bl_session(db):
    _seed_codes(db)
    service.create_invoice_bl_match_session_service(db, _cert_payload(), user="a")
    with pytest.raises(HTTPException) as exc:
        service.create_invoice_bl_match_session_service(db, _cert_payload(is_draft=True), user="a")
    assert exc.value.status_code == 409


def test_doc13_second_certified_session_gives_409(db):
    _seed_codes(db)
    s = service.create_invoice_bl_match_session_service(db, _cert_payload(), user="a")
    assert s.certified_by == "a"
    assert db.get(ImportFile, 1).bl_number == "BL-9"
    with pytest.raises(HTTPException) as exc:
        service.create_invoice_bl_match_session_service(db, _cert_payload(), user="a")
    assert exc.value.status_code == 409


def test_doc13_critical_without_notes_gives_400(db):
    _seed_codes(db)
    with pytest.raises(HTTPException) as exc:
        service.create_invoice_bl_match_session_service(
            db,
            _cert_payload(
                invoice_data={"invoice_number": "INV-9", "currency": "USD", "total_gross_weight_kg": 1000},
                bl_data={"draft_bl_number": "BL-9", "total_gross_weight_kg": 1500},
                is_safe_for_certification=True,
                notes=" ",
            ),
            user="a",
        )
    assert exc.value.status_code == 400


# --- DOC-15 / DOC-19 ----------------------------------------------------------------------------------------
def test_doc15_no_expiry_defaults_to_issue_plus_validity_and_tracker_valid(db):
    res = service.create_acid_session_service(db, AcidRegistrationCreate(
        import_file_id=2, acid_number="1234567890123456789", requested_date=date.today(), generated_date=date.today(),
        **ACID_REQUIRED,
    ), user="a")
    assert res.expiry_date == date.today() + timedelta(days=service.ACID_DEFAULT_VALIDITY_DAYS)
    tracker = service.get_acid_tracker_service(db)
    row = next(i for i in tracker.items if i.import_file_id == 2)
    assert row.status == "Valid"
    assert row.days_remaining == service.ACID_DEFAULT_VALIDITY_DAYS


def test_doc15_pending_number_is_never_verified(db):
    service.create_acid_session_service(db, AcidRegistrationCreate(import_file_id=2, acid_number=None, generated_date=date.today(), **ACID_REQUIRED))
    sess = db.query(AcidRegistrationSession).filter_by(import_file_id=2).one()
    assert sess.acid_number == "PENDING" and sess.status == "Requested"


# --- BE03-T06: ACID verification status is derived on the server ---------------------------------------------
def test_be03_t06_acid_flags_unit():
    assert acid_flags(None) == (True, True, True, True, False)
    assert acid_flags({}) == (True, True, True, True, False)
    assert acid_flags({"items": [{"field": "importer_name", "match": False}]}) == (False, True, True, True, True)
    assert acid_flags({"items": [{"field": "exporter_name", "status": "MISMATCH"}]}) == (True, False, True, True, True)
    assert acid_flags({"items": [{"field": "proforma_invoice_no", "is_matched": False}]}) == (True, True, False, True, True)
    assert acid_flags({"items": [{"field": "pod_name", "is_matched": False}]}) == (True, True, True, False, True)
    assert acid_flags({"items": [
        {"field": "importer_name", "match": False},
        {"field": "pol_name", "match": False},
    ]}) == (False, True, True, False, True)


def test_be03_t06_create_acid_with_discrepancies_requires_override_reason(db):
    disc = {"items": [{"field": "exporter_name", "match": False}]}
    # Without override reason -> 400
    with pytest.raises(HTTPException) as exc:
        service.create_acid_session_service(db, AcidRegistrationCreate(
            import_file_id=2,
            acid_number="1234567890123456789",
            generated_date=date.today(),
            discrepancies_data=disc,
            **ACID_REQUIRED,
        ), user="a")
    assert exc.value.status_code == 400
    assert "يوجد اختلافات" in exc.value.detail

    # With override reason -> Discrepancy_Accepted, has_discrepancies True
    res = service.create_acid_session_service(db, AcidRegistrationCreate(
        import_file_id=2,
        acid_number="1234567890123456789",
        generated_date=date.today(),
        discrepancies_data=disc,
        discrepancy_override_reason="Supplier name shortened on Nafeza",
        **ACID_REQUIRED,
    ), user="a")
    assert res.status == "Discrepancy_Accepted"
    assert res.has_discrepancies is True
    assert res.is_exporter_matched is False


def test_be03_t06_put_status_verified_on_requested_stays_requested(db):
    created = service.create_acid_session_service(db, AcidRegistrationCreate(
        import_file_id=2,
        acid_number="PENDING",
        requested_date=date.today(),
        **ACID_REQUIRED,
    ), user="a")
    assert created.status == "Requested"

    # Client tries to force status="Verified" on a pending/requested session
    updated = service.update_acid_session_service(
        db, created.acid_id, AcidRegistrationUpdate(status="Verified")
    )
    assert updated.status == "Requested"


def test_be03_t06_different_acid_on_file_gives_409_conflict(db):
    # File 1 has acid_number="1111111111111111111"
    f = db.query(ImportFile).filter_by(import_file_id=1).one()
    f.acid_number = "1111111111111111111"
    db.commit()

    # Session with "2222222222222222222" -> 409 DOC_ACID_CONFLICT
    with pytest.raises(HTTPException) as exc:
        service.create_acid_session_service(db, AcidRegistrationCreate(
            import_file_id=1,
            acid_number="2222222222222222222",
            generated_date=date.today(),
            **ACID_REQUIRED,
        ), user="a")
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "DOC_ACID_CONFLICT"


def test_doc19_revision_report_uses_english_label(db):
    payload = DraftBLReviewCreate(import_file_id=1, checklist_data=[{
        "field_key": "vessel_name", "field_label_ar": "اسم السفينة", "field_label_en": "Vessel Name",
        "source_entity": "Booking", "system_value": "A", "draft_value": "B", "status": "Incorrect",
        "required_correction": "fix", "reason": "typo",
    }])
    review = service.create_draft_bl_review_service(db, payload, user="a")
    assert review.revision_report_data[0]["item"] == "Vessel Name"
    assert review.status == "REVISION_REQUIRED"


# --- DOC-25 (Q10 pin) ---------------------------------------------------------------------------------------
def test_q10_numeric_compare_with_zero_system_value_stays_match(db, monkeypatch):
    snap = {"total_gross_weight_kg": 0.0}
    monkeypatch.setattr(service, "_build_system_bl_snapshot", lambda db, fid: snap)
    res = service.compare_draft_bl_service(db, DraftBLComparisonRequest(import_file_id=1, draft_fields={"total_gross_weight_kg": 999}))
    row = next(r for r in res["comparison_matrix"] if r["field_key"] == "total_gross_weight_kg")
    assert row["match_status"] == "MATCH"


# --- diff-review follow-ups (#4, #5, #9, #10) -----------------------------------------------------------------
def test_review4_dual_approval_needs_pending_review(db):
    draft = _clean_review(db, is_draft=True)
    with pytest.raises(HTTPException) as exc:
        service.process_dual_approval_service(db, DualApprovalRequest(bl_review_id=draft.bl_review_id, role="importer", action="Approved", approved_by="x"), user="a")
    assert exc.value.status_code == 400


def test_review4_content_change_resets_approvals(db):
    review = _clean_review(db)
    service.process_dual_approval_service(db, DualApprovalRequest(bl_review_id=review.bl_review_id, role="importer", action="Approved", approved_by="x"), user="alice")
    updated = service.update_draft_bl_review_service(db, review.bl_review_id, DraftBLReviewUpdate(vessel_name="NEW"), user="bob")
    assert updated.importer_approval_status == "Pending" and updated.importer_approved_by is None
    # bob may now approve as broker without becoming FINAL (importer approval was reset)
    after = service.process_dual_approval_service(db, DualApprovalRequest(bl_review_id=review.bl_review_id, role="customs_broker", action="Approved", approved_by="x"), user="alice")
    assert after.status == "REVIEWED_PENDING_APPROVAL"


def test_review5_new_version_with_blocking_is_revision_required(db, monkeypatch):
    review = _clean_review(db)
    real = service.compare_draft_bl_service

    def blocking_compare(db_, req):
        res = real(db_, req)
        res["has_blocking_mismatch"] = True
        return res

    monkeypatch.setattr(service, "compare_draft_bl_service", blocking_compare)
    v2 = service.create_new_draft_version_service(db, NewDraftVersionRequest(parent_session_id=review.bl_review_id, draft_fields={}), user="a")
    assert v2.status == "REVISION_REQUIRED"


def test_review9_client_checklist_blocking_and_reason_check(db):
    row = {"field_key": "booking_no", "field_label_ar": "رقم الحجز", "field_label_en": "Booking No",
           "source_entity": "Booking", "system_value": "A", "draft_value": "B", "status": "Incorrect"}
    with pytest.raises(HTTPException) as exc:
        service.create_draft_bl_review_service(db, DraftBLReviewCreate(import_file_id=1, checklist_data=[row], has_blocking_mismatch=False), user="a")
    assert exc.value.status_code == 400
    row.update(required_correction="fix", reason="typo")
    review = service.create_draft_bl_review_service(db, DraftBLReviewCreate(import_file_id=1, checklist_data=[row], has_blocking_mismatch=False), user="a")
    assert review.has_blocking_mismatch is True


def test_review10_coo_put_draft_to_certified_runs_follow_ups(db):
    from modules.docs_customs_approval.model import CustomsDocumentApproval
    db.add(CustomsDocumentApproval(approval_code="CDA-T-COO", import_file_id=1, document_type="Certificate of Origin",
                                   overall_status="Draft", is_active=True))
    db.commit()
    draft = service.create_coo_review_service(db, CertificateOfOriginReviewCreate(
        import_file_id=1, certificate_number="C-9", is_draft=True, country_of_origin="Germany",
        comparison_matrix=[{"field_key": "x", "match_status": "MATCH"}]), user="a")
    app = db.query(CustomsDocumentApproval).filter_by(approval_code="CDA-T-COO").one()
    assert app.commercial_status != "Approved"
    saved = service.update_coo_review_service(db, draft.coo_review_id, CertificateOfOriginReviewUpdate(is_draft=False, override_reason="checked"), user="bob")
    assert saved.status == "Approved"
    db.refresh(app)
    assert app.commercial_status == "Approved" and app.commercial_reviewed_by == "bob"


# --- customs-rules-reviewer follow-ups (#3, #4, #5, #6) -------------------------------------------------------
def test_customs3_certify_writes_real_columns_only(db):
    _seed_codes(db)
    imp1 = db.get(ImportFile, 1)
    imp1.estimated_cost_currency = "EUR"
    db.commit()
    service.create_invoice_bl_match_session_service(db, _cert_payload(
        invoice_data={"invoice_number": "INV-9", "currency": "usd", "total_amount": 500, "incoterm": "FOB"}), user="a")
    db.expire_all()
    imp = db.get(ImportFile, 1)
    assert imp.estimated_cost_currency == "EUR" and imp.incoterm_code == "FOB"
    assert "total_amount" not in imp.__dict__


def test_customs4_sync_with_cargo_record_keeps_containers_only(db):
    from modules.cargo_shipping.model import CargoShippingRecord
    _seed_codes(db)
    db.add(CargoShippingRecord(cargo_shipping_code="CS-T-1", import_file_id=1, is_active=True))
    db.commit()
    containers = [{"container_no": "MSCU1234567", "seal_no": "S1"}]
    service.create_invoice_bl_match_session_service(db, _cert_payload(
        bl_data={"draft_bl_number": "BL-9", "vessel_name": "V", "total_gross_weight_kg": 10, "containers": containers}), user="a")
    db.expire_all()
    rec = db.query(CargoShippingRecord).filter_by(cargo_shipping_code="CS-T-1").one()
    assert rec.containers_loading_data == containers
    assert db.get(ImportFile, 1).bl_number == "BL-9"


def test_customs5_snapshot_reads_booking_through_cargo_relation(db):
    from modules.cargo_shipping.model import CargoShippingRecord
    from modules.freight_booking.model import ShipmentBooking
    bk = ShipmentBooking(booking_code="BK-T-1", booking_confirmation_no="MSC-BKG-1", shipping_line_name="MSC", is_active=True)
    db.add(bk)
    db.flush()
    db.add(CargoShippingRecord(cargo_shipping_code="CS-T-2", import_file_id=1, booking_id=bk.booking_id, is_active=True))
    db.commit()
    snap = service._build_system_bl_snapshot(db, 1)
    assert snap["booking_no"] == "MSC-BKG-1" and snap["shipping_line"] == "MSC"
    assert snap["total_gross_weight_kg"] is None and snap["qty_pkg"] is None
    assert snap["freight_terms"] is None and snap["shipping_mode"] is None


def test_customs6_po_header_totals_follow_adjusted_lines(db):
    _po(db, 1, 1)
    db.add(POLineItem(item_id=11, po_id=1, description_ar="second", quantity=2, unit_price=5.0, total_price=10.0,
                      gross_weight_kg=4.0, net_weight_kg=3.0, total_cbm=0.5))
    db.commit()
    req = POFinalAdjustmentRequest(import_file_id=1, final_invoice_number="INV-1", items=[
        _adj_item(po_item_id=10, final_quantity=3, final_unit_price=2.555, final_gross_weight_kg=6.0,
                  final_net_weight_kg=5.0, final_cbm=1.25),
        _adj_item(po_item_id=11, final_quantity=2, final_unit_price=0.0, unit_price=0.0, final_gross_weight_kg=0.0),
    ])
    res = service.reconcile_po_final_adjustments_service(db, req, user="alice")
    po = db.get(PurchaseOrder, 1)
    assert float(po.total_amount_fob) == round(7.67 + 10.0, 2)  # rounded line totals; zero price keeps 5.0
    assert float(po.total_gross_weight_kg) == 10.0 and float(po.total_net_weight_kg) == 8.0
    assert float(po.total_cbm) == 1.75
    assert res["total_final_amount"] == 17.67
    assert res["total_gross_weight_kg"] == 10.0  # zero final weight -> stored 4.0 counted


# --- security review: /approve fills only the missing role; FINAL reviews are not deleted ---------------------
def test_sec_approve_with_no_role_approved_gives_409(db):
    review = _clean_review(db)
    with pytest.raises(HTTPException) as exc:
        service.approve_draft_bl_service(db, review.bl_review_id, user="boss")
    assert exc.value.status_code == 409
    db.refresh(review)
    assert review.status == "REVIEWED_PENDING_APPROVAL" and review.broker_approval_status == "Pending"


def test_sec_approve_by_the_other_role_approver_gives_409(db):
    review = _clean_review(db)
    _importer_approves(db, review, user="alice")
    with pytest.raises(HTTPException) as exc:
        service.approve_draft_bl_service(db, review.bl_review_id, user="Alice")
    assert exc.value.status_code == 409


def test_sec_approve_fills_only_the_missing_role(db):
    review = _clean_review(db)
    _importer_approves(db, review, user="alice")
    final = service.approve_draft_bl_service(db, review.bl_review_id, user="boss")
    assert final.status == "FINAL"
    assert final.importer_approved_by == "alice" and final.broker_approved_by == "boss"
    assert final.approved_by == "alice & boss"


def test_sec_delete_final_review_gives_409_and_delete_is_audited(db):
    from modules.audit_logs.model import AuditLog
    review = _clean_review(db)
    _importer_approves(db, review, user="alice")
    service.approve_draft_bl_service(db, review.bl_review_id, user="boss")
    with pytest.raises(HTTPException) as exc:
        service.delete_draft_bl_review_service(db, review.bl_review_id, user="eve")
    assert exc.value.status_code == 409
    assert db.get(DraftBLReviewSession, review.bl_review_id).is_active is True

    other = _clean_review(db, file_id=2)
    service.delete_draft_bl_review_service(db, other.bl_review_id, user="eve")
    assert db.get(DraftBLReviewSession, other.bl_review_id).is_active is False
    log = db.query(AuditLog).filter_by(entity_type="DraftBLReviewSession", action="DELETE").one()
    assert log.performed_by == "eve"


# --- BE03-T07: Draft B/L blocking flags and versions are server-owned ----------------------------------------
def test_be03_t07_put_cannot_override_blocking_mismatch_and_dual_approval_blocked(db):
    row = {
        "field_key": "consignee", "field_label_ar": "المرسل إليه", "field_label_en": "Consignee",
        "source_entity": "Booking", "system_value": "Acme Corp", "draft_value": "Wrong Consignee",
        "status": "Incorrect", "required_correction": "Fix consignee", "reason": "Name mismatch",
    }
    review = service.create_draft_bl_review_service(
        db, DraftBLReviewCreate(import_file_id=1, checklist_data=[row], is_draft=False), user="alice"
    )
    assert review.status == "REVISION_REQUIRED"
    assert review.has_blocking_mismatch is True
    assert review.open_discrepancies_count == 1

    # Client tries to override blocking flags via PUT
    updated = service.update_draft_bl_review_service(
        db, review.bl_review_id, DraftBLReviewUpdate(
            has_blocking_mismatch=False, open_discrepancies_count=0
        ), user="bob"
    )
    assert updated.status == "REVISION_REQUIRED"
    assert updated.has_blocking_mismatch is True
    assert updated.open_discrepancies_count == 1

    # Dual approval cannot proceed on a review with blocking mismatch / REVISION_REQUIRED
    with pytest.raises(HTTPException) as exc:
        service.process_dual_approval_service(
            db, DualApprovalRequest(
                bl_review_id=review.bl_review_id, role="importer", action="Approved", approved_by="client"
            ), user="alice"
        )
    assert exc.value.status_code == 400


def test_be03_t07_new_version_deactivates_non_terminal_parent(db):
    row = {
        "field_key": "consignee", "field_label_ar": "المرسل إليه", "field_label_en": "Consignee",
        "source_entity": "Booking", "system_value": "Acme Corp", "draft_value": "Wrong Consignee",
        "status": "Incorrect", "required_correction": "Fix consignee", "reason": "Name mismatch",
    }
    parent = service.create_draft_bl_review_service(
        db, DraftBLReviewCreate(import_file_id=2, checklist_data=[row], is_draft=False), user="alice"
    )
    assert parent.is_active is True
    assert parent.status == "REVISION_REQUIRED"

    v2 = service.create_new_draft_version_service(
        db, NewDraftVersionRequest(parent_session_id=parent.bl_review_id, draft_fields={}), user="bob"
    )
    db.refresh(parent)
    assert parent.is_active is False
    assert v2.is_active is True

    # Exactly one active review for the file
    active_reviews = db.query(DraftBLReviewSession).filter_by(import_file_id=2, is_active=True).all()
    assert len(active_reviews) == 1
    assert active_reviews[0].bl_review_id == v2.bl_review_id


# --- BE03-T11: Real PO sources in compare and DCA matrix -----------------------------------
def test_be03_t11_soft_deleted_po_not_used(db):
    db.add(ImportFile(import_file_id=10, import_file_code="IMP-SD-1", company_name="Co", supplier_name="Sup", is_active=True))
    db.add(PurchaseOrder(po_id=101, po_number="PO-SD", import_file_id=10, project_id=1, company_id=1, supplier_id=1,
                         incoterm_id=1, currency_id=1, status="DRAFT", is_active=False))
    db.add(POLineItem(item_id=1001, po_id=101, description_ar="Soft Item", quantity=10, unit_price=5.0))
    db.commit()

    req = POExtractAndCompareRequest(
        import_file_id=10,
        invoice_data={"invoice_number": "INV-10", "items": [{"item_code": "X", "quantity": 10, "unit_price": 5.0}]},
    )
    res = service.extract_and_compare_po_documents_service(db, req)
    assert res.system_items_missing is True
    assert res.is_safe_for_certification is False
    assert res.overall_status == "DRAFT"
    assert len(res.reconciled_invoice_items) == 0


def test_be03_t11_file_with_no_po_lines_has_system_items_missing(db):
    db.add(ImportFile(import_file_id=11, import_file_code="IMP-NO-LINES", company_name="Co", supplier_name="Sup", is_active=True))
    db.add(PurchaseOrder(po_id=102, po_number="PO-EMPTY", import_file_id=11, project_id=1, company_id=1, supplier_id=1,
                         incoterm_id=1, currency_id=1, status="DRAFT", is_active=True))
    db.commit()

    req = POExtractAndCompareRequest(
        import_file_id=11,
        invoice_data={"invoice_number": "INV-11", "items": [{"item_code": "Y", "quantity": 20, "unit_price": 10.0}]},
    )
    res = service.extract_and_compare_po_documents_service(db, req)
    assert res.system_items_missing is True
    assert res.is_safe_for_certification is False
    assert res.overall_status == "DRAFT"
    assert len(res.reconciled_invoice_items) == 0


def test_be03_t11_packing_rows_expose_packing_item_id_and_po_item_id(db):
    db.add(ImportFile(import_file_id=12, import_file_code="IMP-PKG-TEST", company_name="Co", supplier_name="Sup", is_active=True))
    db.add(PurchaseOrder(po_id=103, po_number="PO-PKG", import_file_id=12, project_id=1, company_id=1, supplier_id=1,
                         incoterm_id=1, currency_id=1, status="DRAFT", is_active=True))
    db.add(POLineItem(item_id=2001, po_id=103, item_code="MAT-100", description_ar="Material", quantity=50, unit_price=2.0))
    db.add(PackingListItem(packing_item_id=3001, po_id=103, item_code="MAT-100", qty_pcs=50, qty_pkg=5, package_type="Carton",
                           total_gross_weight_kg=120.0, total_net_weight_kg=100.0, total_cbm=1.5, hs_code="841510"))
    db.commit()

    req = POExtractAndCompareRequest(
        import_file_id=12,
        invoice_data={"invoice_number": "INV-12", "items": [{"item_code": "MAT-100", "quantity": 50, "unit_price": 2.0}]},
        packing_data={"packing_list_number": "PL-12", "items": [{"item_code": "MAT-100", "packages_count": 5, "gross_weight_kg": 120.0}]},
    )
    res = service.extract_and_compare_po_documents_service(db, req)
    assert res.system_items_missing is False
    assert len(res.reconciled_packing_items) == 1
    pkg_row = res.reconciled_packing_items[0]
    assert pkg_row.packing_item_id == 3001
    assert pkg_row.po_item_id == 2001


# --- BE03-T12: Inspection draft template without invented standards -----------------------
def test_be03_t12_inspection_draft_no_invented_standards(db):
    # 1. No PO lines -> applicable_standards is empty list
    res_empty = service.generate_inspection_draft_template_service(db, 2, "SGS", "COC")
    assert res_empty.applicable_standards == []
    assert res_empty.template_data["coc_number"] == ""
    assert "coc_number" in res_empty.template_data["missing_fields"]
    assert "adopted_standard" in res_empty.template_data["missing_fields"]

    # 2. PO line "Steel bolts" -> item adopted_standard == "" and "adopted_standard" in missing_fields, no "brand: Standard"
    file_id = 15
    db.add(ImportFile(import_file_id=file_id, import_file_code="IMP-BOLTS-1", company_name="Co", supplier_name="", is_active=True))
    po = PurchaseOrder(po_id=150, po_number="PO-BOLTS", import_file_id=file_id, project_id=1, company_id=1, supplier_id=1,
                       incoterm_id=1, currency_id=1, status="DRAFT", is_active=True)
    db.add(po)
    line = POLineItem(item_id=1501, po_id=150, description_en="Steel bolts", description_ar="مسامير صلب", quantity=500.0, unit_price=0.5)
    db.add(line)
    db.commit()

    res = service.generate_inspection_draft_template_service(db, file_id, "COTECNA", "COC")
    assert res.template_data["coc_number"] == ""
    assert res.applicable_standards == []
    assert len(res.template_data["inspected_items"]) == 1
    item = res.template_data["inspected_items"][0]
    assert item["product_type"] == ""
    assert item["adopted_standard"] == ""
    assert "brand: Standard" not in item["description"]
    assert "adopted_standard" in res.template_data["missing_fields"]
    assert "coc_number" in res.template_data["missing_fields"]


def test_be03_t12_inspection_draft_matched_product_has_standard(db):
    file_id = 16
    db.add(ImportFile(import_file_id=file_id, import_file_code="IMP-CHAIR-1", company_name="Co", supplier_name="Mega Furn", is_active=True))
    po = PurchaseOrder(po_id=160, po_number="PO-CHAIR", import_file_id=file_id, project_id=1, company_id=1, supplier_id=1,
                       incoterm_id=1, currency_id=1, status="DRAFT", is_active=True)
    db.add(po)
    line = POLineItem(item_id=1601, po_id=160, description_en="Office Chairs", description_ar="كراسي", quantity=20.0, unit_price=50.0)
    db.add(line)
    db.commit()

    res = service.generate_inspection_draft_template_service(db, file_id, "TÜV", "COC")
    assert res.template_data["coc_number"] == ""
    assert any("ES 7321" in s for s in res.applicable_standards)
    assert len(res.template_data["inspected_items"]) == 1
    item = res.template_data["inspected_items"][0]
    assert item["product_type"] == "Office Chairs"
    assert "ES 7321" in item["adopted_standard"]
    assert "brand: Mega" in item["description"]
    assert "adopted_standard" not in res.template_data["missing_fields"]
    assert "coc_number" in res.template_data["missing_fields"]


# --- BE03-T16: Certified COO review is locked ---------------------------------------------
def test_be03_t16_certified_coo_post_locked_and_lifecycle_unchanged(db, monkeypatch):
    lifecycle_calls = []
    original_lifecycle = service._coo_certified_follow_ups

    def mock_follow_ups(*args, **kwargs):
        lifecycle_calls.append((args, kwargs))
        return original_lifecycle(*args, **kwargs)

    monkeypatch.setattr(service, "_coo_certified_follow_ups", mock_follow_ups)

    # 1. First certified POST succeeds and triggers follow-up
    certified = CertificateOfOriginReviewCreate(
        import_file_id=1,
        certificate_type="EUR.1",
        certificate_number="COO-CERT-1",
        country_of_origin="Germany",
        is_draft=False,
        override_reason="Matches approved PO",
        comparison_matrix=[{"field_key": "x", "match_status": "MATCH"}],
    )
    saved = service.create_coo_review_service(db, certified, user="alice")
    assert saved.status == "Approved"
    assert len(lifecycle_calls) == 1

    # 2. Second certified POST raises 409 and does not trigger lifecycle follow-up
    certified2 = CertificateOfOriginReviewCreate(
        import_file_id=1,
        certificate_type="EUR.1",
        certificate_number="COO-CERT-2",
        country_of_origin="Germany",
        is_draft=False,
        override_reason="Matches approved PO",
        comparison_matrix=[{"field_key": "x", "match_status": "MATCH"}],
    )
    with pytest.raises(HTTPException) as exc:
        service.create_coo_review_service(db, certified2, user="bob")
    assert exc.value.status_code == 409
    assert len(lifecycle_calls) == 1  # Unchanged!


def test_be03_t16_certified_coo_put_locked_except_notes_and_delete_locked(db):
    certified = CertificateOfOriginReviewCreate(
        import_file_id=1,
        certificate_type="EUR.1",
        certificate_number="COO-LOCK-1",
        country_of_origin="Germany",
        is_draft=False,
        override_reason="Valid COO",
        comparison_matrix=[{"field_key": "x", "match_status": "MATCH"}],
    )
    saved = service.create_coo_review_service(db, certified, user="alice")

    # 1. PUT on certified modifying certificate_number -> 409
    with pytest.raises(HTTPException) as exc:
        service.update_coo_review_service(
            db, saved.coo_review_id,
            CertificateOfOriginReviewUpdate(certificate_number="COO-LOCK-CHANGED"),
            user="alice",
        )
    assert exc.value.status_code == 409

    # 2. PUT on certified updating notes -> 200 OK
    updated = service.update_coo_review_service(
        db, saved.coo_review_id,
        CertificateOfOriginReviewUpdate(notes="Verified with chamber of commerce"),
        user="alice",
    )
    assert updated.notes == "Verified with chamber of commerce"
    assert updated.certificate_number == "COO-LOCK-1"

    # 3. DELETE on certified -> 409
    with pytest.raises(HTTPException) as exc:
        service.delete_coo_review_service(db, saved.coo_review_id, user="alice")
    assert exc.value.status_code == 409


# --- BE03-T04: Gate /invoice-bl/certify-and-sync behind certified session and container merge ---
def test_be03_t04_no_session_gives_409_and_approvals_unchanged(db):
    _seed_codes(db)
    app = CustomsDocumentApproval(
        approval_code="CDA-T-01",
        import_file_id=1,
        document_type="Commercial Invoice",
        commercial_status="Pending",
        is_active=True,
    )
    db.add(app)
    db.commit()

    req = InvoiceBLSyncRequest(
        import_file_id=1,
        invoice_data={"invoice_number": "INV-X", "currency": "USD"},
        bl_data={"draft_bl_number": "BL-X"},
    )
    with pytest.raises(HTTPException) as exc:
        service.sync_certified_invoice_bl_to_file_service(db, req, user="operator")

    assert exc.value.status_code == 409
    assert exc.value.detail.get("code") == "DOC_INVOICE_BL_NOT_CERTIFIED"

    db.refresh(app)
    assert app.commercial_status == "Pending"
    imp = db.get(ImportFile, 1)
    assert imp.bl_number is None
    assert imp.pi_number is None


def test_be03_t04_with_certified_session_syncs_session_data_ignoring_body(db):
    _seed_codes(db)
    app = CustomsDocumentApproval(
        approval_code="CDA-T-02",
        import_file_id=1,
        document_type="Commercial Invoice",
        commercial_status="Pending",
        is_active=True,
    )
    db.add(app)
    db.commit()

    service.create_invoice_bl_match_session_service(
        db,
        _cert_payload(
            invoice_data={"invoice_number": "INV-REAL", "currency": "USD"},
            bl_data={"draft_bl_number": "BL-REAL"},
            notes="certified ok",
        ),
        user="certifier",
    )

    # Call sync endpoint sending fake/ignored body data
    req = InvoiceBLSyncRequest(
        import_file_id=1,
        invoice_data={"invoice_number": "INV-FAKE"},
        bl_data={"draft_bl_number": "BL-FAKE"},
    )
    res = service.sync_certified_invoice_bl_to_file_service(db, req, user="operator")

    assert res["status"] == "success"
    assert res["message_code"] == "DOC_INVOICE_BL_SYNCED"

    db.expire_all()
    imp = db.get(ImportFile, 1)
    assert imp.bl_number == "BL-REAL"
    assert imp.pi_number == "INV-REAL"


def test_be03_t04_container_merge_preserves_vgm_and_tracking_status(db):
    _seed_codes(db)
    cargo = CargoShippingRecord(
        cargo_shipping_code="CS-T-04",
        import_file_id=1,
        is_active=True,
        containers_loading_data=[
            {"container_no": "MSCU1", "vgm_status": "Verified", "tracking_status": "GateIn"}
        ],
    )
    db.add(cargo)
    db.commit()

    service.create_invoice_bl_match_session_service(
        db,
        _cert_payload(
            bl_data={
                "draft_bl_number": "BL-CONT-1",
                "containers": [
                    {"container_no": "MSCU1", "seal_no": "S1"},
                    {"container_no": "MSCU2", "seal_no": "S2", "container_type": "40HC"},
                ],
            },
            notes="ok",
        ),
        user="certifier",
    )

    req = InvoiceBLSyncRequest(import_file_id=1, sync_to_shipping=True)
    service.sync_certified_invoice_bl_to_file_service(db, req, user="operator")

    db.expire_all()
    updated_cargo = db.get(CargoShippingRecord, cargo.cargo_shipping_id)
    containers = {c["container_no"]: c for c in updated_cargo.containers_loading_data}

    assert "MSCU1" in containers
    assert containers["MSCU1"]["vgm_status"] == "Verified"
    assert containers["MSCU1"]["tracking_status"] == "GateIn"
    assert containers["MSCU1"]["seal_no"] == "S1"

    assert "MSCU2" in containers
    assert containers["MSCU2"]["seal_no"] == "S2"
    assert containers["MSCU2"]["container_type"] == "40HC"


# --- BE03-T05: Server-owned gate fields for invoice/B-L and PO reconciliation sessions ---
def test_be03_t05_po_recon_empty_post_does_not_advance_lifecycle(db, monkeypatch):
    import modules.lifecycle_board.service as lc
    called = []
    monkeypatch.setattr(lc, "advance_lifecycle_step_service", lambda *args, **kwargs: called.append(kwargs))

    res = service.create_po_reconciliation_session_service(
        db,
        POReconciliationSessionCreate(import_file_id=1, currency="USD"),
        user="operator",
    )
    assert res.is_safe_for_certification is False
    assert res.overall_status == "DRAFT"
    assert len(called) == 0


def test_be03_t05_po_recon_missing_currency_gives_422():
    with pytest.raises(ValidationError):
        POReconciliationSessionCreate(import_file_id=1)


def test_be03_t05_po_recon_router_validation(db):
    from fastapi.testclient import TestClient
    from main import app
    from database.database import get_db

    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    try:
        client = TestClient(app)

        # Missing currency -> 422
        resp = client.post("/api/v1/import-documentation/po-reconciliation/sessions", json={"import_file_id": 1})
        assert resp.status_code == 422

        # Inactive / unknown currency -> 400
        resp_bad = client.post(
            "/api/v1/import-documentation/po-reconciliation/sessions",
            json={"import_file_id": 1, "currency": "XYZ"},
        )
        assert resp_bad.status_code == 400
    finally:
        app.dependency_overrides.pop(get_db, None)


def test_be03_t05_invoice_bl_server_gate_overrides_client(db):
    _seed_codes(db)
    # Draft session: client claims FULLY_MATCHED and is_safe=True without files
    session_data = InvoiceBLMatchSessionCreate(
        import_file_id=1,
        is_draft=True,
        is_safe_for_certification=True,
        overall_status="FULLY_MATCHED",
        critical_discrepancies_count=0,
    )
    saved = service.create_invoice_bl_match_session_service(db, session_data, user="operator")
    assert saved.is_safe_for_certification is False
    assert saved.overall_status == "DISCREPANCY_DETECTED"


# --- BE03-T09: Document workflows fire once per transition ---------------------------------
def test_be03_t09_acid_verified_workflows_fire_once(db):
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification
    from modules.import_documentation.schemas import AcidRegistrationUpdate

    # 1. Create verified ACID session (19 digits, generated_date present -> status="Verified")
    acid_req = AcidRegistrationCreate(
        import_file_id=1,
        acid_number="1234567890123456789",
        requested_date=date.today() - timedelta(days=5),
        generated_date=date.today(),
        expiry_date=date.today() + timedelta(days=90),
        **ACID_REQUIRED,
    )
    created = service.create_acid_session_service(db, acid_req, user="alice")
    assert created.status == "Verified"

    # Verify 1 freight-booking task and 1 notification created
    tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == 1,
        SmartTask.msg_code == "DOC_TASK_FREIGHT_BOOKING",
    ).all()
    assert len(tasks) == 1

    notifs = db.query(SystemNotification).filter(
        SystemNotification.entity_id == created.acid_id,
        SystemNotification.msg_code == "DOC_ACID_REGISTERED",
    ).all()
    assert len(notifs) == 1

    # 2. Update with broker name (saving verified ACID again) -> workflows should not fire again
    updated = service.update_acid_session_service(
        db, created.acid_id,
        AcidRegistrationUpdate(customs_broker_name="Sherif El-Gammal"),
        user="alice",
    )
    assert updated.customs_broker_name == "Sherif El-Gammal"

    tasks_after = db.query(SmartTask).filter(
        SmartTask.import_file_id == 1,
        SmartTask.msg_code == "DOC_TASK_FREIGHT_BOOKING",
    ).all()
    assert len(tasks_after) == 1

    notifs_after = db.query(SystemNotification).filter(
        SystemNotification.entity_id == created.acid_id,
        SystemNotification.msg_code == "DOC_ACID_REGISTERED",
    ).all()
    assert len(notifs_after) == 1


def test_be03_t09_banking_receive_twice_creates_one_declaration_task(db):
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification
    from modules.import_documentation.schemas import BankingDocumentCreate

    # 1. Create banking document in Requested state
    bank_req = BankingDocumentCreate(
        doc_type="Form 4",
        import_file_id=1,
        bank_name="National Bank of Egypt",
        amount=15000.0,
        currency_code="USD",
        doc_reference_number="PENDING",
        request_date=date.today() - timedelta(days=2),
    )
    created = service.create_banking_document_service(db, bank_req, user="alice")

    # Initially no declaration 46 task since it's not received yet
    init_tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == 1,
        SmartTask.msg_code == "DOC_TASK_DECLARATION_46",
    ).all()
    assert len(init_tasks) == 0

    # 2. First receive -> moves into issued state -> fires workflow
    rec1 = service.receive_banking_document_service(
        db, created.bank_doc_id,
        form4_number="FORM4-2026-999",
        received_date=date.today(),
        notes="First receive",
        user="alice",
    )
    assert rec1.status == "Received"

    tasks_after_first = db.query(SmartTask).filter(
        SmartTask.import_file_id == 1,
        SmartTask.msg_code == "DOC_TASK_DECLARATION_46",
    ).all()
    assert len(tasks_after_first) == 1

    notifs_after_first = db.query(SystemNotification).filter(
        SystemNotification.entity_id == created.bank_doc_id,
        SystemNotification.msg_code == "DOC_BANK_DOCUMENT_RECORDED",
    ).all()
    assert len(notifs_after_first) == 1

    # 3. Second receive with same form4 number -> should not duplicate task or notification
    rec2 = service.receive_banking_document_service(
        db, created.bank_doc_id,
        form4_number="FORM4-2026-999",
        received_date=date.today(),
        notes="Second receive correction",
        user="alice",
    )
    assert rec2.status == "Received"

    tasks_after_second = db.query(SmartTask).filter(
        SmartTask.import_file_id == 1,
        SmartTask.msg_code == "DOC_TASK_DECLARATION_46",
    ).all()
    assert len(tasks_after_second) == 1

    notifs_after_second = db.query(SystemNotification).filter(
        SystemNotification.entity_id == created.bank_doc_id,
        SystemNotification.msg_code == "DOC_BANK_DOCUMENT_RECORDED",
    ).all()
    assert len(notifs_after_second) == 1


def test_be03_t09_acid_upsert_does_not_duplicate_workflow(db):
    from modules.smart_tasks.model import SmartTask
    from modules.notifications.model import SystemNotification

    # First create
    acid_req = AcidRegistrationCreate(
        import_file_id=2,
        acid_number="9876543210987654321",
        requested_date=date.today() - timedelta(days=5),
        generated_date=date.today(),
        expiry_date=date.today() + timedelta(days=90),
        **ACID_REQUIRED,
    )
    c1 = service.create_acid_session_service(db, acid_req, user="alice")
    assert c1.status == "Verified"

    # Upsert with same file_id and same acid number
    acid_req_upsert = AcidRegistrationCreate(
        import_file_id=2,
        acid_number="9876543210987654321",
        requested_date=date.today() - timedelta(days=5),
        generated_date=date.today(),
        expiry_date=date.today() + timedelta(days=90),
        customs_broker_name="Broker B",
        **ACID_REQUIRED,
    )
    c2 = service.create_acid_session_service(db, acid_req_upsert, user="alice")
    assert c2.acid_id == c1.acid_id

    tasks = db.query(SmartTask).filter(
        SmartTask.import_file_id == 2,
        SmartTask.msg_code == "DOC_TASK_FREIGHT_BOOKING",
    ).all()
    assert len(tasks) == 1

    notifs = db.query(SystemNotification).filter(
        SystemNotification.entity_id == c1.acid_id,
        SystemNotification.msg_code == "DOC_ACID_REGISTERED",
    ).all()
    assert len(notifs) == 1


