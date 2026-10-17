"""
Unit tests for BE01-T03: Collision-safe business codes for consultations, price lists, expense types, and RFQs.
Verifies that:
- Cloned records (e.g. CUS-2026-003-COPY, PL-2026-003-COPY) do not break numeric sequences.
- Custom/non-numeric suffixes (e.g. EXP-CUSTOM, RFQ-2026-003-COPY) are ignored by sequence generators.
- Sequences continue from the highest valid numeric suffix.
- Years are isolated (a previous year's high number does not pollute the current year).
- Concurrency collisions trigger up to 3 retries, succeeding if resolved, or raising 409 if exhausted.
"""
from datetime import date, datetime, timezone
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import main  # noqa: F401
from database.database import Base
from modules.external_service_providers.model import ExternalServiceProvider
from modules.customs_consultation.model import (
    ClearanceExpenseType,
    BrokerPriceList,
    CustomsConsultationSession,
)
from modules.customs_consultation.schemas import (
    ClearanceExpenseTypeCreate,
    BrokerPriceListCreate,
    CloneBrokerPriceListRequest,
    CustomsConsultationCreate,
    CloneConsultationRequest,
)
from modules.customs_consultation.repository import (
    ClearanceExpenseTypeRepository,
    BrokerPriceListRepository,
    CustomsConsultationRepository,
)
from modules.customs_consultation.service import (
    ClearanceExpenseTypeService,
    BrokerPriceListService,
    CustomsConsultationService,
)
from modules.freight_quotations.model import FreightRFQRequest
from modules.freight_quotations.schemas import (
    FreightRFQRequestCreate,
    FreightQuotationItemCreate,
)
from modules.freight_quotations.repository import FreightQuotationRepository
from modules.freight_quotations.service import FreightQuotationService


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Seed required broker and carrier
    broker = ExternalServiceProvider(
        provider_id=1,
        partner_code="PRT-BRK-001",
        partner_name="مكتب النسر للتخليص الجمركي",
        partner_type="Customs Broker",
        is_active=True,
    )
    carrier = ExternalServiceProvider(
        provider_id=2,
        partner_code="PRT-CAR-001",
        partner_name="Maersk Line Egypt",
        partner_type="Shipping Line",
        is_active=True,
    )
    session.add_all([broker, carrier])
    session.commit()

    yield session
    session.close()


# ==============================================================================
# 1. Customs Consultation Codes (CUS)
# ==============================================================================

def test_consultation_code_after_clone_copy(db_session):
    year = datetime.now(timezone.utc).year

    # Create CUS-YYYY-001 .. CUS-YYYY-003
    for i in range(1, 4):
        sess = CustomsConsultationSession(
            consultation_code=f"CUS-{year}-{i:03d}",
            title=f"Consultation {i}",
            broker_id=1,
            broker_name="مكتب النسر",
            overall_status="Draft",
            is_active=True,
        )
        db_session.add(sess)
    db_session.commit()

    # Clone the 3rd consultation with default -COPY code
    original = CustomsConsultationRepository.get_by_code(db_session, f"CUS-{year}-003")
    cloned = CustomsConsultationService.clone_consultation(
        db_session,
        original.consultation_id,
        CloneConsultationRequest(new_title="Cloned Consultation"),
    )
    assert cloned.consultation_code == f"CUS-{year}-003-COPY"

    # Next generated code must be CUS-YYYY-004
    next_code = CustomsConsultationRepository.generate_consultation_code(db_session)
    assert next_code == f"CUS-{year}-004"

    # Creating a new consultation through the service must succeed with CUS-YYYY-004
    created = CustomsConsultationService.create_consultation(
        db_session,
        CustomsConsultationCreate(
            title="Fresh Consultation",
            broker_id=1,
            broker_name="مكتب النسر",
        ),
    )
    assert created.consultation_code == f"CUS-{year}-004"


# ==============================================================================
# 2. Broker Price List Codes (PL)
# ==============================================================================

