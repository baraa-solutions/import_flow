"""
Unit tests for BE01-T13:
Scenario clone guard and update re-validation (modules/shipping_scenarios).
"""
from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import main  # Registers all SQLAlchemy models on Base.metadata
from database.database import Base
from modules.common.errors import CodedHTTPException
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.shipping_scenarios.schemas import (
    CloneShippingEvaluationRequest,
    ShippingEvaluationCreate,
    ShippingEvaluationUpdate,
    ShippingScenarioItemCreate,
)
from modules.shipping_scenarios.service import ShippingScenarioService
from modules.shipping_scenarios.validators import SCENARIO_SESSION_EXISTS


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()

    # Seed base provider and currencies
    from modules.currencies.model import Currency
    provider = ExternalServiceProvider(
        provider_id=1,
        partner_code="FF-001",
        partner_name="COSCO Logistics",
        partner_type="Freight Forwarder",
        is_active=True,
    )
    session.add(provider)
    session.add_all([
        Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True),
        Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True),
        Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="E£", is_active=True),
    ])
    session.commit()

    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _make_item(crd: date, provider_id: int = 1, sailing_offset: int = 2, arrival_offset: int = 20, **kwargs):
    data = {
        "provider_id": provider_id,
        "provider_name": "COSCO Logistics",
        "vessel_name": "COSCO PRIDE",
        "sailing_date": crd + timedelta(days=sailing_offset),
        "estimated_arrival_date": crd + timedelta(days=arrival_offset),
        "expected_line_delay_days": 0,
        "free_time_days": 14,
        "total_quotation_amount": 2000.0,
        "quotation_currency": "USD",
    }
    data.update(kwargs)
    return ShippingScenarioItemCreate(**data)


def _create_import_file(db: Session, code: str = "IMP-TEST-001", is_active: bool = True) -> ImportFile:
    imp = ImportFile(
        import_file_code=code,
        company_name="Test Company",
        supplier_name="Test Supplier",
        shipment_mode="Sea",
        incoterm_code="FOB",
        priority="Normal",
        shipment_category="Commercial",
        is_active=is_active,
    )
    db.add(imp)
    db.commit()
    db.refresh(imp)
    return imp


def _create_po(db: Session, po_number: str = "PO-TEST-001", is_active: bool = True) -> PurchaseOrder:
    po = PurchaseOrder(
        po_number=po_number,
        project_id=1,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        total_amount_fob=1000.0,
        status="Draft",
        version=1,
        is_active=is_active,
    )
    db.add(po)
    db.commit()
    db.refresh(po)
    return po


