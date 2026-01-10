"""
Unit tests for extension registry operations.
"""

from extensions.extension_registry import ExtensionRegistry, ExtensionMetadata

fn test_extension_metadata() raises -> Bool:
    """Test ExtensionMetadata struct operations."""
    print("Testing extension metadata...")

    var metadata = ExtensionMetadata(
        name="test_ext",
        version="1.0.0",
        description="Test extension",
        is_builtin=False
    )

    # Add dependencies and commands
    metadata.add_dependency("core")
    metadata.add_dependency("storage")
    metadata.add_command("test_cmd")

    # Check fields
    if metadata.name != "test_ext":
        print("ERROR: Name field incorrect")
        return False

    if metadata.version != "1.0.0":
        print("ERROR: Version field incorrect")
        return False

    if metadata.description != "Test extension":
        print("ERROR: Description field incorrect")
        return False

    if len(metadata.dependencies) != 2:
        print("ERROR: Dependencies count incorrect")
        return False

    if len(metadata.commands) != 1:
        print("ERROR: Commands count incorrect")
        return False

    if metadata.is_builtin:
        print("ERROR: is_builtin should be False")
        return False

    if not metadata.is_installed:
        print("ERROR: is_installed should be True for non-builtin by default")
        return False

    print("✓ Extension metadata test passed")
    return True

fn test_builtin_extensions_registration() raises -> Bool:
    """Test that built-in extensions are properly registered."""
    print("Testing built-in extensions registration...")

    var registry = ExtensionRegistry()

    # Check that built-in extensions are registered
    var builtin_extensions = List[String](
        "repl", "query_parser", "block_store", "blob_store",
        "wal", "fractal_tree", "b_plus_tree", "test", "benchmark"
    )

    for ext_name in builtin_extensions:
        if not registry.is_extension_installed(ext_name):
            print("ERROR: Built-in extension '" + ext_name + "' not installed")
            return False

        var metadata = registry.extensions[ext_name]
        if not metadata.is_builtin:
            print("ERROR: Extension '" + ext_name + "' should be marked as builtin")
            return False

    print("✓ Built-in extensions registration test passed")
    return True

fn test_extension_installation() raises -> Bool:
    """Test extension installation and uninstallation."""
    print("Testing extension installation...")

    var registry = ExtensionRegistry()

    # Test installing SCM extension
    if not registry.install_extension("scm"):
        print("ERROR: Failed to install SCM extension")
        return False

    if not registry.is_extension_installed("scm"):
        print("ERROR: SCM extension should be installed")
        return False

    # Test that we can't install it again
    if registry.install_extension("scm"):
        print("ERROR: Should not be able to install already installed extension")
        return False

    # Test uninstalling SCM extension
    if not registry.uninstall_extension("scm"):
        print("ERROR: Failed to uninstall SCM extension")
        return False

    if registry.is_extension_installed("scm"):
        print("ERROR: SCM extension should not be installed")
        return False

    # Test that we can't uninstall built-in extensions
    if registry.uninstall_extension("repl"):
        print("ERROR: Should not be able to uninstall built-in extension")
        return False

    print("✓ Extension installation test passed")
    return True

fn test_extension_discovery() raises -> Bool:
    """Test extension discovery functionality."""
    print("Testing extension discovery...")

    var registry = ExtensionRegistry()

    # Initially, SCM should be available to install
    var available = registry.discover_available_extensions()
    var found_scm = False
    for ext in available:
        if ext == "scm":
            found_scm = True
            break

    if not found_scm:
        print("ERROR: SCM should be available for installation")
        return False

    # After installing SCM, it should not be in available list
    registry.install_extension("scm")
    available = registry.discover_available_extensions()
    found_scm = False
    for ext in available:
        if ext == "scm":
            found_scm = True
            break

    if found_scm:
        print("ERROR: SCM should not be available after installation")
        return False

    print("✓ Extension discovery test passed")
    return True

fn test_extension_validation() raises -> Bool:
    """Test extension validation functionality."""
    print("Testing extension validation...")

    var registry = ExtensionRegistry()

    # Test valid extension
    if not registry.validate_extension_compatibility("scm"):
        print("ERROR: SCM should be valid")
        return False

    # Test invalid extension
    if registry.validate_extension_compatibility("nonexistent"):
        print("ERROR: Nonexistent extension should not be valid")
        return False

    print("✓ Extension validation test passed")
    return True

fn test_extension_commands() raises -> Bool:
    """Test extension command tracking."""
    print("Testing extension commands...")

    var registry = ExtensionRegistry()

    # Test SCM commands
    var scm_commands = registry.get_extension_commands("scm")
    if len(scm_commands) == 0:
        print("ERROR: SCM should have commands")
        return False

    var found_scm_cmd = False
    for cmd in scm_commands:
        if cmd == "scm":
            found_scm_cmd = True
            break

    if not found_scm_cmd:
        print("ERROR: SCM should provide 'scm' command")
        return False

    # Test uninstalled extension commands
    registry.uninstall_extension("scm")
    scm_commands = registry.get_extension_commands("scm")
    if len(scm_commands) != 0:
        print("ERROR: Uninstalled extension should not provide commands")
        return False

    print("✓ Extension commands test passed")
    return True

fn test_registry_persistence() raises -> Bool:
    """Test extension registry persistence."""
    print("Testing registry persistence...")

    var registry1 = ExtensionRegistry("test_registry.json")

    # Install an extension
    registry1.install_extension("scm")

    # Save registry
    registry1.save_registry()

    # Create new registry and load
    var registry2 = ExtensionRegistry("test_registry.json")
    try:
        registry2.load_registry()
    except:
        print("ERROR: Failed to load registry")
        return False

    # Check that SCM is still installed
    if not registry2.is_extension_installed("scm"):
        print("ERROR: SCM should still be installed after loading")
        return False

    # Clean up
    try:
        import os
        os.remove("test_registry.json")
    except:
        pass  # Ignore cleanup errors

    print("✓ Registry persistence test passed")
    return True

fn test_extension_registry() raises -> Bool:
    """Run all extension registry tests."""
    if not test_extension_metadata():
        return False
    if not test_builtin_extensions_registration():
        return False
    if not test_extension_installation():
        return False
    if not test_extension_discovery():
        return False
    if not test_extension_validation():
        return False
    if not test_extension_commands():
        return False
    if not test_registry_persistence():
        return False

    print("🎉 All extension registry tests passed!")
    return True