from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.errors import register_error_handlers
from app.api.routers.audit_templates import router as audit_templates_router
from app.api.routers.auth import router as auth_router
from app.api.routers.courses import router as courses_router
from app.api.routers.health import router as health_router
from app.api.routers.lesson_progress import router as lesson_progress_router
from app.api.routers.operational_audits import router as operational_audits_router
from app.api.routers.training_attempts import router as training_attempts_router
from app.api.routers.users import router as users_router
from app.core.config import get_settings, validate_settings


def create_app() -> FastAPI:
    settings = get_settings()
    validate_settings(settings)

    app = FastAPI(title="Hercules Control API")
    register_error_handlers(app)
    if settings.allowed_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.allowed_origins,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    app.include_router(auth_router)
    app.include_router(users_router)
    app.include_router(audit_templates_router)
    app.include_router(operational_audits_router)
    app.include_router(courses_router)
    app.include_router(training_attempts_router)
    app.include_router(lesson_progress_router)
    app.include_router(health_router)
    return app


app = create_app()
