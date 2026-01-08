from python import Python, PythonObject

fn main(argc: Int, argv: UnsafePointer[UnsafePointer[CChar]]) raises:
    try:
        Python.add_to_path(".")
        var sys = Python.import_module("sys")
        var args_list = List[String]()
        for i in range(argc):
            var arg = String(argv[i])
            args_list.append(arg)
        sys.argv = PythonObject(args_list)
        var args_mod = Python.import_module("args")
        var interop_mod = Python.import_module("interop")
        var parsed_args = args_mod.parse_args()
        print("parsed_args:", parsed_args)
        if str(parsed_args.command) == 'version':
            interop_mod.print_panel("Version", "Mojo Gobi CLI v0.1.0")
        elif str(parsed_args.command) == 'help':
            interop_mod.print_panel("Help", "Available commands: version, help, init")
        elif str(parsed_args.command) == 'init':
            interop_mod.create_project_structure(str(parsed_args.name), str(parsed_args.path))
        else:
            interop_mod.print_rich("[bold green]Hello AI CLI![/bold green]")
    except:
        var interop_mod = Python.import_module("interop")
        interop_mod.print_trace()