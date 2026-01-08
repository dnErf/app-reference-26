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
from datetime import datetime

console = Console()

def log_entry(entry):
    log_file = os.path.join(os.path.dirname(__file__), '.agents', '_log.md')
    with open(log_file, 'a') as f:
        f.write(f"- {datetime.now()}: {entry}\n")

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
    log_entry(f"Starting init command for project '{name}' at '{path}'")
    # Input validation
    if not validate_project_name(name):
        log_entry(f"Init command failed: invalid project name '{name}'")
        print_error("Invalid project name. Must start with letter, contain only letters, numbers, underscores, hyphens.")
        return
    if not os.path.exists(path):
        log_entry(f"Init command failed: path does not exist '{path}'")
        print_error(f"Path does not exist: {path}")
        return
    project_path = os.path.join(path, name)
    if os.path.exists(project_path) and os.listdir(project_path):
        log_entry(f"Init command failed: project directory exists and not empty '{project_path}'")
        print_error(f"Project directory already exists and is not empty: {project_path}")
        return
    
    template = load_template()
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
            log_entry(f"Init command failed: validation errors {errors}")
            print_error("Validation errors:")
            for error in errors:
                print_error(f"  - {error}")
            # Rollback: remove the created project directory
            import shutil
            if os.path.exists(project_path):
                shutil.rmtree(project_path)
                log_entry(f"Rolled back init: removed '{project_path}' due to validation errors")
                print_error("Project creation rolled back due to errors.")
        else:
            log_entry(f"Init command completed successfully for '{name}'")
            tree = Tree(f"[bold green]{name}[/bold green]")
            for dir_name in template['directories']:
                tree.add(f"[blue]{dir_name}/[/blue]")
            for file_name in template['files']:
                tree.add(f"[yellow]{file_name}[/yellow]")
            console.print(tree)
            print_rich("[bold green]Project created successfully![/bold green]")
            print_rich("[bold blue]Agent beacon active: Run scripts/ai_agent.py to notify agents.[/bold blue]")

