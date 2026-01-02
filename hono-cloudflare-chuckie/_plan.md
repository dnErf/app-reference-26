# _plan.md — Cloudflare Worker: `mini-dbt` (MVP)

## Goal
Create a Cloudflare Worker (Cloudflare Pages / Workers) using **pnpm**, **Hono**, and **Nunjucks** that provides a minimal dbt-like workflow for compiling SQL models, previewing compiled SQL, and optionally executing materializations via configurable bindings (e.g., D1 or external DB). Follow the repo AGENTS workflow (spec → plan → implement → test → QA).

## Tech stack (decisions)
- Package manager: **pnpm** (fast installs, consistent lockfiles)
- Framework: **Hono** for lightweight routing and Cloudflare compatibility
- Templating: **Nunjucks** for Jinja-like templating in SQL models (see security constraints below)
- Runtime: **Cloudflare Workers / Pages** (use `wrangler.toml` / dashboard for Bindings)
- Test runner: **vitest**

## Acceptance criteria ✅
- A `package.json` and `pnpm-lock.yaml` (or instructions to use pnpm) are added with scripts: `dev`, `build`, `precompile-templates`, `test`, `deploy`.
- A `specs/model-config.json` documents configuration keys and default values (includes `defaultModel: "raptor-mini-preview"`).
- A Cloudflare Worker scaffold (`src/worker/`) using Hono is added with endpoints to:
  - list SQL models (from `models/`),
  - preview compiled SQL for a named model (compiling Nunjucks templates safely),
  - (optional) queue a materialization job (calls out to D1 or external DB via bindings).
- Templates are **precompiled at build time** and not accepted from runtime uploads in MVP (prevents server-side RCE). The precompile step produces a JS module that Worker imports.
- A runtime configuration helper reads `DEFAULT_MODEL` from Cloudflare Bindings (`c.env.DEFAULT_MODEL`) or `process.env.DEFAULT_MODEL` and falls back to `raptor-mini-preview`.
- Unit tests (vitest) for compile/preview and helper behavior.
- `_qa.md` explains how to set `DEFAULT_MODEL` in `wrangler.toml` and how to validate locally and on Pages.

## MVP scope (first iteration) — Minimal & safe
1. Project metadata & AGENT files
   - Add `specs/model-config.json` describing `defaultModel` and allowed values (includes `raptor-mini-preview`).
   - Add `_qa.md` stub with QA steps and deployment notes for Cloudflare Pages/Workers.
   - Add `package.json` with pnpm scripts and a `scripts/precompile-templates.js` tool to precompile Nunjucks templates (or use `nunjucks.precompile`).
2. Worker scaffold
   - Add `src/worker/index.ts` (Hono) exposing endpoints:
     - `GET /models` — list model names (from `models/` folder)
     - `GET /models/:name/compile` — return compiled SQL (use precompiled template renderer)
     - `POST /jobs/materialize` — enqueue a materialization job (optional, uses Queues/Bindings)
   - Configure Vite/Hono Cloudflare Pages adapter per Hono docs (dev and build via pnpm scripts).
3. Compiler & templating
   - Use Nunjucks with **precompile** step at build-time to generate safe renderer modules.
   - Restrict runtime template context to safe variables only (no arbitrary functions). Do **not** allow runtime-uploaded templates in MVP.
   - Resolve `ref()` during compile by loading referenced models and inlining (no execution) — detect cycles and error.
4. Runtime config & defaults
   - Add `lib/default-model.ts` helper that checks, in order: Cloudflare binding `c.env.DEFAULT_MODEL`, `process.env.DEFAULT_MODEL`, then falls back to `'raptor-mini-preview'`.
   - Document setting `DEFAULT_MODEL` in `wrangler.toml` and Cloudflare dashboard.
5. Tests & CI
   - Unit tests for compiler, ref-resolution, precompile step, and `lib/default-model.ts` (vitest).
   - GitHub Actions that installs `pnpm`, runs `pnpm install --frozen-lockfile`, `pnpm run precompile-templates`, `pnpm test`.
6. Docs & QA
   - Update `AGENTS.md` with a short note: "Enable Raptor mini (Preview) for all clients as the default model" and reference `specs/model-config.json`.
   - Add `_qa.md` with manual steps: run dev server (`pnpm dev`), call `/models/:name/compile`, set binding in `wrangler.toml`, and deploy to Pages to validate.

## Implementation plan — tasks (ordered)
1. Add `package.json` and pnpm scripts; add `pnpm-lock.yaml` if needed and list dependencies to install (`hono`, `nunjucks`, `vitest`, Hono Vite plugins, `@cloudflare/wrangler` tools as dev-deps).
2. Create `specs/model-config.json` and update `AGENTS.md` with the new feature note about `raptor-mini-preview` default.
3. Add `models/` example with a couple of `.sql.njk` files demonstrating `ref()` usage and small frontmatter metadata.
4. Implement `scripts/precompile-templates.js` (or npm script calling `nunjucks.precompile`) and the `src/worker` scaffold (Hono) that imports precompiled templates.
5. Implement the compiler module: load precompiled template, render with restricted context, implement `ref()` resolution (inline compiled dependency SQL), and add tests.
6. Add `lib/default-model.ts`, document `wrangler.toml` example, and wire into worker endpoints.
7. Add tests and CI; run QA checklist and finalize docs.
8. Integrate D1 database for materialization: Update `wrangler.toml` with D1 binding, modify `/jobs/materialize` endpoint to execute compiled SQL against D1 database instead of in-memory placeholder.
9. Enhance variable support: Update compiler to resolve variables from a `variables` object (loaded from Cloudflare bindings or environment) instead of just returning defaults.
10. Add database bindings configuration: Ensure `wrangler.toml` includes D1 binding and update code to use configurable binding name from specs.
11. Fix materialization execution logic: Detect SELECT queries and use `db.prepare(sql).all()` for data retrieval, otherwise use `db.exec(sql)` for DML/DDL.
12. Improve error handling and logging: Add structured logging for operations, provide specific error messages, and enhance try-catch blocks.
13. Enhance D1 setup and documentation: Update README with D1 database creation and seeding instructions, add comments to `wrangler.toml`.

## Security notes (Nunjucks & Cloudflare Workers)
- **Do not** accept user-uploaded templates in MVP. Only precompile templates from the `models/` folder during build.
- Limit the template context to simple data (no database handles, no arbitrary functions). Avoid custom filters that perform I/O.
- Prefer precompilation (faster, avoids runtime parsing) and narrower runtime render APIs.
- Sanitize any values interpolated into SQL (as needed) and clearly document that execution of compiled SQL is a separate, opt-in feature that may require parameterized queries when connecting to an actual DB.

## Risks & constraints
- Cloudflare Workers cannot run arbitrary warehouse SQL — the MVP focuses on compilation and preview; execution will be delegated to D1 or external DB via bindings later.
- Nunjucks supports rich templating but can be unsafe if templates are user-provided; we mitigate this by precompiling and restricting runtime context.

## Next step
- Implement task 1: add `package.json` (pnpm scripts), add `specs/model-config.json`, and create `models/example.sql.njk` plus a simple precompile script.

---

*Updated plan following `AGENTS.md` guidelines and the chosen stack (pnpm, Hono, Cloudflare Workers/Pages, Nunjucks). Next I'll add the `specs/` file and example models and install dependencies using pnpm.*