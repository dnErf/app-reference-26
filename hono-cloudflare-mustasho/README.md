# CDT - Cloudflare Data Transformer

A library for data transformations on Cloudflare, inspired by dbt and SQLMesh.

## Setup
- Install VS Code extension: "Handlebars" for syntax highlighting in .sql files.
- Workspace settings in `.vscode/settings.json` associate .sql with Handlebars.

## Docs
Run `pnpm run docs` to generate JSDoc documentation in `docs/` folder.

## Usage
- CLI: `cdt run --models=models/ --database=my_db`
- In Worker: `import { Runner } from 'cdt-cloudflare'; const runner = new Runner({ d1, r2 }); await runner.run('models/');`

## Features
- SQL templating with Handlebars (ref, var, source, config helpers)
- Runner for D1 executions with error handling
- Orchestrator for planning/deploying changes
- Backfill support and dependency validation
- CLI commands: run, plan, test

## Example Model
```sql
SELECT {{columns}}
FROM {{ref 'raw_users'}}
WHERE created_at > '{{var 'START_DATE'}}'
{{#if incremental}}
  AND updated_at > '{{var 'LAST_RUN'}}'
{{/if}}
```

## Hono Integration
See [integration guide](https://example.com) for Worker usage.

See AGENTS.md for workflow.