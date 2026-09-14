from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db.session import get_db
from app.models.course import CourseLesson, TrainingQuestion
from app.models.training_attempt import LessonProgress, TrainingAnswer, TrainingAnswerOption, TrainingAttempt
from app.schemas.training_attempt import TrainingAttemptCreate, TrainingAttemptRead

router = APIRouter(prefix="/training-attempts", tags=["training-attempts"])


def _get_lesson_or_404(db: Session, lesson_id: int) -> CourseLesson:
    lesson = db.scalar(
        select(CourseLesson)
        .options(selectinload(CourseLesson.questions).selectinload(TrainingQuestion.options))
        .where(CourseLesson.id == lesson_id)
    )
    if lesson is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
    return lesson


def _get_attempt_or_404(db: Session, attempt_id: int) -> TrainingAttempt:
    attempt = db.scalar(
        select(TrainingAttempt)
        .options(selectinload(TrainingAttempt.answers).selectinload(TrainingAnswer.selected_options))
        .where(TrainingAttempt.id == attempt_id)
    )
    if attempt is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Training attempt not found")
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


@router.post("", response_model=TrainingAttemptRead, status_code=status.HTTP_201_CREATED)
def create_training_attempt(payload: TrainingAttemptCreate, db: Session = Depends(get_db)) -> TrainingAttempt:
    lesson = _get_lesson_or_404(db, payload.lesson_id)

    active_questions = {question.id: question for question in lesson.questions if question.active}
    answered_question_ids = {answer.question_id for answer in payload.answers}
    if answered_question_ids != set(active_questions.keys()):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Answers must cover exactly the lesson's active questions",
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
                detail=f"selected_option_ids must belong to question {question.id}",
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
        employee_reference=payload.employee_reference,
        lesson_id=payload.lesson_id,
        score_percent=score_percent,
        required_approval_percent=lesson.required_approval_percent,
        approved=approved,
        answers=answers,
    )
    db.add(attempt)
    _upsert_lesson_progress(db, payload.employee_reference, payload.lesson_id, score_percent, approved)
    db.commit()
    db.refresh(attempt)
    return _get_attempt_or_404(db, attempt.id)


@router.get("", response_model=list[TrainingAttemptRead])
def list_training_attempts(
    employee_reference: str | None = None,
    lesson_id: int | None = None,
    db: Session = Depends(get_db),
) -> list[TrainingAttempt]:
    query = select(TrainingAttempt).options(
        selectinload(TrainingAttempt.answers).selectinload(TrainingAnswer.selected_options)
    )
    if employee_reference is not None:
        query = query.where(TrainingAttempt.employee_reference == employee_reference)
    if lesson_id is not None:
        query = query.where(TrainingAttempt.lesson_id == lesson_id)

    return list(db.scalars(query.order_by(TrainingAttempt.id)))


@router.get("/{attempt_id}", response_model=TrainingAttemptRead)
def get_training_attempt(attempt_id: int, db: Session = Depends(get_db)) -> TrainingAttempt:
    return _get_attempt_or_404(db, attempt_id)
