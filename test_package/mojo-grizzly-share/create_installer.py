#!/usr/bin/env python3
"""
Grizzly Database Packager
Creates a user-friendly installer package for non-technical users
"""

import os
import shutil
import zipfile
import platform
from pathlib import Path

def create_installer_package():
    """Create a user-friendly installer package"""

    print("🔧 Creating Grizzly Database Installer Package...")

    # Get current directory
    source_dir = Path("/home/lnx/Dev/app-reference-26/test_package/mojo-grizzly-share")
    installer_dir = source_dir.parent / "Grizzly_Installer"

    # Create installer directory
    installer_dir.mkdir(exist_ok=True)

    # Copy essential files
    essential_files = [
        'griz',  # The executable
        'run_grizzly.sh',  # Linux launcher
        'run_grizzly.bat',  # Windows launcher
        'README.md',
        'README_SHARE.txt'
    ]

    print("📋 Copying essential files...")
    for file in essential_files:
        src = source_dir / file
        if src.exists():
            shutil.copy2(src, installer_dir / file)
            print(f"  ✓ {file}")

    # Create a simple installer script
    installer_script = f"""#!/bin/bash
# Grizzly Database Simple Installer
# Run this script to set up Grizzly Database on your system

echo "🐻 Welcome to Grizzly Database Installer!"
echo ""
echo "This will install Grizzly Database on your system."
echo "Grizzly is a high-performance columnar database built with Mojo."
echo ""

# Detect OS
OS="$(uname -s)"
case "${{OS}}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Cygwin;;
    MINGW*)     MACHINE=MinGW;;
    *)          MACHINE="UNKNOWN:${{OS}}"
esac

echo "Detected OS: ${{MACHINE}}"
echo ""

# Create installation directory
INSTALL_DIR="$HOME/.grizzly"
echo "Installing to: ${{INSTALL_DIR}}"

if [ -d "$INSTALL_DIR" ]; then
    echo "Previous installation found. Removing..."
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying database files..."
cp -r * "$INSTALL_DIR/"

# Make executable
chmod +x "$INSTALL_DIR/griz"
chmod +x "$INSTALL_DIR/run_grizzly.sh"

# Create desktop shortcut (if on Linux with desktop)
if [ -d "$HOME/Desktop" ] && [ "${{MACHINE}}" = "Linux" ]; then
    echo "Creating desktop shortcut..."
    cat > "$HOME/Desktop/Grizzly Database.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Grizzly Database
Comment=High-performance columnar database
Exec=$INSTALL_DIR/run_grizzly.sh
Icon=$INSTALL_DIR/griz
Terminal=true
Categories=Development;Database;
EOF
    chmod +x "$HOME/Desktop/Grizzly Database.desktop"
fi

# Add to PATH (optional)
echo ""
echo "Would you like to add Grizzly to your PATH? (y/n)"
read -r ADD_TO_PATH
if [ "$ADD_TO_PATH" = "y" ] || [ "$ADD_TO_PATH" = "Y" ]; then
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi

    echo "export PATH=\\"$INSTALL_DIR:\\$PATH\\"" >> "$SHELL_RC"
    echo "Added Grizzly to PATH in $SHELL_RC"
    echo "Please restart your terminal or run: source $SHELL_RC"
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "To run Grizzly Database:"
echo "  Double-click: run_grizzly.sh (Linux/Mac)"
echo "  Or run: $INSTALL_DIR/run_grizzly.sh"
echo "  Or run: grizzly (if added to PATH)"
echo ""
echo "Enjoy exploring your new columnar database! 🚀"
"""

    with open(installer_dir / "install.sh", 'w') as f:
        f.write(installer_script)

    # Make installer executable
    os.chmod(installer_dir / "install.sh", 0o755)

    # Create a README for the installer
    installer_readme = """# Grizzly Database Installer

## For Non-Technical Users

Welcome! This package contains Grizzly Database, a high-performance columnar database built with Mojo.

## Quick Start

### Option 1: Double-Click Installation (Recommended)
1. **Run the installer**: Double-click `install.sh`
2. **Follow the prompts**: The installer will guide you through setup
3. **Launch the database**: Use the desktop shortcut or run `run_grizzly.sh`

### Option 2: Manual Installation
1. **Run the launcher**: Double-click `run_grizzly.sh` (Linux/Mac) or `run_grizzly.bat` (Windows)
2. **Explore the demo**: See how the database works with sample data

## What You'll See

The demo will show you:
- Loading sample data (Alice, Bob, Charlie)
- Running SQL-like queries
- Columnar data processing capabilities

## System Requirements

- Linux, macOS, or Windows
- No additional software installation required!

## Files Included

- `griz` - The database executable
- `run_grizzly.sh` - Linux/Mac launcher
- `run_grizzly.bat` - Windows launcher
- `install.sh` - Automated installer
- `README.md` - Full documentation

## Need Help?

The database comes with built-in help. Just run it and type `HELP` at the prompt!

---
Built with ❤️ using Mojo programming language
"""

    with open(installer_dir / "INSTALL_README.md", 'w') as f:
        f.write(installer_readme)

    # Create a zip package
    zip_path = source_dir.parent / "Grizzly_Database_Installer.zip"
    print("📦 Creating installer package...")

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for file_path in installer_dir.rglob('*'):
            if file_path.is_file():
                arcname = file_path.relative_to(installer_dir)
                zipf.write(file_path, arcname)
                print(f"  ✓ {arcname}")

    print("\n✅ Installer package created successfully!")
    print(f"📁 Location: {zip_path}")
    print(f"📏 Size: {zip_path.stat().st_size / (1024*1024):.1f} MB")
    print("")
    print("🎯 User Instructions:")
    print("1. Unzip the installer package")
    print("2. Double-click 'install.sh' to install")
    print("3. Or double-click 'run_grizzly.sh' to try immediately")
    print("")
    print("🚀 Ready for non-technical users!")

if __name__ == "__main__":
    create_installer_package()