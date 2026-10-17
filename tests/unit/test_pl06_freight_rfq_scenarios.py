"""
Unit Tests for PL-06: Freight RFQ Scenarios (BP-008 & AI-BENCH-007)
Comprehensive automated test suite covering RFQ creation, auto-transit calculation,
AI-BENCH-007 multi-factor scoring, quotation awarding, bidirectional ImportFile sync,
and business validation guards.
"""

import pytest
from datetime import date, timedelta
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.purchase_orders.model import PurchaseOrder
from modules.projects.model import Project
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

    # Seed 3 carrier partners
    c1 = ExternalServiceProvider(
        partner_code="ESP-000001",
        partner_name="Maersk Line",
        partner_type="Shipping Line",
        is_active=True,
    )
    c2 = ExternalServiceProvider(
        partner_code="ESP-000002",
        partner_name="MSC Mediterranean Shipping",
        partner_type="Shipping Line",
        is_active=True,
    )
    c3 = ExternalServiceProvider(
        partner_code="ESP-000003",
        partner_name="CMA CGM",
        partner_type="Shipping Line",
        is_active=True,
    )
    db.add_all([c1, c2, c3])

    # Seed an ImportFile
    imp = ImportFile(
        import_file_code="IMP-2026-0001",
        company_name="SCAS Logistics Co.",
        supplier_name="Global Machinery Ltd.",
        status="Open",
        is_active=True,
    )
    db.add(imp)

    # Seed a Project
    proj = Project(
        project_code="PRJ-2026-001",
        project_name="Soundproof Acoustic Lines",
        project_owner="Ahmed",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        status="Active",
        is_active=True,
    )
    db.add(proj)
    db.flush()

    # Seed a Purchase Order
    po = PurchaseOrder(
        po_number="PO-2026-0001",
        proforma_invoice_number="PI-99001",
        project_id=proj.project_id,
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        currency_id=1,
        status="Approved",
        is_active=True,
    )
    db.add(po)

    db.commit()

    yield db
    db.close()