def test_price_list_code_after_clone_copy(db_session):
    year = datetime.now(timezone.utc).year

    # Create PL-YYYY-001 .. PL-YYYY-003
    for i in range(1, 4):
        pl = BrokerPriceList(
            price_list_code=f"PL-{year}-{i:03d}",
            title=f"Price List {i}",
            broker_id=1,
            broker_name="مكتب النسر",
            effective_from=date(year, 1, 1),
            version=1,
            is_active=True,
        )
        db_session.add(pl)
    db_session.commit()

    # Clone the 3rd price list with default -COPY code
    original = BrokerPriceListRepository.get_by_code(db_session, f"PL-{year}-003")
    cloned = BrokerPriceListService.clone_price_list(
        db_session,
        original.price_list_id,
        CloneBrokerPriceListRequest(new_title="Cloned Price List"),
    )
    assert cloned.price_list_code == f"PL-{year}-003-COPY"

    # Next generated code must be PL-YYYY-004
    next_code = BrokerPriceListRepository.generate_price_list_code(db_session)
    assert next_code == f"PL-{year}-004"

    # Creating a new price list through the service must succeed with PL-YYYY-004
    created = BrokerPriceListService.create_price_list(
        db_session,
        BrokerPriceListCreate(
            title="Fresh Price List",
            broker_id=1,
            broker_name="مكتب النسر",
            effective_from=date(year, 6, 1),
        ),
    )
    assert created.price_list_code == f"PL-{year}-004"


# ==============================================================================
# 3. Clearance Expense Type Codes (EXP)
# ==============================================================================

def test_expense_code_skips_non_digits_and_gaps(db_session):
    # Insert EXP-001, EXP-CUSTOM, EXP-007
    exp1 = ClearanceExpenseType(
        expense_code="EXP-001",
        name_ar="مصروف 1",
        category="Clearance Fees",
        is_active=True,
    )
    exp_custom = ClearanceExpenseType(
        expense_code="EXP-CUSTOM",
        name_ar="مصروف مخصص",
        category="Custom Fees",
        is_active=True,
    )
    exp7 = ClearanceExpenseType(
        expense_code="EXP-007",
        name_ar="مصروف 7",
        category="Inspection Fees",
        is_active=True,
    )
    db_session.add_all([exp1, exp_custom, exp7])
    db_session.commit()

    # Next generated code must be EXP-008
    next_code = ClearanceExpenseTypeRepository.generate_expense_code(db_session)
    assert next_code == "EXP-008"

    # Create through service with auto-generated code
    created = ClearanceExpenseTypeService.create_expense_type(
        db_session,
        ClearanceExpenseTypeCreate(
            name_ar="مصروف جديد",
            category="Clearance Fees",
        ),
    )
    assert created.expense_code == "EXP-008"


# ==============================================================================
# 4. Freight RFQ Codes (RFQ)
# ==============================================================================

def test_rfq_code_skips_non_digits_and_gaps(db_session):
    year = datetime.now(timezone.utc).year

    # Insert RFQ-YYYY-001, RFQ-YYYY-003-COPY, RFQ-YYYY-005
    rfq1 = FreightRFQRequest(
        rfq_code=f"RFQ-{year}-001",
        title="RFQ 1",
        crd_date=date(year, 4, 1),
        pol_name="Shanghai",
        pod_name="Alexandria",
        is_active=True,
    )
    rfq_copy = FreightRFQRequest(
        rfq_code=f"RFQ-{year}-003-COPY",
        title="RFQ Copy",
        crd_date=date(year, 4, 1),
        pol_name="Ningbo",
        pod_name="Dekheila",
        is_active=True,
    )
    rfq5 = FreightRFQRequest(
        rfq_code=f"RFQ-{year}-005",
        title="RFQ 5",
        crd_date=date(year, 4, 1),
        pol_name="Shenzhen",
        pod_name="Sokhna",
        is_active=True,
    )
    db_session.add_all([rfq1, rfq_copy, rfq5])
    db_session.commit()

    # Next generated code must be RFQ-YYYY-006
    next_code = FreightQuotationRepository.generate_rfq_code(db_session)
    assert next_code == f"RFQ-{year}-006"

    # Create through service
    created = FreightQuotationService.create_rfq(
        db_session,
        FreightRFQRequestCreate(
            title="Fresh RFQ",
            crd_date=date(year, 5, 1),
            pol_name="Qingdao",
            pod_name="Alexandria",
        ),
    )
    assert created.rfq_code == f"RFQ-{year}-006"


# ==============================================================================
# 5. Yearly Isolation
# ==============================================================================

