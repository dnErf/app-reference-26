# Job Scheduling Engine - Implementation Documentation

## Overview
The Job Scheduling Engine provides automated execution of stored procedures and pipelines based on cron expressions, enabling scheduled data processing and automation workflows in PL-GRIZZLY.

## Architecture

### Core Components

#### 1. Cron Expression Evaluator (`cron_evaluator.mojo`)
- **Purpose**: Parse and evaluate cron expressions for scheduling
- **Key Functions**:
  - `CronExpression.__init__()`: Parse cron expression into field arrays
  - `matches()`: Check if current time matches cron pattern
  - `get_next_run_time()`: Calculate next execution timestamp

#### 2. Job Scheduler (`job_scheduler.mojo`)
- **Purpose**: Manage scheduled jobs with execution and tracking
- **Key Classes**:
  - `ScheduledJob`: Job definition with cron expression and execution parameters
  - `JobExecutionResult`: Execution result with status and timing
  - `JobScheduler`: Main scheduler with job queue and execution logic

#### 3. Daemon Integration (`daemon.mojo`)
- **Purpose**: Background job processing in lakehouse daemon
- **Features**:
  - Job control commands (list, status, enable, disable)
  - Background job checking and execution
  - Integration with existing daemon request processing

## Job Lifecycle

### 1. Job Creation
```sql
UPSERT SCHEDULE AS daily_backup (
  sched: "0 2 * * *",     -- Daily at 2 AM
  exe: "procedure",       -- Execute procedure
  call: "backup_procedure" -- Procedure name
);
```

### 2. Job Scheduling
- Cron expression parsed and validated
- Next run time calculated based on current time
- Job added to scheduler with pending status

### 3. Job Execution
- Daemon checks for jobs ready to run
- Procedure executed with provided parameters
- Execution result recorded with success/failure status

### 4. Error Handling
- Failed jobs automatically retried (configurable)
- Retry delay with exponential backoff
- Maximum retry count prevents infinite loops
- Failed jobs can be disabled after max retries

## Data Structures

### ScheduledJob
```mojo
struct ScheduledJob(Copyable, Movable):
    var name: String                    # Job identifier
    var cron_expression: String         # Cron schedule pattern
    var execution_type: String          # "procedure" or "pipeline"
    var call_target: String             # Procedure/pipeline name
    var parameters: Dict[String, PLValue] # Execution parameters
    var enabled: Bool                   # Job enabled/disabled
    var last_run: Float64               # Last execution timestamp
    var next_run: Float64               # Next scheduled run
    var status: String                  # Current job status
    var retry_count: Int               # Current retry attempts
    var max_retries: Int               # Maximum retry limit
```

### JobExecutionResult
```mojo
struct JobExecutionResult(Copyable, Movable):
    var job_name: String       # Job that was executed
    var success: Bool          # Execution success flag
    var error_message: String  # Error details if failed
    var execution_time: Float64 # Time taken to execute
    var timestamp: Float64     # Execution timestamp
```

## API Reference

### JobScheduler Methods

#### Core Management
- `start()`: Initialize scheduler and load schedules
- `stop()`: Stop scheduler operation
- `check_and_execute_jobs()`: Check and execute due jobs

#### Job Control
- `get_job_status(job_name)`: Get current job status
- `enable_job(job_name)`: Enable a job for execution
- `disable_job(job_name)`: Disable a job
- `list_jobs()`: List all job names

#### History & Monitoring
- `get_execution_history(job_name)`: Get execution history for a job

### Daemon Commands

#### Job Management
- `list_jobs`: Display all scheduled jobs
- `job_status <name>`: Show status of specific job
- `enable_job <name>`: Enable job execution
- `disable_job <name>`: Disable job execution

## Configuration

### Job Parameters
- **max_retries**: Maximum retry attempts (default: 3)
- **retry_delay**: Delay between retries in seconds (default: 60)
- **check_interval**: Job check frequency in seconds (default: 60)

### Cron Expression Format
```
* * * * *
│ │ │ │ │
│ │ │ │ └── Day of week (0-6, Sunday=0)
│ │ │ └──── Month (1-12)
│ │ └────── Day of month (1-31)
│ └──────── Hour (0-23)
└────────── Minute (0-59)
```

## Error Handling

### Execution Failures
- Automatic retry with configurable limits
- Exponential backoff for retry delays
- Job status tracking (failed, retry_pending, failed_permanently)
- Detailed error logging and history

### Validation Errors
- Cron expression syntax validation
- Required parameter checking
- Execution type validation
- Target existence verification

## Performance Considerations

### Efficiency Features
- Timestamp-based scheduling (no string parsing on each check)
- Job queue processed in single pass
- Minimal memory overhead for job tracking
- Background execution without blocking daemon

### Scalability
- Supports multiple concurrent jobs
- Configurable check intervals
- Memory-efficient execution history
- Resource-aware job execution

## Future Enhancements

### Planned Features
- Pipeline execution support (currently placeholder)
- Job prioritization and queuing
- Resource limits and throttling
- Advanced retry strategies
- Job dependency management
- Distributed job execution

### Integration Points
- LIST SCHEDULES command implementation
- DROP SCHEDULE command implementation
- Job execution metrics and monitoring
- Alert system for job failures
- Job execution dashboards

## Testing

### Unit Tests
- Cron expression parsing and evaluation
- Job scheduling logic
- Execution result handling
- Error recovery scenarios

### Integration Tests
- End-to-end job execution
- Daemon integration
- Concurrent job processing
- Failure and retry scenarios

## Dependencies

### Core Dependencies
- `cron_evaluator.mojo`: Cron expression handling
- `procedure_execution_engine.mojo`: Procedure execution
- `root_storage.mojo`: Job persistence
- `daemon.mojo`: Background processing

### External Dependencies
- Python `time` module: Timestamp operations
- Python `datetime` module: Date/time utilities (legacy support)

## Troubleshooting

### Common Issues
1. **Compilation Errors**: Check dependency module compilation
2. **Job Not Executing**: Verify cron expression and job status
3. **Procedure Errors**: Check procedure existence and parameters
4. **Memory Issues**: Monitor job execution history size

### Debug Commands
- `job_status <name>`: Check job state
- `list_jobs`: View all jobs
- Daemon logs: Check execution errors
- Execution history: Review past runs

## Conclusion

The Job Scheduling Engine provides robust automated execution capabilities for PL-GRIZZLY, enabling scheduled data processing workflows with comprehensive error handling and monitoring. The implementation follows the existing codebase patterns and integrates seamlessly with the Global Lakehouse Daemon for background operation.