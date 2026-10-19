from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy.orm import Session

from database.database import SessionLocal, Base, engine
import main  # Register all models in Base.metadata
from seed import seed_data
from modules.shipping_scenarios.schemas import (
    ShippingEvaluationCreate,
    ShippingEvaluationUpdate,
    ShippingScenarioItemCreate,
    CloneShippingEvaluationRequest,
)
from modules.shipping_scenarios.service import ShippingScenarioService


from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

@pytest.fixture(scope="module")
def db():
    test_engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=test_engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    session = TestingSession()
    # Scenario provider ids must reference active providers (SS-03).
    from modules.external_service_providers.model import ExternalServiceProvider
    session.add_all([
        ExternalServiceProvider(provider_id=1, partner_code="FF-001", partner_name="Forwarder One", partner_type="Freight Forwarder"),
        ExternalServiceProvider(provider_id=2, partner_code="FF-002", partner_name="Forwarder Two", partner_type="Freight Forwarder"),
    ])
    from modules.currencies.model import Currency, ExchangeRate
    session.add_all([
        Currency(currency_id=1, currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, decimal_places=2, is_active=True),
        Currency(currency_id=2, currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_base_currency=False, decimal_places=2, is_active=True),
        ExchangeRate(rate_id=1, currency_id=2, commercial_rate=50.0, customs_rate=50.0, effective_date=date(2020, 1, 1), is_active=True),
    ])
    session.commit()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=test_engine)