def test_yearly_isolation(db_session):
    prev_year = 2025
    curr_year = 2026

    # Insert old-year records
    db_session.add(
        CustomsConsultationSession(
            consultation_code=f"CUS-{prev_year}-099",
            title="Old Consultation",
            broker_id=1,
            broker_name="مكتب النسر",
            is_active=True,
        )
    )
    db_session.add(
        BrokerPriceList(
            price_list_code=f"PL-{prev_year}-088",
            title="Old Price List",
            broker_id=1,
            broker_name="مكتب النسر",
            effective_from=date(prev_year, 1, 1),
            is_active=True,
        )
    )
    db_session.add(
        FreightRFQRequest(
            rfq_code=f"RFQ-{prev_year}-077",
            title="Old RFQ",
            crd_date=date(prev_year, 1, 1),
            pol_name="Shanghai",
            pod_name="Alexandria",
            is_active=True,
        )
    )
    db_session.commit()

    # 2026 sequences must start at 001
    assert CustomsConsultationRepository.generate_consultation_code(db_session, year=curr_year) == f"CUS-{curr_year}-001"
    assert BrokerPriceListRepository.generate_price_list_code(db_session, year=curr_year) == f"PL-{curr_year}-001"
    assert FreightQuotationRepository.generate_rfq_code(db_session, year=curr_year) == f"RFQ-{curr_year}-001"


# ==============================================================================
# 6. Concurrency Collision & Retry Tests
# ==============================================================================

def test_consultation_collision_retry_success(db_session, monkeypatch):
    year = datetime.now(timezone.utc).year

    # Seed CUS-YYYY-001
    db_session.add(
        CustomsConsultationSession(
            consultation_code=f"CUS-{year}-001",
            title="Existing Consultation",
            broker_id=1,
            broker_name="مكتب النسر",
            is_active=True,
        )
    )
    db_session.commit()

    attempt_count = 0
    orig_generate = CustomsConsultationRepository.generate_consultation_code

    def colliding_generate(db, year=None):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count == 1:
            # First attempt collides with existing record
            return f"CUS-{year or datetime.now(timezone.utc).year}-001"
        return orig_generate(db, year=year)

    monkeypatch.setattr(CustomsConsultationRepository, "generate_consultation_code", colliding_generate)

    created = CustomsConsultationService.create_consultation(
        db_session,
        CustomsConsultationCreate(
            title="Retry Consultation",
            broker_id=1,
            broker_name="مكتب النسر",
        ),
    )
    assert attempt_count == 2
    assert created.consultation_code == f"CUS-{year}-002"


def test_consultation_collision_exhausted_raises_409(db_session, monkeypatch):
    year = datetime.now(timezone.utc).year

    # Seed CUS-YYYY-001
    db_session.add(
        CustomsConsultationSession(
            consultation_code=f"CUS-{year}-001",
            title="Existing Consultation",
            broker_id=1,
            broker_name="مكتب النسر",
            is_active=True,
        )
    )
    db_session.commit()

    # Always collides
    monkeypatch.setattr(
        CustomsConsultationRepository,
        "generate_consultation_code",
        lambda db, year=None: f"CUS-{year or datetime.now(timezone.utc).year}-001",
    )

    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(
            db_session,
            CustomsConsultationCreate(
                title="Failing Consultation",
                broker_id=1,
                broker_name="مكتب النسر",
            ),
        )
    assert exc_info.value.status_code == 409
    assert "مستخدم بالفعل" in str(exc_info.value.detail)


def test_price_list_collision_retry_success(db_session, monkeypatch):
    year = datetime.now(timezone.utc).year

    # Seed PL-YYYY-001
    db_session.add(
        BrokerPriceList(
            price_list_code=f"PL-{year}-001",
            title="Existing Price List",
            broker_id=1,
            broker_name="مكتب النسر",
            effective_from=date(year, 1, 1),
            is_active=True,
        )
    )
    db_session.commit()

    attempt_count = 0
    orig_generate = BrokerPriceListRepository.generate_price_list_code

    def colliding_generate(db, year=None):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count == 1:
            return f"PL-{year or datetime.now(timezone.utc).year}-001"
        return orig_generate(db, year=year)

    monkeypatch.setattr(BrokerPriceListRepository, "generate_price_list_code", colliding_generate)

    created = BrokerPriceListService.create_price_list(
        db_session,
        BrokerPriceListCreate(
            title="Retry Price List",
            broker_id=1,
            broker_name="مكتب النسر",
            effective_from=date(year, 1, 1),
        ),
    )
    assert attempt_count == 2
    assert created.price_list_code == f"PL-{year}-002"


def test_price_list_collision_exhausted_raises_409(db_session, monkeypatch):
    year = datetime.now(timezone.utc).year

    # Seed PL-YYYY-001
    db_session.add(
        BrokerPriceList(
            price_list_code=f"PL-{year}-001",
            title="Existing Price List",
            broker_id=1,
            broker_name="مكتب النسر",
            effective_from=date(year, 1, 1),
            is_active=True,
        )
    )
    db_session.commit()

    monkeypatch.setattr(
        BrokerPriceListRepository,
        "generate_price_list_code",
        lambda db, year=None: f"PL-{year or datetime.now(timezone.utc).year}-001",
    )

    with pytest.raises(HTTPException) as exc_info:
        BrokerPriceListService.create_price_list(
            db_session,
            BrokerPriceListCreate(
                title="Failing Price List",
                broker_id=1,
                broker_name="مكتب النسر",
                effective_from=date(year, 1, 1),
            ),
        )
    assert exc_info.value.status_code == 409
    assert "مستخدم بالفعل" in str(exc_info.value.detail)


