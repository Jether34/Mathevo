from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    jwt_issuer: str = "mathverse-api"
    access_token_minutes: int = 20
    refresh_token_days: int = 30
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
if len(settings.jwt_secret.encode("utf-8")) < 32:
    raise RuntimeError("JWT_SECRET must contain at least 32 bytes")
