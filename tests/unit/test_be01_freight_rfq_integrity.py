"""
BE01-T04: RFQ integrity: quotation upsert, award only through /award, read without side effects.
"""

from datetime import date, timedelta
import pytest
from fastapi import HTTPException

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.freight_quotations.model import FreightRFQRequest, FreightQuotationItem
from modules.freight_quotations.schemas import (
    FreightRFQRequestCreate,
    FreightRFQRequestUpdate,
    FreightQuotationItemCreate,
)
from modules.freight_quotations.service import FreightQuotationService
from modules.import_files.model import ImportFile


@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(bind=engine)
    session = TestingSession()

    p1 = ExternalServiceProvider(
        partner_code="ESP-0001",
        partner_name="Hapag-Lloyd",
        partner_type="Shipping Line",
        is_active=True,
    )
    p2 = ExternalServiceProvider(
        partner_code="ESP-0002",
        partner_name="CMA CGM",
        partner_type="Shipping Line",
        is_active=True,
    )
    p_inactive = ExternalServiceProvider(
        partner_code="ESP-0003",
        partner_name="Inactive Line",
        partner_type="Shipping Line",
        is_active=False,
    )
    imp = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-0001",
        company_id=1,
        company_name="SCAS",
        supplier_id=1,
        supplier_name="Suzhou Yuheng",
        is_active=True,
    )
    session.add_all([p1, p2, p_inactive, imp])
    session.commit()

    yield session
    session.close()


def test_create_with_is_awarded_and_status_ignored(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    p2 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0002").first()
    crd = date(2026, 9, 1)

    payload = {
        "title": "طلب عروض أسعار اختبار",
        "shipping_method": "Ocean FCL",
        "crd_date": crd,
        "pol_name": "Ningbo",
        "pod_name": "Alexandria",
        "status": "Awarded",
        "selected_quotation_id": 999,
        "quotations": [
            {
                "provider_id": p1.provider_id,
                "provider_name": p1.partner_name,
                "ocean_freight_cost": 2500.0,
                "sailing_date": crd + timedelta(days=2),
                "estimated_arrival_date": crd + timedelta(days=22),
                "is_awarded": True,
            },
            {
                "provider_id": p2.provider_id,
                "provider_name": p2.partner_name,
                "ocean_freight_cost": 2700.0,
                "sailing_date": crd + timedelta(days=4),
                "estimated_arrival_date": crd + timedelta(days=24),
                "is_awarded": True,
            },
        ],
    }

    rfq_in = FreightRFQRequestCreate.model_validate(payload)
    res = FreightQuotationService.create_rfq(db_session, rfq_in)

    assert res.status == "Draft"
    assert res.selected_quotation_id is None
    assert res.awarded_provider_name is None
    for q in res.quotations:
        assert q.is_awarded is False

    # Check direct in DB
    db_rfq = db_session.query(FreightRFQRequest).filter_by(rfq_id=res.rfq_id).first()
    assert db_rfq.status == "Draft"
    assert db_rfq.selected_quotation_id is None
    for q in db_rfq.quotations:
        assert q.is_awarded is False


def test_get_never_mutates_is_awarded(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب قراءة بدون تعديل",
        crd_date=crd,
        pol_name="Shanghai",
        pod_name="Sokhna",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2000.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=20),
            )
        ],
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)

    # Calling get_rfq and list_rfqs
    got = FreightQuotationService.get_rfq(db_session, created.rfq_id)
    assert got.quotations[0].is_awarded is False

    listed = FreightQuotationService.list_rfqs(db_session)
    assert len(listed) >= 1

    # Ensure DB was never mutated
    db_quote = db_session.query(FreightQuotationItem).filter_by(rfq_id=created.rfq_id).first()
    assert db_quote.is_awarded is False


