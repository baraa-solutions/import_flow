from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import _RATE_CACHE
from modules.import_companies.model import ImportCompany
from modules.import_files.model import ImportFile
from modules.import_files.schemas import ImportFileCreate
from modules.import_files.service import generate_master_report_service, create_import_file_service
import modules.import_files.repository as if_repo
from modules.incoterms.model import Incoterm
from modules.projects.model import Project
from modules.projects.schemas import ProjectCreate
from modules.projects.service import ProjectService
from modules.purchase_orders.model import PurchaseOrder
from modules.suppliers.model import Supplier


@pytest.fixture
def db_context():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSession()

    _RATE_CACHE.clear()

    # Seed base companies, supplier, incoterm
    company = ImportCompany(
        importer_name="Company Alpha",
        address="Cairo",
        country="Egypt",
        importer_id="IMP-001",
        importer_id_expiry=date.today() + timedelta(days=100),
        vat_id="VAT-001",
        vat_id_expiry=date.today() + timedelta(days=100),
        registration_number="REG-001",
        registration_expiry=date.today() + timedelta(days=100),
        is_active=True,
    )
    supplier = Supplier(
        supplier_code="SUP-001",
        company_name="Global Supplier",
        supplier_type="Manufacturer",
        registration_type="Factory",
        foreign_exporter_id="EXP-001",
        foreign_exporter_country="Germany",
        foreign_exporter_country_code="DE",
        address="Berlin",
        is_active=True,
    )
    incoterm = Incoterm(incoterm_code="FOB", incoterm_name="Free On Board", is_active=True)
    session.add_all([company, supplier, incoterm])
    session.commit()

    # Seed currencies
    usd = Currency(currency_id=1, currency_code="USD", currency_name="US Dollar", currency_symbol="$", is_active=True)
    eur = Currency(currency_id=2, currency_code="EUR", currency_name="Euro", currency_symbol="€", is_active=True)
    egp = Currency(currency_id=3, currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_base_currency=True, is_active=True)
    session.add_all([usd, eur, egp])
    session.commit()

    yield {
        "engine": engine,
        "session": session,
        "company": company,
        "supplier": supplier,
        "incoterm": incoterm,
        "usd": usd,
        "eur": eur,
        "egp": egp,
    }

    _RATE_CACHE.clear()
    session.close()


def _add_rate(session, currency_id: int, commercial_rate: float, effective_date: date = date.today()):
    rate = ExchangeRate(
        currency_id=currency_id,
        commercial_rate=Decimal(str(commercial_rate)),
        customs_rate=Decimal(str(commercial_rate)),
        effective_date=effective_date,
        is_active=True,
    )
    session.add(rate)
    session.commit()
    _RATE_CACHE.clear()
    return rate


# ─── BEX-T10 Acceptance Criteria Tests ────────────────────────────────────────

def test_project_commitments_multi_currency_conversion(db_context):
    """BEX-T10 Acceptance Test 1:
    Project budget USD 100,000. PO1 USD 10,000; PO2 EUR 10,000; rates commercial USD 48.50, EUR 52.80 (EGP per unit).
    EUR->USD = 10,000 * 52.80 / 48.50 = 10,886.597... ->
    total_committed_usd = 20,886.60, remaining_budget_usd = 79,113.40, budget_utilization_percent = 20.9,
    committed_by_currency = {"USD": 10000.0, "EUR": 10000.0}, missing_rate_currencies = [].
    """
    session = db_context["session"]
    _add_rate(session, currency_id=db_context["usd"].currency_id, commercial_rate=48.50)
    _add_rate(session, currency_id=db_context["eur"].currency_id, commercial_rate=52.80)

    service = ProjectService(session)
    project = service.create(ProjectCreate(
        project_name="Expansion 2026",
        project_owner="Eng. Tarek",
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        total_budget_usd=100000.0,
    ))

    # PO1 in USD 10,000
    po1 = PurchaseOrder(
        po_number="PO-USD-1",
        project_id=project.project_id,
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        currency_id=db_context["usd"].currency_id,
        total_amount_fob=Decimal("10000.00"),
        is_active=True,
    )
    # PO2 in EUR 10,000
    po2 = PurchaseOrder(
        po_number="PO-EUR-2",
        project_id=project.project_id,
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        currency_id=db_context["eur"].currency_id,
        total_amount_fob=Decimal("10000.00"),
        is_active=True,
    )
    session.add_all([po1, po2])
    session.commit()

    # Verify single project response via get_by_id
    resp = service.get_by_id(project.project_id)
    assert resp.total_committed_usd == 20886.60
    assert resp.remaining_budget_usd == 79113.40
    assert resp.budget_utilization_percent == 20.9
    assert resp.committed_by_currency == {"USD": 10000.0, "EUR": 10000.0}
    assert resp.missing_rate_currencies == []
    assert resp.po_count == 2

    # Verify get_financial_commitments
    commitments = service.get_financial_commitments(project.project_id)
    assert commitments["total_committed_usd"] == 20886.60
    assert commitments["remaining_budget_usd"] == 79113.40
    assert commitments["budget_utilization_percent"] == 20.9
    assert commitments["committed_by_currency"] == {"USD": 10000.0, "EUR": 10000.0}
    assert commitments["missing_rate_currencies"] == []
    assert commitments["po_count"] == 2


