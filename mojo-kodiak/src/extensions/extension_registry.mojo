"""
Extension Registry System for Mojo Kodiak

This module provides a comprehensive extension management system that tracks
installed extensions, their metadata, dependencies, and provides validation
and discovery capabilities.
"""

from collections import Dict, List
from python import Python

# Extension metadata structure
struct ExtensionMetadata(Copyable, Movable):
    var name: String
    var version: String
    var description: String
    var dependencies: List[String]
    var is_builtin: Bool
    var is_installed: Bool
    var commands: List[String]  # CLI commands provided by this extension

    fn __init__(out self, name: String, version: String, description: String, is_builtin: Bool = False):
        self.name = name
        self.version = version
        self.description = description
        self.dependencies = List[String]()
        self.is_builtin = is_builtin
        self.is_installed = is_builtin  # Built-in extensions are always installed
        self.commands = List[String]()

    fn add_dependency(mut self, dependency: String):
        """Add a dependency to this extension."""
        self.dependencies.append(dependency)

    fn add_command(mut self, command: String):
        """Add a CLI command provided by this extension."""
        self.commands.append(command)

    fn to_string(self) -> String:
        """Convert metadata to string representation."""
        var result = self.name + " v" + self.version
        if self.is_builtin:
            result += " (built-in)"
        else:
            result += " (installed: " + String(self.is_installed) + ")"

        result += "\n  Description: " + self.description

        if len(self.dependencies) > 0:
            result += "\n  Dependencies: "
            for i in range(len(self.dependencies)):
                if i > 0:
                    result += ", "
                result += self.dependencies[i]

        if len(self.commands) > 0:
            result += "\n  Commands: "
            for i in range(len(self.commands)):
                if i > 0:
                    result += ", "
                result += self.commands[i]

        return result

