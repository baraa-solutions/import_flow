"""Add parent_import_file_id, parent_file_code, and is_partial_shipment to import_files (DEV-OPS-04)

Revision ID: f3a4b5c6d7e8
Revises: e2f3a4b5c6d7
Create Date: 2026-10-15 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f3a4b5c6d7e8'
down_revision: Union[str, Sequence[str], None] = 'e2f3a4b5c6d7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _double_quoted_defaults(columns: list) -> dict:
    """Columns whose DEFAULT is a double-quoted string, e.g. inland_transport_status DEFAULT "NOT_BOOKED"
    from the pre-Alembic modules/inland_transport/migration.py (v1.0.184). SQLite accepts that form in the
    original table, but when batch mode recreates the table Alembic re-emits it as DEFAULT ("NOT_BOOKED"),
    which SQLite rejects ("default value ... is not constant") and the startup upgrade fails."""
    fixed = {}
    for column in columns:
        default = column.get('default')
        if isinstance(default, str) and len(default) >= 2 and default[0] == default[-1] == '"':
            fixed[column['name']] = (column['type'], default[1:-1])
    return fixed


def _rewrite_double_quoted_defaults(batch_op, columns: list) -> None:
    """Re-declare legacy double-quoted defaults as standard single-quoted literals in the recreated table."""
    for name, (column_type, value) in _double_quoted_defaults(columns).items():
        literal = "'" + value.replace("'", "''") + "'"
        batch_op.alter_column(name, existing_type=column_type, server_default=sa.text(literal))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    reflected = inspector.get_columns('import_files')
    columns = [c['name'] for c in reflected]

    with op.batch_alter_table('import_files', schema=None) as batch_op:
        _rewrite_double_quoted_defaults(batch_op, reflected)

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
    reflected = sa.inspect(op.get_bind()).get_columns('import_files')
    with op.batch_alter_table('import_files', schema=None) as batch_op:
        _rewrite_double_quoted_defaults(batch_op, reflected)
        batch_op.drop_index('idx_import_files_parent_id')
        batch_op.drop_column('is_partial_shipment')
        batch_op.drop_column('parent_file_code')
        batch_op.drop_column('parent_import_file_id')
