from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "momentum-streaming-asr"
    log_level: str = "info"

    riva_uri: str = Field(..., alias="RIVA_URI")
    riva_use_ssl: bool = Field(True, alias="RIVA_USE_SSL")
    riva_api_key: str | None = Field(default=None, alias="RIVA_API_KEY")
    riva_asr_model: str = Field("parakeet-ctc-1.1b-asr", alias="RIVA_ASR_MODEL")
    riva_language_code: str = Field("en-US", alias="RIVA_LANGUAGE_CODE")

    sample_rate_hz: int = Field(16000, alias="SAMPLE_RATE_HZ")

    supabase_url: str = Field(..., alias="SUPABASE_URL")
    supabase_service_key: str = Field(..., alias="SUPABASE_SERVICE_KEY")
    supabase_table: str = Field("memos", alias="SUPABASE_TABLE")


settings = Settings()
