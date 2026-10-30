import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

from .config import settings


password_hasher = PasswordHasher()
_dummy_hash = password_hasher.hash(secrets.token_urlsafe(32))


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(encoded: str, password: str) -> bool:
    try:
        return password_hasher.verify(encoded, password)
    except (InvalidHashError, VerificationError, VerifyMismatchError):
        return False


def burn_password_check(password: str) -> None:
    verify_password(_dummy_hash, password)


def new_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def refresh_token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_access_token(user_id: str) -> tuple[str, datetime]:
    expires = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_minutes)
    token = jwt.encode(
        {
            "sub": user_id,
            "iss": settings.jwt_issuer,
            "iat": datetime.now(timezone.utc),
            "exp": expires,
            "type": "access",
        },
        settings.jwt_secret,
        algorithm="HS256",
    )
    return token, expires


def decode_access_token(token: str) -> str:
    claims = jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=["HS256"],
        issuer=settings.jwt_issuer,
        options={"require": ["sub", "iat", "exp", "iss"]},
    )
    if claims.get("type") != "access":
        raise jwt.InvalidTokenError("Wrong token type")
    return str(claims["sub"])
