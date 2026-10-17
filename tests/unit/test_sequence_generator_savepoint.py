"""
modules.common.sequence_generator.savepoint: a savepoint taken after reads only must stay inside the caller's
transaction on SQLite (pysqlite would otherwise make it the outermost transaction and commit on RELEASE).
"""
import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from modules.common.sequence_generator import savepoint


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    with engine.begin() as connection:
        connection.exec_driver_sql("CREATE TABLE codes (code TEXT PRIMARY KEY)")
    session = sessionmaker(bind=engine)()
    yield session
    session.close()
    engine.dispose()


def _count(db) -> int:
    return db.execute(text("SELECT COUNT(*) FROM codes")).scalar()


def test_rollback_after_a_read_only_savepoint_drops_the_row(db):
    db.execute(text("SELECT 1"))  # reads only: no write has opened the transaction yet
    with savepoint(db):
        db.execute(text("INSERT INTO codes VALUES ('TSK-1')"))
    db.rollback()
    assert _count(db) == 0


def test_commit_keeps_the_row(db):
    with savepoint(db):
        db.execute(text("INSERT INTO codes VALUES ('TSK-1')"))
    db.commit()
    assert _count(db) == 1


def test_failed_savepoint_keeps_the_callers_earlier_writes(db):
    db.execute(text("INSERT INTO codes VALUES ('TSK-1')"))
    with pytest.raises(IntegrityError):
        with savepoint(db):
            db.execute(text("INSERT INTO codes VALUES ('TSK-1')"))
    with savepoint(db):
        db.execute(text("INSERT INTO codes VALUES ('TSK-2')"))
    db.commit()
    assert _count(db) == 2
