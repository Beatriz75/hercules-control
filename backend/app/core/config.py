from dataclasses import dataclass, field
import os


DEFAULT_DATABASE_URL = "postgresql+psycopg://postgres:postgres@db:5432/hercules_control"
DEFAULT_AUTH_SECRET_KEY = "local-development-secret-change-me"


@dataclass(frozen=True)
class Settings:
    database_url: str = DEFAULT_DATABASE_URL
    environment: str = "development"
    auth_secret_key: str = DEFAULT_AUTH_SECRET_KEY
    auth_algorithm: str = "HS256"
    access_token_expire_minutes: int = 480
    allowed_origins: list[str] = field(default_factory=list)


def get_settings() -> Settings:
    origins = os.getenv("ALLOWED_ORIGINS", "")
    return Settings(
        database_url=os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL),
        environment=os.getenv("ENVIRONMENT", "development"),
        auth_secret_key=os.getenv("AUTH_SECRET_KEY", DEFAULT_AUTH_SECRET_KEY),
        auth_algorithm=os.getenv("AUTH_ALGORITHM", "HS256"),
        access_token_expire_minutes=int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "480")),
        allowed_origins=[origin.strip() for origin in origins.split(",") if origin.strip()],
    )


def validate_settings(settings: Settings) -> None:
    if settings.environment == "production" and (
        settings.auth_secret_key == DEFAULT_AUTH_SECRET_KEY or len(settings.auth_secret_key) < 32
    ):
        raise RuntimeError("AUTH_SECRET_KEY must be set to a random value of at least 32 characters in production")
