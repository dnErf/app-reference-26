"""
Mojo Kodiak DB - Main Entry Point

A high-performance database with in-memory and block storage layers.
"""

from database import Database
from extensions.repl import start_repl
from types import Row, Table
from python import Python
from extensions.repl import scm_init, scm_pack, scm_unpack, scm_add, scm_commit, scm_status, scm_diff, scm_install, scm_uninstall, scm_branch, scm_rollback, scm_validate, scm_test, scm_review, scm_snapshot
from extensions.workspace_manager import scm_workspace_create, scm_workspace_switch, scm_workspace_list, scm_workspace_info, scm_workspace_merge, scm_workspace_delete
from extensions.extension_registry import get_extension_registry, initialize_extension_registry
from sys import argv

# Extension management functions
fn extension_list() raises:
    """
    List installed extensions.
    """
    var registry = get_extension_registry()
    var installed = registry.list_installed_extensions()

    print("Installed extensions:")
    for name in installed:
        var info = registry.get_extension_info(name)
        print("  " + info)
        print("")  # Add blank line between extensions

fn extension_install(name: String) raises:
    """
    Install an extension.
    """
    var registry = get_extension_registry()

    if not registry.validate_extension_compatibility(name):
        print("Extension '" + name + "' is not compatible with the current system")
        return

    if registry.install_extension(name):
        # Save registry state
        registry.save_registry()
        print("Extension '" + name + "' installed successfully")
    else:
        print("Failed to install extension '" + name + "'")

fn extension_uninstall(name: String) raises:
    """
    Uninstall an extension.
    """
    var registry = get_extension_registry()
    
    if registry.uninstall_extension(name):
        # Save registry state
        registry.save_registry()
        print("Extension '" + name + "' uninstalled successfully")
    else:
        print("Failed to uninstall extension '" + name + "'")

fn extension_info(name: String) raises:
    """
    Show detailed information about an extension.
    """
    var registry = get_extension_registry()
    var info = registry.get_extension_info(name)
    print(info)

fn extension_discover() raises:
    """
    Show available extensions that can be installed.
    """
    var registry = get_extension_registry()
    var available = registry.discover_available_extensions()

    if len(available) == 0:
        print("No additional extensions available to install")
        return

    print("Available extensions to install:")
    for name in available:
        var info = registry.get_extension_info(name)
        print("  " + info)
        print("")  # Add blank line between extensions

fn show_help():
    print("Mojo Kodiak DB - A high-performance database")
    print("")
    print("Usage:")
    print("  kodiak                Show this help")
    print("  kodiak help           Show this help")
    print("  kodiak repl           Start interactive REPL")
    print("  kodiak health         Show database health status")
    print("  kodiak extension <command>  Extension management commands")
    print("  kodiak scm <command>  SCM commands (when extension installed)")
    print("")
    print("Extension Commands:")
    print("  kodiak extension list         List installed extensions")
    print("  kodiak extension info <name>  Show detailed extension information")
    print("  kodiak extension discover     Show available extensions to install")
    print("  kodiak extension install <name> Install extension")
    print("  kodiak extension uninstall <name> Uninstall extension")
    print("")
    print("SCM Commands (requires SCM extension):")
    print("  kodiak scm init       Initialize project structure")
    print("  kodiak scm pack [format] Pack project to {project_name}.kdk (format: feather/orc, default: feather)")
    print("  kodiak scm unpack     Unpack {project_name}.kdk to project folders")
    print("  kodiak scm add <files> Add files to staging")
    print("  kodiak scm commit <msg> Commit changes")
    print("  kodiak scm status     Show status")
    print("  kodiak scm diff       Show differences")
    print("  kodiak scm branch     Branch management commands")
    print("  kodiak scm rollback <version> Rollback to specific schema version")
    print("  kodiak scm validate <version> Validate schema compatibility")
    print("  kodiak scm test [version]    Test migrations and database integrity")
    print("  kodiak scm review           Collaborative change review commands")
    print("  kodiak scm audit            Audit trail and change history commands")
    print("  kodiak scm snapshot         Database snapshot and backup commands")
    print("  kodiak scm doc              Generate schema documentation")
    print("  kodiak scm structure         Validate project directory structure")
    print("  kodiak scm workspace <subcommand> Workspace management commands")
    print("  kodiak scm install <file> Install package")
    print("  kodiak scm uninstall <name> Uninstall package")
    print("")
    print("Workspace Commands:")
    print("  kodiak scm workspace create <name> [desc] [base] [env] Create workspace")
    print("  kodiak scm workspace switch <name>                  Switch to workspace")
    print("  kodiak scm workspace list                           List workspaces")
    print("  kodiak scm workspace info <name>                    Show workspace info")
    print("  kodiak scm workspace merge <source> [target]        Merge workspaces")
    print("  kodiak scm workspace delete <name>                  Delete workspace")
    print("")
    print("Examples:")
    print("  kodiak repl")
    print("  kodiak health")
    print("  kodiak extension list")
    print("  kodiak scm init")

fn validate_project_structure() raises:
    """
    Validate the project structure.
    """
    print("Project structure validation not implemented yet")

