"""
Tests for BE01-T18: Currency fields validated against the currency master (no invented defaults).

Verifies across the 4 Phase-01 modules:
- shipping_scenarios
- customs_consultation
- freight_quotations
- import_requirements
"""
from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.common.errors import CodedHTTPException
from modules.currencies.model import Currency
from modules.external_service_providers.model import ExternalServiceProvider
from modules.shipping_scenarios.schemas import (
    ShippingEvaluationCreate,
    ShippingScenarioItemCreate,
)
from modules.shipping_scenarios.service import ShippingScenarioService
from modules.customs_consultation.schemas import (
    ClearanceExpenseTypeCreate,
    BrokerPriceListCreate,
    BrokerPriceListItemCreate,
    CustomsBrokerQuoteItemCreate,
    CustomsConsultationCreate,
)
from modules.customs_consultation.service import (
    ClearanceExpenseTypeService,
    BrokerPriceListService,
    CustomsConsultationService,
)
from modules.freight_quotations.schemas import (
    FreightRFQRequestCreate,
    FreightQuotationItemCreate,
)
from modules.freight_quotations.service import FreightQuotationService
from modules.import_requirements.schemas import ImportRequirementCreate
from modules.import_requirements.service import create_assessment_service


@pytest.fixture
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(autocommit=False, autoflush=False, bind=engine)()

    # Master Currencies
    session.add_all([
        Currency(currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True),
        Currency(currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True),
        Currency(currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="E£", is_active=True),
        Currency(currency_code="GBP", currency_name="British Pound", currency_symbol="£", is_active=False),  # Inactive
    ])

    # External Service Providers
    session.add_all([
        ExternalServiceProvider(
            provider_id=1,
            partner_code="FF-001",
            partner_name="COSCO Shipping",
            partner_type="Freight Forwarder",
            is_active=True,
        ),
        ExternalServiceProvider(
            provider_id=2,
            partner_code="CB-001",
            partner_name="Alexandria Customs Broker",
            partner_type="Customs Broker",
            is_active=True,
        ),
    ])
    session.commit()

    try:
        yield session
    finally:
        session.close()
        engine.dispose()


# ==============================================================================
# 1. Shipping Scenarios Currency Validation
# ==============================================================================

class TestShippingScenariosCurrencyValidation:

    def test_scenario_price_without_currency_raises_400(self, db):
        crd = date.today() + timedelta(days=5)
        item = ShippingScenarioItemCreate(
            provider_id=1,
            provider_name="COSCO Shipping",
            vessel_name="COSCO UNIVERSE",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=20),
            container_40ft_applicable=True,
            container_40ft_price=1200.0,
            container_40ft_currency=None,  # Missing currency
        )
        payload = ShippingEvaluationCreate(
            title="Scenario Missing Currency",
            cargo_ready_date=crd,
            items=[item],
        )
        with pytest.raises(HTTPException) as exc_info:
            ShippingScenarioService.create_session_service(db, payload)
        assert exc_info.value.status_code == 400
        assert "كود عملة حاوية 40 قدم مطلوب عند إدخال قيمة مالية" in exc_info.value.detail

    def test_scenario_lowercase_currency_normalized_to_uppercase(self, db):
        crd = date.today() + timedelta(days=5)
        item = ShippingScenarioItemCreate(
            provider_id=1,
            provider_name="COSCO Shipping",
            vessel_name="COSCO UNIVERSE",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=20),
            container_40ft_applicable=True,
            container_40ft_price=1200.0,
            container_40ft_currency="usd",  # Lowercase
        )
        payload = ShippingEvaluationCreate(
            title="Scenario Lowercase Currency",
            cargo_ready_date=crd,
            items=[item],
        )
        res = ShippingScenarioService.create_session_service(db, payload)
        assert res.items[0].container_40ft_currency == "USD"

    def test_scenario_unknown_currency_code_raises_400(self, db):
        crd = date.today() + timedelta(days=5)
        item = ShippingScenarioItemCreate(
            provider_id=1,
            provider_name="COSCO Shipping",
            vessel_name="COSCO UNIVERSE",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=20),
            container_40ft_applicable=True,
            container_40ft_price=1200.0,
            container_40ft_currency="XYZ",  # Nonexistent
        )
        payload = ShippingEvaluationCreate(
            title="Scenario Unknown Currency",
            cargo_ready_date=crd,
            items=[item],
        )
        with pytest.raises(CodedHTTPException) as exc_info:
            ShippingScenarioService.create_session_service(db, payload)
        assert exc_info.value.status_code == 400
        assert exc_info.value.code == "CURRENCY_CODE_UNKNOWN"

    def test_scenario_inactive_currency_code_raises_400(self, db):
        crd = date.today() + timedelta(days=5)
        item = ShippingScenarioItemCreate(
            provider_id=1,
            provider_name="COSCO Shipping",
            vessel_name="COSCO UNIVERSE",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=20),
            container_40ft_applicable=True,
            container_40ft_price=1200.0,
            container_40ft_currency="GBP",  # Inactive
        )
        payload = ShippingEvaluationCreate(
            title="Scenario Inactive Currency",
            cargo_ready_date=crd,
            items=[item],
        )
        with pytest.raises(CodedHTTPException) as exc_info:
            ShippingScenarioService.create_session_service(db, payload)
        assert exc_info.value.status_code == 400
        assert exc_info.value.code == "CURRENCY_CODE_UNKNOWN"

    def test_scenario_zero_price_allows_null_currency(self, db):
        crd = date.today() + timedelta(days=5)
        item = ShippingScenarioItemCreate(
            provider_id=1,
            provider_name="COSCO Shipping",
            vessel_name="COSCO UNIVERSE",
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=20),
            container_40ft_applicable=False,
            container_40ft_price=0.0,
            container_40ft_currency=None,
        )
        payload = ShippingEvaluationCreate(
            title="Scenario Zero Price Null Currency",
            cargo_ready_date=crd,
            items=[item],
        )
        res = ShippingScenarioService.create_session_service(db, payload)
        assert res.items[0].container_40ft_currency is None


