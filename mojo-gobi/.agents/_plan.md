Feature 1: Mojo CLI Core with Python Interop (Essential - Enables Rich & Args)
Create main.mojo with fn main() raises, import Python module.
Set up Rich console via Python.import_module("rich.console"), handle exceptions.
Implement arg parsing using Python.import_module("argparse") for CLI subcommands.
Add "help" command with Rich Panel output (e.g., styled text, borders).
Test interop: print Rich-colored "Hello AI CLI" on run.

Feature 2: AI-Strict Init Command (Value-Add - Enforces AI Rules)
Define AI project schema (dict of required dirs/files, e.g., {"ai_models/": ".mojo", "data/": ".json"}).
Code "init" subcommand: parse name/path args, create dirs/files via os (Mojo stdlib), validate against schema.
Integrate Rich progress: use Rich Spinner during creation, Tree for output display.
Add AI checks: warn if no .mojo files, enforce naming (e.g., no spaces).
Mock test: init sample project, verify structure with Rich success/error messages.

Feature 3: Agent Beacon for AI Projects (Agent-Aware - Prevents Out-of-Bounds)
Add .ai beacon file to template.json with metadata (ai_project flag, structure_version, agent_hooks, folders list).
Implement beacon creation in init logic: generate .ai with JSON metadata signaling AI presence and bounds.
Add agent hook: include scripts/ping_agent.py that agents can run for validation/notification.
Enhance validation: check .ai on init, warn if structure deviates from beacon.
Test beacon: create project, verify .ai signals correctly, agents stay in bounds.