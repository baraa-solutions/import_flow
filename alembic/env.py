from logging.config import fileConfig

from sqlalchemy import create_engine
from sqlalchemy import pool

from alembic import context

import database.database
from database.database import Base

# Load all models for Alembic
# This imports all SQLAlchemy models so Alembic can detect tables
import database.models


# Alembic Config object
config = context.config


# Configure Python logging only for the CLI (an ini file) and only when the caller allows it:
# the in-app runner (database/migration_runner.py) sets configure_logger=False so the app's
# logging setup is not replaced.
if config.config_file_name is not None and config.attributes.get("configure_logger", True):
    fileConfig(config.config_file_name)


# SQLAlchemy Metadata for autogenerate
target_metadata = Base.metadata


def _database_url() -> str:
    # alembic.ini's sqlalchemy.url is never read: it is cwd-relative and would point at whatever
    # sorour_logistics.db sits in the current folder. The URL comes from the caller or from
    # database.database.DATABASE_URL, which honours DATABASE_PATH / DATABASE_URL.
    return config.attributes.get("url") or database.database.DATABASE_URL


def run_migrations_offline() -> None:
    """
    Run migrations in offline mode.
    """

    context.configure(
        url=_database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={
            "paramstyle": "named"
        },
        render_as_batch=True,
        transaction_per_migration=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def _run_with_connection(connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        render_as_batch=True,
        transaction_per_migration=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """
    Run migrations in online mode. Uses the caller's connection when one is passed
    (config.attributes["connection"]), otherwise opens its own NullPool engine.
    """

    connection = config.attributes.get("connection")
    if connection is not None:
        _run_with_connection(connection)
        return

    connectable = create_engine(_database_url(), poolclass=pool.NullPool)
    try:
        with connectable.connect() as connection:
            _run_with_connection(connection)
    finally:
        connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
