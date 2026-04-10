from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # API keys
    anthropic_api_key: str = ""
    openai_api_key: str = ""
    google_api_key: str = ""
    qwen_api_key: str = ""  # Alibaba DashScope key
    qwen_base_url: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"

    # Model selection (overridable via env)
    claude_model: str = "claude-opus-4-5"
    openai_model: str = "gpt-4o"
    gemini_model: str = "gemini-1.5-pro"
    qwen_model: str = "qwen-max"

    # Judge model — defaults to Claude Opus for best synthesis quality
    judge_model: str = "claude-opus-4-5"

    # Output
    output_dir: str = "ideas"


settings = Settings()