# ==============================================================================
# 2. Customs Consultation Currency Validation
# ==============================================================================

class TestCustomsConsultationCurrencyValidation:

    def test_clearance_expense_type_unknown_default_currency_raises_400(self, db):
        payload = ClearanceExpenseTypeCreate(
            category="Clearance Fees",
            expense_name="Unloading Fee",
            name_ar="رسوم تفريغ",
            default_unit="PER_CONTAINER",
            default_currency="INVALID",
        )
        with pytest.raises(CodedHTTPException) as exc_info:
            ClearanceExpenseTypeService.create_expense_type(db, payload)
        assert exc_info.value.status_code == 400
        assert exc_info.value.code == "CURRENCY_CODE_UNKNOWN"

    def test_broker_price_list_item_missing_currency_raises_400(self, db):
        payload = BrokerPriceListCreate(
            title="Alexandria Tariff 2026",
            broker_id=2,
            broker_name="Alexandria Customs Broker",
            price_list_name="Alexandria Tariff 2026",
            effective_from=date.today(),
            items=[
                BrokerPriceListItemCreate(
                    category="Clearance Fees",
                    expense_name="Handling",
                    unit_type="Per Container",
                    standard_price=500.0,
                    currency=None,  # Missing currency
                )
            ],
        )
        with pytest.raises(HTTPException) as exc_info:
            BrokerPriceListService.create_price_list(db, payload)
        assert exc_info.value.status_code == 400
        assert "كود عملة بند قائمة الأسعار مطلوب عند إدخال قيمة مالية" in exc_info.value.detail

    def test_broker_price_list_item_currency_normalized(self, db):
        payload = BrokerPriceListCreate(
            title="Alexandria Tariff 2026",
            broker_id=2,
            broker_name="Alexandria Customs Broker",
            price_list_name="Alexandria Tariff 2026",
            effective_from=date.today(),
            items=[
                BrokerPriceListItemCreate(
                    category="Clearance Fees",
                    expense_name="Handling",
                    unit_type="Per Container",
                    standard_price=500.0,
                    currency="egp",  # Lowercase
                )
            ],
        )
        res = BrokerPriceListService.create_price_list(db, payload)
        assert res.items[0].currency == "EGP"

    def test_consultation_quote_item_missing_currency_raises_400(self, db):
        payload = CustomsConsultationCreate(
            title="Customs Consultation Missing Currency",
            broker_id=2,
            broker_quote_items=[
                CustomsBrokerQuoteItemCreate(
                    category="Clearance Fees",
                    expense_name="Customs Declaration",
                    unit_type="Per Invoice",
                    unit_price=1500.0,
                    currency=None,  # Missing currency
                    qty=1.0,
                )
            ],
        )
        with pytest.raises(HTTPException) as exc_info:
            CustomsConsultationService.create_consultation(db, payload)
        assert exc_info.value.status_code == 400
        assert "كود عملة بند عرض سعر المخلص مطلوب عند إدخال قيمة مالية" in exc_info.value.detail


