from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import require_permission
from app.api.routers.courses import _apply_question
from app.core.permissions import Permission
from app.db.session import get_db
from app.models.course import Course, CourseLesson, TrainingQuestion
from app.models.user import User
from app.schemas.course import QuestionBankRow, QuestionUpdate

router = APIRouter(prefix="/questions", tags=["questions"])

CourseViewer = Annotated[User, Depends(require_permission(Permission.COURSES_VIEW))]
CourseManager = Annotated[User, Depends(require_permission(Permission.COURSES_MANAGE))]


def _row(question: TrainingQuestion) -> QuestionBankRow:
    lesson = question.lesson
    course = lesson.course
    return QuestionBankRow(
        id=question.id,
        prompt=question.prompt,
        question_type=question.question_type,
        answer_mode=question.answer_mode,
        image_url=question.image_url,
        sort_order=question.sort_order,
        options=question.options,
        lesson_id=lesson.id,
        lesson_title=lesson.title,
        lesson_sort_order=lesson.sort_order,
        course_id=course.id,
        course_title=course.title,
        course_status=course.status,
        course_active=course.active,
        stores=[store.store_code for store in course.stores],
    )


def _bank_query():
    return (
        select(TrainingQuestion)
        .join(CourseLesson, CourseLesson.id == TrainingQuestion.lesson_id)
        .join(Course, Course.id == CourseLesson.course_id)
        .options(
            selectinload(TrainingQuestion.options),
            selectinload(TrainingQuestion.lesson).selectinload(CourseLesson.course).selectinload(Course.stores),
        )
        .where(TrainingQuestion.active.is_(True), CourseLesson.active.is_(True))
    )


@router.get("", response_model=list[QuestionBankRow])
def list_question_bank(
    _: CourseViewer,
    course_id: int | None = None,
    lesson_id: int | None = None,
    db: Session = Depends(get_db),
) -> list[QuestionBankRow]:
    """Every active question of every course, with its course and lesson, for the general bank view."""
    query = _bank_query()
    if course_id is not None:
        query = query.where(Course.id == course_id)
    if lesson_id is not None:
        query = query.where(CourseLesson.id == lesson_id)
    questions = db.scalars(
        query.order_by(Course.sort_order, Course.id, CourseLesson.sort_order, TrainingQuestion.sort_order)
    ).unique()
    return [_row(question) for question in questions]


@router.put("/{question_id}", response_model=QuestionBankRow)
def update_question(
    question_id: int, payload: QuestionUpdate, _: CourseManager, db: Session = Depends(get_db)
) -> QuestionBankRow:
    """Edit one question in place (same rules as the course editor: answered options keep their history)."""
    question = db.scalar(_bank_query().where(TrainingQuestion.id == question_id))
    if question is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la pregunta.")
    lesson = question.lesson
    previous_ids = {q.id for q in lesson.questions}

    _apply_question(db, lesson, question, payload.model_copy(update={"id": question.id, "sort_order": question.sort_order}))
    db.commit()

    if not question.active:
        # The question was replaced by a copy to keep answered history; return the new one.
        db.expire_all()
        replacement_id = max(q.id for q in db.get(CourseLesson, lesson.id).questions if q.id not in previous_ids)
        question = db.scalar(_bank_query().where(TrainingQuestion.id == replacement_id))
    else:
        db.expire_all()
        question = db.scalar(_bank_query().where(TrainingQuestion.id == question_id))
    return _row(question)
