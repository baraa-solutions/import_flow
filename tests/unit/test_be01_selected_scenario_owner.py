"""
Test BE01-T22: One owner for import_files.selected_scenario, ports by ID, and clear on soft delete.
"""
from datetime import date, timedelta
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.import_files.model import ImportFile
from modules.external_service_providers.model import ExternalServiceProvider
from modules.shipping_scenarios.model import ShippingEvaluationSession, ShippingScenarioItem
from modules.shipping_scenarios.service import ShippingScenarioService
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.freight_quotations.service import FreightQuotationService
from modules.freight_quotations.schemas import FreightRFQRequestCreate, FreightQuotationItemCreate


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_be01_t22_shipping_scenario_clears_on_delete(db_session):
    # 1. Setup file
    file = ImportFile(
        import_file_code="IMP-2026-SCEN",
        company_name="Test Company",
        supplier_name="Test Supplier",
        selected_scenario="Maersk Recommended",
        owner="test_user",
        status="Active",
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    # 2. Setup session
    session_obj = ShippingEvaluationSession(
        session_code="SCE-2026-001",
        title="Test Study",
        import_file_id=file.import_file_id,
        is_active=True,
    )
    db_session.add(session_obj)
    db_session.commit()

    # 3. Soft delete session
    ShippingScenarioService.soft_delete_service(db_session, session_obj.session_id, user="admin")
    db_session.refresh(file)

    # Assert selected_scenario is cleared on soft delete
    assert file.selected_scenario is None


def test_be01_t22_rfq_award_and_clear_on_delete(db_session):
    carrier = ExternalServiceProvider(
        partner_code="HL-001",
        partner_name="Hapag-Lloyd",
        partner_type="Shipping Line",
        is_active=True,
    )
    db_session.add(carrier)
    db_session.commit()

    file = ImportFile(
        import_file_code="IMP-2026-RFQ",
        company_name="Test Company",
        supplier_name="Test Supplier",
        owner="test_user",
        status="Active",
    )
    db_session.add(file)
    db_session.commit()
    db_session.refresh(file)

    from modules.currencies.model import Currency
    usd = Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    db_session.add(usd)
    db_session.commit()

    crd = date.today()
    rfq_in = FreightRFQRequestCreate(
        title="RFQ Test",
        shipping_method="Ocean FCL",
        import_file_id=file.import_file_id,
        crd_date=crd,
        pol_name="Shanghai",
        pod_name="Alexandria",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=carrier.provider_id,
                provider_name=carrier.partner_name,
                ocean_freight_cost=1500.0,
                currency_code="USD",
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=20),
                free_days_at_pod=14,
            )
        ],
    )
    rfq = FreightQuotationService.create_rfq(db_session, rfq_in)
    quote_id = rfq.quotations[0].quotation_id

    # Award the quotation
    FreightQuotationService.award_quotation(db_session, rfq.rfq_id, quote_id, user="test_user")
    db_session.refresh(file)

    assert "Hapag-Lloyd" in file.selected_scenario
    assert file.target_free_days == 14
    assert file.port_of_loading == "Shanghai"
    assert file.port_of_discharge == "Alexandria"

    # Soft delete RFQ
    FreightQuotationService.soft_delete_rfq(db_session, rfq.rfq_id, user="admin")
    db_session.refresh(file)

    # Assert selected_scenario is cleared on soft delete of the owning RFQ
    assert file.selected_scenario is None