fn handle_workspace_command(args: List[String]) raises:
    """
    Handle workspace subcommands.
    """
    if len(args) == 0:
        print("Workspace commands require a subcommand")
        print("Use 'kodiak help' for usage")
        return

    var subcommand = args[0]
    if subcommand == "create" and len(args) >= 2:
        var name = args[1]
        var description = ""
        if len(args) > 2:
            description = args[2]
        var base_workspace = "main"
        if len(args) > 3:
            base_workspace = args[3]
        var environment = "dev"
        if len(args) > 4:
            environment = args[4]
        scm_workspace_create(name, description, base_workspace, environment)
    elif subcommand == "switch" and len(args) >= 2:
        scm_workspace_switch(args[1])
    elif subcommand == "list":
        scm_workspace_list()
    elif subcommand == "info" and len(args) >= 2:
        scm_workspace_info(args[1])
    elif subcommand == "merge" and len(args) >= 2:
        var source = args[1]
        var target = "main"
        if len(args) > 2:
            target = args[2]
        scm_workspace_merge(source, target)
    elif subcommand == "delete" and len(args) >= 2:
        scm_workspace_delete(args[1])
    else:
        print("Unknown workspace subcommand: " + subcommand)
        print("Use 'kodiak help' for usage")

fn main() raises:
    # Initialize extension registry
    initialize_extension_registry()

    var args = argv()
    
    if len(args) == 1:
        show_help()
    elif len(args) >= 2:
        var command = String(args[1])
        if command == "help":
            show_help()
        elif command == "repl":
            var db = Database()
            start_repl(db)
        elif command == "health":
            var db = Database()
            print(db.get_health())
        elif command == "extension":
            # Extension management commands
            if len(args) < 3:
                print("Extension commands require a subcommand")
                print("Use 'kodiak help' for usage")
                return
            var ext_cmd = String(args[2])
            if ext_cmd == "list":
                extension_list()
            elif ext_cmd == "info" and len(args) > 3:
                extension_info(String(args[3]))
            elif ext_cmd == "discover":
                extension_discover()
            elif ext_cmd == "install" and len(args) > 3:
                extension_install(String(args[3]))
            elif ext_cmd == "uninstall" and len(args) > 3:
                extension_uninstall(String(args[3]))
            else:
                print("Unknown extension command: " + ext_cmd)
                print("Use 'kodiak help' for usage")
        elif command == "scm":
            # SCM extension commands - check if extension is installed
            var registry = get_extension_registry()
            if not registry.is_extension_installed("scm"):
                print("SCM extension is not installed")
                print("Use 'kodiak extension install scm' to install it")
                return

            if len(args) < 3:
                print("SCM commands require a subcommand")
                print("Use 'kodiak help' for usage")
                return
            var scm_cmd = String(args[2])
            if scm_cmd == "init":
                scm_init()
            elif scm_cmd == "pack":
                if len(args) > 3:
                    scm_pack(String(args[3]))  # format parameter
                else:
                    scm_pack()  # default format
            elif scm_cmd == "unpack":
                scm_unpack()
            elif scm_cmd == "add" and len(args) > 3:
                scm_add(String(args[3]))
            elif scm_cmd == "commit" and len(args) > 3:
                var message_parts = List[String]()
                for i in range(3, len(args)):
                    message_parts.append(String(args[i]))
                var message = " ".join(message_parts)
                scm_commit(message)
            elif scm_cmd == "status":
                scm_status()
            elif scm_cmd == "diff":
                scm_diff()
            elif scm_cmd == "install" and len(args) > 3:
                scm_install(String(args[3]))
            elif scm_cmd == "uninstall" and len(args) > 3:
                scm_uninstall(String(args[3]))
            elif scm_cmd == "branch":
                var branch_args = List[String]()
                for i in range(3, len(args)):
                    branch_args.append(String(args[i]))
                scm_branch(branch_args)
            elif scm_cmd == "rollback" and len(args) > 3:
                scm_rollback(String(args[3]))
            elif scm_cmd == "validate" and len(args) > 3:
                scm_validate(String(args[3]))
            elif scm_cmd == "test":
                if len(args) > 3:
                    scm_test(String(args[3]))
                else:
                    scm_test()
            elif scm_cmd == "review":
                var review_args = List[String]()
                for i in range(3, len(args)):
                    review_args.append(String(args[i]))
                scm_review(review_args)
            elif scm_cmd == "audit":
                var audit_args = List[String]()
                for i in range(3, len(args)):
                    audit_args.append(String(args[i]))
                # scm_audit(audit_args)  # Commented out - function not implemented
                print("SCM audit not yet implemented")
            elif scm_cmd == "snapshot":
                var snapshot_args = List[String]()
                for i in range(3, len(args)):
                    snapshot_args.append(String(args[i]))
                scm_snapshot(snapshot_args)
            elif scm_cmd == "doc":
                var doc_args = List[String]()
                for i in range(3, len(args)):
                    doc_args.append(String(args[i]))
                # scm_doc(doc_args)  # Commented out - function not implemented
                print("SCM doc not yet implemented")
            elif scm_cmd == "structure":
                validate_project_structure()
            elif scm_cmd == "workspace":
                var workspace_args = List[String]()
                for i in range(3, len(args)):
                    workspace_args.append(String(args[i]))
                handle_workspace_command(workspace_args)
            else:
                print("Unknown SCM command: " + scm_cmd)
                print("Use 'kodiak help' for usage")
        else:
            print("Unknown command: " + command)
            print("")
            show_help()
    else:
        print("Too many arguments")
        print("")
        show_help()