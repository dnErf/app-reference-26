"""
Threading Examples in Mojo

This file demonstrates basic threading patterns in Mojo using Python's threading module.
"""

from python import Python

def thread_work(duration: Float16):
    print("thread starting work for", duration, " seconds")
    

fn main() raises:
    print("=== Threading Examples in Mojo ===\n")

    # Import threading module
    var threading = Python.import_module("threading")
    var time = Python.import_module("time")

    # Example 1: Basic Thread Creation
    print("1. Basic Thread Creation")
    print("Creating and starting threads...")

    # Create threads using Python directly
    var py_code = """
import threading
import time

def thread_work(duration):
    print('Thread starting work for', duration, 'seconds')
    time.sleep(duration)
    print('Thread finished work')

# Create and start threads
t1 = threading.Thread(target=thread_work, args=(1.0,))
t2 = threading.Thread(target=thread_work, args=(0.5,))
t1.start()
t2.start()
t1.join()
t2.join()
print('All threads completed!')
"""
    Python.evaluate("exec('''" + py_code + "''')")

    # Example 2: Thread with custom function
    print("2. Thread with Custom Function")

    var worker_code = """
import threading
import time

def worker_task():
    print('Worker thread: starting')
    time.sleep(0.8)
    print('Worker thread: done')

# Create and run worker thread
worker = threading.Thread(target=worker_task)
worker.start()
worker.join()
print('Custom function thread completed!')
"""
    Python.evaluate("exec('''" + worker_code + "''')")

    print("=== Threading Examples Complete ===")