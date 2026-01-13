from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from pl_grizzly_interpreter import PLGrizzlyInterpreter
from blob_storage import BlobStorage
from schema_manager import SchemaManager
from index_storage import IndexStorage
from orc_storage import ORCStorage

fn main() raises:
    print("🔍 Debug MATCH Expression Test")
    print("=" * 40)

    # Initialize minimal storage for interpreter
    var storage = BlobStorage(".")
    var schema_manager = SchemaManager(storage)
    var index_storage = IndexStorage(storage)
    var bloom_cols = List[String]()
    bloom_cols.append("id")
    bloom_cols.append("category")
    var orc_storage = ORCStorage(storage^, schema_manager^, index_storage^, "none", True, 10000, 65536, bloom_cols^)
    var interpreter = PLGrizzlyInterpreter(orc_storage^)

    # Test just one case
    var sql = '42 MATCH { 42 -> "Answer", 24 -> "Half", _ -> "Other" }'
    print("Testing: " + sql)

    try:
        var result = interpreter.interpret(sql)
        print("Result: " + result.__str__())
    except e:
        print("Error: " + String(e))

    print("Debug test completed")