def test_project_commitments_missing_rate_gives_none_totals(db_context):
    """BEX-T10 Acceptance Test 2:
    Same project with no EUR rate -> total_committed_usd=None, remaining_budget_usd=None,
    budget_utilization_percent=None, missing_rate_currencies=["EUR"],
    committed_by_currency={"USD": 10000.0, "EUR": 10000.0}.
    """
    session = db_context["session"]
    # Seed USD rate only, no EUR rate
    _add_rate(session, currency_id=db_context["usd"].currency_id, commercial_rate=48.50)

    service = ProjectService(session)
    project = service.create(ProjectCreate(
        project_name="Expansion Missing EUR Rate",
        project_owner="Eng. Tarek",
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        total_budget_usd=100000.0,
    ))

    po1 = PurchaseOrder(
        po_number="PO-USD-M1",
        project_id=project.project_id,
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        currency_id=db_context["usd"].currency_id,
        total_amount_fob=Decimal("10000.00"),
        is_active=True,
    )
    po2 = PurchaseOrder(
        po_number="PO-EUR-M2",
        project_id=project.project_id,
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        currency_id=db_context["eur"].currency_id,
        total_amount_fob=Decimal("10000.00"),
        is_active=True,
    )
    session.add_all([po1, po2])
    session.commit()

    resp = service.get_by_id(project.project_id)
    assert resp.total_committed_usd is None
    assert resp.remaining_budget_usd is None
    assert resp.budget_utilization_percent is None
    assert resp.missing_rate_currencies == ["EUR"]
    assert resp.committed_by_currency == {"USD": 10000.0, "EUR": 10000.0}

    commitments = service.get_financial_commitments(project.project_id)
    assert commitments["total_committed_usd"] is None
    assert commitments["remaining_budget_usd"] is None
    assert commitments["budget_utilization_percent"] is None
    assert commitments["missing_rate_currencies"] == ["EUR"]
    assert commitments["committed_by_currency"] == {"USD": 10000.0, "EUR": 10000.0}


def test_master_report_currency_aggregates(db_context):
    """BEX-T10 Acceptance Test 3:
    Master report with files USD 1,000, EUR 2,000, EGP 500 ->
    estimated_cost_by_currency={"USD":1000.0, "EUR":2000.0, "EGP":500.0}, total_estimated_cost=None.
    With only USD 1,000 + USD 500 -> total_estimated_cost=1500.0, estimated_cost_by_currency={"USD":1500.0}.
    """
    session = db_context["session"]

    # 1. Multi-currency files
    f1 = ImportFile(
        import_file_code="IF-2026-MC1",
        company_id=db_context["company"].company_id,
        company_name=db_context["company"].importer_name,
        supplier_name="Global Supplier",
        estimated_cost=1000.0,
        estimated_cost_currency="USD",
        status="Open",
        is_active=True,
    )
    f2 = ImportFile(
        import_file_code="IF-2026-MC2",
        company_id=db_context["company"].company_id,
        company_name=db_context["company"].importer_name,
        supplier_name="Global Supplier",
        estimated_cost=2000.0,
        estimated_cost_currency="EUR",
        status="In Progress",
        is_active=True,
    )
    f3 = ImportFile(
        import_file_code="IF-2026-MC3",
        company_id=db_context["company"].company_id,
        company_name=db_context["company"].importer_name,
        supplier_name="Global Supplier",
        estimated_cost=500.0,
        estimated_cost_currency="EGP",
        status="Closed",
        is_active=True,
    )
    session.add_all([f1, f2, f3])
    session.commit()

    report = generate_master_report_service(session)
    assert report.total_import_files == 3
    assert report.open_files_count == 1
    assert report.in_progress_count == 1
    assert report.closed_files_count == 1
    assert report.estimated_cost_by_currency == {"USD": 1000.0, "EUR": 2000.0, "EGP": 500.0}
    assert report.total_estimated_cost is None

    # 2. Deactivate EUR and EGP files so only USD remain
    f2.is_active = False
    f3.is_active = False
    f4 = ImportFile(
        import_file_code="IF-2026-MC4",
        company_id=db_context["company"].company_id,
        company_name=db_context["company"].importer_name,
        supplier_name="Global Supplier",
        estimated_cost=500.0,
        estimated_cost_currency="USD",
        status="Open",
        is_active=True,
    )
    session.add(f4)
    session.commit()

    report_usd_only = generate_master_report_service(session)
    assert report_usd_only.total_import_files == 2
    assert report_usd_only.estimated_cost_by_currency == {"USD": 1500.0}
    assert report_usd_only.total_estimated_cost == 1500.0


