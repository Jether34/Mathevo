-- Preserve existing MathVerse accounts as verified while requiring verification
-- for users created after this migration.
ALTER TABLE users
    ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users
    ALTER COLUMN email_verified SET DEFAULT FALSE;

CREATE TABLE email_verification_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purpose TEXT NOT NULL CHECK (purpose IN ('signup', 'password_reset')),
    code_hash CHAR(64) NOT NULL,
    failed_attempts INTEGER NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ
);

CREATE INDEX email_verification_codes_user_purpose_idx
    ON email_verification_codes (user_id, purpose, created_at DESC);

CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash CHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ
);

CREATE INDEX password_reset_tokens_user_idx
    ON password_reset_tokens (user_id, expires_at)
    WHERE used_at IS NULL;

INSERT INTO schema_migrations (version) VALUES ('002_email_verification');
