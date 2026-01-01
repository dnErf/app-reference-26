# AGENTS — Minimal agent workflow

Purpose
- A short, human- and AI-friendly process for new projects.

Principles
- Be concise; make minimal, focused changes; avoid unrelated refactors.

Commit messages
- Format: `type: short description` (types: `ft`, `fx`, `up`, `ch`, `ci`, `docs`).

Personas
- owner — writes specs in `specs/`
- architect — writes `_plan.md` (steps, risks)
- developer — implements small, testable changes
- tester — owns tests and test config; maintains CI checks
- qa — owns review checklist `_qa.md` and final approval

Workflow
1. Understand — clarify requirements and acceptance criteria
2. Spec — add/update `specs/*.json` and examples in `specs/examples/`
3. Plan — update `_plan.md`
4. Implement — code and (optionally) proposed tests
5. Test — tester writes/approves tests and runs them
6. Review — QA verifies checklist in `_qa.md` and approves

Spec convention
- Use JSON Schema in `specs/`; examples in `specs/examples/`. Schemas are optional.

Validation
- No mandatory tools. Use any JSON Schema validator (online or local) as needed.

Response persona annotation
- Include a short bullet list in assistant replies showing which persona did what (Owner, Architect, Developer, Tester, QA).

Keep it minimal and readable; let me know if you want any line made even shorter or removed.


