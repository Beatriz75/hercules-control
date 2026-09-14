from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.course import CourseLesson
from app.models.training_attempt import LessonProgress
from app.schemas.training_attempt import LessonProgressRead, TheoryCompletedUpdate

router = APIRouter(prefix="/lesson-progress", tags=["lesson-progress"])


def _get_lesson_or_404(db: Session, lesson_id: int) -> CourseLesson:
    lesson = db.get(CourseLesson, lesson_id)
    if lesson is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")
    return lesson


@router.patch("/{lesson_id}/theory-completed", response_model=LessonProgressRead)
def mark_theory_completed(
    lesson_id: int,
    payload: TheoryCompletedUpdate,
    db: Session = Depends(get_db),
) -> LessonProgress:
    _get_lesson_or_404(db, lesson_id)

    progress = db.scalar(
        select(LessonProgress).where(
            LessonProgress.employee_reference == payload.employee_reference,
            LessonProgress.lesson_id == lesson_id,
        )
    )
    if progress is None:
        progress = LessonProgress(
            employee_reference=payload.employee_reference,
            lesson_id=lesson_id,
            theory_completed=False,
            practice_approved=False,
        )
        db.add(progress)

    progress.theory_completed = True
    db.commit()
    db.refresh(progress)
    return progress


@router.get("", response_model=list[LessonProgressRead])
def list_lesson_progress(
    employee_reference: str,
    course_id: int | None = None,
    db: Session = Depends(get_db),
) -> list[LessonProgress]:
    query = select(LessonProgress).where(LessonProgress.employee_reference == employee_reference)
    if course_id is not None:
        query = query.join(CourseLesson, CourseLesson.id == LessonProgress.lesson_id).where(
            CourseLesson.course_id == course_id
        )

    return list(db.scalars(query.order_by(LessonProgress.lesson_id)))
