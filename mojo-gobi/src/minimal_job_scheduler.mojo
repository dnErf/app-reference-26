"""
Minimal Job Scheduler for PL-GRIZZLY

A simplified version that focuses on core scheduling functionality
without complex dependencies.
"""

from collections import Dict, List
from python import Python, PythonObject
from cron_evaluator import evaluate_cron, get_next_run_time

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
    var parameters: Dict[String, String]

    fn __init__(out self, name: String, cron_expression: String, execution_type: String, call_target: String) raises:
        self.name = name
        self.cron_expression = cron_expression
        self.execution_type = execution_type
        self.call_target = call_target
        self.enabled = True
        self.status = "pending"
        self.next_run = Float64(get_next_run_time(cron_expression, Python.import_module("time").time()))
        self.last_run = 0.0
        self.retry_count = 0
        self.max_retries = 3
        self.parameters = Dict[String, String]()

struct JobExecutionResult(Copyable, Movable):
    """Result of a job execution."""
    var job_name: String
    var success: Bool
    var error_message: String
    var execution_time: Float64
    var timestamp: Float64

    fn __init__(out self, job_name: String, success: Bool, error_message: String, execution_time: Float64, timestamp: Float64):
        self.job_name = job_name
        self.success = success
        self.error_message = error_message
        self.execution_time = execution_time
        self.timestamp = timestamp

struct JobScheduler(Movable):
    """Manages scheduled job execution."""
    var jobs: Dict[String, ScheduledJob]
    var is_running: Bool
    var check_interval: Int  # seconds between schedule checks
    var execution_history: List[JobExecutionResult]

    fn __init__(out self):
        self.jobs = Dict[String, ScheduledJob]()
        self.is_running = False
        self.check_interval = 60  # Check every minute
        self.execution_history = List[JobExecutionResult]()

    fn add_job(mut self, mut job: ScheduledJob) raises:
        """Add a job to the scheduler."""
        if job.name in self.jobs:
            raise Error("Job '" + job.name + "' already exists")
        self.jobs[job.name] = job ^

    fn remove_job(mut self, job_name: String) raises:
        """Remove a job from the scheduler."""
        if job_name not in self.jobs:
            raise Error("Job '" + job_name + "' not found")
        _ = self.jobs.pop(job_name)

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

        # Collect jobs that need to run
        var jobs_to_run = List[String]()
        var job_names = List[String]()
        for name in self.jobs.keys():
            job_names.append(name)

        for i in range(len(job_names)):
            var job_name = job_names[i]
            var job_copy = self.jobs[job_name].copy()
            if not job_copy.enabled or job_copy.status == "running":
                continue

            # Check if it's time to run
            if now_timestamp >= job_copy.next_run:
                jobs_to_run.append(job_name)

        # Execute the jobs
        for i in range(len(jobs_to_run)):
            self._execute_job(jobs_to_run[i])

    fn _execute_job(mut self, job_name: String) raises:
        """Execute a scheduled job."""
        # Check if job exists
        if job_name not in self.jobs:
            raise Error("Job '" + job_name + "' not found")

        # Get the job and mark as running
        var job_copy = self.jobs[job_name].copy()
        job_copy.status = "running"
        self.jobs[job_name] = job_copy ^

        var start_time = Python.import_module("time").time()
        var _success = False
        var error_msg = ""

        try:
            if job_copy.execution_type == "procedure":
                # Simple procedure execution - just print for now
                print("Executing procedure:", job_copy.call_target)
                _success = True

            elif job_copy.execution_type == "pipeline":
                # Simple pipeline execution - just print for now
                print("Executing pipeline:", job_copy.call_target)
                _success = True
            else:
                raise Error("Unknown execution type: " + job_copy.execution_type)

        except e:
            _success = False
            error_msg = String(e)
            job_copy.retry_count += 1

            if job_copy.retry_count >= job_copy.max_retries:
                job_copy.status = "failed"
                print("Job", job_name, "failed after", job_copy.max_retries, "retries:", error_msg)
            else:
                job_copy.status = "pending"
                print("Job", job_name, "failed, retry", job_copy.retry_count, "/", job_copy.max_retries, ":", error_msg)

            # Save updated job
            self.jobs[job_name] = job_copy ^

        if _success:
            job_copy.status = "completed"
            job_copy.retry_count = 0
            job_copy.last_run = Float64(Python.import_module("time").time())
            # Calculate next run time
            job_copy.next_run = Float64(get_next_run_time(job_copy.cron_expression, Python.import_module("time").time()))
            print("Job", job_name, "completed successfully")

            # Save updated job
            self.jobs[job_name] = job_copy ^

        # Record execution result
        var execution_time = Python.import_module("time").time() - start_time
        var result = JobExecutionResult(
            job_name,
            _success,
            error_msg,
            Float64(execution_time),
            Float64(Python.import_module("time").time())
        )
        self.execution_history.append(result ^)

    fn get_job_status(self, job_name: String) raises -> String:
        """Get the status of a job."""
        if job_name not in self.jobs:
            raise Error("Job '" + job_name + "' not found")
        return self.jobs[job_name].copy().status

    fn get_execution_history(self, job_name: String) raises -> List[JobExecutionResult]:
        """Get execution history for a job."""
        var history = List[JobExecutionResult]()
        for i in range(len(self.execution_history)):
            var result = self.execution_history[i].copy()
            if result.job_name == job_name:
                history.append(result ^)
        return history.copy()

    fn list_jobs(self) -> List[String]:
        """List all job names."""
        var job_names = List[String]()
        for name in self.jobs.keys():
            job_names.append(name)
        return job_names.copy()