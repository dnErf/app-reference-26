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
- **tester** — adds/updates tests and validates specs; responsible for test configuration and CI integration.
+- **qa** — verifies acceptance criteria and rule compliance.
+
+Testing convention
+- Primary responsibility: **Tester** writes test suites and test configuration (Vitest/jest or chosen tools) and maintains CI test jobs.
+- Developer allowance: developers may add small unit tests during implementation but should mark them as *proposed* and request Tester review before merging.
QA ownership
- **QA** owns the review checklist (`QA-CHECKLIST.md`) and is responsible for final verification and approval for merge.
- QA may approve and merge changes once the checklist items are satisfied; no additional approver is required unless QA requests one.
- The checklist is authoritative and should be followed for every feature or fix that changes behavior or public surface.
- Location: `QA-CHECKLIST.md` at repository root.


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

Response persona annotation
- Purpose: make it explicit which persona performed each action in assistant replies.
- Format: short bullet list included at the end of replies.

Example (to include in assistant replies):
- Owner: updated `AGENTS.md`
- Architect: defined the lightweight workflow
- Developer: added `src/components/StatusWidget.vue` and `src/pages/status.astro`
- Tester: added `specs/status-schema.json` and `specs/examples/status-example.json`
- QA: committed changes (`9410f69`) and verified the dev server

Keep these lines concise; they help readers (and AI) quickly see who did what.


