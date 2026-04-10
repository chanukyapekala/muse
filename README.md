# muse

> Summon multiple AI minds. Let the best idea win.

**muse** fans out your ideation prompt to Claude, OpenAI GPT, Gemini, and Qwen concurrently, saves each response as a `.md` file, then runs a judge (Claude Opus) that scores all responses and writes a `synthesis.md` with the best combined recommendation.

```
ideas/
  20250409_143022_a3f1b2/
    prompt.md
    claude.md
    openai.md
    gemini.md
    qwen.md
    synthesis.md   ← judge output
```

## Quickstart

```bash
# 1. Clone
git clone https://github.com/chanukyapekala/muse
cd muse

# 2. Install uv (if you don't have it)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 3. Install dependencies
uv sync

# 4. Configure API keys
cp .env.example .env
# edit .env with your keys

# 5. Run
uv run muse "should I build muse as a CLI or WebUI?"
```

## Usage

```bash
# Ideate across all four models
muse "your idea or question here"

# Show all model responses before synthesis
muse --show-all "is EU lakehouse SaaS viable in 2025?"

# Restrict to specific models
muse --model claude --model openai "best stack for a Python CLI tool"

# Skip the judge step (just collect responses)
muse --no-judge "brainstorm names for my data product"
```

## Development

```bash
# Install with dev dependencies
uv sync --extra dev

# Run tests
uv run pytest

# Lint + format
uv run ruff check --fix . && uv run ruff format .

# Type check
uv run mypy src/
```

## Architecture

```
muse "prompt"
  └── orchestrator.py    async fan-out to 4 model APIs
        ├── claude.md
        ├── openai.md
        ├── gemini.md
        └── qwen.md
              └── judge.py      Claude Opus reads all 4, writes synthesis.md
```

## Supported models

| Slug | Provider | Default model |
|------|----------|---------------|
| `claude` | Anthropic | claude-opus-4-5 |
| `openai` | OpenAI | gpt-4o |
| `gemini` | Google | gemini-1.5-pro |
| `qwen` | Alibaba DashScope | qwen-max |

Override any model via `.env` — e.g. `OPENAI_MODEL=gpt-4o-mini`.

## License

MIT
