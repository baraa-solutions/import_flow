"""
Unit tests for Broker Price Lists, Clearance Expense Catalog & Consultation Snapshot Engine (BP-009)
"""

import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import main
from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.customs_consultation.model import (
    ClearanceExpenseType,
    BrokerPriceList,
    BrokerPriceListItem,
    CustomsConsultationSession,
    CustomsChecklistItem,
    CustomsBrokerQuoteItem,
)
from modules.customs_consultation.schemas import (
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeUpdate,
    BrokerPriceListCreate,
    BrokerPriceListItemCreate,
    BrokerPriceListUpdate,
    CustomsConsultationCreate,
    CustomsBrokerQuoteItemCreate,
    CustomsChecklistItemCreate,
)
from modules.customs_consultation.service import (
    ClearanceExpenseTypeService,
    BrokerPriceListService,
    CustomsConsultationService,
)


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Create dummy broker
    broker = ExternalServiceProvider(
        provider_id=1,
        partner_code="PRT-BRK-001",
        partner_name="مكتب النسر للتخليص الجمركي",
        partner_type="Customs Broker",
        is_active=True,
    )
    session.add(broker)
    session.commit()

    # Money fields need an active currency in master data (currency required when a value is entered).
    from modules.currencies.model import Currency as _Currency
    for _code in ("USD", "EGP", "EUR"):
        if not session.query(_Currency).filter_by(currency_code=_code).first():
            session.add(_Currency(currency_code=_code, currency_name=_code, currency_symbol=_code, is_active=True))
    session.commit()
    yield session
    session.close()


def test_create_and_list_expense_types(db_session):
    # 1. Create expense types
    exp1 = ClearanceExpenseTypeService.create_expense_type(
        db_session,
        ClearanceExpenseTypeCreate(
            expense_code="EXP-CLR-101",
            name_ar="أتعاب تخليص LCL",
            name_en="LCL Clearance Fee",
            category="Clearance Fees (أتعاب ومصاريف تخليص)",
            default_unit="Per Invoice (لكل فاتورة)",
            default_currency="EGP",
            display_order=1,
        ),
    )
    assert exp1.expense_id is not None
    assert exp1.name_ar == "أتعاب تخليص LCL"

    exp2 = ClearanceExpenseTypeService.create_expense_type(
        db_session,
        ClearanceExpenseTypeCreate(
            expense_code="EXP-TRN-102",
            name_ar="نقل حاوية 20 قدم للقاهرة",
            category="Inland Transport (نقل بري وشاحنات)",
            default_unit="Per Container (لكل حاوية)",
            default_currency="EGP",
            display_order=2,
        ),
    )
    assert exp2.expense_id is not None

    # 2. List and Filter
    all_expenses = ClearanceExpenseTypeService.list_expense_types(db_session)
    assert len(all_expenses) == 2

    transport_expenses = ClearanceExpenseTypeService.list_expense_types(
        db_session, category="Inland Transport (نقل بري وشاحنات)"
    )
    assert len(transport_expenses) == 1
    assert transport_expenses[0].expense_code == "EXP-TRN-102"


def test_create_and_fetch_active_broker_price_list(db_session):
    # 1. Create Price List
    pl = BrokerPriceListService.create_price_list(
        db_session,
        BrokerPriceListCreate(
            title="بيان أسعار التخليص والنقل لميناء الإسكندرية 2026",
            broker_id=1,
            broker_name="مكتب النسر للتخليص الجمركي",
            port_name="ميناء الإسكندرية",
            effective_from=date(2026, 1, 1),
            effective_to=date(2026, 12, 31),
            version=1,
            items=[
                BrokerPriceListItemCreate(
                    expense_name="أتعاب تخليص 20 قدم",
                    category="Clearance Fees (أتعاب ومصاريف تخليص)",
                    unit_type="Per Invoice",
                    standard_price=2500.0,
                    currency="EGP",
                ),
                BrokerPriceListItemCreate(
                    expense_name="مصاريف تخليص حاوية 20 قدم",
                    category="Clearance Fees (أتعاب ومصاريف تخليص)",
                    unit_type="Per Container",
                    standard_price=7500.0,
                    currency="EGP",
                ),
                BrokerPriceListItemCreate(
                    expense_name="نقل حاوية 20 قدم للقاهرة",
                    category="Inland Transport (نقل بري وشاحنات)",
                    unit_type="Per Container",
                    standard_price=14800.0,
                    currency="EGP",
                ),
            ],
        ),
    )

    assert pl.price_list_id is not None
    assert len(pl.items) == 3
    assert pl.items[0].standard_price == 2500.0

    # 2. Fetch active price list for broker on 2026-06-15
    active_pl = BrokerPriceListService.get_active_price_list_for_broker(
        db_session, broker_id=1, target_date=date(2026, 6, 15)
    )
    assert active_pl is not None
    assert active_pl.price_list_id == pl.price_list_id
    assert len(active_pl.items) == 3


