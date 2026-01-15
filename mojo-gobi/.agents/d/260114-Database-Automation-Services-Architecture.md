# 260114 - Database Automation & Services Architecture

## Overview
Transform PL-GRIZZLY from an embedded lakehouse database into a full database server with automation capabilities including cron jobs, triggers, stored procedures, and global service accessibility.

## Architecture Overview

### Global Lakehouse Service
PL-GRIZZLY will support two operational modes:

1. **Embedded Mode** (Current): Direct library usage within applications
2. **Service Mode** (New): Background daemon providing global lakehouse instance

### Key Components

#### 1. Global Lakehouse Daemon
- **Purpose**: Maintain persistent lakehouse instance across sessions
- **Implementation**: Background process with IPC communication
- **Lifecycle**: `gobi daemon start/stop/status` commands
- **Configuration**: Service settings via config file

#### 2. IPC Communication Layer
- **Protocol**: Custom binary protocol over Unix domain sockets
- **Fallback**: TCP sockets for network access
- **Features**:
  - Connection pooling
  - Message serialization
  - Authentication
  - Error handling

#### 3. Stored Procedures Engine
- **Language**: Extended PL-GRIZZLY with procedure syntax
- **Storage**: Procedures stored in system tables
- **Execution**: Isolated runtime environment
- **Features**:
  - Parameters and return values
  - Variable scoping
  - Error handling
  - Performance profiling

#### 4. Triggers System
- **Types**: BEFORE/AFTER triggers for DML operations
- **Granularity**: Row-level and statement-level
- **Execution**: Event-driven with proper ordering
- **Management**: Enable/disable, dependency tracking

#### 5. Cron Scheduler
- **Syntax**: Standard cron expressions
- **Execution**: Background job processing
- **Management**: Job queue, history, error handling
- **Integration**: Execute procedures or SQL statements

## Technical Implementation

### Service Architecture

```
┌─────────────────┐    ┌──────────────────┐
│   CLI Client    │────│  IPC Protocol    │
│                 │    │                  │
│ gobi attach Gobi│    │ Unix Socket/TCP  │
└─────────────────┘    └──────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌──────────────────┐
│  Lakehouse      │    │  Automation      │
│  Engine         │────│  Engine          │
│                 │    │                  │
│ - Storage       │    │ - Procedures     │
│ - Query Exec    │    │ - Triggers       │
│ - Transactions  │    │ - Scheduler      │
└─────────────────┘    └──────────────────┘
```

### IPC Protocol Design

#### Message Format
```
Message {
  header: MessageHeader,
  payload: MessagePayload
}

MessageHeader {
  message_id: u64,
  message_type: MessageType,
  payload_size: u32,
  session_id: u64
}

MessagePayload {
  // Type-specific data
}
```

#### Message Types
- `CONNECT`: Establish client connection
- `DISCONNECT`: Close client connection
- `EXECUTE_SQL`: Execute SQL statement
- `EXECUTE_PROCEDURE`: Call stored procedure
- `MANAGE_PROCEDURE`: Create/drop procedures
- `MANAGE_TRIGGER`: Create/drop triggers
- `MANAGE_SCHEDULE`: Create/drop schedules
- `SERVICE_CONTROL`: Start/stop/status operations

### Stored Procedures

#### Syntax Extension
```sql
CREATE PROCEDURE procedure_name(param1 type, param2 type)
AS
BEGIN
  -- PL-GRIZZLY code
  DECLARE result type;
  SET result = param1 + param2;
  RETURN result;
END;

-- Usage
CALL procedure_name(10, 20);
```

#### Storage Schema
```sql
CREATE TABLE system.procedures (
  name VARCHAR PRIMARY KEY,
  parameters JSON,
  body TEXT,
  created_at TIMESTAMP,
  modified_at TIMESTAMP
);
```

### Triggers System

#### Syntax Extension
```sql
CREATE TRIGGER trigger_name
  BEFORE INSERT ON table_name
  FOR EACH ROW
AS
BEGIN
  -- Trigger logic
  IF NEW.status = 'active' THEN
    SET NEW.created_at = NOW();
  END IF;
END;
```

#### Execution Flow
1. DML operation initiated
2. BEFORE triggers fire (if any)
3. Row processing
4. AFTER triggers fire (if any)
5. Transaction commit/rollback

### Cron Scheduler

#### Syntax Extension
```sql
CREATE SCHEDULE schedule_name
  CRON '0 0 * * *'  -- Daily at midnight
AS
BEGIN
  -- Scheduled task
  CALL maintenance_procedure();
END;
```

#### Scheduler Components
- **Parser**: Cron expression parsing
- **Queue**: Job scheduling and prioritization
- **Executor**: Background job execution
- **Monitor**: Job status and error handling

## Implementation Phases

### Phase 1: Global Service Foundation (2 weeks)
- Daemon mode implementation
- Basic IPC communication
- Service lifecycle management
- ATTACH Gobi support

### Phase 2: Stored Procedures (2 weeks)
- Procedure language extensions
- Execution engine
- Procedure management commands
- Testing and validation

### Phase 3: Triggers System (1 week)
- Trigger syntax and parsing
- Event detection and execution
- Trigger management
- Integration testing

### Phase 4: Cron Scheduler (1 week)
- Cron expression parsing
- Job scheduling engine
- Schedule management
- End-to-end testing

## Usage Examples

### Starting Global Service
```bash
# Initialize global lakehouse
gobi init --global /var/lib/gobi

# Start daemon
gobi daemon start

# Check status
gobi daemon status
```

### Connecting to Global Instance
```sql
-- In any PL-GRIZZLY session
ATTACH Gobi;

-- Now access global lakehouse
SELECT * FROM global_table;
```

### Creating Automation
```sql
-- Stored procedure
CREATE PROCEDURE daily_backup()
AS
BEGIN
  -- Backup logic
  BACKUP DATABASE TO '/backups/daily_' || DATE_FORMAT(NOW(), 'YYYYMMDD') || '.gobi';
END;

-- Trigger
CREATE TRIGGER audit_log
  AFTER INSERT ON users
  FOR EACH ROW
AS
BEGIN
  INSERT INTO audit_log (table_name, operation, user_id, timestamp)
  VALUES ('users', 'INSERT', NEW.id, NOW());
END;

-- Cron job
CREATE SCHEDULE daily_maintenance
  CRON '0 2 * * *'  -- 2 AM daily
AS
BEGIN
  CALL daily_backup();
  CALL cleanup_old_logs();
END;
```

## Benefits

### For Applications
- **Shared Data**: Multiple applications can access same lakehouse
- **Automation**: Database-level automation without application code
- **Consistency**: Centralized business logic in stored procedures
- **Reliability**: Triggers ensure data integrity automatically

### For Operations
- **Monitoring**: Centralized logging and monitoring
- **Maintenance**: Automated backup and cleanup
- **Scaling**: Service can be scaled independently
- **Reliability**: Background service ensures availability

## Migration Path

### Backward Compatibility
- Existing embedded usage continues to work unchanged
- New features are opt-in
- No breaking changes to current API

### Gradual Adoption
1. Start with global service for shared access
2. Add stored procedures for business logic
3. Implement triggers for data integrity
4. Add cron jobs for automation

## Conclusion

This phase transforms PL-GRIZZLY from a powerful embedded database into a full-featured database server with enterprise automation capabilities, while maintaining its embedded nature for applications that need it.