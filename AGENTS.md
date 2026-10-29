# PROJECT KNOWLEDGE BASE

**Generated:** 2026-10-29
**Commit:** 7c43f96
**Branch:** main

## OVERVIEW

FastMCP stdio server for MercadoLibre's REST API (listings, orders, shipping, ads) across 18 country sites. Python 3.11, uv, hatchling, httpx. One OAuth profile per site, plus an optional account alias.

## STRUCTURE

```
mercadolibre-mcp/
├── src/mercadolibre_mcp/   # entire runtime; no __main__.py
│   ├── main.py             # FastMCP, input models, tool handlers, mcp.tool() registration
│   ├── auth.py             # PKCE, TokenStore, setup CLI
│   ├── client.py           # sync httpx wrapper, 429 retry
│   └── __init__.py         # __version__ only — Hatch reads this
├── tests/                  # unittest, offline; no package __init__.py
├── .github/workflows/ci.yml
└── README.es.md            # translation; pyproject readme is README.md
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add or change a tool | `src/mercadolibre_mcp/main.py` | Pydantic input beside the handler; register with `mcp.tool()`, not a decorator |
| OAuth, profiles, PKCE | `src/mercadolibre_mcp/auth.py` | CLI is `python -m mercadolibre_mcp.auth` |
| HTTP, site/account, 429 | `src/mercadolibre_mcp/client.py` | Base `https://api.mercadolibre.com` |
| Version bump | `src/mercadolibre_mcp/__init__.py` | Sole source; do not copy into pyproject |
| Offline regressions | `tests/` | `unittest`; mock `get_client` / HTTP |
| MCP client launch snippets | `README.md` | `uv --directory … run python -m mercadolibre_mcp.main` |

## CONVENTIONS

- Src layout. `python -m mercadolibre_mcp` does not work. Server: `python -m mercadolibre_mcp.main` or console script `mercadolibre-mcp` → `main:run` → `mcp.run(transport="stdio")`. `--version` is a manual `sys.argv` check, not argparse.
- Tools take one Pydantic model (`SiteParam` plus fields) and return dicts. Failures are `{"error": ...}`. Handlers catch `_CLIENT_ERRORS` (`MercadoLibreError`, `RuntimeError`) only. Unknown `site_id` / bad alias raise `ValueError` and escape that handler.
- `site_id`: arg, else `MERCADOLIBRE_SITE_ID`, else `MLA`. `account`: arg, else `MERCADOLIBRE_ACCOUNT`, else the site default. Alias charset `^[A-Za-z0-9_-]{1,32}$`. Profile file `~/.mercadolibre_mcp/profiles/{SITE}.json` or `{SITE}__{alias}.json`, mode 600. Raw MCP arguments are `{"input": {...}}`, not flat fields.
- `.env.example` drifts: it omits `MERCADOLIBRE_ACCOUNT` and lists `REQUEST_TIMEOUT`, which nothing reads. Client timeout is `DEFAULT_TIMEOUT = 30` in `client.py`.
- Modules do not load `.env`. Use `uv run --env-file .env`. `python-dotenv` is declared and unused under `src/`.
- Ruff: py311, line-length 100, select `E,F,I,N,W,UP`; `tests/*` ignores `E501`. Pyright `standard` points at `.venv` but CI does not run it.
- Tests are unittest. `pytest` / `pytest-asyncio` are dev extras and unused. No `conftest.py`. Tests import the installed package, so `uv sync` first.
- English `README.md` is the packaged readme. `README.es.md` is a translation and can lag.

## ANTI-PATTERNS (THIS PROJECT)

- NEVER call `ensure_token(..., interactive=True)` or `input()` on a tool path. A missing profile must return the auth-CLI hint, not block.
- NEVER print or log the authorization URL, callback, verifier, state, client secret, or tokens. Browser-launch failure is fail-closed.
- NEVER commit `.env` or copy `~/.mercadolibre_mcp/` into the repo. The auth CLI accepts `--client-secret`; do not use it. Prefer `uv run --env-file .env`.
- Do not POST descriptions or put description text on the item body. Updates are `PUT items/{id}/description?api_version=2` with `{"plain_text": ...}`.
- `delete_item` is `PUT items/{id}` `{"status": "closed"}`, not HTTP DELETE. Relist later via `relist_item`.
- Writes must use the profile that owns the listing. A mismatched `site_id` / `account` is a 403.
- Tests must not hit the network, open a browser, or read real profiles.
- Do not trust the README "Project Structure" tree; it omits `tests/`, CI, and `uv.lock`.

## UNIQUE STYLES

- Eighteen sites in `AUTH_DOMAINS` / `SITE_NAMES`. Same app credentials; the token is per seller account. Cached tokens are treated as expired 5 minutes early. Legacy `~/.mercadolibre_mcp/tokens.json` migrates on `TokenStore` init.
- CLI default redirect is `http://localhost:8080/callback`. No local callback server — the user pastes the redirect. Registered URI must match the app exactly (empty path and `/` are treated as the same target).
- Optional `BM25Search` transform; a missing `fastmcp.server.transforms.search` is swallowed.
- Tool handlers are async; HTTP is sync `httpx`. A 429 sleeps on `Retry-After` (default 5s) and recurses with no retry cap.
- Shared clients live in `_clients`, keyed by `(site_id, account)`.

## COMMANDS

```bash
uv sync --extra dev
uv run --extra dev ruff check src tests
uv run --extra dev python -m unittest discover -s tests -v
uv run --env-file .env python -m mercadolibre_mcp.auth --site-id MLA
uv run python -m mercadolibre_mcp.auth --list
uv run mercadolibre-mcp --version
```

## NOTES

- Symbol ref counts unmeasured: no Python LSP, no ast-grep binary. Locations above are from a Python `ast` walk and direct reads.
- Hotspots: `main.py` (~952), `auth.py` (~695), `tests/test_auth_pkce.py` (~509).
- No `LICENSE` file; `pyproject.toml` declares MIT. No `py.typed`.
- CI is ruff + unittest only (`.github/workflows/ci.yml`).
