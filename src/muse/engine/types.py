"""Shared types for the muse engine — the contract between all frontends."""

from dataclasses import dataclass, field
from datetime import UTC, datetime


@dataclass
class ModelResult:
    name: str
    slug: str
    content: str
    error: str | None = None
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0
    provider_type: str = "cloud"  # "cloud" or "local"
    latency_ms: int = 0


@dataclass
class MuseRequest:
    prompt: str
    enabled_models: list[str] | None = None
    skip_judge: bool = False
    persona: str | None = None


@dataclass
class MuseResponse:
    session_id: str = ""
    prompt: str = ""
    answer: str = ""  # judge synthesis — the main output
    trust_score: float | None = None
    raw_responses: list[ModelResult] = field(default_factory=list)
    total_cost_usd: float = 0.0
    created_at: str = field(default_factory=lambda: datetime.now(UTC).isoformat())
