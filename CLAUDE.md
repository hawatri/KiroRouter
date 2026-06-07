# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Companion docs

`AGENTS.md` is the authoritative guide for this repo. It documents the project philosophy, code conventions (naming, type hints, docstring style, logging via loguru), testing rules, and common pitfalls. **Read it before non-trivial changes.** This file only covers what `AGENTS.md` does not, plus the highest-leverage facts.

Two principles from `AGENTS.md` that materially constrain implementation choices:

- **Complete feature consistency**: any feature must be implemented for both OpenAI and Anthropic surfaces, and for both streaming and non-streaming paths. Test coverage must cover all four combinations.
- **Paranoid testing + network isolation**: every change ships with tests; tests must never make real network calls (`tests/conftest.py` installs a `block_all_network_calls` fixture).

## Commands

```bash
# Run the server (FastAPI + uvicorn)
python main.py                    # 0.0.0.0:8000
python main.py --port 9000        # override port
python main.py --host 127.0.0.1 --port 9000

# Tests (pytest, configured in pytest.ini, testpaths=tests)
pytest                            # full suite
pytest -v -x                      # verbose, stop on first failure
pytest tests/unit/test_auth_manager.py -v
pytest tests/unit/test_auth_manager.py::TestKiroAuthManagerInitialization::test_initialization_stores_credentials -v
pytest tests/unit/  tests/integration/

# Coverage (requires pytest-cov, not in requirements.txt)
pip install pytest-cov && pytest --cov=kiro --cov-report=html

# Install deps
pip install -r requirements.txt

# Docker
docker-compose up -d --build
docker-compose logs -f
```

`manual_api_test.py` is excluded from pytest collection — it is an interactive script that hits the real Kiro API. Run it explicitly with `python manual_api_test.py`.

## Architecture

The gateway is a translation layer between client API formats (OpenAI / Anthropic) and the Kiro upstream (Amazon Q Developer / CodeWhisperer). Every request flows through the same five stages; the stage modules are split per direction.

```
client → routes_{openai,anthropic}      auth, validation, request entry
       → converters_{openai,anthropic}  client format → UnifiedMessage → Kiro payload
       → http_client.KiroHttpClient     POST to Kiro with retry on 403/429/5xx
       → parsers + streaming_{openai,anthropic}  Kiro AWS event-stream → client SSE
       → response back to client
```

`converters_core.py` and `streaming_core.py` hold logic shared by both API surfaces — when adding a feature, the shared piece almost always belongs in `*_core.py` and the API-specific glue in the per-surface adapter. This is how feature consistency (item 10 in `AGENTS.md`) is enforced structurally.

Key cross-cutting subsystems (each isolated to one module so it can be reasoned about independently):

- **Auth** (`auth.py` + optional `account_manager.py`): four credential sources auto-detected — JSON file (Kiro IDE), refresh-token env var, kiro-cli SQLite DB, AWS SSO OIDC. Auth type is decided by the *shape* of the credential, not config: presence of `clientId`/`clientSecret` ⇒ AWS SSO OIDC, otherwise Kiro Desktop Auth. Token refresh is async-lock-protected. Setting `ACCOUNT_SYSTEM=true` in `.env` enables `account_manager.py`, which adds a multi-account circuit breaker with sticky selection — on first run it migrates `.env` credentials into `credentials.json` and from that point ignores `.env` for accounts.
- **Model resolution** (`model_resolver.py` + `cache.py`): four-stage pipeline — *normalize name* (dashes→dots, strip date suffixes, e.g. `claude-haiku-4-5-20251001` → `claude-haiku-4.5`) → *dynamic cache* from `/ListAvailableModels` → *hidden models* from `config.HIDDEN_MODELS` → *pass-through* (let Kiro reject unknown names). Don't gatekeep models in this layer.
- **Streaming** (`streaming_*.py` + `parsers.py` + `thinking_parser.py`): parses AWS event-stream framing, extracts `<thinking>...</thinking>` blocks via FSM, deduplicates tool calls, applies first-token timeout. **Streaming MUST use a per-request `httpx.AsyncClient`** — reusing a shared client causes CLOSE_WAIT leaks. Non-streaming requests reuse the shared pooled client.
- **Truncation recovery** (`truncation_state.py` + `truncation_recovery.py`): tracks partial-response state and resumes when Kiro cuts a response short.
- **Error classification** (`network_errors.py`, `kiro_errors.py`, `account_errors.py`): converts low-level exceptions into actionable messages. Kiro's "Improperly formed request" is notoriously vague — see `AGENTS.md` §"About 'Improperly formed request' Errors".
- **Debug logging** (`debug_logger.py` + `debug_middleware.py`): off by default. `DEBUG_MODE=errors` (recommended for support) writes per-request artifacts to `debug_logs/` only on 4xx/5xx; `DEBUG_MODE=all` writes for every request.
- **Payload guards** (`payload_guards.py`): pre-flight validation against known Kiro API quirks before sending upstream.

## Editing rules specific to this repo

- Touching the request/response path? Update both `*_openai` and `*_anthropic` modules, both streaming and non-streaming paths, and add tests for all four combinations. PRs lacking this symmetry are rejected per `AGENTS.md`.
- Tests live in `tests/unit/` and `tests/integration/`. Check `tests/README.md` to find the right existing `test_*.py` — avoid creating new test files unless adding a whole new module.
- Configuration loads from `.env` (see `.env.example` for the full list). CLI flags > env vars > defaults.
- Use `loguru` for logging; never `print`. Use `httpx` for HTTP; never `requests` (despite it appearing in older docs, it's not in `requirements.txt`).
- All identifiers, comments, and docstrings in English. Google-style docstrings with Args/Returns/Raises. Type hints on every parameter and return.