def test_consultation_study_with_broker_quote_calculations(db_session):
    # 1. Create study with broker quote lines
    study_in = CustomsConsultationCreate(
        title="دراسة استشارة جمركية وعرض سعر مخلص لشحنة مواتير",
        broker_id=1,
        broker_name="مكتب النسر للتخليص الجمركي",
        estimated_duties_egp=50000.0,
        checklist_items=[
            CustomsChecklistItemCreate(
                document_type="Commercial Invoice",
                status="Approved",
            ),
            CustomsChecklistItemCreate(
                document_type="Packing List",
                status="Approved",
            ),
        ],
        broker_quote_items=[
            CustomsBrokerQuoteItemCreate(
                currency="EGP",
                expense_name="أتعاب تخليص (فاتورة)",
                category="Clearance Fees (أتعاب ومصاريف تخليص)",
                unit_type="Per Invoice",
                unit_price=2500.0,
                qty=1.0,
                is_applicable=True,
            ),
            CustomsBrokerQuoteItemCreate(
                currency="EGP",
                expense_name="مصاريف تخليص حاوية 20 قدم",
                category="Clearance Fees (أتعاب ومصاريف تخليص)",
                unit_type="Per Container",
                unit_price=7500.0,
                qty=2.0,
                is_applicable=True,
            ),
            CustomsBrokerQuoteItemCreate(
                currency="EGP",
                expense_name="نقل حاوية 20 قدم للقاهرة",
                category="Inland Transport (نقل بري وشاحنات)",
                unit_type="Per Container",
                unit_price=14800.0,
                qty=2.0,
                is_applicable=True,
            ),
            CustomsBrokerQuoteItemCreate(
                currency="EGP",
                expense_name="عرض أمن عام للقاهرة",
                category="Procedures & Approvals (إجراءات وموافقات وفحص)",
                unit_type="Per Case",
                unit_price=5000.0,
                qty=1.0,
                is_applicable=False,  # NOT applied
            ),
        ],
    )

    created_study = CustomsConsultationService.create_consultation(db_session, study_in)

    # Calculation verification:
    # 2500 * 1 + 7500 * 2 + 14800 * 2 = 2500 + 15000 + 29600 = 47100 EGP
    expected_broker_total = 2500.0 + 15000.0 + 29600.0
    assert created_study.total_broker_fees_egp == expected_broker_total
    assert created_study.applied_broker_items_count == 3
    assert len(created_study.broker_quote_items) == 4


def test_historical_snapshot_isolation(db_session):
    """
    CRITICAL BUSINESS TEST:
    Modifying the master price list later MUST NEVER change past saved consultation studies.
    """
    # 1. Create original Price List V1
    pl = BrokerPriceListService.create_price_list(
        db_session,
        BrokerPriceListCreate(
            title="أسعار 2026",
            broker_id=1,
            broker_name="مكتب النسر",
            effective_from=date(2026, 1, 1),
            items=[
                BrokerPriceListItemCreate(
                    currency="EGP",
                    expense_name="أتعاب تخليص",
                    category="Clearance Fees",
                    unit_type="Per Invoice",
                    standard_price=2000.0,
                ),
            ],
        ),
    )

    # 2. Create Consultation Study based on V1
    study_in = CustomsConsultationCreate(
        title="دراسة شحنة يناير 2026",
        broker_id=1,
        broker_name="مكتب النسر",
        broker_price_list_id=pl.price_list_id,
        broker_quote_items=[
            CustomsBrokerQuoteItemCreate(
                currency="EGP",
                expense_name="أتعاب تخليص",
                category="Clearance Fees",
                unit_type="Per Invoice",
                unit_price=2000.0,
                qty=1.0,
                is_applicable=True,
            ),
        ],
    )
    study = CustomsConsultationService.create_consultation(db_session, study_in)
    assert study.total_broker_fees_egp == 2000.0

    # 3. Update Master Price List to 3500.0 EGP (Price increase in August)
    BrokerPriceListService.update_price_list(
        db_session,
        pl.price_list_id,
        BrokerPriceListUpdate(
            items=[
                BrokerPriceListItemCreate(
                    currency="EGP",
                    expense_name="أتعاب تخليص",
                    category="Clearance Fees",
                    unit_type="Per Invoice",
                    standard_price=3500.0,
                ),
            ]
        ),
    )

    # 4. Fetch the previous study and verify its snapshot is preserved at 2000.0
    fetched_study = CustomsConsultationService.get_consultation(db_session, study.consultation_id)
    assert fetched_study.total_broker_fees_egp == 2000.0
    assert fetched_study.broker_quote_items[0].unit_price == 2000.0
    assert fetched_study.broker_quote_items[0].total_amount == 2000.0
