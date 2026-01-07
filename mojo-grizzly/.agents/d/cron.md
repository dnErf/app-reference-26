# Cron Jobs in Mojo Grizzly

Cron jobs enable scheduled execution of SQL commands.

## Syntax
CRON ADD 'schedule' 'command'

RUN CRON  # Executes all jobs in background threads

## Example
CRON ADD 'daily' 'OPTIMIZE users'

RUN CRON

## Implementation
- Stored in global cron_jobs list
- Uses Thread for background execution
- Tied to #grizzly_zig for advanced scheduling