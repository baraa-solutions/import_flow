"""
Unit Tests for BE01-T04: Freight RFQ Integrity:
Quotation upsert, award only via /award, pure read metrics, transaction hygiene,
active checks, and NOT NULL column guards.
"""

from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
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

    # Seed active and inactive carrier partners
    c1 = ExternalServiceProvider(
        partner_code="ESP-000001",
        partner_name="Maersk Line Shipping",
        partner_type="Shipping Line",
        is_active=True,
    )
    c2 = ExternalServiceProvider(
        partner_code="ESP-000002",
        partner_name="MSC Shipping",
        partner_type="Shipping Line",
        is_active=True,
    )
    c3_inactive = ExternalServiceProvider(
        partner_code="ESP-000003",
        partner_name="Inactive Carrier",
        partner_type="Shipping Line",
        is_active=False,
    )

    # Seed import file
    f1 = ImportFile(
        import_file_code="IMP-2026-0001",
        custom_file_number="CF-2026-001",
        company_name="SCAS Logistics Co.",
        supplier_name="Global Machinery Ltd.",
        status="Open",
        is_active=True,
    )

    db.add_all([c1, c2, c3_inactive, f1])
    db.commit()

    # Money fields need an active currency in master data (currency required when a value is entered).
    from modules.currencies.model import Currency as _Currency
    for _code in ("USD", "EGP", "EUR"):
        if not db.query(_Currency).filter_by(currency_code=_code).first():
            db.add(_Currency(currency_code=_code, currency_name=_code, currency_symbol=_code, is_active=True))
    db.commit()
    yield db
    db.close()


