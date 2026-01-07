#!/bin/bash

# Grizzly Database Launcher
# Double-click this file or run it from terminal to start the database demo

echo "=========================================="
echo "        Grizzly Database Demo"
echo "=========================================="
echo ""
echo "Starting the Grizzly columnar database..."
echo "This will show you how to interact with the database"
echo "just like SQLite or DuckDB!"
echo ""
echo "Press Enter to continue..."
read

# Check if we're in the right directory
if [ ! -f "./griz" ]; then
    echo "Error: griz executable not found in current directory"
    echo "Please make sure you're running this from the Grizzly database folder"
    echo ""
    echo "Press Enter to exit..."
    read
    exit 1
fi

# Run the demo
echo "Launching Grizzly Database REPL..."
echo ""
./griz

echo ""
echo "=========================================="
echo "        Demo Complete!"
echo "=========================================="
echo ""
echo "The Grizzly database successfully demonstrated:"
echo "• Loading sample data (Alice, Bob, Charlie)"
echo "• Running SQL-like queries"
echo "• Columnar data processing"
echo ""
echo "This is a high-performance database built with Mojo,"
echo "similar to modern analytical databases like DuckDB."
echo ""
echo "Press Enter to exit..."
read