# ==============================================================================
# 3. Freight Quotations Currency Validation
# ==============================================================================

class TestFreightQuotationsCurrencyValidation:

    def test_freight_rfq_item_missing_currency_raises_400(self, db):
        payload = FreightRFQRequestCreate(
            rfq_code="RFQ-2026-TEST",
            title="Freight RFQ Test",
            crd_date=date.today() + timedelta(days=10),
            shipment_mode="FCL",
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    provider_name="COSCO Shipping",
                    forwarder_name="COSCO Shipping",
                    sailing_date=date.today() + timedelta(days=12),
                    estimated_arrival_date=date.today() + timedelta(days=25),
                    provider_id=1,
                    ocean_freight_cost=2500.0,
                    currency_code=None,  # Missing currency
                )
            ],
        )
        with pytest.raises(HTTPException) as exc_info:
            FreightQuotationService.create_rfq(db, payload)
        assert exc_info.value.status_code == 400
        assert "كود عملة عرض الشحن مطلوب عند إدخال قيمة مالية" in exc_info.value.detail

    def test_freight_rfq_item_unknown_currency_raises_400(self, db):
        payload = FreightRFQRequestCreate(
            rfq_code="RFQ-2026-TEST2",
            title="Freight RFQ Unknown Currency",
            crd_date=date.today() + timedelta(days=10),
            shipment_mode="FCL",
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    provider_name="COSCO Shipping",
                    forwarder_name="COSCO Shipping",
                    sailing_date=date.today() + timedelta(days=12),
                    estimated_arrival_date=date.today() + timedelta(days=25),
                    provider_id=1,
                    ocean_freight_cost=2500.0,
                    currency_code="BAD",  # Unknown
                )
            ],
        )
        with pytest.raises(CodedHTTPException) as exc_info:
            FreightQuotationService.create_rfq(db, payload)
        assert exc_info.value.status_code == 400
        assert exc_info.value.code == "CURRENCY_CODE_UNKNOWN"

    def test_freight_rfq_item_currency_normalized(self, db):
        payload = FreightRFQRequestCreate(
            rfq_code="RFQ-2026-TEST3",
            title="Freight RFQ Normalized Currency",
            crd_date=date.today() + timedelta(days=10),
            shipment_mode="FCL",
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    provider_name="COSCO Shipping",
                    forwarder_name="COSCO Shipping",
                    sailing_date=date.today() + timedelta(days=12),
                    estimated_arrival_date=date.today() + timedelta(days=25),
                    provider_id=1,
                    ocean_freight_cost=2500.0,
                    currency_code="usd",  # Lowercase
                )
            ],
        )
        res = FreightQuotationService.create_rfq(db, payload)
        assert res.quotations[0].currency_code == "USD"


# ==============================================================================
# 4. Import Requirements Currency Validation
# ==============================================================================

class TestImportRequirementsCurrencyValidation:

    def test_import_requirement_missing_currency_raises_400(self, db):
        payload = ImportRequirementCreate(
            assessment_title="Chemical Product Assessment",
            hs_code="29011000",
            shipment_value=15000.0,
            currency=None,  # Missing currency
        )
        with pytest.raises(HTTPException) as exc_info:
            create_assessment_service(db, payload)
        assert exc_info.value.status_code == 400
        assert "كود عملة قيمة الشحنة مطلوب عند إدخال قيمة مالية" in exc_info.value.detail

    def test_import_requirement_unknown_currency_raises_400(self, db):
        payload = ImportRequirementCreate(
            assessment_title="Chemical Product Assessment",
            hs_code="29011000",
            shipment_value=15000.0,
            currency="FOO",  # Unknown
        )
        with pytest.raises(CodedHTTPException) as exc_info:
            create_assessment_service(db, payload)
        assert exc_info.value.status_code == 400
        assert exc_info.value.code == "CURRENCY_CODE_UNKNOWN"

    def test_import_requirement_currency_normalized(self, db):
        payload = ImportRequirementCreate(
            assessment_title="Chemical Product Assessment",
            hs_code="29011000",
            shipment_value=15000.0,
            currency="eur",  # Lowercase
        )
        res = create_assessment_service(db, payload)
        assert res.currency == "EUR"

    def test_import_requirement_zero_value_allows_null_currency(self, db):
        payload = ImportRequirementCreate(
            assessment_title="Zero Value Assessment",
            hs_code="29011000",
            shipment_value=0.0,
            currency=None,
        )
        res = create_assessment_service(db, payload)
        assert res.currency is None