class TestBE01FreightRFQIntegrity:

    def test_award_then_put_preserves_awarded_quote_and_ids(self, db_session):
        """
        Acceptance criterion: award -> PUT with the same quotation ids ->
        selected_quotation_id still resolves, awarded_provider_name unchanged.
        """
        carriers = db_session.query(ExternalServiceProvider).filter(ExternalServiceProvider.is_active == True).all()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="RFQ Test Award then PUT",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3000.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                ),
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=2800.0,
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=24),
                ),
            ],
        )

        created = FreightQuotationService.create_rfq(db_session, rfq_in)
        q1_id = created.quotations[0].quotation_id
        q2_id = created.quotations[1].quotation_id

        # Award Q2
        awarded = FreightQuotationService.award_quotation(db_session, created.rfq_id, q2_id)
        assert awarded.status == "Awarded"
        assert awarded.selected_quotation_id == q2_id
        assert awarded.awarded_provider_name == carriers[1].partner_name

        # PUT with the same quotation IDs, updating some costs
        update_in = FreightRFQRequestUpdate(
            title="RFQ Test Award then PUT - Updated Title",
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    quotation_id=q1_id,
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=2950.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                ),
                FreightQuotationItemCreate(
                    currency_code="USD",
                    quotation_id=q2_id,
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=2750.0,
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=24),
                ),
            ],
        )

        updated = FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)
        assert updated.title == "RFQ Test Award then PUT - Updated Title"
        assert updated.selected_quotation_id == q2_id
        assert updated.awarded_provider_name == carriers[1].partner_name

        # Verify quote IDs were preserved in place
        updated_quote_ids = {q.quotation_id for q in updated.quotations}
        assert updated_quote_ids == {q1_id, q2_id}

    def test_put_deleting_awarded_quote_raises_409(self, db_session):
        """
        If the awarded quotation is missing from the update payload -> raise 409.
        """
        carriers = db_session.query(ExternalServiceProvider).filter(ExternalServiceProvider.is_active == True).all()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="RFQ Delete Awarded Quote Guard",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3000.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                ),
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=2800.0,
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=24),
                ),
            ],
        )

        created = FreightQuotationService.create_rfq(db_session, rfq_in)
        q1_id = created.quotations[0].quotation_id
        q2_id = created.quotations[1].quotation_id

        # Award Q1
        FreightQuotationService.award_quotation(db_session, created.rfq_id, q1_id)

        # Attempt to PUT omitting Q1 (only sending Q2)
        update_in = FreightRFQRequestUpdate(
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    quotation_id=q2_id,
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=2800.0,
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=24),
                ),
            ]
        )

        with pytest.raises(HTTPException) as exc_info:
            FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)

        assert exc_info.value.status_code == 409
        assert "لا يمكن حذف العرض المعتمد" in exc_info.value.detail

    def test_get_never_changes_is_awarded(self, db_session):
        """
        Acceptance criterion: GET never changes is_awarded.
        Read computation is pure with zero side-effect writes.
        """
        carriers = db_session.query(ExternalServiceProvider).filter(ExternalServiceProvider.is_active == True).all()
        crd = date(2026, 10, 1)

        # Directly insert RFQ into DB with 2 quotes, neither awarded
        rfq = FreightRFQRequest(
            rfq_code="RFQ-2026-999",
            title="RFQ Direct DB Insert",
            shipping_method="Ocean FCL",
            crd_date=crd,
            pol_name="Ningbo",
            pod_name="Alexandria",
            status="Draft",
            selected_quotation_id=None,
            is_active=True,
        )
        db_session.add(rfq)
        db_session.flush()

        q1 = FreightQuotationItem(
            rfq_id=rfq.rfq_id,
            provider_id=carriers[0].provider_id,
            provider_name=carriers[0].partner_name,
            ocean_freight_cost=2500.0,
            sailing_date=crd + timedelta(days=2),
            estimated_arrival_date=crd + timedelta(days=22),
            is_awarded=False,
        )
        q2 = FreightQuotationItem(
            rfq_id=rfq.rfq_id,
            provider_id=carriers[1].provider_id,
            provider_name=carriers[1].partner_name,
            ocean_freight_cost=2700.0,
            sailing_date=crd + timedelta(days=3),
            estimated_arrival_date=crd + timedelta(days=23),
            is_awarded=False,
        )
        db_session.add_all([q1, q2])
        db_session.commit()

        # Call GET
        res = FreightQuotationService.get_rfq(db_session, rfq.rfq_id)
        assert res.rfq_id == rfq.rfq_id

        # Verify DB items were NOT mutated
        db_quotes = db_session.query(FreightQuotationItem).filter(FreightQuotationItem.rfq_id == rfq.rfq_id).all()
        for q in db_quotes:
            assert q.is_awarded is False

    def test_create_with_is_awarded_true_stores_none_awarded(self, db_session):
        """
        Acceptance criterion: create with is_awarded=true on two quotes stores none awarded.
        """
        carriers = db_session.query(ExternalServiceProvider).filter(ExternalServiceProvider.is_active == True).all()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="RFQ Create Client Award Attempt",
            status="Awarded",  # Client tries to set status
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3000.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                    is_awarded=True,  # Client tries to award
                ),
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=2800.0,
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=24),
                    is_awarded=True,  # Client tries to award
                ),
            ],
        )

        created = FreightQuotationService.create_rfq(db_session, rfq_in)
        assert created.status == "Draft"
        assert created.selected_quotation_id is None
        assert created.awarded_provider_name is None

        db_quotes = db_session.query(FreightQuotationItem).filter(FreightQuotationItem.rfq_id == created.rfq_id).all()
        assert len(db_quotes) == 2
        for q in db_quotes:
            assert q.is_awarded is False

    def test_award_soft_deleted_rfq_raises_404(self, db_session):
        """
        award_quotation on a soft-deleted RFQ -> 404 (active_only=True).
        """
        carriers = db_session.query(ExternalServiceProvider).filter(ExternalServiceProvider.is_active == True).all()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="RFQ Soft Delete Award Test",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3000.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                ),
            ],
        )
        created = FreightQuotationService.create_rfq(db_session, rfq_in)
        quote_id = created.quotations[0].quotation_id

        # Soft delete RFQ
        FreightQuotationService.soft_delete_rfq(db_session, created.rfq_id)

        # Attempt to award soft-deleted RFQ
        with pytest.raises(HTTPException) as exc_info:
            FreightQuotationService.award_quotation(db_session, created.rfq_id, quote_id)

        assert exc_info.value.status_code == 404
        assert "غير موجود" in exc_info.value.detail

    def test_award_cancelled_rfq_raises_409(self, db_session):
        """
        award_quotation on a Cancelled RFQ -> 409.
        """
        carriers = db_session.query(ExternalServiceProvider).filter(ExternalServiceProvider.is_active == True).all()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="RFQ Cancelled Award Test",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3000.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                ),
            ],
        )
        created = FreightQuotationService.create_rfq(db_session, rfq_in)
        quote_id = created.quotations[0].quotation_id

        # Set status to Cancelled
        db_rfq = db_session.query(FreightRFQRequest).filter(FreightRFQRequest.rfq_id == created.rfq_id).first()
        db_rfq.status = "Cancelled"
        db_session.commit()

        # Attempt to award cancelled RFQ
        with pytest.raises(HTTPException) as exc_info:
            FreightQuotationService.award_quotation(db_session, created.rfq_id, quote_id)

        assert exc_info.value.status_code == 409
        assert "ملغي" in exc_info.value.detail

    def test_update_explicit_null_on_not_null_column_raises_400(self, db_session):
        """
        Update: reject explicit null for NOT NULL columns with 400 Arabic detail.
        PUT {"title": null} -> 400.
        """
        crd = date(2026, 10, 1)
        rfq_in = FreightRFQRequestCreate(
            title="RFQ Valid Title",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
        )
        created = FreightQuotationService.create_rfq(db_session, rfq_in)

        # Update with title=None explicitly in payload
        update_in = FreightRFQRequestUpdate.model_validate({"title": None})

        with pytest.raises(HTTPException) as exc_info:
            FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)

        assert exc_info.value.status_code == 400
        assert "الحقول الإلزامية" in exc_info.value.detail
        assert "title" in exc_info.value.detail

    def test_update_upsert_inserts_new_quotes_and_deletes_omitted(self, db_session):
        """
        Update upsert: existing quotes are updated in place, new quotes without quotation_id
        are inserted, omitted quotes are deleted.
        """
        carriers = db_session.query(ExternalServiceProvider).filter(ExternalServiceProvider.is_active == True).all()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="RFQ Upsert Dynamic",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3000.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                ),
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=carriers[1].provider_id,
                    provider_name=carriers[1].partner_name,
                    ocean_freight_cost=2800.0,
                    sailing_date=crd + timedelta(days=3),
                    estimated_arrival_date=crd + timedelta(days=24),
                ),
            ],
        )
        created = FreightQuotationService.create_rfq(db_session, rfq_in)
        q1_id = created.quotations[0].quotation_id
        q2_id = created.quotations[1].quotation_id

        # Update: keep Q1 (modify cost), omit Q2, add Q3
        update_in = FreightRFQRequestUpdate(
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    quotation_id=q1_id,
                    provider_id=carriers[0].provider_id,
                    provider_name=carriers[0].partner_name,
                    ocean_freight_cost=3100.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                ),
                FreightQuotationItemCreate(
                    currency_code="USD",
                    # No quotation_id -> new quote
                    provider_id=carriers[1].provider_id,
                    provider_name="New Quote Provider",
                    ocean_freight_cost=2500.0,
                    sailing_date=crd + timedelta(days=4),
                    estimated_arrival_date=crd + timedelta(days=25),
                ),
            ]
        )

        updated = FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)
        assert len(updated.quotations) == 2

        updated_ids = {q.quotation_id for q in updated.quotations}
        assert q1_id in updated_ids
        assert q2_id not in updated_ids  # Q2 was deleted

        # Verify Q2 is deleted from DB
        deleted_q2 = db_session.query(FreightQuotationItem).filter(FreightQuotationItem.quotation_id == q2_id).first()
        assert deleted_q2 is None

    def test_validate_carrier_requires_active(self, db_session):
        """
        validate_carrier_exists: inactive carrier raises 400 with require_active Arabic message.
        """
        inactive_carrier = db_session.query(ExternalServiceProvider).filter(ExternalServiceProvider.is_active == False).first()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="RFQ Inactive Carrier Test",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            quotations=[
                FreightQuotationItemCreate(
                    currency_code="USD",
                    provider_id=inactive_carrier.provider_id,
                    provider_name=inactive_carrier.partner_name,
                    ocean_freight_cost=3000.0,
                    sailing_date=crd + timedelta(days=2),
                    estimated_arrival_date=crd + timedelta(days=22),
                ),
            ],
        )

        with pytest.raises(HTTPException) as exc_info:
            FreightQuotationService.create_rfq(db_session, rfq_in)

        assert exc_info.value.status_code == 400
        assert "غير نشط" in exc_info.value.detail or "غير موجود" in exc_info.value.detail

    def test_list_rfqs_batches_import_file_codes(self, db_session):
        """
        list_rfqs: import_file_code is resolved via batch codes_by_ids.
        """
        imp_file = db_session.query(ImportFile).first()
        crd = date(2026, 10, 1)

        rfq_in = FreightRFQRequestCreate(
            title="RFQ with Linked File",
            crd_date=crd,
            pol_name="Shanghai",
            pod_name="Alexandria",
            import_file_id=imp_file.import_file_id,
        )
        created = FreightQuotationService.create_rfq(db_session, rfq_in)

        rfqs = FreightQuotationService.list_rfqs(db_session, import_file_id=imp_file.import_file_id)
        assert len(rfqs) >= 1
        matched = next(r for r in rfqs if r.rfq_id == created.rfq_id)
        assert matched.import_file_code == imp_file.import_file_code
