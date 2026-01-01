# QA Review Checklist

This checklist is owned by **QA**. QA runs the checklist after Tester marks tests as approved and CI passes — no extra prompt required. If checklist items pass, QA may approve and merge the change.

Checklist (QA to run)
- [ ] Specs present and valid (`specs/<name>.json` and `specs/examples/`)
- [ ] `_plan.md` updated
- [ ] Implementation matches plan
- [ ] Tests are present and passing
- [ ] Tester confirmed tests (mark in PR) — tests approved
- [ ] Manual QA verification of core flows (browser)
- [ ] Accessibility/basic UX check
- [ ] Docs updated if needed

Notes:
- If any check fails or the change is risky for production, QA will request the necessary review from owner/architect.
- QA is empowered to approve and merge when the checklist is complete.

