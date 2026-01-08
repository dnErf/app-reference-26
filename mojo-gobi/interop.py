from rich.console import Console
from rich.panel import Panel
from rich.spinner import Spinner
from rich.tree import Tree
from rich import print as rprint
import traceback
import json
import os
import re

console = Console()

def print_rich(text):
    console.print(text)

def print_panel(title, content):
    console.print(Panel(content, title=title))

def print_error(message):
    rprint(f"[red]{message}[/red]")

def print_trace():
    tb = traceback.format_exc()
    print_panel("Error Trace", tb)

def load_template():
    with open('template.json', 'r') as f:
        return json.load(f)

def validate_project_name(name):
    pattern = r'^[a-zA-Z][a-zA-Z0-9_-]*$'
    return bool(re.match(pattern, name))

def create_project_structure(name, path):
    template = load_template()
    project_path = os.path.join(path, name)
    os.makedirs(project_path, exist_ok=True)
    
    with console.status("[bold green]Creating project structure...") as status:
        # Create directories
        for dir_name in template['directories']:
            os.makedirs(os.path.join(project_path, dir_name), exist_ok=True)
        
        # Create files
        for file_name, content in template['files'].items():
            full_path = os.path.join(project_path, file_name)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, 'w') as f:
                f.write(content)
        
        status.update("[bold green]Validating structure...")
        # Validate
        errors = []
        if not os.path.exists(os.path.join(project_path, 'main.mojo')):
            errors.append("Missing main.mojo file")
        if not validate_project_name(name):
            errors.append("Invalid project name")
        
        # Check .ai beacon
        ai_file = os.path.join(project_path, '.ai')
        if os.path.exists(ai_file):
            try:
                with open(ai_file, 'r') as f:
                    ai_data = json.load(f)
                if not ai_data.get('ai_project'):
                    errors.append(".ai beacon does not confirm AI project")
                if ai_data.get('folders') != template['directories']:
                    errors.append(".ai beacon folders mismatch")
            except json.JSONDecodeError:
                errors.append(".ai beacon is invalid JSON")
        else:
            errors.append("Missing .ai beacon file")
        
        if errors:
            print_error("Validation errors:")
            for error in errors:
                print_error(f"  - {error}")
        else:
            tree = Tree(f"[bold green]{name}[/bold green]")
            for dir_name in template['directories']:
                tree.add(f"[blue]{dir_name}/[/blue]")
            for file_name in template['files']:
                tree.add(f"[yellow]{file_name}[/yellow]")
            console.print(tree)
            print_rich("[bold green]Project created successfully![/bold green]")
            print_rich("[bold blue]Agent beacon active: Run scripts/ping_agent.py to notify agents.[/bold blue]")