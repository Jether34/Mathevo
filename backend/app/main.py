import re
import uuid
import logging
from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator
from psycopg import errors
from psycopg.rows import dict_row

from .config import settings
from .db import lifespan_pool, pool
from .security import (
    burn_password_check,
    decode_access_token,
    hash_password,
    issue_access_token,
    new_refresh_token,
    refresh_token_hash,
    verify_password,
)


app = FastAPI(
    title="MathVerse API",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
    lifespan=lifespan_pool,
)
logger = logging.getLogger("mathverse.api")


class Credentials(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        email = value.strip().lower()
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
            raise ValueError("Enter a valid email address")
        return email


class SignupRequest(Credentials):
    name: str = Field(min_length=1, max_length=80)

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if not normalized:
            raise ValueError("Enter your name")
        return normalized


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    username: str
    name: str = Field(validation_alias="display_name")

    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_at: datetime
    user: UserResponse


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=40, max_length=256)


class LogoutRequest(RefreshRequest):
    pass


def _make_session(user: dict) -> AuthResponse:
    access, expires = issue_access_token(str(user["id"]))
    refresh = new_refresh_token()
    refresh_expires = datetime.now(timezone.utc) + timedelta(
        days=settings.refresh_token_days
    )
    with pool.connection() as conn:
        conn.execute(
            """INSERT INTO refresh_sessions (user_id, token_hash, expires_at)
               VALUES (%s, %s, %s)""",
            (user["id"], refresh_token_hash(refresh), refresh_expires),
        )
    return AuthResponse(
        access_token=access,
        refresh_token=refresh,
        expires_at=expires,
        user=user,
    )


@app.get("/health/live")
def live() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/ready")
def ready() -> dict[str, str]:
    with pool.connection() as conn:
        conn.execute("SELECT 1")
    return {"status": "ready"}


@app.post("/v1/auth/signup", response_model=AuthResponse, status_code=201)
def signup(payload: SignupRequest) -> AuthResponse:
    name = payload.name
    username = f"learner_{uuid.uuid4().hex[:12]}"
    password_hash = hash_password(payload.password)
    try:
        with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """INSERT INTO users (email, username, display_name, password_hash)
                   VALUES (%s, %s, %s, %s)
                   RETURNING id, email, username, display_name""",
                (payload.email, username, name, password_hash),
            )
            user = cur.fetchone()
    except errors.UniqueViolation:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists. Log in instead.",
        ) from None
    return _make_session(user)


@app.post("/v1/auth/login", response_model=AuthResponse)
def login(payload: Credentials) -> AuthResponse:
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT id, email, username, display_name, password_hash
               FROM users WHERE lower(email) = %s AND disabled_at IS NULL""",
            (payload.email,),
        )
        user = cur.fetchone()
    if user is None:
        burn_password_check(payload.password)
        raise HTTPException(status_code=401, detail="Email or password is incorrect.")
    if not verify_password(user["password_hash"], payload.password):
        raise HTTPException(status_code=401, detail="Email or password is incorrect.")
    return _make_session(user)


@app.post("/v1/auth/refresh", response_model=AuthResponse)
def refresh(payload: RefreshRequest) -> AuthResponse:
    token_hash = refresh_token_hash(payload.refresh_token)
    now = datetime.now(timezone.utc)
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """UPDATE refresh_sessions SET revoked_at = %s
               WHERE token_hash = %s AND revoked_at IS NULL AND expires_at > %s
               RETURNING user_id""",
            (now, token_hash, now),
        )
        session = cur.fetchone()
        if session is None:
            raise HTTPException(status_code=401, detail="Session expired. Log in again.")
        cur.execute(
            """SELECT id, email, username, display_name FROM users
               WHERE id = %s AND disabled_at IS NULL""",
            (session["user_id"],),
        )
        user = cur.fetchone()
        if user is None:
            raise HTTPException(status_code=401, detail="Account is unavailable.")
    return _make_session(user)


@app.post("/v1/auth/logout", status_code=204)
def logout(payload: LogoutRequest) -> JSONResponse:
    with pool.connection() as conn:
        conn.execute(
            """UPDATE refresh_sessions SET revoked_at = %s
               WHERE token_hash = %s AND revoked_at IS NULL""",
            (datetime.now(timezone.utc), refresh_token_hash(payload.refresh_token)),
        )
    return JSONResponse(status_code=204, content=None)


def current_user(authorization: Annotated[str | None, Header()] = None) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authentication required.")
    try:
        user_id = decode_access_token(authorization[7:])
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Session expired. Log in again.") from None
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT id, email, username, display_name FROM users
               WHERE id = %s AND disabled_at IS NULL""",
            (user_id,),
        )
        user = cur.fetchone()
    if user is None:
        raise HTTPException(status_code=401, detail="Account is unavailable.")
    return user


@app.get("/v1/users/me", response_model=UserResponse)
def me(user: Annotated[dict, Depends(current_user)]) -> dict:
    return user


@app.exception_handler(Exception)
async def unexpected_error(_request: Request, _exc: Exception) -> JSONResponse:
    # Avoid returning SQL, configuration, or credential details to the client.
    logger.exception("Unhandled API error")
    return JSONResponse(status_code=500, content={"detail": "Internal server error."})