def test_award_and_upsert_preserves_selected_quotation_and_awarded_provider(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    p2 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0002").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب للترسية والتحديث",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
        import_file_id=1,
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            ),
            FreightQuotationItemCreate(
                provider_id=p2.provider_id,
                provider_name=p2.partner_name,
                ocean_freight_cost=2800.0,
                sailing_date=crd + timedelta(days=3),
                estimated_arrival_date=crd + timedelta(days=23),
            ),
        ],
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)
    q1_id = created.quotations[0].quotation_id
    q2_id = created.quotations[1].quotation_id

    # Award quote 1
    awarded = FreightQuotationService.award_quotation(db_session, created.rfq_id, q1_id)
    assert awarded.status == "Awarded"
    assert awarded.selected_quotation_id == q1_id
    assert awarded.awarded_provider_name == p1.partner_name

    # PUT with the same quotation IDs and updated ocean freight cost
    update_in = FreightRFQRequestUpdate(
        quotations=[
            FreightQuotationItemCreate(
                quotation_id=q1_id,
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2400.0,  # updated price
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            ),
            FreightQuotationItemCreate(
                quotation_id=q2_id,
                provider_id=p2.provider_id,
                provider_name=p2.partner_name,
                ocean_freight_cost=2750.0,
                sailing_date=crd + timedelta(days=3),
                estimated_arrival_date=crd + timedelta(days=23),
            ),
        ]
    )
    updated = FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)

    # Quotation IDs are intact!
    assert [q.quotation_id for q in updated.quotations] == [q1_id, q2_id]
    # Selected quotation id still resolves!
    assert updated.selected_quotation_id == q1_id
    # Awarded provider name unchanged!
    assert updated.awarded_provider_name == p1.partner_name
    # Updated cost reflected
    assert updated.quotations[0].ocean_freight_cost == 2400.0


def test_update_deleting_awarded_quotation_raises_409(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    p2 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0002").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب لمنع حذف العرض المعتمد",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            ),
            FreightQuotationItemCreate(
                provider_id=p2.provider_id,
                provider_name=p2.partner_name,
                ocean_freight_cost=2800.0,
                sailing_date=crd + timedelta(days=3),
                estimated_arrival_date=crd + timedelta(days=23),
            ),
        ],
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)
    q1_id = created.quotations[0].quotation_id
    q2_id = created.quotations[1].quotation_id

    # Award quote 1
    FreightQuotationService.award_quotation(db_session, created.rfq_id, q1_id)

    # Try to PUT only quote 2 (omitting awarded quote 1)
    update_in = FreightRFQRequestUpdate(
        quotations=[
            FreightQuotationItemCreate(
                quotation_id=q2_id,
                provider_id=p2.provider_id,
                provider_name=p2.partner_name,
                ocean_freight_cost=2800.0,
                sailing_date=crd + timedelta(days=3),
                estimated_arrival_date=crd + timedelta(days=23),
            )
        ]
    )

    with pytest.raises(HTTPException) as exc:
        FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)

    assert exc.value.status_code == 409
    assert "لا يمكن حذف العرض المعتمد" in exc.value.detail


def test_update_unawarded_rfq_can_add_update_delete_quotes(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    p2 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0002").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب لتعديل البنود",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            ),
            FreightQuotationItemCreate(
                provider_id=p2.provider_id,
                provider_name=p2.partner_name,
                ocean_freight_cost=2800.0,
                sailing_date=crd + timedelta(days=3),
                estimated_arrival_date=crd + timedelta(days=23),
            ),
        ],
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)
    q1_id = created.quotations[0].quotation_id

    # Update quote 1 in place and add new quote without quotation_id, omitting quote 2
    update_in = FreightRFQRequestUpdate(
        quotations=[
            FreightQuotationItemCreate(
                quotation_id=q1_id,
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2300.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            ),
            FreightQuotationItemCreate(
                provider_id=p2.provider_id,
                provider_name=p2.partner_name,
                ocean_freight_cost=3100.0,
                sailing_date=crd + timedelta(days=5),
                estimated_arrival_date=crd + timedelta(days=25),
            ),
        ]
    )

    updated = FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)
    assert len(updated.quotations) == 2
    # First quote kept id
    assert updated.quotations[0].quotation_id == q1_id
    assert updated.quotations[0].ocean_freight_cost == 2300.0
    # Second quote got new id
    assert updated.quotations[1].quotation_id != q1_id
    assert updated.quotations[1].ocean_freight_cost == 3100.0