class TestScenarioCloneGuardAndUpdateRevalidation:

    def test_clone_keeping_import_file_raises_409_scenario_session_exists(self, db: Session):
        """
        When cloning a session without unlinking import_file_id (unlink_import_file=False),
        it must detect the existing active study and raise 409 SCENARIO_SESSION_EXISTS.
        """
        imp = _create_import_file(db, code="IMP-CLONE-409")
        crd = date.today() + timedelta(days=5)

        session_res = ShippingScenarioService.create_session_service(
            db,
            ShippingEvaluationCreate(
                title="Original File Study",
                cargo_ready_date=crd,
                import_file_id=imp.import_file_id,
                items=[_make_item(crd)],
            ),
        )

        # Clone keeping the file link -> 409
        clone_req = CloneShippingEvaluationRequest(
            new_title="Duplicate Study for Same File",
            unlink_import_file=False,
            copy_carrier_options=True,
        )

        with pytest.raises(CodedHTTPException) as exc:
            ShippingScenarioService.clone_session_service(db, session_res.session_id, clone_req)

        assert exc.value.status_code == 409
        assert exc.value.code == SCENARIO_SESSION_EXISTS
        assert "يوجد بالفعل دراسة سيناريوهات شحن محفوظة لهذا الملف" in str(exc.value.detail)

    def test_clone_unlinking_import_file_succeeds(self, db: Session):
        """Cloning with unlink_import_file=True (default) succeeds and resets import_file_id."""
        imp = _create_import_file(db, code="IMP-CLONE-UNLINK")
        crd = date.today() + timedelta(days=5)

        session_res = ShippingScenarioService.create_session_service(
            db,
            ShippingEvaluationCreate(
                title="Original File Study 2",
                cargo_ready_date=crd,
                import_file_id=imp.import_file_id,
                items=[_make_item(crd)],
            ),
        )

        clone_req = CloneShippingEvaluationRequest(
            new_title="Standalone Study Clone",
            unlink_import_file=True,
            copy_carrier_options=True,
        )

        cloned = ShippingScenarioService.clone_session_service(db, session_res.session_id, clone_req)
        assert cloned.session_id != session_res.session_id
        assert cloned.import_file_id is None
        assert cloned.title == "Standalone Study Clone"
        assert len(cloned.items) == 1

    def test_clone_revalidates_fks_and_rejects_inactive_carrier_provider(self, db: Session):
        """
        When cloning a session whose carrier item references a provider that was
        deactivated since, validate_foreign_keys must raise 400.
        """
        crd = date.today() + timedelta(days=5)
        session_res = ShippingScenarioService.create_session_service(
            db,
            ShippingEvaluationCreate(
                title="Study with Provider 1",
                cargo_ready_date=crd,
                items=[_make_item(crd, provider_id=1)],
            ),
        )

        # Deactivate provider 1
        provider = db.get(ExternalServiceProvider, 1)
        provider.is_active = False
        db.commit()

        clone_req = CloneShippingEvaluationRequest(
            new_title="Clone with Deactivated Provider",
            copy_carrier_options=True,
        )

        with pytest.raises(HTTPException) as exc:
            ShippingScenarioService.clone_session_service(db, session_res.session_id, clone_req)

        assert exc.value.status_code == 400
        assert "مقدم خدمة الشحن رقم 1 غير موجود أو غير نشط" in exc.value.detail

    def test_clone_revalidates_header_fks_and_rejects_inactive_po(self, db: Session):
        """When cloning and keeping po_id (unlink_po=False) where PO was deactivated, raise 400."""
        po = _create_po(db, po_number="PO-CLONE-FK-TEST")
        crd = date.today() + timedelta(days=5)

        session_res = ShippingScenarioService.create_session_service(
            db,
            ShippingEvaluationCreate(
                title="Study with PO",
                cargo_ready_date=crd,
                po_id=po.po_id,
                items=[],
            ),
        )

        # Deactivate PO
        po.is_active = False
        db.commit()

        clone_req = CloneShippingEvaluationRequest(
            new_title="Clone with Inactive PO",
            unlink_po=False,
            copy_carrier_options=False,
        )

        with pytest.raises(HTTPException) as exc:
            ShippingScenarioService.clone_session_service(db, session_res.session_id, clone_req)

        assert exc.value.status_code == 400
        assert f"أمر الشراء رقم {po.po_id} غير موجود أو غير نشط" in exc.value.detail

    def test_update_changing_crd_without_items_revalidates_stored_items(self, db: Session):
        """
        When updating cargo_ready_date to a later date without providing items (items=None),
        stored items must be re-validated against the new CRD.
        If a stored item's sailing_date is before the new CRD, raise HTTP 400.
        """
        crd = date.today() + timedelta(days=10)
        # sailing_date = crd + 2 = day + 12
        session_res = ShippingScenarioService.create_session_service(
            db,
            ShippingEvaluationCreate(
                title="CRD Revalidation Study",
                cargo_ready_date=crd,
                items=[_make_item(crd, sailing_offset=2, arrival_offset=20)],
            ),
        )

        # Update CRD to day + 15 (which is AFTER sailing_date day + 12)
        new_crd = date.today() + timedelta(days=15)
        update_payload = ShippingEvaluationUpdate(
            cargo_ready_date=new_crd,
            items=None,
        )

        with pytest.raises(HTTPException) as exc:
            ShippingScenarioService.update_session_service(db, session_res.session_id, update_payload)

        assert exc.value.status_code == 400
        assert "لا يمكن أن يكون قبل تاريخ جاهزية البضاعة" in exc.value.detail or "cannot be before Cargo Ready Date" in exc.value.detail

    def test_update_changing_crd_valid_succeeds(self, db: Session):
        """Updating cargo_ready_date with a valid date earlier than sailing date succeeds."""
        crd = date.today() + timedelta(days=10)
        session_res = ShippingScenarioService.create_session_service(
            db,
            ShippingEvaluationCreate(
                title="Valid CRD Update",
                cargo_ready_date=crd,
                items=[_make_item(crd, sailing_offset=5, arrival_offset=25)],
            ),
        )

        # Update CRD to day + 12 (still <= day + 15 sailing_date)
        valid_crd = date.today() + timedelta(days=12)
        update_payload = ShippingEvaluationUpdate(
            cargo_ready_date=valid_crd,
            items=None,
        )

        updated = ShippingScenarioService.update_session_service(db, session_res.session_id, update_payload)
        assert updated.cargo_ready_date == valid_crd

    def test_update_negative_avg_form4_days_raises_400(self, db: Session):
        """Updating avg_form4_days with a negative value raises HTTP 400."""
        crd = date.today() + timedelta(days=5)
        session_res = ShippingScenarioService.create_session_service(
            db,
            ShippingEvaluationCreate(
                title="Avg Days Test",
                cargo_ready_date=crd,
            ),
        )

        with pytest.raises(HTTPException) as exc:
            ShippingScenarioService.update_session_service(
                db, session_res.session_id, ShippingEvaluationUpdate(avg_form4_days=-1)
            )
        assert exc.value.status_code == 400
        assert "متوسط أيام نموذج 4 لا يمكن أن يكون سالباً" in exc.value.detail or "Average Form 4 days cannot be negative." in exc.value.detail

    def test_update_negative_avg_clearance_days_raises_400(self, db: Session):
        """Updating avg_clearance_days with a negative value raises HTTP 400."""
        crd = date.today() + timedelta(days=5)
        session_res = ShippingScenarioService.create_session_service(
            db,
            ShippingEvaluationCreate(
                title="Avg Clearance Days Test",
                cargo_ready_date=crd,
            ),
        )

        with pytest.raises(HTTPException) as exc:
            ShippingScenarioService.update_session_service(
                db, session_res.session_id, ShippingEvaluationUpdate(avg_clearance_days=-3)
            )
        assert exc.value.status_code == 400
        assert "متوسط أيام التخليص الجمركي لا يمكن أن يكون سالباً" in exc.value.detail or "Average Customs Clearance days cannot be negative." in exc.value.detail

    @pytest.mark.parametrize(
        "field,value",
        [
            ("total_quotation_amount", -1.0),
            ("free_time_days", -5),
            ("container_40ft_price", -100.0),
            ("container_40ft_qty", -1),
            ("container_20ft_price", -50.0),
            ("container_20ft_qty", -2),
            ("lcl_cbm_price", -10.0),
            ("lcl_cbm_qty", -0.5),
            ("express_courier_price", -20.0),
            ("eur_atr_price", -15.0),
            ("solas_vgm_price", -25.0),
            ("vgm_notification_price", -5.0),
            ("telex_release_price", -30.0),
            ("insurance_price", -40.0),
            ("booking_cancellation_price", -50.0),
            ("ics2_filing_fee_price", -10.0),
            ("others_fee_price", -1.0),
            ("document_fees_price", -50.0),
            ("waiver_letter_fee_price", -20.0),
            ("dthc_price", -100.0),
            ("storage_per_week_price", -80.0),
            ("extra_day_storage_price", -15.0),
            ("clearance_fee_price", -200.0),
            ("inspection_fee_price", -150.0),
            ("inland_transport_fee_price", -300.0),
            ("port_expenses_price", -100.0),
        ],
    )
    def test_negative_price_or_qty_in_create_schema_raises_validation_error(self, field, value):
        """Every *_price, *_qty, total_quotation_amount, and free_time_days in Create schema must reject negative values."""
        crd = date.today() + timedelta(days=5)
        item_kwargs = {
            "provider_name": "COSCO Logistics",
            "vessel_name": "COSCO PRIDE",
            "sailing_date": crd + timedelta(days=2),
            "estimated_arrival_date": crd + timedelta(days=20),
            field: value,
        }
        with pytest.raises(ValidationError):
            ShippingScenarioItemCreate(**item_kwargs)