class TestPL06FreightRFQScenarios:

    def test_rfq_creation_and_metrics_calculation(self, db_session):
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="طلب عروض أسعار لنقل 3 حاويات خط إنتاج",
            shipping_method="Ocean FCL",
            crd_date=crd,
            pol_name="Ningbo Port (CN NGB)",
            pod_name="Alexandria Port (EG ALX)",
            total_cbm=120.0,
            total_gross_weight_kg=45000.0,
            chargeable_weight_kg=45000.0,
            quotations=[
                FreightQuotationItemCreate(
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    vessel_name="MAERSK MC-KINNEY",
                    ocean_freight_cost=3200.0,
                    local_charges_cost=450.0,
                    inland_cost=300.0,
                    sailing_date=crd + timedelta(days=4),
                    estimated_arrival_date=crd + timedelta(days=28),  # 24 days transit
                    free_days_at_pod=14,
                ),
                FreightQuotationItemCreate(
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    vessel_name="MSC GULSUN",
                    ocean_freight_cost=2900.0,
                    local_charges_cost=400.0,
                    inland_cost=250.0,
                    sailing_date=crd + timedelta(days=6),
                    estimated_arrival_date=crd + timedelta(days=26),  # 20 days transit
                    free_days_at_pod=21,
                ),
                FreightQuotationItemCreate(
                    provider_id=carriers[2].provider_id,
                    provider_name=carriers[2].partner_name,
                    vessel_name="CMA CGM ANTOINE",
                    ocean_freight_cost=3500.0,
                    local_charges_cost=500.0,
                    inland_cost=300.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=32),  # 30 days transit
                    free_days_at_pod=14,
                ),
            ],
        )

        res = FreightQuotationService.create_rfq(db_session, rfq_in)

        assert res.rfq_id is not None
        assert res.rfq_code.startswith("RFQ-")
        assert res.total_quotations_count == 3

        # Costs: Carrier 0: 3950.0, Carrier 1: 3550.0, Carrier 2: 4300.0
        assert res.lowest_freight_cost == 3550.0
        assert res.average_freight_cost == round((3950.0 + 3550.0 + 4300.0) / 3, 2)

        # Transits: 24, 20, 30 days
        assert res.fastest_transit_days == 20
        assert res.average_transit_days == round((24 + 20 + 30) / 3, 1)
        assert res.status == "Draft"
        assert res.awarded_provider_name is None

    def test_ai_bench_007_scoring_and_recommendation(self, db_session):
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="تقييم ومفاضلة عروض الشحن التنافسية",
            shipping_method="Ocean FCL",
            crd_date=crd,
            pol_name="Shanghai Port",
            pod_name="El Dekheila Port",
            quotations=[
                FreightQuotationItemCreate(
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3000.0,
                    local_charges_cost=200.0,
                    inland_cost=0.0,
                    free_days_at_pod=14,
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=28),  # 25 days
                ),
                FreightQuotationItemCreate(
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=2500.0,
                    local_charges_cost=200.0,
                    inland_cost=0.0,
                    free_days_at_pod=21,  # better free time
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=25),  # 22 days (faster)
                ),
            ],
        )

        rfq = FreightQuotationService.create_rfq(db_session, rfq_in)
        benchmark = FreightQuotationService.evaluate_and_rank_rfq_quotes(db_session, rfq.rfq_id)

        assert benchmark.rfq_id == rfq.rfq_id
        assert benchmark.total_quotes_analyzed == 2
        assert len(benchmark.all_ranked_quotes) == 2

        winner = benchmark.all_ranked_quotes[0]
        assert winner.rank == 1
        assert winner.provider_id == carriers[1].provider_id
        assert winner.total_cost == 2700.0
        assert winner.cost_score == 50.0  # lowest price gets full 50 pts
        assert winner.free_days_score == round(25.0 * (21 / 28.0), 1)
        assert winner.transit_score == 15.0  # fastest transit gets full 15 pts
        assert winner.reliability_score == 8.5
        assert winner.cost_saving_vs_average > 0.0
        assert "أقل سعر إجمالي شامل" in winner.key_advantages
        assert "التوصية التنفيذية للاعتماد" in benchmark.executive_recommendation_ar
        assert winner.provider_name in benchmark.executive_recommendation_ar

    def test_quotation_awarding_and_import_file_bidirectional_sync(self, db_session):
        imp = db_session.query(ImportFile).first()
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 10, 5)

        rfq_in = FreightRFQRequestCreate(
            title="طلب شحن مرتبط بملف استيرادي",
            shipping_method="Ocean FCL",
            crd_date=crd,
            pol_name="Qingdao Port",
            pod_name="Alexandria Port",
            import_file_id=imp.import_file_id,
            quotations=[
                FreightQuotationItemCreate(
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3100.0,
                    free_days_at_pod=14,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=26),
                ),
                FreightQuotationItemCreate(
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=2750.0,
                    free_days_at_pod=21,
                    sailing_date=crd + timedelta(days=4),
                    estimated_arrival_date=crd + timedelta(days=25),
                ),
            ],
        )

        rfq = FreightQuotationService.create_rfq(db_session, rfq_in)
        assert rfq.status == "Draft"

        # Award quote 2 (MSC)
        target_quote_id = rfq.quotations[1].quotation_id
        awarded_rfq = FreightQuotationService.award_quotation(db_session, rfq.rfq_id, target_quote_id)

        assert awarded_rfq.status == "Awarded"
        assert awarded_rfq.selected_quotation_id == target_quote_id
        assert awarded_rfq.awarded_provider_name == carriers[1].partner_name

        # Verify Bidirectional Sync with ImportFile
        db_session.refresh(imp)
        assert carriers[1].partner_name in imp.selected_scenario
        assert imp.target_free_days == 21
        assert imp.port_of_loading == "Qingdao Port"
        assert imp.port_of_discharge == "Alexandria Port"
        assert imp.cargo_ready_date == crd

    def test_business_validation_guards(self, db_session):
        carriers = db_session.query(ExternalServiceProvider).all()
        crd = date(2026, 10, 10)

        # 1. Sailing date before CRD
        with pytest.raises(HTTPException) as exc1:
            FreightQuotationService.create_rfq(
                db_session,
                FreightRFQRequestCreate(
                    title="تاريخ غير صالح",
                    crd_date=crd,
                    pol_name="Port",
                    pod_name="Port",
                    quotations=[
                        FreightQuotationItemCreate(
                            provider_id=carriers[0].provider_id,
                            provider_name=carriers[0].partner_name,
                            ocean_freight_cost=2000.0,
                            sailing_date=crd - timedelta(days=1),
                            estimated_arrival_date=crd + timedelta(days=20),
                        )
                    ],
                ),
            )
        assert "Sailing date" in exc1.value.detail

        # 2. Arrival date <= sailing date
        with pytest.raises(HTTPException) as exc2:
            FreightQuotationService.create_rfq(
                db_session,
                FreightRFQRequestCreate(
                    title="تاريخ وصول غير صالح",
                    crd_date=crd,
                    pol_name="Port",
                    pod_name="Port",
                    quotations=[
                        FreightQuotationItemCreate(
                            provider_id=carriers[0].provider_id,
                            provider_name=carriers[0].partner_name,
                            ocean_freight_cost=2000.0,
                            sailing_date=crd + timedelta(days=5),
                            estimated_arrival_date=crd + timedelta(days=4),
                        )
                    ],
                ),
            )
        assert "Estimated arrival date" in exc2.value.detail

        # 3. Non-existent carrier
        with pytest.raises(HTTPException) as exc3:
            FreightQuotationService.create_rfq(
                db_session,
                FreightRFQRequestCreate(
                    title="ناقل غير موجود",
                    crd_date=crd,
                    pol_name="Port",
                    pod_name="Port",
                    quotations=[
                        FreightQuotationItemCreate(
                            provider_id=99999,
                            provider_name="Ghost Line",
                            ocean_freight_cost=2000.0,
                            sailing_date=crd + timedelta(days=2),
                            estimated_arrival_date=crd + timedelta(days=20),
                        )
                    ],
                ),
            )
        assert "غير موجود" in exc3.value.detail or "not found" in exc3.value.detail

        # 4. Inactive / Non-existent Import File ID
        with pytest.raises(HTTPException) as exc4:
            FreightQuotationService.create_rfq(
                db_session,
                FreightRFQRequestCreate(
                    title="ملف استيرادي غير صالح",
                    crd_date=crd,
                    pol_name="Port",
                    pod_name="Port",
                    import_file_id=88888,
                ),
            )
        assert "Import File" in exc4.value.detail

    def test_rfq_filtering_and_soft_delete_lifecycle(self, db_session):
        imp = db_session.query(ImportFile).first()
        crd = date(2026, 10, 1)

        rfq1 = FreightQuotationService.create_rfq(
            db_session,
            FreightRFQRequestCreate(
                title="RFQ Sea FCL",
                shipping_method="Ocean FCL",
                crd_date=crd,
                pol_name="POL 1",
                pod_name="POD 1",
                import_file_id=imp.import_file_id,
            ),
        )

        rfq2 = FreightQuotationService.create_rfq(
            db_session,
            FreightRFQRequestCreate(
                title="RFQ Air",
                shipping_method="Air Freight",
                crd_date=crd,
                pol_name="POL 2",
                pod_name="POD 2",
            ),
        )

        # Filter by shipping_method
        fcl_list = FreightQuotationService.list_rfqs(db_session, shipping_method="Ocean FCL")
        assert len(fcl_list) == 1
        assert fcl_list[0].rfq_id == rfq1.rfq_id

        # Filter by import_file_id
        file_rfqs = FreightQuotationService.list_rfqs(db_session, import_file_id=imp.import_file_id)
        assert len(file_rfqs) == 1
        assert file_rfqs[0].rfq_id == rfq1.rfq_id

        # Soft delete & restore
        deleted = FreightQuotationService.soft_delete_rfq(db_session, rfq2.rfq_id)
        assert deleted.is_active is False

        active_list = FreightQuotationService.list_rfqs(db_session, include_inactive=False)
        assert len(active_list) == 1
        assert active_list[0].rfq_id == rfq1.rfq_id

        restored = FreightQuotationService.restore_rfq(db_session, rfq2.rfq_id)
        assert restored.is_active is True
        all_list = FreightQuotationService.list_rfqs(db_session, include_inactive=False)
        assert len(all_list) == 2
