"""
Unit Tests for Freight Quotations Module (BP-008)
"""

import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.transport_locations.model import TransportLocation
from modules.freight_quotations.schemas import (
    FreightRFQRequestCreate,
    FreightRFQRequestUpdate,
    FreightQuotationItemCreate,
)
from modules.freight_quotations.service import FreightQuotationService


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()

    # Seed active currency
    from modules.currencies.model import Currency
    usd = Currency(
        currency_code="USD",
        currency_name="US Dollar",
        currency_symbol="$",
        is_active=True,
    )
    db.add(usd)

    # Seed carrier partners
    c1 = ExternalServiceProvider(
        partner_code="ESP-000003",
        partner_name="Maersk Line Shipping",
        partner_type="Shipping Line",
        is_active=True,
    )
    c2 = ExternalServiceProvider(
        partner_code="ESP-000004",
        partner_name="MSC Shipping",
        partner_type="Shipping Line",
        is_active=True,
    )
    db.add_all([c1, c2])
    db.commit()

    yield db
    db.close()


class TestFreightQuotationsBackend:

    def test_create_rfq_service(self, db_session):
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 9, 1)

        rfq_in = FreightRFQRequestCreate(
            title="طلب عرض سعر FCL من نينغبو إلى الإسكندرية",
            shipping_method="Ocean FCL",
            crd_date=crd,
            pol_name="Ningbo Port",
            pod_name="Alexandria Port",
            total_cbm=65.0,
            total_gross_weight_kg=22000.0,
            chargeable_weight_kg=22000.0,
            quotations=[
                FreightQuotationItemCreate(
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    vessel_name="MAERSK KINLOSS",
                    ocean_freight_cost=2800.0,
                    local_charges_cost=350.0,
                    inland_cost=200.0,
                    currency_code="USD",
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=26),
                    free_days_at_pod=14,
                ),
                FreightQuotationItemCreate(
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    vessel_name="MSC OSCAR",
                    ocean_freight_cost=2600.0,
                    local_charges_cost=400.0,
                    inland_cost=250.0,
                    currency_code="USD",
                    sailing_date=crd + timedelta(days=6),
                    estimated_arrival_date=crd + timedelta(days=32),
                    free_days_at_pod=21,
                ),
            ],
        )

        res = FreightQuotationService.create_rfq(db_session, rfq_in)
        assert res.rfq_id is not None
        assert res.rfq_code.startswith("RFQ-")
        assert res.total_quotations_count == 2
        assert res.lowest_freight_cost == 3250.0  # 2600+400+250
        assert res.average_freight_cost == 3300.0  # (3350 + 3250)/2
        assert res.fastest_transit_days == 23

    def test_award_quotation_service(self, db_session):
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 9, 1)

        rfq_in = FreightRFQRequestCreate(
            title="طلب سعر للاعتماد",
            shipping_method="Ocean FCL",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Sokhna",
            quotations=[
                FreightQuotationItemCreate(
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3000.0,
                    currency_code="USD",
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                )
            ],
        )

        created = FreightQuotationService.create_rfq(db_session, rfq_in)
        q_id = created.quotations[0].quotation_id

        awarded = FreightQuotationService.award_quotation(db_session, created.rfq_id, q_id)
        assert awarded.status == "Awarded"
        assert awarded.selected_quotation_id == q_id
        assert awarded.awarded_provider_name == carriers[0].partner_name

    def test_sailing_date_before_crd_raises_error(self, db_session):
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 9, 10)

        rfq_in = FreightRFQRequestCreate(
            title="طلب بتاريخ غير صالح",
            shipping_method="Ocean FCL",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=2000.0,
                    sailing_date=crd - timedelta(days=2),  # invalid sailing before CRD
                    estimated_arrival_date=crd + timedelta(days=20),
                )
            ],
        )

        with pytest.raises(Exception) as exc_info:
            FreightQuotationService.create_rfq(db_session, rfq_in)
        assert "Sailing date" in str(exc_info.value)

    def test_soft_delete_and_restore(self, db_session):
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 9, 10)

        rfq_in = FreightRFQRequestCreate(
            title="طلب للحذف والاستعادة",
            shipping_method="Air Freight",
            crd_date=crd,
            pol_name="Shanghai Airport",
            pod_name="Cairo Airport",
        )

        created = FreightQuotationService.create_rfq(db_session, rfq_in)
        deleted = FreightQuotationService.soft_delete_rfq(db_session, created.rfq_id)
        assert deleted.is_active is False

        restored = FreightQuotationService.restore_rfq(db_session, created.rfq_id)
        assert restored.is_active is True

    def test_evaluate_and_rank_rfq_quotes_breakdown(self, db_session):
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 9, 10)

        rfq_in = FreightRFQRequestCreate(
            title="مقارنة وتقييم عروض شحن",
            shipping_method="Ocean FCL",
            crd_date=crd,
            pol_name="Ningbo",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=2500.0,
                    currency_code="USD",
                    free_days_at_pod=21,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=25),
                ),
                FreightQuotationItemCreate(
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=3000.0,
                    currency_code="USD",
                    free_days_at_pod=14,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=28),
                ),
            ],
        )

        rfq = FreightQuotationService.create_rfq(db_session, rfq_in)
        benchmark = FreightQuotationService.evaluate_and_rank_rfq_quotes(db_session, rfq.rfq_id)
        assert benchmark.rfq_id == rfq.rfq_id
        assert len(benchmark.all_ranked_quotes) == 2
        
        winner = benchmark.all_ranked_quotes[0]
        assert winner.rank == 1
        assert winner.cost_score == 50.0  # lowest cost gets full 50 points
        assert winner.free_days_score > 0.0
        assert winner.transit_score > 0.0
        assert winner.reliability_score > 0.0
        assert winner.composite_score == round(
            winner.cost_score + winner.free_days_score + winner.transit_score + winner.reliability_score, 1
        )
