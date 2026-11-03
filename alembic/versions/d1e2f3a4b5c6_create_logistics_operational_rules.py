"""create_logistics_operational_rules

Revision ID: d1e2f3a4b5c6
Revises: c35e0daacd1f
Create Date: 2026-11-02 21:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd1e2f3a4b5c6'
down_revision: Union[str, Sequence[str], None] = 'c35e0daacd1f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'logistics_operational_rules' not in tables:
        op.create_table(
            'logistics_operational_rules',
            sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
            sa.Column('rule_key', sa.String(length=100), nullable=False),
            sa.Column('rule_name_ar', sa.Text(), nullable=False),
            sa.Column('rule_name_en', sa.Text(), nullable=False),
            sa.Column('scope_type', sa.String(length=20), nullable=False, server_default='GLOBAL'),
            sa.Column('scope_id', sa.Integer(), nullable=True),
            sa.Column('conservative_default', sa.Text(), nullable=True),
            sa.Column('verified_value', sa.Text(), nullable=True),
            sa.Column('value_unit', sa.String(length=20), nullable=False),
            sa.Column('enforcement_level', sa.String(length=10), nullable=False, server_default='WARNING'),
            sa.Column('verification_status', sa.String(length=15), nullable=False, server_default='UNVERIFIED'),
            sa.Column('verified_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('verified_on', sa.DateTime(), nullable=True),
            sa.Column('evidence_ref', sa.Text(), nullable=True),
            sa.Column('source_ref', sa.Text(), nullable=True),
            sa.Column('effective_from', sa.Date(), nullable=True),
            sa.Column('effective_to', sa.Date(), nullable=True),
            sa.Column('review_due_on', sa.Date(), nullable=True),
            sa.Column('version_id', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('is_latest', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
            sa.Column('created_by_user_id', sa.Integer(), sa.ForeignKey('users.user_id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.UniqueConstraint('rule_key', 'version_id', name='uq_rule_key_version'),
        )
        op.create_index(
            'ix_logistics_operational_rules_rule_key',
            'logistics_operational_rules',
            ['rule_key'],
            unique=False,
        )
        op.create_index(
            'ix_rule_lookup',
            'logistics_operational_rules',
            ['rule_key', 'scope_type', 'scope_id', 'is_latest'],
            unique=False,
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'logistics_operational_rules' in tables:
        op.drop_index('ix_rule_lookup', table_name='logistics_operational_rules')
        op.drop_index('ix_logistics_operational_rules_rule_key', table_name='logistics_operational_rules')
        op.drop_table('logistics_operational_rules')
