import pytest
from datetime import date, timedelta
from fastapi.testclient import TestClient
from database.database import get_db, Base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from main import app
from modules.import_files.model import ImportFile
from modules.import_companies.model import ImportCompany
from modules.suppliers.model import Supplier
from modules.incoterms.model import Incoterm
from modules.currencies.model import Currency
from modules.projects.model import Project
from modules.customs_tariff.model import CustomsTariff
from modules.purchase_orders.model import PurchaseOrder, POLineItem
from modules.import_documentation.model import POPackingReconciliationSession
from modules.customs_consultation.service import CustomsConsultationService


SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        # Create master data
        comp = ImportCompany(
            importer_name="الشركة النموذجية",
            address="Cairo",
            country="Egypt",
            importer_id="IMP-001",
            importer_id_expiry=date.today() + timedelta(days=120),
            vat_id="VAT-001",
            vat_id_expiry=date.today() + timedelta(days=90),
            registration_number="REG-001",
            registration_expiry=date.today() + timedelta(days=180),
            phone="+2010000000",
            email="info@model.com",
        )
        db.add(comp)
        sup = Supplier(
            supplier_code="SUP-9901",
            company_name="Test China Supplier",
            supplier_type="Manufacturer",
            registration_type="Commercial Registry",
            foreign_exporter_id="EX-9901",
            foreign_exporter_country="China",
            foreign_exporter_country_code="CN",
            address="Hangzhou, China",
            phone="+8612345",
            email="supplier@china.com",
        )
        db.add(sup)
        incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
        currency = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
        db.add_all([incoterm, currency])
        db.commit()

        proj = Project(
            project_code="PRJ-2026-99",
            project_name="Marble Import Project",
            project_owner="Eng. Ali",
            company_id=comp.company_id,
            supplier_id=sup.supplier_id,
            incoterm_id=incoterm.incoterm_id,
            is_active=True,
        )
        db.add(proj)
        db.commit()

        tariff = CustomsTariff(
            hs_code="6802.99",
            hs_description="جرانيت ورخام",
            customs_duty_rate=10.0,
            vat_rate=14.0,
            schedule_tax_rate=0.0,
            development_fee_rate=0.0,
            customs_service_fee_rate=1.0,
            effective_from=date(2020, 1, 1),
        )
        db.add(tariff)
        db.commit()

        imp_file = ImportFile(
            import_file_code="IMP-2026-TEST",
            company_id=comp.company_id,
            company_name=comp.importer_name,
            supplier_id=sup.supplier_id,
            supplier_name=sup.company_name,
            pi_number="PI-9901",
            status="In Progress",
        )
        db.add(imp_file)
        db.commit()

        # Preliminary PO
        po = PurchaseOrder(
            po_number="PO-2026-99",
            import_file_id=imp_file.import_file_id,
            project_id=proj.project_id,
            company_id=comp.company_id,
            supplier_id=sup.supplier_id,
            incoterm_id=incoterm.incoterm_id,
            currency_id=currency.currency_id,
            total_amount_fob=10000.0,
        )
        db.add(po)
        db.commit()

        item = POLineItem(
            po_id=po.po_id,
            description_ar="Raw Granite Slabs",
            tariff_id=tariff.tariff_id,
            quantity=100.0,
            unit_price=100.0,
            total_price=10000.0,
        )
        db.add(item)
        db.commit()

        # Reconciled Final Invoice Session with 120 units at $110
        reconcil = POPackingReconciliationSession(
            session_code="REC-2026-001",
            import_file_id=imp_file.import_file_id,
            final_invoice_number="INV-FINAL-2026-01",
            currency="USD",
            total_invoice_amount=13200.0,
            is_safe_for_certification=True,
            overall_status="FULLY_MATCHED",
            reconciled_invoice_items=[
                {
                    "item_name": "Raw Granite Slabs Reconciled",
                    "hs_code": "6802.99",
                    "quantity": 120.0,
                    "unit_price": 110.0,
                    "total_price": 13200.0,
                    "country_of_origin": "CN",
                }
            ],
        )
        db.add(reconcil)
        db.commit()

        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


def test_customs_consultation_recalculation(db_session):
    imp_file = db_session.query(ImportFile).first()
    res = CustomsConsultationService.recalculate_from_reconciliation_service(
        db_session,
        import_file_id=imp_file.import_file_id,
        exchange_rate=50.0,
        freight_egp=5000.0,
        insurance_egp=1000.0,
    )

    assert res.import_file_id == imp_file.import_file_id
    assert res.is_reconciled is True
    assert res.final_invoice_number == "INV-FINAL-2026-01"
    assert res.preliminary_fob_egp == 500000.0  # 10,000 * 50
    assert res.final_fob_egp == 660000.0        # 13,200 * 50
    assert res.fob_variance_egp == 160000.0
    assert res.forecast_status == "Increased Cost"
    assert len(res.comparison_lines) == 1
    assert res.comparison_lines[0].qty_variance == 20.0
    assert res.comparison_lines[0].unit_price_variance == 10.0
    assert res.total_taxes_variance_egp > 0


