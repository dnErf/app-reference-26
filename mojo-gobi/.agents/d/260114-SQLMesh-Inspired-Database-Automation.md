# 260114 - SQLMesh-Inspired Database Automation & Services

## Overview
Transform PL-GRIZZLY from an embedded lakehouse database into a full database server with SQLMesh-inspired automation capabilities including cron jobs, triggers, stored procedures, and global service accessibility.

## Architecture Overview

### Global Lakehouse Service
PL-GRIZZLY will support two operational modes:

1. **Embedded Mode** (Current): Direct library usage within applications
2. **Service Mode** (New): Background daemon providing global lakehouse instance via `gobi mount`

### Key Components

#### 1. Global Lakehouse Daemon (`gobi mount <folder>`)
- **Purpose**: Maintain persistent lakehouse instance across sessions
- **Command**: `gobi mount <folder>` starts daemon with specific folder as global instance
- **Lifecycle**: `gobi daemon status/stop` commands for management
- **Discovery**: Service registration for direct connections

#### 2. Apache Arrow IPC Communication Layer
- **Protocol**: Apache Arrow IPC for efficient data serialization
- **Benefits**:
  - Zero-copy data transfer
  - Cross-language compatibility
  - Efficient columnar data exchange
  - Built-in compression support
- **Implementation**: PyArrow IPC integration with connection pooling

#### 3. SQLMesh-Inspired Stored Procedures
- **Syntax**: `upsert procedure procedure_name as {kind: '', sched: [...]}`
- **Features**:
  - Model-like declarations with kind and schedule properties
  - Parameter inference with `TryToInferType`
  - Async/sync execution modes
  - Integration with SQLMesh transformation staging

#### 4. Function Declaration Extensions
```pl-grizzly
function name <ReceiverType> () 
raises Exception
returns void|type
as async|sync
{
    // implementation
}
```

#### 5. Triggers System (`upsert TRIGGER`)
```sql
upsert TRIGGER as trigger_name (
    timing: 'before|after',
    event: 'insert|update|delete|upsert',
    target: 'collections',
    exe: 'pipeline|procedure' 
)
```

#### 6. Cron Scheduler (`upsert SCHEDULE`)
```sql
upsert SCHEDULE as schedule_name (
    sched: '0 0 * * *',
    exe: 'pipeline|procedure',
    call: 'function',
)
```

