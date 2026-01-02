# CDT Implementation Plan

## Overview
Implement Cloudflare Data Transformer (CDT) library in hono-cloudflare-mustasho, inspired by dbt/SQLMesh. Focus on SQL templating, runner for D1, orchestrator for deployments, and CLI.

## Acceptance Criteria
- Library scaffolded with core components (template-engine, runner, orchestrator, cli)
- Example models in models/ rendered and executed locally (mock D1)
- CLI commands work: `cdt run`, `cdt plan`, `cdt test`
- README updated with usage
- Local test script demonstrates functionality
- ESM conversion complete
- Error handling, validation, enhanced templating added
- Performance basics (caching not yet, but validation)

## Tasks
- [x] Update package.json with dependencies (handlebars, minimist)
- [x] Implement lib/template-engine.js (Handlebars with dbt-like helpers)
- [x] Implement lib/runner.js (execute SQL on D1/mock)
- [x] Implement lib/orchestrator.js (plan/deploy logic)
- [x] Implement bin/cli.js (command interface)
- [x] Implement lib/index.js (exports)
- [x] Update models/ with templated SQL
- [x] Create test.js for local demo
- [x] Update README.md
- [x] Convert to ESM
- [x] Add error handling and validation
- [x] Enhance templating (source, config helpers)
- [x] Improve CLI (test command)
- [x] Update docs and examples

## Dependencies
- handlebars: ^4.7.8
- minimist: ^1.2.8
- wrangler: for local D1 simulation

## Notes
- Use pnpm for all installs/runs
- Mock D1 for local testing (no real DB needed initially)
- Follow AGENTS.md: conscious changes, pnpm, commit style