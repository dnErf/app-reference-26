"""
Enhanced CLI Interface for Godi
================================

Provides rich CLI features for the PL-GRIZZLY language.
"""

from python import Python, PythonObject
from collections import List

struct EnhancedConsole(Copyable):
    """Enhanced console with rich formatting."""
    
    var console: PythonObject
    var progress: PythonObject
    var completer: PythonObject
    var has_prompt_toolkit: Bool
    
    fn __init__(out self) raises:
        """Initialize the enhanced console."""
        var rich = Python.import_module("rich.console")
        var rich_progress = Python.import_module("rich.progress")
        
        self.console = rich.Console()
        self.progress = rich_progress.Progress(
            rich_progress.TextColumn("[bold blue]{task.description}", justify="right"),
            rich_progress.BarColumn(bar_width=None),
            "[progress.percentage]{task.percentage:>3.1f}%",
            "•",
            rich_progress.DownloadColumn(),
            "•",
            rich_progress.TransferSpeedColumn(),
            "•",
            rich_progress.TimeRemainingColumn(),
        )
        
        # Try to initialize prompt_toolkit, but make it optional
        self.has_prompt_toolkit = False
        try:
            var prompt_toolkit = Python.import_module("prompt_toolkit")
            self.completer = prompt_toolkit.completion.WordCompleter([])
            self.has_prompt_toolkit = True
        except:
            # Fallback: create a dummy completer
            self.completer = PythonObject()
    
    fn __copyinit__(out self, other: EnhancedConsole):
        """Copy constructor for EnhancedConsole."""
        self.console = other.console
        self.progress = other.progress
        self.completer = other.completer
        self.has_prompt_toolkit = other.has_prompt_toolkit
    
    fn print(self, text: String, style: String = "") raises:
        """Print text with optional rich styling."""
        if style == "":
            self.console.print(text)
        else:
            self.console.print(text, style=style)
    
    fn print_success(self, text: String) raises:
        """Print success message."""
        self.console.print("✓ " + text, style="green")
    
    fn print_error(self, text: String) raises:
        """Print error message."""
        self.console.print("✗ " + text, style="red")
    
    fn print_warning(self, text: String) raises:
        """Print warning message."""
        self.console.print("⚠ " + text, style="yellow")
    
    fn print_info(self, text: String) raises:
        """Print info message."""
        self.console.print("ℹ " + text, style="blue")
    
    fn input(self, prompt: String = "> ") raises -> String:
        """Get input from user with completion."""
        if self.has_prompt_toolkit:
            var prompt_toolkit = Python.import_module("prompt_toolkit")
            var session = prompt_toolkit.PromptSession(completer=self.completer)
            try:
                var result = session.prompt(prompt)
                return String(result)
            except KeyboardInterrupt:
                return "quit"
        else:
            # Fallback to basic input
            try:
                print(prompt, end="")
                var result = input()
                return result
            except KeyboardInterrupt:
                return "quit"
    
    fn update_completer_context(mut self, table_names: List[String], function_names: List[String]) raises:
        """Update the completer with current context."""
        var words = List[String]()
        
        # Add SQL keywords
        words.append("SELECT")
        words.append("FROM")
        words.append("WHERE")
        words.append("INSERT")
        words.append("UPDATE")
        words.append("DELETE")
        words.append("CREATE")
        words.append("TABLE")
        words.append("INDEX")
        words.append("DROP")
        words.append("ALTER")
        words.append("SHOW")
        words.append("DESCRIBE")
        words.append("USE")
        words.append("TYPE")
        words.append("SECRET")
        words.append("WITH")
        words.append("AS")
        
        # Add table names
        for table in table_names:
            words.append(table)
        
        # Add function names
        for func in function_names:
            words.append(func)
        
        # Add REPL commands
        words.append("help")
        words.append("quit")
        words.append("exit")
        words.append("status")
        words.append("show")
        words.append("tables")
        words.append("databases")
        words.append("schema")
        words.append("describe")
        words.append("create")
        words.append("insert")
        words.append("select")
        words.append("use")
        
        # Convert to Python list
        var py_words = Python.list()
        for word in words:
            py_words.append(word)
        
        if self.has_prompt_toolkit:
            var prompt_toolkit = Python.import_module("prompt_toolkit")
            self.completer = prompt_toolkit.completion.WordCompleter(py_words)
    
    fn create_progress_task(self, description: String, total: Int64 = 100) raises -> PythonObject:
        """Create a progress task."""
        return self.progress.add_task(description, total=total)
    
    fn update_progress(self, task_id: PythonObject, advance: Int64 = 1) raises:
        """Update progress for a task."""
        self.progress.update(task_id, advance=advance)
    
    fn start_progress(self) raises:
        """Start the progress display."""
        self.progress.start()
    
    fn stop_progress(self) raises:
        """Stop the progress display."""
        self.progress.stop()
    
    fn print_table(self, headers: List[String], rows: List[List[String]]) raises:
        """Print a formatted table."""
        var rich_table = Python.import_module("rich.table")
        var table = rich_table.Table()
        
        for header in headers:
            table.add_column(header, style="cyan", no_wrap=True)
        
        for row in rows:
            var py_row = Python.list()
            for cell in row:
                py_row.append(cell)
            table.add_row(py_row)
        
        self.console.print(table)
    
    fn print_panel(self, content: String, title: String = "", border_style: String = "blue") raises:
        """Print content in a panel."""
        var rich_panel = Python.import_module("rich.panel")
        var panel = rich_panel.Panel(content, title=title, border_style=border_style)
        self.console.print(panel)
    
    fn print_rule(self, title: String = "", style: String = "blue") raises:
        """Print a horizontal rule."""
        var rich_rule = Python.import_module("rich.rule")
        var rule = rich_rule.Rule(title=title, style=style)
        self.console.print(rule)

fn create_enhanced_console() raises -> EnhancedConsole:
    """Factory function to create an enhanced console."""
    return EnhancedConsole()