def test_get_all_projects_query_count_constant(db_context):
    """BEX-T10 Acceptance Test 4:
    Query-count assertion that GET /projects with 10 projects runs a constant number of queries (<= 4).
    """
    session = db_context["session"]
    engine = db_context["engine"]

    _add_rate(session, currency_id=db_context["usd"].currency_id, commercial_rate=48.50)
    service = ProjectService(session)

    # Create 10 projects with associated active POs
    for i in range(10):
        p = service.create(ProjectCreate(
            project_name=f"Project {i+1}",
            project_owner=f"Owner {i+1}",
            company_id=db_context["company"].company_id,
            supplier_id=db_context["supplier"].supplier_id,
            incoterm_id=db_context["incoterm"].incoterm_id,
            total_budget_usd=50000.0,
        ))
        po = PurchaseOrder(
            po_number=f"PO-N1-{i+1}",
            project_id=p.project_id,
            company_id=db_context["company"].company_id,
            supplier_id=db_context["supplier"].supplier_id,
            incoterm_id=db_context["incoterm"].incoterm_id,
            currency_id=db_context["usd"].currency_id,
            total_amount_fob=Decimal("5000.00"),
            is_active=True,
        )
        session.add(po)
    session.commit()

    # Count queries during service.get_all()
    queries = []

    def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
        queries.append(statement)

    event.listen(engine, "before_cursor_execute", before_cursor_execute)
    try:
        results = service.get_all(include_inactive=False)
    finally:
        event.remove(engine, "before_cursor_execute", before_cursor_execute)

    assert len(results) == 10
    for r in results:
        assert r.total_committed_usd == 5000.0
        assert r.remaining_budget_usd == 45000.0
        assert r.budget_utilization_percent == 10.0
        assert r.po_count == 1

    # N+1 guard: 10 projects must run <= 4 queries (1 projects eager, 1 companies, 1 grouped POs)
    assert len(queries) <= 4, f"Expected <= 4 queries, executed {len(queries)}:\n" + "\n".join(queries)


def test_project_commitments_zero_pos(db_context):
    session = db_context["session"]
    service = ProjectService(session)
    project = service.create(ProjectCreate(
        project_name="Zero PO Project",
        project_owner="Tester",
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        total_budget_usd=75000.0,
    ))

    resp = service.get_by_id(project.project_id)
    assert resp.total_committed_usd == 0.0
    assert resp.remaining_budget_usd == 75000.0
    assert resp.budget_utilization_percent == 0.0
    assert resp.po_count == 0
    assert resp.missing_rate_currencies == []
    assert resp.committed_by_currency == {}


def test_project_commitments_egp_pivot_conversion(db_context):
    session = db_context["session"]
    _add_rate(session, currency_id=db_context["usd"].currency_id, commercial_rate=48.50)

    service = ProjectService(session)
    project = service.create(ProjectCreate(
        project_name="EGP PO Project",
        project_owner="Tester",
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        total_budget_usd=20000.0,
    ))

    po = PurchaseOrder(
        po_number="PO-EGP-1",
        project_id=project.project_id,
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        currency_id=db_context["egp"].currency_id,
        total_amount_fob=Decimal("485000.00"),
        is_active=True,
    )
    session.add(po)
    session.commit()

    resp = service.get_by_id(project.project_id)
    assert resp.total_committed_usd == 10000.0
    assert resp.remaining_budget_usd == 10000.0
    assert resp.budget_utilization_percent == 50.0
    assert resp.committed_by_currency == {"EGP": 485000.0}
    assert resp.missing_rate_currencies == []


def test_master_report_empty_and_unknown_currency(db_context):
    session = db_context["session"]

    # Zero files
    empty_report = generate_master_report_service(session)
    assert empty_report.total_import_files == 0
    assert empty_report.total_estimated_cost == 0.0
    assert empty_report.estimated_cost_by_currency == {}

    # File with empty currency and None cost
    f = ImportFile(
        import_file_code="IF-UNKNOWN-1",
        company_id=db_context["company"].company_id,
        company_name=db_context["company"].importer_name,
        supplier_name="Global Supplier",
        estimated_cost=None,
        estimated_cost_currency="",
        status="Open",
        is_active=True,
    )
    session.add(f)
    session.commit()

    report = generate_master_report_service(session)
    assert report.total_import_files == 1
    assert report.estimated_cost_by_currency == {"UNKNOWN": 0.0}
    assert report.total_estimated_cost == 0.0


