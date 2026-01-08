try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.spinner import Spinner
    from rich.tree import Tree
    from rich import print as rprint
    RICH_AVAILABLE = True
except ImportError:
    # Fallback for when rich is not available
    class DummyConsole:
        def print(self, *args, **kwargs):
            print(*args)
        def status(self, *args, **kwargs):
            return DummyStatus()
    class DummyStatus:
        def __enter__(self):
            return self
        def __exit__(self, *args):
            pass
        def update(self, *args):
            pass
    class DummyPanel:
        def __init__(self, content, title=None, **kwargs):
            self.content = content
            self.title = title
        def __str__(self):
            if self.title:
                return f"{self.title}\n{self.content}"
            return self.content
    class DummySpinner:
        pass
    class DummyTree:
        def __init__(self, root, **kwargs):
            self.root = root
            self.items = []
        def add(self, item):
            self.items.append(item)
        def __str__(self):
            lines = [self.root]
            for item in self.items:
                lines.append(f"├── {item}")
            return "\n".join(lines)
    def rprint(*args, **kwargs):
        print(*args)
    Console = DummyConsole
    Panel = DummyPanel
    Spinner = DummySpinner
    Tree = DummyTree
    RICH_AVAILABLE = False

import traceback
import json
import os
import re
import subprocess
import tomllib
try:
    import tomli_w
except ImportError:
    tomli_w = None
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
    # Find template.json relative to this script's location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    template_path = os.path.join(script_dir, 'template.json')
    with open(template_path, 'r') as f:
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
            
            # Create venv
            env_create(project_path)
            
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
    
    # Execute agent hooks
    if os.path.exists(manifest_path):
        try:
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)
            agent_hooks = manifest.get('agent_hooks', [])
            for hook in agent_hooks:
                if hook == 'validate_structure':
                    agent_script = os.path.join(path, '.gobi', 'scripts', 'ai_agent.py')
                    if os.path.exists(agent_script):
                        log_entry(f"Executing agent hook: {hook}")
                        try:
                            result = subprocess.run([agent_script], capture_output=True, text=True, cwd=path)
                            if result.stdout:
                                print_panel("AI Agent Output", result.stdout.strip())
                            if result.stderr:
                                print_error(f"Agent script error: {result.stderr.strip()}")
                        except Exception as e:
                            print_error(f"Failed to execute agent hook {hook}: {e}")
                # Add other hooks here as needed
        except json.JSONDecodeError:
            pass  # Already handled above
    
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
    main_mojo = os.path.join(path, 'main.mojo')
    if not os.path.exists(main_mojo):
        log_entry(f"Build command failed: no main.mojo at '{path}'")
        print_error("No main.mojo found in project.")
        return
    
    build_dir = os.path.join(path, 'build')
    os.makedirs(build_dir, exist_ok=True)
    
    with console.status("[bold green]Building Mojo project...") as status:
        try:
            # Step 1: Run mojo build
            status.update("[bold green]Running mojo build...")
            result = subprocess.run(['mojo', 'build', 'main.mojo'], cwd=path, capture_output=True, text=True)
            if result.returncode != 0:
                log_entry(f"Build command failed at mojo build: {result.stderr.strip()}")
                print_error("Mojo build failed.")
                console.print(result.stderr)
                return
            
            # Assume build produces an executable, e.g., main
            exe_path = os.path.join(path, 'main')
            if not os.path.exists(exe_path):
                log_entry(f"Build command failed: no executable produced at '{exe_path}'")
                print_error("No executable found after mojo build.")
                return
            
            # Step 2: Copy executable to build directory
            status.update("[bold green]Copying executable to build directory...")
            import shutil
            shutil.copy2(exe_path, build_dir)
            
            # Step 3: Copy dependencies
            status.update("[bold green]Copying dependencies...")
            env_dir = os.path.join(path, '.gobi', 'env')
            if os.path.exists(env_dir):
                # Copy venv to build
                build_env = os.path.join(build_dir, 'env')
                shutil.copytree(env_dir, build_env, dirs_exist_ok=True)
            
            # Copy requirements.txt and other config files
            for file in ['requirements.txt', 'pyproject.toml', 'pylock.toml']:
                src = os.path.join(path, file)
                if os.path.exists(src):
                    shutil.copy2(src, build_dir)
            
            # Step 4: Create a simple launcher script or package
            status.update("[bold green]Creating package...")
            # For now, just create a simple run script
            run_script = os.path.join(build_dir, 'run.sh')
            with open(run_script, 'w') as f:
                f.write('#!/bin/bash\n')
                f.write('export PYTHONPATH="$(dirname "$0")/env/lib/python*/site-packages:$PYTHONPATH"\n')
                f.write('./main "$@"\n')
            os.chmod(run_script, 0o755)
            
            log_entry(f"Build command completed successfully at '{path}'")
            print_rich("[bold green]Project built successfully![/bold green]")
            print_rich(f"[bold blue]Build output in: {build_dir}[/bold blue]")
            
        except Exception as e:
            log_entry(f"Build command error at '{path}': {e}")
            print_error(f"Error building project: {e}")


