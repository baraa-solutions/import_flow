import logging
from sqlalchemy import MetaData, create_engine, event
from sqlalchemy.orm import declarative_base, sessionmaker


import os
from pathlib import Path

from utils.db_safety import app_base_dir

logger = logging.getLogger(__name__)

# Frozen build: the executable's folder (never sys._MEIPASS); dev: the repo root.
BASE_DIR = app_base_dir()

DB_PATH = os.getenv("DATABASE_PATH", str(BASE_DIR / "sorour_logistics.db"))
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    DATABASE_URL = f"sqlite:///{Path(DB_PATH).as_posix()}"

# Normalize legacy postgres:// URI to standard postgresql:// for SQLAlchemy 2.0
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

IS_SQLITE = DATABASE_URL.startswith("sqlite")

# Create Engine with Optimized Connection Pooling for Concurrency
if IS_SQLITE:
    engine = create_engine(
        DATABASE_URL,
        echo=False,
        pool_size=20,
        max_overflow=20,
        pool_timeout=30,
        pool_recycle=1800,
        connect_args={
            "check_same_thread": False,
            "timeout": 30,
        }
    )

    @event.listens_for(engine, "connect")
    def _set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        try:
            # WAL mode allows concurrent readers while writing
            cursor.execute("PRAGMA journal_mode = WAL;")
            cursor.execute("PRAGMA synchronous = NORMAL;")
            # Foreign key constraints enforcement for relational integrity
            cursor.execute("PRAGMA foreign_keys = ON;")
            # Prevent "database is locked" errors by waiting up to 30s for locks to clear
            cursor.execute("PRAGMA busy_timeout = 30000;")
            # Expand page cache from default 2MB to 64MB (-64000 KiB)
            cursor.execute("PRAGMA cache_size = -64000;")
            # Memory-mapped I/O (256 MB) for lightning-fast reads
            cursor.execute("PRAGMA mmap_size = 268435456;")
            # Keep temp tables and sorting structures in RAM
            cursor.execute("PRAGMA temp_store = MEMORY;")
        except Exception as exc:
            logger.exception("Failed to execute SQLite PRAGMA initialization: %s", exc)
        finally:
            cursor.close()
else:
    # Enterprise PostgreSQL Engine with connection recycling and health pre-ping
    engine = create_engine(
        DATABASE_URL,
        echo=False,
        pool_size=20,
        max_overflow=20,
        pool_timeout=30,
        pool_recycle=1800,
        pool_pre_ping=True,
    )


# Create Session
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)


# Base Class for all Models with standard naming convention
convention = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}
metadata = MetaData(naming_convention=convention)
Base = declarative_base(metadata=metadata)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()