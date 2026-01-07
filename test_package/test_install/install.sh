#!/bin/bash
# Grizzly Database Simple Installer
# Run this script to set up Grizzly Database on your system

echo "🐻 Welcome to Grizzly Database Installer!"
echo ""
echo "This will install Grizzly Database on your system."
echo "Grizzly is a high-performance columnar database built with Mojo."
echo ""

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Cygwin;;
    MINGW*)     MACHINE=MinGW;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "Detected OS: ${MACHINE}"
echo ""

# Create installation directory
INSTALL_DIR="$HOME/.grizzly"
echo "Installing to: ${INSTALL_DIR}"

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
if [ -d "$HOME/Desktop" ] && [ "${MACHINE}" = "Linux" ]; then
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

    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
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
