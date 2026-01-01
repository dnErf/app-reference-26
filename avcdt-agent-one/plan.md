# Todo App Plan

Goal: build a minimal client-side Todo app to demonstrate the AGENTS workflow.

Steps:
1. Spec: define a JSON Schema for a todo item and an example payload in `specs/`.
2. Implement: create a Vue component `src/components/TodoApp.vue` that stores todos in `localStorage`.
5. Test: **Tester** writes test suites and test configuration (Vitest) and ensures the tests cover add/toggle/remove/persistence; developers may add proposed unit tests but must request Tester review before merging.
6. Page: add `src/pages/todo.astro` to load the component with `client:load`.
7. QA: manually open `/todo` and verify create/toggle/remove persist. Use `QA-CHECKLIST.md` to confirm all review items.
8. Commit: stage and commit changes with a concise message. QA may approve and merge once checklist is complete.

Acceptance criteria:
- Component allows adding, toggling, and removing todos.
- Todos persist in browser via `localStorage`.
- `specs/todo-schema.json` and example exist.