def test_project_commitments_dangling_currency_po_not_dropped(db_context):
    """Test that POs with missing or dangling currency_id are not silently dropped by join,
    and instead flag UNKNOWN in missing_rate_currencies with total_committed_usd=None."""
    session = db_context["session"]
    _add_rate(session, currency_id=db_context["usd"].currency_id, commercial_rate=48.50)
    service = ProjectService(session)
    project = service.create(ProjectCreate(
        project_name="Dangling Currency PO",
        project_owner="Tester",
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        total_budget_usd=50000.0,
    ))

    # PO with dangling currency_id (no matching currency row)
    po = PurchaseOrder(
        po_number="PO-DANGLING-1",
        project_id=project.project_id,
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        currency_id=9999,
        total_amount_fob=Decimal("7000.00"),
        is_active=True,
    )
    session.add(po)
    session.commit()

    resp = service.get_by_id(project.project_id)
    assert resp.po_count == 1
    assert resp.total_committed_usd is None
    assert resp.remaining_budget_usd is None
    assert resp.missing_rate_currencies == ["UNKNOWN"]
    assert resp.committed_by_currency == {"UNKNOWN": 7000.0}

    # Also verify get_financial_commitments
    commitments = service.get_financial_commitments(project.project_id)
    assert commitments["po_count"] == 1
    assert commitments["total_committed_usd"] is None
    assert commitments["missing_rate_currencies"] == ["UNKNOWN"]
    assert commitments["committed_by_currency"] == {"UNKNOWN": 7000.0}


def test_project_commitments_usd_rate_non_positive(db_context):
    """Test that USD rate <= 0 flags USD in missing_rate_currencies rather than silently dropping."""
    session = db_context["session"]
    # Seed USD rate as 0.0
    _add_rate(session, currency_id=db_context["usd"].currency_id, commercial_rate=0.0)
    _add_rate(session, currency_id=db_context["eur"].currency_id, commercial_rate=50.0)

    service = ProjectService(session)
    project = service.create(ProjectCreate(
        project_name="Zero USD Rate Project",
        project_owner="Tester",
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        total_budget_usd=50000.0,
    ))

    po = PurchaseOrder(
        po_number="PO-EUR-ZERO-USD",
        project_id=project.project_id,
        company_id=db_context["company"].company_id,
        supplier_id=db_context["supplier"].supplier_id,
        incoterm_id=db_context["incoterm"].incoterm_id,
        currency_id=db_context["eur"].currency_id,
        total_amount_fob=Decimal("5000.00"),
        is_active=True,
    )
    session.add(po)
    session.commit()

    resp = service.get_by_id(project.project_id)
    assert resp.total_committed_usd is None
    assert "USD" in resp.missing_rate_currencies


def test_get_all_rate_caching_on_missing_rates(db_context):
    """Test that in get_all(), missing rates are cached and not repeatedly re-queried (no N+1 on missing path)."""
    session = db_context["session"]
    # Do not seed EUR rate
    _add_rate(session, currency_id=db_context["usd"].currency_id, commercial_rate=48.50)

    service = ProjectService(session)
    for i in range(5):
        p = service.create(ProjectCreate(
            project_name=f"Missing Rate Project {i+1}",
            project_owner=f"Owner {i+1}",
            company_id=db_context["company"].company_id,
            supplier_id=db_context["supplier"].supplier_id,
            incoterm_id=db_context["incoterm"].incoterm_id,
            total_budget_usd=30000.0,
        ))
        po = PurchaseOrder(
            po_number=f"PO-MISSING-EUR-{i+1}",
            project_id=p.project_id,
            company_id=db_context["company"].company_id,
            supplier_id=db_context["supplier"].supplier_id,
            incoterm_id=db_context["incoterm"].incoterm_id,
            currency_id=db_context["eur"].currency_id,
            total_amount_fob=Decimal("1000.00"),
            is_active=True,
        )
        session.add(po)
    session.commit()

    results = service.get_all(include_inactive=False)
    # The 5 projects with missing EUR rate should all have total_committed_usd=None and missing_rate_currencies=["EUR"]
    eur_projects = [r for r in results if r.project_name.startswith("Missing Rate Project")]
    assert len(eur_projects) == 5
    for r in eur_projects:
        assert r.total_committed_usd is None
        assert r.missing_rate_currencies == ["EUR"]


