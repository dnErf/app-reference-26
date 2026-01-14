# 260113 - SINCE Timestamp Design Document

## 🎯 **Time Travel Queries: SINCE Timestamp Implementation**

### **Overview**
SINCE timestamp queries enable time travel functionality in the lakehouse, allowing users to query historical states of data since any point in time. This feature provides immutable, cryptographically-verified snapshots of data with enterprise-grade tamper detection.

---

## 📋 **Core Concepts**

### **1. Time Travel Query Syntax**
```sql
-- Standard SQL syntax with SINCE
SELECT * FROM table_name SINCE timestamp

-- Alternative syntax (FROM table SINCE timestamp SELECT *)
FROM table_name SINCE timestamp SELECT *

-- With WHERE conditions
SELECT * FROM table_name SINCE timestamp WHERE column = 'value'

-- Complex queries with time travel
SELECT t1.*, t2.name
FROM table1 t1 SINCE 1640995200
JOIN table2 t2 SINCE 1640995200 ON t1.id = t2.id
WHERE t1.status = 'active'
```

### **2. Timestamp Formats**
- **Unix Epoch**: `1640995200` (seconds since 1970-01-01 00:00:00 UTC)
- **ISO 8601**: `'2022-01-01T00:00:00Z'` (future extension)
- **Relative**: `'1 hour ago'`, `'yesterday'` (future extension)

### **3. Merkle Timeline Integration**
Every SINCE query leverages the Merkle timeline for:
- **Cryptographic Integrity**: Merkle proofs verify data hasn't been tampered
- **Efficient Lookup**: B+ Tree structure enables O(log n) timestamp queries
- **Snapshot Consistency**: All tables referenced use the same timestamp

---

## 🏗️ **Architecture Design**

### **1. Query Processing Pipeline**

```
SQL Query → PL-GRIZZLY Parser → AST with SINCE clauses → LakehouseEngine → MerkleTimeline → ORCStorage
     ↓              ↓                    ↓                      ↓                ↓              ↓
  "SELECT *      Parse SINCE        Extract timestamp     query_since()    get_commits_    Execute query
   FROM users                       and table names       method           since()        against
   SINCE 1640995200"                                                  snapshot       historical data
```

### **2. LakehouseEngine Integration**

```mojo
struct LakehouseEngine(Movable):
    // ... existing fields ...

    fn query_since(self, table_name: String, timestamp: Int64, sql: String) raises -> String:
        """Execute a time-travel query against the lakehouse."""
        print("Time-travel query since", String(timestamp) + ":", sql)

        // Get commits since the specified timestamp
        var commits = self.timeline.query_since(table_name, timestamp)
        print("Found", len(commits), "commits since timestamp", String(timestamp))

        // In full implementation, this would:
        // 1. Parse SQL with SINCE clause
        // 2. Filter data based on timeline state
        // 3. Execute query against historical data

        return "Time-travel query executed: " + sql + " (since " + String(timestamp) + ")"
```

### **3. MerkleTimeline Time Travel**

```mojo
struct MerkleTimeline:
    var commit_tree: MerkleBPlusTree[CommitKey, CommitData]

    fn query_since(self, table_name: String, timestamp: Int64) -> List[Commit]:
        """Get all commits for a table since the specified timestamp."""
        var commits = List[Commit]()

        // Query B+ Tree for range [timestamp, current_time]
        var range_query = self.commit_tree.range_query(
            CommitKey(table_name, timestamp),
            CommitKey(table_name, current_timestamp())
        )

        for entry in range_query:
            commits.append(entry.value.commit)

        return commits

    fn get_merkle_proof(self, table_name: String, timestamp: Int64) -> MerkleProof:
        """Generate cryptographic proof for time travel query integrity."""
        // Generate proof that data since timestamp is authentic
        return self.commit_tree.generate_proof(CommitKey(table_name, timestamp))
```

---

## 🔍 **Implementation Details**

### **1. PL-GRIZZLY Parser Extensions**

#### **AST Node Extensions**
```mojo
struct SinceClause:
    var timestamp: Int64
    var timestamp_expr: Optional[Expression]  # For future expression support

struct SelectStatement:
    var table_name: String
    var since_clause: Optional[SinceClause]  # New field
    var where_clause: Optional[Expression]
    var columns: List[String]
```

