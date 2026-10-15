"""Add parent_import_file_id, parent_file_code, and is_partial_shipment to import_files (DEV-OPS-04)

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-10-15 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c3d4e5f6a7b8'
down_revision: Union[str, Sequence[str], None] = 'b2c3d4e5f6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [c['name'] for c in inspector.get_columns('import_files')]

    with op.batch_alter_table('import_files', schema=None) as batch_op:
        if 'parent_import_file_id' not in columns:
            batch_op.add_column(
                sa.Column(
                    'parent_import_file_id',
                    sa.Integer(),
                    sa.ForeignKey('import_files.import_file_id'),
                    nullable=True,
                )
            )
            batch_op.create_index(
                'idx_import_files_parent_id',
                ['parent_import_file_id'],
                unique=False,
            )

        if 'parent_file_code' not in columns:
            batch_op.add_column(
                sa.Column('parent_file_code', sa.String(length=50), nullable=True)
            )

        if 'is_partial_shipment' not in columns:
            batch_op.add_column(
                sa.Column(
                    'is_partial_shipment',
                    sa.Boolean(),
                    nullable=False,
                    server_default=sa.text('0'),
                )
            )


def downgrade() -> None:
    with op.batch_alter_table('import_files', schema=None) as batch_op:
        batch_op.drop_index('idx_import_files_parent_id')
        batch_op.drop_column('is_partial_shipment')
        batch_op.drop_column('parent_file_code')
        batch_op.drop_column('parent_import_file_id')
