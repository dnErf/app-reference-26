# Simple test of thread-safety components

struct SpinLock(Movable):
    var locked: Bool

    fn __init__(out self):
        self.locked = False

    fn acquire(mut self):
        while True:
            if not self.locked:
                self.locked = True
                break
            # Busy wait - in real implementation would yield or sleep

    fn release(mut self):
        self.locked = False

struct AtomicInt(Movable):
    var value: Int
    var lock: SpinLock

    fn __init__(out self):
        self.value = 0
        self.lock = SpinLock()

    fn __init__(out self, initial: Int):
        self.value = initial
        self.lock = SpinLock()

    fn load(mut self) -> Int:
        self.lock.acquire()
        var val = self.value
        self.lock.release()
        return val

    fn increment(mut self) -> Int:
        self.lock.acquire()
        self.value += 1
        var val = self.value
        self.lock.release()
        return val

    fn decrement(mut self) -> Int:
        self.lock.acquire()
        self.value -= 1
        var val = self.value
        self.lock.release()
        return val

    fn get(mut self) -> Int:
        return self.load()

fn main():
    print("Testing basic thread-safety...")
    
    var atomic = AtomicInt(10)
    print("Initial value:", atomic.get())
    _ = atomic.increment()
    print("After increment:", atomic.get())
    _ = atomic.decrement()
    print("After decrement:", atomic.get())
    
    var lock = SpinLock()
    lock.acquire()
    print("Lock acquired")
    lock.release()
    print("Lock released")
    
    print("Basic thread-safety test completed!")
