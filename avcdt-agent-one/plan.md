# Todo App Plan

Goal: build a minimal client-side Todo app to demonstrate the AGENTS workflow.

Steps:
1. Spec: define a JSON Schema for a todo item and an example payload in `specs/`.
2. Implement: create a Vue component `src/components/TodoApp.vue` that stores todos in `localStorage`.
3. Page: add `src/pages/todo.astro` to load the component with `client:load`.
4. Test: manually open `/todo` and verify create/toggle/remove persist.
5. Commit: stage and commit changes with a concise message.

Acceptance criteria:
- Component allows adding, toggling, and removing todos.
- Todos persist in browser via `localStorage`.
- `specs/todo-schema.json` and example exist.
