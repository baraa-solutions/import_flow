"""
Unit tests for BE01-T12:
Consultation validation: FKs, clone guard, null clearing, money inputs, price-list dates.
"""
from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database.database import Base
from modules.auth.seed_rbac import seed_rbac
from modules.common.errors import CodedHTTPException
from modules.currencies.model import Currency, ExchangeRate
from modules.currencies.service import clear_currency_cache
from modules.customs_consultation.model import (
    BrokerPriceList,
    BrokerPriceListItem,
    ClearanceExpenseType,
    CustomsConsultationSession,
)
from modules.customs_consultation.schemas import (
    BrokerPriceListCreate,
    BrokerPriceListItemCreate,
    BrokerPriceListItemUpdate,
    BrokerPriceListUpdate,
    ClearanceExpenseTypeCreate,
    ClearanceExpenseTypeUpdate,
    CloneBrokerPriceListRequest,
    CloneConsultationRequest,
    CustomsBrokerQuoteItemCreate,
    CustomsChecklistItemCreate,
    CustomsConsultationCreate,
    CustomsConsultationUpdate,
)
from modules.customs_consultation.service import (
    BrokerPriceListService,
    ClearanceExpenseTypeService,
    CustomsConsultationService,
)
from modules.external_service_providers.model import ExternalServiceProvider
from modules.import_files.model import ImportFile
from modules.projects.model import Project
from modules.purchase_orders.model import PurchaseOrder


@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    clear_currency_cache()
    yield sessionmaker(bind=engine, autoflush=False)
    clear_currency_cache()
    engine.dispose()


@pytest.fixture
def db(session_factory):
    session = session_factory()
    seed_rbac(session)

    # Base currencies
    egp = Currency(currency_id=1, currency_code="EGP", currency_name="Egyptian Pound", currency_symbol="EGP", is_active=True)
    session.add(egp)

    # Active broker
    broker = ExternalServiceProvider(
        provider_id=1,
        partner_code="BRK-001",
        partner_name="Speedy Customs Broker",
        partner_type="Customs Broker",
        is_active=True,
    )
    # Inactive broker
    inactive_broker = ExternalServiceProvider(
        provider_id=2,
        partner_code="BRK-002",
        partner_name="Inactive Customs Broker",
        partner_type="Customs Broker",
        is_active=False,
    )

    # Active ImportFile
    imp_file = ImportFile(
        import_file_id=1,
        import_file_code="IMP-2026-001",
        company_name="Test Company",
        supplier_name="Test Supplier",
        is_active=True,
    )
    # Inactive ImportFile
    inactive_file = ImportFile(
        import_file_id=2,
        import_file_code="IMP-2026-002",
        company_name="Inactive Company",
        supplier_name="Inactive Supplier",
        is_active=False,
    )
    # Target ImportFile for clone
    target_file = ImportFile(
        import_file_id=3,
        import_file_code="IMP-2026-003",
        company_name="Target Company",
        supplier_name="Target Supplier",
        is_active=True,
    )

    # Active Project
    project = Project(
        project_id=1,
        project_code="PRJ-001",
        project_name="Solar Project",
        project_owner="Eng. Ahmed",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        is_active=True,
    )
    inactive_project = Project(
        project_id=2,
        project_code="PRJ-002",
        project_name="Inactive Project",
        project_owner="Eng. Ahmed",
        company_id=1,
        supplier_id=1,
        incoterm_id=1,
        is_active=False,
    )

    # Active PO
    po = PurchaseOrder(
        po_id=1,
        po_number="PO-2026-001",
        supplier_id=1,
        company_id=1,
        project_id=1,
        currency_id=1,
        incoterm_id=1,
        is_active=True,
    )
    inactive_po = PurchaseOrder(
        po_id=2,
        po_number="PO-2026-002",
        supplier_id=1,
        company_id=1,
        project_id=1,
        currency_id=1,
        incoterm_id=1,
        is_active=False,
    )

    # Active Expense Type
    exp_type = ClearanceExpenseType(
        expense_id=1,
        expense_code="EXP-001",
        name_ar="رسوم التخليص الجمركي",
        category="CLEARANCE_FEES",
        default_unit="PER_INVOICE",
        default_currency="EGP",
        is_active=True,
    )
    inactive_exp_type = ClearanceExpenseType(
        expense_id=2,
        expense_code="EXP-002",
        name_ar="مصروف ملغى",
        category="CLEARANCE_FEES",
        default_unit="PER_INVOICE",
        default_currency="EGP",
        is_active=False,
    )

    session.add_all([
        broker, inactive_broker,
        imp_file, inactive_file, target_file,
        project, inactive_project,
        po, inactive_po,
        exp_type, inactive_exp_type,
    ])
    session.commit()

    yield session
    session.close()


