"""Create courses content model.

Revision ID: 20260913_0001
Revises: 20260806_0003
Create Date: 2026-09-13 00:00:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260913_0001"
down_revision: str | None = "20260806_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "courses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=20), server_default="draft", nullable=False),
        sa.Column("sort_order", sa.Integer(), server_default="1", nullable=False),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "course_stores",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("course_id", sa.Integer(), nullable=False),
        sa.Column("store_code", sa.String(length=40), nullable=False),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("course_id", "store_code", name="uq_course_stores_course_store_code"),
    )
    op.create_index("ix_course_stores_course_id", "course_stores", ["course_id"])

    op.create_table(
        "course_lessons",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("course_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("theory", sa.Text(), nullable=False),
        sa.Column("required_approval_percent", sa.Integer(), server_default="80", nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("course_id", "sort_order", name="uq_course_lessons_course_sort_order"),
    )
    op.create_index("ix_course_lessons_course_id", "course_lessons", ["course_id"])

    op.create_table(
        "course_lesson_theory_images",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("url", sa.Text(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["lesson_id"], ["course_lessons.id"], ondelete="CASCADE"),
    )
    op.create_index(
        "ix_course_lesson_theory_images_lesson_id",
        "course_lesson_theory_images",
        ["lesson_id"],
    )

    op.create_table(
        "training_questions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("lesson_id", sa.Integer(), nullable=False),
        sa.Column("prompt", sa.Text(), nullable=False),
        sa.Column("question_type", sa.String(length=20), server_default="text", nullable=False),
        sa.Column("answer_mode", sa.String(length=20), server_default="single", nullable=False),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["lesson_id"], ["course_lessons.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("lesson_id", "sort_order", name="uq_training_questions_lesson_sort_order"),
    )
    op.create_index("ix_training_questions_lesson_id", "training_questions", ["lesson_id"])

    op.create_table(
        "training_question_options",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("question_id", sa.Integer(), nullable=False),
        sa.Column("label", sa.Text(), nullable=False),
        sa.Column("media_url", sa.Text(), nullable=True),
        sa.Column("option_type", sa.String(length=20), server_default="text", nullable=False),
        sa.Column("is_correct", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["question_id"], ["training_questions.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "question_id",
            "sort_order",
            name="uq_training_question_options_question_sort_order",
        ),
    )
    op.create_index(
        "ix_training_question_options_question_id",
        "training_question_options",
        ["question_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_training_question_options_question_id", table_name="training_question_options")
    op.drop_table("training_question_options")
    op.drop_index("ix_training_questions_lesson_id", table_name="training_questions")
    op.drop_table("training_questions")
    op.drop_index("ix_course_lesson_theory_images_lesson_id", table_name="course_lesson_theory_images")
    op.drop_table("course_lesson_theory_images")
    op.drop_index("ix_course_lessons_course_id", table_name="course_lessons")
    op.drop_table("course_lessons")
    op.drop_index("ix_course_stores_course_id", table_name="course_stores")
    op.drop_table("course_stores")
    op.drop_table("courses")
