# Packaging Extension for Mojo Grizzly DB
# Inspired by Hatch, Pixi, cx_Freeze for distributing Mojo apps with Python interop

from arrow import Table, Schema

struct PackageConfig:
    var name: String
    var version: String
    var python_deps: List[String]
    var mojo_files: List[String]

var current_package: PackageConfig

fn init():
    current_package = PackageConfig("", "", List[String](), List[String]())
    print("Packaging extension loaded. Supports init, build, install like Pixi/Hatch.")

fn package_init(name: String, version: String):
    current_package.name = name
    current_package.version = version
    # Create package directory
    let py_os = Python.import_module("os")
    py_os.makedirs(name, exist_ok=True)
    let py_path = Python.import_module("pathlib").Path
    let toml_path = py_path(name) / "pyproject.toml"
    with open(String(toml_path), "w") as f:
        f.write("[tool.hatch.build]\npackages = [\".\"]\n")
    print("Package initialized:", name, version)

fn add_python_dep(dep: String):
    current_package.python_deps.append(dep)
    # Update pyproject.toml
    let py_path = Python.import_module("pathlib").Path
    let toml_path = py_path(current_package.name) / "pyproject.toml"
    with open(String(toml_path), "a") as f:
        f.write("dependencies = [\"" + dep + "\"]\n")
    print("Added Python dep:", dep)

fn add_mojo_file(file: String):
    current_package.mojo_files.append(file)
    # Copy file to package dir
    let py_shutil = Python.import_module("shutil")
    py_shutil.copy(file, current_package.name + "/" + file)
    print("Added Mojo file:", file)

fn package_build():
    # Build: Compile Mojo files, create distribution archive without external tools
    print("Building package with pure Mojo/Python...")
    let py_subprocess = Python.import_module("subprocess")
    let py_os = Python.import_module("os")
    let py_shutil = Python.import_module("shutil")
    let py_zipfile = Python.import_module("zipfile")
    # Compile Mojo files using modular
    for file in current_package.mojo_files:
        py_subprocess.run(["modular", "run", "mojo", "build", file], cwd=current_package.name)
        print("Compiled", file, "with Mojo")
    # Create dist directory
    py_os.makedirs(current_package.name + "/dist", exist_ok=True)
    # Create a simple executable script that runs the Mojo binary
    let exe_content = "#!/bin/bash\n# Simple launcher for Mojo app\n./" + current_package.name + "\n"
    with open(current_package.name + "/dist/run.sh", "w") as f:
        f.write(exe_content)
    py_os.chmod(current_package.name + "/dist/run.sh", 0o755)
    # Copy compiled binaries and deps
    for file in current_package.mojo_files:
        let base = file.split(".")[0]  # Assume .mojo -> binary name
        if py_os.path.exists(base):
            py_shutil.copy(base, current_package.name + "/dist/")
    # Create zip archive for distribution
    let zip_name = current_package.name + "-" + current_package.version + ".zip"
    with py_zipfile.ZipFile(zip_name, "w") as zf:
        for root, dirs, files in py_os.walk(current_package.name + "/dist"):
            for file in files:
                zf.write(py_os.path.join(root, file), py_os.path.relpath(py_os.path.join(root, file), current_package.name + "/dist"))
    print("Pure build completed, archive:", zip_name)

fn package_install():
    # Install: Copy to system location without pip
    print("Installing package to system...")
    let py_shutil = Python.import_module("shutil")
    let py_os = Python.import_module("os")
    let install_dir = "/usr/local/bin/" + current_package.name
    py_os.makedirs(install_dir, exist_ok=True)
    py_shutil.copytree(current_package.name + "/dist", install_dir, dirs_exist_ok=True)
    print("Package installed to", install_dir)

# Pixi integration (pure, no external dep)
fn pixi_init():
    print("Initializing pure Pixi-like project...")
    let py_os = Python.import_module("os")
    let py_path = Python.import_module("pathlib").Path
    py_os.makedirs(current_package.name, exist_ok=True)
    let pixi_path = py_path(current_package.name) / "pixi.toml"
    with open(String(pixi_path), "w") as f:
        f.write("[project]\nname = \"" + current_package.name + "\"\nversion = \"" + current_package.version + "\"\n")
    print("Pure Pixi project initialized")

fn pixi_add_dep(dep: String):
    print("Adding dependency (pure, no external Pixi):", dep)
    current_package.python_deps.append(dep)
    # Append to pixi.toml
    let py_path = Python.import_module("pathlib").Path
    let pixi_path = py_path(current_package.name) / "pixi.toml"
    with open(String(pixi_path), "a") as f:
        f.write("dependencies = [\"" + dep + "\"]\n")
    print("Dependency added to pixi.toml")

# Hatch integration (pure, no external dep)
fn hatch_init():
    print("Initializing pure Hatch-like project...")
    let py_os = Python.import_module("os")
    let py_path = Python.import_module("pathlib").Path
    py_os.makedirs(current_package.name, exist_ok=True)
    let hatch_path = py_path(current_package.name) / "pyproject.toml"
    with open(String(hatch_path), "w") as f:
        f.write("[build-system]\nrequires = [\"hatchling\"]\nbuild-backend = \"hatchling.build\"\n\n[project]\nname = \"" + current_package.name + "\"\nversion = \"" + current_package.version + "\"\n")
    print("Pure Hatch project initialized")

fn hatch_build():
    print("Pure Hatch build (no external Hatch)...")
    # Since pure, just compile and package
    package_build()
    print("Pure Hatch build completed"))