# ==============================================================================
# 1. Broker validation (active and exists)
# ==============================================================================

def test_create_consultation_unknown_broker_fails(db):
    payload = CustomsConsultationCreate(
        title="Study 1",
        broker_id=9999,
        broker_name="Nonexistent Broker",
    )
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(db, payload)
    assert exc_info.value.status_code == 400
    assert "المخلص الجمركي رقم 9999 غير موجود أو غير نشط." in exc_info.value.detail


def test_create_consultation_inactive_broker_fails(db):
    payload = CustomsConsultationCreate(
        title="Study Inactive Broker",
        broker_id=2,  # inactive
        broker_name="Inactive Broker",
    )
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(db, payload)
    assert exc_info.value.status_code == 400
    assert "المخلص الجمركي رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


def test_update_consultation_inactive_broker_fails(db):
    # First create valid consultation
    created = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="Valid Study", broker_id=1, broker_name="Speedy Broker")
    )
    # Update with inactive broker
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.update_consultation(
            db, created.consultation_id, CustomsConsultationUpdate(broker_id=2)
        )
    assert exc_info.value.status_code == 400
    assert "المخلص الجمركي رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


def test_create_price_list_inactive_broker_fails(db):
    payload = BrokerPriceListCreate(
        title="Price List Inactive Broker",
        broker_id=2,  # inactive
        broker_name="Inactive Broker",
        effective_from=date.today(),
    )
    with pytest.raises(HTTPException) as exc_info:
        BrokerPriceListService.create_price_list(db, payload)
    assert exc_info.value.status_code == 400
    assert "المخلص الجمركي رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


def test_update_price_list_inactive_broker_fails(db):
    created = BrokerPriceListService.create_price_list(
        db,
        BrokerPriceListCreate(
            title="Valid Price List",
            broker_id=1,
            broker_name="Speedy Broker",
            effective_from=date.today(),
        ),
    )
    with pytest.raises(HTTPException) as exc_info:
        BrokerPriceListService.update_price_list(
            db, created.price_list_id, BrokerPriceListUpdate(broker_id=2)
        )
    assert exc_info.value.status_code == 400
    assert "المخلص الجمركي رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


# ==============================================================================
# 2. Master & transaction references validation (require_active)
# ==============================================================================

def test_create_consultation_inactive_import_file_fails(db):
    payload = CustomsConsultationCreate(
        title="Study Inactive File",
        broker_id=1,
        broker_name="Speedy Broker",
        import_file_id=2,  # inactive
    )
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(db, payload)
    assert exc_info.value.status_code == 400
    assert "ملف الاستيراد رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


def test_create_consultation_inactive_po_fails(db):
    payload = CustomsConsultationCreate(
        title="Study Inactive PO",
        broker_id=1,
        broker_name="Speedy Broker",
        po_id=2,  # inactive
    )
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(db, payload)
    assert exc_info.value.status_code == 400
    assert "أمر الشراء رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


def test_create_consultation_inactive_project_fails(db):
    payload = CustomsConsultationCreate(
        title="Study Inactive Project",
        broker_id=1,
        broker_name="Speedy Broker",
        project_id=2,  # inactive
    )
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(db, payload)
    assert exc_info.value.status_code == 400
    assert "المشروع رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


def test_create_consultation_inactive_price_list_fails(db):
    # Create inactive price list
    pl = BrokerPriceList(
        price_list_code="PL-999",
        title="Inactive PL",
        broker_id=1,
        broker_name="Speedy Broker",
        effective_from=date.today(),
        is_active=False,
    )
    db.add(pl)
    db.commit()

    payload = CustomsConsultationCreate(
        title="Study Inactive PL",
        broker_id=1,
        broker_name="Speedy Broker",
        broker_price_list_id=pl.price_list_id,
    )
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(db, payload)
    assert exc_info.value.status_code == 400
    assert f"قائمة أسعار المخلص رقم {pl.price_list_id} غير موجود أو غير نشط." in exc_info.value.detail


