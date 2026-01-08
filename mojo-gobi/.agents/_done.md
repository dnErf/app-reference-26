- Create main.mojo with basic fn main() structure.
- Create pyproject.toml for project metadata, dependencies (Rich), and Mojo build config.
- Set up Python interop module: create interop.py with Rich imports and basic console setup.
### Feature 1: Mojo CLI Core with Python Interop (Essential Foundation - Max Quality/Perf Boost)
- Implement basic arg parsing: create args.py using Python's argparse, callable from Mojo.
- Set up Python interop module: create interop.py with Rich imports and basic console setup.
- Implement basic arg parsing: create args.py using Python's argparse, callable from Mojo.
- Build "version" command: add version subcommand in main.mojo calling Rich panel output.
- Add global error handling: wrap main in try-except with Rich trace printing.

### Feature 2: AI Project Init Engine (Value-Add - Stricter AI Enforcement)
- Define AI template schema: create template.json with dir structure (ai_models/, data/, scripts/) and naming rules.
- Code "init" subcommand: add init parser in args.py, logic in main.mojo to create dirs/files.
- Enforce AI constraints: add validation in init logic (e.g., require .mojo file, check naming).
- Validate created structure: implement schema check function flagging non-compliant elements.
- Enhance with Rich UI: add progress spinner, tree display, red warnings in init output.
- Unit test init: create test_init.mojo with mock AI project creation and assertions.

### Feature 3: Agent Beacon for AI Projects (Agent-Aware - Prevents Out-of-Bounds)
- Add .ai beacon file to template.json with metadata (ai_project flag, structure_version, agent_hooks, folders list).
- Implement beacon creation in init logic: generate .ai with JSON metadata signaling AI presence and bounds.
- Add agent hook: include scripts/ping_agent.py that agents can run for validation/notification.
- Enhance validation: check .ai on init, warn if structure deviates from beacon.
- Test beacon: create project, verify .ai signals correctly, agents stay in bounds.