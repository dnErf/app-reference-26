"""
Basic Job Scheduler Demo for PL-GRIZZLY

A simple demonstration of cron-based job scheduling.
"""

from collections import Dict, List
from python import Python
from cron_evaluator import evaluate_cron, get_next_run_time

fn main() raises:
    """Demonstrate basic job scheduling."""
    print("PL-GRIZZLY Job Scheduler Demo")
    print("=============================")

    # Create a simple job scheduler instance
    var scheduler = JobScheduler()

    # Add some demo jobs
    var job1 = ScheduledJob("backup_db", "* * * * *", "procedure", "backup_database")
    var job2 = ScheduledJob("cleanup_logs", "0 * * * *", "procedure", "cleanup_old_logs")

    scheduler.add_job(job1)
    scheduler.add_job(job2)

    print("Added jobs:")
    var job_names = scheduler.list_jobs()
    for i in range(len(job_names)):
        print(" -", job_names[i])

    # Start the scheduler
    scheduler.start()

    # Simulate checking for jobs to run
    print("\nChecking for jobs to run...")
    scheduler.check_and_execute_jobs()

    print("Demo completed successfully!")

struct ScheduledJob(Copyable, Movable):
    """Represents a scheduled job."""
    var name: String
    var cron_expression: String
    var execution_type: String  # "procedure" or "pipeline"
    var call_target: String
    var enabled: Bool
    var status: String  # "pending", "running", "completed", "failed"
    var next_run: Float64
    var last_run: Float64
    var retry_count: Int
    var max_retries: Int

    fn __init__(out self, name: String, cron_expression: String, execution_type: String, call_target: String) raises:
        self.name = name
        self.cron_expression = cron_expression
        self.execution_type = execution_type
        self.call_target = call_target
        self.enabled = True
        self.status = "pending"
        var next_run_dt = get_next_run_time(cron_expression, Python.import_module("datetime").datetime.now())
        self.next_run = Float64(next_run_dt.timestamp())
        self.last_run = 0.0
        self.retry_count = 0
        self.max_retries = 3

struct JobScheduler(Movable):
    """Manages scheduled job execution."""
    var jobs: Dict[String, ScheduledJob]
    var is_running: Bool

    fn __init__(out self):
        self.jobs = Dict[String, ScheduledJob]()
        self.is_running = False

    fn add_job(mut self, job: ScheduledJob) raises:
        """Add a job to the scheduler."""
        if job.name in self.jobs:
            raise Error("Job '" + job.name + "' already exists")
        self.jobs[job.name] = job.copy()
        print("Added job:", job.name)

    fn start(mut self) raises:
        """Start the job scheduler."""
        if self.is_running:
            return
        self.is_running = True
        print("Job scheduler started")

    fn stop(mut self):
        """Stop the job scheduler."""
        self.is_running = False
        print("Job scheduler stopped")

    fn check_and_execute_jobs(mut self) raises:
        """Check for jobs that need to execute and run them."""
        if not self.is_running:
            return

        var time_mod = Python.import_module("time")
        var now_timestamp = time_mod.time()

        print("Checking", len(self.jobs), "jobs at timestamp", now_timestamp)

        # Simple execution for demo - run all enabled jobs
        var job_names = List[String]()
        for name in self.jobs.keys():
            job_names.append(name)

        for i in range(len(job_names)):
            var job_name = job_names[i]
            var job = self.jobs[job_name].copy()

            if job.enabled and job.status != "running":
                print("Executing job:", job_name)
                self._execute_job(job_name)

    fn _execute_job(mut self, job_name: String) raises:
        """Execute a scheduled job."""
        print("Running job:", job_name)

        # Simple execution - just mark as completed
        var job = self.jobs[job_name].copy()
        job.status = "completed"
        job.last_run = Float64(Python.import_module("time").time())
        self.jobs[job_name] = job.copy()

        print("Job", job_name, "completed successfully")

    fn get_job_status(self, job_name: String) raises -> String:
        """Get the status of a job."""
        if job_name not in self.jobs:
            raise Error("Job '" + job_name + "' not found")
        return self.jobs[job_name].copy().status

    fn enable_job(mut self, job_name: String) raises -> Bool:
        """Enable a job."""
        if job_name not in self.jobs:
            return False
        var job = self.jobs[job_name].copy()
        job.enabled = True
        self.jobs[job_name] = job.copy()
        return True

    fn disable_job(mut self, job_name: String) raises -> Bool:
        """Disable a job."""
        if job_name not in self.jobs:
            return False
        var job = self.jobs[job_name].copy()
        job.enabled = False
        self.jobs[job_name] = job.copy()
        return True

    fn list_jobs(self) -> List[String]:
        """List all job names."""
        var job_names = List[String]()
        for name in self.jobs.keys():
            job_names.append(name)
        return job_names.copy()