# AGENTS WORKFLOW GUIDELINES

## principles
- conscious and concise changes only
- no unrelated refactors

## commits
- `type: description` (ft, fx, up, ch, ci, docs)

## roles
- **owner**
    - specs(`specs/`)
    - create and review checklist (`_qa.md`) and approval
- **developer**
    - plan (`_plan.md`)
    - implementation
    - tests
    - ci

## workflow
1. understand - confirm acceptance criteria
2. spec - if medium+ complexity, add/update `specs/*.json`
3. plan - create/update `_plan.md`
4. implement - code
5. test - test implementation
6. qa - run `_qa.md` and approve

## specs
- prefer JSON schema in `specs/`

## Agent Defaults
- **Default model for all clients:** `raptor-mini-preview` (override via `DEFAULT_MODEL` Cloudflare binding or environment variable)
- **D1 Database:** Configured via `wrangler.toml` with binding `DB`
- **Variables:** Key-value pairs for template variables via `VARIABLES` binding or environment (JSON string)
