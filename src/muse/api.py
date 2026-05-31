"""muse API — local-only FastAPI server. No data leaves your machine except to model providers."""

import time
import uuid

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from muse.engine.judge import judge
from muse.engine.orchestrator import SYSTEM_PROMPT, fan_out, get_all_providers
from muse.engine.storage.sqlite_store import SQLiteStore
from muse.engine.types import MuseResponse

app = FastAPI(
    title="muse",
    description="Multi-model AI synthesis — local-first, privacy-first.",
    version="0.2.0",
)

# Allow local frontends (iOS simulator, web dev server) to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

store = SQLiteStore()


# --- Request/Response models for the API ---


class IdeateRequest(BaseModel):
    prompt: str
    models: list[str] | None = None
    skip_judge: bool = False
    persona: str | None = None


class IdeateResponse(BaseModel):
    session_id: str
    answer: str
    trust_score: float | None = None
    total_cost_usd: float = 0.0
    raw_responses: list[dict] | None = None


class SessionSummary(BaseModel):
    session_id: str
    prompt: str
    trust_score: float | None
    total_cost_usd: float
    created_at: str


# --- Endpoints ---


@app.post("/muse", response_model=IdeateResponse)
async def ideate(req: IdeateRequest) -> IdeateResponse:
    """Fan out prompt to models, judge, and return the synthesized answer."""
    results = await fan_out(
        prompt=req.prompt,
        enabled_models=req.models,
        persona=req.persona,
    )

    answer = ""
    trust_score = None
    if not req.skip_judge:
        answer, trust_score = await judge(req.prompt, results)

    total_cost = sum(r.cost_usd for r in results)

    # Persist session
    session_id = str(uuid.uuid4())
    response = MuseResponse(
        session_id=session_id,
        prompt=req.prompt,
        answer=answer,
        trust_score=trust_score,
        raw_responses=results,
        total_cost_usd=total_cost,
    )
    await store.save(response)

    return IdeateResponse(
        session_id=session_id,
        answer=answer,
        trust_score=trust_score,
        total_cost_usd=total_cost,
        raw_responses=[
            {
                "name": r.name,
                "slug": r.slug,
                "content": r.content,
                "error": r.error,
                "latency_ms": r.latency_ms,
            }
            for r in results
        ],
    )


@app.get("/sessions", response_model=list[SessionSummary])
async def list_sessions(limit: int = 50) -> list[SessionSummary]:
    """List recent sessions."""
    sessions = await store.list_sessions(limit=limit)
    return [
        SessionSummary(
            session_id=s.session_id,
            prompt=s.prompt,
            trust_score=s.trust_score,
            total_cost_usd=s.total_cost_usd,
            created_at=s.created_at,
        )
        for s in sessions
    ]


@app.get("/sessions/{session_id}")
async def get_session(session_id: str) -> dict:
    """Retrieve a full session with all model responses."""
    session = await store.get(session_id)
    if session is None:
        return {"error": "Session not found"}
    return {
        "session_id": session.session_id,
        "prompt": session.prompt,
        "answer": session.answer,
        "trust_score": session.trust_score,
        "total_cost_usd": session.total_cost_usd,
        "created_at": session.created_at,
        "raw_responses": [
            {
                "name": r.name,
                "slug": r.slug,
                "content": r.content,
                "error": r.error,
                "input_tokens": r.input_tokens,
                "output_tokens": r.output_tokens,
                "cost_usd": r.cost_usd,
                "latency_ms": r.latency_ms,
            }
            for r in session.raw_responses
        ],
    }


@app.get("/health")
async def health() -> dict:
    """Health check."""
    return {"status": "ok", "service": "muse"}


# --- OpenAI-compatible endpoint ---
# Any tool that speaks OpenAI protocol (Claude Code, Cursor, aider, etc.)
# can point at http://localhost:8000/v1 and use muse as its AI backend.


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str = "muse"
    messages: list[ChatMessage]
    max_tokens: int | None = Field(default=2048)
    temperature: float = 0.7


class ChatChoice(BaseModel):
    index: int = 0
    message: ChatMessage
    finish_reason: str = "stop"


class ChatUsage(BaseModel):
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0


class ChatResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: list[ChatChoice]
    usage: ChatUsage


@app.post("/v1/chat/completions", response_model=ChatResponse)
async def chat_completions(req: ChatRequest) -> ChatResponse:
    """OpenAI-compatible chat completions — use muse as a local AI provider."""
    # Extract system and user messages
    system = ""
    user_prompt = ""
    for msg in req.messages:
        if msg.role == "system":
            system = msg.content
        elif msg.role == "user":
            user_prompt = msg.content

    if not system:
        system = SYSTEM_PROMPT

    max_tokens = req.max_tokens or 2048

    # Route based on model name
    if req.model == "muse":
        # Full muse flow: fan-out + judge
        results = await fan_out(prompt=user_prompt, system=system, max_tokens=max_tokens)
        answer, _ = await judge(user_prompt, results)
        total_in = sum(r.input_tokens for r in results)
        total_out = sum(r.output_tokens for r in results)
    else:
        # Route to a specific provider by slug (e.g. "mlx", "claude", "openai")
        providers = get_all_providers()
        provider = next((p for p in providers if p.slug == req.model), None)
        if provider is None:
            # Fallback: try all available, pick first
            provider = providers[0] if providers else None
        if provider is None:
            answer = "No providers available. Check your API keys or install mlx-lm."
            total_in, total_out = 0, 0
        else:
            result = await provider.generate(user_prompt, system, max_tokens)
            answer = result.content
            total_in = result.input_tokens
            total_out = result.output_tokens

    return ChatResponse(
        id=f"chatcmpl-{uuid.uuid4().hex[:12]}",
        created=int(time.time()),
        model=req.model,
        choices=[
            ChatChoice(
                message=ChatMessage(role="assistant", content=answer),
            )
        ],
        usage=ChatUsage(
            prompt_tokens=total_in,
            completion_tokens=total_out,
            total_tokens=total_in + total_out,
        ),
    )


@app.get("/v1/models")
async def list_models() -> dict:
    """List available models — OpenAI-compatible."""
    providers = get_all_providers()
    models = [
        {
            "id": p.slug,
            "object": "model",
            "owned_by": "muse",
        }
        for p in providers
    ]
    # Add the special "muse" model (fan-out + judge)
    models.insert(0, {"id": "muse", "object": "model", "owned_by": "muse"})
    return {"object": "list", "data": models}


def serve(host: str = "127.0.0.1", port: int = 8000) -> None:
    """Start the muse API server (localhost only)."""
    import uvicorn

    uvicorn.run(app, host=host, port=port)


if __name__ == "__main__":
    serve()
