"""Phase 9 regression tests (docs/plans/phase-09-quality-plan.md): one or more per fixed finding."""
from datetime import date, datetime
from decimal import Decimal
from unittest.mock import patch

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError

import modules.auth.permissions as permissions
from database.database import get_db
from modules.audit_logs.model import AuditLog
from modules.currencies.model import Currency, ExchangeRate
from modules.freight_booking.model import ShipmentBooking
from modules.import_files.model import ImportFile
from modules.smart_tasks.model import SmartTask
from modules.financial_settlement.model import LandedCostSettlementRecord
from modules.financial_settlement.odoo_export_service import (
    export_odoo_csv_service,
    generate_odoo_journal_entry_service,
)
from modules.financial_settlement.schemas import (
    ApproveActualLandedCostRequest,
    ConfirmInvoicesSettlementRequest,
    FinancialSettlementCreate,
    FinancialSettlementUpdate,
)
from modules.financial_settlement import service as fs
from modules.recalculation import service as rc
from modules.recalculation.model import RecalculationLog
from modules.recalculation.schemas import RecalculationApplyRequest
from modules.users.model import User

from tests.unit.test_phase09_characterization import (  # noqa: F401  (db fixture + seeds)
    ODOO_EXPENSES,
    db,
    seed_actual_sources,
    seed_odoo_settlement,
    seed_shipment,
)


def _code(exc_info):
    detail = exc_info.value.detail
    return detail.get("code") if isinstance(detail, dict) else None


def _approved(db):
    imp = seed_shipment(db, cbm=(12.0, 4.0))
    seed_actual_sources(db, imp)
    imp.financial_settlement_status = "INVOICES_SETTLED"
    db.commit()
    res = fs.approve_actual_landed_cost_service(
        db, ApproveActualLandedCostRequest(import_file_id=imp.import_file_id, approved_by="spoofed"), actor="alice"
    )
    return imp, res, db.query(LandedCostSettlementRecord).get(res.settlement_id)


# ── FS-01 / FS-04 ────────────────────────────────────────────────────────────

def test_approve_stores_canonical_invoices_and_items_and_records_the_actor(db):
    imp, res, rec = _approved(db)
    assert rec.status == "Approved"
    assert rec.accountant_name == "alice" and rec.created_by == "alice"  # body approved_by ignored
    assert len(rec.expense_invoices) == 4
    for e in rec.expense_invoices:
        assert {"invoice_no", "category", "provider_name", "currency", "amount_fx", "exchange_rate",
                "amount_egp", "allocation_rule", "bucket"} <= set(e)
        assert e["amount_egp"] > 0
    assert round(sum(e["amount_egp"] for e in rec.expense_invoices), 2) == rec.total_expenses_egp
    for i in rec.item_landed_costs:
        assert i["total_landed_cost_egp"] == i["actual_total_landed_cost_egp"] > 0
        assert i["unit_landed_cost_egp"] > 0 and i["fob_unit_egp"] > 0
        assert i["allocated_customs_egp"] == round(i["allocated_customs_duty_egp"] + i["allocated_vat_egp"], 2)
    # A re-run of the engine on the stored rows keeps the approved totals (no drop to FOB-only).
    calc = fs.calculate_landed_cost_engine([dict(e) for e in rec.expense_invoices],
                                           [dict(i) for i in rec.item_landed_costs])
    assert calc["total_expenses_egp"] == rec.total_expenses_egp
    assert calc["total_landed_cost_egp"] == rec.total_landed_cost_egp
    # Odoo journal of an approved settlement balances.
    assert generate_odoo_journal_entry_service(db, rec.settlement_id).is_balanced


# ── FS-03 ────────────────────────────────────────────────────────────────────

def test_approved_settlement_is_frozen(db):
    _, _, rec = _approved(db)
    with pytest.raises(HTTPException) as e1:
        fs.recalculate_settlement_service(db, rec.settlement_id, actor="bob")
    assert e1.value.status_code == 409 and _code(e1) == "SETTLEMENT_NOT_EDITABLE"
    with pytest.raises(HTTPException) as e2:
        fs.update_settlement_service(db, rec.settlement_id, FinancialSettlementUpdate(notes="x"), actor="bob")
    assert e2.value.status_code == 409


def test_put_cannot_set_approved_status():
    with pytest.raises(ValidationError):
        FinancialSettlementUpdate(status="Approved")
    assert FinancialSettlementUpdate(status="Draft").status == "Draft"


# ── FS-02 ────────────────────────────────────────────────────────────────────

def test_missing_fx_rate_is_a_coded_409_not_48_5(db):
    imp = ImportFile(import_file_code="IMP-P09-FX", company_name="c", supplier_name="s", is_active=True)
    db.add(imp)
    db.flush()
    db.add(ShipmentBooking(booking_code="FRT-P09", import_file_id=imp.import_file_id, total_freight_cost_usd=1000.0,
                           status="Confirmed", is_active=True, booking_confirmation_date=datetime(2026, 3, 1)))
    db.commit()
    with pytest.raises(HTTPException) as exc:
        fs.aggregate_shipment_invoices_service(db, imp.import_file_id)
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "SETTLEMENT_FX_RATE_MISSING"
    assert exc.value.detail["currency"] == "USD" and exc.value.detail["on_date"] == "2026-03-01"


def test_freight_uses_the_rate_table(db):
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db.add(usd)
    db.flush()
    db.add(ExchangeRate(currency_id=usd.currency_id, customs_rate=Decimal("51"), commercial_rate=Decimal("47.25"),
                        effective_date=date(2020, 1, 1), is_active=True))
    imp = ImportFile(import_file_code="IMP-P09-FX2", company_name="c", supplier_name="s", is_active=True)
    db.add(imp)
    db.flush()
    db.add(ShipmentBooking(booking_code="FRT-P09B", import_file_id=imp.import_file_id, total_freight_cost_usd=1000.0,
                           status="Confirmed", is_active=True))
    db.commit()
    agg = fs.aggregate_shipment_invoices_service(db, imp.import_file_id)
    frt = next(i for i in agg.invoices if i.party_type == "CARRIER")
    assert (frt.exchange_rate, frt.amount_egp) == (47.25, 47250.0)


# ── FS-05 / FS-08 ────────────────────────────────────────────────────────────

def test_create_from_po_fills_items_at_the_po_rate(db):
    imp = seed_shipment(db, cbm=(12.0, 4.0))
    rec = fs.create_settlement_service(db, FinancialSettlementCreate(import_file_id=imp.import_file_id), actor="alice")
    assert len(rec.item_landed_costs) == 2
    first = rec.item_landed_costs[0]
    assert first["fob_unit_egp"] == 1500.0 * 48.5 and first["cbm"] == 12.0 and first["hs_code"] == "8479.89.90"
    assert rec.total_fob_egp == 20000.0 * 48.5
    assert rec.created_by == "alice" and rec.accountant_name == "alice"


def test_actual_reports_reconciliation_difference(db):
    imp = seed_shipment(db, cbm=(12.0, 4.0))
    seed_actual_sources(db, imp)
    res = fs.calculate_actual_landed_cost_service(db, imp.import_file_id)
    assert res.reconciliation_difference_egp == round(
        res.actual_total_landed_cost_egp - sum(i.actual_total_landed_cost_egp for i in res.items_breakdown), 2
    )
    cats = {c.category: c for c in res.categories_breakdown}
    assert cats["Freight"].allocation_rule == "Volume-Based"  # FS-09: rule actually used


# ── FS-06 / FS-07 ────────────────────────────────────────────────────────────

