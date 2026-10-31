from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    jwt_issuer: str = "mathverse-api"
    access_token_minutes: int = 20
    refresh_token_days: int = 30
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from_email: str = ""
    smtp_from_name: str = "mathevo"
    verification_code_minutes: int = 10
    verification_code_resend_seconds: int = 60
    password_reset_token_minutes: int = 10
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def smtp_configured(self) -> bool:
        return bool(self.smtp_username and self.smtp_password and self.smtp_from_email)


settings = Settings()
if len(settings.jwt_secret.encode("utf-8")) < 32:
    raise RuntimeError("JWT_SECRET must contain at least 32 bytes")
