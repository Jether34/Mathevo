# MathVerse cloud account service

This is a separate Docker Compose project. It creates only the `mathverse-cloud`
containers, a dedicated `mathverse` PostgreSQL database, and its private volume.
It does not use or alter WeeWare or CCOverT databases, containers, files, ports,
or service configuration.

## Contents

- `migrations/001_initial.sql`: user accounts and revocable refresh sessions.
- `app/`: REST API for signup, login, session refresh/logout, current-user lookup,
  and health checks.
- `compose.yaml`: isolated PostgreSQL/API/TLS gateway stack. PostgreSQL and the
  API have no host-published ports; the gateway publishes only `18443/tcp`.

Passwords are hashed using Argon2id by the backend. Access tokens are short-lived
HS256 JWTs; refresh tokens are random opaque values stored only as SHA-256 hashes
in PostgreSQL. The app keeps returned tokens in Android Keystore/iOS Keychain via
`flutter_secure_storage`. The password is never saved on the phone.

## Local startup

1. Copy `.env.example` to `.env`.
2. Generate a long random database password and a separate JWT secret of at least
   32 random bytes. Use URL-safe hexadecimal values for the DB password.
3. On the server, create `certs/server.key` and `certs/server.crt`. For the
   fixed-IP installation, use a self-signed certificate with IP SAN
   `76.13.183.207`. Keep the private key only on the VPS. The app pins the public
   certificate by including its PEM file as an asset.
4. Start with `docker compose up -d --build` and allow inbound `18443/tcp` in the
   VPS firewall. Ports 80 and 443 are not used or changed.
5. Copy the public `server.crt` to `assets/certs/server.crt` and build the app:
   `flutter build apk --dart-define=MATHVERSE_API_BASE_URL=https://76.13.183.207:18443 --dart-define=MATHVERSE_API_CERTIFICATE_ASSET=assets/certs/server.crt`

The app refuses non-HTTPS URLs. It uses a dedicated pinned certificate so this
service can use the VPS IP and a separate port without changing existing HTTP or
HTTPS listeners. Only the TLS gateway joins the public ingress network; the API
and database remain on the isolated private network. Rotating that certificate
requires updating the bundled public certificate and rebuilding the app.

## API

- `POST /v1/auth/signup` body: `{ "name", "email", "password" }` (password at
  least 8 characters). Creates the cloud user and starts a session.
- `POST /v1/auth/login` body: `{ "email", "password" }`.
- `POST /v1/auth/refresh` body: `{ "refresh_token" }`. Rotates and revokes the
  supplied refresh token.
- `POST /v1/auth/logout` body: `{ "refresh_token" }`.
- `GET /v1/users/me` requires `Authorization: Bearer <access_token>`.
- `GET /health/live` and `/health/ready` are health checks.

The initial SQL migration runs only when the dedicated PostgreSQL volume is
created for the first time. Back up that volume before future database changes;
apply later migrations explicitly and record them in `schema_migrations`.

## VPS deployment boundary

Do not run `docker compose down`, prune Docker resources, replace global proxy
configuration, or edit shared system services for this project. This Compose
project has its own containers, network, certificate files, and database
volume. Never put the VPS password, DB password, JWT secret, or TLS private key
in source control or client build arguments.
