from fastapi import FastAPI

from app.api.routers.audit_templates import router as audit_templates_router
from app.api.routers.courses import router as courses_router
from app.api.routers.health import router as health_router
from app.api.routers.lesson_progress import router as lesson_progress_router
from app.api.routers.operational_audits import router as operational_audits_router
from app.api.routers.training_attempts import router as training_attempts_router


def create_app() -> FastAPI:
    app = FastAPI(title="Hercules Control API")
    app.include_router(audit_templates_router)
    app.include_router(operational_audits_router)
    app.include_router(courses_router)
    app.include_router(training_attempts_router)
    app.include_router(lesson_progress_router)
    app.include_router(health_router)
    return app


app = create_app()
