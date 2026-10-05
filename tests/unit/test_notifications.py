import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from modules.notifications.schemas import NotificationCreate
from modules.notifications.service import NotificationService


class TestNotificationsModule(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        Base.metadata.create_all(bind=self.engine)
        self.db = TestingSessionLocal()
        self.service = NotificationService(self.db)

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    def test_create_and_fetch_notification(self):
        schema = NotificationCreate(
            title="تنبيه تجريبي من الاختبارات",
            message="هذا الإشعار لتجربة محرك الإشعارات اللحظية",
            severity="WARNING",
            category="COMPANY_EXPIRY",
            entity_type="ImportCompany",
            entity_id=1,
            target_role="ALL",
        )

        notif = self.service.create_notification(schema)
        self.assertIsNotNone(notif.notification_id)
        self.assertFalse(notif.is_read)
        self.assertEqual(notif.severity, "WARNING")

        # Fetch notifications
        all_notifs = self.service.get_notifications(unread_only=True)
        self.assertGreaterEqual(len(all_notifs), 1)

    def test_mark_as_read(self):
        schema = NotificationCreate(
            title="تنبيه قابل للقراءة",
            message="اختبار الفلترة وتغيير الحالة",
            severity="INFO",
            category="SYSTEM",
        )
        notif = self.service.create_notification(schema)

        # Mark read
        updated = self.service.mark_read(notif.notification_id)
        self.assertTrue(updated.is_read)

        summary = self.service.get_summary()
        self.assertGreaterEqual(summary.total_count, 1)

    def test_trigger_expiry_check(self):
        new_alerts = self.service.trigger_expiry_check()
        self.assertIsInstance(new_alerts, list)


# ── Single-language storage (Phase B): system message codes ──────────────────
import pytest
from datetime import date, timedelta
from pydantic import ValidationError

from modules.notifications.expiry_checker import ExpiryCheckerService


def _session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine)()


def test_create_with_code_only_fills_english_title_and_message():
    schema = NotificationCreate(
        msg_code="NOTIF_DEMURRAGE_WARNING",
        msg_params={"import_file_code": "IMP-1", "days_left": 2},
        severity="WARNING",
    )
    assert schema.title == "Demurrage warning: IMP-1"
    assert "2 days left" in schema.message
    db = _session()
    created = NotificationService(db).create_notification(schema)
    assert created.msg_code == "NOTIF_DEMURRAGE_WARNING"
    assert created.msg_params == {"import_file_code": "IMP-1", "days_left": 2}
    assert created.title == "Demurrage warning: IMP-1"
    db.close()


def test_create_with_code_keeps_explicit_text():
    schema = NotificationCreate(title="t", message="m", msg_code="ALERT_DISK_LOW", msg_params={"free_gb": 4})
    assert (schema.title, schema.message) == ("t", "m")


def test_blank_title_and_message_with_code_are_rendered_not_rejected():
    schema = NotificationCreate(
        title="", message="   ", msg_code="NOTIF_DEMURRAGE_WARNING",
        msg_params={"import_file_code": "IMP-9", "days_left": 1},
    )
    assert schema.title == "Demurrage warning: IMP-9"
    assert "1 days left" in schema.message or "1 day" in schema.message
    with pytest.raises(ValidationError):  # blank text without a code is still missing
        NotificationCreate(title="", message="")


def test_unknown_code_is_rejected():
    with pytest.raises(ValidationError) as exc:
        NotificationCreate(msg_code="NOPE_UNKNOWN")
    assert "رمز الرسالة غير معروف" in str(exc.value)


def test_text_required_without_code():
    with pytest.raises(ValidationError):
        NotificationCreate(severity="INFO")
    with pytest.raises(ValidationError):
        NotificationCreate(title="x", message="y", msg_params={"a": 1})


def test_legacy_text_notification_has_no_code():
    db = _session()
    created = NotificationService(db).create_notification(NotificationCreate(title="x", message="y"))
    assert created.msg_code is None and created.msg_params is None
    db.close()


def test_expiry_checker_company_alert_is_coded_and_english():
    from modules.import_companies.model import ImportCompany

    db = _session()
    expiry = date.today() + timedelta(days=5)
    db.add(ImportCompany(
        importer_name="ACME", address="1 Port St", country="EG", importer_id="IMP-77", importer_id_expiry=expiry,
        vat_id="VAT-1", vat_id_expiry=date.today() + timedelta(days=400),
        registration_number="CR-1", registration_expiry=date.today() + timedelta(days=400), is_active=True,
    ))
    db.commit()
    created = ExpiryCheckerService(db)._check_company_expiries()
    assert len(created) == 1
    n = created[0]
    assert n.msg_code == "NOTIF_COMPANY_IMPORTER_ID_EXPIRY"
    assert n.msg_params == {
        "company_name": "ACME", "importer_id": "IMP-77", "days_left": 5, "expiry_date": expiry.isoformat(),
    }
    assert n.title == "Importer card expiring: ACME"
    assert n.severity == "CRITICAL"
    assert not any("؀" <= ch <= "ۿ" for ch in n.title + n.message)
    db.close()