def test_line_without_hs_is_skipped_not_defaulted(db):
    imp = seed_shipment(db)
    imp.hs_code = None
    from modules.purchase_orders.model import POLineItem
    li = db.query(POLineItem).filter(POLineItem.item_code == "ITM-CONV-02").one()
    li.tariff_id = None
    db.commit()
    res = fs.simulate_estimated_landed_cost_service(db, imp.import_file_id)
    assert {"code": "SETTLEMENT_LINE_NO_HS", "params": {"item_code": "ITM-CONV-02", "line_no": 2},
            "severity": "warning"} in [m.model_dump() for m in res.messages]
    conv = next(i for i in res.items_breakdown if i.item_code == "ITM-CONV-02")
    assert conv.hs_code == "" and conv.allocated_customs_duty_egp == 0.0 and conv.allocated_vat_egp == 0.0
    assert res.total_customs_duty_egp + res.total_vat_and_fees_egp == pytest.approx(res.total_customs_and_taxes_egp)


def test_estimate_constants_come_from_system_parameters(db):
    from modules.common.system_parameters import SystemParameter
    imp = seed_shipment(db)
    db.add(SystemParameter(param_key="settlement.default_clearance_egp", param_value="6000", is_active=True))
    db.commit()
    res = fs.simulate_estimated_landed_cost_service(db, imp.import_file_id)
    assert res.total_clearance_and_port_egp == 6000.0 + 5000.0


# ── FS-11 ────────────────────────────────────────────────────────────────────

def test_restore_refuses_a_second_active_settlement(db):
    imp = seed_shipment(db)
    first = fs.create_settlement_service(db, FinancialSettlementCreate(import_file_id=imp.import_file_id))
    fs.soft_delete_settlement_service(db, first.settlement_id)
    fs.create_settlement_service(db, FinancialSettlementCreate(import_file_id=imp.import_file_id))
    with pytest.raises(HTTPException) as exc:
        fs.restore_settlement_service(db, first.settlement_id)
    assert exc.value.status_code == 409


def test_soft_deleted_import_file_is_404(db):
    imp = seed_shipment(db)
    imp.is_active = False
    db.commit()
    with pytest.raises(HTTPException) as exc:
        fs.simulate_estimated_landed_cost_service(db, imp.import_file_id)
    assert exc.value.status_code == 404


# ── FS-12 ────────────────────────────────────────────────────────────────────

def test_confirm_runs_once_and_closes_only_the_0901_task(db):
    imp = seed_shipment(db)
    db.add_all([
        SmartTask(task_code=f"TSK-0901-{imp.import_file_id}", title="Settle invoices", status="Pending",
                  import_file_id=imp.import_file_id),
        SmartTask(task_code="TSK-OTHER", title="Review invoices (فواتير)", status="Pending",
                  import_file_id=imp.import_file_id),
    ])
    db.commit()
    req = ConfirmInvoicesSettlementRequest(import_file_id=imp.import_file_id, settled_by="spoofed")
    res = fs.confirm_invoices_settlement_service(db, req, actor="alice")
    assert res.total_settled_egp == 970000.0  # server aggregation, overrides ignored
    tasks = {t.task_code: t.status for t in db.query(SmartTask).all()}
    assert tasks[f"TSK-0901-{imp.import_file_id}"] == "Completed"
    assert tasks["TSK-OTHER"] == "Pending"
    with pytest.raises(HTTPException) as exc:
        fs.confirm_invoices_settlement_service(db, req, actor="alice")
    assert exc.value.status_code == 409 and _code(exc) == "INVOICES_ALREADY_SETTLED"


# ── FS-14 ────────────────────────────────────────────────────────────────────

def test_seller_paid_rows_are_not_credited(db):
    rows = ODOO_EXPENSES + [{"invoice_no": "SP-1", "category": "Freight", "provider_name": "Seller", "currency": "EGP",
                             "amount_fx": 9999.0, "exchange_rate": 1.0, "amount_egp": 9999.0, "is_seller_paid": True}]
    rec = seed_odoo_settlement(db, rows)
    entry = generate_odoo_journal_entry_service(db, rec.settlement_id)
    assert entry.is_balanced and "SP-1" not in " ".join(l.label for l in entry.lines)


def test_unbalanced_journal_is_not_exported_and_fx_rows_name_their_currency(db):
    rows = [dict(ODOO_EXPENSES[0], currency="USD", amount_fx=1000.0, exchange_rate=50.0)]
    rec = seed_odoo_settlement(db, rows, status="Approved")
    entry = generate_odoo_journal_entry_service(db, rec.settlement_id)
    # Odoo sign convention: a credit line carries a negative amount_currency (review 2 #8).
    assert entry.lines[2].currency == "USD" and entry.lines[2].amount_currency == -1000.0
    rec.total_landed_cost_egp += 5.0
    db.commit()
    with pytest.raises(HTTPException) as exc:
        export_odoo_csv_service(db, rec.settlement_id)
    assert exc.value.status_code == 409 and _code(exc) == "JOURNAL_UNBALANCED"


# ── FS-04 (HTTP): permissions ────────────────────────────────────────────────

