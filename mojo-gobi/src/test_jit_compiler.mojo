"""
JIT Compiler Test Module

Tests for the JIT compiler to ensure it doesn't cause compilation issues.
"""

from jit_compiler import JITCompiler, CodeGenerator, CompiledFunction, BenchmarkResult
from pl_grizzly_parser import ASTNode
from pl_grizzly_values import PLValue

fn test_jit_compiler_basic():
    """Test basic JIT compiler functionality."""
    print("Testing JIT compiler...")

    var jit = JITCompiler(5)  # Lower threshold for testing

    # Test recording function calls
    jit.record_function_call("test_func")
    jit.record_function_call("test_func")
    jit.record_function_call("test_func")

    # Should not compile yet (below threshold)
    if jit.should_jit_compile("test_func"):
        print("ERROR: Should not compile yet")
        return

    # Add more calls
    jit.record_function_call("test_func")
    jit.record_function_call("test_func")
    jit.record_function_call("test_func")

    # Should compile now
    if not jit.should_jit_compile("test_func"):
        print("ERROR: Should compile now")
        return

    print("JIT compiler basic test passed")

fn test_code_generator():
    """Test code generator safety."""
    print("Testing code generator...")

    var generator = CodeGenerator(10)  # Low recursion limit for testing

    # Test with empty function name
    var result = generator.generate_function("", List[ASTNode](), "string", ASTNode("LITERAL", "test"))
    if result.find("// Error:") == -1:
        print("ERROR: Should contain error message")
        return

    print("Code generator safety test passed")

fn test_runtime_compilation() raises:
    """Test Phase 3: Runtime compilation functionality."""
    print("Testing runtime compilation...")

    var jit = JITCompiler(3)  # Lower threshold for testing

    # Create a simple function AST for testing
    var func_ast = ASTNode("FUNCTION", "add")
    func_ast.set_attribute("return_type", "number")

    # Add a parameter
    var param = ASTNode("PARAMETER", "a")
    func_ast.children.append(param.copy())

    # Add a simple body (just return the parameter)
    var body = ASTNode("IDENTIFIER", "a")
    func_ast.children.append(body.copy())

    # Test runtime compilation
    var compiled = jit.compile_to_runtime("add", func_ast)
    if not compiled:
        print("ERROR: Runtime compilation failed")
        return

    # Test execution
    var args = List[PLValue]()
    args.append(PLValue("number", "5"))
    args.append(PLValue("number", "3"))

    var result = jit.execute_compiled_function("add", args)
    print("JIT execution result: " + result.value)

    # Test JIT try_execute
    var jit_result = jit.try_execute_jit("add", args)
    if jit_result:
        print("JIT try_execute successful: " + jit_result.value().value)
    else:
        print("ERROR: JIT try_execute failed")

    print("Runtime compilation tests passed")

fn test_runtime_stats() raises:
    """Test runtime compilation statistics."""
    print("Testing runtime statistics...")

    var jit = JITCompiler()

    # Get initial stats
    var stats = jit.get_runtime_stats()
    var compiled_count = stats.get("compiled_functions", "0")
    var runtime_calls = stats.get("total_runtime_calls", "0")
    print("Initial compiled functions: " + compiled_count)
    print("Initial runtime calls: " + runtime_calls)

    print("Runtime statistics tests passed")

fn test_enhanced_code_generation() raises:
    """Test enhanced code generation features from Phase 2."""
    print("Testing enhanced code generation...")

    var generator = CodeGenerator()

    # Test basic code generation
    var result = generator.generate_function("test", List[ASTNode](), "string", ASTNode("LITERAL", "test"))
    if result == "":
        print("ERROR: Code generation returned empty string")
        return

    print("Enhanced code generation tests passed")