def test_create_consultation_inactive_expense_type_in_quote_fails(db):
    payload = CustomsConsultationCreate(
        title="Study Inactive Expense",
        broker_id=1,
        broker_name="Speedy Broker",
        broker_quote_items=[
            CustomsBrokerQuoteItemCreate(
                expense_type_id=2,  # inactive
                expense_name="Inactive Expense",
                category="Customs",
                unit_price=100.0,
            )
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.create_consultation(db, payload)
    assert exc_info.value.status_code == 400
    assert "نوع المصروف رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


def test_create_price_list_inactive_expense_type_fails(db):
    payload = BrokerPriceListCreate(
        title="PL Inactive Item",
        broker_id=1,
        broker_name="Speedy Broker",
        effective_from=date.today(),
        items=[
            BrokerPriceListItemCreate(
                expense_type_id=2,  # inactive
                expense_name="Inactive Expense",
                category="Customs",
                unit_type="Per Invoice",
                standard_price=150.0,
            )
        ],
    )
    with pytest.raises(HTTPException) as exc_info:
        BrokerPriceListService.create_price_list(db, payload)
    assert exc_info.value.status_code == 400
    assert "نوع المصروف رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


# ==============================================================================
# 3. Clone guard (_check_one_per_file and require_active)
# ==============================================================================

def test_clone_consultation_same_file_fails_with_409_consultation_exists(db):
    # Create consultation linked to import file 1
    created = CustomsConsultationService.create_consultation(
        db,
        CustomsConsultationCreate(
            title="Original Study",
            broker_id=1,
            broker_name="Speedy Broker",
            import_file_id=1,
        ),
    )
    # Clone without target_import_file_id retains original file -> 409
    req = CloneConsultationRequest(new_title="Cloned Study")
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.clone_consultation(db, created.consultation_id, req)
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "CONSULTATION_EXISTS"


def test_clone_consultation_into_target_file_with_existing_study_fails_with_409(db):
    c1 = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="Study 1", broker_id=1, broker_name="Speedy Broker", import_file_id=1)
    )
    # Create study on target file 3
    c2 = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="Study 3", broker_id=1, broker_name="Speedy Broker", import_file_id=3)
    )
    # Attempt to clone c1 into target file 3 which already has c2
    req = CloneConsultationRequest(new_title="Cloned into 3", target_import_file_id=3)
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.clone_consultation(db, c1.consultation_id, req)
    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "CONSULTATION_EXISTS"


def test_clone_consultation_into_inactive_target_file_fails_with_400(db):
    c1 = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="Study 1", broker_id=1, broker_name="Speedy Broker", import_file_id=1)
    )
    req = CloneConsultationRequest(new_title="Cloned into Inactive", target_import_file_id=2)  # file 2 is inactive
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.clone_consultation(db, c1.consultation_id, req)
    assert exc_info.value.status_code == 400
    assert "ملف الاستيراد رقم 2 غير موجود أو غير نشط." in exc_info.value.detail


def test_clone_consultation_into_clean_active_file_succeeds(db):
    c1 = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="Study 1", broker_id=1, broker_name="Speedy Broker", import_file_id=1)
    )
    # File 3 has no consultation yet
    req = CloneConsultationRequest(new_title="Cloned into File 3", target_import_file_id=3)
    cloned = CustomsConsultationService.clone_consultation(db, c1.consultation_id, req)
    assert cloned.consultation_id != c1.consultation_id
    assert cloned.import_file_id == 3
    assert cloned.title == "Cloned into File 3"


# ==============================================================================
# 4. Explicit null clearing on NOT NULL columns rejected with 400
# ==============================================================================

def test_update_consultation_explicit_null_on_title_fails(db):
    created = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="Valid Study", broker_id=1, broker_name="Speedy Broker")
    )
    payload = CustomsConsultationUpdate.model_validate({"title": None})
    with pytest.raises(HTTPException) as exc_info:
        CustomsConsultationService.update_consultation(db, created.consultation_id, payload)
    assert exc_info.value.status_code == 400
    assert "لا يمكن مسح الحقل الإلزامي 'title' في دراسة الاستشارة الجمركية." in exc_info.value.detail


def test_update_consultation_explicit_null_on_broker_id_is_allowed(db):
    # FE01-T02: broker_id is nullable (tax review mode has no broker), so clearing it is not a NOT NULL violation.
    created = CustomsConsultationService.create_consultation(
        db, CustomsConsultationCreate(title="Valid Study", broker_id=1, broker_name="Speedy Broker")
    )
    payload = CustomsConsultationUpdate.model_validate({"broker_id": None})
    updated = CustomsConsultationService.update_consultation(db, created.consultation_id, payload)
    assert updated.broker_id is None


def test_update_price_list_explicit_null_on_effective_from_fails(db):
    created = BrokerPriceListService.create_price_list(
        db,
        BrokerPriceListCreate(
            title="Valid Price List",
            broker_id=1,
            broker_name="Speedy Broker",
            effective_from=date.today(),
        ),
    )
    payload = BrokerPriceListUpdate.model_validate({"effective_from": None})
    with pytest.raises(HTTPException) as exc_info:
        BrokerPriceListService.update_price_list(db, created.price_list_id, payload)
    assert exc_info.value.status_code == 400
    assert "لا يمكن مسح الحقل الإلزامي 'effective_from' في قائمة أسعار المخلص." in exc_info.value.detail


