"""
Legacy-row tolerance of list endpoints (screenshot run 2026-10-05: freight booking, customs clearance and
warehouse receiving lists returned HTTP 500).

Root cause: the startup schema upgrade adds a column that only has a Python-side default as a plain nullable
column, so rows created before the upgrade read NULL there (customs_clearance_records: 16 columns added on
2026-08-23 / 2026-09-18; warehouse_receiving_records: 4 columns added on 2026-09-18). Freight booking's
free_demurrage_days is nullable and an update may clear it. The response models declared those fields as
non-nullable, so one such row turned the whole list into a ResponseValidationError.
"""
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app
from database.database import Base, get_db
from modules.customs_clearance.model import CustomsClearanceRecord
from modules.customs_clearance.schemas import CustomsClearanceResponse
from modules.freight_booking.model import ShipmentBooking
from modules.import_files.model import ImportFile
from modules.warehouse_receiving.model import WarehouseReceivingRecord

HEADERS = {"X-User-Role": "ADMIN", "X-User-Name": "admin"}

# Columns the startup upgrade added after the table existed (git log -S on each model), i.e. NULL on old rows.
CUSTOMS_LATE_COLUMNS = (
    "customs_tariff_items_count", "cif_base_amount", "customs_exchange_rate", "development_fee_amount",
    "customs_service_fees", "estimated_duty_total", "actual_duty_total", "duty_variance_amount",
    "duty_variance_percentage", "assessment_status", "free_days_allowed", "delivery_order_fees",
    "delivery_order_currency", "delivery_order_status", "duty_paid_amount", "total_clearance_expenses_egp",
    "total_port_expenses_egp", "total_handling_expenses_egp", "clearance_invoices_count",
)
WAREHOUSE_LATE_COLUMNS = ("supplier_claim_filed", "claim_amount_estimated", "claim_currency", "discrepancy_rate_percent")


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    db = sessionmaker(autocommit=False, autoflush=False, bind=engine)()
    try:
        yield db
    finally:
        db.close()
        engine.dispose()


@pytest.fixture
def client(db_session):
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    try:
        yield TestClient(app, raise_server_exceptions=False)
    finally:
        app.dependency_overrides.clear()


def _import_file(db) -> ImportFile:
    imp = ImportFile(import_file_code="IMP-LEGACY-0001", company_name="Legacy Co", supplier_name="Legacy Supplier")
    db.add(imp)
    db.commit()
    return imp


def _null_out(db, table: str, columns, id_column: str, row_id: int) -> None:
    """Make the row look like one created before ``columns`` were added (the upgrade leaves them NULL)."""
    db.execute(text(f"UPDATE {table} SET {', '.join(f'{c} = NULL' for c in columns)} WHERE {id_column} = :i"), {"i": row_id})
    db.commit()
    db.expire_all()


def test_customs_clearance_list_tolerates_legacy_row(db_session, client):
    imp = _import_file(db_session)
    rec = CustomsClearanceRecord(clearance_code="CLR-LEGACY-0001", import_file_id=imp.import_file_id, created_by="admin", updated_by="admin")
    db_session.add(rec)
    db_session.commit()
    _null_out(db_session, "customs_clearance_records", CUSTOMS_LATE_COLUMNS, "customs_clearance_id", rec.customs_clearance_id)

    response = client.get("/api/v1/customs-clearance", headers=HEADERS)

    assert response.status_code == 200, response.text
    row = next(r for r in response.json() if r["clearance_code"] == "CLR-LEGACY-0001")
    assert row["clearance_invoices_count"] == 0
    assert row["delivery_order_status"] == "Pending"
    assert row["assessment_status"] == "Assessed"
    # Money / rates are never fabricated: a legacy NULL stays null (no 1.0 exchange rate, no 0.0 totals).
    assert row["customs_exchange_rate"] is None
    assert row["cif_base_amount"] is None
    assert row["total_clearance_expenses_egp"] is None
    assert row["duty_paid_amount"] is None


