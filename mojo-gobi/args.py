import argparse

def parse_args():
    parser = argparse.ArgumentParser(description="Mojo CLI app for AI projects")
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Version command
    subparsers.add_parser('version', help='Show version')

    # Help command
    subparsers.add_parser('help', help='Show help')

    # Init command
    init_parser = subparsers.add_parser('init', help='Initialize AI project')
    init_parser.add_argument('name', help='Project name')
    init_parser.add_argument('--path', default='.', help='Path to create project')

    # Run command
    run_parser = subparsers.add_parser('run', help='Run the AI project')
    run_parser.add_argument('--path', default='.', help='Path to project')

    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate AI project')
    validate_parser.add_argument('path', default='.', help='Path to project')

    # Sync command
    sync_parser = subparsers.add_parser('sync', help='Sync dependencies for AI project')
    sync_parser.add_argument('--path', default='.', help='Path to project')
    sync_parser.add_argument('--lock', action='store_true', help='Generate pylock.toml file')

    # Build command
    build_parser = subparsers.add_parser('build', help='Build AI project')
    build_parser.add_argument('--path', default='.', help='Path to project')
    build_parser.add_argument('--platform', choices=['linux', 'mac', 'windows', 'all'], default='current', help='Target platform for build')

    # Add command
    add_parser = subparsers.add_parser('add', help='Add dependency to AI project')
    add_parser.add_argument('package', help='Package to add')
    add_parser.add_argument('--version', help='Version')
    add_parser.add_argument('--path', default='.', help='Path to project')
    add_parser.add_argument('--lock', action='store_true', help='Update pylock.toml file')

    # Remove command
    remove_parser = subparsers.add_parser('remove', help='Remove dependency from AI project')
    remove_parser.add_argument('package', help='Package to remove')
    remove_parser.add_argument('--path', default='.', help='Path to project')
    remove_parser.add_argument('--lock', action='store_true', help='Update pylock.toml file')

    # Test command
    test_parser = subparsers.add_parser('test', help='Run tests for AI project')
    test_parser.add_argument('--path', default='.', help='Path to project')

    # Deploy command
    deploy_parser = subparsers.add_parser('deploy', help='Deploy AI project')
    deploy_parser.add_argument('--path', default='.', help='Path to project')

    # Clean command
    clean_parser = subparsers.add_parser('clean', help='Clean build artifacts and temporary files')
    clean_parser.add_argument('--path', default='.', help='Path to project')

    # Update command
    update_parser = subparsers.add_parser('update', help='Update the Gobi CLI tool')
    update_parser.add_argument('--method', choices=['pip', 'git'], default='pip', help='Update method')

    # Plugin command
    plugin_parser = subparsers.add_parser('plugin', help='Run a custom plugin')
    plugin_parser.add_argument('name', help='Plugin name')
    plugin_parser.add_argument('args', nargs='*', help='Arguments for the plugin')
    plugin_parser.add_argument('--path', default='.', help='Path to project')

    # Env command
    env_parser = subparsers.add_parser('env', help='Manage environment for AI project')
    env_subparsers = env_parser.add_subparsers(dest='env_command', help='Environment subcommands')

    # env create
    create_parser = env_subparsers.add_parser('create', help='Create venv for AI project')
    create_parser.add_argument('--path', default='.', help='Path to project')

    # env activate
    activate_parser = env_subparsers.add_parser('activate', help='Activate venv for AI project')
    activate_parser.add_argument('--path', default='.', help='Path to project')

    # env install
    install_parser = env_subparsers.add_parser('install', help='Install package in venv')
    install_parser.add_argument('package', help='Package to install')
    install_parser.add_argument('--version', help='Version')
    install_parser.add_argument('--path', default='.', help='Path to project')

    # env list
    list_parser = env_subparsers.add_parser('list', help='List packages in venv')
    list_parser.add_argument('--path', default='.', help='Path to project')

    return parser.parse_args()