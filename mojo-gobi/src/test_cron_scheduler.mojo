# Minimal test for Cron Scheduler functionality
from root_storage import RootStorage
from job_scheduler import JobScheduler
from collections import List

fn main() raises:
    print("Testing Cron Scheduler functionality...")

    # Create root storage
    var root = RootStorage(".gobi")
    print("RootStorage created")

    # Create job scheduler
    var scheduler = JobScheduler(root)
    print("JobScheduler created")

    # Test basic scheduler operations
    print("Testing scheduler operations...")

    # List jobs (should be empty initially)
    var job_names = scheduler.list_jobs()
    print("Found", len(job_names), "jobs initially")

    # Create a test schedule using RootStorage
    var success = root.store_schedule(
        "test_job",
        "*/5 * * * *",  # Every 5 minutes
        "procedure",    # execution type
        "echo 'Test job executed'"  # call target
    )
    print("Created schedule, success:", success)

    # Load schedules into scheduler
    scheduler.load_schedules()
    print("Loaded schedules into scheduler")

    # List jobs again
    job_names = scheduler.list_jobs()
    print("Now found", len(job_names), "jobs")

    # Get job status
    if len(job_names) > 0:
        var status = scheduler.get_job_status(job_names[0])
        print("Job status:", status)

        # Test history (should be empty)
        var history = scheduler.get_execution_history(job_names[0])
        print("Job history:", len(history), "entries")

        # Try manual execution
        var executed = scheduler.manual_execute_job(job_names[0])
        print("Manual execution result:", executed)

        # Check history again
        history = scheduler.get_execution_history(job_names[0])
        print("Job history after execution:", len(history), "entries")

    print("Cron Scheduler basic functionality test completed successfully!")