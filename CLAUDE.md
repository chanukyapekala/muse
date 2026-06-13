# muse — Development Guide

## Vision

muse is a **private, multi-model AI synthesis tool** built around one core mechanic: fan out a prompt to several models in parallel, then have a judge return one authoritative answer with a trust score. The user sees the answer, not the noise.

muse ships as **two products that share the engine, judge concept, and privacy posture**:

| Product | Audience | Distribution | Use case |
|---|---|---|---|
| **muse CLI** | Developers | `pip install muse-ai` (PyPI) | Multi-model code synthesis + validation in the terminal |
| **muse iOS** | Students, individuals | App Store (lightweight) | Private multi-model chat on-device with optional cloud providers |

**Privacy is non-negotiable.** No muse server, no telemetry. Prompts go device-to-API. On-device MLX mode is fully airgapped.

**BYOK pricing** replaces $20/mo subs with pay-per-token; on-device MLX gives a $0 offline mode.

---

## Strategic positioning

The structurally unique thing about muse — what no aggregator (Poe, ChatHub, TypingMind) ships — is the **judge + trust score**. Product strategy doubles down on that:

- **CLI** — framed as a "code synthesis validation deck." Use an **asymmetric pool** (cheap/local generators + one frontier judge) to keep cost low. Move from LLM-vibes confidence to **deterministic trust signals**: AST equivalence for code, textual similarity for prose. Organic growth via PR-attached confidence blocks; enterprise-friendly because the offline mode passes data-exfiltration review.
- **iOS** — leans into privacy + on-device. Lightweight binary, chat UI, models downloaded on demand. Differentiator vs. ChatGPT/Claude apps is private multi-model judging in your pocket with $0 cost in offline mode.

---

## Current state (on `main`)

### Shipped

- **Python engine** (`src/muse/engine/`) — `Provider` protocol, async fan-out orchestrator, judge with trust scoring
- **Python providers** — Anthropic, OpenAI, Gemini, Qwen, plus on-device `mlx_local.py`
- **CLI** (`muse "prompt"`) + **local FastAPI server** (`muse serve`)
- **SQLite session storage** at `~/.muse/history.db`
- **iOS app** (`MuseApp/`) — SwiftUI chat UI, on-device MLX (Llama 3.2 3B Instruct 4-bit), cloud providers, API keys in iOS Keychain

### Partial

- **Personas** — `src/muse/personas.toml` exists and is wired into the API + orchestrator. CLI `--persona` flag not yet added.
- **Cost tracking** — `ModelResult` carries token + cost fields; CLI/API don't surface them.

---

## Architecture

```
src/muse/                              ← Python backend (CLI target)
  engine/
    types.py                           ← ModelResult, MuseRequest, MuseResponse
    orchestrator.py                    ← async fan-out to providers
    judge.py                           ← synthesis with trust scoring
    providers/
      base.py                          ← Provider protocol
      anthropic.py / openai_provider.py / gemini.py / qwen.py / mlx_local.py
    storage/
      sqlite_store.py                  ← local session history (~/.muse/history.db)
  cli.py                               ← Typer CLI frontend
  api.py                               ← FastAPI local API server
  personas.toml                        ← persona presets

MuseApp/                               ← iOS app (App Store target)
  MuseApp/
    Engine/MuseEngine.swift            ← fan-out orchestrator + judge
    Providers/
      MLXProvider.swift                ← on-device Llama 3.2 3B (4-bit)
      AnthropicProvider.swift / OpenAIProvider.swift
    Storage/                           ← Keychain for API keys
    Views/                             ← ChatView, SettingsView
```

**Adding a new provider (Python):** Create a class in `engine/providers/` implementing `Provider` (slug, name, generate, is_available), then register it in `engine/orchestrator.py:get_all_providers()`.

**Adding a new provider (iOS):** Create a class conforming to `ModelProvider` in `MuseApp/Providers/`, then register it in `MuseEngine.reloadProviders()`.

**Frontend contract:** All frontends consume `MuseResponse` — `answer` (judge synthesis), `trust_score`, `raw_responses` (expandable on demand).

---

## Roadmap

### CLI track

**Phase 5 — OpenRouter migration + `muse init`** *(next)*
- Single `OPENROUTER_API_KEY` replaces per-provider keys
- `muse init` interactive setup writes `~/.config/muse/config.toml`
- Data-driven model roster (no hardcoded provider classes)
- Surface cost tracking from unified OpenRouter usage metadata

**Phase 6 — Local context + repo awareness**
- `context.py` repository crawler (respects `.gitignore` / `.museignore`)
- Pre-filter code chunks and docs relevant to the prompt
- Wire pre-filtered context into the asymmetric pool

**Phase 6b — Deterministic trust signals**
- Pairwise textual similarity across responses
- Python AST equivalence for code blocks — different model outputs that parse to the same AST lock confidence to 1.0
- Replace/augment the current LLM-judged trust score

**Phase 7 — PyPI distribution**
- Publish as `muse-ai` for `pip install muse-ai`
- Pin runtime deps in `pyproject.toml`

### iOS track

**Goal:** lightweight App Store binary — small download, models pulled on demand.

- Trim dependencies and bundle size
- Persist chat history (SwiftData)
- Carry persona presets across from the Python side
- TestFlight validation before App Store submission

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

Post-Phase 5, only `OPENROUTER_API_KEY` will be required (persisted in `~/.config/muse/config.toml` via `muse init`).
