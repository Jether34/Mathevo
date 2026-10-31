import hmac
import logging
import re
import secrets
import uuid
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
from .mailer import MailDeliveryError, send_verification_code
from .security import (
    burn_password_check,
    decode_access_token,
    hash_password,
    issue_access_token,
    new_refresh_token,
    refresh_token_hash,
    verify_password,
    verification_code_hash,
)


app = FastAPI(
    title="Mathevo API",
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


class EmailRequest(BaseModel):
    email: str = Field(min_length=3, max_length=254)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        email = value.strip().lower()
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
            raise ValueError("Enter a valid email address")
        return email


class VerificationRequest(EmailRequest):
    code: str = Field(pattern=r"^\d{6}$")


class PasswordResetComplete(EmailRequest):
    reset_token: str = Field(min_length=32, max_length=256)
    new_password: str = Field(min_length=8, max_length=128)


class MessageResponse(BaseModel):
    message: str


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


def _issue_email_code(user: dict, purpose: str) -> str:
    now = datetime.now(timezone.utc)
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT created_at FROM email_verification_codes
               WHERE user_id = %s AND purpose = %s
               ORDER BY created_at DESC LIMIT 1""",
            (user["id"], purpose),
        )
        latest = cur.fetchone()
        if latest and now - latest["created_at"] < timedelta(
            seconds=settings.verification_code_resend_seconds
        ):
            raise HTTPException(
                status_code=429,
                detail="Please wait before requesting another code.",
            )
        cur.execute(
            """UPDATE email_verification_codes SET consumed_at = %s
               WHERE user_id = %s AND purpose = %s AND consumed_at IS NULL""",
            (now, user["id"], purpose),
        )
        code = f"{secrets.randbelow(1_000_000):06d}"
        cur.execute(
            """INSERT INTO email_verification_codes
               (user_id, purpose, code_hash, expires_at)
               VALUES (%s, %s, %s, %s) RETURNING id""",
            (
                user["id"],
                purpose,
                verification_code_hash(purpose, user["email"], code),
                now + timedelta(minutes=settings.verification_code_minutes),
            ),
        )
        code_row_id = cur.fetchone()["id"]
    try:
        send_verification_code(
            user["email"],
            user.get("display_name", "Mathevo user"),
            code,
            password_reset=purpose == "password_reset",
        )
    except MailDeliveryError as error:
        with pool.connection() as conn:
            conn.execute(
                "DELETE FROM email_verification_codes WHERE id = %s",
                (code_row_id,),
            )
        raise HTTPException(status_code=503, detail=str(error)) from None
    return code


def _verify_email_code(user: dict, purpose: str, code: str) -> bool:
    now = datetime.now(timezone.utc)
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT id, code_hash, expires_at, failed_attempts
               FROM email_verification_codes
               WHERE user_id = %s AND purpose = %s AND consumed_at IS NULL
               ORDER BY created_at DESC LIMIT 1 FOR UPDATE""",
            (user["id"], purpose),
        )
        row = cur.fetchone()
        if row is None or row["expires_at"] <= now or row["failed_attempts"] >= 5:
            if row is not None:
                cur.execute(
                    "UPDATE email_verification_codes SET consumed_at = %s WHERE id = %s",
                    (now, row["id"]),
                )
            return False
        supplied = verification_code_hash(purpose, user["email"], code)
        if not hmac.compare_digest(row["code_hash"], supplied):
            cur.execute(
                """UPDATE email_verification_codes
                   SET failed_attempts = failed_attempts + 1,
                       consumed_at = CASE WHEN failed_attempts >= 4 THEN %s ELSE NULL END
                   WHERE id = %s""",
                (now, row["id"]),
            )
            return False
        cur.execute(
            "UPDATE email_verification_codes SET consumed_at = %s WHERE id = %s",
            (now, row["id"]),
        )
    return True


@app.get("/health/live")
def live() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/ready")
def ready() -> dict[str, str]:
    with pool.connection() as conn:
        conn.execute("SELECT 1")
    return {"status": "ready"}


@app.post("/v1/auth/signup", response_model=MessageResponse, status_code=202)
def signup(payload: SignupRequest) -> MessageResponse:
    name = payload.name
    username = f"learner_{uuid.uuid4().hex[:12]}"
    password_hash = hash_password(payload.password)
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """INSERT INTO users
               (email, username, display_name, password_hash, email_verified)
               VALUES (%s, %s, %s, %s, FALSE)
               ON CONFLICT (lower(email)) DO UPDATE
               SET display_name = EXCLUDED.display_name,
                   password_hash = EXCLUDED.password_hash
               WHERE users.email_verified = FALSE AND users.disabled_at IS NULL
               RETURNING id, email, username, display_name""",
            (payload.email, username, name, password_hash),
        )
        user = cur.fetchone()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists. Log in instead.",
        )
    _issue_email_code(user, "signup")
    return MessageResponse(message="Verification code sent to your email address.")


