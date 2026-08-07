from fastapi import FastAPI

from app.api.routers.audit_templates import router as audit_templates_router
from app.api.routers.health import router as health_router


def create_app() -> FastAPI:
    app = FastAPI(title="Hercules Control API")
    app.include_router(audit_templates_router)
    app.include_router(health_router)
    return app


app = create_app()
