"""Add video links to lesson theory and questions.

Revision ID: 20261015_0001
Revises: 20261014_0001
Create Date: 2026-10-15 00:00:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20261015_0001"
down_revision: str | None = "20261014_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("training_questions", sa.Column("video_url", sa.Text(), nullable=True))
    op.create_table(
        "course_lesson_theory_videos",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("url", sa.Text(), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["lesson_id"], ["course_lessons.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_course_lesson_theory_videos_lesson_id", "course_lesson_theory_videos", ["lesson_id"])


def downgrade() -> None:
    op.drop_index("ix_course_lesson_theory_videos_lesson_id", table_name="course_lesson_theory_videos")
    op.drop_table("course_lesson_theory_videos")
    op.drop_column("training_questions", "video_url")
