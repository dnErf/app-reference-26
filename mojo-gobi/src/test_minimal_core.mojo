"""
Minimal test to isolate compilation issues - Core modules only
"""

from blob_storage import BlobStorage
from schema_manager import SchemaManager
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from pl_grizzly_values import PLValue

fn main():
    print("Core modules imported successfully")