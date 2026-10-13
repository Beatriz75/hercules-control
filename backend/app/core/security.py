from datetime import UTC, datetime, timedelta
import base64
import hashlib
import hmac
import secrets

import jwt

from app.core.config import Settings

_HASH_ALGORITHM = "pbkdf2_sha256"
_HASH_ITERATIONS = 600_000


def hash_password(password: str) -> str:
    salt = secrets.token_urlsafe(16)
    derived_key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), _HASH_ITERATIONS)
    return f"{_HASH_ALGORITHM}${_HASH_ITERATIONS}${salt}${base64.b64encode(derived_key).decode('ascii')}"


def verify_password(password: str, password_hash: str) -> bool:
    try:
        algorithm, iterations, salt, expected_hash = password_hash.split("$", 3)
    except ValueError:
        return False
    if algorithm != _HASH_ALGORITHM:
        return False
    derived_key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), int(iterations))
    return hmac.compare_digest(base64.b64encode(derived_key).decode("ascii"), expected_hash)


def create_access_token(user_id: int, settings: Settings) -> str:
    expires_at = datetime.now(UTC) + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {"sub": str(user_id), "exp": expires_at}
    return jwt.encode(payload, settings.auth_secret_key, algorithm=settings.auth_algorithm)


def decode_access_token(token: str, settings: Settings) -> int | None:
    try:
        payload = jwt.decode(token, settings.auth_secret_key, algorithms=[settings.auth_algorithm])
        return int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
