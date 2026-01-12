"""
PL-GRIZZLY Profiling Module

Query profiling and performance monitoring for PL-GRIZZLY.
"""

from collections import Dict

# Query profiling data
struct QueryProfile(Copyable, Movable, ImplicitlyCopyable):
    var query: String
    var execution_count: Int
    var total_time: Float64
    var min_time: Float64
    var max_time: Float64
    var avg_time: Float64
    var last_executed: String

    fn __init__(out self, query: String):
        self.query = query
        self.execution_count = 0
        self.total_time = 0.0
        self.min_time = Float64.MAX
        self.max_time = 0.0
        self.avg_time = 0.0
        self.last_executed = ""

    fn __copyinit__(out self, other: QueryProfile):
        self.query = other.query
        self.execution_count = other.execution_count
        self.total_time = other.total_time
        self.min_time = other.min_time
        self.max_time = other.max_time
        self.avg_time = other.avg_time
        self.last_executed = other.last_executed

    fn record_execution(mut self, execution_time: Float64):
        self.execution_count += 1
        self.total_time += execution_time
        self.min_time = min(self.min_time, execution_time)
        self.max_time = max(self.max_time, execution_time)
        self.avg_time = self.total_time / Float64(self.execution_count)
        # self.last_executed = datetime.now().isoformat()  # Would need datetime import

# Profiling manager
struct ProfilingManager:
    var execution_counts: Dict[String, Int]
    var profiling_enabled: Bool

    fn __init__(out self):
        self.execution_counts = Dict[String, Int]()
        self.profiling_enabled = False

    fn enable_profiling(mut self):
        self.profiling_enabled = True

    fn disable_profiling(mut self):
        self.profiling_enabled = False

    fn record_function_call(mut self, func_name: String):
        if not self.profiling_enabled:
            return
        var count = self.execution_counts.get(func_name, 0)
        self.execution_counts[func_name] = count + 1

    fn get_profile_stats(self) -> Dict[String, Int]:
        return self.execution_counts.copy()