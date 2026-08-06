from app.core.config import DEFAULT_DATABASE_URL, get_settings


def test_database_url_uses_default_when_env_is_missing(monkeypatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)

    settings = get_settings()

    assert settings.database_url == DEFAULT_DATABASE_URL


def test_database_url_uses_environment_value(monkeypatch) -> None:
    database_url = "postgresql+psycopg://user:password@localhost:5432/test_db"
    monkeypatch.setenv("DATABASE_URL", database_url)

    settings = get_settings()

    assert settings.database_url == database_url