# Extension registry class
struct ExtensionRegistry:
    var extensions: Dict[String, ExtensionMetadata]  # name -> metadata
    var registry_file: String

    fn __init__(out self, registry_file: String = "extensions.json"):
        self.extensions = Dict[String, ExtensionMetadata]()
        self.registry_file = registry_file
        self._initialize_builtin_extensions()

    fn _initialize_builtin_extensions(mut self):
        """Initialize built-in extensions that are always available."""

        # Core database extensions
        var repl_ext = ExtensionMetadata("repl", "1.0.0", "Interactive REPL for database operations", True)
        repl_ext.add_command("repl")
        self.extensions["repl"] = repl_ext.copy()

        var query_parser_ext = ExtensionMetadata("query_parser", "1.0.0", "SQL query parsing and execution", True)
        query_parser_ext.add_command("query")
        self.extensions["query_parser"] = query_parser_ext.copy()

        var blob_store_ext = ExtensionMetadata("blob_store", "1.0.0", "BLOB storage with ULID generation", True)
        blob_store_ext.add_command("blob")
        self.extensions["blob_store"] = blob_store_ext.copy()

        var scm_ext = ExtensionMetadata("scm", "1.0.0", "Source Control Management for projects", True)
        scm_ext.add_command("scm")
        self.extensions["scm"] = scm_ext.copy()

        var test_ext = ExtensionMetadata("test", "1.0.0", "Database testing framework", True)
        test_ext.add_command("test")
        self.extensions["test"] = test_ext.copy()

    fn list_extensions(self) -> List[String]:
        """Get a list of all extension names."""
        var names = List[String]()
        for name in self.extensions.keys():
            names.append(name)
        return names

    fn list_installed_extensions(self) raises -> List[String]:
        """Get a list of installed extension names."""
        var names = List[String]()
        for name in self.extensions.keys():
            var ext = self.extensions[name].copy()
            if ext.is_installed:
                names.append(name)
        return names.copy()

    fn get_extension_info(self, name: String) raises -> String:
        """Get detailed information about an extension."""
        var ext_exists = False
        for ext_key in self.extensions.keys():
            if ext_key == name:
                ext_exists = True
                break
        if not ext_exists:
            return "Extension '" + name + "' not found"

        var ext = self.extensions[name].copy()
        return ext.to_string()

    fn is_extension_installed(self, name: String) raises -> Bool:
        """Check if an extension is installed."""
        var ext_exists = False
        for ext_key in self.extensions.keys():
            if ext_key == name:
                ext_exists = True
                break
        if not ext_exists:
            return False
        return self.extensions[name].copy().is_installed

    fn install_extension(mut self, name: String) raises -> Bool:
        """Install an extension and its dependencies."""
        var ext_exists = False
        for ext_key in self.extensions.keys():
            if ext_key == name:
                ext_exists = True
                break
        if not ext_exists:
            print("Extension '" + name + "' not found in registry")
            return False

        var ext = self.extensions[name].copy()

        if ext.is_installed:
            print("Extension '" + name + "' is already installed")
            return True

        # Check dependencies
        for dep in ext.dependencies:
            if not self.is_extension_installed(dep):
                print("Installing dependency: " + dep)
                if not self.install_extension(dep):
                    print("Failed to install dependency: " + dep)
                    return False

        # Install the extension
        ext.is_installed = True
        self.extensions[name] = ext.copy()

        print("Successfully installed extension: " + name)
        return True

    fn uninstall_extension(mut self, name: String) raises -> Bool:
        """Uninstall an extension."""
        var ext_exists = False
        for ext_key in self.extensions.keys():
            if ext_key == name:
                ext_exists = True
                break
        if not ext_exists:
            print("Extension '" + name + "' not found in registry")
            return False

        var ext = self.extensions[name].copy()

        if not ext.is_installed:
            print("Extension '" + name + "' is not installed")
            return True

        if ext.is_builtin:
            print("Cannot uninstall built-in extension: " + name)
            return False

        # Check if other extensions depend on this one
        var extension_names = List[String]()
        for other_name in self.extensions.keys():
            extension_names.append(other_name)
        for other_name in extension_names:
            var other_ext = self.extensions[other_name].copy()
            for dep in other_ext.dependencies:
                if dep == name and other_ext.is_installed:
                    print("Cannot uninstall '" + name + "': required by '" + other_name + "'")
                    return False

        # Uninstall the extension
        ext.is_installed = False
        self.extensions[name] = ext.copy()

        print("Successfully uninstalled extension: " + name)
        return True

    fn validate_extension_compatibility(self, name: String) raises -> Bool:
        """Validate that an extension is compatible with the current system."""
        var ext_exists = False
        for ext_key in self.extensions.keys():
            if ext_key == name:
                ext_exists = True
                break
        if not ext_exists:
            return False

        var ext = self.extensions[name].copy()

        # Check if all dependencies are available
        for dep in ext.dependencies:
            var dep_exists = False
            for dep_key in self.extensions.keys():
                if dep_key == dep:
                    dep_exists = True
                    break
            if not dep_exists:
                print("Missing dependency: " + dep)
                return False

        # Additional compatibility checks could be added here
        # For example: version compatibility, platform checks, etc.

        return True

    fn discover_available_extensions(self) raises -> List[String]:
        """Discover extensions that could be installed."""
        var available = List[String]()
        for name in self.extensions.keys():
            var ext = self.extensions[name].copy()
            if not ext.is_builtin and not ext.is_installed:
                available.append(name)
        return available.copy()

    fn get_extension_commands(self, name: String) -> List[String]:
        """Get the CLI commands provided by an extension."""
        var ext_exists = False
        for ext_key in self.extensions.keys():
            if ext_key == name:
                ext_exists = True
                break
        if not ext_exists:
            return List[String]()

        var ext = self.extensions[name]
        if not ext.is_installed:
            return List[String]()

        return ext.commands

    fn save_registry(self) raises:
        """Save the extension registry to disk."""
        try:
            var py = Python.import_module("json")

            # Convert registry to Python dict
            var registry_dict = py.dict()
            for name in self.extensions.keys():
                var ext = self.extensions[name].copy()
                var ext_dict = py.dict()
                ext_dict["name"] = ext.name
                ext_dict["version"] = ext.version
                ext_dict["description"] = ext.description
                ext_dict["is_builtin"] = ext.is_builtin
                ext_dict["is_installed"] = ext.is_installed

                var deps_list = py.list()
                for dep in ext.dependencies:
                    deps_list.append(dep)
                ext_dict["dependencies"] = deps_list

                var cmds_list = py.list()
                for cmd in ext.commands:
                    cmds_list.append(cmd)
                ext_dict["commands"] = cmds_list

                registry_dict[name] = ext_dict

            # Write to file using Python's open
            var py_open = Python.import_module("builtins").open
            var f = py_open(self.registry_file, "w")
            py.json.dump(registry_dict, f, indent=2)
            f.close()

        except:
            print("Warning: Could not save extension registry to disk")

    fn load_registry(mut self) raises:
        """Load the extension registry from disk."""
        try:
            var py = Python.import_module("json")

            # Read from file using Python's open
            var py_open = Python.import_module("builtins").open
            var f = py_open(self.registry_file, "r")
            var registry_dict = py.json.load(f)
            f.close()

            # Clear current registry and reload
            self.extensions = Dict[String, ExtensionMetadata]()

            for name in registry_dict.keys():
                var ext_dict = registry_dict[name]
                var ext = ExtensionMetadata(
                    String(ext_dict["name"]),
                    String(ext_dict["version"]),
                    String(ext_dict["description"]),
                    Bool(ext_dict["is_builtin"])
                )
                ext.is_installed = Bool(ext_dict["is_installed"])

                var deps = ext_dict["dependencies"]
                for dep in deps:
                    ext.add_dependency(String(dep))

                var cmds = ext_dict["commands"]
                for cmd in cmds:
                    ext.add_command(String(cmd))

                self.extensions[String(name)] = ext.copy()

        except:
            # If loading fails, reinitialize with defaults
            self._initialize_builtin_extensions()

# Extension registry - create on demand
fn get_extension_registry() -> ExtensionRegistry:
    """Get an extension registry instance."""
    return ExtensionRegistry()

fn initialize_extension_registry():
    """Initialize the global extension registry."""
    _global_registry = ExtensionRegistry()
    try:
        _global_registry.load_registry()
    except:
        # If loading fails, use defaults
        pass