def test_expense_type_collision_retry_success(db_session, monkeypatch):
    # Seed EXP-001
    db_session.add(
        ClearanceExpenseType(
            expense_code="EXP-001",
            name_ar="مصروف قائم",
            category="Clearance Fees",
            is_active=True,
        )
    )
    db_session.commit()

    attempt_count = 0
    orig_generate = ClearanceExpenseTypeRepository.generate_expense_code

    def colliding_generate(db):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count == 1:
            return "EXP-001"
        return orig_generate(db)

    monkeypatch.setattr(ClearanceExpenseTypeRepository, "generate_expense_code", colliding_generate)

    created = ClearanceExpenseTypeService.create_expense_type(
        db_session,
        ClearanceExpenseTypeCreate(
            name_ar="مصروف جديد",
            category="Clearance Fees",
        ),
    )
    assert attempt_count == 2
    assert created.expense_code == "EXP-002"


def test_expense_type_collision_exhausted_raises_409(db_session, monkeypatch):
    # Seed EXP-001
    db_session.add(
        ClearanceExpenseType(
            expense_code="EXP-001",
            name_ar="مصروف قائم",
            category="Clearance Fees",
            is_active=True,
        )
    )
    db_session.commit()

    monkeypatch.setattr(
        ClearanceExpenseTypeRepository,
        "generate_expense_code",
        lambda db: "EXP-001",
    )

    with pytest.raises(HTTPException) as exc_info:
        ClearanceExpenseTypeService.create_expense_type(
            db_session,
            ClearanceExpenseTypeCreate(
                name_ar="مصروف فاشل",
                category="Clearance Fees",
            ),
        )
    assert exc_info.value.status_code == 409
    assert "مستخدم بالفعل" in str(exc_info.value.detail)


def test_rfq_collision_retry_success(db_session, monkeypatch):
    year = datetime.now(timezone.utc).year

    # Seed RFQ-YYYY-001
    db_session.add(
        FreightRFQRequest(
            rfq_code=f"RFQ-{year}-001",
            title="Existing RFQ",
            crd_date=date(year, 4, 1),
            pol_name="Shanghai",
            pod_name="Alexandria",
            is_active=True,
        )
    )
    db_session.commit()

    attempt_count = 0
    orig_generate = FreightQuotationRepository.generate_rfq_code

    def colliding_generate(db, year=None):
        nonlocal attempt_count
        attempt_count += 1
        if attempt_count == 1:
            return f"RFQ-{year or datetime.now(timezone.utc).year}-001"
        return orig_generate(db, year=year)

    monkeypatch.setattr(FreightQuotationRepository, "generate_rfq_code", colliding_generate)

    created = FreightQuotationService.create_rfq(
        db_session,
        FreightRFQRequestCreate(
            title="Retry RFQ",
            crd_date=date(year, 5, 1),
            pol_name="Ningbo",
            pod_name="Dekheila",
        ),
    )
    assert attempt_count == 2
    assert created.rfq_code == f"RFQ-{year}-002"


def test_rfq_collision_exhausted_raises_409(db_session, monkeypatch):
    year = datetime.now(timezone.utc).year

    # Seed RFQ-YYYY-001
    db_session.add(
        FreightRFQRequest(
            rfq_code=f"RFQ-{year}-001",
            title="Existing RFQ",
            crd_date=date(year, 4, 1),
            pol_name="Shanghai",
            pod_name="Alexandria",
            is_active=True,
        )
    )
    db_session.commit()

    monkeypatch.setattr(
        FreightQuotationRepository,
        "generate_rfq_code",
        lambda db, year=None: f"RFQ-{year or datetime.now(timezone.utc).year}-001",
    )

    with pytest.raises(HTTPException) as exc_info:
        FreightQuotationService.create_rfq(
            db_session,
            FreightRFQRequestCreate(
                title="Failing RFQ",
                crd_date=date(year, 5, 1),
                pol_name="Shenzhen",
                pod_name="Sokhna",
            ),
        )
    assert exc_info.value.status_code == 409
    assert "مستخدم بالفعل" in str(exc_info.value.detail)
