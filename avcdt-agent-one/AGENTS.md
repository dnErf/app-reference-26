# AGENTS — Minimal agent workflow

Purpose
- A short, human- and AI-friendly process for small projects.

Principles
- Make small, focused changes; avoid unrelated refactors.

Commits
- Use: `type: short description` (types: `ft`, `fx`, `up`, `ch`, `ci`, `docs`).

Roles
- **owner:** specs (`specs/`)
- **architect:** plan (`_plan.md`)
- **developer:** implementation
- **tester:** tests & CI
- **qa:** review checklist (`_qa.md`) and approval

Workflow
1. Understand — confirm acceptance criteria
2. Spec — add/update `specs/*.json` and `specs/examples/`
3. Plan — update `_plan.md`
4. Implement — code (and optional proposed tests)
5. Test — tester writes and approves tests
6. QA — run `_qa.md` and approve

Specs
- Prefer JSON Schema in `specs/`; examples in `specs/examples/` (optional).

Validation
- No required tools; use any JSON Schema validator as needed.

Response persona annotation
- Add a short bullet in assistant replies listing involved personas (Owner, Architect, Developer, Tester, QA).

Keep it minimal; tell me which line to shorten or remove.


