from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import require_permission
from app.api.routers.courses import _RETIRED_SORT_OFFSET, _apply_question, _new_question
from app.core.permissions import Permission
from app.core.similarity import similarity
from app.db.session import get_db
from app.models.course import Course, CourseLesson, TrainingQuestion
from app.models.user import User
from app.schemas.course import (
    QuestionBankRow,
    QuestionCreate,
    QuestionUpdate,
    SimilarQuestionRow,
    normalize_question_code,
)

router = APIRouter(prefix="/questions", tags=["questions"])

CourseViewer = Annotated[User, Depends(require_permission(Permission.COURSES_VIEW))]
CourseManager = Annotated[User, Depends(require_permission(Permission.COURSES_MANAGE))]


def _row(question: TrainingQuestion) -> QuestionBankRow:
    lesson = question.lesson
    course = lesson.course
    return QuestionBankRow(
        id=question.id,
        code=question.code,
        prompt=question.prompt,
        question_type=question.question_type,
        answer_mode=question.answer_mode,
        image_url=question.image_url,
        video_url=question.video_url,
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
    code: str | None = None,
    db: Session = Depends(get_db),
) -> list[QuestionBankRow]:
    """Every active question of every course, with its course and lesson, for the general bank view."""
    query = _bank_query()
    if course_id is not None:
        query = query.where(Course.id == course_id)
    if lesson_id is not None:
        query = query.where(CourseLesson.id == lesson_id)
    if code is not None:
        normalized = normalize_question_code(code)
        if normalized is None:
            return []
        query = query.where(func.upper(TrainingQuestion.code) == normalized)
    questions = db.scalars(
        query.order_by(Course.sort_order, Course.id, CourseLesson.sort_order, TrainingQuestion.sort_order)
    ).unique()
    return [_row(question) for question in questions]


SIMILARITY_THRESHOLD = 0.6


@router.get("/similar", response_model=list[SimilarQuestionRow])
def similar_questions(
    _: CourseManager,
    prompt: str = Query(min_length=3, max_length=4000),
    exclude_id: int | None = None,
    limit: int = Query(default=5, ge=1, le=20),
    db: Session = Depends(get_db),
) -> list[SimilarQuestionRow]:
    """Existing active questions that look like `prompt` (any course), most similar first."""
    matches = []
    for question in db.scalars(_bank_query()).unique():
        if question.id == exclude_id:
            continue
        score = similarity(prompt, question.prompt)
        if score >= SIMILARITY_THRESHOLD:
            matches.append((score, question))
    matches.sort(key=lambda item: item[0], reverse=True)
    return [
        SimilarQuestionRow(**_row(question).model_dump(), similarity=round(score, 2))
        for score, question in matches[:limit]
    ]


@router.post("", response_model=QuestionBankRow, status_code=status.HTTP_201_CREATED)
def create_question(payload: QuestionCreate, _: CourseManager, db: Session = Depends(get_db)) -> QuestionBankRow:
    """Add a question at the end of a lesson's bank."""
    lesson = db.scalar(
        select(CourseLesson)
        .options(selectinload(CourseLesson.questions))
        .where(CourseLesson.id == payload.lesson_id, CourseLesson.active.is_(True))
    )
    if lesson is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la lección.")
    used = [q.sort_order for q in lesson.questions if q.sort_order < _RETIRED_SORT_OFFSET]
    question = _new_question(payload.model_copy(update={"sort_order": max(used, default=0) + 1}))
    lesson.questions.append(question)
    db.commit()
    return _row(db.scalar(_bank_query().where(TrainingQuestion.id == question.id)))


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
