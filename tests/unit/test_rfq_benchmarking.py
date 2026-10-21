import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi.testclient import TestClient

import main
from database.database import Base, get_db
from modules.external_service_providers.model import ExternalServiceProvider
from modules.freight_quotations.schemas import (
    FreightRFQRequestCreate,
    FreightQuotationItemCreate,
)
from modules.freight_quotations.service import FreightQuotationService


SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        # Money fields need an active currency in master data (currency required when a value is entered).
        from modules.currencies.model import Currency as _Currency
        for _code in ("USD", "EGP", "EUR"):
            if not db.query(_Currency).filter_by(currency_code=_code).first():
                db.add(_Currency(currency_code=_code, currency_name=_code, currency_symbol=_code, is_active=True))
        db.commit()
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    main.app.dependency_overrides[get_db] = override_get_db
    test_client = TestClient(main.app)
    yield test_client
    main.app.dependency_overrides.clear()


class TestFreightRFQBenchmarking:
    """
    Tests for AI-BENCH-007: Trade-Lane Forwarder Benchmarking & Top 3 Ranking.
    """

    def test_rfq_benchmarking_and_ranking(self, db_session):
        # 1. Create 5 Freight Forwarders
        forwarders = []
        for i in range(1, 6):
            p = ExternalServiceProvider(
                partner_code=f"FWD-00{i}",
                partner_name=f"Forwarder Logistics #{i}",
                partner_type="Freight Forwarder",
            )
            db_session.add(p)
            forwarders.append(p)
        db_session.commit()
        for p in forwarders:
            db_session.refresh(p)

        # 2. Create RFQ with 5 competing quotes
        sailing = date.today() + timedelta(days=5)
        arrival = sailing + timedelta(days=14)

        quotes = [
            FreightQuotationItemCreate(
                currency_code="USD",
                provider_id=forwarders[0].provider_id,
                provider_name=forwarders[0].partner_name,
                ocean_freight_cost=2500.0,
                local_charges_cost=300.0,
                total_cost=2800.0,
                transit_days=16,
                free_days_at_pod=14,
                sailing_date=sailing,
                estimated_arrival_date=arrival,
            ),
            FreightQuotationItemCreate(
                currency_code="USD",
                provider_id=forwarders[1].provider_id,
                provider_name=forwarders[1].partner_name,
                ocean_freight_cost=2600.0,
                local_charges_cost=300.0,
                total_cost=2900.0,
                transit_days=13,
                free_days_at_pod=21,  # Best free days
                sailing_date=sailing,
                estimated_arrival_date=arrival,
            ),
            FreightQuotationItemCreate(
                currency_code="USD",
                provider_id=forwarders[2].provider_id,
                provider_name=forwarders[2].partner_name,
                ocean_freight_cost=2400.0,
                local_charges_cost=300.0,
                total_cost=2700.0,  # Best price
                transit_days=18,
                free_days_at_pod=14,
                sailing_date=sailing,
                estimated_arrival_date=arrival,
            ),
            FreightQuotationItemCreate(
                currency_code="USD",
                provider_id=forwarders[3].provider_id,
                provider_name=forwarders[3].partner_name,
                ocean_freight_cost=3400.0,
                local_charges_cost=400.0,
                total_cost=3800.0,
                transit_days=12,  # Fastest transit
                free_days_at_pod=14,
                sailing_date=sailing,
                estimated_arrival_date=arrival,
            ),
            FreightQuotationItemCreate(
                currency_code="USD",
                provider_id=forwarders[4].provider_id,
                provider_name=forwarders[4].partner_name,
                ocean_freight_cost=4000.0,
                local_charges_cost=500.0,
                total_cost=4500.0,  # Worst price
                transit_days=22,
                free_days_at_pod=7,
                sailing_date=sailing,
                estimated_arrival_date=arrival,
            ),
        ]

        rfq_resp = FreightQuotationService.create_rfq(
            db_session,
            FreightRFQRequestCreate(
                title="Genoa to Alexandria 40HQ Benchmark",
                shipping_method="Ocean FCL",
                crd_date=date.today() + timedelta(days=3),
                pol_name="Genoa Port, Italy",
                pod_name="Alexandria Port, Egypt",
                quotations=quotes,
            ),
        )

        # 3. Run Benchmark Service
        benchmark = FreightQuotationService.evaluate_and_rank_rfq_quotes(db_session, rfq_resp.rfq_id)
        assert benchmark.total_quotes_analyzed == 5
        assert len(benchmark.all_ranked_quotes) == 5
        assert len(benchmark.top_three_quotes) == 3

        # Verify Rank 1, 2, 3 have descending composite scores
        assert benchmark.top_three_quotes[0].rank == 1
        assert benchmark.top_three_quotes[1].rank == 2
        assert benchmark.top_three_quotes[2].rank == 3
        assert benchmark.top_three_quotes[0].composite_score >= benchmark.top_three_quotes[1].composite_score
        assert benchmark.top_three_quotes[1].composite_score >= benchmark.top_three_quotes[2].composite_score

        # The worst price ($4,500) must NOT be in top 3
        top_providers = [q.provider_name for q in benchmark.top_three_quotes]
        assert forwarders[4].partner_name not in top_providers

        # Verify Executive Recommendation
        assert "التوصية التنفيذية للاعتماد" in benchmark.executive_recommendation_ar
        assert "Genoa Port, Italy ──> Alexandria Port, Egypt" in benchmark.route

    def test_api_benchmark_endpoint(self, client, db_session):
        # Create Provider
        p = ExternalServiceProvider(
            partner_code="FWD-API-01",
            partner_name="Kuehne+Nagel Egypt",
            partner_type="Freight Forwarder",
        )
        db_session.add(p)
        db_session.commit()
        db_session.refresh(p)

        # Create RFQ
        sailing = date.today() + timedelta(days=5)
        rfq_resp = FreightQuotationService.create_rfq(
            db_session,
            FreightRFQRequestCreate(
                title="Shanghai to Damietta Benchmark",
                shipping_method="Ocean FCL",
                crd_date=date.today() + timedelta(days=3),
                pol_name="Shanghai Port",
                pod_name="Damietta Port",
                quotations=[
                    FreightQuotationItemCreate(
                        currency_code="USD",
                        provider_id=p.provider_id,
                        provider_name=p.partner_name,
                        ocean_freight_cost=3100.0,
                        total_cost=3100.0,
                        transit_days=25,
                        free_days_at_pod=14,
                        sailing_date=sailing,
                        estimated_arrival_date=sailing + timedelta(days=25),
                    )
                ],
            ),
        )

        # Test API
        resp = client.get(f"/api/v1/freight-quotations/{rfq_resp.rfq_id}/benchmark")
        assert resp.status_code == 200
        data = resp.json()
        assert data["rfq_id"] == rfq_resp.rfq_id
        assert data["total_quotes_analyzed"] == 1
        assert len(data["top_three_quotes"]) == 1
        assert data["top_three_quotes"][0]["rank"] == 1
        assert "Kuehne+Nagel Egypt" in data["top_three_quotes"][0]["provider_name"]
