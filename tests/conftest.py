import os
import tempfile
import pytest

# Set required environment variables BEFORE any module imports
# SECRET_KEY must be at least 32 chars (enforced by settings.py)
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-unit-tests-only-32chars")
os.environ.setdefault("ALLOW_DEV_AUTH_BYPASS", "true")
os.environ.setdefault("ENABLE_API_DOCS", "false")

# Create a temporary test database file for the test session
test_db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
test_db_path = test_db_file.name
test_db_file.close()

os.environ["DATABASE_PATH"] = test_db_path

from database.database import Base, engine, SessionLocal, get_db

# Import all SQLAlchemy models to register them in Base.metadata
import modules.import_companies.model
import modules.suppliers.model
import modules.external_service_providers.model
import modules.users.model
import modules.audit_logs.model
import modules.incoterms.model
import modules.customs_tariff.model
import modules.transport_locations.model
import modules.currencies.model
import modules.projects.model
import modules.purchase_orders.model
import modules.cbm_calculator.model
import modules.shipping_scenarios.model
import modules.customs_consultation.model
import modules.freight_quotations.model
import modules.customs_clearance_quotations.model
import modules.financial_approval.model
import modules.import_documentation.model
import modules.import_files.model
import modules.freight_booking.model
import modules.cargo_shipping.model
import modules.customs_clearance.model
import modules.warehouse_receiving.model
import modules.financial_settlement.model
import modules.file_closure.model
import modules.notifications.model
import modules.smart_tasks.model
import modules.shipment_updates.model
import modules.demurrage_detention.model
import modules.smart_document_upload.model
import modules.docs_customs_approval.model
import modules.cargox.model
import modules.original_documents_collection.model
import modules.smart_email_listener.model

@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    # Build all tables in the temporary database
    Base.metadata.create_all(bind=engine)
    yield
    # Cleanup after test session
    try:
        if os.path.exists(test_db_path):
            os.remove(test_db_path)
    except Exception:
        pass


# ─── Dev-bypass test seam ─────────────────────────────────────────────────────
# Most TestClient tests override get_db with an empty (or table-less) database and call routes without a
# token, relying on ALLOW_DEV_AUTH_BYPASS=true. Now that routers require auth, the bypass would find no user
# and return 401. This seam keeps the real bypass lookup and, only when it yields nothing (or the test DB has
# no users table), returns a transient ADMIN user that is never persisted.
# Tests that need the strict behaviour patch modules.auth.permissions.ALLOW_DEV_AUTH_BYPASS to False, which
# short-circuits before this seam is reached.
import modules.auth.permissions as _auth_permissions  # noqa: E402
from sqlalchemy.exc import SQLAlchemyError  # noqa: E402
from modules.users.model import User as _User  # noqa: E402


def _transient_test_admin() -> _User:
    return _User(username="test-admin", full_name="Test Admin", role="ADMIN", is_active=True)


@pytest.fixture(scope="session", autouse=True)
def dev_bypass_test_admin_seam():
    original = _auth_permissions._dev_bypass_fallback_user

    def _wrapped(db, x_user_role=None, x_user_name=None):
        try:
            user = original(db, x_user_role, x_user_name)
        except SQLAlchemyError:
            db.rollback()
            user = None
        return user if user is not None else _transient_test_admin()

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(_auth_permissions, "_dev_bypass_fallback_user", _wrapped)
        yield
