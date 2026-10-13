from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import has_permission, require_permission
from app.api.routers.courses import ensure_student_can_access_lesson
from app.core.permissions import Permission
from app.db.session import get_db
from app.models.course import CourseLesson
from app.models.training_attempt import LessonProgress
from app.models.user import User
from app.schemas.training_attempt import LessonProgressRead

router = APIRouter(prefix="/lesson-progress", tags=["lesson-progress"])

CourseStudent = Annotated[User, Depends(require_permission(Permission.COURSES_TAKE))]
ProgressReader = Annotated[
    User, Depends(require_permission(Permission.COURSES_PROGRESS_VIEW, Permission.COURSES_TAKE))
]


def _get_lesson_or_404(db: Session, lesson_id: int) -> CourseLesson:
    lesson = db.get(CourseLesson, lesson_id)
    if lesson is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la lección o no está asignada a tu tienda.")
    return lesson


@router.patch("/{lesson_id}/theory-completed", response_model=LessonProgressRead)
def mark_theory_completed(
    lesson_id: int,
    student: CourseStudent,
    db: Session = Depends(get_db),
) -> LessonProgress:
    ensure_student_can_access_lesson(db, student, _get_lesson_or_404(db, lesson_id))

    progress = db.scalar(
        select(LessonProgress).where(
            LessonProgress.employee_reference == student.username,
            LessonProgress.lesson_id == lesson_id,
        )
    )
    if progress is None:
        progress = LessonProgress(
            employee_reference=student.username,
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
    user: ProgressReader,
    employee_reference: str | None = None,
    course_id: int | None = None,
    db: Session = Depends(get_db),
) -> list[LessonProgress]:
    if not has_permission(user, Permission.COURSES_PROGRESS_VIEW):
        employee_reference = user.username

    query = select(LessonProgress)
    if employee_reference is not None:
        query = query.where(LessonProgress.employee_reference == employee_reference)
    if course_id is not None:
        query = query.join(CourseLesson, CourseLesson.id == LessonProgress.lesson_id).where(
            CourseLesson.course_id == course_id
        )

    return list(db.scalars(query.order_by(LessonProgress.lesson_id)))
