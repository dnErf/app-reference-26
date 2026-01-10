"""
Godi - Embedded Lakehouse Database
===================================

An embedded lakehouse database inspired by Apache Hudi and SQLMesh,
built with Mojo for high performance and memory safety.

Features:
- Merkle B+ Tree with SHA-256 integrity verification
- Universal compaction strategy
- PyArrow ORC columnar storage
- BLOB storage abstraction
- Rich CLI interface
- Pack/unpack .gobi format
"""

from python import Python, PythonObject
from collections import List
from sys import argv
from blob_storage import BlobStorage
from merkle_tree import MerkleBPlusTree
from schema_manager import SchemaManager, DatabaseSchema, TableSchema, Column
from orc_storage import ORCStorage

# Import required Python modules
fn initialize_python_modules() raises:
    """Initialize Python modules for interop."""
    Python.add_to_path(".")
    # Rich will be imported as needed

# Main entry point
fn main() raises:
    """Main entry point for Godi CLI."""
    initialize_python_modules()

    var rich_console = Python.import_module("rich.console").Console()
    rich_console.print("[bold blue]Godi - Embedded Lakehouse Database[/bold blue]")
    rich_console.print("=" * 50)

    # Parse command line arguments
    var args = argv()

    if len(args) < 2:
        print_usage(rich_console)
        return

    var command = String(args[1])

    if command == "init":
        if len(args) < 3:
            rich_console.print("[red]Error: init requires a folder path[/red]")
            return
        initialize_database(String(args[2]), rich_console)
    elif command == "repl":
        start_repl(rich_console)
    elif command == "pack":
        if len(args) < 3:
            rich_console.print("[red]Error: pack requires a folder path[/red]")
            return
        pack_database(String(args[2]), rich_console)
    elif command == "unpack":
        if len(args) < 3:
            rich_console.print("[red]Error: unpack requires a .gobi file path[/red]")
            return
        unpack_database(String(args[2]), rich_console)
    else:
        rich_console.print("[red]Unknown command: " + command + "[/red]")
        print_usage(rich_console)

fn print_usage(rich_console: PythonObject) raises:
    """Print CLI usage information."""
    rich_console.print("[yellow]Usage:[/yellow]")
    rich_console.print("  gobi init <folder>    - Initialize database in folder")
    rich_console.print("  gobi repl             - Start interactive REPL")
    rich_console.print("  gobi pack <folder>    - Pack folder into .gobi file")
    rich_console.print("  gobi unpack <file>    - Unpack .gobi file to folder")

fn initialize_database(folder: String, rich_console: PythonObject) raises:
    """Initialize a new Godi database in the specified folder."""
    rich_console.print("[green]Initializing Godi database in: " + folder + "[/green]")

    var storage = BlobStorage(folder)
    var schema_manager = SchemaManager(storage)

    # Create default schema
    var schema = DatabaseSchema("godi_db")
    var success = schema_manager.save_schema(schema)

    if success:
        rich_console.print("[green]Database initialized successfully![/green]")
    else:
        rich_console.print("[red]Failed to initialize database[/red]")

fn start_repl(rich_console: PythonObject) raises:
    """Start the interactive REPL."""
    rich_console.print("[blue]Starting Godi REPL...[/blue]")
    rich_console.print("[dim]Type 'help' for commands, 'quit' to exit[/dim]")

    # Simple REPL loop (in real implementation, use proper async/event loop)
    var running = True
    while running:
        var prompt = rich_console.input("[bold cyan]godi> [/bold cyan]")
        var cmd = String(prompt)

        if cmd == "quit" or cmd == "exit":
            running = False
            rich_console.print("[yellow]Goodbye![/yellow]")
        elif cmd == "help":
            rich_console.print("[yellow]Available commands:[/yellow]")
            rich_console.print("  help    - Show this help")
            rich_console.print("  quit    - Exit REPL")
            rich_console.print("  status  - Show database status")
        elif cmd == "status":
            rich_console.print("[green]Database status: Operational[/green]")
        else:
            rich_console.print("[red]Unknown command: " + cmd + "[/red]")

fn pack_database(folder: String, rich_console: PythonObject) raises:
    """Pack database folder into a .gobi file."""
    rich_console.print("[green]Packing database from: " + folder + "[/green]")
    # TODO: Implement packing logic with compression
    rich_console.print("[yellow]Packing not yet implemented[/yellow]")

fn unpack_database(file_path: String, rich_console: PythonObject) raises:
    """Unpack .gobi file to folder structure."""
    rich_console.print("[green]Unpacking database from: " + file_path + "[/green]")
    # TODO: Implement unpacking logic
    rich_console.print("[yellow]Unpacking not yet implemented[/yellow]")