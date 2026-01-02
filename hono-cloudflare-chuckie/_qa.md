# QA checklist — mini-dbt (MVP)

## Quick smoke tests

1. Install dependencies and run precompile

   pnpm install
   pnpm run precompile-templates

2. Set up local database (for local dev)

   pnpm run db:migrate
   pnpm run db:seed

3. Run dev server

   pnpm run dev

4. Manual API checks

- Home page
  GET http://localhost:8788/
- List models
  GET http://localhost:8788/models
- View model source
  GET http://localhost:8788/models/example/view
- Compile model
  GET http://localhost:8788/models/example/compile
- Execute model (shows compiled SQL and results)
  GET http://localhost:8788/models/example/execute
- Test variables: Set VARIABLES env var to {"start_date": "2021-01-01"} and check if compiled SQL uses 2021 date
- Materialize model: POST http://localhost:8788/jobs/materialize with {"model": "example"} and check if it executes against D1
- Check logs: Ensure console logs appear for compilation, materialization, and errors

5. Validate default model
- Set env var locally: DEFAULT_MODEL=raptor-mini-preview
- Call `/models/example/compile` and ensure response includes `defaultModel: "raptor-mini-preview"`

## Technical notes

- Templates are precompiled to raw strings at build time (no Nunjucks runtime in production)
- Variables use simple string replacement: `{{ var('key', default) }}` → value or eval(default)
- Refs are inlined recursively: `{{ ref('model') }}` → (compiled SQL of model)
- Local dev uses eval for default values (warning expected), production should avoid complex defaults
