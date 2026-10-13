from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(Text(), nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default="draft")
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, server_default="1")
    active: Mapped[bool] = mapped_column(Boolean(), nullable=False, server_default="true")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    stores: Mapped[list["CourseStore"]] = relationship(
        back_populates="course",
        cascade="all, delete-orphan",
        order_by="CourseStore.id",
    )
    lessons: Mapped[list["CourseLesson"]] = relationship(
        back_populates="course",
        cascade="all, delete-orphan",
        order_by="CourseLesson.sort_order",
    )


class CourseStore(Base):
    __tablename__ = "course_stores"
    __table_args__ = (UniqueConstraint("course_id", "store_code", name="uq_course_stores_course_store_code"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True)
    store_code: Mapped[str] = mapped_column(String(40), nullable=False)

    course: Mapped[Course] = relationship(back_populates="stores")


class CourseLesson(Base):
    __tablename__ = "course_lessons"
    __table_args__ = (UniqueConstraint("course_id", "sort_order", name="uq_course_lessons_course_sort_order"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    summary: Mapped[str] = mapped_column(Text(), nullable=False)
    theory: Mapped[str] = mapped_column(Text(), nullable=False)
    required_approval_percent: Mapped[int] = mapped_column(Integer, nullable=False, server_default="80")
    # How many questions of the lesson's bank each practice draws at random; None = all of them.
    questions_per_attempt: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean(), nullable=False, server_default="true")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    course: Mapped[Course] = relationship(back_populates="lessons")
    theory_images: Mapped[list["CourseLessonTheoryImage"]] = relationship(
        back_populates="lesson",
        cascade="all, delete-orphan",
        order_by="CourseLessonTheoryImage.sort_order",
    )
    theory_videos: Mapped[list["CourseLessonTheoryVideo"]] = relationship(
        back_populates="lesson",
        cascade="all, delete-orphan",
        order_by="CourseLessonTheoryVideo.sort_order",
    )
    questions: Mapped[list["TrainingQuestion"]] = relationship(
        back_populates="lesson",
        cascade="all, delete-orphan",
        order_by="TrainingQuestion.sort_order",
    )


class CourseLessonTheoryImage(Base):
    __tablename__ = "course_lesson_theory_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("course_lessons.id", ondelete="CASCADE"), nullable=False, index=True
    )
    url: Mapped[str] = mapped_column(Text(), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)

    lesson: Mapped[CourseLesson] = relationship(back_populates="theory_images")


class CourseLessonTheoryVideo(Base):
    __tablename__ = "course_lesson_theory_videos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("course_lessons.id", ondelete="CASCADE"), nullable=False, index=True
    )
    url: Mapped[str] = mapped_column(Text(), nullable=False)
    title: Mapped[str | None] = mapped_column(String(160), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)

    lesson: Mapped[CourseLesson] = relationship(back_populates="theory_videos")


class TrainingQuestion(Base):
    __tablename__ = "training_questions"
    __table_args__ = (UniqueConstraint("lesson_id", "sort_order", name="uq_training_questions_lesson_sort_order"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("course_lessons.id", ondelete="CASCADE"), nullable=False, index=True
    )
    prompt: Mapped[str] = mapped_column(Text(), nullable=False)
    question_type: Mapped[str] = mapped_column(String(20), nullable=False, server_default="text")
    answer_mode: Mapped[str] = mapped_column(String(20), nullable=False, server_default="single")
    image_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    video_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean(), nullable=False, server_default="true")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    lesson: Mapped[CourseLesson] = relationship(back_populates="questions")
    options: Mapped[list["TrainingQuestionOption"]] = relationship(
        back_populates="question",
        cascade="all, delete-orphan",
        order_by="TrainingQuestionOption.sort_order",
    )


class TrainingQuestionOption(Base):
    __tablename__ = "training_question_options"
    __table_args__ = (
        UniqueConstraint("question_id", "sort_order", name="uq_training_question_options_question_sort_order"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    question_id: Mapped[int] = mapped_column(
        ForeignKey("training_questions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    label: Mapped[str] = mapped_column(Text(), nullable=False)
    media_url: Mapped[str | None] = mapped_column(Text(), nullable=True)
    option_type: Mapped[str] = mapped_column(String(20), nullable=False, server_default="text")
    is_correct: Mapped[bool] = mapped_column(Boolean(), nullable=False, server_default="false")
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)

    question: Mapped[TrainingQuestion] = relationship(back_populates="options")
