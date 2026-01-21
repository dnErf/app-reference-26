"""
Direct Mojo B+ Tree - Calls Mojo without Python fallback.

This module directly uses the Mojo B+ Tree implementation for high-performance
operations. No Python fallback is used.
"""

import sys
import os


def _compile_mojo_module():
    """Compile the Mojo module if needed"""
    import subprocess
    
    mojo_file = os.path.join(os.path.dirname(__file__), "bplus_tree_mojo.mojo")
    
    if os.path.exists(mojo_file):
        try:
            print(f"[Mojo] Compiling {mojo_file}...")
            result = subprocess.run(
                ["mojo", "compile", mojo_file, "-o", "bplus_tree_mojo.so"],
                cwd=os.path.dirname(__file__),
                capture_output=True,
                text=True,
                timeout=30
            )
            if result.returncode == 0:
                print("[Mojo] Compilation successful!")
                return True
            else:
                print(f"[Mojo] Compilation error: {result.stderr}")
                return False
        except Exception as e:
            print(f"[Mojo] Compilation failed: {e}")
            return False
    return False


# Try to import compiled Mojo module
try:
    sys.path.insert(0, os.path.dirname(__file__))
    from bplus_tree_mojo import MojoBPlusTree as MojoNativeBPlusTree
    print("[Mojo] Successfully imported compiled Mojo module!")
    MOJO_COMPILED = True
except ImportError as e:
    print(f"[Mojo] Import failed: {e}")
    print("[Mojo] Attempting to compile Mojo module...")
    if _compile_mojo_module():
        try:
            from bplus_tree_mojo import MojoBPlusTree as MojoNativeBPlusTree
            print("[Mojo] Successfully imported compiled Mojo module!")
            MOJO_COMPILED = True
        except ImportError:
            MOJO_COMPILED = False
    else:
        MOJO_COMPILED = False

if not MOJO_COMPILED:
    raise ImportError(
        "Failed to load Mojo B+ Tree module. Please ensure Mojo is installed and available.\n"
        "Install Mojo: https://docs.modular.com/mojo/manual/get-started"
    )


class MojoBPlusTree:
    """Direct wrapper around Mojo B+ Tree - no fallback"""
    
    def __init__(self, max_keys: int = 3):
        """Initialize with Mojo B+ Tree"""
        print(f"[Mojo] Creating MojoBPlusTree with max_keys={max_keys}")
        self._tree = MojoNativeBPlusTree(max_keys)
        self._max_keys = max_keys
    
    def search(self, key: str) -> str:
        """Search for a value - calls Mojo directly"""
        print(f"[Mojo] Searching for key: {key}")
        result = self._tree.search(key)
        print(f"[Mojo] Search result: {result if result else 'NOT FOUND'}")
        return result if result else None
    
    def insert(self, key: str, value: str) -> None:
        """Insert a key-value pair - calls Mojo directly"""
        print(f"[Mojo] Inserting: {key} -> {value}")
        self._tree.insert(str(key), str(value))
    
    def delete(self, key: str) -> bool:
        """Delete a key - calls Mojo directly"""
        print(f"[Mojo] Deleting key: {key}")
        result = self._tree.delete(str(key))
        print(f"[Mojo] Delete result: {result}")
        return result
    
    def bulk_insert(self, items: list) -> None:
        """Bulk insert - calls Mojo directly"""
        keys = [str(k) for k, v in items]
        values = [str(v) for k, v in items]
        print(f"[Mojo] Bulk inserting {len(items)} items")
        self._tree.bulk_insert(keys, values)
    
    def range_query(self, start_key: str, end_key: str) -> list:
        """Range query - calls Mojo directly"""
        print(f"[Mojo] Range query: [{start_key}, {end_key}]")
        results = self._tree.range_query(str(start_key), str(end_key))
        print(f"[Mojo] Found {len(results)} results")
        return results
    
    def get_all_keys(self) -> list:
        """Get all keys - calls Mojo directly"""
        print(f"[Mojo] Fetching all keys")
        return self._tree.get_all_keys()
    
    def get_all_values(self) -> list:
        """Get all values - calls Mojo directly"""
        print(f"[Mojo] Fetching all values")
        return self._tree.get_all_values()
    
    def get_stats(self) -> dict:
        """Get performance statistics from Mojo"""
        ops = self._tree.get_operation_count()
        return {
            "operations": ops,
            "max_keys": self._max_keys,
            "backend": "Mojo (Direct)",
        }
    
    def display(self) -> str:
        """Display tree information - calls Mojo directly"""
        print(f"[Mojo] Displaying tree information")
        return self._tree.display()
