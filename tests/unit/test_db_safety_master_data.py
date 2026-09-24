"""
DB safety (docs/plans/update-system-plan.md section 0), A12: the startup master-data sync inserts
missing Incoterm responsibilities only and never overwrites a user's edits.
"""
import importlib
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database.database import Base
from database.master_data_sync_service import MasterDataSyncService
from modules.incoterms.model import IncotermResponsibility

REPO_ROOT = Path(__file__).resolve().parents[2]


def _register_all_models() -> None:
    """Import every modules/<name>/model.py so Base.metadata is complete when this file runs alone
    (sync_all touches expense_catalog, experience_guide, RBAC ... tables)."""
    for model_file in sorted((REPO_ROOT / "modules").glob("*/model.py")):
        importlib.import_module(f"modules.{model_file.parent.name}.model")


_register_all_models()


def test_user_edited_incoterm_responsibility_survives_sync_all(tmp_path):
    engine = create_engine(f"sqlite:///{(tmp_path / 'md.db').as_posix()}")
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    try:
        MasterDataSyncService(session).sync_all()
        total = session.query(IncotermResponsibility).count()
        assert total > 0

        row = session.query(IncotermResponsibility).order_by(IncotermResponsibility.responsibility_id).first()
        edited_party = "Shared" if row.responsible_party != "Shared" else "Importer"
        row.responsible_party = edited_party
        row.included_in_incoterm = not row.included_in_incoterm
        row.notes = "user edit - keep"
        edited_included = row.included_in_incoterm
        row_id = row.responsibility_id
        session.commit()

        result = MasterDataSyncService(session).sync_incoterms()
        session.expire_all()

        again = session.get(IncotermResponsibility, row_id)
        assert again.responsible_party == edited_party
        assert again.included_in_incoterm == edited_included
        assert again.notes == "user edit - keep"
        assert result["responsibilities_updated"] == 0
        assert result["responsibilities_added"] == 0
        assert session.query(IncotermResponsibility).count() == total
    finally:
        session.close()
        engine.dispose()


def test_missing_incoterm_responsibility_is_reinserted(tmp_path):
    engine = create_engine(f"sqlite:///{(tmp_path / 'md2.db').as_posix()}")
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    try:
        MasterDataSyncService(session).sync_incoterms()
        total = session.query(IncotermResponsibility).count()
        victim = session.query(IncotermResponsibility).first()
        session.delete(victim)
        session.commit()

        result = MasterDataSyncService(session).sync_incoterms()
        assert result["responsibilities_added"] == 1
        assert session.query(IncotermResponsibility).count() == total
    finally:
        session.close()
        engine.dispose()