#### 7. Text-Based User Interface (TUI)
- **Framework**: Textual library (Python) for rich terminal interfaces
- **Inspiration**: DuckDB UI (https://duckdb.org/2025/03/12/duckdb-ui)
- **Features**:
  - Visual procedure/trigger/schedule management
  - Real-time monitoring and debugging
  - Interactive creation wizards
  - Performance metrics dashboard

## Technical Implementation

### Service Architecture

```
┌─────────────────┐    ┌──────────────────┐
│   CLI Client    │────│  Arrow IPC       │
│                 │    │  Protocol        │
│ gobi attach Gobi│    │                  │
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

### Arrow IPC Protocol Design

#### Message Format
Using Apache Arrow's native IPC format:
- **Schema**: Predefined message schemas for different operation types
- **Batches**: RecordBatch for data transfer
- **Streams**: Streaming IPC for continuous data flow
- **Compression**: Built-in LZ4/ZSTD compression support

#### Message Types
- `EXECUTE_SQL`: Execute SQL with Arrow-encoded results
- `CALL_PROCEDURE`: Invoke stored procedure with parameters
- `MANAGE_PROCEDURE`: Create/update/drop procedures
- `MANAGE_TRIGGER`: Create/update/drop triggers
- `MANAGE_SCHEDULE`: Create/update/drop schedules
- `SERVICE_CONTROL`: Mount/unmount service operations

### SQLMesh-Inspired Procedures

#### Syntax Extension
```pl-grizzly
upsert procedure daily_etl as 
<{
    kind: 'INCREMENTAL_BY_TIME_RANGE',
    sched: ['daily_etl_schedule']
}> 
(source_path string, target_table string)
raises ETLError 
returns int
as async
{
    // SQLMesh-style incremental processing
    let latest_timestamp = SELECT MAX(updated_at) FROM target_table;
    
    let new_data = SELECT * FROM source_path 
                   WHERE updated_at > latest_timestamp;
    
    INSERT INTO target_table SELECT * FROM new_data;
    
    return len(new_data);
}
```

#### Storage Schema
```sql
CREATE TABLE system.procedures (
  name VARCHAR PRIMARY KEY,
  model_config JSON,  -- SQLMesh model configuration
  parameters JSON,
  body TEXT,
  execution_mode VARCHAR,  -- 'async' or 'sync'
  created_at TIMESTAMP,
  modified_at TIMESTAMP
);
```

### Triggers System

#### Execution Flow
1. **DML Operation** initiated (INSERT/UPDATE/DELETE/UPSERT)
2. **BEFORE Triggers** fire (if timing = 'before')
3. **Row Processing** occurs
4. **AFTER Triggers** fire (if timing = 'after')
5. **Transaction Commit** or rollback

#### Trigger Types
- **Pipeline Execution**: Run data processing pipelines
- **Procedure Calls**: Execute stored procedures
- **Complex Logic**: Custom PL-GRIZZLY code execution

### Cron Scheduler

#### Job Execution
- **Cron Parsing**: Standard cron expressions with extensions
- **Queue Management**: Prioritized job execution
- **Execution Tracking**: Status, logs, and metrics
- **Error Handling**: Retry logic and failure notifications

#### Integration Points
- **SQLMesh Schedules**: Reference SQLMesh schedule definitions
- **Procedure Calls**: Execute stored procedures
- **Pipeline Triggers**: Start data processing pipelines
- **Function Calls**: Invoke PL-GRIZZLY functions

## Implementation Phases

### Phase 1: Global Service Foundation (2 weeks)
- `gobi mount <folder>` command implementation
- Apache Arrow IPC layer integration
- Basic service lifecycle management
- ATTACH Gobi connection support

### Phase 2: SQLMesh-Inspired Procedures (2 weeks)
- `upsert procedure` syntax and parsing
- Model-like configuration support
- Function declaration extensions
- Procedure execution engine

### Phase 3: Triggers & Scheduler (2 weeks)
- `upsert TRIGGER` syntax and execution
- `upsert SCHEDULE` syntax and cron parsing
- Job scheduling engine
- Integration testing

### Phase 4: Text-Based UI (1 week)
- Textual library integration
- Management dashboard development
- Interactive features implementation
- User experience refinement

## Usage Examples

### Starting Global Service
```bash
# Mount lakehouse as global service
gobi mount /var/lib/my-lakehouse

# Check daemon status
gobi daemon status

# Stop the daemon
gobi daemon stop
```

### SQLMesh-Style Procedures
```pl-grizzly
upsert procedure customer_summary as 
<{
    kind: 'VIEW',
    sched: ['hourly_refresh']
}> 
() 
returns void
as sync
{
    CREATE OR REPLACE VIEW customer_summary AS
    SELECT 
        region,
        COUNT(*) as customer_count,
        SUM(total_orders) as total_revenue
    FROM customers c
    JOIN orders o ON c.id = o.customer_id
    GROUP BY region;
}
```

### Triggers for Automation
```sql
upsert TRIGGER as audit_customers (
    timing: 'after',
    event: 'insert',
    target: 'customers',
    exe: 'procedure'
) -- Calls audit_log_procedure
```

### Cron Scheduling
```sql
upsert SCHEDULE as nightly_backup (
    sched: '0 2 * * *',
    exe: 'procedure',
    call: 'perform_backup'
)
```

### TUI Management
```bash
# Launch visual management interface
gobi tui

# Or access specific management sections
gobi tui procedures
gobi tui triggers
gobi tui schedules
```

## Benefits

### For Data Engineers
- **SQLMesh Integration**: Familiar model-based development
- **Transformation Staging**: Built-in incremental processing
- **Visual Management**: TUI for complex automation setup
- **Arrow Efficiency**: Fast data interchange

### For Applications
- **Global Access**: `ATTACH Gobi` for shared lakehouse
- **Background Automation**: Database-level scheduling
- **Event-Driven Processing**: Automatic triggers on data changes
- **Business Logic**: Centralized stored procedures

### For Operations
- **Visual Monitoring**: TUI dashboards for system health
- **Easy Management**: Upsert semantics for configuration
- **Audit Trails**: Comprehensive logging and tracking
- **High Performance**: Arrow IPC for efficient communication

## Conclusion

This SQLMesh-inspired approach transforms PL-GRIZZLY into a powerful database server that combines:
- **Embedded Flexibility**: Direct library usage for applications
- **Server Capabilities**: Global service with background automation
- **SQLMesh Compatibility**: Model-based development and scheduling
- **Arrow Efficiency**: High-performance data communication
- **Visual Management**: TUI for complex automation tasks

The result is a database that serves both application developers (embedded usage) and data teams (server automation), with SQLMesh-style procedures for transformation staging and comprehensive automation capabilities.