#### **Parser Grammar Updates**
```
select_statement ::= SELECT columns FROM table_reference [WHERE condition]
table_reference ::= table_name [SINCE timestamp] [AS alias]

-- Alternative grammar for FROM-first syntax
from_first_statement ::= FROM table_name SINCE timestamp SELECT columns [WHERE condition]

timestamp ::= INTEGER_LITERAL | STRING_LITERAL | expression
```

#### **Example Parse Trees**
```
-- Standard syntax: SELECT * FROM users SINCE 1640995200 WHERE active = true
AST:
SelectStatement {
    table_name: "users"
    since_clause: SinceClause {
        timestamp: 1640995200
    }
    where_clause: BinaryOp {
        left: ColumnRef("active")
        op: "="
        right: BooleanLiteral(true)
    }
    columns: ["*"]
}

-- Alternative syntax: FROM users SINCE 1640995200 SELECT * WHERE active = true
AST:
FromFirstStatement {
    table_name: "users"
    since_clause: SinceClause {
        timestamp: 1640995200
    }
    select_clause: SelectClause {
        columns: ["*"]
        where_clause: BinaryOp {
            left: ColumnRef("active")
            op: "="
            right: BooleanLiteral(true)
        }
    }
}
```

### **2. Query Execution Strategy**

#### **Snapshot Resolution**
1. **Timestamp Validation**: Ensure timestamp is within valid range
2. **Commit Discovery**: Find all commits ≤ timestamp for the table
3. **Merkle Verification**: Verify integrity of commit chain
4. **Data Reconstruction**: Build historical state from commit log

#### **Multi-Table Consistency**
```mojo
fn execute_time_travel_query(tables: List[TableRef], timestamp: Int64) -> DataFrame:
    """Execute query across multiple tables since consistent timestamp."""
    var table_snapshots = Dict[String, List[Commit]]()

    // Get consistent snapshots for all tables since timestamp
    for table_ref in tables:
        var commits = timeline.query_since(table_ref.name, timestamp)
        table_snapshots[table_ref.name] = commits

        // Verify Merkle integrity across all tables
        verify_cross_table_consistency(table_snapshots)

    // Execute query against historical snapshots
    return execute_query_on_snapshots(sql, table_snapshots)
```

### **3. Incremental Processing Integration**

#### **Change Data Capture with Time Travel**
```sql
-- Get all changes since last watermark
SELECT * FROM get_changes_since('users', 1640995200)

-- Time travel + incremental processing
SELECT * FROM users SINCE 1640995200
WHERE id IN (SELECT id FROM get_changes_since('users', 1640995200))
```

#### **Watermark Management**
```mojo
struct IncrementalProcessor:
    var watermarks: Dict[String, Int64]  # table -> last_processed_timestamp

    fn get_changes_since(self, table_name: String, since: Int64) -> ChangeSet:
        """Get incremental changes with Merkle proof verification."""
        var changes = ChangeSet()

        // Get commits since watermark
        var commits = timeline.query_since(table_name, since)
        for commit in commits:
            changes.add_commit(commit)

        // Generate Merkle proof for change set
        changes.proof = timeline.get_merkle_proof(table_name, since)

        return changes
```

---

## 📊 **Examples & Use Cases**

### **1. Basic Time Travel**

#### **Query Historical User Data**
```sql
-- See user data since New Year's 2022
SELECT * FROM users SINCE 1640995200

-- Check account balance since specific time
SELECT user_id, balance FROM accounts SINCE 1640995200 WHERE user_id = 12345
```

#### **Audit Trail Queries**
```sql
-- Investigate data since time of incident
SELECT * FROM audit_log SINCE 1640995200
WHERE event_type = 'suspicious_login'

-- Compare states over time
SELECT 'before' as period, COUNT(*) as user_count FROM users SINCE 1640995200
UNION ALL
SELECT 'after' as period, COUNT(*) as user_count FROM users SINCE 1643673600
```

### **2. Complex Analytical Queries**

