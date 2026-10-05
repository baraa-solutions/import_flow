"""
CL-006: Unit Tests for Demurrage & Logistics Alert Engine
Tests the 4 new alert types added to ExpiryCheckerService.
"""
import pytest
from unittest.mock import MagicMock, patch
from datetime import date, datetime, timezone, timedelta


# ─── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def mock_db():
    return MagicMock()


@pytest.fixture
def mock_repo():
    repo = MagicMock()
    repo.exists_active_for_entity.return_value = False
    repo.create.side_effect = lambda schema: schema  # return schema as-is
    return repo


@pytest.fixture
def checker(mock_db, mock_repo):
    from modules.notifications.expiry_checker import ExpiryCheckerService
    svc = ExpiryCheckerService(mock_db)
    svc.repo = mock_repo
    return svc


# ─── Alert 10: Active Demurrage Charges ───────────────────────────────────────

def test_active_demurrage_creates_critical_alert(checker, mock_db):
    """شحنة بغرامات > 0 → CRITICAL notification تُنشأ"""
    session = MagicMock()
    session.tracking_id = 1
    session.import_file_code = "IF-2025-0001"
    session.total_demurrage_fx = 5000.0
    session.total_cost_egp = 247000.0
    session.is_active = True

    mock_db.query.return_value.filter.return_value.all.return_value = [session]

    result = checker._check_active_demurrage_alerts()
    assert len(result) == 1
    created = result[0]
    assert created.severity == "CRITICAL"
    assert "DEMURRAGE_ACTIVE" == created.category
    assert "IF-2025-0001" in created.title


def test_active_demurrage_no_duplicate(checker, mock_db, mock_repo):
    """لا تكرار — exists_active_for_entity True يمنع الإنشاء"""
    mock_repo.exists_active_for_entity.return_value = True

    session = MagicMock()
    session.tracking_id = 1
    session.import_file_code = "IF-2025-0002"
    session.total_demurrage_fx = 3000.0
    session.total_cost_egp = 150000.0
    session.is_active = True

    mock_db.query.return_value.filter.return_value.all.return_value = [session]

    result = checker._check_active_demurrage_alerts()
    assert len(result) == 0


def test_zero_demurrage_no_alert(checker, mock_db):
    """شحنة بغرامات = 0 لا تحتاج تنبيه Alert 10"""
    mock_db.query.return_value.filter.return_value.all.return_value = []

    result = checker._check_active_demurrage_alerts()
    assert len(result) == 0


# ─── Alert 11: Demurrage Free-Time 72-Hour Warning ────────────────────────────

def test_freetime_warning_creates_warning_alert(checker, mock_db):
    """شحنة بـ 2 يوم سماح → WARNING notification تُنشأ"""
    session = MagicMock()
    session.tracking_id = 2
    session.import_file_code = "IF-2025-0003"
    session.free_days_remaining = 2
    session.total_demurrage_fx = 0.0
    session.is_active = True
    session.status = "Free Time Active"

    mock_db.query.return_value.filter.return_value.all.return_value = [session]

    result = checker._check_demurrage_freetime_warning()
    assert len(result) == 1
    created = result[0]
    assert created.severity == "WARNING"
    assert created.category == "DEMURRAGE_WARNING"
    assert "2 days" in created.message
    assert created.msg_code == "NOTIF_DEMURRAGE_WARNING"
    assert created.msg_params["days_left"] == 2


def test_freetime_warning_zero_days_still_triggers(checker, mock_db):
    """شحنة بـ 0 يوم متبقي → تنبيه WARNING يجب أن يُنشأ"""
    session = MagicMock()
    session.tracking_id = 3
    session.import_file_code = "IF-2025-0004"
    session.free_days_remaining = 0
    session.total_demurrage_fx = 0.0
    session.is_active = True
    session.status = "Free Time Active"

    mock_db.query.return_value.filter.return_value.all.return_value = [session]

    result = checker._check_demurrage_freetime_warning()
    assert len(result) == 1


# ─── Alert 12: Incomplete Documents on Arrived Shipments ──────────────────────

