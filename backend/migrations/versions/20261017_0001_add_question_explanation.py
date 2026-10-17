"""Add an explanation to bank questions, shown after a practice is submitted.

Revision ID: 20261017_0001
Revises: 20261016_0001
Create Date: 2026-10-17 00:00:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20261017_0001"
down_revision: str | None = "20261016_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Nullable: existing questions keep working without an explanation.
    op.add_column("training_questions", sa.Column("explanation", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("training_questions", "explanation")