class TestShippingScenariosBackend:
    """
    Unit tests for BP-007 Shipping Scenarios Evaluation Engine
    """

    def test_create_shipping_evaluation_service(self, db: Session):
        crd = date.today() + timedelta(days=5)
        item1 = ShippingScenarioItemCreate(
            provider_name="COSCO Shipping",
            vessel_name="COSCO UNIVERSE",
            voyage_number="101E",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=22),
            expected_line_delay_days=2,
            is_recommended=True,
            risk_level="Low",
        )
        item2 = ShippingScenarioItemCreate(
            provider_name="Maersk Line",
            vessel_name="MAERSK MC-KINNEY",
            voyage_number="202W",
            sailing_date=crd + timedelta(days=4),
            estimated_arrival_date=crd + timedelta(days=28),
            expected_line_delay_days=3,
            is_recommended=False,
            risk_level="Medium",
        )

        payload = ShippingEvaluationCreate(
            title="Shanghai to Alexandria Transit Study",
            cargo_ready_date=crd,
            avg_form4_days=5,
            avg_clearance_days=7,
            items=[item1, item2],
        )

        res = ShippingScenarioService.create_session_service(db, payload)

        assert res.session_id is not None
        assert res.session_code.startswith("SCE-")
        assert len(res.items) == 2

        # Item 1 calculations check:
        # Lead time = 20 days (sailing +2 -> arrival +22)
        # Ready days = 2 days
        # Total warehouse days = 20 (vessel) + 2 (ready) + 5 (form4) + 7 (clearance) + 2 (delay) = 36 days
        assert res.items[0].vessel_lead_time_days == 20
        assert res.items[0].ready_for_shipping_days == 2
        assert res.items[0].expected_total_days_to_warehouse == 36
        assert res.items[0].expected_warehouse_arrival_date == crd + timedelta(days=36)

        # Item 2 calculations check:
        # Lead time = 24 days (sailing +4 -> arrival +28)
        # Ready days = 4 days
        # Total warehouse days = 24 + 4 + 5 + 7 + 3 = 43 days
        assert res.items[1].vessel_lead_time_days == 24
        assert res.items[1].ready_for_shipping_days == 4
        assert res.items[1].expected_total_days_to_warehouse == 43

        # Summary averages check:
        # Avg transit days = (36 + 43) / 2 = 39.5 days
        assert res.avg_expected_transit_days == 39.5
        assert res.earliest_arrival_scenario_provider == "COSCO Shipping"
        assert res.latest_arrival_scenario_provider == "Maersk Line"
        assert res.recommended_scenario_provider == "COSCO Shipping (COSCO UNIVERSE)"

    def test_exclusion_of_outlier_scenarios_from_average(self, db: Session):
        crd = date.today()
        item1 = ShippingScenarioItemCreate(
            provider_name="Fast Carrier",
            vessel_name="FAST-01",
            sailing_date=crd,
            estimated_arrival_date=crd + timedelta(days=10),
            expected_line_delay_days=0,
            is_excluded_from_average=False,
        )
        item2 = ShippingScenarioItemCreate(
            provider_name="Outlier Delayed Carrier",
            vessel_name="SLOW-99",
            sailing_date=crd + timedelta(days=20),
            estimated_arrival_date=crd + timedelta(days=100),
            expected_line_delay_days=15,
            is_excluded_from_average=True,  # Excluded from average calculation
        )

        payload = ShippingEvaluationCreate(
            title="Outlier Exclusion Test",
            cargo_ready_date=crd,
            avg_form4_days=5,
            avg_clearance_days=5,
            items=[item1, item2],
        )

        res = ShippingScenarioService.create_session_service(db, payload)

        assert len(res.items) == 2
        # Only item1 total days (10 + 0 + 5 + 5 + 0 = 20) should be included in average
        assert res.avg_expected_transit_days == 20.0

    def test_invalid_sailing_date_before_crd_raises_error(self, db: Session):
        crd = date.today() + timedelta(days=10)
        invalid_item = ShippingScenarioItemCreate(
            provider_name="Invalid Carrier",
            vessel_name="PAST-01",
            sailing_date=crd - timedelta(days=2),  # Before CRD!
            estimated_arrival_date=crd + timedelta(days=15),
        )

        payload = ShippingEvaluationCreate(
            title="Invalid Date Study",
            cargo_ready_date=crd,
            items=[invalid_item],
        )

        with pytest.raises(HTTPException) as exc_info:
            ShippingScenarioService.create_session_service(db, payload)

        assert exc_info.value.status_code == 400
        assert "cannot be before Cargo Ready Date" in exc_info.value.detail

    def test_invalid_eta_before_sailing_date_raises_error(self, db: Session):
        crd = date.today()
        invalid_item = ShippingScenarioItemCreate(
            provider_name="Time Travel Line",
            vessel_name="TIME-01",
            sailing_date=crd + timedelta(days=5),
            estimated_arrival_date=crd + timedelta(days=3),  # ETA before sailing!
        )

        payload = ShippingEvaluationCreate(
            title="Time Travel Study",
            cargo_ready_date=crd,
            items=[invalid_item],
        )

        with pytest.raises(HTTPException) as exc_info:
            ShippingScenarioService.create_session_service(db, payload)

        assert exc_info.value.status_code == 400
        assert "Estimated Arrival Date (ETA) must be after Sailing Date" in exc_info.value.detail

    def test_duplicate_carrier_option_raises_error(self, db: Session):
        crd = date.today()
        sailing = crd + timedelta(days=2)
        eta = crd + timedelta(days=20)
        item1 = ShippingScenarioItemCreate(
            provider_id=1,
            provider_name="COSCO",
            vessel_name="VESSEL A",
            sailing_date=sailing,
            estimated_arrival_date=eta,
        )
        item2 = ShippingScenarioItemCreate(
            provider_id=1,
            provider_name="COSCO",
            vessel_name="VESSEL A",
            sailing_date=sailing,
            estimated_arrival_date=eta,
        )

        payload = ShippingEvaluationCreate(
            title="Duplicate Option Study",
            cargo_ready_date=crd,
            items=[item1, item2],
        )

        with pytest.raises(HTTPException) as exc_info:
            ShippingScenarioService.create_session_service(db, payload)

        assert exc_info.value.status_code == 400
        assert "Duplicate shipping option found" in exc_info.value.detail

        # Allowed if provider_id is different (different freight forwarder offering same shipping line option)
        item3 = ShippingScenarioItemCreate(
            provider_id=2,
            provider_name="COSCO",
            vessel_name="VESSEL A",
            sailing_date=sailing,
            estimated_arrival_date=eta,
        )
        payload2 = ShippingEvaluationCreate(
            title="Allowed Non-Duplicate Study",
            cargo_ready_date=crd,
            items=[item1, item3],
        )
        sess = ShippingScenarioService.create_session_service(db, payload2)
        assert sess is not None

    def test_list_and_update_shipping_evaluation(self, db: Session):
        crd = date.today()
        payload = ShippingEvaluationCreate(
            title="Initial Study",
            cargo_ready_date=crd,
            items=[
                ShippingScenarioItemCreate(
                    provider_name="Line A",
                    vessel_name="Vessel 1",
                    sailing_date=crd + timedelta(days=1),
                    estimated_arrival_date=crd + timedelta(days=15),
                )
            ],
        )
        created = ShippingScenarioService.create_session_service(db, payload)

        # List check
        sessions = ShippingScenarioService.list_sessions_service(db, search="Initial")
        assert len(sessions) == 1
        assert sessions[0].session_id == created.session_id

        # Update check
        update_payload = ShippingEvaluationUpdate(
            title="Updated Study Title",
            avg_form4_days=8,
        )
        updated = ShippingScenarioService.update_session_service(
            db, created.session_id, update_payload
        )
        assert updated.title == "Updated Study Title"
        assert updated.avg_form4_days == 8

    def test_soft_delete_and_restore_shipping_evaluation(self, db: Session):
        crd = date.today()
        payload = ShippingEvaluationCreate(
            title="Delete Restore Study",
            cargo_ready_date=crd,
        )
        created = ShippingScenarioService.create_session_service(db, payload)

        # Soft delete
        del_res = ShippingScenarioService.soft_delete_service(db, created.session_id)
        assert "deactivated successfully" in del_res["message"]

        # Listed active only should not return it
        active_list = ShippingScenarioService.list_sessions_service(db, include_inactive=False)
        assert not any(s.session_id == created.session_id for s in active_list)

        # Restore
        restored = ShippingScenarioService.restore_service(db, created.session_id)
        assert restored.is_active is True

    def test_link_shipping_evaluation_to_import_file(self, db: Session):
        from modules.import_files.model import ImportFile
        # Seed an import file record
        imp_file = ImportFile(
            import_file_code="IMP-2026-9999",
            company_name="Test Company",
            supplier_name="Test Supplier",
            shipment_mode="Sea",
            incoterm_code="FOB",
            priority="High",
            shipment_category="New Purchase",
        )
        db.add(imp_file)
        db.commit()
        db.refresh(imp_file)

        crd = date.today()
        payload = ShippingEvaluationCreate(
            title="Linked Study Test",
            cargo_ready_date=crd,
            import_file_id=imp_file.import_file_id,
            items=[
                ShippingScenarioItemCreate(
                    provider_name="Linked Carrier",
                    vessel_name="Vessel Link",
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=12),
                    is_recommended=True,
                )
            ],
        )

        res = ShippingScenarioService.create_session_service(db, payload)
        assert res.import_file_id == imp_file.import_file_id
        assert res.import_file_code == "IMP-2026-9999"

        # Check that ImportFile.selected_scenario was updated to the recommended provider
        db.refresh(imp_file)
        assert imp_file.selected_scenario == "Linked Carrier (Vessel Link)"

    def test_quotation_breakdown_with_dthc_and_storage(self, db: Session):
        crd = date.today()
        item = ShippingScenarioItemCreate(
            provider_name="Hapag-Lloyd",
            vessel_name="AL JASRAH",
            sailing_date=crd + timedelta(days=3),
            estimated_arrival_date=crd + timedelta(days=20),
            free_time_days=21,
            quotation_currency="USD",
            total_quotation_amount=2450.0,
            dthc_applicable=True,
            dthc_price=350.0,
            dthc_currency="USD",
            storage_per_week_applicable=True,
            storage_per_week_price=120.0,
            storage_per_week_currency="USD",
            extra_day_storage_applicable=True,
            extra_day_storage_price=30.0,
            extra_day_storage_currency="USD",
        )
        payload = ShippingEvaluationCreate(
            title="Quotation Study with DTHC and Storage",
            cargo_ready_date=crd,
            items=[item],
        )

        res = ShippingScenarioService.create_session_service(db, payload)
        assert len(res.items) == 1
        created_item = res.items[0]
        assert created_item.dthc_applicable is True
        assert created_item.dthc_price == 350.0
        assert created_item.dthc_currency == "USD"
        assert created_item.storage_per_week_applicable is True
        assert created_item.storage_per_week_price == 120.0
        assert created_item.storage_per_week_currency == "USD"
        assert created_item.extra_day_storage_applicable is True
        assert created_item.extra_day_storage_price == 30.0
        assert created_item.extra_day_storage_currency == "USD"

    def test_soft_delete_and_update_reactivates_study(self, db: Session):
        crd = date.today() + timedelta(days=2)
        item = ShippingScenarioItemCreate(
            provider_name="ONE Line",
            vessel_name="ONE APUS",
            sailing_date=crd + timedelta(days=3),
            estimated_arrival_date=crd + timedelta(days=25),
        )
        payload = ShippingEvaluationCreate(
            title="Study to be soft deleted and reactivated on edit",
            cargo_ready_date=crd,
            items=[item],
        )

        session_res = ShippingScenarioService.create_session_service(db, payload)
        session_id = session_res.session_id
        assert session_res.is_active is True

        # Soft delete the session
        ShippingScenarioService.soft_delete_service(db, session_id)
        get_res = ShippingScenarioService.get_session_service(db, session_id)
        assert get_res.is_active is False

        # User clicks Edit in UI and saves modifications -> must be reactivated (is_active = True)
        update_payload = ShippingEvaluationUpdate(
            title="Updated Reactivated Study",
            items=[
                ShippingScenarioItemCreate(
                    provider_name="ONE Line Updated",
                    vessel_name="ONE APUS v2",
                    sailing_date=crd + timedelta(days=4),
                    estimated_arrival_date=crd + timedelta(days=26),
                    free_time_days=21,
                    container_40ft_applicable=True,
                    container_40ft_price=3200.0,
                    container_40ft_qty=1,
                    total_quotation_amount=3200.0,
                )
            ],
        )
        updated_res = ShippingScenarioService.update_session_service(db, session_id, update_payload)
        assert updated_res.is_active is True
        assert updated_res.title == "Updated Reactivated Study"
        assert len(updated_res.items) == 1
        assert updated_res.items[0].provider_name == "ONE Line Updated"
        assert updated_res.items[0].vessel_name == "ONE APUS v2"
        assert updated_res.items[0].free_time_days == 21
        assert updated_res.items[0].total_quotation_amount == 3200.0

    def test_clone_shipping_evaluation(self, db: Session):
        crd = date.today() + timedelta(days=3)
        item = ShippingScenarioItemCreate(
            provider_name="Hapag-Lloyd",
            vessel_name="AL DAHNA EXPRESS",
            voyage_number="303S",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=24),
            expected_line_delay_days=1,
            is_recommended=True,
            is_selected=True,
            total_quotation_amount=4500.0,
            free_time_days=21,
            container_40ft_applicable=True,
            container_40ft_price=4500.0,
            container_40ft_qty=1,
        )
        payload = ShippingEvaluationCreate(
            title="Mediterranean Fast Express Study",
            cargo_ready_date=crd,
            avg_form4_days=4,
            avg_clearance_days=6,
            items=[item],
        )
        source_session = ShippingScenarioService.create_session_service(db, payload)
        source_id = source_session.session_id

        # Execute clone
        clone_req = CloneShippingEvaluationRequest(
            new_title="Mediterranean Fast Express Cloned Study",
            remarks="Cloned for alternative port comparison",
            unlink_import_file=True,
            unlink_po=True,
            copy_carrier_options=True,
        )
        cloned_res = ShippingScenarioService.clone_session_service(db, source_id, clone_req)

        assert cloned_res.session_id != source_id
        assert cloned_res.session_code != source_session.session_code
        assert cloned_res.session_code.startswith("SCE-")
        assert cloned_res.title == "Mediterranean Fast Express Cloned Study"
        # Default clone title: language-independent English suffix
        default_clone = ShippingScenarioService.clone_session_service(db, source_id, CloneShippingEvaluationRequest())
        assert default_clone.title == "Mediterranean Fast Express Study (Copy)"
        assert cloned_res.import_file_id is None
        assert cloned_res.po_id is None
        assert "[Clone Note]: Cloned for alternative port comparison" in cloned_res.notes
        assert len(cloned_res.items) == 1
        cloned_item = cloned_res.items[0]
        assert cloned_item.provider_name == "Hapag-Lloyd"
        assert cloned_item.vessel_name == "AL DAHNA EXPRESS"
        assert cloned_item.total_quotation_amount == 4500.0
        assert cloned_item.free_time_days == 21
        # Crucial invariants: recommended and selected must be reset
        assert cloned_item.is_recommended is False
        assert cloned_item.is_selected is False

    def test_server_computes_totals(self, db: Session):
        crd = date.today() + timedelta(days=5)
        item = ShippingScenarioItemCreate(
            provider_name="Maersk Line",
            vessel_name="MAERSK MC-KINNEY",
            voyage_number="202W",
            sailing_date=crd + timedelta(days=4),
            estimated_arrival_date=crd + timedelta(days=28),
            quotation_currency="USD",
            container_40ft_applicable=True,
            container_40ft_price=2000.0,
            container_40ft_qty=2,
            container_40ft_currency="USD",
            solas_vgm_applicable=True,
            solas_vgm_price=25.0,
            solas_vgm_currency="USD",
            clearance_fee_applicable=True,
            clearance_fee_price=15000.0,
            clearance_fee_currency="EGP",
            insurance_applicable=True,
            insurance_price=100.0,
            insurance_currency="USD",
        )
        payload = ShippingEvaluationCreate(
            title="Server Totals Calculation Test",
            cargo_ready_date=crd,
            items=[item],
        )
        created = ShippingScenarioService.create_session_service(db, payload)
        assert len(created.items) == 1
        calc_item = created.items[0]
        # Freight = 2 * 2000 = 4000.0 USD
        assert calc_item.freight_total_amount == 4000.0
        # SOLAS = 25 * 2 = 50.0 USD; Clearance = 15000 / 50 = 300.0 USD; Insurance = 100.0 USD
        # Total = 4000 + 50 + 300 + 100 = 4450.0 USD
        assert calc_item.total_quotation_amount == 4450.0
        assert calc_item.totals_rate_date is not None

    def test_client_total_ignored(self, db: Session):
        crd = date.today() + timedelta(days=5)
        item = ShippingScenarioItemCreate(
            provider_name="COSCO Shipping",
            vessel_name="COSCO UNIVERSE",
            voyage_number="101E",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=22),
            quotation_currency="USD",
            container_40ft_applicable=True,
            container_40ft_price=2000.0,
            container_40ft_qty=2,
            container_40ft_currency="USD",
            total_quotation_amount=999999.0,  # Untrusted client total
        )
        payload = ShippingEvaluationCreate(
            title="Client Total Ignored Test",
            cargo_ready_date=crd,
            items=[item],
        )
        created = ShippingScenarioService.create_session_service(db, payload)
        assert created.items[0].total_quotation_amount == 4000.0
        assert created.items[0].freight_total_amount == 4000.0

        # Also test on update: client passes forged total_quotation_amount
        update_item = ShippingScenarioItemCreate(
            provider_name="COSCO Shipping",
            vessel_name="COSCO UNIVERSE",
            voyage_number="101E",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=22),
            quotation_currency="USD",
            container_40ft_applicable=True,
            container_40ft_price=2000.0,
            container_40ft_qty=1,
            container_40ft_currency="USD",
            total_quotation_amount=777777.0,
        )
        updated = ShippingScenarioService.update_session_service(
            db, created.session_id, ShippingEvaluationUpdate(items=[update_item])
        )
        assert updated.items[0].total_quotation_amount == 2000.0
        assert updated.items[0].freight_total_amount == 2000.0

    def test_missing_rate_409(self, db: Session):
        crd = date.today() + timedelta(days=5)
        item = ShippingScenarioItemCreate(
            provider_name="Hapag-Lloyd",
            vessel_name="AL DAHNA EXPRESS",
            voyage_number="303S",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=24),
            quotation_currency="USD",
            clearance_fee_applicable=True,
            clearance_fee_price=1000.0,
            clearance_fee_currency="EUR",  # EUR has no rate seeded in DB
        )
        payload = ShippingEvaluationCreate(
            title="Missing Rate 409 Test",
            cargo_ready_date=crd,
            items=[item],
        )
        with pytest.raises(HTTPException) as exc_info:
            ShippingScenarioService.create_session_service(db, payload)
        assert exc_info.value.status_code == 409
        detail = exc_info.value.detail
        assert isinstance(detail, dict)
        assert detail.get("code") == "SS_FX_RATE_MISSING"
        assert detail.get("currency") == "EUR"