def run_project(path):
    log_entry(f"Starting run command at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Run command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        log_entry(f"Run command failed: no .manifest.ai at '{path}'")
        print_error("No .manifest.ai found. Not an AI project.")
        return
    main_mojo = os.path.join(path, 'main.mojo')
    if not os.path.exists(main_mojo):
        log_entry(f"Run command failed: no main.mojo at '{path}'")
        print_error("No main.mojo found in project.")
        return
    with console.status("[bold green]Running AI project...") as status:
        try:
            result = subprocess.run(['mojo', 'main.mojo'], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                log_entry(f"Run command completed successfully at '{path}'")
                print_rich("[bold green]Project ran successfully![/bold green]")
                console.print(result.stdout)
            else:
                log_entry(f"Run command failed at '{path}': {result.stderr.strip()}")
                print_error("Project run failed.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Run command error at '{path}': {e}")
            print_error(f"Error running project: {e}")

def validate_project(path):
    log_entry(f"Starting validate command at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Validate command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
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
        log_entry(f"Validate command completed: project valid at '{path}'")
        print_rich("[bold green]Project is valid![/bold green]")
    else:
        log_entry(f"Validate command completed with issues at '{path}': {len(errors)} errors, {len(warnings)} warnings")

def sync_dependencies(path):
    log_entry(f"Starting sync command at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Sync command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
    req_file = os.path.join(path, 'requirements.txt')
    if not os.path.exists(req_file):
        log_entry(f"Sync command failed: no requirements.txt at '{path}'")
        print_error("No requirements.txt found in project.")
        return
    with console.status("[bold green]Syncing dependencies...") as status:
        try:
            result = subprocess.run(['pip', 'install', '-r', 'requirements.txt'], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                log_entry(f"Sync command completed successfully at '{path}'")
                print_rich("[bold green]Dependencies synced successfully![/bold green]")
            else:
                log_entry(f"Sync command failed at '{path}': {result.stderr.strip()}")
                print_error("Dependency sync failed.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Sync command error at '{path}': {e}")
            print_error(f"Error syncing dependencies: {e}")

def build_project(path):
    log_entry(f"Starting build command at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Build command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        log_entry(f"Build command failed: no .manifest.ai at '{path}'")
        print_error("No .manifest.ai found. Not an AI project.")
        return
    with console.status("[bold green]Building AI project...") as status:
        try:
            # First, build the Mojo project
            result = subprocess.run(['mojo', 'build', 'main.mojo'], cwd=path, capture_output=True, text=True)
            if result.returncode != 0:
                log_entry(f"Build command failed: Mojo build error at '{path}': {result.stderr.strip()}")
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
            if os.path.abspath(gobi_src) != os.path.abspath(gobi_dst):
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
                log_entry(f"Build command completed successfully at '{path}'")
                print_rich("[bold green]Gobi CLI binary built successfully![/bold green]")
                print_rich("[bold blue]Binary located in build/ directory.[/bold blue]")
            else:
                log_entry(f"Build command failed: CLI binary build error at '{path}': {result.stderr.strip()}")
                print_error("CLI binary build failed.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Build command error at '{path}': {e}")
            print_error(f"Error building: {e}")

def add_dependency(package, version, path):
    log_entry(f"Starting add command for '{package}' at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Add command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
    req_file = os.path.join(path, 'requirements.txt')
    if not os.path.exists(req_file):
        log_entry(f"Add command failed: no requirements.txt at '{path}'")
        print_error("No requirements.txt found in project.")
        return
    if not package or not re.match(r'^[a-zA-Z0-9\-_.]+$', package):
        log_entry(f"Add command failed: invalid package name '{package}'")
        print_error("Invalid package name. Must be non-empty and contain only alphanumeric characters, hyphens, underscores, and dots.")
        return
    dep = f"{package}=={version}" if version else package
    with open(req_file, 'a') as f:
        f.write(f"{dep}\n")
    with console.status(f"[bold green]Adding {dep}...") as status:
        try:
            result = subprocess.run(['pip', 'install', dep], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                log_entry(f"Add command completed successfully for '{dep}' at '{path}'")
                print_rich(f"[bold green]{dep} added successfully![/bold green]")
            else:
                log_entry(f"Add command failed for '{dep}' at '{path}': {result.stderr.strip()}")
                print_error(f"Failed to add {dep}.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Add command error for '{dep}' at '{path}': {e}")
            print_error(f"Error adding dependency: {e}")

def remove_dependency(package, path):
    log_entry(f"Starting remove command for '{package}' at '{path}'")
    if not os.path.exists(path) or not os.path.isdir(path):
        log_entry(f"Remove command failed: invalid path '{path}'")
        print_error(f"Invalid path: {path} does not exist or is not a directory.")
        return

    req_file = os.path.join(path, 'requirements.txt')

    if not os.path.exists(req_file):
        log_entry(f"Remove command failed: no requirements.txt at '{path}'")
        print_error(f"requirements.txt not found in {path}.")
        return

    if not package or not re.match(r'^[a-zA-Z0-9\-_.]+$', package):
        log_entry(f"Remove command failed: invalid package name '{package}'")
        print_error("Invalid package name. Must be non-empty and contain only alphanumeric characters, hyphens, underscores, and dots.")
        return

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
                log_entry(f"Remove command completed successfully for '{package}' at '{path}'")
                print_rich(f"[bold green]{package} removed successfully![/bold green]")
            else:
                log_entry(f"Remove command failed for '{package}' at '{path}': {result.stderr.strip()}")
                print_error(f"Failed to remove {package}.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Remove command error for '{package}' at '{path}': {e}")
            print_error(f"Error removing dependency: {e}")

def test_project(path):
    log_entry(f"Starting test command at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Test command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        log_entry(f"Test command failed: no .manifest.ai at '{path}'")
        print_error("No .manifest.ai found. Not an AI project.")
        return

    with console.status("[bold green]Running tests...") as status:
        try:
            # Run Mojo tests
            mojo_test_files = []
            for root, dirs, files in os.walk(path):
                for file in files:
                    if file.endswith('.mojo') and 'test' in file.lower():
                        mojo_test_files.append(os.path.join(root, file))
            if mojo_test_files:
                for test_file in mojo_test_files:
                    log_entry(f"Running Mojo test: {test_file}")
                    result = subprocess.run(['mojo', 'run', test_file], cwd=path, capture_output=True, text=True)
                    if result.returncode == 0:
                        print_rich(f"[bold green]Mojo test passed: {os.path.basename(test_file)}[/bold green]")
                    else:
                        log_entry(f"Mojo test failed: {test_file} - {result.stderr.strip()}")
                        print_error(f"Mojo test failed: {os.path.basename(test_file)}")
                        console.print(result.stderr)
            else:
                print_rich("[yellow]No Mojo test files found.[/yellow]")

            # Run Python tests with pytest
            if os.path.exists(os.path.join(path, 'test')) or any(f.endswith('_test.py') or f.startswith('test_') for f in os.listdir(path)):
                log_entry("Running Python tests with pytest")
                result = subprocess.run(['pytest'], cwd=path, capture_output=True, text=True)
                if result.returncode == 0:
                    print_rich("[bold green]Python tests passed![/bold green]")
                else:
                    log_entry(f"Python tests failed: {result.stderr.strip()}")
                    print_error("Python tests failed.")
                    console.print(result.stderr)
            else:
                print_rich("[yellow]No Python test files found.[/yellow]")

            log_entry(f"Test command completed at '{path}'")
        except Exception as e:
            log_entry(f"Test command error at '{path}': {e}")
            print_error(f"Error running tests: {e}")

def deploy_project(path):
    log_entry(f"Starting deploy command at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Deploy command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        log_entry(f"Deploy command failed: no .manifest.ai at '{path}'")
        print_error("No .manifest.ai found. Not an AI project.")
        return

    with console.status("[bold green]Deploying project...") as status:
        try:
            import zipfile
            import shutil

            # Check if build exists
            build_dir = os.path.join(path, 'build')
            if not os.path.exists(build_dir):
                log_entry(f"Deploy command failed: no build directory at '{path}'")
                print_error("No build directory found. Run 'build' first.")
                return

            # Create deploy directory
            deploy_dir = os.path.join(path, 'deploy')
            os.makedirs(deploy_dir, exist_ok=True)

            # Copy build to deploy
            shutil.copytree(build_dir, os.path.join(deploy_dir, 'build'), dirs_exist_ok=True)

            # Copy main.mojo and other essentials
            shutil.copy(os.path.join(path, 'main.mojo'), deploy_dir)
            if os.path.exists(os.path.join(path, 'requirements.txt')):
                shutil.copy(os.path.join(path, 'requirements.txt'), deploy_dir)
            if os.path.exists(os.path.join(path, 'README.md')):
                shutil.copy(os.path.join(path, 'README.md'), deploy_dir)

            # Create zip
            zip_name = os.path.basename(path) + '_deploy'
            zip_path = os.path.join(path, zip_name)
            shutil.make_archive(zip_path, 'zip', deploy_dir)

            log_entry(f"Deploy command completed: created {zip_name}.zip at '{path}'")
            print_rich(f"[bold green]Project deployed successfully![/bold green]")
            print_rich(f"[bold blue]Package: {zip_name}.zip[/bold blue]")

            # Clean up deploy dir
            shutil.rmtree(deploy_dir)

        except Exception as e:
            log_entry(f"Deploy command error at '{path}': {e}")
            print_error(f"Error deploying: {e}")

def clean_project(path):
    log_entry(f"Starting clean command at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Clean command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return

    with console.status("[bold green]Cleaning project...") as status:
        try:
            import shutil
            cleaned = False

            # Remove build directory
            build_dir = os.path.join(path, 'build')
            if os.path.exists(build_dir):
                shutil.rmtree(build_dir)
                log_entry(f"Removed build directory at '{path}'")
                cleaned = True

            # Remove __pycache__ directories
            for root, dirs, files in os.walk(path):
                if '__pycache__' in dirs:
                    pycache_path = os.path.join(root, '__pycache__')
                    shutil.rmtree(pycache_path)
                    log_entry(f"Removed __pycache__ at '{pycache_path}'")
                    cleaned = True

            # Remove .pyc files
            for root, dirs, files in os.walk(path):
                for file in files:
                    if file.endswith('.pyc'):
                        pyc_file = os.path.join(root, file)
                        os.remove(pyc_file)
                        log_entry(f"Removed .pyc file '{pyc_file}'")
                        cleaned = True

            # Remove deploy zips
            for file in os.listdir(path):
                if file.endswith('_deploy.zip'):
                    zip_file = os.path.join(path, file)
                    os.remove(zip_file)
                    log_entry(f"Removed deploy zip '{zip_file}'")
                    cleaned = True

            if cleaned:
                log_entry(f"Clean command completed successfully at '{path}'")
                print_rich("[bold green]Project cleaned successfully![/bold green]")
            else:
                log_entry(f"Clean command: nothing to clean at '{path}'")
                print_rich("[yellow]Nothing to clean.[/yellow]")

        except Exception as e:
            log_entry(f"Clean command error at '{path}': {e}")
            print_error(f"Error cleaning: {e}")

def update_cli(method):
    log_entry(f"Starting update command with method '{method}'")
    with console.status("[bold green]Updating Gobi CLI...") as status:
        try:
            if method == 'pip':
                result = subprocess.run(['pip', 'install', '--upgrade', 'gobi'], capture_output=True, text=True)
                if result.returncode == 0:
                    log_entry("Update command completed successfully via pip")
                    print_rich("[bold green]Gobi CLI updated successfully via pip![/bold green]")
                else:
                    log_entry(f"Update command failed via pip: {result.stderr.strip()}")
                    print_error("Update failed via pip.")
                    console.print(result.stderr)
            elif method == 'git':
                # Assume the CLI is installed via git, update the repo
                cli_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                result = subprocess.run(['git', 'pull'], cwd=cli_dir, capture_output=True, text=True)
                if result.returncode == 0:
                    log_entry("Update command completed successfully via git")
                    print_rich("[bold green]Gobi CLI updated successfully via git![/bold green]")
                else:
                    log_entry(f"Update command failed via git: {result.stderr.strip()}")
                    print_error("Update failed via git.")
                    console.print(result.stderr)
        except Exception as e:
            log_entry(f"Update command error: {e}")
            print_error(f"Error updating: {e}")

def run_plugin(name, args, path):
    log_entry(f"Starting plugin '{name}' at '{path}' with args {args}")
    plugin_dir = os.path.join(path, 'plugins')
    plugin_file = os.path.join(plugin_dir, f"{name}.py")
    if not os.path.exists(plugin_file):
        log_entry(f"Plugin '{name}' not found at '{plugin_file}'")
        print_error(f"Plugin '{name}' not found in plugins/ directory.")
        return

    with console.status(f"[bold green]Running plugin {name}...") as status:
        try:
            # Run the plugin script with Python
            cmd = ['python', plugin_file] + list(args)
            result = subprocess.run(cmd, cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                log_entry(f"Plugin '{name}' completed successfully")
                print_rich(f"[bold green]Plugin '{name}' ran successfully![/bold green]")
                if result.stdout:
                    console.print(result.stdout)
            else:
                log_entry(f"Plugin '{name}' failed: {result.stderr.strip()}")
                print_error(f"Plugin '{name}' failed.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Plugin '{name}' error: {e}")
            print_error(f"Error running plugin: {e}")