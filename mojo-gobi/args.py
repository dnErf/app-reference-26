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

    return parser.parse_args()