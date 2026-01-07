# Simple Packaging Test for Mojo Grizzly
from python import Python

fn main() raises:
    print("Testing packaging for Mojo Grizzly...")
    
    # Use shell commands for simplicity
    var py_subprocess = Python.import_module("subprocess")
    
    var package_name = "mojo-grizzly-share"
    var version = "1.0.0"
    
    # Create package directory
    py_subprocess.run(["mkdir", "-p", package_name])
    
    # Copy main files
    py_subprocess.run(["cp", "main.mojo", package_name + "/"])
    py_subprocess.run(["cp", "README.md", package_name + "/"])
    
    # Create a simple run script
    var run_script = "#!/bin/bash\necho 'Run with: mojo run main.mojo'\n"
    var file = open(package_name + "/run.sh", "w")
    file.write(run_script)
    file.close()
    py_subprocess.run(["chmod", "+x", package_name + "/run.sh"])
    
    # Create zip archive
    var zip_name = package_name + "-" + version + ".zip"
    py_subprocess.run(["zip", "-r", zip_name, package_name])
    
    print("Package created:", zip_name)
    print("To share, distribute the zip file. Users can extract and run with 'mojo run main.mojo'")