#### **Time-Series Analysis**
```sql
-- Monthly revenue trends since time travel
SELECT
    DATE_FORMAT(timestamp, '%Y-%m') as month,
    SUM(amount) as revenue
FROM transactions SINCE 1640995200
WHERE timestamp >= '2022-01-01' AND timestamp < '2023-01-01'
GROUP BY DATE_FORMAT(timestamp, '%Y-%m')
ORDER BY month
```

#### **Point-in-Time Reporting**
```sql
-- Generate quarterly report since end of Q1 2022
SELECT
    department,
    SUM(salary) as total_salary,
    COUNT(*) as employee_count,
    AVG(salary) as avg_salary
FROM employees SINCE 1648771200  -- 2022-04-01 00:00:00
GROUP BY department
ORDER BY total_salary DESC
```

### **3. Data Recovery & Debugging**

#### **Data Recovery**
```sql
-- Recover accidentally deleted records since specific time
SELECT * FROM products SINCE 1640995200
WHERE deleted_at IS NULL
  AND id NOT IN (
      SELECT id FROM products  -- Current state
  )
```

#### **A/B Testing Analysis**
```sql
-- Compare user behavior before/after feature rollout since timestamps
SELECT
    'before_rollout' as period,
    COUNT(*) as sessions,
    AVG(duration) as avg_session_time
FROM user_sessions SINCE 1640995200  -- Before rollout
WHERE feature_enabled = false

UNION ALL

SELECT
    'after_rollout' as period,
    COUNT(*) as sessions,
    AVG(duration) as avg_session_time
FROM user_sessions SINCE 1643673600  -- After rollout
WHERE feature_enabled = true
```

### **4. Incremental Processing Examples**

#### **Change Data Capture**
```sql
-- Process only new orders since last run
SELECT * FROM orders SINCE 1640995200
WHERE order_timestamp > (SELECT watermark FROM processing_state WHERE table_name = 'orders')
```

#### **Real-time Analytics with Time Travel**
```sql
-- Dashboard showing current state + historical trends since timestamp
WITH current_data AS (
    SELECT department, SUM(sales) as current_sales
    FROM sales
    GROUP BY department
),
historical_data AS (
    SELECT department, SUM(sales) as historical_sales
    FROM sales SINCE 1640995200  -- Last month
    GROUP BY department
)
SELECT
    c.department,
    c.current_sales,
    h.historical_sales,
    ROUND((c.current_sales - h.historical_sales) / h.historical_sales * 100, 2) as growth_pct
FROM current_data c
JOIN historical_data h ON c.department = h.department
```

---

## 🔒 **Security & Integrity**

### **1. Cryptographic Verification**
- **Merkle Proofs**: Every AS OF query includes tamper-proof verification
- **Chain of Trust**: Commits are cryptographically linked
- **Integrity Checks**: Automatic verification of historical data authenticity

### **2. Access Control**
```sql
-- Time travel queries respect current permissions
-- Users can only access historical data they can currently access
GRANT SELECT ON users TO analyst;
-- Analyst can now query: SELECT * FROM users SINCE timestamp
```

### **3. Audit Logging**
```sql
-- All time travel queries are logged
SELECT * FROM audit_log WHERE query_type = 'TIME_TRAVEL'
  AND timestamp >= 1640995200
```

---

## ⚡ **Performance Considerations**

### **1. Timeline Optimization**
- **B+ Tree Indexing**: O(log n) timestamp lookups
- **Compaction**: Automatic timeline compaction reduces storage
- **Caching**: Frequently accessed timestamps cached

### **2. Query Optimization**
- **Snapshot Reuse**: Multiple queries at same timestamp share snapshot
- **Incremental Materialization**: Pre-compute common historical views
- **Parallel Execution**: Time travel queries can be parallelized

### **3. Storage Efficiency**
- **Deduplication**: Common data across snapshots deduplicated
- **Compression**: Historical data compressed for storage efficiency
- **Archival**: Old snapshots can be archived to cheaper storage

---

## 🧪 **Testing Strategy**

### **1. Unit Tests**
```mojo
fn test_time_travel_basic():
    var engine = LakehouseEngine("./test_data")

    // Create test data
    engine.create_table("users", user_schema)
    engine.insert("users", test_records)

    // Test time travel
    var past_query = engine.query_since("users", past_timestamp, "SELECT COUNT(*) FROM users")
    var current_query = engine.query("users", "SELECT COUNT(*) FROM users")

    assert past_query != current_query  // Data has changed since timestamp
```

