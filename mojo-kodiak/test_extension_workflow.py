#!/usr/bin/env python3
"""
Test script to demonstrate the extension management workflow
This simulates the CLI commands that would be available once the binary is rebuilt
"""

import subprocess
import sys
import os

def run_command(cmd):
    """Run a command and return the result"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=os.path.dirname(__file__))
        return result.stdout, result.stderr, result.returncode
    except Exception as e:
        return "", str(e), 1

def test_extension_workflow():
    """Test the complete extension management workflow"""

    print("=== Mojo Kodiak Extension Management Test ===\n")

    # Test 1: List installed extensions
    print("1. Testing extension list command...")
    stdout, stderr, code = run_command("./kodiak extension list")
    if code == 0:
        print("✓ Extension list command works")
        print("Current extensions:")
        print(stdout)
    else:
        print("✗ Extension list command failed")
        print("Error:", stderr)

    # Test 2: Try to use SCM commands without SCM installed
    print("\n2. Testing SCM command gating (should fail)...")
    stdout, stderr, code = run_command("./kodiak scm status")
    if "not installed" in stderr.lower():
        print("✓ SCM commands properly gated when extension not installed")
    else:
        print("? SCM command result:", "SUCCESS" if code == 0 else "FAILED")
        if stderr:
            print("Error:", stderr)

    # Test 3: Install SCM extension
    print("\n3. Testing SCM extension installation...")
    stdout, stderr, code = run_command("./kodiak extension install scm")
    if code == 0 and "successfully" in stdout.lower():
        print("✓ SCM extension installed successfully")
    else:
        print("? SCM installation result:", "SUCCESS" if code == 0 else "FAILED")
        if stdout:
            print("Output:", stdout)
        if stderr:
            print("Error:", stderr)

    # Test 4: List extensions again to see SCM
    print("\n4. Testing extension list after SCM installation...")
    stdout, stderr, code = run_command("./kodiak extension list")
    if code == 0 and "scm" in stdout.lower():
        print("✓ SCM extension appears in installed list")
    else:
        print("? Extension list result:", "SUCCESS" if code == 0 else "FAILED")
        print("Output:", stdout)

    # Test 5: Try SCM commands now that it's installed
    print("\n5. Testing SCM commands after installation...")
    stdout, stderr, code = run_command("./kodiak scm status")
    if code == 0:
        print("✓ SCM commands work after extension installation")
    else:
        print("? SCM command result:", "SUCCESS" if code == 0 else "FAILED")
        if stderr:
            print("Error:", stderr)

    # Test 6: Try to install already installed extension
    print("\n6. Testing duplicate extension installation...")
    stdout, stderr, code = run_command("./kodiak extension install scm")
    if "already installed" in stdout.lower():
        print("✓ Duplicate installation properly rejected")
    else:
        print("? Duplicate installation result:", "SUCCESS" if code == 0 else "FAILED")

    # Test 7: Try to uninstall built-in extension
    print("\n7. Testing uninstallation of built-in extension...")
    stdout, stderr, code = run_command("./kodiak extension uninstall repl")
    if "cannot uninstall" in stdout.lower():
        print("✓ Built-in extension uninstallation properly rejected")
    else:
        print("? Built-in uninstall result:", "SUCCESS" if code == 0 else "FAILED")

    # Test 8: Uninstall SCM extension
    print("\n8. Testing SCM extension uninstallation...")
    stdout, stderr, code = run_command("./kodiak extension uninstall scm")
    if code == 0 and "successfully" in stdout.lower():
        print("✓ SCM extension uninstalled successfully")
    else:
        print("? SCM uninstall result:", "SUCCESS" if code == 0 else "FAILED")

    # Test 9: Verify SCM commands are gated again
    print("\n9. Testing SCM command gating after uninstallation...")
    stdout, stderr, code = run_command("./kodiak scm status")
    if "not installed" in stderr.lower():
        print("✓ SCM commands properly gated after extension uninstallation")
    else:
        print("? SCM command result:", "SUCCESS" if code == 0 else "FAILED")

    # Test 10: Test extension info command
    print("\n10. Testing extension info command...")
    stdout, stderr, code = run_command("./kodiak extension info scm")
    if code == 0:
        print("✓ Extension info command works")
        print("SCM Info:")
        print(stdout)
    else:
        print("? Extension info result:", "SUCCESS" if code == 0 else "FAILED")

    # Test 11: Test extension discover command
    print("\n11. Testing extension discover command...")
    stdout, stderr, code = run_command("./kodiak extension discover")
    if code == 0:
        print("✓ Extension discover command works")
        print("Available extensions:")
        print(stdout)
    else:
        print("? Extension discover result:", "SUCCESS" if code == 0 else "FAILED")

    print("\n=== Extension Management Test Complete ===")
    print("\nNote: This test uses the existing binary. Full functionality")
    print("requires rebuilding with the updated main.mojo that includes")
    print("the extension registry integration.")

if __name__ == "__main__":
    test_extension_workflow()