def test_warehouse_receiving_list_tolerates_legacy_row(db_session, client):
    imp = _import_file(db_session)
    rec = WarehouseReceivingRecord(
        grn_code="GRN-LEGACY-0001", import_file_id=imp.import_file_id, warehouse_name="Cairo Main Warehouse",
        arrival_datetime=datetime(2026, 9, 1, 9, 0), inspector_name="admin", created_by="admin", updated_by="admin",
    )
    db_session.add(rec)
    db_session.commit()
    _null_out(db_session, "warehouse_receiving_records", WAREHOUSE_LATE_COLUMNS, "receiving_id", rec.receiving_id)

    response = client.get("/api/v1/warehouse-receiving", headers=HEADERS)

    assert response.status_code == 200, response.text
    row = next(r for r in response.json() if r["grn_code"] == "GRN-LEGACY-0001")
    assert row["claim_currency"] == "EGP"
    assert row["supplier_claim_filed"] is False
    assert row["claim_amount_estimated"] is None
    assert row["discrepancy_rate_percent"] is None


def test_freight_booking_cleared_free_days_does_not_break_update_or_list(db_session, client):
    booking = ShipmentBooking(booking_code="BKG-LEGACY-0001", status="Draft", owner="admin")
    db_session.add(booking)
    db_session.commit()

    # The app itself can store NULL: the column is nullable and an explicit null on update is kept.
    updated = client.put(f"/api/v1/freight-booking/{booking.booking_id}", json={"free_demurrage_days": None}, headers=HEADERS)
    assert updated.status_code == 200, updated.text
    stored = db_session.execute(
        text("SELECT free_demurrage_days FROM shipment_bookings WHERE booking_id = :i"), {"i": booking.booking_id}
    ).scalar()
    assert stored is None

    listed = client.get("/api/v1/freight-booking", headers=HEADERS)
    assert listed.status_code == 200, listed.text
    row = next(r for r in listed.json() if r["booking_code"] == "BKG-LEGACY-0001")
    assert row["free_demurrage_days"] is None


def test_financial_settlement_list_with_app_written_row(db_session, client):
    """Settlement 500 in the screenshot run came only from hand SQL that left created_*/updated_* NULL; every app
    path writes them (columns exist since the table was created), so an app-written row must list fine."""
    from modules.financial_settlement.model import LandedCostSettlementRecord

    imp = _import_file(db_session)
    rec = LandedCostSettlementRecord(settlement_code="LCS-LEGACY-0001", import_file_id=imp.import_file_id, created_by="admin", updated_by="admin")
    db_session.add(rec)
    db_session.commit()

    response = client.get("/api/v1/financial-settlement", headers=HEADERS)

    assert response.status_code == 200, response.text
    assert any(r["settlement_code"] == "LCS-LEGACY-0001" for r in response.json())


# ── Input-only rules are not re-applied on read (Create/Update keep them) ─────────────────────────────────────

def test_acid_list_shows_legacy_15_digit_number(db_session, client):
    from modules.import_documentation.model import AcidRegistrationSession
    from modules.import_documentation.schemas import AcidRegistrationCreate

    legacy_acid = "123456789012345"  # 15 digits: older Nafeza format, rejected by today's input rule
    db_session.add(AcidRegistrationSession(
        acid_code="ACID-LEGACY-0001", acid_number=legacy_acid, importer_name="Legacy Importer",
        importer_tax_id="123-456-789", exporter_name="Legacy Exporter", exporter_reg_id="REG-1",
        exporter_country="China", proforma_invoice_no="PI-1", pol_name="Ningbo", pod_name="Alexandria",
        expiry_date=datetime(2026, 12, 31).date(),
    ))
    db_session.commit()

    response = client.get("/api/v1/import-documentation/acid-sessions", headers=HEADERS)

    assert response.status_code == 200, response.text
    row = next(r for r in response.json() if r["acid_code"] == "ACID-LEGACY-0001")
    assert row["acid_number"] == legacy_acid
    # The input rule still guards new data.
    with pytest.raises(ValidationError):
        AcidRegistrationCreate(
            acid_number=legacy_acid, importer_name="Imp", importer_tax_id="12345", exporter_name="Exp",
            exporter_reg_id="R", exporter_country="CN", proforma_invoice_no="PI", pol_name="A", pod_name="B",
        )


