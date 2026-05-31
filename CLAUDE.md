# muse — Development Plan

## What muse is

A CLI tool that fans out an ideation prompt to multiple AI models concurrently, then runs a judge (Claude Opus) that scores all responses and produces a `synthesis.md` with the best combined recommendation.

The differentiator: not a "side-by-side UI for many models" — muse explicitly surfaces **consensus vs. disagreement** across models and synthesizes them into one authoritative answer.

---

## Current state (Phase 1 — complete)

- `orchestrator.py` — async fan-out to Claude, OpenAI GPT, Gemini, Qwen
- `models/adapters.py` — one adapter per provider, each returns structured markdown
- `judge.py` — Claude Opus reads all responses, scores on Feasibility/Novelty/Specificity, writes synthesis
- `writer.py` — saves session to `ideas/<timestamp_hash>/` with one `.md` per model + `synthesis.md`
- `cli.py` — Typer CLI with `--model`, `--no-judge`, `--show-all` flags
- `config.py` — Pydantic Settings, all keys and model names overridable via `.env`

**Known gap:** The previous run (`ideas/20260409_235749_ebc41c/`) failed with 401s — no `.env` file was present.

---

## MVP gaps

| Item | Status | Notes |
|------|--------|-------|
| OpenRouter aggregation | Missing | Currently 4 separate API keys/adapters; OpenRouter replaces all with one pipe |
| Merge / Synthesis | Partial | Judge does this, but no explicit "consensus vs. disagreement" section |
| Cost Tracking | Missing | No token counting, no $/call display |
| Persona Library | Missing | `SYSTEM_PROMPT` is hardcoded in adapters; no `--persona` flag |

---

## Roadmap

### Phase 2 — Cost Tracking

Token usage is already returned by every API response but is not surfaced.

- Add `input_tokens` and `output_tokens` to `ModelResult`
- Add per-model cost rates to `config.py` (overridable via `.env`)
- Display a cost table in the CLI after fan-out
- Include total cost in `synthesis.md` header

### Phase 3 — Persona Library

The system prompt in `adapters.py` is hardcoded. Personas allow the prompt to be shaped by a role.

- Add `--persona` / `-p` CLI flag (e.g. `--persona "Expert Code Reviewer"`)
- Ship built-in presets: `code-reviewer`, `creative-writer`, `product-manager`, `devil-advocate`
- Store presets in `src/muse/personas.toml`
- Custom persona string is injected as a role prefix into the system prompt

### Phase 4 — OpenRouter Migration

Currently requires 4 separate API keys. OpenRouter provides one endpoint for 200+ models.

- Replace the 4 adapters with a single OpenRouter adapter (OpenAI-compatible)
- Single `OPENROUTER_API_KEY` in `.env`
- Model roster becomes data-driven (a list in config), not hardcoded adapters
- Enables easy expansion: add Mistral, LLaMA, Grok, etc. without new adapter code
- Cost tracking integrates naturally — OpenRouter returns unified usage metadata

### Phase 5 — Synthesis Quality

Improve the judge output to be more explicitly useful.

- Add a **Consensus** section: what all (or most) models agreed on
- Add a **Disagreements** section: where models diverged and why it matters
- Score the judge's own confidence
- Support `--judge-model` CLI flag to override the synthesis model

---

## Architecture

```
muse "prompt"
  └── orchestrator.py       async fan-out
        ├── adapters.py     one per model (or one OpenRouter adapter post-Phase 4)
        │     claude.md
        │     openai.md
        │     gemini.md
        │     qwen.md
        └── judge.py        Claude Opus synthesizes all → synthesis.md
              writer.py     saves ideas/<session>/
```

---

## Development commands

```bash
uv sync --extra dev        # install with dev deps
uv run muse "your prompt"  # run
uv run pytest              # tests
uv run ruff check --fix . && uv run ruff format .  # lint + format
uv run mypy src/           # type check
```

## Environment

Copy `.env.example` to `.env` and fill in keys:

```
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GOOGLE_API_KEY=
QWEN_API_KEY=
```

Post-Phase 4, only `OPENROUTER_API_KEY` will be required.