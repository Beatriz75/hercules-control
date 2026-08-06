from dataclasses import dataclass
import os


DEFAULT_DATABASE_URL = "postgresql+psycopg://postgres:postgres@db:5432/hercules_control"


@dataclass(frozen=True)
class Settings:
    database_url: str = DEFAULT_DATABASE_URL


def get_settings() -> Settings:
    return Settings(database_url=os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL))
