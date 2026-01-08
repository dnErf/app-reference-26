#!/usr/bin/env python3

import sys
import os

# Change to the directory where this script is located
script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)

sys.path.append(".")

from args import parse_args
from interop import *

def main():
    parsed_args = parse_args()
    command = parsed_args.command
    if command == 'version':
        print_panel("Version", "Mojo Gobi CLI v0.1.0")
    elif command == 'help':
        print_panel("Help", "Available commands: version, help, init, run, validate, sync, build, add, remove, test, deploy, clean, update, plugin, exit")
    elif command == 'init':
        create_project_structure(parsed_args.name, parsed_args.path)
    elif command == 'run':
        run_project(parsed_args.path)
    elif command == 'validate':
        validate_project(parsed_args.path)
    elif command == 'sync':
        sync_dependencies(parsed_args.path)
    elif command == 'build':
        build_project(parsed_args.path)
    elif command == 'add':
        add_dependency(parsed_args.package, parsed_args.version or '', parsed_args.path)
    elif command == 'remove':
        remove_dependency(parsed_args.package, parsed_args.path)
    elif command == 'test':
        test_project(parsed_args.path)
    elif command == 'deploy':
        deploy_project(parsed_args.path)
    elif command == 'clean':
        clean_project(parsed_args.path)
    elif command == 'update':
        update_cli(parsed_args.method)
    elif command == 'plugin':
        run_plugin(parsed_args.name, parsed_args.args, parsed_args.path)
    else:
        print_rich("[bold green]Hello AI CLI![/bold green]")

if __name__ == "__main__":
    main()