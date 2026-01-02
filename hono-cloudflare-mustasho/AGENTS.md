# AGENTS WORKFLOW GUIDELINES

## principles
- conscious and concise changes only
- no unrelated refactors
- use pnpm

## commits
- `type: description` (ft, fx, up, ch, ci, docs)

## roles
- **owner**
    - specs(`specs/`)
    - create and review checklist (`_qa.md`) and approval
- **developer**
    - plan (`_plan.md`)
    - implementation
    - ci

## workflow
1. understand - confirm acceptance criteria
2. spec - if medium+ complexity, add/update `specs/*.json`
3. plan - create/update `_plan.md`
4. implement - code
5. qa - run `_qa.md` and approve

## specs
- prefer JSON schema in `specs/`