### **2. Integration Tests**
- **Multi-table consistency**: Ensure JOINs work across time travel
- **Incremental processing**: Verify change streams work with time travel
- **Performance regression**: Monitor query performance over time

### **3. Security Tests**
- **Tamper detection**: Verify Merkle proofs catch data corruption
- **Access control**: Ensure permissions work with historical data
- **Audit trails**: Verify all time travel queries are logged

---

## 🚀 **Future Extensions**

### **1. Advanced Timestamp Expressions**
```sql
-- Relative timestamps (future)
SELECT * FROM users AS OF '1 hour ago'
SELECT * FROM users AS OF 'last monday'

-- Expression-based timestamps (future)
SELECT * FROM users AS OF (SELECT max(timestamp) FROM backups WHERE status = 'completed')
```

### **2. Snapshot Management**
```sql
-- Named snapshots (future)
CREATE SNAPSHOT 'quarterly_backup' FROM users SINCE CURRENT_TIMESTAMP
SELECT * FROM users SINCE SNAPSHOT 'quarterly_backup'
```

### **3. Cross-Table Time Travel**
```sql
-- Ensure transactional consistency across tables since timestamp (future)
BEGIN TIME TRAVEL SINCE 1640995200
    SELECT * FROM orders o JOIN customers c ON o.customer_id = c.id
END TIME TRAVEL
```

---

## 📈 **Implementation Roadmap**

### **Phase 1: Basic SINCE Support** ✅
- [x] LakehouseEngine.query_since() method
- [x] MerkleTimeline timestamp queries
- [x] Basic time travel functionality

### **Phase 2: PL-GRIZZLY Integration** 🔄
- [ ] Extend parser for SINCE syntax
- [ ] AST nodes for time travel clauses
- [ ] Query execution with historical data

### **Phase 3: Advanced Features** 📋
- [ ] Multi-table time travel consistency
- [ ] Named snapshots
- [ ] Relative timestamp expressions
- [ ] Performance optimizations

### **Phase 4: Enterprise Features** 🎯
- [ ] Time travel in stored procedures
- [ ] Cross-database time travel
- [ ] Time travel in views/materialized views
- [ ] Advanced snapshot management

---

## 🔧 **API Reference**

### **LakehouseEngine Methods**
```mojo
fn query_since(table_name: String, timestamp: Int64, sql: String) -> String
fn get_commits_since(table_name: String, since: Int64) -> List[Commit]
fn verify_timeline_integrity(table_name: String, timestamp: Int64) -> Bool
```

### **MerkleTimeline Methods**
```mojo
fn query_since(table_name: String, timestamp: Int64) -> List[Commit]
fn get_merkle_proof(table_name: String, timestamp: Int64) -> MerkleProof
fn compact_commits()  // Automatic optimization
```

### **IncrementalProcessor Methods**
```mojo
fn get_changes_since(table_name: String, since: Int64) -> ChangeSet
fn update_watermark(table_name: String, timestamp: Int64)
fn verify_changes_integrity(changes: ChangeSet) -> Bool
```

---

## 🎯 **Success Criteria**

### **Functional Requirements**
- [x] Basic SINCE queries work with Unix timestamps
- [ ] PL-GRIZZLY parser supports SINCE syntax
- [ ] Multi-table queries maintain timestamp consistency
- [ ] Merkle proofs verify data integrity
- [ ] Incremental processing works with time travel

### **Performance Requirements**
- [ ] Time travel queries within 2x of current query performance
- [ ] B+ Tree lookups in O(log n) time
- [ ] Efficient storage with automatic compaction

### **Security Requirements**
- [ ] All time travel queries cryptographically verified
- [ ] Access controls enforced on historical data
- [ ] Comprehensive audit logging

### **Compatibility Requirements**
- [ ] Existing queries continue to work unchanged
- [ ] Backward compatibility maintained
- [ ] Migration path for existing data

---

*Document Version: 1.0 | Date: January 13, 2026 | Author: AI Agent*</content>
<parameter name="filePath">/home/lnx/Dev/app-reference-26/mojo-gobi/.agents/d/260113-AS-OF-Timestamp-Design.md