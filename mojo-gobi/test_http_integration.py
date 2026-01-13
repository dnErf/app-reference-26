#!/usr/bin/env python3
"""
Test script for HTTP Integration with Secrets functionality
"""
import subprocess
import os
import tempfile

def run_pl_grizzly(commands):
    """Run PL-GRIZZLY with given commands and return output"""
    # Create a temporary database file
    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
        db_file = f.name

    try:
        # Build the command to run PL-GRIZZLY
        cmd = ['mojo', 'run', 'src/main.mojo', '--db', db_file]

        # Add commands as input
        process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd='/home/lnx/Dev/app-reference-26/mojo-gobi'
        )

        # Send commands to PL-GRIZZLY
        input_commands = '\n'.join(commands) + '\n.exit\n'
        stdout, stderr = process.communicate(input=input_commands, timeout=30)

        return stdout, stderr, process.returncode

    finally:
        # Clean up
        if os.path.exists(db_file):
            os.unlink(db_file)

def test_http_integration():
    """Test HTTP Integration with Secrets functionality"""
    print("Testing HTTP Integration with Secrets functionality...")

    # Commands to test
    commands = [
        "INSTALL httpfs;",
        "LOAD io, math, httpfs;",
        "TYPE SECRET AS github_token (kind: 'https', key: 'Authorization', value: 'Bearer ghp_test_token');",
        "SELECT * FROM 'https://api.github.com/user' WITH SECRET ['github_token'];",
        "SHOW SECRETS;"
    ]

    stdout, stderr, returncode = run_pl_grizzly(commands)

    print("STDOUT:")
    print(stdout)
    print("\nSTDERR:")
    print(stderr)
    print(f"\nReturn code: {returncode}")

    # Check for success indicators
    success = True
    if "error" in stdout.lower() or "error" in stderr.lower():
        print("❌ Test FAILED - Errors detected")
        success = False
    elif "installed successfully" in stdout.lower() or "loaded successfully" in stdout.lower():
        print("✅ Test PASSED - HTTP integration features working")
    else:
        print("⚠️  Test UNCLEAR - Check output manually")
        success = False

    return success

if __name__ == "__main__":
    test_http_integration()