import pytest
from datetime import date
from sqlalchemy.orm import Session

from database.database import SessionLocal
from modules.import_files.model import ImportFile
import modules.import_files.repository as repo
import modules.import_files.service as service


@pytest.fixture
def db_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_search_insights_aggregations(db_session: Session):
    # Ensure test records for UX-SEARCH-013 exist
    code1 = "IMP-INSIGHT-001"
    code2 = "IMP-INSIGHT-002"

    file1 = db_session.query(ImportFile).filter(ImportFile.import_file_code == code1).first()
    if not file1:
        file1 = ImportFile(
            import_file_code=code1,
            company_name="Insight Import Co",
            supplier_name="Insight Global Supplier",
            shipment_mode="Sea FCL",
            port_of_loading="Shanghai Port",
            port_of_discharge="Alexandria Port",
            hs_code="8504",
            product_category="Transformers",
            estimated_cost=3200.0,
            estimated_cost_currency="USD",
            actual_landed_cost_total_egp=150000.0,
            file_opening_date=date(2026, 1, 10),
            status="Completed",
            is_active=True,
        )
        db_session.add(file1)

    file2 = db_session.query(ImportFile).filter(ImportFile.import_file_code == code2).first()
    if not file2:
        file2 = ImportFile(
            import_file_code=code2,
            company_name="Insight Import Co",
            supplier_name="Insight Global Supplier",
            shipment_mode="Sea FCL",
            port_of_loading="Shanghai Port",
            port_of_discharge="Alexandria Port",
            hs_code="8504",
            product_category="Transformers",
            estimated_cost=3400.0,
            estimated_cost_currency="USD",
            actual_landed_cost_total_egp=160000.0,
            file_opening_date=date(2026, 3, 15),
            status="In Progress",
            is_active=True,
        )
        db_session.add(file2)
    db_session.commit()

    # Query insights for this supplier & HS code
    insights = repo.get_search_insights(
        db_session,
        search="Insight Global Supplier",
        hs_code="8504",
    )

    assert insights["total_count"] >= 2
    assert "Shanghai Port → Alexandria Port" in (insights["mode_route"] or "")
    assert insights["mode_shipping_mode"] == "Sea FCL"
    assert insights["latest_freight_cost"] is not None
    assert insights["latest_freight_currency"] == "USD"
    assert insights["avg_landed_cost"] is not None
    assert insights["avg_landed_currency"] == "EGP"