def sync_dependencies(path, lock=False):
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
            # Use venv's pip if env exists
            env_dir = os.path.join(path, '.gobi', 'env')
            pip_cmd = ['pip', 'install', '-r', 'requirements.txt']
            if os.path.exists(env_dir):
                python_exe = os.path.join(env_dir, 'bin', 'python')
                pip_cmd = [python_exe, '-m', 'pip', 'install', '-r', 'requirements.txt']
                log_entry("Using venv for dependency sync")
            result = subprocess.run(pip_cmd, cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                log_entry(f"Sync command completed successfully at '{path}'")
                print_rich("[bold green]Dependencies synced successfully![/bold green]")
                if lock:
                    if generate_pylock_from_requirements(path):
                        print_rich("[bold green]Pylock file generated![/bold green]")
                    else:
                        print_error("Failed to generate pylock file.")
            else:
                log_entry(f"Sync command failed at '{path}': {result.stderr.strip()}")
                print_error("Dependency sync failed.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Sync command error at '{path}': {e}")
            print_error(f"Error syncing dependencies: {e}")

def build_project(path, platform='current'):
    log_entry(f"Starting build command at '{path}' for platform '{platform}'")
    if not os.path.exists(path):
        log_entry(f"Build command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        log_entry(f"Build command failed: no .manifest.ai at '{path}'")
        print_error("No .manifest.ai found. Not an AI project.")
        return
    main_mojo = os.path.join(path, 'main.mojo')
    if not os.path.exists(main_mojo):
        log_entry(f"Build command failed: no main.mojo at '{path}'")
        print_error("No main.mojo found in project.")
        return
    
    import platform as plat_module
    current_platform = plat_module.system().lower()
    if platform == 'current':
        platforms = [current_platform]
    elif platform == 'all':
        platforms = ['linux', 'darwin', 'windows']
    else:
        platforms = [platform]
    
    for target_platform in platforms:
        build_dir = os.path.join(path, 'build', target_platform)
        os.makedirs(build_dir, exist_ok=True)
        
        with console.status(f"[bold green]Building for {target_platform}...") as status:
            try:
                if target_platform == current_platform:
    build_dir = os.path.join(path, 'build')
    os.makedirs(build_dir, exist_ok=True)
    
    with console.status("[bold green]Building Mojo project...") as status:
        try:
            # Step 1: Run mojo build
            status.update("[bold green]Running mojo build...")
            result = subprocess.run(['mojo', 'build', 'main.mojo'], cwd=path, capture_output=True, text=True)
            if result.returncode != 0:
                log_entry(f"Build command failed at mojo build: {result.stderr.strip()}")
                print_error("Mojo build failed.")
                console.print(result.stderr)
                return
            
            # Assume build produces an executable, e.g., main
            exe_path = os.path.join(path, 'main')
            if not os.path.exists(exe_path):
                log_entry(f"Build command failed: no executable produced at '{exe_path}'")
                print_error("No executable found after mojo build.")
                return
            
            # Step 2: Copy executable to build directory
            status.update("[bold green]Copying executable to build directory...")
            import shutil
            shutil.copy2(exe_path, build_dir)
            
            # Step 3: Copy dependencies
            status.update("[bold green]Copying dependencies...")
            env_dir = os.path.join(path, '.gobi', 'env')
            if os.path.exists(env_dir):
                # Copy venv to build
                build_env = os.path.join(build_dir, 'env')
                shutil.copytree(env_dir, build_env, dirs_exist_ok=True)
            
            # Copy requirements.txt and other config files
            for file in ['requirements.txt', 'pyproject.toml', 'pylock.toml']:
                src = os.path.join(path, file)
                if os.path.exists(src):
                    shutil.copy2(src, build_dir)
            
            # Step 4: Do cx_Freeze for Python dependencies
            status.update("[bold green]Freezing Python dependencies with cx_Freeze...")
            # Create setup.py for cx_Freeze to freeze the Python environment
            setup_content = '''
from cx_Freeze import setup, Executable

# Dummy executable since we're just freezing the environment
setup(
    name="ai_project",
    version="0.1.0",
    description="AI Project Dependencies",
    options={
        "build_exe": {
            "packages": [],
            "include_files": [],
            "path": "env/lib/python*/site-packages",
        }
    },
    executables=[],
)
'''
            with open(os.path.join(build_dir, 'setup.py'), 'w') as f:
                f.write(setup_content)
            
            # Run cx_Freeze
            python_cmd = ['python', 'setup.py', 'build']
            if os.path.exists(build_env):
                python_cmd = ['./env/bin/python', 'setup.py', 'build']
            result = subprocess.run(python_cmd, cwd=build_dir, capture_output=True, text=True)
            if result.returncode != 0:
                log_entry(f"cx_Freeze failed: {result.stderr.strip()}")
                print_error("cx_Freeze failed.")
                console.print(result.stderr)
                # Continue anyway
            
            log_entry(f"Build command completed successfully at '{path}'")
            print_rich("[bold green]Project built successfully![/bold green]")
            print_rich(f"[bold blue]Build output in: {build_dir}[/bold blue]")
            
        except Exception as e:
            log_entry(f"Build command error at '{path}': {e}")
            print_error(f"Error building project: {e}")

def read_pyproject(path):
    """Read pyproject.toml and return the data."""
    pyproject_file = os.path.join(path, 'pyproject.toml')
    if not os.path.exists(pyproject_file):
        return None
    try:
        with open(pyproject_file, 'rb') as f:
            return tomllib.load(f)
    except Exception as e:
        print_error(f"Error reading pyproject.toml: {e}")
        return None

def update_pyproject_dependencies(path, dependencies):
    """Update dependencies in pyproject.toml."""
    pyproject_file = os.path.join(path, 'pyproject.toml')
    try:
        # Read existing pyproject.toml
        data = read_pyproject(path)
        if data is None:
            return False
        
        # Update dependencies
        if 'project' not in data:
            data['project'] = {}
        data['project']['dependencies'] = dependencies
        
        # Write back
        with open(pyproject_file, 'wb') as f:
            tomli_w.dump(data, f)
        return True
    except Exception as e:
        print_error(f"Error updating pyproject.toml: {e}")
        return False

def add_dependency_to_pyproject(path, package, version):
    """Add a dependency to pyproject.toml."""
    data = read_pyproject(path)
    if data is None:
        return False
    
    deps = data.get('project', {}).get('dependencies', [])
    dep_str = f"{package}=={version}" if version else package
    
    # Check if already exists
    for dep in deps:
        if dep.startswith(package):
            # Update existing
            deps[deps.index(dep)] = dep_str
            break
    else:
        # Add new
        deps.append(dep_str)
    
    return update_pyproject_dependencies(path, deps)

def remove_dependency_from_pyproject(path, package):
    """Remove a dependency from pyproject.toml."""
    data = read_pyproject(path)
    if data is None:
        return False
    
    deps = data.get('project', {}).get('dependencies', [])
    deps = [dep for dep in deps if not dep.startswith(package)]
    
    return update_pyproject_dependencies(path, deps)

def write_pylock(path, data):
    """Write data to pylock.toml file."""
    pylock_file = os.path.join(path, 'pylock.toml')
    try:
        if tomli_w:
            with open(pylock_file, 'wb') as f:
                tomli_w.dump(data, f)
        else:
            # Simple TOML writer for basic cases
            with open(pylock_file, 'w') as f:
                f.write("# Pylock file generated by Gobi CLI\n\n")
                if 'metadata' in data:
                    f.write("[metadata]\n")
                    for k, v in data['metadata'].items():
                        f.write(f'{k} = "{v}"\n')
                    f.write("\n")
                if 'packages' in data:
                    for pkg in data['packages']:
                        f.write("[[packages]]\n")
                        for k, v in pkg.items():
                            if isinstance(v, str):
                                f.write(f'{k} = "{v}"\n')
                            else:
                                f.write(f'{k} = {v}\n')
                        f.write("\n")
        return True
    except Exception as e:
        print_error(f"Error writing pylock.toml: {e}")
        return False

def generate_pylock_from_requirements(path):
    """Generate pylock.toml from requirements.txt and installed packages."""
    req_file = os.path.join(path, 'requirements.txt')
    if not os.path.exists(req_file):
        print_error("No requirements.txt found to generate pylock from.")
        return False
    
    # Get installed packages info
    try:
        result = subprocess.run(['pip', 'list', '--format=json'], capture_output=True, text=True, cwd=path)
        if result.returncode != 0:
            print_error("Failed to get installed packages list.")
            return False
        
        installed = json.loads(result.stdout)
        packages = []
        with open(req_file, 'r') as f:
            requirements = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        
        for pkg in installed:
            name = pkg['name']
            version = pkg['version']
            # Check if this package is in requirements
            for req in requirements:
                if req.startswith(name) or req.startswith(name.replace('-', '_')):
                    packages.append({
                        'name': name,
                        'version': version,
                        'source': 'pypi'
                    })
                    break
        
        pylock_data = {
            'metadata': {
                'version': '1.0',
                'python': '3.14'
            },
            'packages': packages
        }
        
        return write_pylock(path, pylock_data)
    except Exception as e:
        print_error(f"Error generating pylock: {e}")
        return False

def add_dependency(package, version, path, lock=False):
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
                
                # Update pyproject.toml
                if add_dependency_to_pyproject(path, package, version):
                    print_rich("[bold green]pyproject.toml updated![/bold green]")
                else:
                    print_error("Failed to update pyproject.toml.")
                
                if lock:
                    if generate_pylock_from_requirements(path):
                        print_rich("[bold green]Pylock file updated![/bold green]")
                    else:
                        print_error("Failed to update pylock file.")
            else:
                log_entry(f"Add command failed for '{dep}' at '{path}': {result.stderr.strip()}")
                print_error(f"Failed to add {dep}.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Add command error for '{dep}' at '{path}': {e}")
            print_error(f"Error adding dependency: {e}")

def remove_dependency(package, path, lock=False):
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
    
    # Update pyproject.toml if it exists
    if remove_dependency_from_pyproject(path, package):
        print_rich("[bold green]pyproject.toml updated![/bold green]")
    else:
        print_error("Failed to update pyproject.toml.")
    
    with console.status(f"[bold green]Removing {package}...") as status:
        try:
            result = subprocess.run(['pip', 'uninstall', '-y', package], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                log_entry(f"Remove command completed successfully for '{package}' at '{path}'")
                print_rich(f"[bold green]{package} removed successfully![/bold green]")
                if lock:
                    if generate_pylock_from_requirements(path):
                        print_rich("[bold green]Pylock file updated![/bold green]")
                    else:
                        print_error("Failed to update pylock file.")
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
            env_dir = os.path.join(path, '.gobi', 'env')
            pytest_cmd = ['pytest']
            if os.path.exists(env_dir):
                python_exe = os.path.join(env_dir, 'bin', 'python')
                pytest_cmd = [python_exe, '-m', 'pytest']
                log_entry("Using venv for Python tests")
            if os.path.exists(os.path.join(path, 'test')) or any(f.endswith('_test.py') or f.startswith('test_') for f in os.listdir(path)):
                log_entry("Running Python tests with pytest")
                result = subprocess.run(pytest_cmd, cwd=path, capture_output=True, text=True)
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

def validate_project(path):
    log_entry(f"Starting validate command at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Validate command failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return
    manifest_path = os.path.join(path, '.manifest.ai')
    if not os.path.exists(manifest_path):
        log_entry(f"Validate command failed: no .manifest.ai at '{path}'")
        print_error("No .manifest.ai found. Not an AI project.")
        return

    with console.status("[bold green]Validating AI project...") as status:
        try:
            # Read manifest
            with open(manifest_path, 'r') as f:
                manifest = json.load(f)
            
            # Execute agent hooks
            agent_hooks = manifest.get('agent_hooks', [])
            for hook in agent_hooks:
                log_entry(f"Executing agent hook: {hook}")
                if hook == 'validate_structure':
                    if not validate_project_structure(path, manifest):
                        print_error(f"Structure validation failed for hook: {hook}")
                        return
                elif hook == 'check_dependencies':
                    if not check_project_dependencies(path, manifest):
                        print_error(f"Dependency check failed for hook: {hook}")
                        return
                else:
                    print_rich(f"[yellow]Unknown agent hook: {hook}[/yellow]")
            
            log_entry(f"Validate command completed successfully at '{path}'")
            print_rich("[bold green]AI project validation successful![/bold green]")
            
        except Exception as e:
            log_entry(f"Validate command error at '{path}': {e}")
            print_error(f"Error validating project: {e}")

def validate_project_structure(path, manifest):
    """Validate project structure according to manifest."""
    required_folders = manifest.get('folders', [])
    for folder in required_folders:
        folder_path = os.path.join(path, folder)
        if not os.path.exists(folder_path):
            log_entry(f"Structure validation failed: missing folder '{folder}'")
            print_error(f"Missing required folder: {folder}")
            return False
        if not os.path.isdir(folder_path):
            log_entry(f"Structure validation failed: '{folder}' is not a directory")
            print_error(f"Required path is not a directory: {folder}")
            return False
    
    log_entry("Project structure validation passed")
    print_rich("[green]✓ Project structure validated[/green]")
    return True

def check_project_dependencies(path, manifest):
    """Check project dependencies."""
    req_file = os.path.join(path, 'requirements.txt')
    if not os.path.exists(req_file):
        log_entry("Dependency check failed: no requirements.txt")
        print_error("Missing requirements.txt")
        return False
    
    # Check if pyproject.toml exists and is consistent
    pyproject_file = os.path.join(path, 'pyproject.toml')
    if os.path.exists(pyproject_file):
        try:
            import tomllib
            with open(pyproject_file, 'rb') as f:
                pyproject_data = tomllib.load(f)
            
            pyproject_deps = pyproject_data.get('project', {}).get('dependencies', [])
            
            with open(req_file, 'r') as f:
                req_lines = [line.strip() for line in f if line.strip() and not line.startswith('#')]
            
            # Basic consistency check - pyproject should have at least the reqs
            for req in req_lines:
                package = req.split('==')[0].split('>=')[0].split('<=')[0].split('>')[0].split('<')[0].strip()
                if not any(dep.startswith(package) for dep in pyproject_deps):
                    log_entry(f"Dependency mismatch: {package} in requirements.txt but not in pyproject.toml")
                    print_error(f"Dependency mismatch: {package} in requirements.txt but not in pyproject.toml")
                    return False
            
            log_entry("Dependencies consistency check passed")
            print_rich("[green]✓ Dependencies consistent[/green]")
        except Exception as e:
            log_entry(f"Error checking pyproject.toml consistency: {e}")
            print_error(f"Error checking pyproject.toml: {e}")
            return False
    else:
        log_entry("No pyproject.toml found, skipping consistency check")
        print_rich("[yellow]! No pyproject.toml for consistency check[/yellow]")
    
    return True

def sync_pyproject_from_requirements(path):
    """Sync pyproject.toml dependencies from requirements.txt."""
    req_file = os.path.join(path, 'requirements.txt')
    if not os.path.exists(req_file):
        print_error("No requirements.txt found to sync from.")
        return False
    
    with open(req_file, 'r') as f:
        req_lines = [line.strip() for line in f if line.strip() and not line.startswith('#')]
    
    # Update pyproject.toml
    return update_pyproject_dependencies(path, req_lines)

def env_create(path):
    log_entry(f"Starting env create at '{path}'")
    if not os.path.exists(path):
        log_entry(f"Env create failed: path does not exist '{path}'")
        print_error(f"Project path does not exist: {path}")
        return

    env_dir = os.path.join(path, '.gobi', 'env')
    if os.path.exists(env_dir):
        log_entry(f"Env create: venv already exists at '{env_dir}'")
        print_rich("[yellow]Venv already exists.[/yellow]")
        return

    with console.status("[bold green]Creating venv...") as status:
        try:
            import venv
            venv.create(env_dir, with_pip=True)
            log_entry(f"Created venv at '{env_dir}'")

            # Install base dependencies
            req_file = os.path.join(path, 'requirements.txt')
            if os.path.exists(req_file):
                pip_exe = os.path.join(env_dir, 'bin', 'pip')
                result = subprocess.run([pip_exe, 'install', '-r', req_file], cwd=path, capture_output=True, text=True)
                if result.returncode == 0:
                    log_entry(f"Installed dependencies from requirements.txt in venv")
                    print_rich("[bold green]Venv created and dependencies installed![/bold green]")
                else:
                    log_entry(f"Failed to install dependencies: {result.stderr.strip()}")
                    print_error("Venv created but failed to install dependencies.")
                    console.print(result.stderr)
            else:
                print_rich("[bold green]Venv created![/bold green]")

        except Exception as e:
            log_entry(f"Env create error at '{path}': {e}")
            print_error(f"Error creating venv: {e}")

def env_activate(path):
    log_entry(f"Starting env activate at '{path}'")
    env_dir = os.path.join(path, '.gobi', 'env')
    if not os.path.exists(env_dir):
        log_entry(f"Env activate failed: venv does not exist at '{env_dir}'")
        print_error("Venv does not exist. Run 'env create' first.")
        return

    activate_script = os.path.join(env_dir, 'bin', 'activate')
    if os.path.exists(activate_script):
        log_entry(f"Activated venv at '{env_dir}'")
        print_rich(f"[bold green]Venv activated. Run 'source {activate_script}' in your shell.[/bold green]")
    else:
        log_entry(f"Env activate failed: activate script not found")
        print_error("Activate script not found.")

def env_install(package, version, path):
    log_entry(f"Starting env install '{package}' at '{path}'")
    env_dir = os.path.join(path, '.gobi', 'env')
    if not os.path.exists(env_dir):
        log_entry(f"Env install failed: venv does not exist at '{env_dir}'")
        print_error("Venv does not exist. Run 'env create' first.")
        return

    pip_exe = os.path.join(env_dir, 'bin', 'pip')
    dep = f"{package}=={version}" if version else package
    with console.status(f"[bold green]Installing {dep}...") as status:
        try:
            result = subprocess.run([pip_exe, 'install', dep], cwd=path, capture_output=True, text=True)
            if result.returncode == 0:
                log_entry(f"Installed {dep} in venv")
                print_rich(f"[bold green]{dep} installed successfully![/bold green]")

                # Update requirements.txt
                req_file = os.path.join(path, 'requirements.txt')
                with open(req_file, 'a') as f:
                    f.write(f"{dep}\n")
                log_entry(f"Updated requirements.txt with {dep}")
            else:
                log_entry(f"Failed to install {dep}: {result.stderr.strip()}")
                print_error(f"Failed to install {dep}.")
                console.print(result.stderr)
        except Exception as e:
            log_entry(f"Env install error for '{dep}' at '{path}': {e}")
            print_error(f"Error installing {dep}: {e}")

def env_list(path):
    log_entry(f"Starting env list at '{path}'")
    env_dir = os.path.join(path, '.gobi', 'env')
    if not os.path.exists(env_dir):
        log_entry(f"Env list failed: venv does not exist at '{env_dir}'")
        print_error("Venv does not exist. Run 'env create' first.")
        return

    pip_exe = os.path.join(env_dir, 'bin', 'pip')
    try:
        result = subprocess.run([pip_exe, 'list'], cwd=path, capture_output=True, text=True)
        if result.returncode == 0:
            log_entry(f"Listed packages in venv at '{path}'")
            print_rich("[bold green]Installed packages:[/bold green]")
            console.print(result.stdout)
        else:
            log_entry(f"Failed to list packages: {result.stderr.strip()}")
            print_error("Failed to list packages.")
            console.print(result.stderr)
    except Exception as e:
        log_entry(f"Env list error at '{path}': {e}")
        print_error(f"Error listing packages: {e}")