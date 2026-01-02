# mini-dbt (MVP)

Minimal dbt-like Cloudflare Worker using pnpm + Hono + Nunjucks.

## D1 Database Setup

1. Create a D1 database:

   wrangler d1 create mini-dbt-db

2. Note the `database_id` from the output and update `wrangler.toml`:

   ```toml
   [[d1_databases]]
   binding = "DB"
   database_name = "mini-dbt-db"
   database_id = "your-actual-database-id-here"
   ```

3. (Optional) Seed the database with initial schema:

   Create a migration file or run SQL directly via Wrangler to create tables like `raw_users_table`.

Quick start

1. Install deps

   pnpm install

2. Precompile templates

   pnpm run precompile-templates

3. Set up local database

   - Start dev server: `pnpm run dev` (runs on http://localhost:8788)
   - Seed the database: `pnpm exec wrangler d1 execute mini-dbt-db --local --command="INSERT OR IGNORE INTO raw_users_table (name, created_at) VALUES ('Alice','2023-01-01'),('Bob','2023-06-15');"`

4. Run dev

   pnpm run dev

API endpoints

- GET / — HTML home page
- GET /models — list available models (JSON or HTML based on Accept header)
- GET /models/:name/view — view NJK source for a model (HTML)
- GET /models/:name/compile — compile and preview SQL for a model (JSON or HTML)
- GET /models/:name/execute — execute the model and show results (HTML)
- GET /schedule — view cron schedule (HTML)
- POST /jobs/materialize — enqueue a materialization job (executes the model)
- Scheduled: Daily materialization of the default model (via cron trigger at midnight UTC)

Runtime configuration

- Set the default model via `wrangler.toml` or the Cloudflare dashboard using `DEFAULT_MODEL`.

Security notes

- Templates are Nunjucks files (`.sql.njk`) and should be precompiled during build for production.
- Do NOT accept untrusted user-supplied templates in production without sandboxing.

CI: This repository runs a GitHub Actions workflow that installs dependencies, runs `pnpm run precompile-templates`, and then runs `pnpm test` to ensure templates are precompiled before tests. (See `.github/workflows/ci.yml`)