def test_incomplete_docs_creates_warning(checker, mock_db):
    """شحنة بنسبة مستندات < 60% → WARNING"""
    from modules.import_files.model import ImportFile

    f = MagicMock(spec=ImportFile)
    f.import_file_id = 10
    f.import_file_code = "IF-2025-0005"
    f.is_active = True
    f.is_customs_released = False
    # فقط 2 مستندات من 7
    f.invoices_data = [{"invoice_no": "INV-1"}]
    f.packing_lists_data = None
    f.acid_number = None
    f.form4_no = None
    f.custom_file_number = None
    f.form46_no = None
    f.pi_number = None

    mock_db.query.return_value.filter.return_value.all.return_value = [f]

    result = checker._check_incomplete_docs_alerts()
    assert len(result) == 1
    assert result[0].category == "INCOMPLETE_DOCS"
    assert result[0].severity == "WARNING"


def test_complete_docs_no_alert(checker, mock_db):
    """شحنة باكتمال مستندي 100% لا تولّد تنبيهاً"""
    from modules.import_files.model import ImportFile

    f = MagicMock(spec=ImportFile)
    f.import_file_id = 11
    f.import_file_code = "IF-2025-0006"
    f.is_active = True
    f.is_customs_released = False
    # كل المستندات موجودة
    f.invoices_data = [{"invoice_no": "INV-1"}]
    f.packing_lists_data = [{"pl_no": "PL-1"}]
    f.acid_number = "ACID-001"
    f.form4_no = "F4-001"
    f.custom_file_number = "CF-001"
    f.form46_no = "46-001"
    f.pi_number = "PI-001"

    mock_db.query.return_value.filter.return_value.all.return_value = [f]

    result = checker._check_incomplete_docs_alerts()
    assert len(result) == 0


# ─── Alert 13: ETA < 48 Hours without Customs Clearance ──────────────────────

def test_eta_customs_alert_triggers(checker, mock_db):
    """شحنة موعد وصولها خلال 24 ساعة بدون إقرار جمركي → CRITICAL"""
    from modules.freight_booking.model import ShipmentBooking
    from modules.import_files.model import ImportFile

    booking = MagicMock(spec=ShipmentBooking)
    booking.import_file_id = 20
    booking.eta = datetime.now(timezone.utc) + timedelta(hours=24)

    import_file = MagicMock(spec=ImportFile)
    import_file.import_file_id = 20
    import_file.import_file_code = "IF-2025-0020"
    import_file.is_active = True
    import_file.form46_no = None
    import_file.custom_file_number = None
    import_file.is_customs_released = False

    mock_db.query.return_value.filter.return_value.all.return_value = [booking]
    mock_db.query.return_value.filter.return_value.first.return_value = import_file

    result = checker._check_eta_customs_readiness_alerts()
    assert len(result) == 1
    assert result[0].category == "ETA_CUSTOMS_ALERT"
    assert result[0].severity == "CRITICAL"
    assert "IF-2025-0020" in result[0].title


# ─── check_all_expiries includes CL-006 methods ───────────────────────────────

def test_check_all_expiries_calls_cl006_methods(checker):
    """التحقق أن check_all_expiries تستدعي الدوال الأربعة الجديدة"""
    checker._check_company_expiries = MagicMock(return_value=[])
    checker._check_acid_expiries = MagicMock(return_value=[])
    checker._check_cargox_upload_alerts = MagicMock(return_value=[])
    checker._check_bank_form4_alerts = MagicMock(return_value=[])
    checker._check_empty_container_detention_alerts = MagicMock(return_value=[])
    checker._check_courier_tracking_alerts = MagicMock(return_value=[])
    checker._check_regulatory_inspection_alerts = MagicMock(return_value=[])
    checker._check_budget_variance_alerts = MagicMock(return_value=[])
    checker._check_currency_fluctuation_alerts = MagicMock(return_value=[])
    checker._check_active_demurrage_alerts = MagicMock(return_value=[])
    checker._check_demurrage_freetime_warning = MagicMock(return_value=[])
    checker._check_incomplete_docs_alerts = MagicMock(return_value=[])
    checker._check_eta_customs_readiness_alerts = MagicMock(return_value=[])

    checker.check_all_expiries()

    checker._check_active_demurrage_alerts.assert_called_once()
    checker._check_demurrage_freetime_warning.assert_called_once()
    checker._check_incomplete_docs_alerts.assert_called_once()
    checker._check_eta_customs_readiness_alerts.assert_called_once()
