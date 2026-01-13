from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_parser import PLGrizzlyParser
from pl_grizzly_interpreter import PLGrizzlyInterpreter
from blob_storage import BlobStorage
from schema_manager import SchemaManager
from index_storage import IndexStorage
from orc_storage import ORCStorage

fn main() raises:
    print("🧪 Comprehensive MATCH Expression Testing")
    print("==================================================")

    # Initialize minimal storage for interpreter
    var storage = BlobStorage(".")
    var schema_manager = SchemaManager(storage)
    var index_storage = IndexStorage(storage)
    var bloom_cols = List[String]()
    bloom_cols.append("id")
    bloom_cols.append("category")
    var orc_storage = ORCStorage(storage^, schema_manager^, index_storage^, "none", True, 10000, 65536, bloom_cols^)
    var interpreter = PLGrizzlyInterpreter(orc_storage^)

    # Test cases for MATCH expressions
    var test_cases = List[String]()
    test_cases.append('"premium" MATCH { "premium" -> "VIP", "basic" -> "Standard", _ -> "Unknown" }')
    test_cases.append('"basic" MATCH { "premium" -> "VIP", "basic" -> "Standard", _ -> "Unknown" }')
    test_cases.append('"gold" MATCH { "premium" -> "VIP", "basic" -> "Standard", _ -> "Unknown" }')
    test_cases.append('42 MATCH { 42 -> "Answer", 24 -> "Half", _ -> "Other" }')
    test_cases.append('99 MATCH { 42 -> "Answer", 24 -> "Half", _ -> "Other" }')

    for i in range(len(test_cases)):
        var sql = test_cases[i]
        print("\n🧪 Test Case " + String(i+1) + ": " + sql)
        print("-" * 40)

        try:
            # Test tokenization
            var lexer = PLGrizzlyLexer(sql)
            var tokens = lexer.tokenize()
            print("✅ Tokenization successful")

            # Test parsing
            var parser = PLGrizzlyParser(tokens)
            var ast = parser.parse()
            print("✅ Parsing successful")
            print("   AST Type: " + ast.node_type)
            print("   Children: " + String(len(ast.children)))

            # Test interpretation
            var result = interpreter.interpret(sql)
            print("✅ Interpretation successful")
            print("   Result: " + result.__str__())

            # Validate result based on expected outcomes
            if i == 0:  # "premium" -> "VIP"
                if result.value == "VIP":
                    print("✅ Result matches expected: VIP")
                else:
                    print("❌ Expected 'VIP', got '" + result.value + "'")
            elif i == 1:  # "basic" -> "Standard"
                if result.value == "Standard":
                    print("✅ Result matches expected: Standard")
                else:
                    print("❌ Expected 'Standard', got '" + result.value + "'")
            elif i == 2:  # "gold" -> "Unknown" (wildcard)
                if result.value == "Unknown":
                    print("✅ Result matches expected: Unknown (wildcard)")
                else:
                    print("❌ Expected 'Unknown', got '" + result.value + "'")
            elif i == 3:  # 42 -> "Answer"
                if result.value == "Answer":
                    print("✅ Result matches expected: Answer")
                else:
                    print("❌ Expected 'Answer', got '" + result.value + "'")
            elif i == 4:  # 99 -> "Other" (wildcard)
                if result.value == "Other":
                    print("✅ Result matches expected: Other (wildcard)")
                else:
                    print("❌ Expected 'Other', got '" + result.value + "'")

        except e:
            print("❌ Test failed with error: " + String(e))

    print("\n🎉 MATCH Expression Testing Completed!")
    print("==================================================")
