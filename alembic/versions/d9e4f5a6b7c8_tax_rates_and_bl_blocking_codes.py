"""tax rates table (withholding tax) + coded draft B/L blocking reasons

- New table ``tax_rates``: effective-dated rates that are not part of the HS-code tariff. Schema only: the
  rows (the 1% withholding tax rates the settlement engine used to hard-code, effective from 2000-01-01) are
  seeded by MasterDataSyncService.sync_tax_rates, which runs on every startup right after the upgrade
  (migrations never write data rows, see test_migration_runner test_4).
- ``draft_bl_review_sessions.blocking_reasons_coded`` (nullable JSON): [{code, params}] twin of
  ``blocking_reasons``. Legacy rows keep NULL.

Defensive: the table is created only when missing (create_all may already have built it); the column is
added only when missing.

Revision ID: d9e4f5a6b7c8
Revises: c8d3e4f5a6b7
Create Date: 2026-10-05 12:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "d9e4f5a6b7c8"
down_revision: Union[str, Sequence[str], None] = "c8d3e4f5a6b7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TAX_RATES = "tax_rates"
DRAFT_BL = "draft_bl_review_sessions"


def _create_tax_rates() -> None:
    op.create_table(
        TAX_RATES,
        sa.Column("tax_rate_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("tax_code", sa.String(50), nullable=False),
        sa.Column("rate_percent", sa.Numeric(7, 4), nullable=False),
        sa.Column("effective_from", sa.Date(), nullable=False),
        sa.Column("effective_to", sa.Date(), nullable=True),
        sa.Column("description", sa.String(255), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="1"),
        sa.Column("deleted_at", sa.DateTime(), nullable=True),
        sa.Column("deleted_by", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("created_by", sa.String(100), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("updated_by", sa.String(100), nullable=True),
        sa.UniqueConstraint("tax_code", "effective_from", name="uq_tax_rates_code_effective_from"),
    )
    op.create_index("ix_tax_rates_tax_rate_id", TAX_RATES, ["tax_rate_id"])
    op.create_index("ix_tax_rates_tax_code", TAX_RATES, ["tax_code"])


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    if TAX_RATES not in tables:
        _create_tax_rates()

    if DRAFT_BL in tables:
        existing = {c["name"].lower() for c in inspector.get_columns(DRAFT_BL)}
        if "blocking_reasons_coded" not in existing:
            with op.batch_alter_table(DRAFT_BL) as batch_op:
                batch_op.add_column(sa.Column("blocking_reasons_coded", sa.JSON(), nullable=True))


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    if DRAFT_BL in tables:
        existing = {c["name"].lower() for c in inspector.get_columns(DRAFT_BL)}
        if "blocking_reasons_coded" in existing:
            with op.batch_alter_table(DRAFT_BL) as batch_op:
                batch_op.drop_column("blocking_reasons_coded")
    if TAX_RATES in tables:
        op.drop_table(TAX_RATES)
