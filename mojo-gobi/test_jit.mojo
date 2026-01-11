# Test JIT compilation
from main import start_repl
import sys

# Mock rich console for testing
var rich = Python.import_module("rich.console")
var console = rich.Console()

# Test commands
var commands = [
    "enable profiling",
    "interpret CREATE FUNCTION add(x, y) => x + y",
    "interpret add(1, 2)",
    "interpret add(3, 4)",
    "interpret add(5, 6)",
    "interpret add(7, 8)",
    "interpret add(9, 10)",
    "interpret add(11, 12)",
    "interpret add(13, 14)",
    "interpret add(15, 16)",
    "interpret add(17, 18)",  # This should trigger JIT
    "jit status",
    "show profile",
    "quit"
]

print("Testing JIT compilation...")
for cmd in commands:
    print("Command:", cmd)
    # We can't easily simulate the REPL input, so let's just test the interpreter directly