@app.post("/v1/auth/verify-email", response_model=AuthResponse)
def verify_email(payload: VerificationRequest) -> AuthResponse:
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT id, email, username, display_name FROM users
               WHERE lower(email) = %s AND disabled_at IS NULL""",
            (payload.email,),
        )
        user = cur.fetchone()
    if user is None or not _verify_email_code(user, "signup", payload.code):
        raise HTTPException(status_code=400, detail="The code is invalid or expired.")
    with pool.connection() as conn:
        conn.execute(
            "UPDATE users SET email_verified = TRUE, updated_at = %s WHERE id = %s",
            (datetime.now(timezone.utc), user["id"]),
        )
    return _make_session(user)


@app.post("/v1/auth/verify-email/resend", response_model=MessageResponse)
def resend_signup_code(payload: EmailRequest) -> MessageResponse:
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT id, email, display_name FROM users
               WHERE lower(email) = %s AND disabled_at IS NULL
                 AND email_verified = FALSE""",
            (payload.email,),
        )
        user = cur.fetchone()
    if user is None:
        return MessageResponse(message="If verification is pending, a new code was sent.")
    _issue_email_code(user, "signup")
    return MessageResponse(message="If verification is pending, a new code was sent.")


@app.post("/v1/auth/login", response_model=AuthResponse)
def login(payload: Credentials) -> AuthResponse:
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT id, email, username, display_name, password_hash, email_verified
               FROM users WHERE lower(email) = %s AND disabled_at IS NULL""",
            (payload.email,),
        )
        user = cur.fetchone()
    if user is None:
        burn_password_check(payload.password)
        raise HTTPException(status_code=401, detail="Email or password is incorrect.")
    if not verify_password(user["password_hash"], payload.password):
        raise HTTPException(status_code=401, detail="Email or password is incorrect.")
    if not user["email_verified"]:
        raise HTTPException(
            status_code=403,
            detail="Verify your email address before logging in.",
        )
    return _make_session(user)


@app.post("/v1/auth/password-reset/request", response_model=MessageResponse)
def request_password_reset(payload: EmailRequest) -> MessageResponse:
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT id, email, display_name FROM users
               WHERE lower(email) = %s AND disabled_at IS NULL AND email_verified = TRUE""",
            (payload.email,),
        )
        user = cur.fetchone()
    if user is not None:
        try:
            _issue_email_code(user, "password_reset")
        except HTTPException as error:
            if error.status_code != 429:
                raise
    return MessageResponse(
        message="If an eligible account exists, a password reset code has been sent."
    )


@app.post("/v1/auth/password-reset/verify", response_model=dict[str, str])
def verify_password_reset(payload: VerificationRequest) -> dict[str, str]:
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT id, email FROM users
               WHERE lower(email) = %s AND disabled_at IS NULL AND email_verified = TRUE""",
            (payload.email,),
        )
        user = cur.fetchone()
    if user is None or not _verify_email_code(
        user, "password_reset", payload.code
    ):
        raise HTTPException(status_code=400, detail="The code is invalid or expired.")
    token = new_refresh_token()
    with pool.connection() as conn:
        conn.execute(
            """INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
               VALUES (%s, %s, %s)""",
            (
                user["id"],
                refresh_token_hash(token),
                datetime.now(timezone.utc)
                + timedelta(minutes=settings.password_reset_token_minutes),
            ),
        )
    return {"reset_token": token}


@app.post("/v1/auth/password-reset/complete", response_model=MessageResponse)
def complete_password_reset(payload: PasswordResetComplete) -> MessageResponse:
    now = datetime.now(timezone.utc)
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """UPDATE password_reset_tokens AS token
               SET used_at = %s
               FROM users AS account
               WHERE token.user_id = account.id
                 AND lower(account.email) = %s
                 AND token.token_hash = %s
                 AND token.used_at IS NULL
                 AND token.expires_at > %s
               RETURNING token.user_id""",
            (now, payload.email, refresh_token_hash(payload.reset_token), now),
        )
        token = cur.fetchone()
        if token is None:
            raise HTTPException(status_code=400, detail="The reset session is invalid or expired.")
        cur.execute(
            "UPDATE users SET password_hash = %s, updated_at = %s WHERE id = %s",
            (hash_password(payload.new_password), now, token["user_id"]),
        )
        cur.execute(
            """UPDATE refresh_sessions SET revoked_at = %s
               WHERE user_id = %s AND revoked_at IS NULL""",
            (now, token["user_id"]),
        )
    return MessageResponse(message="Password updated. You can now log in.")


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
