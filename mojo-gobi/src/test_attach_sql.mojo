from pl_grizzly_interpreter import PLGrizzlyInterpreter
from orc_storage import ORCStorage
from blob_storage import BlobStorage
from schema_manager import SchemaManager
from index_storage import IndexStorage

fn main() raises:
    # Initialize storage
    var storage = BlobStorage("../test_db")
    var schema_manager = SchemaManager(storage)
    var index_storage = IndexStorage(storage)

    var bloom_cols = List[String]()
    bloom_cols.append("id")
    var orc_storage = ORCStorage(storage^, schema_manager^, index_storage^, "none", True, 10000, 65536, bloom_cols^)

    var interpreter = PLGrizzlyInterpreter(orc_storage^)

    # Test ATTACH SQL file directly on schema_manager
    print("Testing direct schema_manager attach...")
    var success = interpreter.orc_storage.schema_manager.attach_sql_file("my_script", "test_script.sql")
    print("Direct attach success:", success)

    # Check attached SQL files
    var attached_sqls = interpreter.orc_storage.schema_manager.list_attached_sql_files()
    print("Number of attached SQL files after direct attach:", len(attached_sqls))

    # Test EXECUTE
    print("Testing EXECUTE SQL file...")
    var execute_result = interpreter.interpret("EXECUTE my_script")
    print("EXECUTE result:", execute_result.__str__())

    print("Test completed!")