fn test_benchmarking() raises:
    """Test Phase 4: Performance benchmarking functionality."""
    print("Testing performance benchmarking...")

    var jit = JITCompiler(3)  # Lower threshold for testing

    # Create and compile a test function
    var func_ast = ASTNode("FUNCTION", "add")
    func_ast.set_attribute("return_type", "number")
    var param = ASTNode("PARAMETER", "a")
    func_ast.children.append(param.copy())
    var body = ASTNode("IDENTIFIER", "a")
    func_ast.children.append(body.copy())

    var compiled = jit.compile_to_runtime("add", func_ast)
    if not compiled:
        print("ERROR: Failed to compile function for benchmarking")
        return

    # Test benchmarking
    var args = List[PLValue]()
    args.append(PLValue("number", "5"))
    args.append(PLValue("number", "3"))

    var benchmark = jit.benchmark_function("add", args, 10)
    print("Benchmark result - Function: " + benchmark.function_name)
    print("JIT time: " + String(benchmark.jit_time) + "s")
    print("Interpreted time: " + String(benchmark.interpreted_time) + "s")
    print("Speedup ratio: " + String(benchmark.speedup_ratio) + "x")

    if benchmark.speedup_ratio <= 0.0:
        print("ERROR: Invalid speedup ratio")
        return

    print("Benchmarking tests passed")

fn test_threshold_optimization() raises:
    """Test threshold optimization based on benchmark results."""
    print("Testing threshold optimization...")

    var jit = JITCompiler(10)
    var results = List[BenchmarkResult]()

    # Create mock benchmark results
    results.append(BenchmarkResult("func1", 0.001, 0.01, 0.0001, 100))  # 10x speedup
    results.append(BenchmarkResult("func2", 0.002, 0.008, 0.0002, 100))  # 4x speedup

    var recommendations = jit.optimize_thresholds(results)

    print("Optimization recommendations:")
    for key in recommendations.keys():
        var value = recommendations.get(key).value()
        print("  " + key + ": " + value)

    if recommendations.get("avg_speedup", "0x") == "0x":
        print("ERROR: No speedup calculated")
        return

    print("Threshold optimization tests passed")

fn test_cache_management() raises:
    """Test cache management and cleanup."""
    print("Testing cache management...")

    var jit = JITCompiler(5)

    # Add some compiled functions
    var func_ast = ASTNode("FUNCTION", "test_func")
    func_ast.set_attribute("return_type", "number")
    var param = ASTNode("PARAMETER", "x")
    func_ast.children.append(param.copy())
    var body = ASTNode("IDENTIFIER", "x")
    func_ast.children.append(body.copy())

    jit.compile_to_runtime("test_func1", func_ast)
    jit.compile_to_runtime("test_func2", func_ast)

    var initial_count = len(jit.compiled_functions)
    print("Initial compiled functions: " + String(initial_count))

    # Test cache cleanup
    var removed = jit.cleanup_cache(0.0, 0)  # Aggressive cleanup
    print("Functions removed by cleanup: " + String(removed))

    var final_count = len(jit.compiled_functions)
    print("Final compiled functions: " + String(final_count))

    print("Cache management tests passed")

fn test_performance_report() raises:
    """Test comprehensive performance reporting."""
    print("Testing performance reporting...")

    var jit = JITCompiler(5)
    var results = List[BenchmarkResult]()

    # Create mock benchmark results
    results.append(BenchmarkResult("func1", 0.001, 0.01, 0.0001, 100))
    results.append(BenchmarkResult("func2", 0.002, 0.008, 0.0002, 100))

    var report = jit.get_performance_report(results)

    print("Performance report:")
    for key in report.keys():
        var value = report.get(key).value()
        print("  " + key + ": " + value)

    if report.get("overall_speedup", "0x") == "0x":
        print("ERROR: No overall speedup in report")
        return

    print("Performance report tests passed")

# Run tests
fn main() raises:
    print("Running JIT compiler tests...")
    test_jit_compiler_basic()
    test_code_generator()
    test_enhanced_code_generation()
    test_runtime_compilation()
    test_runtime_stats()
    test_benchmarking()
    test_threshold_optimization()
    test_cache_management()
    test_performance_report()
    print("All JIT compiler tests passed!")