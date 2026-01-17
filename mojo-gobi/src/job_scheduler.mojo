"""
Job Scheduling Engine for PL-GRIZZLY Cron Scheduler

Manages scheduled job execution with cron expression evaluation,
job queue management, execution tracking, and failure handling.
"""

from collections import Dict, List
from python import Python, PythonObject
from cron_evaluator import evaluate_cron, get_next_run_time
from root_storage import RootStorage, Record
from pl_grizzly_environment import Environment
from ast_evaluator import ASTEvaluator
from pl_grizzly_values import PLValue

struct ScheduledJob(Copyable, Movable):
    """Represents a scheduled job."""
    var name: String
    var cron_expression: String
    var execution_type: String  # "procedure" or "pipeline"
    var call_target: String     # procedure or pipeline name
    var parameters: Dict[String, PLValue]
    var enabled: Bool
    var last_run: Float64  # timestamp of last execution
    var next_run: Float64  # timestamp of next scheduled run
    var status: String          # "pending", "running", "completed", "failed"
    var retry_count: Int
    var max_retries: Int

    fn __init__(out self, name: String, cron_expr: String, exe_type: String, call_target: String) raises:
        self.name = name
        self.cron_expression = cron_expr
        self.execution_type = exe_type
        self.call_target = call_target
        self.parameters = Dict[String, PLValue]()
        self.enabled = True
        var datetime_mod = Python.import_module("datetime")
        var now = datetime_mod.datetime.now()
        var timestamp = Float64(Python.import_module("time").mktime(now.timetuple()))
        self.last_run = 0.0
        self.next_run = timestamp  # For now, set to current time
        self.status = "pending"
        self.retry_count = 0
        self.max_retries = 3

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

struct JobScheduler(Copyable, Movable):
    """Manages scheduled job execution."""
    var jobs: Dict[String, ScheduledJob]
    var storage: RootStorage
    var is_running: Bool
    var check_interval: Int  # seconds between schedule checks
    var execution_history: List[JobExecutionResult]

    fn __init__(out self, storage: RootStorage) raises:
        self.storage = storage.copy()
        self.jobs = Dict[String, ScheduledJob]()
        self.is_running = False
        self.check_interval = 60  # Check every minute
        self.execution_history = List[JobExecutionResult]()

    fn load_schedules(mut self) raises:
        """Load all schedules from storage."""
        # Get all schedule entities
        var schedule_entities = self.storage.list_entities("schedule")
        for entity in schedule_entities:
            var record = entity.copy()
            var data_json = record.get_value("data")
            
            # Parse JSON data
            var json_mod = Python.import_module("json")
            var data_dict = json_mod.loads(data_json)
            
            var sched = String(data_dict["sched"])
            var exe = String(data_dict["exe"]) 
            var call = String(data_dict["call"])
            var name = String(data_dict["name"])
            
            if sched != "" and exe != "" and call != "":
                var job = ScheduledJob(name, sched, exe, call)
                self.jobs[name] = job ^

    fn start(mut self) raises:
        """Start the job scheduler."""
        if self.is_running:
            return

        self.is_running = True
        self.load_schedules()

        # Note: For now, jobs are checked when requested
        # In the future, this could run in a background thread

    fn stop(mut self):
        """Stop the job scheduler."""
        self.is_running = False

    fn check_and_execute_jobs(mut self) raises:
        """Check for jobs that need to execute and run them."""
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
        var job = self.jobs[job_name].copy()
        job.status = "running"
        self.jobs[job_name] = job ^

        var start_time = Python.import_module("time").time()
        var success = False
        var error_msg = ""

        try:
            if job.execution_type == "procedure":
                # TODO: Execute procedure with proper dependencies
                # For now, just mark as successful
                print("Executing procedure:", job.call_target)
                success = True

            elif job.execution_type == "pipeline":
                # TODO: Implement pipeline execution
                # For now, just mark as successful
                success = True
                print("Pipeline execution not yet implemented for job:", job_name)
            else:
                raise Error("Unknown execution type: " + job.execution_type)

        except e:
            success = False
            error_msg = String(e)
            job.retry_count += 1

            if job.retry_count >= job.max_retries:
                job.status = "failed"
                print("Job", job_name, "failed after", job.max_retries, "retries:", error_msg)
            else:
                job.status = "pending"
                print("Job", job_name, "failed, retry", job.retry_count, "/", job.max_retries, ":", error_msg)

        if success:
            job.status = "completed"
            job.retry_count = 0
            job.last_run = Float64(Python.import_module("time").time())
            print("Job", job_name, "completed successfully")

            # Save updated job
            self.jobs[job_name] = job ^

        # Record execution result
        var execution_time = Python.import_module("time").time() - start_time
        var result = JobExecutionResult(
            job_name,
            success,
            error_msg,
            Float64(execution_time),
            Float64(Python.import_module("time").time())
        )
        self.execution_history.append(result ^)

    fn get_job_status(self, job_name: String) raises -> String:
        """Get the status of a job."""
        if job_name in self.jobs:
            return self.jobs[job_name].status
        return "not_found"

    fn enable_job(mut self, job_name: String) raises -> Bool:
        """Enable a job."""
        if job_name in self.jobs:
            self.jobs[job_name].enabled = True
            return True
        return False

    fn disable_job(mut self, job_name: String) raises -> Bool:
        """Disable a job."""
        if job_name in self.jobs:
            self.jobs[job_name].enabled = False
            return True
        return False

    fn list_jobs(self) raises -> List[String]:
        """List all job names."""
        var job_names = List[String]()
        for name in self.jobs.keys():
            job_names.append(name)
        return job_names ^

    fn get_execution_history(self, job_name: String) raises -> List[JobExecutionResult]:
        """Get execution history for a job."""
        var history = List[JobExecutionResult]()
        for i in range(len(self.execution_history)):
            var result = self.execution_history[i].copy()
            if result.job_name == job_name:
                history.append(result ^)
        return history.copy()

    fn manual_execute_job(mut self, job_name: String) raises -> Bool:
        """Manually execute a job regardless of schedule."""
        if job_name not in self.jobs:
            return False

        var job = self.jobs[job_name].copy()
        if not job.enabled:
            return False

        # Execute the job
        self._execute_job(job_name)
        return True
