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

struct Profiler:
    var start_time: Float64
    var events: List[String]

    fn __init__(out self):
        self.start_time = time.now()
        self.events = List[String]()

    fn mark(inout self, event: String):
        let now = time.now()
        let elapsed = now - self.start_time
        self.events.append(event + ": " + str(elapsed) + "s")

    fn report(self):
        print("Profile Report:")
        for e in self.events:
            print(e)