def test_award_soft_deleted_rfq_raises_404(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب محذوف",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            )
        ],
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)
    q_id = created.quotations[0].quotation_id

    # Soft delete
    FreightQuotationService.soft_delete_rfq(db_session, created.rfq_id)

    # Award soft-deleted RFQ must raise 404
    with pytest.raises(HTTPException) as exc:
        FreightQuotationService.award_quotation(db_session, created.rfq_id, q_id)

    assert exc.value.status_code == 404


def test_award_cancelled_rfq_raises_409(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب ملغي",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            )
        ],
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)
    q_id = created.quotations[0].quotation_id

    # Set status Cancelled in DB
    db_rfq = db_session.query(FreightRFQRequest).filter_by(rfq_id=created.rfq_id).first()
    db_rfq.status = "Cancelled"
    db_session.commit()

    # Award cancelled RFQ must raise 409
    with pytest.raises(HTTPException) as exc:
        FreightQuotationService.award_quotation(db_session, created.rfq_id, q_id)

    assert exc.value.status_code == 409
    assert "لا يمكن ترسية طلب عروض أسعار ملغي" in exc.value.detail


def test_update_explicit_null_not_null_column_raises_400(db_session):
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب لاختبار الحقول الإلزامية",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)

    # Send explicit null for title
    update_in = FreightRFQRequestUpdate(title=None)
    # In Pydantic model_dump(exclude_unset=True) includes fields explicitly set
    update_in = FreightRFQRequestUpdate.model_validate({"title": None})

    with pytest.raises(HTTPException) as exc:
        FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)

    assert exc.value.status_code == 400
    assert "لا يمكن مسح الحقل الإلزامي" in exc.value.detail


def test_inactive_carrier_raises_400(db_session):
    p_inactive = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0003").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب بناقل غير نشط",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p_inactive.provider_id,
                provider_name=p_inactive.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            )
        ],
    )

    with pytest.raises(HTTPException) as exc:
        FreightQuotationService.create_rfq(db_session, rfq_in)

    assert exc.value.status_code == 400
    assert "غير نشط" in exc.value.detail or "غير موجود" in exc.value.detail


def test_update_duplicate_quotation_ids_raises_400(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب لاختبار تكرار المعرفات",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            )
        ],
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)
    q_id = created.quotations[0].quotation_id

    update_in = FreightRFQRequestUpdate(
        quotations=[
            FreightQuotationItemCreate(
                quotation_id=q_id,
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            ),
            FreightQuotationItemCreate(
                quotation_id=q_id,
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2600.0,
                sailing_date=crd + timedelta(days=3),
                estimated_arrival_date=crd + timedelta(days=23),
            ),
        ]
    )

    with pytest.raises(HTTPException) as exc:
        FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)

    assert exc.value.status_code == 400
    assert "تكرار" in exc.value.detail


def test_update_foreign_quotation_id_raises_400(db_session):
    p1 = db_session.query(ExternalServiceProvider).filter_by(partner_code="ESP-0001").first()
    crd = date(2026, 9, 1)

    rfq_in = FreightRFQRequestCreate(
        title="طلب لاختبار معرف أجنبي",
        crd_date=crd,
        pol_name="Ningbo",
        pod_name="Alexandria",
        quotations=[
            FreightQuotationItemCreate(
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            )
        ],
    )
    created = FreightQuotationService.create_rfq(db_session, rfq_in)

    update_in = FreightRFQRequestUpdate(
        quotations=[
            FreightQuotationItemCreate(
                quotation_id=88888,
                provider_id=p1.provider_id,
                provider_name=p1.partner_name,
                ocean_freight_cost=2500.0,
                sailing_date=crd + timedelta(days=2),
                estimated_arrival_date=crd + timedelta(days=22),
            )
        ]
    )

    with pytest.raises(HTTPException) as exc:
        FreightQuotationService.update_rfq(db_session, created.rfq_id, update_in)

    assert exc.value.status_code == 400
    assert "غير موجود في هذا الطلب" in exc.value.detail
