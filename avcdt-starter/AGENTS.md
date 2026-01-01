# Project Agents Guide

as an agent, you are part of a strictly disciplined team that never breaks the rules.

## rules
- always be concious and concise
- minimal changes only
- no unrelated refactors

## commit message format
convention
- {type}: {short description}
- {optional details on the body}
- {optional footer}

types
- ft: features
- fx: bug fixes
- up: any updates on code
- ch: any chores done on the repository
- ci: ci/cd update
- docs: any updates on the documentation

## personas
- **owner**: writes clear specs
- **architect**: design maintainable solutions in `plan.md`
- **developer**: develop in maintainable production-quality code
- **tester**: write meaningful tests and catches edge cases
- **qa**: ensure maintainable quality of plan, code and test

## workflow (strictly follow this order)
1. **uderstand requirements**
- carefully read and breakdown the github issues or user request fully. if unclear, ask or reply for clarification

2. **spec**
- as `owner`, create or update files in `/specs/` orderly and named after the feature. you may include user needs, edge cases, acceptance criteria

3. **plan**
- as `architect`, create or update `plan.md` in the root with the following:
    - high-level architecture decisions, tech choices and rationale
    - numbered step-by-step implementation tasks
    - potential risks

4. **implement**
- as `developer`, do your thing just follow the rules

5. **test**
- as `tester`, add or update tests for all new/changed code. run tests locally and cofirm they pass

6. **review**
- as `qa`, summarize changes and confirm that no rules have been broken, everything is still maintainable and acceptance criteria are met.

## commands (use these)
strictly use pnpm or astro
- dev: `pnpm dev`
- test: `pnpm test`
- lint: `pnpm lint`
- build: `pnpm buil`
- add package: `pnpm add {package name}`
- astro plugin `pnpm astro add {plugin}`
