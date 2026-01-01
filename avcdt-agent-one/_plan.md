# Plans

## Todo App Plan

Goal: build a minimal client-side Todo app to demonstrate the AGENTS workflow.

Steps:
1. Spec: define a JSON Schema for a todo item and an example payload in `specs/`.
2. Implement: create a Vue component `src/components/TodoApp.vue` that stores todos in `localStorage`.
3. Test: **Tester** writes test suites and test configuration (Vitest) and ensures the tests cover add/toggle/remove/persistence; developers may add proposed unit tests but must request Tester review before merging.
4. Page: add `src/pages/todo.astro` to load the component with `client:load`.
5. QA: manually open `/todo` and verify create/toggle/remove persist. Use `_qa.md` to confirm all review items.
6. Commit: stage and commit changes with a concise message. QA may approve and merge once checklist is complete.

Acceptance criteria:
- Component allows adding, toggling, and removing todos.
- Todos persist in browser via `localStorage`.
- `specs/todo-schema.json` and example exist.

---

## Feedback widget plan (small feature)

Goal: small widget to upvote/downvote an item, show score, and persist to `localStorage`.

Steps:
1. Owner: add `specs/feedback-schema.json` and example `specs/examples/feedback-example.json`.
2. Architect: document in this `_plan.md` the task and acceptance criteria.
3. Developer: implement `src/components/FeedbackWidget.vue` and `src/pages/feedback.astro`.
4. Tester: add unit tests `src/components/FeedbackWidget.test.ts` to verify vote behavior and persistence.
5. QA: run the checklist in `_qa.md`, manually verify `/feedback`, and approve merge.

Acceptance criteria:
- User can upvote and downvote (score updates +/-1).
- Score persists in `localStorage` per item.
- Component has accessible buttons and visible score.
- Tests cover vote actions and persistence.

