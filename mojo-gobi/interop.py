from rich.console import Console
from rich.panel import Panel
from rich.spinner import Spinner
from rich.tree import Tree
from rich import print as rprint
import traceback
import json
import os
import re
import subprocess

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
        
        # Check .manifest.ai beacon
        ai_file = os.path.join(project_path, '.manifest.ai')
        if os.path.exists(ai_file):
            try:
                with open(ai_file, 'r') as f:
                    ai_data = json.load(f)
                if not ai_data.get('ai_project'):
                    errors.append(".manifest.ai beacon does not confirm AI project")
                if ai_data.get('folders') != template['directories']:
                    errors.append(".manifest.ai beacon folders mismatch")
            except json.JSONDecodeError:
                errors.append(".manifest.ai beacon is invalid JSON")
        else:
            errors.append("Missing .manifest.ai beacon file")
        
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
            print_rich("[bold blue]Agent beacon active: Run scripts/ai_agent.py to notify agents.[/bold blue]")

def run_project(path):
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        print_error("No .manifest.ai found. Not an AI project.")
        return
    main_mojo = os.path.join(path, 'main.mojo')
    if not os.path.exists(main_mojo):
        print_error("No main.mojo found in project.")
        return
    with console.status("[bold green]Running AI project...") as status:
        try:
            result = subprocess.run(['mojo', 'main.mojo'], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                print_rich("[bold green]Project ran successfully![/bold green]")
                console.print(result.stdout)
            else:
                print_error("Project run failed.")
                console.print(result.stderr)
        except Exception as e:
            print_error(f"Error running project: {e}")

def validate_project(path):
    errors = []
    warnings = []
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        errors.append("Missing .manifest.ai beacon file")
    else:
        try:
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)
            if not manifest.get('ai_project'):
                errors.append(".manifest.ai does not confirm AI project")
            expected_folders = manifest.get('folders', [])
            for folder in expected_folders:
                if not os.path.exists(os.path.join(path, folder)):
                    errors.append(f"Missing folder: {folder}")
            if not os.path.exists(os.path.join(path, 'main.mojo')):
                errors.append("Missing main.mojo file")
            if not validate_project_name(os.path.basename(path)):
                warnings.append("Project name does not match naming rules")
        except json.JSONDecodeError:
            errors.append(".manifest.ai is invalid JSON")
    if errors:
        print_error("Validation errors:")
        for error in errors:
            print_error(f"  - {error}")
    if warnings:
        rprint("[yellow]Warnings:[/yellow]")
        for warning in warnings:
            rprint(f"  - {warning}")
    if not errors and not warnings:
        print_rich("[bold green]Project is valid![/bold green]")

def sync_dependencies(path):
    req_file = os.path.join(path, 'requirements.txt')
    if not os.path.exists(req_file):
        print_error("No requirements.txt found in project.")
        return
    with console.status("[bold green]Syncing dependencies...") as status:
        try:
            result = subprocess.run(['pip', 'install', '-r', 'requirements.txt'], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                print_rich("[bold green]Dependencies synced successfully![/bold green]")
            else:
                print_error("Dependency sync failed.")
                console.print(result.stderr)
        except Exception as e:
            print_error(f"Error syncing dependencies: {e}")

def build_project(path):
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        print_error("No .manifest.ai found. Not an AI project.")
        return
    with console.status("[bold green]Building AI project...") as status:
        try:
            # First, build the Mojo project
            result = subprocess.run(['mojo', 'build', 'main.mojo'], cwd=path, capture_output=True, text=True)
            if result.returncode != 0:
                print_error("Mojo build failed.")
                console.print(result.stderr)
                return
            print_rich("[bold green]Mojo build completed![/bold green]")
            
            # Then, build the Gobi CLI binary
            status.update("[bold green]Building Gobi CLI binary...")
            # Copy gobi script to project path
            import shutil
            cli_dir = os.path.dirname(os.path.abspath(__file__))
            gobi_src = os.path.join(cli_dir, 'gobi')
            gobi_dst = os.path.join(path, 'gobi')
            shutil.copy(gobi_src, gobi_dst)
            # Create setup.py for cx_Freeze
            setup_content = '''
from cx_Freeze import setup, Executable

setup(
    name="gobi",
    version="0.1.0",
    description="Mojo Gobi CLI",
    options={
        "build_exe": {
            "packages": ["rich", "cx_Freeze"],
            "include_files": [],
        }
    },
    executables=[Executable("gobi")],
)
'''
            with open(os.path.join(path, 'setup.py'), 'w') as f:
                f.write(setup_content)
            result = subprocess.run(['python', 'setup.py', 'build'], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                print_rich("[bold green]Gobi CLI binary built successfully![/bold green]")
                print_rich("[bold blue]Binary located in build/ directory.[/bold blue]")
            else:
                print_error("CLI binary build failed.")
                console.print(result.stderr)
        except Exception as e:
            print_error(f"Error building: {e}")

def add_dependency(package, version, path):
    req_file = os.path.join(path, 'requirements.txt')
    dep = f"{package}=={version}" if version else package
    with open(req_file, 'a') as f:
        f.write(f"{dep}\n")
    with console.status(f"[bold green]Adding {dep}...") as status:
        try:
            result = subprocess.run(['pip', 'install', dep], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                print_rich(f"[bold green]{dep} added successfully![/bold green]")
            else:
                print_error(f"Failed to add {dep}.")
                console.print(result.stderr)
        except Exception as e:
            print_error(f"Error adding dependency: {e}")

def remove_dependency(package, path):
    req_file = os.path.join(path, 'requirements.txt')
    if os.path.exists(req_file):
        with open(req_file, 'r') as f:
            lines = f.readlines()
        with open(req_file, 'w') as f:
            for line in lines:
                if not line.startswith(f"{package}"):
                    f.write(line)
    with console.status(f"[bold green]Removing {package}...") as status:
        try:
            result = subprocess.run(['pip', 'uninstall', '-y', package], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                print_rich(f"[bold green]{package} removed successfully![/bold green]")
            else:
                print_error(f"Failed to remove {package}.")
                console.print(result.stderr)
        except Exception as e:
            print_error(f"Error removing dependency: {e}")