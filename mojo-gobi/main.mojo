from python import Python, PythonObject

fn main() raises:
    Python.add_to_path(".")
    var args_mod = Python.import_module("args")
    var interop_mod = Python.import_module("interop")
    var sys = Python.import_module("sys")
    
    print("Welcome to Mojo Gobi CLI")
    print("Type 'help' for commands, 'exit' to quit.")
    
    while True:
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
            interop_mod.print_panel("Help", "Available commands: version, help, init, run, validate, sync, build, add, remove, exit")
        elif command == 'init':
            interop_mod.create_project_structure(String(parsed_args.name), String(parsed_args.path))
        elif command == 'run':
            interop_mod.run_project(String(parsed_args.path))
        elif command == 'validate':
            interop_mod.validate_project(String(parsed_args.path))
        elif command == 'sync':
            interop_mod.sync_dependencies(String(parsed_args.path))
        elif command == 'build':
            interop_mod.build_project(String(parsed_args.path))
        elif command == 'add':
            interop_mod.add_dependency(String(parsed_args.package), String(parsed_args.version), String(parsed_args.path))
        elif command == 'remove':
            interop_mod.remove_dependency(String(parsed_args.package), String(parsed_args.path))
        else:
            print("Unknown command. Type 'help' for commands.")