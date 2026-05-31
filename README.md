# muse

> Your private AI — multi-model synthesis with a built-in judge.

**muse** sends your prompt to multiple AI models concurrently, then a judge evaluates all responses and returns **one synthesized answer with a trust score**. You don't see four competing answers — you get *the* answer, backed by consensus across models.

**Privacy-first.** Your prompts go directly from your device to model APIs using your own keys. No muse server, no telemetry, no data leakage. On-device inference via Apple MLX means you can use muse on a plane with zero network calls.

## How it works

```
You → "How should I structure my portfolio?"

     ┌──────────┐
     │  muse    │
     └────┬─────┘
          │ fan-out (concurrent)
    ┌─────┼──────┬──────┐
    ▼     ▼      ▼      ▼
  Claude  GPT  Gemini  MLX(local)
    │     │      │      │
    └─────┴──────┴──────┘
          │
          ▼
       Judge (Claude Opus)
          │
          ▼
    One answer + trust score: 0.87
```

## Quickstart

```bash
# Clone and install
git clone https://github.com/chanukyapekala/muse
cd muse
uv sync

# Configure API keys
cp .env.example .env   # edit with your keys

# Run via CLI
uv run muse "should I build muse as a CLI or WebUI?"

# Or start the local API server
uv run muse serve
# POST http://localhost:8000/muse {"prompt": "your question"}
```

## Usage

### CLI

```bash
# Get a synthesized answer across all models
muse "your idea or question here"

# See raw model responses (hidden by default)
muse --show-all "is EU lakehouse SaaS viable?"

# Restrict to specific models
muse --model claude --model openai "best stack for a Python CLI"

# Skip the judge (just collect raw responses)
muse --no-judge "brainstorm names for my data product"
```

### Local API server

```bash
# Start the server (localhost only — never exposed to network)
muse serve

# Query it from anywhere on your machine
curl -X POST http://localhost:8000/muse \
  -H "Content-Type: application/json" \
  -d '{"prompt": "how should I structure my portfolio?"}'

# Browse session history
curl http://localhost:8000/sessions
```

**API response:**
```json
{
  "session_id": "...",
  "answer": "The judge's synthesized recommendation...",
  "trust_score": 0.87,
  "total_cost_usd": 0.03,
  "raw_responses": [...]
}
```

## Architecture

```
src/muse/
  engine/                    ← core (shared across all frontends)
    types.py                 ← ModelResult, MuseRequest, MuseResponse
    orchestrator.py          ← async fan-out to providers
    judge.py                 ← synthesis with trust scoring
    providers/
      base.py                ← Provider protocol
      anthropic.py           ← Claude
      openai_provider.py     ← GPT
      gemini.py              ← Gemini
      qwen.py                ← Qwen
    storage/
      sqlite_store.py        ← local session history (~/.muse/history.db)
  cli.py                     ← Typer CLI frontend
  api.py                     ← FastAPI local API server
```

## Supported models

| Slug | Provider | Default model |
|------|----------|---------------|
| `claude` | Anthropic | claude-opus-4-5 |
| `openai` | OpenAI | gpt-4o |
| `gemini` | Google | gemini-1.5-pro |
| `qwen` | Alibaba DashScope | qwen-max |

Override any model via `.env` — e.g. `OPENAI_MODEL=gpt-4o-mini`.

## Privacy guarantees

- **BYOK** — your API keys, stored in `.env` (CLI) or Keychain (iOS). Never leave your device.
- **Localhost only** — the API server binds to `127.0.0.1`. Not accessible from the network.
- **No telemetry** — no analytics, no crash reporting, no external calls except to model providers you chose.
- **On-device mode** — MLX inference runs entirely on your Apple Silicon. Zero network calls.
- **Local storage** — session history lives in `~/.muse/history.db` on your machine. No cloud sync.

## Roadmap

| Phase | What | Status |
|-------|------|--------|
| 1 | Core engine — orchestrator, providers, judge, CLI | Done |
| 2 | Local API server + SQLite session storage | Done |
| 3 | MLX on-device provider (Apple Silicon — offline mode) | Next |
| 4 | iOS app (SwiftUI — prompt → judge answer → done) | Planned |
| 5 | OpenRouter migration (one API key for 200+ models) | Planned |
| 6 | Persona library (`--persona "code reviewer"`) | Planned |

## Development

```bash
uv sync --extra dev                                  # install with dev deps
uv run pytest                                        # run tests
uv run ruff check --fix . && uv run ruff format .   # lint + format
uv run mypy src/                                     # type check
```

## License

MIT
