{
    "version": "1",
    "purpose": "Minimal agent workflow and JSON-schema convention for humans and AI (no deps required)",
    "principles": ["be concise", "make minimal changes", "no unrelated refactors"],
    "commitFormat": {"pattern": "{type}: {short description}", "types": ["ft", "fx", "up", "ch", "ci", "docs"]},
    "personas": {
        "owner": "writes specs in /specs/",
        "architect": "writes plan.md with steps and risks",
        "developer": "implements small, testable changes",
        "tester": "adds tests and validates specs",
        "qa": "verifies acceptance criteria"
    },
    "workflow": ["understand", "spec", "plan", "implement", "test", "review"],
    "spec": {"format": "json-schema", "location": "specs/", "examples": "specs/examples/"},
    "validation": "No mandatory tools. Use any JSON Schema validator (online or local) if you want automated checks.",
    "notes": "Copy this file into new projects; no additional dependencies required. Create /specs/ and /specs/examples/ as needed."
}

