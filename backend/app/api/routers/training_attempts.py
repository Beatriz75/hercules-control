from datetime import UTC, datetime
import random
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import has_permission, require_permission
from app.api.routers.courses import ensure_student_can_access_lesson, practice_size
from app.core.permissions import Permission
from app.db.session import get_db
from app.models.course import CourseLesson, TrainingQuestion
from app.models.training_attempt import (
    LessonProgress,
    PracticeSession,
    TrainingAnswer,
    TrainingAnswerOption,
    TrainingAttempt,
)
from app.schemas.course import PracticeSessionRead, PracticeStart, StudentQuestionOptionRead, StudentQuestionRead
from app.models.user import User
from app.schemas.training_attempt import TrainingAttemptCreate, TrainingAttemptRead

router = APIRouter(prefix="/training-attempts", tags=["training-attempts"])

CourseStudent = Annotated[User, Depends(require_permission(Permission.COURSES_TAKE))]
ProgressReader = Annotated[
    User, Depends(require_permission(Permission.COURSES_PROGRESS_VIEW, Permission.COURSES_TAKE))
]


def _get_lesson_or_404(db: Session, lesson_id: int) -> CourseLesson:
    lesson = db.scalar(
        select(CourseLesson)
        .options(selectinload(CourseLesson.questions).selectinload(TrainingQuestion.options))
        .where(CourseLesson.id == lesson_id)
    )
    if lesson is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la lección o no está asignada a tu tienda.")
    return lesson


def _get_attempt_or_404(db: Session, attempt_id: int) -> TrainingAttempt:
    attempt = db.scalar(
        select(TrainingAttempt)
        .options(
            selectinload(TrainingAttempt.answers).selectinload(TrainingAnswer.selected_options),
            selectinload(TrainingAttempt.answers)
            .selectinload(TrainingAnswer.question)
            .selectinload(TrainingQuestion.options),
        )
        .where(TrainingAttempt.id == attempt_id)
    )
    if attempt is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró el intento de práctica.")
    return attempt


def _upsert_lesson_progress(
    db: Session,
    employee_reference: str,
    lesson_id: int,
    score_percent: float,
    approved: bool,
) -> None:
    progress = db.scalar(
        select(LessonProgress).where(
            LessonProgress.employee_reference == employee_reference,
            LessonProgress.lesson_id == lesson_id,
        )
    )
    if progress is None:
        progress = LessonProgress(
            employee_reference=employee_reference,
            lesson_id=lesson_id,
            theory_completed=False,
            practice_approved=False,
        )
        db.add(progress)

    was_approved = progress.practice_approved
    progress.practice_approved = progress.practice_approved or approved
    progress.best_score_percent = (
        score_percent
        if progress.best_score_percent is None
        else max(progress.best_score_percent, score_percent)
    )
    if progress.practice_approved and not was_approved:
        progress.completed_at = datetime.now(UTC)


@router.post("/start", response_model=PracticeSessionRead, status_code=status.HTTP_201_CREATED)
def start_practice(payload: PracticeStart, student: CourseStudent, db: Session = Depends(get_db)) -> PracticeSessionRead:
    """Draw this practice's questions at random from the lesson's bank, with options shuffled."""
    lesson = _get_lesson_or_404(db, payload.lesson_id)
    ensure_student_can_access_lesson(db, student, lesson)

    bank = [question for question in lesson.questions if question.active]
    if not bank:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Esta lección todavía no tiene preguntas.")
    drawn = random.sample(bank, practice_size(lesson.questions_per_attempt, len(bank)))

    session = PracticeSession(
        employee_reference=student.username, lesson_id=lesson.id, question_ids=[question.id for question in drawn]
    )
    db.add(session)
    db.commit()

    questions = []
    for question in drawn:
        options = [StudentQuestionOptionRead.model_validate(option) for option in question.options]
        random.shuffle(options)
        questions.append(StudentQuestionRead.model_validate(question).model_copy(update={"options": options}))
    return PracticeSessionRead(
        session_id=session.id,
        lesson_id=lesson.id,
        required_approval_percent=lesson.required_approval_percent,
        questions=questions,
    )


