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

// Phase 7: Automatic Optimization Engine
pub const workload_analyzer = @import("workload_analyzer.zig");
pub const migration = @import("migration.zig");
pub const optimizer = @import("optimizer.zig");

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

// Sprint 19: Hybrid Storage Architecture
pub const storage_engine = @import("storage_engine.zig");
pub const storage_config = @import("storage_config.zig");
pub const storage_selector = @import("storage_selector.zig");
pub const memory_store = @import("memory_store.zig");
pub const column_store = @import("column_store.zig");
pub const row_store = @import("row_store.zig");
pub const graph_store = @import("graph_store.zig");
pub const blockchain = @import("blockchain.zig");
pub const graph_query = @import("graph_query.zig");
pub const avro_bridge = @import("avro_bridge.zig");
pub const index = @import("index.zig");
pub const parquet = @import("parquet.zig");
pub const arrow_bridge = @import("arrow_bridge.zig");

// Sprint 20: HTTPFS Extension
pub const extensions = @import("extensions.zig");
pub const extension_api = @import("extension_api.zig");
pub const dynamic_loader = @import("dynamic_loader.zig");
pub const http_client = @import("http_client.zig");
pub const tls = @import("tls.zig");
pub const url = @import("url.zig");
pub const secrets = @import("secrets.zig");

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

// Sprint 19 types
pub const StorageEngine = storage_engine.StorageEngine;
pub const StorageType = storage_engine.StorageType;
pub const StorageCapabilities = storage_engine.StorageCapabilities;
pub const PerformanceMetrics = storage_engine.PerformanceMetrics;
pub const StorageRecommendation = storage_engine.StorageRecommendation;
pub const StorageConfig = storage_config.StorageConfig;
pub const StorageMetadata = storage_config.StorageMetadata;
pub const StorageRegistry = storage_config.StorageRegistry;
pub const WorkloadProfile = storage_selector.WorkloadProfile;
pub const StorageSelector = storage_selector.StorageSelector;
pub const MemoryStore = memory_store.MemoryStore;
pub const ColumnStore = column_store.ColumnStore;
pub const RowStore = row_store.RowStore;
pub const GraphStore = graph_store.GraphStore;
pub const Blockchain = blockchain.Blockchain;
pub const GraphQuery = graph_query.GraphQuery;
pub const AvroWriter = avro_bridge.AvroWriter;
pub const AvroReader = avro_bridge.AvroReader;
pub const Index = index.Index;
pub const ParquetWriter = parquet.ParquetWriter;
pub const ArrowRecordBatch = memory_store.ArrowRecordBatch;
pub const ArrowBridge = arrow_bridge.ArrowBridge;

// Sprint 20 types
pub const ExtensionManager = extensions.ExtensionManager;
pub const Extension = extension_api.Extension;
pub const ExtensionConfig = extension_api.ExtensionConfig;
pub const ExtensionCapability = extension_api.ExtensionCapability;
pub const ExtensionEntry = extension_api.ExtensionEntry;
pub const Client = http_client.Client;
pub const Request = http_client.Request;
pub const Response = http_client.Response;
pub const Method = http_client.Method;
pub const Status = http_client.Status;
pub const Headers = http_client.Headers;
pub const TLS = tls.TLS;
pub const URL = url.URL;
pub const SecretsManager = secrets.SecretsManager;
pub const Secret = secrets.SecretsManager.Secret;
pub const DuckDBConnection = arrow_bridge.DuckDBConnection;

// Phase 7: Automatic Optimization Engine
pub const WorkloadAnalyzer = workload_analyzer.WorkloadAnalyzer;
pub const MigrationEngine = migration.MigrationEngine;
pub const StorageOptimizer = optimizer.StorageOptimizer;
pub const MigrationResult = storage_engine.MigrationResult;
pub const MigrationEstimate = migration.MigrationEstimate;

test {
    std.testing.refAllDecls(@This());
}
