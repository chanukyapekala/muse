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
- **iOS app** (`MuseApp/`) — SwiftUI chat UI with on-device MLX inference and cloud provider fan-out
- **MLX on-device provider** — Llama 3.2 3B Instruct 4-bit via MLX Swift, zero cost, fully offline

### Not yet built

| Item | Phase | Notes |
|------|-------|-------|
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

MuseApp/
  MuseApp/
    Engine/                    ← Swift orchestrator + judge (MuseEngine.swift)
    Providers/                 ← MLXProvider (Llama 3.2 3B), AnthropicProvider, OpenAIProvider
    Storage/                   ← Keychain for API keys
    Views/                     ← ChatView, SettingsView
```

**Adding a new provider (Python):** Create a class in `engine/providers/` implementing `Provider` protocol (slug, name, generate, is_available), then register it in `engine/orchestrator.py:get_all_providers()`.

**Adding a new provider (iOS):** Create a class conforming to `ModelProvider` protocol in `MuseApp/Providers/`, then register it in `MuseEngine.reloadProviders()`.

**Frontend contract:** All frontends (CLI, API, iOS) consume `MuseResponse` — which contains `answer` (judge synthesis), `trust_score`, and `raw_responses` (expandable on demand).

---

## Roadmap

### Phase 3 — MLX On-Device Provider ✓

Done. Llama 3.2 3B Instruct 4-bit via MLX Swift (~1.7 GB RAM). GPU cache set to 512 MB, token cap enforced during generation.

### Phase 4 — iOS App ✓

Done. SwiftUI chat UI in `MuseApp/`. On-device MLX + cloud providers (Anthropic, OpenAI, Gemini via OpenRouter). API keys in Keychain.

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
