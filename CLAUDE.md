# muse — Development Guide

## Vision

muse is a **private, multi-model AI synthesis tool**. You type a prompt, multiple models respond concurrently, and a judge produces one authoritative answer with a trust score. The user sees the answer, not the noise.

**Target audience:** Students and individuals who want a cheaper, private alternative to ChatGPT/Claude subscriptions. BYOK (bring your own API keys) means pay-per-token instead of $20/mo, and on-device inference via MLX means $0 for offline use.

**Privacy is non-negotiable.** No muse server, no telemetry, no data leakage. Prompts go directly from device to model API. On-device MLX mode is fully airgapped.

---

## Current state

### Done

- **Engine** (`src/muse/engine/`) — provider-based architecture with `Provider` protocol, async fan-out orchestrator, provider-agnostic judge with trust scoring
- **Providers** — Anthropic, OpenAI, Gemini, Qwen (each as a class implementing `Provider`)
- **Storage** — SQLite backend at `~/.muse/history.db` for session persistence
- **CLI** (`cli.py`) — `muse "prompt"` for synthesis, `muse serve` to start local API
- **API** (`api.py`) — FastAPI server, localhost-only, `POST /muse` → judge answer + trust score
- **Tests** — 15 tests covering orchestrator, judge, API, and storage

### Not yet built

| Item | Phase | Notes |
|------|-------|-------|
| MLX on-device provider | 3 | Apple Silicon local inference, offline mode |
| iOS app | 4 | SwiftUI, reimplements engine in Swift, MLX Swift for on-device |
| OpenRouter | 5 | Single API key for 200+ models, replaces per-provider keys |
| Persona library | 6 | `--persona` flag, presets in `personas.toml` |
| Cost tracking display | 5 | Token counts are captured but not surfaced in CLI/API |

---

## Architecture

```
src/muse/
  engine/                    ← core (shared contract for all frontends)
    types.py                 ← ModelResult, MuseRequest, MuseResponse
    orchestrator.py          ← fan_out() — async concurrent dispatch to providers
    judge.py                 ← judge() — synthesis + trust score extraction
    providers/
      base.py                ← Provider protocol (slug, name, generate, is_available)
      anthropic.py           ← Claude
      openai_provider.py     ← GPT
      gemini.py              ← Gemini
      qwen.py                ← Qwen
    storage/
      base.py                ← StorageBackend protocol
      sqlite_store.py        ← SQLite implementation
  cli.py                     ← Typer CLI (presentation only)
  api.py                     ← FastAPI local server (presentation only)
  config.py                  ← Pydantic Settings, .env-driven
  writer.py                  ← Filesystem session writer (legacy, kept for backward compat)
```

**Adding a new provider:** Create a class in `engine/providers/` implementing `Provider` protocol (slug, name, generate, is_available), then register it in `engine/orchestrator.py:get_all_providers()`.

**Frontend contract:** All frontends (CLI, API, iOS) consume `MuseResponse` — which contains `answer` (judge synthesis), `trust_score`, and `raw_responses` (expandable on demand).

---

## Roadmap

### Phase 3 — MLX On-Device Provider

The compelling feature. Local inference on Apple Silicon, zero cost, works offline.

- Add `mlx-lm` as optional dependency (Apple Silicon only)
- Implement `engine/providers/mlx_local.py` conforming to `Provider`
- Model management: `muse models download llama-3.2-3b`
- Target: quantized 1-3B models (Llama 3.2 1B = ~800MB RAM, 3B = ~2GB)
- `muse --model mlx "prompt"` for local-only mode
- `cost_usd = 0.0`, `provider_type = "local"`

### Phase 4 — iOS App

SwiftUI app, Swift-native (no Python bridging). Reimplements ~300 lines of orchestration logic.

- **UX:** Prompt input → one judge answer with trust score → expandable raw responses toggle
- Cloud providers via URLSession direct API calls
- On-device via MLX Swift (`mlx-swift`)
- API keys in iOS Keychain
- Session history in SwiftData/SQLite
- Lightweight: <20MB binary, models downloaded on demand

```
MuseApp/
  Sources/
    Engine/          ← Swift orchestrator + judge
    Providers/       ← Cloud + MLX Swift adapters
    Storage/         ← SQLite + Keychain
    Views/           ← IdeateView, ResultsView, SettingsView
```

### Phase 5 — OpenRouter Migration

Replace per-provider API keys with single OpenRouter endpoint.

- Single `OPENROUTER_API_KEY` in `.env`
- Model roster becomes data-driven (config list, not hardcoded classes)
- Cost tracking from unified OpenRouter usage metadata

### Phase 6 — Persona Library

- `--persona "code reviewer"` CLI flag
- Built-in presets in `personas.toml`: code-reviewer, creative-writer, product-manager, devil-advocate
- Persona string injected as system prompt prefix

---

## Development commands

```bash
uv sync --extra dev                                  # install with dev deps
uv run muse "your prompt"                           # run CLI
uv run muse serve                                    # start local API server
uv run pytest                                        # tests
uv run ruff check --fix . && uv run ruff format .   # lint + format
uv run mypy src/                                     # type check
```

## Environment

Copy `.env.example` to `.env` and fill in keys:

```
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GOOGLE_API_KEY=
QWEN_API_KEY=
```

Post-Phase 5, only `OPENROUTER_API_KEY` will be required.
