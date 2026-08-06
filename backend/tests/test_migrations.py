from pathlib import Path


MIGRATIONS_DIR = Path(__file__).resolve().parents[1] / "migrations" / "versions"
EXCLUDED_BUSINESS_TABLE_TERMS = (
    "account",
    "budget",
    "category",
    "debt",
    "expense",
    "finance",
    "financial",
    "income",
    "invoice",
    "payment",
    "transaction",
)


def test_initial_migration_creates_only_bootstrap_table() -> None:
    migration_files = sorted(MIGRATIONS_DIR.glob("*.py"))

    assert [migration.name for migration in migration_files] == [
        "20260806_0001_create_schema_migrations_bootstrap.py"
    ]

    migration_text = migration_files[0].read_text(encoding="utf-8")

    assert 'op.create_table(\n        "schema_migrations_bootstrap"' in migration_text
    assert migration_text.count("op.create_table(") == 1


def test_initial_migration_does_not_create_business_tables() -> None:
    migration_text = "\n".join(
        migration.read_text(encoding="utf-8").lower() for migration in MIGRATIONS_DIR.glob("*.py")
    )

    for excluded_term in EXCLUDED_BUSINESS_TABLE_TERMS:
        assert excluded_term not in migration_text
