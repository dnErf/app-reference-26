# AGENTS — Minimal agent workflow

Purpose
- A small, human-friendly workflow that is also easy for AI to follow. Copy into new projects as-is.

Principles
- Be concise.
- Make minimal, focused changes.
- Avoid unrelated refactors.

Commit messages
- Format: `type: short description` (types: `ft`, `fx`, `up`, `ch`, `ci`, `docs`).

Personas
- **owner** — writes concise specs in `/specs/`.
- **architect** — writes `plan.md` (steps, risks).
- **developer** — implements small, testable changes.
- **tester** — adds/updates tests and validates specs.
- **qa** — verifies acceptance criteria and rule compliance.

Workflow (6 steps)
1. Understand — clarify requirements and acceptance criteria.
2. Spec — add/update `specs/<name>.json` (JSON Schema) and examples in `specs/examples/`.
3. Plan — add/update `plan.md` with numbered implementation steps.
4. Implement — write minimal code and tests.
5. Test — run tests and validate example payloads against the spec (manually or with any validator).
6. Review — ensure rules and acceptance criteria are met.

Spec convention
- Use JSON Schema for specs: place files in `specs/`.
- Put example payloads in `specs/examples/` with matching names.
- Schemas are optional; start with an example JSON if you prefer.

Validation (no required tools)
- No additional packages are required by this workflow.
- To validate, paste the schema and example into any online JSON Schema validator or run a local validator you already use.

Notes
- This file is intentionally dependency-free and portable. I can scaffold `specs/` and examples for any new project on request.