@router.post("", response_model=TrainingAttemptRead, status_code=status.HTTP_201_CREATED)
def create_training_attempt(
    payload: TrainingAttemptCreate, student: CourseStudent, db: Session = Depends(get_db)
) -> TrainingAttempt:
    session = db.get(PracticeSession, payload.session_id)
    if session is None or session.employee_reference != student.username:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la práctica. Vuelve a empezarla.")
    if session.attempt_id is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Esta práctica ya fue entregada. Empieza una nueva.")
    lesson = _get_lesson_or_404(db, session.lesson_id)
    ensure_student_can_access_lesson(db, student, lesson)

    # Grade against the questions drawn for this session, even if the lesson was edited meanwhile.
    active_questions = {question.id: question for question in lesson.questions if question.id in set(session.question_ids)}
    answered_question_ids = {answer.question_id for answer in payload.answers}
    if answered_question_ids != set(session.question_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debes responder todas las preguntas de la práctica.",
        )

    answers: list[TrainingAnswer] = []
    correct_count = 0

    for answer in payload.answers:
        question = active_questions[answer.question_id]
        options_by_id = {option.id: option for option in question.options}
        invalid_option_ids = [
            option_id for option_id in answer.selected_option_ids if option_id not in options_by_id
        ]
        if invalid_option_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Una de las respuestas elegidas no pertenece a su pregunta. Recarga la práctica.",
            )

        selected_ids = set(answer.selected_option_ids)
        correct_ids = {option.id for option in question.options if option.is_correct}
        is_correct = selected_ids == correct_ids
        if is_correct:
            correct_count += 1

        answers.append(
            TrainingAnswer(
                question_id=answer.question_id,
                is_correct=is_correct,
                selected_options=[TrainingAnswerOption(option_id=option_id) for option_id in answer.selected_option_ids],
            )
        )

    score_percent = (correct_count / len(payload.answers)) * 100
    approved = score_percent >= lesson.required_approval_percent

    attempt = TrainingAttempt(
        employee_reference=student.username,
        lesson_id=lesson.id,
        score_percent=score_percent,
        required_approval_percent=lesson.required_approval_percent,
        approved=approved,
        answers=answers,
    )
    db.add(attempt)
    _upsert_lesson_progress(db, student.username, lesson.id, score_percent, approved)
    db.flush()
    session.attempt_id = attempt.id
    db.commit()
    db.refresh(attempt)
    return _get_attempt_or_404(db, attempt.id)


@router.get("", response_model=list[TrainingAttemptRead])
def list_training_attempts(
    employee_reference: str | None = None,
    lesson_id: int | None = None,
    *,
    user: ProgressReader,
    db: Session = Depends(get_db),
) -> list[TrainingAttempt]:
    if not has_permission(user, Permission.COURSES_PROGRESS_VIEW):
        employee_reference = user.username
    query = select(TrainingAttempt).options(
        selectinload(TrainingAttempt.answers).selectinload(TrainingAnswer.selected_options),
        selectinload(TrainingAttempt.answers)
        .selectinload(TrainingAnswer.question)
        .selectinload(TrainingQuestion.options)
    )
    if employee_reference is not None:
        query = query.where(TrainingAttempt.employee_reference == employee_reference)
    if lesson_id is not None:
        query = query.where(TrainingAttempt.lesson_id == lesson_id)

    return list(db.scalars(query.order_by(TrainingAttempt.id)))


@router.get("/{attempt_id}", response_model=TrainingAttemptRead)
def get_training_attempt(attempt_id: int, user: ProgressReader, db: Session = Depends(get_db)) -> TrainingAttempt:
    attempt = _get_attempt_or_404(db, attempt_id)
    if not has_permission(user, Permission.COURSES_PROGRESS_VIEW) and attempt.employee_reference != user.username:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró el intento de práctica.")
    return attempt
