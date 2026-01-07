# Profiling Tools for Mojo Grizzly
# Hotspot analysis

import time

fn timeit(func: fn() -> None) -> fn() -> None:
    fn wrapper():
        let start = time.now()
        func()
        let end = time.now()
        print("Function", func.__name__, "took", end - start, "seconds")
    return wrapper

struct MemoryProfiler:
    var allocations: Int
    var total_bytes: Int

    fn __init__(out self):
        self.allocations = 0
        self.total_bytes = 0

    fn track_alloc(mut self, bytes: Int):
        self.allocations += 1
        self.total_bytes += bytes

    fn report(self):
        print("Memory Usage: ", self.allocations, "allocations,", self.total_bytes, "bytes")

struct Profiler:
    var start_time: Float64
    var events: List[String]
    var mem_prof: MemoryProfiler

    fn __init__(out self):
        self.start_time = time.now()
        self.events = List[String]()
        self.mem_prof = MemoryProfiler()

    fn mark(inout self, event: String):
        let now = time.now()
        let elapsed = now - self.start_time
        self.events.append(event + ": " + str(elapsed) + "s")

    fn track_memory(mut self, bytes: Int):
        self.mem_prof.track_alloc(bytes)

    fn report(self):
        print("Profile Report:")
        for e in self.events:
            print(e)
        self.mem_prof.report()