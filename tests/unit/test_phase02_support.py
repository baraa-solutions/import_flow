"""
Shared seed helpers for the Phase 2 (financial approval) tests. No tests live here.

Used by test_phase02_characterization.py and test_financial_approval_guards.py.
"""
from datetime import date
from itertools import count
from typing import Dict, Optional

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base

# Models imported for FK resolution in Base.metadata
from modules.external_service_providers.model import ExternalServiceProvider  # noqa: F401
from modules.transport_locations.model import TransportLocation  # noqa: F401
from modules.import_companies.model import ImportCompany  # noqa: F401
from modules.suppliers.model import Supplier  # noqa: F401
from modules.projects.model import Project  # noqa: F401
from modules.incoterms.model import Incoterm  # noqa: F401
from modules.currencies.model import Currency, ExchangeRate
from modules.customs_tariff.model import CustomsTariff  # noqa: F401
from modules.purchase_orders.model import PurchaseOrder, POLineItem  # noqa: F401
from modules.import_files.model import ImportFile
from modules.shipping_scenarios.model import ShippingEvaluationSession  # noqa: F401
from modules.customs_consultation.model import CustomsConsultationSession
from modules.notifications.model import SystemNotification  # noqa: F401
from modules.smart_tasks.model import SmartTask  # noqa: F401
from modules.lifecycle_board.model import ShipmentStageActivity  # noqa: F401
from modules.financial_approval.model import ImportBudgetApproval, PaymentRequestSession  # noqa: F401
from modules.users.model import User

_seq = count(1)


def make_session() -> Session:
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    return sessionmaker(autocommit=False, autoflush=False, bind=engine)()


def seed_rate(db: Session, code: str, rate: float, base: bool = False) -> Currency:
    cur = Currency(currency_code=code, currency_name=code, currency_symbol=code, is_active=True, is_base_currency=base)
    db.add(cur)
    db.commit()
    if not base:
        db.add(ExchangeRate(currency_id=cur.currency_id, commercial_rate=rate, customs_rate=rate,
                            effective_date=date(2020, 1, 1), is_active=True))
        db.commit()
    return cur


def seed_file(db: Session, **extra) -> ImportFile:
    n = next(_seq)
    imp = ImportFile(
        import_file_code=extra.pop("import_file_code", f"IMP-T-{n:04d}"),
        custom_file_number=f"FILE-T-{n:04d}",
        company_name="Test Importer",
        supplier_name="Test Supplier",
        **extra,
    )
    db.add(imp)
    db.commit()
    db.refresh(imp)
    return imp


def seed_consultation(db: Session, import_file_id: int, duties: float = 0.0, fees: float = 0.0,
                      broker_id: Optional[int] = 1, broker_name: str = "Broker") -> CustomsConsultationSession:
    n = next(_seq)
    cs = CustomsConsultationSession(
        consultation_code=f"CS-T-{n:04d}",
        title="Customs study",
        broker_id=broker_id,
        broker_name=broker_name,
        import_file_id=import_file_id,
        estimated_duties_egp=duties,
        total_broker_fees_egp=fees,
        overall_status="Clearance Ready",
    )
    db.add(cs)
    db.commit()
    return cs


def seed_budget(db: Session, import_file_id: Optional[int], status: str = "Pending Review", **amounts) -> ImportBudgetApproval:
    n = next(_seq)
    values: Dict[str, float] = {
        "invoice_amount_egp": 0.0, "freight_cost_egp": 0.0, "customs_duties_egp": 0.0, "clearance_inland_egp": 0.0,
    }
    values.update(amounts)
    b = ImportBudgetApproval(
        budget_code=f"BGT-T-{n:04d}",
        title=f"Budget {n}",
        import_file_id=import_file_id,
        exchange_rate=50.0,
        total_budget_egp=sum(values[k] for k in ("invoice_amount_egp", "freight_cost_egp",
                                                 "customs_duties_egp", "clearance_inland_egp")),
        budget_status=status,
        is_active=True,
        **values,
    )
    db.add(b)
    db.commit()
    db.refresh(b)
    return b


def admin_user() -> User:
    return User(user_id=9001, username="finance_admin", email="fa@example.com", role="ADMIN", is_active=True)


def plain_user(username: str = "plain_user") -> User:
    return User(user_id=9002, username=username, email=f"{username}@example.com", role="USER", is_active=True)