def test_customs_recalculation_api_endpoint(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    from modules.auth.security import create_access_token, hash_password
    from modules.users.model import User

    user = User(
        username="admin_recalc_test",
        email="admin_recalc@test.com",
        full_name="Admin Test",
        hashed_password=hash_password("Admin@123"),
        role="ADMIN",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    token = create_access_token({"sub": str(user.user_id), "role": user.role})
    headers = {"Authorization": f"Bearer {token}"}

    app.dependency_overrides[get_db] = override_get_db
    client = TestClient(app)

    imp_file = db_session.query(ImportFile).first()
    payload = {
        "import_file_id": imp_file.import_file_id,
        "exchange_rate": 52.0,
        "freight_egp": 6000.0,
        "insurance_egp": 1200.0,
    }

    response = client.post("/api/v1/customs-consultations/recalculate-from-reconciliation", json=payload, headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["import_file_id"] == imp_file.import_file_id
    assert data["exchange_rate"] == 52.0
    assert data["is_reconciled"] is True
    assert "comparison_lines" in data

    app.dependency_overrides.clear()


# ── CC-01: tariff engine, no fallback rates ─────────────────────────────────────

def _recalc(db, **kw):
    imp_file = db.query(ImportFile).first()
    return CustomsConsultationService.recalculate_from_reconciliation_service(db, import_file_id=imp_file.import_file_id, **kw)


def _set_final_items(db, items):
    rec = db.query(POPackingReconciliationSession).first()
    rec.reconciled_invoice_items = items
    db.commit()


def test_taxes_come_from_the_tariff_engine(db_session):
    res = _recalc(db_session, exchange_rate=50.0, freight_egp=0.0, insurance_egp=0.0)
    line = res.comparison_lines[0]
    assert line.status == "OK"
    # Final CIF 660,000: duty 10% = 66,000; VAT 14% on (CIF + duty) = 101,640; service fee 1% = 6,600.
    assert line.final_duty_egp == 66000.0
    assert line.final_vat_egp == 101640.0
    assert line.final_total_taxes_egp == 174240.0
    assert res.final_cif_egp == 660000.0
    assert res.tariff_missing_lines_count == 0


def test_missing_tariff_line_is_flagged_and_excluded_from_totals(db_session):
    _set_final_items(db_session, [
        {"item_name": "Granite", "hs_code": "6802.99", "quantity": 120.0, "unit_price": 110.0, "total_price": 13200.0},
        {"item_name": "Unknown", "hs_code": "9999.99", "quantity": 10.0, "unit_price": 10.0, "total_price": 100.0},
    ])
    res = _recalc(db_session, exchange_rate=50.0)
    by_name = {line.item_name: line for line in res.comparison_lines}
    missing = by_name["Unknown"]
    assert missing.status == "TARIFF_MISSING"
    assert (missing.final_duty_egp, missing.final_vat_egp, missing.vat_rate_pct, missing.duty_rate_pct) == (0.0, 0.0, 0.0, 0.0)
    assert res.tariff_missing_lines_count == 1
    assert res.final_fob_egp == 660000.0  # the unknown line's 5,000 EGP is not in the totals
    assert res.final_total_taxes_egp == by_name["Granite"].final_total_taxes_egp


def test_line_without_hs_is_tariff_missing_not_defaulted(db_session):
    _set_final_items(db_session, [{"item_name": "No HS", "quantity": 1.0, "unit_price": 10.0, "total_price": 10.0}])
    db_session.query(POLineItem).delete()
    db_session.commit()
    res = _recalc(db_session, exchange_rate=50.0)
    assert res.comparison_lines[0].status == "TARIFF_MISSING"
    assert res.comparison_lines[0].hs_code == ""
    assert res.final_total_taxes_egp == 0.0


def test_lines_match_by_po_item_id_not_position(db_session):
    po = db_session.query(PurchaseOrder).first()
    tariff = db_session.query(CustomsTariff).first()
    first = db_session.query(POLineItem).first()
    second = POLineItem(po_id=po.po_id, item_code="B-2", description_ar="Second", tariff_id=tariff.tariff_id,
                        quantity=5.0, unit_price=20.0, total_price=100.0)
    db_session.add(second)
    db_session.commit()
    _set_final_items(db_session, [
        {"po_item_id": second.item_id, "description": "Second final", "hs_code": "6802.99",
         "final_quantity": 6.0, "final_unit_price": 20.0, "total_amount": 120.0},
        {"po_item_id": first.item_id, "description": "First final", "hs_code": "6802.99",
         "final_quantity": 100.0, "final_unit_price": 100.0, "total_amount": 10000.0},
    ])
    res = _recalc(db_session, exchange_rate=1.0)
    lines = {line.item_name: line for line in res.comparison_lines}
    assert lines["Second final"].preliminary_qty == 5.0
    assert lines["Second final"].qty_variance == 1.0
    assert lines["First final"].preliminary_qty == 100.0
    assert lines["First final"].qty_variance == 0.0


def test_fx_comes_from_customs_rate_table(db_session):
    from modules.currencies.model import Currency as CurrencyModel, ExchangeRate
    import modules.currencies.service as currency_service

    usd = db_session.query(CurrencyModel).filter(CurrencyModel.currency_code == "USD").one()
    db_session.add(ExchangeRate(currency_id=usd.currency_id, commercial_rate=49.0, customs_rate=48.25,
                                effective_date=date(2020, 1, 1)))
    db_session.commit()
    currency_service._RATE_CACHE.clear()
    res = _recalc(db_session, estimate_date=date(2026, 1, 15))
    assert res.exchange_rate == 48.25
    assert res.preliminary_fob_egp == 482500.0


def test_missing_customs_rate_is_409_not_a_fallback(db_session):
    import modules.currencies.service as currency_service
    from fastapi import HTTPException

    currency_service._RATE_CACHE.clear()
    with pytest.raises(HTTPException) as exc:
        _recalc(db_session, estimate_date=date(2026, 1, 16))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "CUSTOMS_FX_RATE_MISSING"
    assert exc.value.detail["currency"] == "USD"


def test_missing_tariff_line_keeps_its_freight_share(db_session):
    # Granite (OK) 13,200 USD + Unknown (no tariff) 100 USD: the OK line gets only 13,200 / 13,300 of the
    # freight and insurance, not the whole amount.
    _set_final_items(db_session, [
        {"item_name": "Granite", "hs_code": "6802.99", "quantity": 120.0, "unit_price": 110.0, "total_price": 13200.0},
        {"item_name": "Unknown", "hs_code": "9999.99", "quantity": 10.0, "unit_price": 10.0, "total_price": 100.0},
    ])
    res = _recalc(db_session, exchange_rate=50.0, freight_egp=6000.0, insurance_egp=1330.0)
    granite = next(line for line in res.comparison_lines if line.item_name == "Granite")
    expected_cif = 660000.0 + (6000.0 + 1330.0) * 13200.0 / 13300.0  # 667274.89
    assert granite.final_cif_egp == pytest.approx(expected_cif, abs=0.01)
    assert res.final_cif_egp == pytest.approx(expected_cif, abs=0.01)


# ── customs-rules review: currency per side, complete preliminary side, rate source ─────────────

def _rate(db, code, customs_rate):
    from modules.currencies.model import Currency as CurrencyModel, ExchangeRate

    cur = db.query(CurrencyModel).filter(CurrencyModel.currency_code == code).first()
    if cur is None:
        cur = CurrencyModel(currency_code=code, currency_name=code, currency_symbol=code, is_active=True)
        db.add(cur)
        db.commit()
    db.add(ExchangeRate(currency_id=cur.currency_id, commercial_rate=customs_rate, customs_rate=customs_rate,
                        effective_date=date(2020, 1, 1)))
    db.commit()


def _clear_rate_cache():
    import modules.currencies.service as currency_service

    currency_service._RATE_CACHE.clear()


def test_each_side_uses_its_own_currency_and_customs_rate(db_session):
    _rate(db_session, "USD", 50.0)
    _rate(db_session, "EUR", 55.0)
    _clear_rate_cache()
    rec = db_session.query(POPackingReconciliationSession).first()
    rec.currency = "EUR"
    db_session.commit()
    res = _recalc(db_session, estimate_date=date(2026, 2, 1))
    assert (res.preliminary_currency, res.final_currency) == ("USD", "EUR")
    assert (res.preliminary_exchange_rate, res.exchange_rate) == (50.0, 55.0)
    assert res.exchange_rate_source == "table"
    assert res.preliminary_fob_egp == 500000.0   # 10,000 USD x 50
    assert res.final_fob_egp == 726000.0         # 13,200 EUR x 55


def test_manual_rate_is_reported_as_manual(db_session):
    res = _recalc(db_session, exchange_rate=50.0)
    assert res.exchange_rate_source == "manual"
    assert res.preliminary_exchange_rate == res.exchange_rate == 50.0


def test_unregistered_currency_without_rate_is_coded_409(db_session):
    from fastapi import HTTPException

    _clear_rate_cache()
    rec = db_session.query(POPackingReconciliationSession).first()
    rec.currency = "ZZZ"
    db_session.commit()
    _rate(db_session, "USD", 50.0)
    _clear_rate_cache()
    with pytest.raises(HTTPException) as exc:
        _recalc(db_session, estimate_date=date(2026, 2, 2))
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "CUSTOMS_FX_RATE_MISSING"
    assert exc.value.detail["currency"] == "ZZZ"


def test_split_new_and_dropped_items_keep_both_totals_complete(db_session):
    po = db_session.query(PurchaseOrder).first()
    tariff = db_session.query(CustomsTariff).first()
    first = db_session.query(POLineItem).first()  # 100 x 100 = 10,000
    dropped = POLineItem(po_id=po.po_id, item_code="DROP", description_ar="Dropped", tariff_id=tariff.tariff_id,
                         quantity=10.0, unit_price=10.0, total_price=100.0)
    db_session.add(dropped)
    db_session.commit()
    _set_final_items(db_session, [
        # split: the first PO line arrives as two invoice rows
        {"po_item_id": first.item_id, "description": "Split A", "hs_code": "6802.99",
         "final_quantity": 60.0, "final_unit_price": 100.0, "total_amount": 6000.0},
        {"po_item_id": first.item_id, "description": "Split B", "hs_code": "6802.99",
         "final_quantity": 40.0, "final_unit_price": 100.0, "total_amount": 4000.0},
        # new item that was never ordered
        {"description": "New", "item_code": "NEW-1", "hs_code": "6802.99",
         "final_quantity": 5.0, "final_unit_price": 20.0, "total_amount": 100.0},
    ])
    res = _recalc(db_session, exchange_rate=1.0)
    lines = {line.item_name: line for line in res.comparison_lines}
    assert lines["Split A"].preliminary_qty == 100.0       # matched once
    assert lines["Split B"].preliminary_qty == 0.0         # no reuse of an already matched PO line
    assert lines["New"].preliminary_qty == 0.0
    assert lines["Dropped"].final_qty == 0.0               # PO line with no invoice row: preliminary only
    assert lines["Dropped"].preliminary_qty == 10.0
    assert res.preliminary_fob_egp == 10100.0              # every PO line counted once
    assert res.final_fob_egp == 10100.0                    # every invoice row counted


def test_preliminary_side_with_mixed_po_currencies_is_coded_409(db_session):
    from fastapi import HTTPException
    from modules.currencies.model import Currency as CurrencyModel

    eur = CurrencyModel(currency_code="EUR", currency_name="Euro", currency_symbol="E", is_active=True)
    db_session.add(eur)
    db_session.commit()
    first = db_session.query(PurchaseOrder).first()
    second = PurchaseOrder(po_number="PO-2026-EUR", import_file_id=first.import_file_id, project_id=first.project_id,
                           company_id=first.company_id, supplier_id=first.supplier_id, incoterm_id=first.incoterm_id,
                           currency_id=eur.currency_id, total_amount_fob=100.0)
    db_session.add(second)
    db_session.commit()
    db_session.add(POLineItem(po_id=second.po_id, description_ar="EUR line", quantity=1.0, unit_price=100.0, total_price=100.0))
    db_session.commit()
    with pytest.raises(HTTPException) as exc:
        _recalc(db_session, exchange_rate=50.0)
    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "CUSTOMS_MIXED_CURRENCY"


def test_manual_rate_applies_only_to_its_side_when_currencies_differ(db_session):
    _rate(db_session, "USD", 48.0)
    _clear_rate_cache()
    rec = db_session.query(POPackingReconciliationSession).first()
    rec.currency = "EUR"
    db_session.commit()
    res = _recalc(db_session, exchange_rate=50.0, estimate_date=date(2026, 2, 3))
    assert (res.exchange_rate, res.exchange_rate_source) == (50.0, "manual")              # EUR final side
    assert (res.preliminary_exchange_rate, res.preliminary_exchange_rate_source) == (48.0, "table")  # USD PO side
    assert res.preliminary_fob_egp == 480000.0

    both = CustomsConsultationService.recalculate_from_reconciliation_service(
        db_session, import_file_id=rec.import_file_id, exchange_rate=50.0, preliminary_exchange_rate=47.0,
    )
    assert (both.preliminary_exchange_rate, both.preliminary_exchange_rate_source) == (47.0, "manual")


def test_empty_file_returns_zero_totals_without_rate_lookup(db_session):
    db_session.query(POLineItem).delete()
    db_session.query(POPackingReconciliationSession).delete()
    db_session.commit()
    res = _recalc(db_session)  # no rate configured: must not 409
    assert res.comparison_lines == []
    assert (res.preliminary_fob_egp, res.final_total_taxes_egp) == (0.0, 0.0)
