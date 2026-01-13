"""
Enhanced CLI Interface for Godi
================================

Provides rich CLI features for the PL-GRIZZLY language.
"""

from python import Python, PythonObject
from collections import List

struct EnhancedConsole:
    """Enhanced console with rich formatting."""
    
    var console: PythonObject
    
    fn __init__(out self) raises:
        """Initialize the enhanced console."""
        var rich = Python.import_module("rich.console")
        self.console = rich.Console()
    
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
        """Get input from user."""
        return String(self.console.input(prompt))

fn create_enhanced_console() raises -> EnhancedConsole:
    """Factory function to create an enhanced console."""
    return EnhancedConsole()