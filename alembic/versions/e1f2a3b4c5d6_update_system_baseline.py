"""update_system_baseline

stamp target for legacy unstamped DBs (update-system plan §5).

No schema change: ``SchemaUpgradeService`` builds the schema with ``create_all`` (models == head schema)
and then stamps head. Revisions after this one must be written defensively (check a column exists
before adding it) and use ``batch_alter_table``.

Revision ID: e1f2a3b4c5d6
Revises: d3e4f5a6b7c8
Create Date: 2026-09-24 12:00:00.000000
"""
from typing import Sequence, Union

revision: str = "e1f2a3b4c5d6"
down_revision: Union[str, Sequence[str], None] = "d3e4f5a6b7c8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