def test_update_expense_type_explicit_null_on_expense_code_fails(db):
    payload = ClearanceExpenseTypeUpdate.model_validate({"expense_code": None})
    with pytest.raises(HTTPException) as exc_info:
        ClearanceExpenseTypeService.update_expense_type(db, 1, payload)
    assert exc_info.value.status_code == 400
    assert "لا يمكن مسح الحقل الإلزامي 'expense_code' في نوع المصروف." in exc_info.value.detail


# ==============================================================================
# 5. Money inputs bounds (ge=0, gt=0)
# ==============================================================================

def test_broker_price_list_item_negative_prices_rejected():
    with pytest.raises(ValidationError):
        BrokerPriceListItemCreate(
            expense_name="Test Item",
            category="Customs",
            unit_type="Per Invoice",
            standard_price=-10.0,
        )

    with pytest.raises(ValidationError):
        BrokerPriceListItemCreate(
            expense_name="Test Item",
            category="Customs",
            unit_type="Per Invoice",
            min_price=-5.0,
        )

    with pytest.raises(ValidationError):
        BrokerPriceListItemCreate(
            expense_name="Test Item",
            category="Customs",
            unit_type="Per Invoice",
            max_price=-1.0,
        )


def test_quote_item_negative_unit_price_or_zero_qty_rejected():
    with pytest.raises(ValidationError):
        CustomsBrokerQuoteItemCreate(
            expense_name="Test Item",
            category="Customs",
            unit_price=-10.0,
            qty=1.0,
        )

    with pytest.raises(ValidationError):
        CustomsBrokerQuoteItemCreate(
            expense_name="Test Item",
            category="Customs",
            unit_price=10.0,
            qty=0.0,  # gt=0 required
        )

    with pytest.raises(ValidationError):
        CustomsBrokerQuoteItemCreate(
            expense_name="Test Item",
            category="Customs",
            unit_price=10.0,
            qty=-1.0,
        )


# ==============================================================================
# 6. Price list date range validation (effective_to >= effective_from)
# ==============================================================================

def test_price_list_create_effective_to_before_from_fails_pydantic():
    today = date.today()
    yesterday = today - timedelta(days=1)
    with pytest.raises(ValidationError) as exc_info:
        BrokerPriceListCreate(
            title="Invalid Dates",
            broker_id=1,
            broker_name="Speedy Broker",
            effective_from=today,
            effective_to=yesterday,
        )
    assert "تاريخ انتهاء السريان يجب أن يكون بعد أو يساوي تاريخ بدء السريان." in str(exc_info.value)


def test_price_list_update_effective_to_before_from_fails_pydantic():
    today = date.today()
    yesterday = today - timedelta(days=1)
    with pytest.raises(ValidationError) as exc_info:
        BrokerPriceListUpdate(
            effective_from=today,
            effective_to=yesterday,
        )
    assert "تاريخ انتهاء السريان يجب أن يكون بعد أو يساوي تاريخ بدء السريان." in str(exc_info.value)


def test_clone_price_list_effective_to_before_from_fails_pydantic():
    today = date.today()
    yesterday = today - timedelta(days=1)
    with pytest.raises(ValidationError) as exc_info:
        CloneBrokerPriceListRequest(
            new_title="Invalid Clone Dates",
            effective_from=today,
            effective_to=yesterday,
        )
    assert "تاريخ انتهاء السريان يجب أن يكون بعد أو يساوي تاريخ بدء السريان." in str(exc_info.value)


def test_update_price_list_service_cross_dates_validation(db):
    today = date.today()
    created = BrokerPriceListService.create_price_list(
        db,
        BrokerPriceListCreate(
            title="Price List 2026",
            broker_id=1,
            broker_name="Speedy Broker",
            effective_from=today,
            effective_to=today + timedelta(days=30),
        ),
    )
    # Updating only effective_to to before stored effective_from -> 422
    with pytest.raises(HTTPException) as exc_info:
        BrokerPriceListService.update_price_list(
            db,
            created.price_list_id,
            BrokerPriceListUpdate(effective_to=today - timedelta(days=5)),
        )
    assert exc_info.value.status_code == 422
    assert "تاريخ انتهاء السريان يجب أن يكون بعد أو يساوي تاريخ بدء السريان." in exc_info.value.detail
