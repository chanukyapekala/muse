# muse — Development Guide

## Vision

muse is a **private, multi-model AI synthesis tool** built around one core mechanic: fan out a prompt to several models in parallel, then have a judge return one authoritative answer with a trust score. The user sees the answer, not the noise.

muse ships as **two products with different shapes but a shared privacy posture**:

| Product | Audience | Distribution | Shape |
|---|---|---|---|
| **muse CLI** | Developers | `pip install muse-ai` (PyPI) | Multi-model code synthesis + judged validation in the terminal |
| **muse iOS** | Students, individuals | App Store (lightweight) | **Single-model on-device chat** — no network, no accounts, no API keys |

**Privacy is non-negotiable.** On iOS this is structural: zero LLM network calls, the model and inference both run on-device via MLX. On CLI, prompts go device-to-API directly (no muse server, no telemetry).

The CLI keeps the multi-model judge story (that's its differentiator). iOS deliberately drops it — one model, simpler product, easier App Store review.

---

## Strategic positioning

The two products have different moats:

- **CLI** — framed as a "code synthesis validation deck." Use an **asymmetric pool** (cheap/local generators + one frontier judge) to keep cost low. Move from LLM-vibes confidence to **deterministic trust signals**: AST equivalence for code, textual similarity for prose. Organic growth via PR-attached confidence blocks; enterprise-friendly because the offline mode passes data-exfiltration review.
- **iOS** — leans into structural privacy. Bundled MLX model (Llama 3.2 1B 4-bit), no network calls, no accounts, no setup. The niche to own: polished + bundled-model + zero-network + works-on-any-A14+-device. Existing on-device chat apps (LLM Farm, Private LLM, MLC Chat) either require model setup, charge upfront, or feel like research demos.

---

## Current state (on `main`)

### Shipped

- **Python engine** (`src/muse/engine/`) — `Provider` protocol, async fan-out orchestrator, judge with trust scoring
- **Python providers** — Anthropic, OpenAI, Gemini, Qwen, plus on-device `mlx_local.py`
- **CLI** (`muse "prompt"`) + **local FastAPI server** (`muse serve`)
- **SQLite session storage** at `~/.muse/history.db`
- **iOS app** (`MuseApp/`) — SwiftUI chat UI, on-device MLX (Llama 3.2 1B Instruct 4-bit). No cloud providers, no API keys, no Keychain — fully on-device.
- **On-device voice input** (iOS) — `SFSpeechRecognizer` with `requiresOnDeviceRecognition=true` and `taskHint=.dictation`. Audio never leaves the device. Tolerates pauses by restarting recognition requests across `isFinal` while accumulating committed transcript.
- **Model preload on launch** (iOS) — `MuseEngine.init()` kicks off `loadModel()` so the ~700 MB download starts when the app opens, not when the user sends their first prompt. Send button + text field are disabled until model is ready.

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
    App/MuseApp.swift                  ← entry point
    Engine/
      MuseEngine.swift                 ← single on-device MLX call
      Types.swift                      ← ModelResult, MuseResponse
    Providers/
      ProviderProtocol.swift           ← future-proofing for adding a second on-device model
      MLXProvider.swift                ← Llama 3.2 1B 4-bit via MLX Swift
    Views/                             ← IdeateView, HistoryView, SettingsView
```

**Adding a new provider (Python CLI):** Create a class in `engine/providers/` implementing `Provider` (slug, name, generate, is_available), then register it in `engine/orchestrator.py:get_all_providers()`.

**iOS provider strategy:** iOS is intentionally single-model for v1. `ProviderProtocol` is kept so we can drop in a second on-device model later without re-architecting.

**Frontend contract (CLI):** `MuseResponse` — `answer` (judge synthesis), `trust_score`, `raw_responses` (expandable on demand). iOS has its own simpler `MuseResponse` (prompt + answer + createdAt).

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

**Goal:** App Store v1 — single bundled on-device model, "install and chat."

**Done**
- Llama 3.2 1B 4-bit via MLX, fully on-device
- Voice input via `SFSpeechRecognizer` (on-device, dictation hint, pause-tolerant)
- Model preload on launch + ready-gated send button
- Chat history opt-in toggle (UserDefaults; in-memory only for now)
- `PrivacyInfo.xcprivacy` manifest, `ITSAppUsesNonExemptEncryption=NO`

**Remaining for App Store v1** (active branch: `ios/appstore-submission`)

*Must-have* (blocks submission or fails App Review):
- **SwiftData chat persistence** — toggle currently writes to UserDefaults but no backend exists; Settings claims "saved locally" but nothing is saved. Reviewer will test this and fail it. Need `@Model StoredChatSession`, `ModelContainer` in `MuseApp.swift`, save-on-response, load-in-HistoryView, "Clear history" button.
- **Copy on long-press** — `.contextMenu` on user bubble + AI response. Fundamental chat UX; absence is jarring.
- Privacy policy text — host on GitHub Pages, paste URL into App Store Connect
- App Store listing copy — name, subtitle, keywords, description, what's new
- Drop final app icon into `Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024)

*Polish before TestFlight*:
- Onboarding screen — first-launch screen reinforcing "no accounts, no keys, on-device"
- Haptic feedback on send/receive

*Then*: TestFlight validation, App Store submission

**External setup** (user-side; not code)
- Confirm paid Apple Developer Program membership (free tier can't submit to App Store)
- Create App Store Connect app record (bundle ID `com.chanukya.muse`, Team `7HWUR5MR38`)
- Take screenshots at iPhone 6.7" minimum

**Out of scope for v1** (consider for later releases): multiple on-device models with judge, persona presets, SwiftData chat history backing the toggle, image input via VLM swap.

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