def test_banking_list_shows_legacy_zero_amount(db_session, client):
    from modules.import_documentation.model import BankingDocumentSession
    from modules.import_documentation.schemas import BankingDocumentCreate

    db_session.add(BankingDocumentSession(bank_doc_code="BNK-LEGACY-0001", bank_name="Legacy Bank", amount=0.0))
    db_session.commit()

    response = client.get("/api/v1/import-documentation/banking-documents", headers=HEADERS)

    assert response.status_code == 200, response.text
    row = next(r for r in response.json() if r["bank_doc_code"] == "BNK-LEGACY-0001")
    assert row["amount"] == 0.0
    with pytest.raises(ValidationError):
        BankingDocumentCreate(bank_name="Bank", amount=0.0)


def test_demurrage_policy_list_tolerates_legacy_nested_tier(db_session, client):
    """Nested models shared with the request body (TierRateItem: from_day >= 1) are relaxed on read only."""
    from modules.demurrage_detention.model import DemurragePolicy
    from modules.demurrage_detention.schemas import TierRateItem

    db_session.add(DemurragePolicy(
        carrier_name="Legacy Line", container_type="40HC",
        demurrage_tiers=[{"from_day": 0, "to_day": 7, "rate_per_day": 0.0}], detention_tiers=[],
    ))
    db_session.commit()

    response = client.get("/api/v1/demurrage-detention/policies", headers=HEADERS)

    assert response.status_code == 200, response.text
    row = next(r for r in response.json() if r["carrier_name"] == "Legacy Line")
    assert row["demurrage_tiers"][0]["from_day"] == 0
    with pytest.raises(ValidationError):
        TierRateItem(from_day=0, rate_per_day=1.0)


def test_response_models_keep_their_own_read_normalisers():
    """read_model drops inherited input validators but keeps validators declared on the response class."""
    from modules.financial_approval.schemas import PaymentRequestResponse
    from modules.import_documentation.schemas import AcidRegistrationResponse

    assert set(PaymentRequestResponse.__pydantic_decorators__.field_validators) == {"_payment_type_code"}
    assert set(AcidRegistrationResponse.__pydantic_decorators__.field_validators) == {"_acid_number_read"}


def test_checklist_auto_sync_tolerates_legacy_null_duty_columns(db_session):
    """smart_checklists compared actual_duty_total / import_duty_amount > 0 without a NULL guard: TypeError -> 500."""
    import modules.smart_checklists.service as checklist_service

    imp = _import_file(db_session)
    rec = CustomsClearanceRecord(
        clearance_code="CLR-LEGACY-0002", import_file_id=imp.import_file_id, channel_type="Red Channel",
        created_by="admin", updated_by="admin",
    )
    db_session.add(rec)
    db_session.commit()
    _null_out(db_session, "customs_clearance_records", ("actual_duty_total", "import_duty_amount"),
              "customs_clearance_id", rec.customs_clearance_id)

    result = checklist_service.auto_sync_checklist(db_session, imp.import_file_id)

    passed = set(result.newly_passed_codes)
    assert "CHK_PRT_03" in passed  # the clearance row was evaluated
    assert "CHK_CLR_01" not in passed and "CHK_CLR_04" not in passed  # NULL duty is not "paid"


def test_required_field_without_any_default_is_not_invented():
    """The normaliser only substitutes declared defaults: a NULL audit timestamp is still reported."""
    rec = CustomsClearanceRecord(
        customs_clearance_id=1, clearance_code="CLR-X", import_file_id=1, customs_office_name="Office",
        channel_type="Red Channel", status="Draft", owner="admin", is_active=True, regulatory_bodies=[],
        created_at=None, created_by="admin", updated_at=datetime.now(timezone.utc), updated_by="admin",
    )
    with pytest.raises(ValidationError) as excinfo:
        CustomsClearanceResponse.model_validate(rec)
    assert {e["loc"][0] for e in excinfo.value.errors()} == {"created_at"}