def test_approve_without_calculate_permission_is_403(db):
    import main
    from modules.auth.security import create_access_token, hash_password
    from modules.users.model import User
    from modules.auth.permissions import invalidate_permission_cache

    user = User(
        username="operator_perm_test",
        email="operator_perm@test.com",
        full_name="Operator Perm Test",
        hashed_password=hash_password("Password123"),
        role="OPERATOR",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    headers = {"Authorization": f"Bearer {token}"}

    invalidate_permission_cache()
    main.app.dependency_overrides[get_db] = lambda: db
    try:
        with patch.object(permissions, "has_user_permission",
                          lambda _db, _u, code: code == "financial_settlement.view"):
            client = TestClient(main.app)
            r = client.post("/api/v1/financial-settlement/approve-actual-landed-cost", json={"import_file_id": 1}, headers=headers)
            assert r.status_code == 403
            r = client.put("/api/v1/financial-settlement/1", json={"status": "Approved"}, headers=headers)
            assert r.status_code == 403
    finally:
        main.app.dependency_overrides.pop(get_db, None)
        invalidate_permission_cache()


# ── RC-01 / RC-02 / RC-03 / RC-05 ────────────────────────────────────────────

def _settlement(db, status="Draft"):
    exp = [
        {"invoice_no": "F1", "category": "Freight", "provider_name": "A", "currency": "EGP", "amount_fx": 12000.0,
         "exchange_rate": 1.0, "amount_egp": 12000.0, "allocation_rule": "Volume-Based"},
        {"invoice_no": "F2", "category": "Ocean Freight", "provider_name": "B", "currency": "EGP", "amount_fx": 8000.0,
         "exchange_rate": 1.0, "amount_egp": 8000.0, "allocation_rule": "Volume-Based"},
        {"invoice_no": "C1", "category": "Customs Clearance", "provider_name": "Br", "currency": "EGP",
         "amount_fx": 5000.0, "exchange_rate": 1.0, "amount_egp": 5000.0, "allocation_rule": "Equal"},
    ]
    items = [{"item_code": "I", "item_name": "I", "qty": 10, "fob_unit_egp": 10000.0, "cbm": 1.0, "gross_weight_kg": 1.0}]
    rec = LandedCostSettlementRecord(settlement_code="LCS-RC-1", import_file_id=1, incoterm_code="FOB",
                                     expense_invoices=exp, item_landed_costs=items, total_fob_egp=100000.0,
                                     total_expenses_egp=25000.0, total_landed_cost_egp=125000.0,
                                     average_markup_factor=1.25, status=status, accountant_name="x", is_active=True)
    db.add(rec)
    db.commit()
    return rec


def _seed_deps(db):
    from modules.recalculation.seed_dependencies import run_seed
    run_seed(db)


FETCHERS = {
    "customs_consultation": lambda db, k, field, agg: 0.0 if field == "estimated_duties_egp" else 5000.0,
    "shipping_scenarios": lambda *a: 26000.0,
    "purchase_orders": lambda *a: 100000.0,
}


def test_settlement_read_matches_engine_categories(db):
    rec = _settlement(db)
    # Both freight rows count once; "Customs Clearance" is clearance, not duties.
    assert rc._get_entity_field_value(rec, "freight_cost_egp", "financial_settlement") == 20000.0
    assert rc._get_entity_field_value(rec, "customs_duties_egp", "financial_settlement") == 0.0
    assert rc._get_entity_field_value(rec, "clearance_fees_egp", "financial_settlement") == 5000.0


def test_estimate_changes_never_touch_settlement_invoices(db):
    # BE09-T03: settlement recalculation follows the PO FOB only. A different scenario freight (26,000 vs
    # actual 20,000) or consultation estimate is not a variance, so apply is a no_op twice and the user's
    # actual invoices stay as entered (no RECALC-ADJ rows).
    _seed_deps(db)
    rec = _settlement(db)
    user = User(username="mgr", full_name="m", email="m@x", role="ADMIN", is_active=True, hashed_password="h")
    db.add(user)
    db.commit()
    req = RecalculationApplyRequest(target_entity_type="financial_settlement", target_entity_id=rec.settlement_id,
                                    source_page="t", justification="carrier surcharge")
    with patch.object(rc, "_SOURCE_FETCHERS", FETCHERS), patch.object(rc, "has_user_permission", return_value=True):
        first = rc.apply(db, req, user)
        second = rc.apply(db, req, user)
        after = rc.preview(db, "financial_settlement", rec.settlement_id, "t", "mgr")
    assert first.action_taken == "no_op" and second.action_taken == "no_op"
    assert (rec.total_expenses_egp, rec.total_landed_cost_egp) == (25000.0, 125000.0)
    assert after.has_any_variance is False and after.message_code == "RECALC_NO_VARIANCE"
    assert [i.field_name for i in after.items] == ["total_fob_egp"]
    by_no = {e["invoice_no"]: e["amount_egp"] for e in rec.expense_invoices}
    assert by_no == {"F1": 12000.0, "F2": 8000.0, "C1": 5000.0}


def test_apply_on_approved_settlement_is_logged(db):
    _seed_deps(db)
    rec = _settlement(db, status="Approved")
    user = User(username="gm", full_name="g", email="g@x", role="ADMIN", is_active=True, hashed_password="h")
    db.add(user)
    db.commit()
    req = RecalculationApplyRequest(target_entity_type="financial_settlement", target_entity_id=rec.settlement_id,
                                    source_page="t", justification="ok")
    # FOB variance 100,000 -> 106,000 (the only settlement dependency since BE09-T03)
    with patch.object(rc, "_SOURCE_FETCHERS", dict(FETCHERS, purchase_orders=lambda *a: 106000.0)), \
            patch.object(rc, "has_user_permission", return_value=True):
        res = rc.apply(db, req, user)
    assert res.action_taken == "recalculated"
    assert db.query(RecalculationLog).get(res.log_id).action_taken == "recalculated_approved"


def test_scenario_quotation_is_converted_and_missing_rate_is_flagged(db):
    from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
    session = ShippingEvaluationSession(import_file_id=77, is_active=True, created_at=datetime(2026, 3, 1))
    for col in ShippingEvaluationSession.__table__.columns:
        if not col.nullable and col.default is None and col.server_default is None and not col.primary_key \
                and getattr(session, col.name) is None:
            setattr(session, col.name, date(2026, 3, 1) if "date" in col.name else "x")
    db.add(session)
    db.flush()
    item = ShippingScenarioItem(session_id=session.session_id, is_recommended=True, quotation_currency="USD",
                                total_quotation_amount=1000.0)
    for col in ShippingScenarioItem.__table__.columns:
        if not col.nullable and col.default is None and col.server_default is None and not col.primary_key \
                and getattr(item, col.name) is None:
            setattr(item, col.name, date(2026, 3, 1) if "date" in col.name else "x")
    db.add(item)
    db.commit()
    with pytest.raises(rc.SourceRateMissing):
        rc._fetch_from_shipping_scenarios(db, 77, "total_quotation_amount", "max")
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db.add(usd)
    db.flush()
    db.add(ExchangeRate(currency_id=usd.currency_id, customs_rate=Decimal("50"), commercial_rate=Decimal("48"),
                        effective_date=date(2020, 1, 1), is_active=True))
    db.commit()
    from modules.currencies import service as currency_service
    currency_service.clear_currency_cache()
    assert rc._fetch_from_shipping_scenarios(db, 77, "total_quotation_amount", "max") == 48000.0


def test_logs_require_the_target_view_permission(db):
    user = User(username="op", full_name="o", email="o@x", role="LOGISTICS_OPERATOR", is_active=True,
                hashed_password="h")
    db.add(user)
    db.commit()
    with patch.object(rc, "has_user_permission", return_value=False):
        with pytest.raises(HTTPException) as exc:
            rc.list_logs(db, user, "financial_settlement", 1)
    assert exc.value.status_code == 403
    with patch.object(rc, "has_user_permission", return_value=True):
        assert rc.list_logs(db, user, "financial_settlement", 1) == []


# ── Review follow-ups (customs-rules-reviewer #2/#3, diff review) ─────────────

def _clearance(db, imp, **kw):
    from modules.customs_clearance.model import CustomsClearanceRecord
    fields = dict(clearance_code="CLR-RV", import_file_id=imp.import_file_id, declaration_46_no="D46-RV",
                  status="Final Release Granted", is_active=True)
    fields.update(kw)
    rec = CustomsClearanceRecord(**fields)
    db.add(rec)
    db.commit()
    return rec


COMPONENTS = dict(import_duty_amount=10000.0, vat_amount=15000.0, schedule_tax_amount=0.0,
                  development_fee_amount=500.0, customs_service_fees=250.0, wht_amount=0.0, lab_service_fees=1500.0)


def test_auto_fetched_duty_keeps_components_and_counts_lab_fees_once(db):
    """Intended change (review #3): the lab fees were added twice (in actual_duty_total and as a separate row)."""
    imp = seed_shipment(db)
    _clearance(db, imp, actual_duty_total=27250.0, total_duty_payable=27250.0, **COMPONENTS)
    rec = fs.create_settlement_service(db, FinancialSettlementCreate(import_file_id=imp.import_file_id))
    rows = {e["duty_component"]: (e["category"], e["amount_egp"]) for e in rec.expense_invoices}
    assert rows == {
        "import_duty_amount": ("Customs Duty", 10000.0), "vat_amount": ("VAT", 15000.0),
        "development_fee_amount": ("Customs", 500.0), "customs_service_fees": ("Customs", 250.0),
        "lab_service_fees": ("Clearance", 1500.0),
    }
    assert rec.total_expenses_egp == 27250.0  # was 28750.0


def test_overridden_assessed_total_is_one_row(db):
    imp = seed_shipment(db)
    _clearance(db, imp, actual_duty_total=30000.0, total_duty_payable=30000.0, **COMPONENTS)
    rec = fs.create_settlement_service(db, FinancialSettlementCreate(import_file_id=imp.import_file_id))
    assert [(e["category"], e["amount_egp"]) for e in rec.expense_invoices] == [("Customs Duty", 30000.0)]


def test_customs_row_uses_the_assessed_total_for_amount_and_balance(db):
    imp = seed_shipment(db)
    _clearance(db, imp, actual_duty_total=170000.0, total_duty_payable=160000.0, duty_paid_amount=170000.0)
    agg = fs.aggregate_shipment_invoices_service(db, imp.import_file_id)
    row = next(i for i in agg.invoices if i.party_type == "CUSTOMS")
    assert (row.amount_egp, row.paid_amount_egp, row.remaining_amount_egp, row.payment_status) == (
        170000.0, 170000.0, 0.0, "PAID")


def test_flutter_egp_payload_without_exchange_rate_is_accepted(db):
    import main
    from modules.auth.security import create_access_token, hash_password
    from modules.users.model import User
    from modules.auth.permissions import invalidate_permission_cache

    imp = seed_shipment(db)
    user = User(
        username="admin_flutter_egp",
        email="admin_flutter_egp@test.com",
        full_name="Admin EGP",
        hashed_password=hash_password("Admin@123"),
        role="ADMIN",
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    headers = {"Authorization": f"Bearer {token}"}

    invalidate_permission_cache()
    main.app.dependency_overrides[get_db] = lambda: db
    try:
        client = TestClient(main.app)
        r = client.post("/api/v1/financial-settlement", json={
            "import_file_id": imp.import_file_id,
            "expense_invoices": [{"invoice_no": "INV-1", "category": "Freight", "provider_name": "Maersk",
                                  "currency": "EGP", "amount_fx": 5000, "allocation_rule": "Value-Based"}],
        }, headers=headers)
    finally:
        main.app.dependency_overrides.pop(get_db, None)
        invalidate_permission_cache()
    assert r.status_code == 201, r.text
    row = r.json()["expense_invoices"][0]
    assert (row["exchange_rate"], row["amount_egp"]) == (1.0, 5000.0)


def test_foreign_invoice_without_rate_needs_the_rate_table(db):
    imp = ImportFile(import_file_code="IMP-P09-EUR", company_name="c", supplier_name="s", is_active=True)
    db.add(imp)
    db.commit()
    payload = FinancialSettlementCreate(import_file_id=imp.import_file_id, expense_invoices=[
        {"invoice_no": "E-1", "category": "Freight", "provider_name": "x", "currency": "EUR", "amount_fx": 100}])
    with pytest.raises(HTTPException) as exc:
        fs.create_settlement_service(db, payload)
    assert exc.value.status_code == 409 and _code(exc) == "SETTLEMENT_FX_RATE_MISSING"


def test_confirm_leaves_the_step_19_grn_task_open(db):
    imp = seed_shipment(db)
    db.add(SmartTask(task_code=f"TSK-GRN-{imp.import_file_id}", title="GRN", step_code="STEP_19", status="Pending",
                     import_file_id=imp.import_file_id))
    db.commit()
    fs.confirm_invoices_settlement_service(db, ConfirmInvoicesSettlementRequest(import_file_id=imp.import_file_id))
    assert db.query(SmartTask).filter(SmartTask.task_code == f"TSK-GRN-{imp.import_file_id}").one().status == "Pending"


def test_downward_recalculation_still_exports_a_balanced_journal(db):
    rows = ODOO_EXPENSES + [{"invoice_no": "RECALC-ADJ-freight_cost_egp", "category": "Freight",
                             "provider_name": "Upstream Sync", "currency": "EGP", "amount_fx": -7000.0,
                             "exchange_rate": 1.0, "amount_egp": -7000.0, "allocation_rule": "Volume-Based"}]
    rec = seed_odoo_settlement(db, rows, status="Approved")
    entry = generate_odoo_journal_entry_service(db, rec.settlement_id)
    adj = next(l for l in entry.lines if "RECALC-ADJ" in l.label)
    assert (adj.debit, adj.credit) == (7000.0, 0.0)
    assert entry.is_balanced
    assert export_odoo_csv_service(db, rec.settlement_id).count("\n") == len(entry.lines) + 1


def test_approved_settlement_cannot_be_deleted(db):
    _, _, rec = _approved(db)
    with pytest.raises(HTTPException) as exc:
        fs.soft_delete_settlement_service(db, rec.settlement_id)
    assert exc.value.status_code == 409 and _code(exc) == "SETTLEMENT_NOT_EDITABLE"


def test_preview_with_a_missing_rate_is_not_no_variance(db):
    _seed_deps(db)
    rec = _settlement(db)

    def _missing(*a):
        raise rc.SourceRateMissing("USD", "2026-03-01")

    fetchers = dict(FETCHERS, purchase_orders=_missing)
    with patch.object(rc, "_SOURCE_FETCHERS", fetchers):
        res = rc.preview(db, "financial_settlement", rec.settlement_id, "t", "mgr")
    assert res.message_code == "RECALC_RATE_MISSING" and res.params == {"fields": "total_fob_egp"}
    assert next(i for i in res.items if i.field_name == "total_fob_egp").status == "RATE_MISSING"


# ── Customs review 2 ──────────────────────────────────────────────────────────

def _fill_required(obj):
    """Give every NOT NULL column without a default a dummy value (test scaffolding only)."""
    for col in type(obj).__table__.columns:
        if col.nullable or col.primary_key or col.default is not None or col.server_default is not None:
            continue
        if getattr(obj, col.name) is None:
            py = col.type.python_type
            setattr(obj, col.name, date(2026, 3, 1) if py is date else (datetime(2026, 3, 1) if py is datetime
                    else (0 if py in (int, float) else f"x-{col.name}")))
    return obj


def test_rfq_quote_in_another_currency_uses_its_own_customs_rate(db):
    from modules.freight_quotations.model import FreightQuotationItem, FreightRFQRequest
    imp = seed_shipment(db)  # goods in USD at customs 50
    eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="E", is_active=True)
    db.add(eur)
    db.flush()
    db.add(ExchangeRate(currency_id=eur.currency_id, customs_rate=Decimal("55"), commercial_rate=Decimal("54"),
                        effective_date=date(2020, 1, 1), is_active=True))
    rfq = _fill_required(FreightRFQRequest(import_file_id=imp.import_file_id))
    db.add(rfq)
    db.flush()
    q = _fill_required(FreightQuotationItem(rfq_id=rfq.rfq_id, currency_code="EUR", ocean_freight_cost=2000.0, total_cost=2000.0))
    db.add(q)
    db.flush()
    rfq.selected_quotation_id = q.quotation_id
    db.commit()
    res = fs.simulate_estimated_landed_cost_service(db, imp.import_file_id)
    assert res.total_freight_egp == 110000.0  # 2000 EUR x 55 (was 2000 x the USD rate 50)


def test_approve_twice_is_refused(db):
    imp, _, _ = _approved(db)
    with pytest.raises(HTTPException) as exc:
        fs.approve_actual_landed_cost_service(db, ApproveActualLandedCostRequest(import_file_id=imp.import_file_id))
    assert exc.value.status_code == 409 and _code(exc) == "SETTLEMENT_NOT_EDITABLE"


def test_file_already_cost_allocated_cannot_be_approved_again(db):
    imp = seed_shipment(db, cbm=(12.0, 4.0))
    imp.financial_settlement_status = "CLOSED"
    db.commit()
    with pytest.raises(HTTPException) as exc:
        fs.approve_actual_landed_cost_service(db, ApproveActualLandedCostRequest(import_file_id=imp.import_file_id))
    assert exc.value.status_code == 409


def _small_variance_fetchers():
    # PO FOB 100000 -> 101000 (1%, below the 5% hard block); FOB is the only settlement dependency (BE09-T03)
    return dict(FETCHERS, purchase_orders=lambda *a: 101000.0)


def test_approved_settlement_needs_a_justification_even_below_the_threshold(db):
    _seed_deps(db)
    imp = ImportFile(import_file_code="IMP-P09-RC3", company_name="c", supplier_name="s", is_active=True,
                     actual_landed_cost_total_egp=125000.0)
    db.add(imp)
    db.flush()
    rec = _settlement(db, status="Approved")
    rec.import_file_id = imp.import_file_id
    user = User(username="gm3", full_name="g", email="g3@x", role="ADMIN", is_active=True, hashed_password="h")
    db.add(user)
    db.commit()
    no_just = RecalculationApplyRequest(target_entity_type="financial_settlement",
                                        target_entity_id=rec.settlement_id, source_page="t")
    with patch.object(rc, "_SOURCE_FETCHERS", _small_variance_fetchers()), \
            patch.object(rc, "has_user_permission", return_value=True):
        with pytest.raises(HTTPException) as exc:
            rc.apply(db, no_just, user)
        assert exc.value.status_code == 400
        res = rc.apply(db, no_just.model_copy(update={"justification": "bunker surcharge"}), user)
    assert res.action_taken == "recalculated"
    db.refresh(imp)
    assert imp.actual_landed_cost_total_egp == rec.total_landed_cost_egp


def test_closed_settlement_is_never_recalculated(db):
    _seed_deps(db)
    rec = _settlement(db, status="Closed")
    user = User(username="gm4", full_name="g", email="g4@x", role="ADMIN", is_active=True, hashed_password="h")
    db.add(user)
    db.commit()
    req = RecalculationApplyRequest(target_entity_type="financial_settlement", target_entity_id=rec.settlement_id,
                                    source_page="t", justification="x")
    with patch.object(rc, "_SOURCE_FETCHERS", _small_variance_fetchers()), \
            patch.object(rc, "has_user_permission", return_value=True):
        with pytest.raises(HTTPException) as exc:
            rc.apply(db, req, user)
        preview = rc.preview(db, "financial_settlement", rec.settlement_id, "t", "gm4")
    assert exc.value.status_code == 409
    assert preview.can_apply is False


def test_fob_apply_is_idempotent(db):
    _seed_deps(db)
    rec = _settlement(db)
    rec.item_landed_costs = [{"item_code": "I", "item_name": "I", "qty": 3, "fob_unit_egp": 100000.0 / 3,
                              "fob_total_egp": 100000.0, "cbm": 1.0, "gross_weight_kg": 1.0}]
    user = User(username="mgr4", full_name="m", email="m4@x", role="ADMIN", is_active=True, hashed_password="h")
    db.add(user)
    db.commit()
    fetchers = dict(FETCHERS, shipping_scenarios=lambda *a: 20000.0, purchase_orders=lambda *a: 100000.03)
    req = RecalculationApplyRequest(target_entity_type="financial_settlement", target_entity_id=rec.settlement_id,
                                    source_page="t", justification="po change")
    with patch.object(rc, "_SOURCE_FETCHERS", fetchers), patch.object(rc, "has_user_permission", return_value=True):
        first = rc.apply(db, req, user)
        second = rc.apply(db, req, user)
    assert first.action_taken == "recalculated"
    assert rec.total_fob_egp == 100000.03
    assert second.action_taken == "no_op"


def test_fractional_quantity_unit_cost_uses_the_real_quantity(db):
    from modules.purchase_orders.model import POLineItem
    imp = seed_shipment(db, cbm=(12.0, 4.0))
    seed_actual_sources(db, imp)
    li = db.query(POLineItem).filter(POLineItem.item_code == "ITM-CONV-02").one()
    li.quantity, li.unit_price, li.total_price = 0.5, 10000.0, 5000.0
    db.commit()
    res = fs.calculate_actual_landed_cost_service(db, imp.import_file_id)
    conv = next(i for i in res.items_breakdown if i.item_code == "ITM-CONV-02")
    assert conv.qty == 0.5  # stored as is (was max(qty, 1) = 1)
    assert conv.actual_unit_landed_cost_egp == round(conv.actual_total_landed_cost_egp / 0.5, 2)
    assert conv.fob_unit_egp == round(5000.0 * 48.5 / 0.5, 2)


def test_stored_rows_are_cents_and_header_is_their_sum(db):
    imp = seed_shipment(db)
    payload = FinancialSettlementCreate(import_file_id=imp.import_file_id, expense_invoices=[
        {"invoice_no": "R-1", "category": "Freight", "provider_name": "x", "currency": "USD", "amount_fx": 333.333,
         "exchange_rate": 48.4321},
        {"invoice_no": "R-2", "category": "Customs Duty", "provider_name": "y", "currency": "EGP",
         "amount_fx": 1000.004, "amount_egp": 1000.004},
    ])
    rec = fs.create_settlement_service(db, payload)
    amounts = [e["amount_egp"] for e in rec.expense_invoices]
    assert amounts == [round(333.333 * 48.4321, 2), 1000.0]
    assert rec.total_expenses_egp == round(sum(amounts), 2)
    assert generate_odoo_journal_entry_service(db, rec.settlement_id).is_balanced


# ── Customs review 3 ──────────────────────────────────────────────────────────

def _capture_customs_request(db, imp, **overrides):
    import modules.customs_tariff.service as tariff_service
    from modules.financial_settlement.schemas import EstimatedLandedCostSimulationRequest
    seen = {}
    real = tariff_service.estimate_multi_item_customs_duty_service

    def _spy(db_, req):
        seen["req"] = req
        return real(db_, req)

    with patch.object(tariff_service, "estimate_multi_item_customs_duty_service", _spy):
        res = fs.simulate_estimated_landed_cost_service(
            db, imp.import_file_id, EstimatedLandedCostSimulationRequest(**overrides) if overrides else None)
    return res, seen.get("req")


def test_freight_and_insurance_sent_to_customs_follow_the_declared_lines(db):
    from modules.purchase_orders.model import POLineItem
    imp = seed_shipment(db)  # line 1: 15,000 USD (HS), line 2: 5,000 USD
    imp.hs_code = None
    db.query(POLineItem).filter(POLineItem.item_code == "ITM-CONV-02").one().tariff_id = None
    db.commit()
    res, req = _capture_customs_request(db, imp, freight_amount_egp_override=30000.0,
                                        insurance_amount_egp_override=4000.0)
    assert [l.line_no for l in req.lines] == [1]
    assert req.freight_egp == Decimal("22500.00")  # 30,000 x 15,000 / 20,000
    assert req.insurance_egp == Decimal("3000.00")
    assert res.total_freight_egp == 30000.0  # the landed cost still carries the full freight


def test_zero_value_line_is_left_out_of_customs_with_a_message(db):
    from modules.purchase_orders.model import POLineItem
    imp = seed_shipment(db)
    li = db.query(POLineItem).filter(POLineItem.item_code == "ITM-CONV-02").one()
    li.unit_price, li.total_price = 0.0, 0.0
    db.commit()
    res, req = _capture_customs_request(db, imp)
    assert [l.line_no for l in req.lines] == [1]
    assert "SETTLEMENT_LINE_ZERO_VALUE" in [m.code for m in res.messages]


def test_each_po_currency_uses_its_own_customs_rate(db):
    from modules.purchase_orders.model import POLineItem, PurchaseOrder
    imp = seed_shipment(db)  # USD PO, customs 50
    eur = Currency(currency_code="EUR", currency_name="Euro", currency_symbol="E", is_active=True)
    db.add(eur)
    db.flush()
    db.add(ExchangeRate(currency_id=eur.currency_id, customs_rate=Decimal("55"), commercial_rate=Decimal("54"),
                        effective_date=date(2020, 1, 1), is_active=True))
    usd_po = db.query(PurchaseOrder).filter(PurchaseOrder.import_file_id == imp.import_file_id).one()
    eur_po = PurchaseOrder(po_number="PO-P09-EUR", import_file_id=imp.import_file_id, project_id=usd_po.project_id,
                           company_id=1, supplier_id=usd_po.supplier_id, incoterm_id=usd_po.incoterm_id,
                           currency_id=eur.currency_id, total_amount_fob=1000.0, is_active=True)
    db.add(eur_po)
    db.flush()
    db.add(POLineItem(po_id=eur_po.po_id, item_code="ITM-EUR", description_ar="e", quantity=1, unit_price=1000.0,
                      total_price=1000.0, tariff_id=usd_po.line_items[0].tariff_id, gross_weight_kg=10.0))
    db.commit()
    res = fs.simulate_estimated_landed_cost_service(db, imp.import_file_id)
    by_code = {i.item_code: i for i in res.items_breakdown}
    assert by_code["ITM-EUR"].fob_total_egp == 55000.0  # 1,000 EUR x 55, not x the USD rate
    assert by_code["ITM-MAC-01"].fob_total_egp == 750000.0  # 15,000 USD x 50
    # The reference currency is the last PO's currency (EUR here): the USD lines are restated, EGP unchanged.
    assert res.total_fob_egp == 55000.0 + 1000000.0


def test_seller_paid_rows_never_count_in_recalc_fields(db):
    rec = _settlement(db)
    rows = list(rec.expense_invoices) + [{"invoice_no": "SP-F", "category": "Freight", "provider_name": "Seller",
                                          "currency": "EGP", "amount_fx": 9000.0, "exchange_rate": 1.0,
                                          "amount_egp": 9000.0, "is_seller_paid": True}]
    assert fs.settlement_field_total(rows, "freight_cost_egp") == 20000.0
    new_rows = fs.apply_settlement_field_total(rows, "freight_cost_egp", 26000.0)
    adj = next(e for e in new_rows if e["invoice_no"] == "RECALC-ADJ-freight_cost_egp")
    assert adj["amount_egp"] == 6000.0  # 26,000 - (12,000 + 8,000); the seller-paid 9,000 is not "others"
    assert fs.settlement_field_total(new_rows, "freight_cost_egp") == 26000.0


def test_aggregation_converts_a_foreign_delivery_order_and_keeps_demurrage(db):
    from modules.customs_clearance.model import CustomsClearanceRecord
    from modules.demurrage_detention.model import DemurrageTracking
    imp = seed_shipment(db)  # USD commercial 48.5
    db.add(CustomsClearanceRecord(clearance_code="CLR-DO", import_file_id=imp.import_file_id, is_active=True,
                                  delivery_order_fees=100.0, delivery_order_currency="USD",
                                  delivery_order_date=datetime(2026, 3, 2), delivery_order_status="Paid"))
    dnd = _fill_required(DemurrageTracking(port_name="Alexandria", import_file_id=imp.import_file_id, tracking_code="DND-P09",
                                           currency="USD", exchange_rate=49.0, total_demurrage_fx=200.0,
                                           total_detention_fx=0.0, total_storage_egp=150.0, total_cost_egp=0.0,
                                           is_active=True))
    db.add(dnd)
    db.commit()
    agg = fs.aggregate_shipment_invoices_service(db, imp.import_file_id)
    do_row = next(i for i in agg.invoices if i.invoice_id.startswith("DO-"))
    assert (do_row.currency, do_row.exchange_rate, do_row.amount_fc, do_row.amount_egp, do_row.payment_status) == (
        "USD", 48.5, 100.0, 4850.0, "PAID")
    d_row = next(i for i in agg.invoices if i.invoice_id.startswith("DND-"))
    assert (d_row.exchange_rate, d_row.amount_egp) == (49.0, 200.0 * 49.0 + 150.0)


def test_actual_items_use_the_po_rate_and_report_the_header_difference(db):
    imp = seed_shipment(db, po_rate=50.25, cbm=(12.0, 4.0))  # goods invoice at 48.5, PO at 50.25
    seed_actual_sources(db, imp)
    res = fs.calculate_actual_landed_cost_service(db, imp.import_file_id)
    assert res.actual_total_fob_egp == 970000.0
    # ACC2-T06: Single FOB basis aligns items to goods invoice basis
    assert [i.fob_total_egp for i in res.items_breakdown] == [15000.0 * 48.5, 5000.0 * 48.5]
    assert res.reconciliation_difference_egp == 0.0
    assert res.fob_basis == "INVOICE"


# ── BE09-T08 ─────────────────────────────────────────────────────────────────

def test_settlement_audit_rows_for_all_transitions(db):
    """BE09-T08: Audit rows for recalculate, delete, restore, confirm, and approve."""
    imp = seed_shipment(db, cbm=(12.0, 4.0))
    rec = LandedCostSettlementRecord(
        settlement_code=f"LCS-AUDIT-{imp.import_file_id}",
        import_file_id=imp.import_file_id,
        incoterm_code="FOB",
        expense_invoices=[
            {
                "invoice_no": "F1",
                "category": "Freight",
                "provider_name": "A",
                "currency": "EGP",
                "amount_fx": 12000.0,
                "exchange_rate": 1.0,
                "amount_egp": 12000.0,
                "allocation_rule": "Volume-Based",
                "note": "Auto-fetched freight quotation",
            },
        ],
        item_landed_costs=[
            {"item_code": "I", "item_name": "I", "qty": 10, "fob_unit_egp": 10000.0, "cbm": 1.0, "gross_weight_kg": 1.0}
        ],
        total_fob_egp=100000.0,
        total_expenses_egp=12000.0,
        total_landed_cost_egp=112000.0,
        average_markup_factor=1.12,
        status="Draft",
        accountant_name="tester",
        is_active=True,
    )
    db.add(rec)
    db.commit()

    # 1. Recalculate
    fs.recalculate_settlement_service(db, rec.settlement_id, actor="audit_user")

    # 2. Soft delete
    fs.soft_delete_settlement_service(db, rec.settlement_id, actor="audit_user")

    # 3. Restore
    fs.restore_settlement_service(db, rec.settlement_id, actor="audit_user")

    # 4. Confirm invoices
    seed_actual_sources(db, imp)
    fs.confirm_invoices_settlement_service(
        db, ConfirmInvoicesSettlementRequest(import_file_id=imp.import_file_id), actor="audit_user"
    )

    # 5. Approve
    fs.approve_actual_landed_cost_service(
        db, ApproveActualLandedCostRequest(import_file_id=imp.import_file_id), actor="audit_user"
    )

    # Check AuditLog entries
    logs = db.query(AuditLog).filter(AuditLog.performed_by == "audit_user").all()
    actions = {l.action: l for l in logs}
    assert {"RECALCULATE", "SOFT_DELETE", "RESTORE", "CONFIRM_INVOICES", "APPROVE"}.issubset(set(actions.keys()))

    for act in ("RECALCULATE", "SOFT_DELETE", "RESTORE", "CONFIRM_INVOICES", "APPROVE"):
        log = actions[act]
        assert log.old_values is not None and len(log.old_values) > 0
        assert log.new_values is not None and len(log.new_values) > 0
        if act == "CONFIRM_INVOICES":
            assert log.entity_type == "ImportFile"
            assert log.entity_id == imp.import_file_id
        else:
            assert log.entity_type == "LandedCostSettlementRecord"
            assert log.entity_id == rec.settlement_id


def test_approve_task_closure_behavior(db):
    """BE09-T08: Pre-completed tasks keep notes; non-completed TSK-0902 variants are resolved."""
    imp = seed_shipment(db, cbm=(12.0, 4.0))
    seed_actual_sources(db, imp)
    fs.confirm_invoices_settlement_service(
        db, ConfirmInvoicesSettlementRequest(import_file_id=imp.import_file_id), actor="user1"
    )

    # 1. Update the existing TSK-0902 task (created by confirm_invoices) to Completed
    completed_task = db.query(SmartTask).filter(
        SmartTask.task_code == f"TSK-0902-{imp.import_file_id}"
    ).first()
    completed_task.status = "Completed"
    completed_task.notes = "Pre-existing completed notes by user"
    completed_task.is_auto_closed = False

    # 2. A non-completed revision / subtask should be marked Completed
    open_subtask = SmartTask(
        task_code=f"TSK-0902-{imp.import_file_id}-REV1",
        title="Revision Task",
        description="Revision Desc",
        step_code="STEP_20",
        task_type="System Generated",
        import_file_id=imp.import_file_id,
        status="In Progress",
        notes="Initial notes",
        is_auto_closed=False,
    )
    db.add(open_subtask)
    db.commit()

    fs.approve_actual_landed_cost_service(
        db, ApproveActualLandedCostRequest(import_file_id=imp.import_file_id), actor="finance_lead"
    )

    db.refresh(completed_task)
    db.refresh(open_subtask)

    # Completed task untouched
    assert completed_task.status == "Completed"
    assert completed_task.notes == "Pre-existing completed notes by user"
    assert completed_task.is_auto_closed is False

    # Open task resolved
    assert open_subtask.status == "Completed"
    assert open_subtask.is_auto_closed is True
    assert "approved by finance_lead" in open_subtask.notes


def test_be09_t04_customs_clearance_snapshot_respects_lock_and_engine(db):
    """BE09-T04: Customs clearance snapshot respects settlement lock and landed-cost engine."""
    from modules.customs_clearance.model import CustomsClearanceRecord
    from modules.customs_clearance.schemas import ClearanceExpenseInvoiceCreate
    from modules.customs_clearance.service import (
        _sync_settlement_snapshot,
        record_clearance_invoice_service,
    )

    imp = seed_shipment(db, cbm=(10.0, 10.0))
    clr = CustomsClearanceRecord(
        import_file_id=imp.import_file_id,
        clearance_code=f"CLR-{imp.import_file_id}",
        status="Final Duty Assessed",
        is_active=True,
    )
    db.add(clr)
    db.commit()

    settlement = LandedCostSettlementRecord(
        settlement_code=f"LCS-BE04-{imp.import_file_id}",
        import_file_id=imp.import_file_id,
        incoterm_code="FOB",
        status="Calculated",
        is_active=True,
        total_fob_egp=500000.0,
        total_expenses_egp=150000.0,
        total_landed_cost_egp=650000.0,
        expense_invoices=[
            {"invoice_no": "FRT-1", "category": "Freight", "amount_egp": 50000.0, "currency": "EGP", "exchange_rate": 1.0, "amount_fx": 50000.0},
            {"invoice_no": "DUTY-1", "category": "Customs Duty", "amount_egp": 100000.0, "currency": "EGP", "exchange_rate": 1.0, "amount_fx": 100000.0},
        ],
        item_landed_costs=[
            {
                "item_code": "ITEM-1",
                "item_name": "Widget",
                "qty": 1000.0,
                "quantity": 1000.0,
                "cbm": 10.0,
                "weight_kg": 500.0,
                "fob_total_egp": 500000.0,
                "fob_unit_egp": 500.0,
                "allocated_freight_egp": 50000.0,
                "allocated_customs_egp": 100000.0,
                "allocated_clearance_egp": 0.0,
                "allocated_other_egp": 0.0,
                "total_expenses_egp": 150000.0,
                "total_landed_cost_egp": 650000.0,
                "unit_landed_cost_egp": 650.0,
            }
        ],
    )
    db.add(settlement)
    db.commit()

    # Record CL-05 invoice amount_egp 5,000
    inv = record_clearance_invoice_service(
        db,
        ClearanceExpenseInvoiceCreate(
            import_file_id=imp.import_file_id,
            customs_clearance_id=clr.customs_clearance_id,
            invoice_number="INV-CL-05-1",
            provider_name="Broker Co",
            expense_category="PORT_DUES_WHARFAGE",
            currency="EGP",
            amount_egp=5000.0,
        ),
        current_user="tester",
    )
    db.refresh(settlement)
    assert settlement.total_expenses_egp == 155000.0
    assert settlement.total_landed_cost_egp == 655000.0

    # Now approve settlement
    settlement.status = "Approved"
    db.commit()

    # Direct snapshot sync on approved settlement is a no-op
    expenses_before = list(settlement.expense_invoices)
    total_expenses_before = settlement.total_expenses_egp
    total_landed_before = settlement.total_landed_cost_egp

    _sync_settlement_snapshot(db, imp.import_file_id, actor="tester")
    db.refresh(settlement)
    assert settlement.expense_invoices == expenses_before
    assert settlement.total_expenses_egp == total_expenses_before
    assert settlement.total_landed_cost_egp == total_landed_before


def test_be09_t10_demurrage_push_and_create_share_initial_settlement_builder(db):
    """BE09-T10: Demurrage push uses build_initial_settlement with PO items and Final Release duty rows."""
    from modules.customs_clearance.model import CustomsClearanceRecord
    from modules.demurrage_detention.model import DemurrageTracking
    from modules.demurrage_detention.schemas import PushToSettlementRequest
    from modules.demurrage_detention.service import push_demurrage_to_financial_settlement_service
    from modules.incoterms.model import Incoterm
    from modules.projects.model import Project
    from modules.purchase_orders.model import PurchaseOrder, POLineItem
    from modules.suppliers.model import Supplier

    supplier = Supplier(
        supplier_code=f"SUP-BE10-{datetime.now().strftime('%f')}",
        company_name="BE10 Supplier",
        supplier_type="Manufacturer",
        registration_type="CargoX",
        foreign_exporter_id="EXP-BE10",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="DE",
        is_active=True,
    )
    inc = Incoterm(incoterm_code=f"FOB-{datetime.now().strftime('%f')[:4]}", incoterm_name="Free On Board", is_active=True)
    db.add_all([supplier, inc])
    db.flush()

    project = Project(
        project_code=f"PRJ-BE10-{datetime.now().strftime('%f')}",
        project_name="BE10 Project",
        project_owner="tester",
        company_id=1,
        supplier_id=supplier.supplier_id,
        incoterm_id=inc.incoterm_id,
        is_active=True,
    )
    db.add(project)
    db.flush()

    imp = ImportFile(
        import_file_code=f"IMP-BE10-{datetime.now().strftime('%f')}",
        company_id=1,
        company_name="Test Co",
        supplier_id=supplier.supplier_id,
        supplier_name="Test Supplier",
        incoterm_code="FOB",
        is_active=True,
    )
    db.add(imp)
    db.flush()

    usd = db.query(Currency).filter(Currency.currency_code == "USD").first()
    if not usd:
        usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        db.add(usd)
        db.flush()

    po = PurchaseOrder(
        po_number=f"PO-BE10-{imp.import_file_id}",
        import_file_id=imp.import_file_id,
        project_id=project.project_id,
        company_id=1,
        supplier_id=supplier.supplier_id,
        incoterm_id=inc.incoterm_id,
        currency_id=usd.currency_id,
        exchange_rate=50.0,
        total_amount_fob=1000.0,
        is_active=True,
    )
    db.add(po)
    db.flush()

    line = POLineItem(
        po_id=po.po_id,
        item_code="ITM-BE10-1",
        description_ar="بند 1",
        description_en="Item 1",
        quantity=10,
        unit_price=100.0,
        total_price=1000.0,
    )
    db.add(line)

    clr = CustomsClearanceRecord(
        clearance_code=f"CLR-BE10-{imp.import_file_id}",
        import_file_id=imp.import_file_id,
        declaration_46_no="D46-BE10",
        actual_duty_total=20000.0,
        status="Final Release Granted",
        is_active=True,
    )
    db.add(clr)

    # Demurrage tracking with 3,000 EGP total
    tracking = DemurrageTracking(
        tracking_code=f"DND-BE10-{imp.import_file_id}",
        import_file_id=imp.import_file_id,
        carrier_name="MSC",
        bill_of_lading_no="BL-BE10",
        port_name="Alexandria Port",
        discharge_date=date(2026, 8, 1),
        containers=[{"container_no": "MSCU1234567", "container_type": "40HC"}],
        currency="USD",
        exchange_rate=50.0,
        total_demurrage_fx=60.0,
        total_detention_fx=0.0,
        total_storage_egp=0.0,
        total_cost_egp=3000.0,
        is_active=True,
    )
    db.add(tracking)
    db.commit()

    class Actor:
        user_id = 1
        username = "lead"
        role = "ADMIN"
        is_active = True
        is_superuser = True

    with patch("modules.demurrage_detention.demurrage_tracking_service._recalculate_containers", return_value=(tracking.containers, 60.0, 0.0, 0.0)):
        push_res = push_demurrage_to_financial_settlement_service(
            db,
            PushToSettlementRequest(tracking_id=tracking.tracking_id),
            user="lead",
            actor=Actor(),
        )

    settlement = db.query(LandedCostSettlementRecord).filter(
        LandedCostSettlementRecord.import_file_id == imp.import_file_id,
        LandedCostSettlementRecord.is_active == True,
    ).first()

    assert settlement is not None
    assert settlement.total_fob_egp == 50000.0
    assert len(settlement.item_landed_costs) == 1
    assert settlement.item_landed_costs[0]["fob_total_egp"] == 50000.0

    duty_rows = [e for e in settlement.expense_invoices if "Customs" in e.get("category", "") or "Duty" in e.get("category", "")]
    dem_rows = [e for e in settlement.expense_invoices if "Demurrage" in e.get("category", "") or "Storage" in e.get("category", "") or "Detention" in e.get("category", "")]
    assert sum(e.get("amount_egp", 0.0) for e in duty_rows) == 20000.0
    assert sum(e.get("amount_egp", 0.0) for e in dem_rows) == 3000.0
    assert settlement.total_expenses_egp == 23000.0
    assert settlement.total_landed_cost_egp == 73000.0


# ── BE09-T14: Hygiene (soft-delete, incoterm, justification, dependencies) ──

def test_be09_t14_soft_delete_audit_fields(db):
    """BE09-T14: Soft delete sets deleted_at and deleted_by; restore clears them."""
    imp = seed_shipment(db)
    rec = fs.create_settlement_service(db, FinancialSettlementCreate(import_file_id=imp.import_file_id), actor="creator")

    # Soft delete
    fs.soft_delete_settlement_service(db, rec.settlement_id, actor="deleter_user")
    db.refresh(rec)
    assert rec.is_active is False
    assert rec.deleted_by == "deleter_user"
    assert rec.deleted_at is not None

    # Restore
    fs.restore_settlement_service(db, rec.settlement_id, actor="restorer_user")
    db.refresh(rec)
    assert rec.is_active is True
    assert rec.deleted_by is None
    assert rec.deleted_at is None


def test_be09_t14_incoterm_validation():
    """BE09-T14: incoterm_code validated against master list; unknown -> ValidationError (422)."""
    # Valid uppercase/lowercase
    req_valid = FinancialSettlementCreate(import_file_id=1, incoterm_code="cif")
    assert req_valid.incoterm_code == "CIF"

    # Unknown code raises ValidationError
    with pytest.raises(ValidationError) as exc:
        FinancialSettlementCreate(import_file_id=1, incoterm_code="XYZ")
    assert "incoterm_code" in str(exc.value)

    # Update schema also validates
    with pytest.raises(ValidationError) as exc2:
        FinancialSettlementUpdate(incoterm_code="INVALID")
    assert "incoterm_code" in str(exc2.value)


def test_be09_t14_hard_block_justification_whitespace(db):
    """BE09-T14: Hard block check rejects whitespace-only justification ('   ') -> 400."""
    from modules.recalculation.service import apply
    from modules.users.model import User

    imp = seed_shipment(db)
    rec = fs.create_settlement_service(db, FinancialSettlementCreate(import_file_id=imp.import_file_id), actor="alice")

    admin_user = User(
        user_id=999,
        username="admin_user",
        email="admin@example.com",
        full_name="Admin",
        hashed_password="pw",
        role="ADMIN",
        is_active=True,
    )

    # Mock _evaluate_dependencies to simulate a hard block item
    from modules.recalculation import service as recalc_svc
    from modules.recalculation.schemas import RecalculationPreviewItem

    hard_block_item = RecalculationPreviewItem(
        dependency_id=1,
        field_name="total_fob_egp",
        label_ar="إجمالي فوب",
        label_en="Total FOB",
        old_value=100000.0,
        new_value=200000.0,
        variance_amount=100000.0,
        variance_percentage=100.0,
        threshold_percentage=10.0,
        is_hard_block=True,
        source_entity_type="purchase_order",
        status="OK",
    )

    from modules.recalculation.schemas import RecalculationApplyRequest
    req = RecalculationApplyRequest(
        target_entity_type="financial_settlement",
        target_entity_id=rec.settlement_id,
        source_page="test",
        justification="   ",  # whitespace only
    )

    with patch.object(recalc_svc, "_evaluate_dependencies", return_value=[hard_block_item]):
        with pytest.raises(HTTPException) as exc:
            apply(
                db=db,
                request=req,
                current_user=admin_user,
            )
        assert exc.value.status_code == 400
        assert "مبرر كتابي" in exc.value.detail


def test_be09_t14_list_dependencies_permission_filter(db):
    """BE09-T14: Unfiltered list_dependencies returns only target types viewable by the user."""
    from modules.recalculation.service import list_dependencies
    from modules.recalculation.seed_dependencies import run_seed
    from modules.users.model import User
    from modules.recalculation import service as recalc_svc

    # Ensure dependencies are seeded in this test db
    run_seed(db)

    # Normal user with no permissions
    limited_user = User(
        user_id=888,
        username="limited_user",
        email="limited@example.com",
        full_name="Limited",
        hashed_password="pw",
        role="USER",
        is_active=True,
    )

    # Patch has_user_permission so user has only financial_settlement.view but NOT financial_approval.view
    def fake_has_perm(d, u, perm):
        if perm == "financial_settlement.view":
            return True
        return False

    with patch.object(recalc_svc, "has_user_permission", side_effect=fake_has_perm):
        deps = list_dependencies(db, limited_user)
        target_types = {d.target_entity_type for d in deps}
        assert "financial_settlement" in target_types
        assert "import_budget" not in target_types



