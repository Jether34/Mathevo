import os
import sys
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "postgresql://unused:unused@127.0.0.1/unused")
os.environ.setdefault("JWT_SECRET", "local-test-secret-" * 3)
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from datetime import datetime, timezone
from uuid import uuid4

from app.main import AuthResponse, Credentials, SignupRequest
from app.security import (
    decode_access_token,
    hash_password,
    issue_access_token,
    refresh_token_hash,
    verify_password,
)
from pydantic import ValidationError


def test_passwords_are_argon2_hashes_and_verify_correctly():
    encoded = hash_password("MathVerse-pass-123")
    assert encoded.startswith("$argon2id$")
    assert verify_password(encoded, "MathVerse-pass-123")
    assert not verify_password(encoded, "wrong-password")


def test_access_token_is_bound_to_issuer_and_subject():
    token, expires = issue_access_token("user-123")
    assert decode_access_token(token) == "user-123"
    assert expires.tzinfo is not None


def test_refresh_token_is_stored_as_one_way_hash():
    token = "high-entropy-session-secret"
    hashed = refresh_token_hash(token)
    assert hashed != token
    assert len(hashed) == 64


def test_signup_normalizes_identity_and_rejects_short_passwords():
    data = SignupRequest(
        name="  Math   Learner  ",
        email=" PERSON@Example.com ",
        password="password123",
    )
    assert data.name == "Math Learner"
    assert data.email == "person@example.com"
    try:
        Credentials(email="person@example.com", password="short")
    except ValidationError:
        pass
    else:
        raise AssertionError("short password was accepted")


def test_auth_response_exposes_profile_name_without_password_hash():
    user_id = uuid4()
    response = AuthResponse(
        access_token="access",
        refresh_token="refresh",
        expires_at=datetime.now(timezone.utc),
        user={
            "id": user_id,
            "email": "person@example.com",
            "username": "learner_123",
            "display_name": "Math Learner",
            "password_hash": "must-not-be-returned",
        },
    )
    encoded = response.model_dump(mode="json")
    assert encoded["user"]["name"] == "Math Learner"
    assert "password_hash" not in encoded["user"]
