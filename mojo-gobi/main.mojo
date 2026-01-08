from python import Python, PythonObject
from os import getenv

fn main() raises:
    print("Main.mojo starting...")
    Python.add_to_path(".")
    var args_mod = Python.import_module("args")
    var interop_mod = Python.import_module("interop")
    var sys = Python.import_module("sys")

    # Check for command-line arguments passed via environment variable (legacy shell script mode)
    var cmd_args = getenv("GOBI_ARGS")
    if cmd_args != "":
        # Command-line mode: set sys.argv from environment
        var args_list = cmd_args.split()
        var argv_list = Python.evaluate("[]")
        argv_list.append("gobi")
        for arg in args_list:
            argv_list.append(arg)
        sys.__setattr__("argv", argv_list)
        
        try:
            var parsed_args = args_mod.parse_args()
            var command = String(parsed_args.command)
            
            if command == 'version':
                interop_mod.print_panel("Version", "Mojo Gobi CLI v0.1.0")
            elif command == 'help':
                interop_mod.print_panel("Help", "Available commands: version, help, init, run, validate, sync, build, add, remove, test, deploy, clean, update, plugin, env")
            elif command == 'init':
                interop_mod.create_project_structure(String(parsed_args.name), String(parsed_args.path))
            elif command == 'run':
                interop_mod.run_project(String(parsed_args.path))
            elif command == 'validate':
                interop_mod.validate_project(String(parsed_args.path))
            elif command == 'sync':
                interop_mod.sync_dependencies(String(parsed_args.path), Bool(parsed_args.lock))
            elif command == 'build':
                interop_mod.build_project(String(parsed_args.path))
            elif command == 'add':
                interop_mod.add_dependency(String(parsed_args.package), String(parsed_args.version or ''), String(parsed_args.path), Bool(parsed_args.lock))
            elif command == 'remove':
                interop_mod.remove_dependency(String(parsed_args.package), String(parsed_args.path), Bool(parsed_args.lock))
            elif command == 'test':
                interop_mod.test_project(String(parsed_args.path))
            elif command == 'deploy':
                interop_mod.deploy_project(String(parsed_args.path))
            elif command == 'clean':
                interop_mod.clean_project(String(parsed_args.path))
            elif command == 'update':
                interop_mod.update_cli(String(parsed_args.method))
            elif command == 'plugin':
                interop_mod.run_plugin(String(parsed_args.name), parsed_args.args, String(parsed_args.path))
            elif command == 'env':
                if String(parsed_args.env_command) == 'create':
                    interop_mod.env_create(String(parsed_args.path))
                elif String(parsed_args.env_command) == 'activate':
                    interop_mod.env_activate(String(parsed_args.path))
                elif String(parsed_args.env_command) == 'install':
                    interop_mod.env_install(String(parsed_args.package), String(parsed_args.version or ''), String(parsed_args.path))
                elif String(parsed_args.env_command) == 'list':
                    interop_mod.env_list(String(parsed_args.path))
                else:
                    interop_mod.print_error("Unknown env subcommand.")
            else:
                interop_mod.print_error("Unknown command. Use 'gobi help' for available commands.")
            return
        except e:
            interop_mod.print_error("Command parsing error: " + String(e))
            return

    # Check for direct command line arguments (new binary mode)
    var argv = sys.argv
    if len(argv) > 1:
        # Direct command-line mode: use sys.argv as-is
        try:
            var parsed_args = args_mod.parse_args()
            var command = String(parsed_args.command)
            
            if command == 'version':
                interop_mod.print_panel("Version", "Mojo Gobi CLI v0.1.0")
            elif command == 'help':
                interop_mod.print_panel("Help", "Available commands: version, help, init, run, validate, sync, build, add, remove, test, deploy, clean, update, plugin, env")
            elif command == 'init':
                interop_mod.create_project_structure(String(parsed_args.name), String(parsed_args.path))
            elif command == 'run':
                interop_mod.run_project(String(parsed_args.path))
            elif command == 'validate':
                interop_mod.validate_project(String(parsed_args.path))
            elif command == 'sync':
                interop_mod.sync_dependencies(String(parsed_args.path), Bool(parsed_args.lock))
            elif command == 'build':
                interop_mod.build_project(String(parsed_args.path))
            elif command == 'add':
                interop_mod.add_dependency(String(parsed_args.package), String(parsed_args.version or ''), String(parsed_args.path), Bool(parsed_args.lock))
            elif command == 'remove':
                interop_mod.remove_dependency(String(parsed_args.package), String(parsed_args.path), Bool(parsed_args.lock))
            elif command == 'test':
                interop_mod.test_project(String(parsed_args.path))
            elif command == 'deploy':
                interop_mod.deploy_project(String(parsed_args.path))
            elif command == 'clean':
                interop_mod.clean_project(String(parsed_args.path))
            elif command == 'update':
                interop_mod.update_cli(String(parsed_args.method))
            elif command == 'plugin':
                interop_mod.run_plugin(String(parsed_args.name), parsed_args.args, String(parsed_args.path))
            elif command == 'env':
                if String(parsed_args.env_command) == 'create':
                    interop_mod.env_create(String(parsed_args.path))
                elif String(parsed_args.env_command) == 'activate':
                    interop_mod.env_activate(String(parsed_args.path))
                elif String(parsed_args.env_command) == 'install':
                    interop_mod.env_install(String(parsed_args.package), String(parsed_args.version or ''), String(parsed_args.path))
                elif String(parsed_args.env_command) == 'list':
                    interop_mod.env_list(String(parsed_args.path))
                else:
                    interop_mod.print_error("Unknown env subcommand.")
            else:
                interop_mod.print_error("Unknown command. Use 'gobi help' for available commands.")
            return
        except e:
            interop_mod.print_error("Command parsing error: " + String(e))
            return

    # Interactive mode
    
    while True:
        try:
            var line = String(Python.evaluate("input('gobi> ')"))
            if line == "exit":
                break
            if len(line) == 0:
                continue
            # Set sys.argv from the line
            var argv_list = Python.evaluate("['gobi'] + " + repr(line.split()))
            sys.__setattr__("argv", argv_list)
            
            var parsed_args = args_mod.parse_args()
            
            var command = String(parsed_args.command)
            if command == 'version':
                interop_mod.print_panel("Version", "Mojo Gobi CLI v0.1.0")
            elif command == 'help':
                interop_mod.print_panel("Help", "Available commands: version, help, init, run, validate, sync, build, add, remove, test, deploy, clean, update, plugin, env, exit")
            elif command == 'init':
                interop_mod.create_project_structure(String(parsed_args.name), String(parsed_args.path))
            elif command == 'run':
                interop_mod.run_project(String(parsed_args.path))
            elif command == 'validate':
                interop_mod.validate_project(String(parsed_args.path))
            elif command == 'sync':
                interop_mod.sync_dependencies(String(parsed_args.path), False)
            elif command == 'build':
                interop_mod.build_project(String(parsed_args.path))
            elif command == 'add':
                interop_mod.add_dependency(String(parsed_args.package), String(parsed_args.version), String(parsed_args.path), False)
            elif command == 'remove':
                interop_mod.remove_dependency(String(parsed_args.package), String(parsed_args.path), False)
            elif command == 'test':
                interop_mod.test_project(String(parsed_args.path))
            elif command == 'deploy':
                interop_mod.deploy_project(String(parsed_args.path))
            elif command == 'clean':
                interop_mod.clean_project(String(parsed_args.path))
            elif command == 'update':
                interop_mod.update_cli(String(parsed_args.method))
            elif command == 'plugin':
                interop_mod.run_plugin(String(parsed_args.name), parsed_args.args, String(parsed_args.path))
            elif command == 'env':
                if String(parsed_args.env_command) == 'create':
                    interop_mod.env_create(String(parsed_args.path))
                elif String(parsed_args.env_command) == 'activate':
                    interop_mod.env_activate(String(parsed_args.path))
                elif String(parsed_args.env_command) == 'install':
                    interop_mod.env_install(String(parsed_args.package), String(parsed_args.version or ''), String(parsed_args.path))
                elif String(parsed_args.env_command) == 'list':
                    interop_mod.env_list(String(parsed_args.path))
                else:
                    print("Unknown env subcommand.")
            else:
                print("Unknown command. Type 'help' for commands.")
        except e:
            interop_mod.print_error("Command error: " + String(e))