//! Grizzly DB - A fast, columnar, AI-friendly database written in Zig
//!
//! Grizzly DB combines the best features of:
//! - DuckDB: Small, embedded, efficient columnar storage
//! - Polars: Fast parallel compute operations
//! - SQLMesh: Maintainable schema versioning
//! - AI-friendly: Export to JSON, JSONL, CSV, and binary formats

const std = @import("std");

// Core modules
pub const types = @import("types.zig");
pub const schema = @import("schema.zig");
pub const column = @import("column.zig");
pub const table = @import("table.zig");
pub const database = @import("database.zig");
pub const query = @import("query.zig");
pub const export_mod = @import("export.zig");
pub const parallel = @import("parallel.zig");

// Sprint 1: AI-auditable analytics
pub const audit = @import("audit.zig");
pub const validator = @import("validator.zig");

// Sprint 2: Data lakehouse and ANSI SQL WHERE
pub const lakehouse = @import("lakehouse.zig");
pub const where_clause = @import("where.zig");

// Sprint 3: Query optimizer, B+Tree indexes, and async I/O
pub const query_plan = @import("query_plan.zig");
pub const btree = @import("btree.zig");
pub const async_io = @import("async_io.zig");

// Sprint 5: Cardinality estimation and statistics
pub const cardinality = @import("cardinality.zig");
pub const checkpoint = @import("checkpoint.zig");

// Sprint 6: File format system
pub const format = @import("format.zig");
pub const csv_format = @import("formats/csv.zig");
pub const json_format = @import("formats/json.zig");

// Sprint 10: CTAS & Model DAG
pub const model = @import("model.zig");
pub const dag = @import("dag.zig");
pub const dependency = @import("dependency.zig");

// Sprint 11: Incremental Models
pub const incremental = @import("incremental.zig");
pub const scheduler_mod = @import("scheduler.zig");
pub const scheduler = @import("scheduler.zig");

// Sprint 13: Create Type - Extended Type System
pub const types_custom = @import("types_custom.zig");
pub const type_registry = @import("type_registry.zig");

// Sprint 14: PL-Grizzly - SQL Templating & Stored Procedures
pub const expression = @import("expression.zig");
pub const template = @import("template.zig");
pub const function = @import("function.zig");

// Re-export commonly used types
pub const DataType = types.DataType;
pub const Value = types.Value;
pub const Schema = schema.Schema;
pub const Column = column.Column;
pub const Table = table.Table;
pub const Database = database.Database;
pub const QueryEngine = query.QueryEngine;
pub const ParallelEngine = parallel.ParallelEngine;

// Sprint 1 types
pub const AuditLog = audit.AuditLog;
pub const QueryTrace = audit.QueryTrace;

// Sprint 5 types
pub const HyperLogLog = cardinality.HyperLogLog;
pub const CardinalityStats = cardinality.CardinalityStats;
pub const Checkpoint = checkpoint.Checkpoint;

// Sprint 6 types
pub const FormatLoader = format.FormatLoader;
pub const FormatRegistry = format.FormatRegistry;
pub const LoadOptions = format.LoadOptions;
pub const SaveOptions = format.SaveOptions;
pub const Validator = validator.Validator;

// Sprint 2 types
pub const Lakehouse = lakehouse.Lakehouse;
pub const Expr = where_clause.Expr;
pub const Predicate = where_clause.Predicate;

// Sprint 3 types
pub const QueryPlan = query_plan.QueryPlan;
pub const PlanNode = query_plan.PlanNode;
pub const Optimizer = query_plan.Optimizer;
pub const BTreeIndex = btree.BTreeIndex;
pub const AsyncLakehouse = async_io.AsyncLakehouse;
pub const WorkStealingScheduler = async_io.WorkStealingScheduler;

// Sprint 11 types
pub const Schedule = scheduler_mod.Schedule;
pub const Scheduler = scheduler_mod.Scheduler;
pub const QueryResult = query.QueryResult;

// Sprint 13 types
pub const CustomType = types_custom.CustomType;
pub const EnumType = types_custom.EnumType;
pub const StructType = types_custom.StructType;
pub const TypeAlias = types_custom.TypeAlias;
pub const CustomValue = types_custom.CustomValue;
pub const EnumValue = types_custom.EnumValue;
pub const StructValue = types_custom.StructValue;
pub const TypeRegistry = type_registry.TypeRegistry;
pub const TypeInfo = type_registry.TypeInfo;

// Sprint 14 types
pub const ExpressionEngine = expression.ExpressionEngine;
pub const TemplateEngine = template.TemplateEngine;
pub const ExprNode = expression.ExprNode;
pub const BinaryOp = expression.BinaryOp;
pub const ExpressionParser = expression.ExpressionParser;
pub const FunctionRegistry = function.FunctionRegistry;
pub const Function = function.Function;
pub const FunctionBody = function.FunctionBody;
pub const Parameter = function.Parameter;

test {
    std.testing.refAllDecls(@This());
}
