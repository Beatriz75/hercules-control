#!/bin/sh
# Apply migrations, create the first administrator if the users table is empty, then start the API.
set -e

alembic upgrade head
python -m app.bootstrap_admin

exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers "${WEB_CONCURRENCY:-2}" \
    --root-path "${ROOT_PATH:-}" \
    --proxy-headers \
    --forwarded-allow-ips "*"
