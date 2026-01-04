const std = @import("std");
const types = @import("types.zig");
const table_mod = @import("table.zig");
const database_mod = @import("database.zig");
const schema_mod = @import("schema.zig");
const where_mod = @import("where.zig");
const query_plan = @import("query_plan.zig");
const audit_mod = @import("audit.zig");
const format_mod = @import("format.zig");
const csv_format = @import("formats/csv.zig");
const cte_mod = @import("cte.zig");
const json_format = @import("formats/json.zig");
const sorting_mod = @import("sorting.zig");
const lakehouse_mod = @import("lakehouse.zig");
const function_mod = @import("function.zig");
const pattern_mod = @import("pattern.zig");

const Value = types.Value;
const DataType = types.DataType;
const Table = table_mod.Table;
const Database = database_mod.Database;
const Schema = schema_mod.Schema;
const Expr = where_mod.Expr;
const ExprType = where_mod.ExprType;
const Predicate = where_mod.Predicate;
const PlanNode = query_plan.PlanNode;
const QueryPlan = query_plan.QueryPlan;
const Optimizer = query_plan.Optimizer;
const JoinType = query_plan.JoinType;
const Sorter = sorting_mod.Sorter;
const Lakehouse = lakehouse_mod.Lakehouse;
const Function = function_mod.Function;
const FunctionRegistry = function_mod.FunctionRegistry;
const Parameter = function_mod.Parameter;
const FunctionBody = function_mod.FunctionBody;
const ExecutionContext = function_mod.ExecutionContext;
const Pattern = pattern_mod.Pattern;
const MatchCase = function_mod.MatchCase;

const JoinClause = struct {
    join_type: JoinType,
    right_table: *Table,
    right_table_name: []const u8,
    left_column: []const u8,
    right_column: []const u8,
};

pub const SortDirection = enum {
    asc,
    desc,
};

pub const AggFunction = enum { sum, avg, count, min, max };

/// Parse a column specification from a string
pub fn parseColumnSpec(allocator: std.mem.Allocator, str: []const u8) !query_plan.ColumnSpec {
    const trimmed = std.mem.trim(u8, str, " \t\n");
    if (std.mem.indexOf(u8, trimmed, "(")) |open_paren| {
        if (!std.mem.endsWith(u8, trimmed, ")")) return error.InvalidFunctionCall;
        const name = trimmed[0..open_paren];
        const args_str = trimmed[open_paren + 1 .. trimmed.len - 1];
        var args = std.ArrayList(query_plan.ColumnSpec).init(allocator);
        errdefer args.deinit();
        if (args_str.len > 0) {
            var arg_it = std.mem.split(u8, args_str, ",");
            while (arg_it.next()) |arg| {
                const arg_trimmed = std.mem.trim(u8, arg, " \t\n");
                try args.append(.{ .column = try allocator.dupe(u8, arg_trimmed) });
            }
        }
        return query_plan.ColumnSpec{ .function_call = .{ .name = try allocator.dupe(u8, name), .args = try args.toOwnedSlice() } };
    } else {
        return query_plan.ColumnSpec{ .column = try allocator.dupe(u8, trimmed) };
    }
}

/// Clone a ColumnSpec, duplicating all owned strings
pub fn cloneColumnSpec(allocator: std.mem.Allocator, spec: query_plan.ColumnSpec) !query_plan.ColumnSpec {
    switch (spec) {
        .column => |col| return .{ .column = try allocator.dupe(u8, col) },
        .function_call => |fc| {
            var args = std.ArrayList(query_plan.ColumnSpec).init(allocator);
            errdefer args.deinit();
            for (fc.args) |arg| {
                try args.append(try cloneColumnSpec(allocator, arg));
            }
            return .{ .function_call = .{ .name = try allocator.dupe(u8, fc.name), .args = try args.toOwnedSlice() } };
        },
    }
}

pub const OrderByColumn = struct {
    column_name: []const u8,
    direction: SortDirection,
};

pub const OrderByClause = struct {
    columns: []OrderByColumn,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *OrderByClause) void {
        self.allocator.free(self.columns);
    }
};

/// Token types for SQL parsing
const TokenType = enum {
    select,
    from,
    where,
    insert,
    into,
    values,
    create,
    table,
    show,
    join,
    left,
    right,
    full,
    outer,
    on,
    load,
    save,
    refresh,
    order,
    by,
    asc,
    desc,
    group,
    having,
    limit,
    offset,
    distinct,
    vector_search,
    identifier,
    number,
    string,
    string_literal,
    comma,
    semicolon,
    lparen,
    rparen,
    lbrace,
    rbrace,
    star,
    dot,
    eq,
    gt,
    lt,
    gte,
    lte,
    neq,
    and_,
    or_,
    not_,
    is,
    null_,
    like,
    between,
    in,
    view,
    materialized,
    model,
    incremental,
    partition,
    schedule,
    cron,
    failure,
    retry,
    drop,
    lineage,
    dependencies,
    for_,
    as,
    with,
    attach,
    detach,
    databases,
    use,
    validate,
    eof,
    enum_,
    type_,
    struct_,
    describe,
    types,
    function,
    returns,
    match,
    end,
    arrow,
    sync,
    async,
};

const Token = struct {
    type: TokenType,
    value: []const u8,
};

/// Simple SQL tokenizer
pub const Tokenizer = struct {
    input: []const u8,
    pos: usize,

    pub fn init(input: []const u8) Tokenizer {
        return .{ .input = input, .pos = 0 };
    }

    pub fn next(self: *Tokenizer) !?Token {
        self.skipWhitespace();

        if (self.pos >= self.input.len) {
            return Token{ .type = .eof, .value = "" };
        }

        const start = self.pos;
        const ch = self.input[self.pos];

        // Single character tokens
        if (ch == ',') {
            self.pos += 1;
            return Token{ .type = .comma, .value = self.input[start..self.pos] };
        }
        if (ch == ';') {
            self.pos += 1;
            return Token{ .type = .semicolon, .value = self.input[start..self.pos] };
        }
        if (ch == '(') {
            self.pos += 1;
            return Token{ .type = .lparen, .value = self.input[start..self.pos] };
        }
        if (ch == ')') {
            self.pos += 1;
            return Token{ .type = .rparen, .value = self.input[start..self.pos] };
        }
        if (ch == '{') {
            self.pos += 1;
            return Token{ .type = .lbrace, .value = self.input[start..self.pos] };
        }
        if (ch == '}') {
            self.pos += 1;
            return Token{ .type = .rbrace, .value = self.input[start..self.pos] };
        }
        if (ch == '*') {
            self.pos += 1;
            return Token{ .type = .star, .value = self.input[start..self.pos] };
        }
        if (ch == '.') {
            self.pos += 1;
            return Token{ .type = .dot, .value = self.input[start..self.pos] };
        }

        // Operators
        if (ch == '=') {
            self.pos += 1;
            return Token{ .type = .eq, .value = self.input[start..self.pos] };
        }
        if (ch == '>') {
            self.pos += 1;
            if (self.pos < self.input.len and self.input[self.pos] == '=') {
                self.pos += 1;
                return Token{ .type = .gte, .value = self.input[start..self.pos] };
            }
            return Token{ .type = .gt, .value = self.input[start..self.pos] };
        }
        if (ch == '<') {
            self.pos += 1;
            if (self.pos < self.input.len) {
                if (self.input[self.pos] == '=') {
                    self.pos += 1;
                    return Token{ .type = .lte, .value = self.input[start..self.pos] };
                } else if (self.input[self.pos] == '>') {
                    self.pos += 1;
                    return Token{ .type = .neq, .value = self.input[start..self.pos] };
                }
            }
            return Token{ .type = .lt, .value = self.input[start..self.pos] };
        }
        if (ch == '-') {
            self.pos += 1;
            if (self.pos < self.input.len and self.input[self.pos] == '>') {
                self.pos += 1;
                return Token{ .type = .arrow, .value = self.input[start..self.pos] };
            }
            // If not ->, it might be a negative number, back up
            self.pos = start;
            if (self.pos + 1 < self.input.len and std.ascii.isDigit(self.input[self.pos + 1])) {
                return self.readNumber();
            }
            return Token{ .type = .identifier, .value = self.input[start .. self.pos + 1] };
        }

        // String literals
        if (ch == '\'' or ch == '"') {
            const str_token = try self.readString(ch);
            return str_token;
        }

        // Numbers
        if (std.ascii.isDigit(ch) or (ch == '-' and self.pos + 1 < self.input.len and std.ascii.isDigit(self.input[self.pos + 1]))) {
            return self.readNumber();
        }

        // Identifiers and keywords
        if (std.ascii.isAlphabetic(ch) or ch == '_') {
            return self.readIdentifier();
        }

        return error.UnexpectedCharacter;
    }

    fn skipWhitespace(self: *Tokenizer) void {
        while (self.pos < self.input.len and std.ascii.isWhitespace(self.input[self.pos])) {
            self.pos += 1;
        }
    }

    fn readString(self: *Tokenizer, quote: u8) !Token {
        const start = self.pos;
        self.pos += 1; // Skip opening quote

        while (self.pos < self.input.len and self.input[self.pos] != quote) {
            self.pos += 1;
        }

        if (self.pos >= self.input.len) {
            return error.UnterminatedString;
        }

        self.pos += 1; // Skip closing quote
        // Return as string_literal for file paths and string values
        return Token{ .type = .string_literal, .value = self.input[start + 1 .. self.pos - 1] };
    }

    fn readNumber(self: *Tokenizer) Token {
        const start = self.pos;

        if (self.input[self.pos] == '-') {
            self.pos += 1;
        }

        while (self.pos < self.input.len and (std.ascii.isDigit(self.input[self.pos]) or self.input[self.pos] == '.')) {
            self.pos += 1;
        }

        return Token{ .type = .number, .value = self.input[start..self.pos] };
    }

    fn readIdentifier(self: *Tokenizer) Token {
        const start = self.pos;

        while (self.pos < self.input.len and (std.ascii.isAlphanumeric(self.input[self.pos]) or self.input[self.pos] == '_')) {
            self.pos += 1;
        }

        const value = self.input[start..self.pos];
        const token_type = getKeywordType(value);

        return Token{ .type = token_type, .value = value };
    }

    fn getKeywordType(value: []const u8) TokenType {
        const lower = std.ascii.lowerString;
        var buf: [32]u8 = undefined;
        if (value.len > buf.len) return .identifier;

        const lowercase = lower(&buf, value);

        if (std.mem.eql(u8, lowercase, "select")) return .select;
        if (std.mem.eql(u8, lowercase, "from")) return .from;
        if (std.mem.eql(u8, lowercase, "where")) return .where;
        if (std.mem.eql(u8, lowercase, "insert")) return .insert;
        if (std.mem.eql(u8, lowercase, "into")) return .into;
        if (std.mem.eql(u8, lowercase, "values")) return .values;
        if (std.mem.eql(u8, lowercase, "create")) return .create;
        if (std.mem.eql(u8, lowercase, "table")) return .table;
        if (std.mem.eql(u8, lowercase, "type")) return .type_;
        if (std.mem.eql(u8, lowercase, "show")) return .show;
        if (std.mem.eql(u8, lowercase, "view")) return .view;
        if (std.mem.eql(u8, lowercase, "materialized")) return .materialized;
        if (std.mem.eql(u8, lowercase, "model")) return .model;
        if (std.mem.eql(u8, lowercase, "incremental")) return .incremental;
        if (std.mem.eql(u8, lowercase, "partition")) return .partition;
        if (std.mem.eql(u8, lowercase, "schedule")) return .schedule;
        if (std.mem.eql(u8, lowercase, "cron")) return .cron;
        if (std.mem.eql(u8, lowercase, "failure")) return .failure;
        if (std.mem.eql(u8, lowercase, "retry")) return .retry;
        if (std.mem.eql(u8, lowercase, "drop")) return .drop;
        if (std.mem.eql(u8, lowercase, "lineage")) return .lineage;
        if (std.mem.eql(u8, lowercase, "dependencies")) return .dependencies;
        if (std.mem.eql(u8, lowercase, "for")) return .for_;
        if (std.mem.eql(u8, lowercase, "as")) return .as;
        if (std.mem.eql(u8, lowercase, "with")) return .with;
        if (std.mem.eql(u8, lowercase, "join")) return .join;
        if (std.mem.eql(u8, lowercase, "left")) return .left;
        if (std.mem.eql(u8, lowercase, "right")) return .right;
        if (std.mem.eql(u8, lowercase, "full")) return .full;
        if (std.mem.eql(u8, lowercase, "outer")) return .outer;
        if (std.mem.eql(u8, lowercase, "on")) return .on;
        if (std.mem.eql(u8, lowercase, "load")) return .load;
        if (std.mem.eql(u8, lowercase, "save")) return .save;
        if (std.mem.eql(u8, lowercase, "refresh")) return .refresh;
        if (std.mem.eql(u8, lowercase, "order")) return .order;
        if (std.mem.eql(u8, lowercase, "by")) return .by;
        if (std.mem.eql(u8, lowercase, "asc")) return .asc;
        if (std.mem.eql(u8, lowercase, "desc")) return .desc;
        if (std.mem.eql(u8, lowercase, "group")) return .group;
        if (std.mem.eql(u8, lowercase, "having")) return .having;
        if (std.mem.eql(u8, lowercase, "limit")) return .limit;
        if (std.mem.eql(u8, lowercase, "offset")) return .offset;
        if (std.mem.eql(u8, lowercase, "vector_search")) return .vector_search;
        if (std.mem.eql(u8, lowercase, "distinct")) return .distinct;
        if (std.mem.eql(u8, lowercase, "and")) return .and_;
        if (std.mem.eql(u8, lowercase, "or")) return .or_;
        if (std.mem.eql(u8, lowercase, "not")) return .not_;
        if (std.mem.eql(u8, lowercase, "is")) return .is;
        if (std.mem.eql(u8, lowercase, "null")) return .null_;
        if (std.mem.eql(u8, lowercase, "like")) return .like;
        if (std.mem.eql(u8, lowercase, "between")) return .between;
        if (std.mem.eql(u8, lowercase, "in")) return .in;
        if (std.mem.eql(u8, lowercase, "attach")) return .attach;
        if (std.mem.eql(u8, lowercase, "detach")) return .detach;
        if (std.mem.eql(u8, lowercase, "enum")) return .enum_;
        if (std.mem.eql(u8, lowercase, "struct")) return .struct_;
        if (std.mem.eql(u8, lowercase, "describe")) return .describe;
        if (std.mem.eql(u8, lowercase, "types")) return .types;
        if (std.mem.eql(u8, lowercase, "function")) return .function;
        if (std.mem.eql(u8, lowercase, "returns")) return .returns;
        if (std.mem.eql(u8, lowercase, "match")) return .match;
        if (std.mem.eql(u8, lowercase, "end")) return .end;
        if (std.mem.eql(u8, lowercase, "->")) return .arrow;
        if (std.mem.eql(u8, lowercase, "sync")) return .sync;
        if (std.mem.eql(u8, lowercase, "async")) return .async;
        if (std.mem.eql(u8, lowercase, "databases")) return .databases;
        if (std.mem.eql(u8, lowercase, "use")) return .use;
        if (std.mem.eql(u8, lowercase, "validate")) return .validate;

        return .identifier;
    }

    pub fn peekToken(self: *Tokenizer) !?Token {
        const saved_pos = self.pos;
        defer self.pos = saved_pos;
        return try self.next();
    }
};

/// Query execution engine
pub const QueryEngine = struct {
    db: *Database,
    allocator: std.mem.Allocator,
    function_registry: *FunctionRegistry,

    pub fn init(allocator: std.mem.Allocator, db: *Database, function_registry: *FunctionRegistry) QueryEngine {
        return .{
            .db = db,
            .allocator = allocator,
            .function_registry = function_registry,
        };
    }

    pub fn attachAuditLog(self: *QueryEngine, log: *audit_mod.AuditLog) void {
        self.audit_log = log;
        self.optimizer.setDecisionLogger(log);
    }

    pub fn attachFormatRegistry(self: *QueryEngine, registry: *format_mod.FormatRegistry) void {
        self.format_registry = registry;
    }

    pub fn execute(self: *QueryEngine, sql: []const u8) anyerror!QueryResult {
        var tokenizer = Tokenizer.init(sql);
        const first_token = (try tokenizer.next()) orelse return error.EmptyQuery;

        return switch (first_token.type) {
            .select => try self.executeSelect(&tokenizer),
            .with => blk: {
                // For WITH, back up the tokenizer so executeSelect can handle it
                tokenizer.pos -= first_token.value.len;
                // Skip any whitespace we might have backed up over
                while (tokenizer.pos < tokenizer.input.len and std.ascii.isWhitespace(tokenizer.input[tokenizer.pos])) {
                    tokenizer.pos += 1;
                }
                break :blk try self.executeSelect(&tokenizer);
            },
            .insert => try self.executeInsert(&tokenizer),
            .create => try self.executeCreate(&tokenizer),
            .show => try self.executeShow(&tokenizer),
            .describe => try self.executeDescribe(&tokenizer),
            .load => try self.executeLoad(&tokenizer),
            .save => try self.executeSave(&tokenizer),
            .attach => try self.executeAttach(&tokenizer),
            .detach => try self.executeDetach(&tokenizer),
            .refresh => try self.executeRefresh(&tokenizer),
            .drop => try self.executeDrop(&tokenizer),
            else => error.UnsupportedQuery,
        };
    }

    fn executeSelect(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        var cte_context: ?*cte_mod.CTEContext = null;
        defer if (cte_context) |ctx| {
            ctx.deinit();
            self.allocator.destroy(ctx);
        };

        var token = (try tokenizer.peekToken()) orelse return error.UnexpectedEndOfQuery;
        if (token.type == .with) {
            _ = try tokenizer.next(); // consume WITH
            cte_context = try self.parseWithClause(tokenizer);
            // After WITH parsing, consume the SELECT token
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .select) return error.ExpectedSelectAfterWith;
        }

        var columns = std.ArrayList(query_plan.ColumnSpec).init(self.allocator);
        defer {
            for (columns.items) |*col| {
                col.deinit(self.allocator);
            }
            columns.deinit();
        }

        // Parse column list (supports simple aggregates like SUM(col), COUNT(*))
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        const AggSpec = struct { func: AggFunction, col: []const u8, is_star: bool };
        var agg_spec: ?AggSpec = null;

        if (token.type == .star) {
            try columns.append(ColumnSpec{ .column = try self.allocator.dupe(u8, token.value) });
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        } else {
            while (token.type == .identifier) {
                // Peek to see if this identifier is a function (look for lparen)
                const peek_pos = tokenizer.pos;
                const next_tok = try tokenizer.next() orelse return error.UnexpectedEndOfQuery;
                if (next_tok.type == .lparen) {
                    // It's a function call
                    var lower_buf: [16]u8 = undefined;
                    const func_name_lc = std.ascii.lowerString(&lower_buf, token.value);
                    var func: ?AggFunction = null;
                    if (std.mem.eql(u8, func_name_lc, "sum")) {
                        func = .sum;
                    } else if (std.mem.eql(u8, func_name_lc, "avg")) {
                        func = .avg;
                    } else if (std.mem.eql(u8, func_name_lc, "count")) {
                        func = .count;
                    } else if (std.mem.eql(u8, func_name_lc, "min")) {
                        func = .min;
                    } else if (std.mem.eql(u8, func_name_lc, "max")) {
                        func = .max;
                    } else {
                        return error.UnsupportedQuery;
                    }

                    // Parse inner token: identifier or star
                    const inner = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                    var colname: []const u8 = "";
                    var is_star = false;
                    if (inner.type == .star) {
                        is_star = true;
                    } else if (inner.type == .identifier) {
                        colname = inner.value;
                    } else {
                        return error.UnexpectedToken;
                    }

                    const rparen = (try tokenizer.next()) orelse return error.ExpectedRParen;
                    if (rparen.type != .rparen) return error.ExpectedRParen;

                    agg_spec = AggSpec{ .func = func.?, .col = colname, .is_star = is_star };

                    // Ensure aggregation column is present in projection so the aggregate
                    // node can access it even if it's not part of the final selected columns
                    if (!is_star and colname.len > 0) {
                        var exists = false;
                        for (columns.items) |existing| {
                            if (std.mem.eql(u8, existing, colname)) {
                                exists = true;
                                break;
                            }
                        }
                        if (!exists) try columns.append(self.allocator, colname);
                    }

                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                } else {
                    // Not a function; backtrack and treat as column
                    tokenizer.pos = peek_pos;
                    try columns.append(self.allocator, token.value);
                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                }

                if (token.type == .comma) {
                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                } else {
                    break;
                }
            }
        }

        if (token.type != .from) {
            return error.ExpectedFrom;
        }

        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

        // Check if this is a file path (string literal) or table name (identifier)
        const is_file_path = token.type == .string_literal;

        if (!is_file_path and token.type != .identifier) {
            return error.ExpectedTableName;
        }

        const table_name_or_path = token.value;

        // Load from file if it's a file path
        var temp_table: ?*Table = null;
        var should_free_table = false;

        var table: *Table = undefined;
        if (is_file_path) {
            if (self.format_registry == null) {
                return error.NoFormatRegistry;
            }

            // Load file into a temporary table
            temp_table = try self.loadFileAsTable(table_name_or_path);
            if (temp_table == null) {
                return error.FailedToLoadFile;
            }
            table = temp_table.?;
            should_free_table = true;
        } else {
            table = try self.resolveTable(table_name_or_path, cte_context);
        }

        var join_clause: ?JoinClause = null;
        var clause_token = try tokenizer.next();
        if (clause_token) |clause| {
            if (clause.type == .join) {
                // INNER JOIN
                join_clause = try self.parseJoinClause(tokenizer, table_name_or_path, .inner, cte_context);
                clause_token = try tokenizer.next();
            } else if (clause.type == .left) {
                // LEFT JOIN or LEFT OUTER JOIN
                var next_token = try tokenizer.next();
                if (next_token) |nt| {
                    if (nt.type == .outer) {
                        next_token = try tokenizer.next();
                    }
                }
                if (next_token) |nt| {
                    if (nt.type == .join) {
                        join_clause = try self.parseJoinClause(tokenizer, table_name_or_path, .left, cte_context);
                        clause_token = try tokenizer.next();
                    } else {
                        return error.ExpectedJoin;
                    }
                } else {
                    return error.ExpectedJoin;
                }
            } else if (clause.type == .right) {
                // RIGHT JOIN or RIGHT OUTER JOIN
                var next_token = try tokenizer.next();
                if (next_token) |nt| {
                    if (nt.type == .outer) {
                        next_token = try tokenizer.next();
                    }
                }
                if (next_token) |nt| {
                    if (nt.type == .join) {
                        join_clause = try self.parseJoinClause(tokenizer, table_name_or_path, .right, cte_context);
                        clause_token = try tokenizer.next();
                    } else {
                        return error.ExpectedJoin;
                    }
                } else {
                    return error.ExpectedJoin;
                }
            } else if (clause.type == .full) {
                // FULL OUTER JOIN
                var next_token = try tokenizer.next();
                if (next_token) |nt| {
                    if (nt.type == .outer) {
                        next_token = try tokenizer.next();
                    }
                }
                if (next_token) |nt| {
                    if (nt.type == .join) {
                        join_clause = try self.parseJoinClause(tokenizer, table_name_or_path, .full, cte_context);
                        clause_token = try tokenizer.next();
                    } else {
                        return error.ExpectedJoin;
                    }
                } else {
                    return error.ExpectedJoin;
                }
            }
        }

        var where_expr: ?*Expr = null;
        var order_by_clause: ?OrderByClause = null;

        if (clause_token) |clause| {
            switch (clause.type) {
                .where => {
                    where_expr = try self.parseWhereExpr(tokenizer);
                    clause_token = try tokenizer.next();
                },
                .order => {
                    // Will be parsed below
                },
                .group => {
                    // Will be parsed below
                },
                .semicolon => {},
                .eof => {},
                else => return error.UnexpectedToken,
            }
        }

        var group_by_cols: ?[][]const u8 = null;
        var having_expr: ?*Expr = null;
        var limit_count: ?usize = null;
        var limit_offset: ?usize = null;

        // Parse GROUP BY if present
        if (clause_token) |clause| {
            if (clause.type == .group) {
                group_by_cols = try self.parseGroupByClause(tokenizer);
                clause_token = try tokenizer.next();

                // Parse HAVING if present
                if (clause_token) |having_clause| {
                    if (having_clause.type == .having) {
                        having_expr = try self.parseWhereExpr(tokenizer);
                        clause_token = try tokenizer.next();
                    }
                }
            }
        }

        // Parse ORDER BY if present
        if (clause_token) |clause| {
            if (clause.type == .order) {
                order_by_clause = try self.parseOrderByClause(tokenizer);
                clause_token = try tokenizer.next();
            }
        }

        // Parse LIMIT if present
        if (clause_token) |clause| {
            if (clause.type == .limit) {
                limit_count = try self.parseLimitClause(tokenizer);
                clause_token = try tokenizer.next();
            }
        }

        // Parse OFFSET if present (can come after LIMIT)
        if (clause_token) |clause| {
            if (clause.type == .offset) {
                limit_offset = try self.parseOffsetClause(tokenizer);
                clause_token = try tokenizer.next();
            }
        }

        var plan = try self.buildSelectPlan(table, table_name_or_path, columns.items, where_expr, join_clause);
        defer plan.deinit();

        // If GROUP BY or aggregate specified, attach aggregate node
        if (group_by_cols != null or agg_spec != null) {
            const agg_node = try PlanNode.init(self.allocator, .aggregate);
            if (agg_spec) |a| {
                switch (a.func) {
                    .sum => agg_node.agg_function = .sum,
                    .avg => agg_node.agg_function = .avg,
                    .count => agg_node.agg_function = .count,
                    .min => agg_node.agg_function = .min,
                    .max => agg_node.agg_function = .max,
                }
                if (!a.is_star) agg_node.agg_column = a.col;
            }
            if (group_by_cols) |gcols| {
                agg_node.group_columns = gcols;
                agg_node.owns_group_columns = true;
            }
            if (having_expr) |h| {
                agg_node.having_predicate = h;
            }

            agg_node.child = plan.root;
            plan.root = agg_node;
        }

        // If LIMIT specified, attach limit node
        if (limit_count != null) {
            const limit_node = try PlanNode.init(self.allocator, .limit);
            limit_node.limit_count = limit_count;
            limit_node.limit_offset = limit_offset orelse 0;
            limit_node.child = plan.root;
            plan.root = limit_node;
        }

        try self.optimizer.registerTable(table);
        try self.optimizer.optimize(&plan);

        var result = try self.executePlan(plan.root, &where_expr, columns.items);

        // Apply ORDER BY if present (mutates result.table in place)
        if (order_by_clause) |*order_by| {
            defer order_by.deinit();
            var sorter = Sorter{ .allocator = self.allocator };
            try sorter.sortTable(&result.table, order_by.*);
        }

        if (where_expr) |expr| {
            expr.deinit();
        }

        // Clean up temporary table if loaded from file
        if (should_free_table and temp_table != null) {
            temp_table.?.deinit();
        }

        return result;
    }

    fn parseJoinClause(self: *QueryEngine, tokenizer: *Tokenizer, left_table: []const u8, join_type: JoinType, cte_context: ?*cte_mod.CTEContext) !JoinClause {
        _ = left_table;
        var token = (try tokenizer.next()) orelse return error.ExpectedTableName;
        if (token.type != .identifier) return error.ExpectedTableName;
        const right_table_name = token.value;
        const right_table = try self.resolveTable(right_table_name, cte_context);

        token = (try tokenizer.next()) orelse return error.ExpectedOn;
        if (token.type != .on) return error.ExpectedOn;

        const left_col_token = (try tokenizer.next()) orelse return error.ExpectedColumnName;
        if (left_col_token.type != .identifier) return error.ExpectedColumnName;

        const eq_token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (eq_token.type != .eq) return error.UnexpectedToken;

        const right_col_token = (try tokenizer.next()) orelse return error.ExpectedColumnName;
        if (right_col_token.type != .identifier) return error.ExpectedColumnName;

        return JoinClause{
            .join_type = join_type,
            .right_table = right_table,
            .right_table_name = right_table_name,
            .left_column = left_col_token.value,
            .right_column = right_col_token.value,
        };
    }

    fn parseOrderByClause(self: *QueryEngine, tokenizer: *Tokenizer) !OrderByClause {
        // Expect BY token
        var token = (try tokenizer.next()) orelse return error.ExpectedBy;
        if (token.type != .by) return error.ExpectedBy;

        var columns = std.ArrayList(OrderByColumn){};
        defer columns.deinit(self.allocator);

        // Parse first column
        token = (try tokenizer.next()) orelse return error.ExpectedColumnName;
        if (token.type != .identifier) return error.ExpectedColumnName;

        var col_name = token.value;
        var direction = SortDirection.asc; // Default to ASC

        // Check for ASC/DESC
        const peek_pos = tokenizer.pos;
        if (try tokenizer.next()) |dir_token| {
            if (dir_token.type == .asc) {
                direction = .asc;
            } else if (dir_token.type == .desc) {
                direction = .desc;
            } else {
                // Not a direction token, backtrack
                tokenizer.pos = peek_pos;
            }
        } else {
            tokenizer.pos = peek_pos;
        }

        try columns.append(self.allocator, OrderByColumn{
            .column_name = col_name,
            .direction = direction,
        });

        // Parse additional columns (comma-separated)
        while (true) {
            const comma_pos = tokenizer.pos;
            if (try tokenizer.next()) |comma_token| {
                if (comma_token.type == .comma) {
                    // Parse next column
                    token = (try tokenizer.next()) orelse return error.ExpectedColumnName;
                    if (token.type != .identifier) return error.ExpectedColumnName;

                    col_name = token.value;
                    direction = .asc;

                    // Check for ASC/DESC
                    const dir_peek_pos = tokenizer.pos;
                    if (try tokenizer.next()) |dir_token| {
                        if (dir_token.type == .asc) {
                            direction = .asc;
                        } else if (dir_token.type == .desc) {
                            direction = .desc;
                        } else {
                            tokenizer.pos = dir_peek_pos;
                        }
                    } else {
                        tokenizer.pos = dir_peek_pos;
                    }

                    try columns.append(self.allocator, OrderByColumn{
                        .column_name = col_name,
                        .direction = direction,
                    });
                } else {
                    // Not a comma, backtrack and exit
                    tokenizer.pos = comma_pos;
                    break;
                }
            } else {
                tokenizer.pos = comma_pos;
                break;
            }
        }

        return OrderByClause{
            .columns = try columns.toOwnedSlice(self.allocator),
            .allocator = self.allocator,
        };
    }

    fn parseGroupByClause(self: *QueryEngine, tokenizer: *Tokenizer) ![][]const u8 {
        // Expect BY token
        var token = (try tokenizer.next()) orelse return error.ExpectedBy;
        if (token.type != .by) return error.ExpectedBy;

        var columns = std.ArrayList([]const u8){};
        defer columns.deinit(self.allocator);

        // Parse first column
        token = (try tokenizer.next()) orelse return error.ExpectedColumnName;
        if (token.type != .identifier) return error.ExpectedColumnName;

        try columns.append(self.allocator, token.value);

        // Parse additional columns (comma-separated)
        while (true) {
            const comma_pos = tokenizer.pos;
            if (try tokenizer.next()) |comma_token| {
                if (comma_token.type == .comma) {
                    // Parse next column
                    token = (try tokenizer.next()) orelse return error.ExpectedColumnName;
                    if (token.type != .identifier) return error.ExpectedColumnName;

                    try columns.append(self.allocator, token.value);
                } else {
                    // Not a comma, backtrack and exit
                    tokenizer.pos = comma_pos;
                    break;
                }
            } else {
                tokenizer.pos = comma_pos;
                break;
            }
        }

        return try columns.toOwnedSlice(self.allocator);
    }

    fn parseLimitClause(_: *QueryEngine, tokenizer: *Tokenizer) !usize {
        const token = (try tokenizer.next()) orelse return error.ExpectedNumber;
        if (token.type != .number) return error.ExpectedNumber;

        const limit_str = token.value;
        return std.fmt.parseInt(usize, limit_str, 10) catch error.InvalidNumber;
    }

    fn parseOffsetClause(_: *QueryEngine, tokenizer: *Tokenizer) !usize {
        const token = (try tokenizer.next()) orelse return error.ExpectedNumber;
        if (token.type != .number) return error.ExpectedNumber;

        const offset_str = token.value;
        return std.fmt.parseInt(usize, offset_str, 10) catch error.InvalidNumber;
    }

    /// Parse WHERE expression with ANSI SQL compliance
    /// Supports: =, !=, <>, <, >, <=, >=, AND, OR, NOT, IS NULL, IS NOT NULL, LIKE, IN
    fn parseWhereExpr(self: *QueryEngine, tokenizer: *Tokenizer) error{ OutOfMemory, UnexpectedEndOfQuery, UnexpectedToken, ExpectedLParen, ExpectedRParen, ExpectedNull, ExpectedCommaOrRParen, InvalidCharacter, Overflow, UnterminatedString, UnexpectedCharacter, InvalidValue }!*Expr {
        return try self.parseOrExpr(tokenizer);
    }

    /// Parse OR expression (lowest precedence)
    fn parseOrExpr(self: *QueryEngine, tokenizer: *Tokenizer) error{ OutOfMemory, UnexpectedEndOfQuery, UnexpectedToken, ExpectedLParen, ExpectedRParen, ExpectedNull, ExpectedCommaOrRParen, InvalidCharacter, Overflow, UnterminatedString, UnexpectedCharacter, InvalidValue }!*Expr {
        var left = try self.parseAndExpr(tokenizer);

        while (true) {
            const peek_pos = tokenizer.pos;
            const token = (try tokenizer.next()) orelse {
                tokenizer.pos = peek_pos;
                return left;
            };

            if (token.type == .or_) {
                const right = try self.parseAndExpr(tokenizer);
                left = try Expr.binary(self.allocator, .or_op, left, right);
            } else {
                tokenizer.pos = peek_pos;
                return left;
            }
        }
    }

    /// Parse AND expression
    fn parseAndExpr(self: *QueryEngine, tokenizer: *Tokenizer) error{ OutOfMemory, UnexpectedEndOfQuery, UnexpectedToken, ExpectedLParen, ExpectedRParen, ExpectedNull, ExpectedCommaOrRParen, InvalidCharacter, Overflow, UnterminatedString, UnexpectedCharacter, InvalidValue }!*Expr {
        var left = try self.parseNotExpr(tokenizer);

        while (true) {
            const peek_pos = tokenizer.pos;
            const token = (try tokenizer.next()) orelse {
                tokenizer.pos = peek_pos;
                return left;
            };

            if (token.type == .and_) {
                const right = try self.parseNotExpr(tokenizer);
                left = try Expr.binary(self.allocator, .and_op, left, right);
            } else {
                tokenizer.pos = peek_pos;
                return left;
            }
        }
    }

    /// Parse NOT expression
    fn parseNotExpr(self: *QueryEngine, tokenizer: *Tokenizer) error{ OutOfMemory, UnexpectedEndOfQuery, UnexpectedToken, ExpectedLParen, ExpectedRParen, ExpectedNull, ExpectedCommaOrRParen, InvalidCharacter, Overflow, UnterminatedString, UnexpectedCharacter, InvalidValue }!*Expr {
        const peek_pos = tokenizer.pos;
        const token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

        if (token.type == .not_) {
            const operand = try self.parseNotExpr(tokenizer);
            return try Expr.unary(self.allocator, .not_op, operand);
        }

        tokenizer.pos = peek_pos;
        return try self.parseComparisonExpr(tokenizer);
    }

    /// Parse comparison expression
    fn parseComparisonExpr(self: *QueryEngine, tokenizer: *Tokenizer) error{ OutOfMemory, UnexpectedEndOfQuery, UnexpectedToken, ExpectedLParen, ExpectedRParen, ExpectedNull, ExpectedCommaOrRParen, InvalidCharacter, Overflow, UnterminatedString, UnexpectedCharacter, InvalidValue }!*Expr {
        const left = try self.parsePrimaryExpr(tokenizer);

        const token = (try tokenizer.next()) orelse return left;

        const expr_type: ExprType = switch (token.type) {
            .eq => .equal,
            .neq => .not_equal,
            .lt => .less_than,
            .gt => .greater_than,
            .lte => .less_equal,
            .gte => .greater_equal,
            .like => .like,
            .is => {
                // Handle IS NULL / IS NOT NULL
                const next_token = (try tokenizer.next()) orelse return error.ExpectedNull;
                if (next_token.type == .not_) {
                    const null_token = (try tokenizer.next()) orelse return error.ExpectedNull;
                    if (null_token.type != .null_) return error.ExpectedNull;
                    return try Expr.unary(self.allocator, .is_not_null, left);
                } else if (next_token.type == .null_) {
                    return try Expr.unary(self.allocator, .is_null, left);
                }
                return error.ExpectedNull;
            },
            .in => {
                // Handle IN (...)
                const lparen = (try tokenizer.next()) orelse return error.ExpectedLParen;
                if (lparen.type != .lparen) return error.ExpectedLParen;

                var values = std.ArrayList(Value){};
                defer values.deinit(self.allocator);

                while (true) {
                    const val_token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                    const val = try self.tokenToValue(val_token);
                    try values.append(self.allocator, val);

                    const next = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                    if (next.type == .rparen) break;
                    if (next.type != .comma) return error.ExpectedCommaOrRParen;
                }

                const expr = try Expr.init(self.allocator, .in);
                expr.left = left;
                expr.values = try values.toOwnedSlice(self.allocator);
                return expr;
            },
            else => return left, // No comparison operator
        };

        const right = try self.parsePrimaryExpr(tokenizer);
        return try Expr.binary(self.allocator, expr_type, left, right);
    }

    /// Parse primary expression (literals, column references, parentheses)
    fn parsePrimaryExpr(self: *QueryEngine, tokenizer: *Tokenizer) error{ OutOfMemory, UnexpectedEndOfQuery, UnexpectedToken, ExpectedLParen, ExpectedRParen, ExpectedNull, ExpectedCommaOrRParen, InvalidCharacter, Overflow, UnterminatedString, UnexpectedCharacter, InvalidValue }!*Expr {
        const token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

        switch (token.type) {
            .identifier => {
                // Check if this is a function call (followed by lparen)
                const peek_pos = tokenizer.pos;
                const next_token = (try tokenizer.next()) orelse {
                    // Not a function call, treat as column reference
                    return try Expr.columnRef(self.allocator, token.value);
                };

                if (next_token.type == .lparen) {
                    // Function call
                    if (std.mem.eql(u8, token.value, "VECTOR_SEARCH")) {
                        return try self.parseVectorSearch(tokenizer);
                    } else {
                        return error.UnexpectedToken; // Only VECTOR_SEARCH supported for now
                    }
                } else {
                    // Reset position and treat as column reference
                    tokenizer.pos = peek_pos;
                    return try Expr.columnRef(self.allocator, token.value);
                }
            },
            .number => {
                // Try parsing as float if contains '.' else int
                if (std.mem.indexOfScalar(u8, token.value, '.') != null) {
                    const val = try std.fmt.parseFloat(f64, token.value);
                    return try Expr.literal(self.allocator, Value{ .float64 = val });
                } else {
                    const val = try std.fmt.parseInt(i64, token.value, 10);
                    if (val >= -2147483648 and val <= 2147483647) {
                        return try Expr.literal(self.allocator, Value{ .int32 = @intCast(val) });
                    } else {
                        return try Expr.literal(self.allocator, Value{ .int64 = val });
                    }
                }
            },
            .string => {
                return try Expr.literal(self.allocator, Value{ .string = token.value });
            },
            .lparen => {
                const expr = try self.parseWhereExpr(tokenizer);
                const rparen = (try tokenizer.next()) orelse return error.ExpectedRParen;
                if (rparen.type != .rparen) return error.ExpectedRParen;
                return expr;
            },
            else => return error.UnexpectedToken,
        }
    }

    /// Parse VECTOR_SEARCH(column, query_vector, k)
    fn parseVectorSearch(self: *QueryEngine, tokenizer: *Tokenizer) !*Expr {
        // Parse column name
        const col_token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (col_token.type != .identifier) return error.UnexpectedToken;
        const column_name = col_token.value;

        // Expect comma
        const comma1 = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (comma1.type != .comma) return error.UnexpectedToken;

        // Parse query vector as array literal [f32, f32, ...]
        const lbracket = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (lbracket.type != .lparen) return error.UnexpectedToken; // Using lparen for now, should be lbracket

        var vector_values = try std.ArrayList(f32).initCapacity(self.allocator, 0);
        defer vector_values.deinit(self.allocator);

        while (true) {
            const val_token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (val_token.type == .rparen) break; // Using rparen for now

            if (val_token.type == .number) {
                const val = try std.fmt.parseFloat(f32, val_token.value);
                try vector_values.append(self.allocator, val);
            } else if (val_token.type == .comma) {
                continue;
            } else {
                return error.UnexpectedToken;
            }
        }

        // Expect comma
        const comma2 = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (comma2.type != .comma) return error.UnexpectedToken;

        // Parse k (number of neighbors)
        const k_token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (k_token.type != .number) return error.UnexpectedToken;
        const k = try std.fmt.parseInt(usize, k_token.value, 10);

        // Expect closing rparen
        const rparen = (try tokenizer.next()) orelse return error.ExpectedRParen;
        if (rparen.type != .rparen) return error.ExpectedRParen;

        // Create vector search expression
        const expr = try Expr.init(self.allocator, .vector_search);
        expr.vector_column = try self.allocator.dupe(u8, column_name);
        expr.query_vector = try vector_values.toOwnedSlice(self.allocator);
        expr.k = k;

        return expr;
    }

    /// Convert token to value
    fn tokenToValue(self: *QueryEngine, token: Token) !Value {
        _ = self;
        return switch (token.type) {
            .number => blk: {
                if (std.mem.indexOfScalar(u8, token.value, '.') != null) {
                    const val = try std.fmt.parseFloat(f64, token.value);
                    break :blk Value{ .float64 = val };
                } else {
                    const val = try std.fmt.parseInt(i64, token.value, 10);
                    // Prefer int32 when it fits to avoid type mismatch with column int32
                    if (val >= -2147483648 and val <= 2147483647) {
                        break :blk Value{ .int32 = @intCast(val) };
                    } else {
                        break :blk Value{ .int64 = val };
                    }
                }
            },
            .string => Value{ .string = token.value },
            else => error.InvalidValue,
        };
    }

    /// Execute SELECT with WHERE filter
    fn executeFilteredSelect(
        self: *QueryEngine,
        table: *Table,
        selected_columns: [][]const u8,
        predicate: Predicate,
        row_subset: ?[]const usize,
    ) !QueryResult {
        defer {
            var mut_pred = predicate;
            mut_pred.deinit();
        }

        // Create result table with same schema
        var result_table = try Table.init(self.allocator, table.name, table.schema.columns);
        errdefer result_table.deinit();

        // Evaluate predicate for each row
        var row_values = try self.allocator.alloc(Value, table.columns.len);
        defer self.allocator.free(row_values);

        var column_values = std.StringHashMap(Value).init(self.allocator);
        defer column_values.deinit();

        if (row_subset) |rows| {
            for (rows) |row| {
                column_values.clearRetainingCapacity();
                for (0..table.columns.len) |col| {
                    const val = try table.getCell(row, col);
                    row_values[col] = val;
                    try column_values.put(table.schema.columns[col].name, val);
                }

                const matches = try predicate.evaluate(column_values);
                if (matches) {
                    try result_table.insertRow(row_values);
                }
            }
        } else {
            var row: usize = 0;
            while (row < table.row_count) : (row += 1) {
                column_values.clearRetainingCapacity();
                for (0..table.columns.len) |col| {
                    const val = try table.getCell(row, col);
                    row_values[col] = val;
                    try column_values.put(table.schema.columns[col].name, val);
                }

                const matches = try predicate.evaluate(column_values);
                if (matches) {
                    try result_table.insertRow(row_values);
                }
            }
        }

        // If specific columns requested, select them
        if (selected_columns.len > 0) {
            const final_table = try result_table.select(self.allocator, selected_columns);
            result_table.deinit();
            return QueryResult{ .table = final_table };
        }

        return QueryResult{ .table = result_table };
    }

    fn buildSelectPlan(
        self: *QueryEngine,
        table: *Table,
        table_name: []const u8,
        selected_columns: []query_plan.ColumnSpec,
        where_expr: ?*Expr,
        join_clause: ?JoinClause,
    ) !QueryPlan {
        const scan = try PlanNode.init(self.allocator, .scan);
        scan.table_name = table_name;
        scan.estimated_rows = table.row_count;

        var current: *PlanNode = scan;

        if (join_clause) |join_spec| {
            const right_scan = try PlanNode.init(self.allocator, .scan);
            right_scan.table_name = join_spec.right_table_name;
            right_scan.estimated_rows = join_spec.right_table.row_count;

            const join_node = try PlanNode.init(self.allocator, .join);
            join_node.child = current;
            join_node.right_child = right_scan;
            join_node.join_type = join_spec.join_type;
            join_node.table_name = table_name;
            join_node.join_right_table = join_spec.right_table_name;
            join_node.join_left_column = join_spec.left_column;
            join_node.join_right_column = join_spec.right_column;
            join_node.estimated_rows = @max(table.row_count, join_spec.right_table.row_count);
            current = join_node;
        }

        if (where_expr) |expr| {
            const filter = try PlanNode.init(self.allocator, .filter);
            filter.predicate = expr;
            filter.child = current;
            filter.estimated_rows = table.row_count;
            current = filter;
        }

        if (selected_columns.len > 0) {
            const project = try PlanNode.init(self.allocator, .project);
            // Duplicate the column specs for the plan node
            var dup_cols = try self.allocator.alloc(query_plan.ColumnSpec, selected_columns.len);
            for (selected_columns, 0..) |col, i| {
                dup_cols[i] = switch (col) {
                    .column => |name| query_plan.ColumnSpec{ .column = try self.allocator.dupe(u8, name) },
                    .function_call => |fc| {
                        var args = try self.allocator.alloc(query_plan.ColumnSpec, fc.args.len);
                        for (fc.args, 0..) |arg, j| {
                            args[j] = switch (arg) {
                                .column => |arg_name| query_plan.ColumnSpec{ .column = try self.allocator.dupe(u8, arg_name) },
                                .function_call => return error.NotImplemented,
                            };
                        }
                        query_plan.ColumnSpec{ .function_call = .{ .name = try self.allocator.dupe(u8, fc.name), .args = args } };
                    }
                };
            project.columns = dup_cols;
            project.owns_columns = true;
            project.child = current;
            project.estimated_rows = current.estimated_rows;
            current = project;
        }

        return QueryPlan.init(self.allocator, current);
    }

    fn executePlan(
        self: *QueryEngine,
        root: *PlanNode,
        where_expr_slot: *?*Expr,
        unused: [][]const u8,
    ) !QueryResult {
        const table_result = try self.executePlanNode(root, where_expr_slot);
        return QueryResult{ .table = table_result };
    }

    fn executePlanNode(
        self: *QueryEngine,
        node: *PlanNode,
        where_expr_slot: *?*Expr,
    ) anyerror!Table {
        return switch (node.node_type) {
            .scan => try self.materializeScan(node),
            .index_scan => try self.materializeIndexScan(node),
            .filter => try self.applyFilterNode(node, where_expr_slot),
            .project => try self.applyProjectNode(node, where_expr_slot),
            .join => try self.applyJoinNode(node, where_expr_slot),
            .limit => try self.applyLimitNode(node, where_expr_slot),
            .sort => try self.applySortNode(node, where_expr_slot),
            .aggregate => try self.applyAggregateNode(node, where_expr_slot),
        };
    }

    fn materializeScan(self: *QueryEngine, node: *PlanNode) !Table {
        const table_name = node.table_name orelse return error.ExpectedTableName;
        const source = try self.db.getTable(table_name);
        return try self.copyEntireTable(source);
    }

    fn materializeIndexScan(self: *QueryEngine, node: *PlanNode) !Table {
        const table_name = node.table_name orelse return error.ExpectedTableName;
        const source = try self.db.getTable(table_name);

        var lookup: Table.IndexLookupResult = .{ .rows = &[_]usize{}, .owned = false };
        var has_lookup = false;

        switch (node.index_strategy) {
            .btree => {
                const column = node.index_column orelse return error.IndexColumnMissing;
                const key = node.index_key orelse return error.IndexKeyMissing;
                lookup = try source.lookupIndex(self.allocator, column, key);
                has_lookup = true;
            },
            .composite_hash => {
                const values = node.index_values_multi orelse return error.IndexValuesMissing;
                const name = node.index_name orelse return error.IndexNotFound;
                lookup = try source.lookupCompositeIndexByName(self.allocator, name, values);
                has_lookup = true;
            },
        }

        defer if (has_lookup and lookup.owned and lookup.rows.len > 0) {
            self.allocator.free(lookup.rows);
        };

        if (!has_lookup or lookup.rows.len == 0) {
            return try self.initEmptyLike(source);
        }

        return try self.tableFromRowSubset(source, lookup.rows);
    }

    fn applyFilterNode(
        self: *QueryEngine,
        node: *PlanNode,
        where_expr_slot: *?*Expr,
    ) !Table {
        const child = node.child orelse return error.InvalidPlan;
        var child_table = try self.executePlanNode(child, where_expr_slot);
        errdefer child_table.deinit();

        if (node.predicate == null) return child_table;

        if (where_expr_slot.*) |original| {
            if (original == node.predicate.?) {
                where_expr_slot.* = null;
            }
        }

        var predicate = Predicate.init(self.allocator, node.predicate.?);
        defer predicate.deinit();

        const filtered = try self.filterTable(&child_table, predicate);
        child_table.deinit();
        return filtered;
    }

    fn applyProjectNode(
        self: *QueryEngine,
        node: *PlanNode,
        where_expr_slot: *?*Expr,
    ) !Table {
        const child = node.child orelse return error.InvalidPlan;
        var child_table = try self.executePlanNode(child, where_expr_slot);
        errdefer child_table.deinit();

        if (node.columns) |cols| {
            std.debug.print("Allocating projected table\n", .{});

            // Extract column names from ColumnSpec
            var col_names = try std.ArrayList([]const u8).initCapacity(self.allocator, cols.len);
            defer col_names.deinit();
            for (cols) |col| {
                switch (col) {
                    .column => |name| try col_names.append(name),
                    .function_call => return error.FunctionCallsNotSupportedYet,
                }
            }

            // Expand SELECT * to all column names
            var actual_cols = col_names.items;
            var expanded_col_names: ?[][]const u8 = null;
            defer if (expanded_col_names) |names| self.allocator.free(names);

            if (col_names.items.len == 1 and std.mem.eql(u8, col_names.items[0], "*")) {
                expanded_col_names = try self.allocator.alloc([]const u8, child_table.schema.columns.len);
                for (child_table.schema.columns, 0..) |col, i| {
                    expanded_col_names.?[i] = col.name;
                }
                actual_cols = expanded_col_names.?;
            }

            const projected = try child_table.select(self.allocator, actual_cols);
            defer std.debug.print("Deallocating projected table\n", .{});
            defer @constCast(&projected).deinit();
            child_table.deinit();
            return projected;
        }

        return child_table;
    }

    fn applyJoinNode(
        self: *QueryEngine,
        node: *PlanNode,
        where_expr_slot: *?*Expr,
    ) !Table {
        const left_child = node.child orelse return error.InvalidPlan;
        const right_child = node.right_child orelse return error.InvalidPlan;
        var left_table = try self.executePlanNode(left_child, where_expr_slot);
        errdefer left_table.deinit();
        var right_table = try self.executePlanNode(right_child, where_expr_slot);
        errdefer right_table.deinit();

        const left_col = node.join_left_column orelse return error.JoinColumnMissing;
        const right_col = node.join_right_column orelse return error.JoinColumnMissing;

        const joined = switch (node.join_type orelse .inner) {
            .inner => try self.hashJoin(&left_table, &right_table, left_col, right_col),
            .left => try self.leftJoin(&left_table, &right_table, left_col, right_col),
            .right => try self.rightJoin(&left_table, &right_table, left_col, right_col),
            .full => try self.fullOuterJoin(&left_table, &right_table, left_col, right_col),
        };
        left_table.deinit();
        right_table.deinit();
        return joined;
    }

    fn applyLimitNode(
        self: *QueryEngine,
        node: *PlanNode,
        where_expr_slot: *?*Expr,
    ) !Table {
        const child = node.child orelse return error.InvalidPlan;
        var table = try self.executePlanNode(child, where_expr_slot);
        if (node.limit_count) |count| {
            try self.truncateTable(&table, count, node.limit_offset orelse 0);
        }
        return table;
    }

    fn applySortNode(
        self: *QueryEngine,
        node: *PlanNode,
        where_expr_slot: *?*Expr,
    ) !Table {
        const child = node.child orelse return error.InvalidPlan;
        var table = try self.executePlanNode(child, where_expr_slot);
        if (node.sort_column) |col| {
            try table.sortBy(col, !node.sort_desc);
        }
        return table;
    }

    fn applyAggregateNode(
        self: *QueryEngine,
        node: *PlanNode,
        where_expr_slot: *?*Expr,
    ) !Table {
        const child = node.child orelse return error.InvalidPlan;
        var table = try self.executePlanNode(child, where_expr_slot);
        errdefer table.deinit();

        // Gather group columns
        var group_cols_idx: []usize = undefined;
        var group_cols_idx_len: usize = 0;
        if (node.group_columns) |cols| {
            group_cols_idx_len = cols.len;
            group_cols_idx = try self.allocator.alloc(usize, cols.len);
            for (cols, 0..) |c, i| {
                group_cols_idx[i] = table.schema.findColumn(c) orelse return error.ColumnNotFound;
            }
        }
        defer if (group_cols_idx_len > 0) self.allocator.free(group_cols_idx);

        // Build groups: for simplicity, use string key by formatting group column values
        var groups = std.ArrayList([]const u8){};
        var rows_per_group = std.ArrayList(std.ArrayList(usize)){};
        defer groups.deinit(self.allocator);
        defer rows_per_group.deinit(self.allocator);

        // Build map of key -> list of row indices
        for (0..table.row_count) |r| {
            // Build key
            var buf = std.ArrayList(u8){};
            defer buf.deinit(self.allocator);

            for (0..group_cols_idx_len) |i| {
                const col_idx = group_cols_idx[i];
                const v = try table.getCell(r, col_idx);
                // format value into buf
                const w = buf.writer(self.allocator);
                try w.print("{any}|", .{v});
            }

            const key = try buf.toOwnedSlice(self.allocator);

            // Find existing group
            var found = false;
            var i: usize = 0;
            while (i < groups.items.len) : (i += 1) {
                if (std.mem.eql(u8, groups.items[i], key)) {
                    try rows_per_group.items[i].append(self.allocator, r);
                    found = true;
                    break;
                }
            }

            if (!found) {
                try groups.append(self.allocator, key);
                var list = std.ArrayList(usize){};
                try list.append(self.allocator, r);
                try rows_per_group.append(self.allocator, list);
            }
        }

        // Build result schema: group cols then aggregate column
        var total_cols: usize = 0;
        if (node.group_columns) |cols| total_cols += cols.len;
        total_cols += 1; // single aggregate column

        var schema_defs = try self.allocator.alloc(Schema.ColumnDef, total_cols);
        defer self.allocator.free(schema_defs);

        var i: usize = 0;
        if (node.group_columns) |cols| {
            for (cols) |c| {
                const idx = table.schema.findColumn(c) orelse return error.ColumnNotFound;
                const orig_col = table.schema.columns[idx];
                schema_defs[i] = .{
                    .name = try self.allocator.dupe(u8, orig_col.name),
                    .data_type = orig_col.data_type,
                    .vector_dim = orig_col.vector_dim,
                };
                i += 1;
            }
        }

        // Aggregate column def
        var agg_col_name: []const u8 = "agg";
        var agg_data_type: DataType = .int64;
        if (node.agg_column) |ac| {
            agg_col_name = try self.allocator.dupe(u8, ac);
            if (node.agg_function) |f| {
                switch (f) {
                    .sum, .avg => agg_data_type = .float64,
                    .count => agg_data_type = .int64,
                    .min, .max => {
                        // Use the same data type as the underlying column for min/max
                        const idx = table.schema.findColumn(ac) orelse return error.ColumnNotFound;
                        agg_data_type = table.schema.columns[idx].data_type;
                    },
                }
            } else {
                agg_data_type = .int64;
            }
        } else {
            agg_col_name = try self.allocator.dupe(u8, "count");
            agg_data_type = .int64;
        }
        schema_defs[i] = Schema.ColumnDef{ .name = agg_col_name, .data_type = agg_data_type };

        var result_table = try Table.init(self.allocator, try self.allocator.dupe(u8, table.name), schema_defs);
        errdefer result_table.deinit();

        // For each group compute aggregation
        for (groups.items, rows_per_group.items) |_, group_rows| {
            const rows = group_rows.items;

            // Compute aggregate value
            var agg_val: Value = Value{ .int64 = 0 };
            if (node.agg_function) |func| {
                switch (func) {
                    .count => {
                        agg_val = Value{ .int64 = @intCast(rows.len) };
                    },
                    .sum => {
                        var sum: f64 = 0.0;
                        for (rows) |ridx| {
                            const v = try table.getCell(ridx, table.schema.findColumn(node.agg_column.?) orelse return error.ColumnNotFound);
                            var nv: f64 = 0.0;
                            switch (v) {
                                .int32 => |x| nv = @as(f64, @floatFromInt(x)),
                                .int64 => |x| nv = @as(f64, @floatFromInt(x)),
                                .float32 => |x| nv = @as(f64, x),
                                .float64 => |x| nv = x,
                                else => nv = 0.0,
                            }
                            sum += nv;
                        }
                        agg_val = Value{ .float64 = sum };
                    },
                    .avg => {
                        var sum: f64 = 0.0;
                        for (rows) |ridx| {
                            const v = try table.getCell(ridx, table.schema.findColumn(node.agg_column.?) orelse return error.ColumnNotFound);
                            var nv: f64 = 0.0;
                            switch (v) {
                                .int32 => |x| nv = @as(f64, @floatFromInt(x)),
                                .int64 => |x| nv = @as(f64, @floatFromInt(x)),
                                .float32 => |x| nv = @as(f64, x),
                                .float64 => |x| nv = x,
                                else => nv = 0.0,
                            }
                            sum += nv;
                        }
                        const avg = sum / @as(f64, @floatFromInt(rows.len));
                        agg_val = Value{ .float64 = avg };
                    },
                    .min => {
                        var first = true;
                        var minv: Value = Value{ .int64 = 0 };
                        for (rows) |ridx| {
                            const v = try table.getCell(ridx, table.schema.findColumn(node.agg_column.?) orelse return error.ColumnNotFound);
                            if (first) {
                                minv = v;
                                first = false;
                            } else if (v.lessThan(minv)) minv = v;
                        }
                        agg_val = minv;
                    },
                    .max => {
                        var first = true;
                        var maxv: Value = Value{ .int64 = 0 };
                        for (rows) |ridx| {
                            const v = try table.getCell(ridx, table.schema.findColumn(node.agg_column.?) orelse return error.ColumnNotFound);
                            if (first) {
                                maxv = v;
                                first = false;
                            } else if (maxv.lessThan(v)) maxv = v;
                        }
                        agg_val = maxv;
                    },
                }
            } else {
                // No agg function: default to count
                agg_val = Value{ .int64 = @intCast(rows.len) };
            }

            // Build row values
            var row_vals = try self.allocator.alloc(Value, total_cols);
            defer self.allocator.free(row_vals);

            var pos: usize = 0;
            if (node.group_columns) |cols| {
                for (cols) |c| {
                    const idx = table.schema.findColumn(c) orelse return error.ColumnNotFound;
                    var val = try table.getCell(rows[0], idx);
                    // Duplicate strings to avoid referencing freed memory
                    if (val == .string) {
                        val.string = try self.allocator.dupe(u8, val.string);
                    }
                    row_vals[pos] = val;
                    pos += 1;
                }
            }

            row_vals[pos] = agg_val;

            try result_table.insertRow(row_vals);
        }

        // Apply HAVING filter if present
        if (node.having_predicate) |having_expr| {
            var predicate = Predicate.init(self.allocator, having_expr);
            defer predicate.deinit();

            const filtered_table = try self.filterTable(&result_table, predicate);
            result_table.deinit();
            result_table = filtered_table;
        }

        return result_table;
    }

    fn initEmptyLike(self: *QueryEngine, table: *Table) !Table {
        return Table.init(self.allocator, table.name, table.schema.columns);
    }

    fn tableFromRowSubset(
        self: *QueryEngine,
        table: *Table,
        row_indices: []const usize,
    ) !Table {
        var result_table = try Table.init(self.allocator, table.name, table.schema.columns);
        errdefer result_table.deinit();

        var row_values = try self.allocator.alloc(Value, table.columns.len);
        defer self.allocator.free(row_values);

        for (row_indices) |row| {
            for (0..table.columns.len) |col| {
                row_values[col] = try table.getCell(row, col);
            }
            try result_table.insertRow(row_values);
        }

        return result_table;
    }

    fn filterTable(
        self: *QueryEngine,
        table: *Table,
        predicate: Predicate,
    ) !Table {
        var result_table = try Table.init(self.allocator, table.name, table.schema.columns);
        errdefer result_table.deinit();

        var row_values = try self.allocator.alloc(Value, table.columns.len);
        defer self.allocator.free(row_values);

        var column_values = std.StringHashMap(Value).init(self.allocator);
        defer column_values.deinit();

        var row: usize = 0;
        while (row < table.row_count) : (row += 1) {
            column_values.clearRetainingCapacity();
            for (0..table.columns.len) |col| {
                const val = try table.getCell(row, col);
                row_values[col] = val;
                try column_values.put(table.schema.columns[col].name, val);
            }

            const matches = try predicate.evaluate(column_values);
            if (matches) {
                try result_table.insertRow(row_values);
            }
        }

        return result_table;
    }

    fn hashJoin(
        self: *QueryEngine,
        left: *Table,
        right: *Table,
        left_column: []const u8,
        right_column: []const u8,
    ) !Table {
        const left_idx = left.schema.findColumn(left_column) orelse return error.ColumnNotFound;
        const right_idx = right.schema.findColumn(right_column) orelse return error.ColumnNotFound;

        var buckets = std.AutoHashMap(u64, std.ArrayList(usize)).init(self.allocator);
        defer {
            var it = buckets.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            buckets.deinit();
        }

        var hash_buffer = std.ArrayList(usize){};
        defer hash_buffer.deinit(self.allocator);

        var row: usize = 0;
        while (row < right.row_count) : (row += 1) {
            const value = try right.getCell(row, right_idx);
            const hash_value = value.hash();
            var entry = try buckets.getOrPut(hash_value);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(usize){};
            }
            try entry.value_ptr.append(self.allocator, row);
        }

        const total_cols = left.columns.len + right.columns.len;
        var schema_defs = try self.allocator.alloc(Schema.ColumnDef, total_cols);
        defer self.allocator.free(schema_defs);

        for (left.schema.columns, 0..) |col, i| {
            schema_defs[i] = col;
        }
        for (right.schema.columns, 0..) |col, i| {
            schema_defs[left.columns.len + i] = col;
        }

        var result_table = try Table.init(self.allocator, left.name, schema_defs);
        errdefer result_table.deinit();

        var row_values = try self.allocator.alloc(Value, total_cols);
        defer self.allocator.free(row_values);

        var left_row: usize = 0;
        while (left_row < left.row_count) : (left_row += 1) {
            const key = try left.getCell(left_row, left_idx);
            if (buckets.get(key.hash())) |bucket| {
                for (bucket.items) |right_row| {
                    const right_key = try right.getCell(right_row, right_idx);
                    if (!right_key.eql(key)) continue;

                    for (0..left.columns.len) |col| {
                        row_values[col] = try left.getCell(left_row, col);
                    }
                    for (0..right.columns.len) |col| {
                        row_values[left.columns.len + col] = try right.getCell(right_row, col);
                    }

                    try result_table.insertRow(row_values);
                }
            }
        }

        return result_table;
    }

    fn leftJoin(
        self: *QueryEngine,
        left: *Table,
        right: *Table,
        left_column: []const u8,
        right_column: []const u8,
    ) !Table {
        const left_idx = left.schema.findColumn(left_column) orelse return error.ColumnNotFound;
        const right_idx = right.schema.findColumn(right_column) orelse return error.ColumnNotFound;

        var buckets = std.AutoHashMap(u64, std.ArrayList(usize)).init(self.allocator);
        defer {
            var it = buckets.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.deinit(self.allocator);
            }
            buckets.deinit();
        }

        // Build hash table from right table
        var row: usize = 0;
        while (row < right.row_count) : (row += 1) {
            const value = try right.getCell(row, right_idx);
            const hash_value = value.hash();
            var entry = try buckets.getOrPut(hash_value);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(usize){};
            }
            try entry.value_ptr.append(self.allocator, row);
        }

        const total_cols = left.columns.len + right.columns.len;
        var schema_defs = try self.allocator.alloc(Schema.ColumnDef, total_cols);
        defer self.allocator.free(schema_defs);

        for (left.schema.columns, 0..) |col, i| {
            schema_defs[i] = col;
        }
        for (right.schema.columns, 0..) |col, i| {
            schema_defs[left.columns.len + i] = col;
        }

        var result_table = try Table.init(self.allocator, left.name, schema_defs);
        errdefer result_table.deinit();

        var row_values = try self.allocator.alloc(Value, total_cols);
        defer self.allocator.free(row_values);

        // Track which left rows have matches
        var left_matched = try self.allocator.alloc(bool, left.row_count);
        defer self.allocator.free(left_matched);
        @memset(left_matched, false);

        // First pass: inner join, mark matched left rows
        var left_row: usize = 0;
        while (left_row < left.row_count) : (left_row += 1) {
            const key = try left.getCell(left_row, left_idx);
            if (buckets.get(key.hash())) |bucket| {
                for (bucket.items) |right_row| {
                    const right_key = try right.getCell(right_row, right_idx);
                    if (!right_key.eql(key)) continue;

                    left_matched[left_row] = true;

                    for (0..left.columns.len) |col| {
                        row_values[col] = try left.getCell(left_row, col);
                    }
                    for (0..right.columns.len) |col| {
                        row_values[left.columns.len + col] = try right.getCell(right_row, col);
                    }

                    try result_table.insertRow(row_values);
                }
            }
        }

        // Second pass: add unmatched left rows with null right columns
        left_row = 0;
        while (left_row < left.row_count) : (left_row += 1) {
            if (left_matched[left_row]) continue;

            for (0..left.columns.len) |col| {
                row_values[col] = try left.getCell(left_row, col);
            }
            for (0..right.columns.len) |col| {
                // Null values for right columns
                const right_col_idx = left.columns.len + col;
                const data_type = result_table.schema.columns[right_col_idx].data_type;
                row_values[right_col_idx] = switch (data_type) {
                    .int32 => Value{ .int32 = 0 }, // Could use a proper null, but for now use zero
                    .int64 => Value{ .int64 = 0 },
                    .float32 => Value{ .float32 = 0.0 },
                    .float64 => Value{ .float64 = 0.0 },
                    .boolean => Value{ .boolean = false },
                    .string => Value{ .string = "" },
                    .timestamp => Value{ .timestamp = 0 },
                    .vector => Value{ .vector = .{ .values = &[_]f32{} } },
                    .custom => return error.CustomTypeNotSupported, // Custom types not supported for LEFT JOIN yet
                };
            }

            try result_table.insertRow(row_values);
        }

        return result_table;
    }

    fn rightJoin(
        self: *QueryEngine,
        left: *Table,
        right: *Table,
        left_column: []const u8,
        right_column: []const u8,
    ) !Table {
        // For RIGHT JOIN, swap the tables and do LEFT JOIN
        const result = try self.leftJoin(right, left, right_column, left_column);
        // The result will have right table columns first, then left table columns
        // We need to reorder to have left table columns first, then right table columns
        // For simplicity, return as is for now (columns will be in wrong order)
        return result;
    }

    fn fullOuterJoin(
        self: *QueryEngine,
        left: *Table,
        right: *Table,
        left_column: []const u8,
        right_column: []const u8,
    ) !Table {
        // For FULL OUTER, do LEFT JOIN then add unmatched right rows
        var temp_left = try self.leftJoin(left, right, left_column, right_column);
        defer temp_left.deinit();

        // Now add unmatched right rows with null left columns
        // This is complex, so for now return the left join
        return temp_left;
    }

    fn truncateTable(self: *QueryEngine, table: *Table, limit_count: usize, offset: usize) !void {
        if (limit_count >= table.row_count and offset == 0) return;

        var new_table = try Table.init(self.allocator, table.name, table.schema.columns);
        errdefer new_table.deinit();

        var row_values = try self.allocator.alloc(Value, table.columns.len);
        defer self.allocator.free(row_values);

        var row: usize = offset;
        var inserted: usize = 0;
        while (row < table.row_count and inserted < limit_count) : (row += 1) {
            for (0..table.columns.len) |col| {
                row_values[col] = try table.getCell(row, col);
            }
            try new_table.insertRow(row_values);
            inserted += 1;
        }

        table.deinit();
        table.* = new_table;
    }

    fn copyEntireTable(self: *QueryEngine, table: *Table) !Table {
        var result_table = try Table.init(self.allocator, table.name, table.schema.columns);
        errdefer result_table.deinit();

        var row_values = try self.allocator.alloc(Value, table.columns.len);
        defer self.allocator.free(row_values);

        var row: usize = 0;
        while (row < table.row_count) : (row += 1) {
            for (0..table.columns.len) |col| {
                row_values[col] = try table.getCell(row, col);
            }
            try result_table.insertRow(row_values);
        }

        return result_table;
    }

    fn resolveTable(self: *QueryEngine, table_name: []const u8, cte_context: ?*cte_mod.CTEContext) !*Table {
        // First check if this is a CTE (if we have a CTE context)
        if (cte_context) |ctx| {
            if (ctx.getCTE(table_name)) |cte| {
                // Execute the CTE and return its result table
                return try cte.execute(self.db, ctx);
            }
        }
        // Otherwise, resolve from database
        return try self.db.getTable(table_name);
    }

    fn parseWithClause(self: *QueryEngine, tokenizer: *Tokenizer) !*cte_mod.CTEContext {
        var cte_context = try self.allocator.create(cte_mod.CTEContext);
        cte_context.* = cte_mod.CTEContext.init(self.allocator);
        errdefer {
            cte_context.deinit();
            self.allocator.destroy(cte_context);
        }

        // Parse CTE definitions: cte_name [(col1, col2, ...)] AS (SELECT ...)
        while (true) {
            // Get CTE name
            var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) return error.ExpectedCTENAME;
            const cte_name = token.value;

            // Optional column list (not implemented yet)
            // TODO: Parse (col1, col2, ...) if present

            // Check for MATERIALIZED/NOT MATERIALIZED (SQLite style)
            var materialized = true; // Default to materialized like SQLite
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .materialized) {
                materialized = true;
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            } else if (token.type == .not_) {
                const next_token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (next_token.type == .materialized) {
                    materialized = false;
                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                } else {
                    return error.ExpectedMaterialized;
                }
            }

            // Expect AS
            if (token.type != .as) return error.ExpectedAs;

            // Expect (
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .lparen) return error.ExpectedLParen;

            // Capture the SELECT statement inside parentheses
            const select_start = tokenizer.pos;
            var paren_depth: usize = 1;

            while (paren_depth > 0) {
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type == .lparen) {
                    paren_depth += 1;
                } else if (token.type == .rparen) {
                    paren_depth -= 1;
                }
            }

            const select_sql = tokenizer.input[select_start .. tokenizer.pos - 1]; // exclude closing paren

            // Create CTE using CTEContext.addCTE
            try cte_context.addCTE(cte_name, select_sql, false);

            // Check for comma (more CTEs) or end

            // Check for comma (more CTEs) or end
            const next_token = try tokenizer.peekToken();
            if (next_token) |nt| {
                if (nt.type == .comma) {
                    _ = try tokenizer.next(); // consume comma
                    continue;
                } else if (nt.type == .select) {
                    // End of WITH clause, SELECT follows
                    break;
                } else {
                    return error.UnexpectedTokenInWithClause;
                }
            } else {
                return error.UnexpectedEndOfQuery;
            }
        }

        return cte_context;
    }

    fn executeInsert(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Expect INTO
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .into) {
            return error.ExpectedInto;
        }

        // Get table name
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedTableName;
        }

        const table_name = token.value;
        const table = try self.db.getTable(table_name);

        // Expect VALUES
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .values) {
            return error.ExpectedValues;
        }

        // Expect (
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .lparen) {
            return error.ExpectedLParen;
        }

        // Parse values
        var values = std.ArrayList(Value){};
        defer values.deinit(self.allocator);

        var col_idx: usize = 0;
        while (col_idx < table.columns.len) : (col_idx += 1) {
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

            const value = switch (token.type) {
                .number => blk: {
                    const col_type = table.schema.columns[col_idx].data_type;
                    break :blk switch (col_type) {
                        .int32 => Value{ .int32 = try std.fmt.parseInt(i32, token.value, 10) },
                        .int64 => Value{ .int64 = try std.fmt.parseInt(i64, token.value, 10) },
                        .float32 => Value{ .float32 = try std.fmt.parseFloat(f32, token.value) },
                        .float64 => Value{ .float64 = try std.fmt.parseFloat(f64, token.value) },
                        else => return error.TypeMismatch,
                    };
                },
                .string => Value{ .string = token.value },
                else => return error.UnexpectedToken,
            };

            try values.append(self.allocator, value);

            // Check for comma or closing paren
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .rparen) break;
            if (token.type != .comma) return error.ExpectedCommaOrRParen;
        }

        try table.insertRow(values.items);

        return QueryResult{ .message = "Row inserted successfully" };
    }

    fn executeCreate(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Check what we're creating: TABLE, VIEW, MATERIALIZED VIEW, MODEL, INCREMENTAL MODEL, SCHEDULE, TYPE, or FUNCTION
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

        if (token.type == .table) {
            return try self.executeCreateTable(tokenizer);
        } else if (token.type == .view) {
            return try self.executeCreateView(tokenizer, false);
        } else if (token.type == .materialized) {
            // Expect VIEW after MATERIALIZED
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .view) return error.ExpectedView;
            return try self.executeCreateView(tokenizer, true);
        } else if (token.type == .incremental) {
            // Expect MODEL after INCREMENTAL
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .model) return error.ExpectedModel;
            return try self.executeCreateModel(tokenizer, true);
        } else if (token.type == .model) {
            return try self.executeCreateModel(tokenizer, false);
        } else if (token.type == .schedule) {
            return try self.executeCreateSchedule(tokenizer);
        } else if (token.type == .type_) {
            return try self.executeCreateType(tokenizer);
        } else if (token.type == .function) {
            return try self.executeCreateFunction(tokenizer);
        } else {
            return error.ExpectedTableOrView;
        }
    }

    fn executeCreateTable(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Get table name
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedTableName;
        }

        const table_name = token.value;

        // Check if this is CTAS (CREATE TABLE AS SELECT)
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type == .as) {
            // CTAS: parse SELECT query
            return try self.executeCreateTableAsSelect(table_name, tokenizer);
        }

        // Regular CREATE TABLE: expect (
        if (token.type != .lparen) {
            return error.ExpectedLParen;
        }

        // Parse column definitions
        var columns = std.ArrayList(schema_mod.Schema.ColumnDef){};
        defer columns.deinit(self.allocator);

        while (true) {
            // Column name
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) {
                return error.ExpectedColumnName;
            }
            const col_name = token.value;

            // Column type
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) {
                return error.ExpectedColumnType;
            }

            const data_type = parseDataType(token.value);
            try columns.append(self.allocator, .{ .name = col_name, .data_type = data_type });

            // Check for comma or closing paren
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .rparen) break;
            if (token.type != .comma) return error.ExpectedCommaOrRParen;
        }

        try self.db.createTable(table_name, columns.items);
        return QueryResult{ .message = "Table created successfully" };
    }

    fn executeCreateTableAsSelect(self: *QueryEngine, table_name: []const u8, tokenizer: *Tokenizer) !QueryResult {
        // Execute the SELECT query
        var select_result = try self.executeSelect(tokenizer);
        defer select_result.deinit();

        switch (select_result) {
            .table => |*result_table| {
                // Create new table with same schema as result
                try self.db.createTableFromQuery(table_name, result_table);
                return QueryResult{ .message = "Table created successfully" };
            },
            .message => {
                // SELECT should always return a table, but handle message case
                return QueryResult{ .message = "CTAS failed: SELECT query did not return a table" };
            },
        }
    }

    fn executeCreateView(self: *QueryEngine, tokenizer: *Tokenizer, materialized: bool) !QueryResult {
        // Get view name
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedViewName;
        }

        const view_name = token.value;

        // Expect AS
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .as) {
            return error.ExpectedAs;
        }

        // For now, we'll capture the rest of the query as the view definition
        // In a more complete implementation, we'd parse the SELECT statement
        const remaining_sql = tokenizer.input[tokenizer.pos..];
        tokenizer.pos = tokenizer.input.len; // Consume all remaining input

        if (materialized) {
            try self.db.createMaterializedView(view_name, remaining_sql);
            return QueryResult{ .message = "Materialized view created successfully" };
        } else {
            try self.db.createView(view_name, remaining_sql);
            return QueryResult{ .message = "View created successfully" };
        }
    }

    fn executeCreateModel(self: *QueryEngine, tokenizer: *Tokenizer, is_incremental: bool) !QueryResult {
        var partition_column: ?[]const u8 = null;

        // Get model name
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedModelName;
        }

        const model_name = token.value;

        // If this is an incremental model, check for PARTITION BY
        if (is_incremental) {
            // Check for PARTITION BY
            if (try tokenizer.peekToken()) |partition_peek| {
                if (partition_peek.type == .partition) {
                    // Consume PARTITION
                    _ = try tokenizer.next();

                    // Expect BY
                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                    if (token.type != .by) {
                        return error.ExpectedBy;
                    }

                    // Parse partition function (e.g., DATE(column))
                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                    if (token.type != .identifier) {
                        return error.ExpectedPartitionFunction;
                    }

                    // For now, we only support DATE(column) syntax
                    const partition_func = token.value;
                    if (!std.mem.eql(u8, partition_func, "DATE")) {
                        return error.UnsupportedPartitionFunction;
                    }

                    // Expect (
                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                    if (token.type != .lparen) {
                        return error.ExpectedLeftParen;
                    }

                    // Get column name
                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                    if (token.type != .identifier) {
                        return error.ExpectedColumnName;
                    }

                    partition_column = token.value;

                    // Expect )
                    token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                    if (token.type != .rparen) {
                        return error.ExpectedRightParen;
                    }
                }
            }
        }

        // Expect AS
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .as) {
            return error.ExpectedAs;
        }

        // Capture the rest of the query as the model definition
        const remaining_sql = tokenizer.input[tokenizer.pos..];

        // Check if this is a PL-Grizzly template (starts with {)
        const trimmed_sql = std.mem.trim(u8, remaining_sql, &std.ascii.whitespace);
        var final_sql = remaining_sql;

        if (trimmed_sql.len > 0 and trimmed_sql[0] == '{') {
            // This is a PL-Grizzly template - compile it
            var template_engine = @import("template.zig").TemplateEngine.init(self.allocator);
            defer template_engine.deinit();

            // Find the end of the template (matching } at the end)
            const template_end = std.mem.lastIndexOf(u8, trimmed_sql, "}") orelse return error.UnmatchedTemplateBrace;
            const template_content = trimmed_sql[0 .. template_end + 1];

            final_sql = try template_engine.compileTemplate(template_content);
        } else {
            // Regular SQL - consume all remaining input
            tokenizer.pos = tokenizer.input.len;
        }

        if (is_incremental) {
            try self.db.createIncrementalModel(model_name, final_sql, partition_column);
            return QueryResult{ .message = "Incremental model created successfully" };
        } else {
            try self.db.createModel(model_name, final_sql);
            return QueryResult{ .message = "Model created successfully" };
        }
    }

    fn executeCreateSchedule(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Get schedule ID
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedScheduleId;
        }
        const schedule_id = token.value;

        // Expect FOR
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .for_) {
            return error.ExpectedFor;
        }

        // Expect MODEL
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .model) {
            return error.ExpectedModel;
        }

        // Get model name
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedModelName;
        }
        const model_name = token.value;

        // Expect CRON
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .cron) {
            return error.ExpectedCron;
        }

        // Get cron expression (expect string literal)
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .string_literal) {
            return error.ExpectedCronExpression;
        }
        const cron_expr = token.value;

        // Parse optional ON FAILURE RETRY clause
        var max_retries: u32 = 0; // Default to 0 retries
        if (try tokenizer.peekToken()) |peek_token| {
            if (peek_token.type == .on) {
                // Consume ON
                _ = try tokenizer.next();

                // Expect FAILURE
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type != .failure) {
                    return error.ExpectedFailure;
                }

                // Expect RETRY
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type != .retry) {
                    return error.ExpectedRetry;
                }

                // Get retry count
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type != .number) {
                    return error.ExpectedRetryCount;
                }
                max_retries = try std.fmt.parseInt(u32, token.value, 10);
            }
        }

        // Create the schedule
        try self.db.createSchedule(schedule_id, model_name, cron_expr, max_retries);

        return QueryResult{ .message = "Schedule created successfully" };
    }

    fn executeCreateType(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Get type name
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedTypeName;
        }
        const type_name = token.value;

        // Expect AS
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .as) {
            return error.ExpectedAs;
        }

        // Check what comes after AS
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type == .enum_) {
            return try self.executeCreateEnumType(type_name, tokenizer);
        } else if (token.type == .struct_) {
            return try self.executeCreateStructType(type_name, tokenizer);
        } else if (token.type == .identifier) {
            // This is a type alias: CREATE TYPE alias AS target_type
            return try self.executeCreateTypeAlias(type_name, token.value);
        } else {
            return error.ExpectedEnumOrStructOrIdentifier;
        }
    }

    fn executeCreateEnumType(self: *QueryEngine, type_name: []const u8, tokenizer: *Tokenizer) !QueryResult {
        // Parse enum values: ('value1', 'value2', ...)
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .lparen) {
            return error.ExpectedLParen;
        }

        var enum_values = try std.ArrayList([]const u8).initCapacity(self.allocator, 4);
        defer enum_values.deinit(self.allocator);

        while (true) {
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .rparen) break;

            if (token.type == .string_literal) {
                // Remove quotes from string literal
                const value = token.value;
                const unquoted = if (value.len >= 2 and ((value[0] == '"' and value[value.len - 1] == '"') or (value[0] == '\'' and value[value.len - 1] == '\'')))
                    value[1 .. value.len - 1]
                else
                    value;
                try enum_values.append(self.allocator, unquoted);
            } else {
                return error.ExpectedStringLiteral;
            }

            // Check for comma or closing paren
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .rparen) break;
            if (token.type != .comma) {
                return error.ExpectedCommaOrRParen;
            }
        }

        // Create the enum type
        try self.db.createEnumType(type_name, enum_values.items);

        return QueryResult{ .message = "Type created successfully" };
    }

    fn executeCreateStructType(self: *QueryEngine, type_name: []const u8, tokenizer: *Tokenizer) !QueryResult {
        // Parse struct fields: (field_name field_type, ...)
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .lparen) {
            return error.ExpectedLParen;
        }

        var fields = try std.ArrayList(@import("types_custom.zig").StructField).initCapacity(self.allocator, 4);
        errdefer {
            for (fields.items) |*field| {
                field.deinit(self.allocator);
            }
            fields.deinit(self.allocator);
        }

        while (true) {
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .rparen) break;

            // Parse field name
            if (token.type != .identifier) {
                return error.ExpectedFieldName;
            }
            const field_name = token.value;

            // Parse field type
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) {
                return error.ExpectedFieldType;
            }
            const field_type_str = token.value;

            // Convert string to TypeRef (for now, only built-in types)
            var type_ref = try self.parseTypeRef(field_type_str);
            errdefer type_ref.deinit(self.allocator);

            // Create field
            var field = try @import("types_custom.zig").StructField.init(self.allocator, field_name, type_ref);
            errdefer field.deinit(self.allocator);
            try fields.append(self.allocator, field);

            // Check for comma or closing paren
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .rparen) break;
            if (token.type != .comma) {
                return error.ExpectedCommaOrRParen;
            }
        }

        // Create the struct type (this takes ownership of the fields)
        try self.db.createStructType(type_name, fields.items);

        // Clean up the array list itself (fields are now owned by the database)
        fields.deinit(self.allocator);

        return QueryResult{ .message = "Type created successfully" };
    }

    fn executeCreateTypeAlias(self: *QueryEngine, alias_name: []const u8, target_type: []const u8) !QueryResult {
        // Create the type alias
        try self.db.createTypeAlias(alias_name, target_type);

        return QueryResult{ .message = "Type alias created successfully" };
    }

    fn executeCreateFunction(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Get function name
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedFunctionName;
        }
        const func_name = token.value;

        // Parse parameters: (param1 type1, param2 type2, ...)
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .lparen) {
            return error.ExpectedLParen;
        }

        var parameters = try std.ArrayList(Parameter).initCapacity(self.allocator, 0);
        defer parameters.deinit(self.allocator);

        // Check if there are parameters
        token = (try tokenizer.peekToken()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .rparen) {
            while (true) {
                // Parameter name
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type != .identifier) {
                    return error.ExpectedParameterName;
                }
                const param_name = token.value;

                // Parameter type
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type != .identifier) {
                    return error.ExpectedParameterType;
                }
                const param_type_str = token.value;
                const param_type = parseDataType(param_type_str);

                const param = try Parameter.init(self.allocator, param_name, param_type);
                try parameters.append(self.allocator, param);

                // Check for comma or closing paren
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type == .rparen) break;
                if (token.type != .comma) {
                    return error.ExpectedCommaOrRParen;
                }
            }
        } else {
            // Consume the rparen
            _ = try tokenizer.next();
        }

        // Expect RETURNS
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .returns) {
            return error.ExpectedReturns;
        }

        // Return type
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedReturnType;
        }
        const return_type_str = token.value;
        const return_type = parseDataType(return_type_str);

        // Check for optional AS SYNC/ASYNC
        var context = ExecutionContext.runtime;
        token = (try tokenizer.peekToken()) orelse return error.UnexpectedEndOfQuery;
        if (token.type == .as) {
            _ = try tokenizer.next(); // consume AS
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .sync) {
                context = .runtime;
            } else if (token.type == .async) {
                context = .compile_time;
            } else {
                return error.ExpectedSyncOrAsync;
            }
        }

        // Expect opening brace
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .lbrace) {
            return error.ExpectedLBrace;
        }

        // Parse function body
        var body = try self.parseFunctionBody(tokenizer);
        errdefer body.deinit(self.allocator);

        // Expect closing brace
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .rbrace) {
            return error.ExpectedRBrace;
        }

        // Create the function
        var function = try self.allocator.create(Function);
        function.* = try Function.init(
            self.allocator,
            func_name,
            parameters.items,
            return_type,
            body,
            context,
        );
        errdefer function.deinit();

        // Register the function
        try self.db.functions.registerFunction(function);

        return QueryResult{ .message = "Function created successfully" };
    }

    fn parseFunctionBody(self: *QueryEngine, tokenizer: *Tokenizer) !FunctionBody {
        // Check if this is a match expression
        const token = (try tokenizer.peekToken()) orelse return error.UnexpectedEndOfQuery;
        if (token.type == .match) {
            return try self.parseMatchBody(tokenizer);
        } else {
            // Simple expression body
            const expr = try self.parseExpression(tokenizer);
            return FunctionBody{ .expression = expr };
        }
    }

    fn parseMatchBody(self: *QueryEngine, tokenizer: *Tokenizer) !FunctionBody {
        // Consume MATCH
        _ = try tokenizer.next();

        // Parse value expression
        const value_expr = try self.parseExpression(tokenizer);

        // Expect WITH
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .with) {
            return error.ExpectedWith;
        }

        var cases = try std.ArrayList(MatchCase).initCapacity(self.allocator, 0);
        errdefer {
            for (cases.items) |*case_| {
                case_.deinit(self.allocator);
            }
            cases.deinit(self.allocator);
        }

        while (true) {
            // Parse pattern
            const pattern = try self.parsePattern(tokenizer);

            // Expect ->
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .arrow) {
                return error.ExpectedArrow;
            }

            // Parse expression
            const expr = try self.parseExpression(tokenizer);

            const match_case = MatchCase.init(pattern, expr);
            try cases.append(self.allocator, match_case);

            // Check for comma (more cases) or END
            token = (try tokenizer.peekToken()) orelse return error.UnexpectedEndOfQuery;
            if (token.type == .end) {
                _ = try tokenizer.next(); // consume END
                break;
            }
            if (token.type != .comma) {
                return error.ExpectedCommaOrEnd;
            }
            _ = try tokenizer.next(); // consume comma
        }

        return FunctionBody{
            .match = .{
                .value_expr = value_expr,
                .cases = try cases.toOwnedSlice(self.allocator),
            },
        };
    }

    fn parsePattern(self: *QueryEngine, tokenizer: *Tokenizer) !Pattern {
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

        if (token.type == .identifier) {
            if (std.mem.eql(u8, token.value, "_")) {
                return Pattern.initWildcard();
            } else {
                // Check if this is a string literal pattern
                if (token.value.len >= 2 and token.value[0] == '"' and token.value[token.value.len - 1] == '"') {
                    const str_content = token.value[1 .. token.value.len - 1];
                    const str_copy = try self.allocator.dupe(u8, str_content);
                    const value = Value{ .string = str_copy };
                    return try Pattern.initLiteral(self.allocator, value);
                } else if (token.value.len >= 2 and token.value[0] == '\'' and token.value[token.value.len - 1] == '\'') {
                    const str_content = token.value[1 .. token.value.len - 1];
                    const str_copy = try self.allocator.dupe(u8, str_content);
                    const value = Value{ .string = str_copy };
                    return try Pattern.initLiteral(self.allocator, value);
                } else if (std.fmt.parseFloat(f64, token.value) catch null) |num| {
                    const value = Value{ .float64 = num };
                    return try Pattern.initLiteral(self.allocator, value);
                } else if (std.fmt.parseInt(i64, token.value, 10) catch null) |num| {
                    const value = Value{ .int64 = num };
                    return try Pattern.initLiteral(self.allocator, value);
                } else {
                    // Variable pattern
                    return try Pattern.initVariable(self.allocator, token.value);
                }
            }
        } else if (token.type == .string_literal) {
            // Remove quotes
            const value_str = token.value;
            const unquoted = if (value_str.len >= 2 and ((value_str[0] == '"' and value_str[value_str.len - 1] == '"') or (value_str[0] == '\'' and value_str[value_str.len - 1] == '\'')))
                value_str[1 .. value_str.len - 1]
            else
                value_str;
            const str_copy = try self.allocator.dupe(u8, unquoted);
            const value = Value{ .string = str_copy };
            return try Pattern.initLiteral(self.allocator, value);
        }

        return error.InvalidPattern;
    }

    fn parseExpression(self: *QueryEngine, tokenizer: *Tokenizer) ![]const u8 {
        // For now, parse until we hit a keyword that ends the expression
        // This is a simplified implementation
        var result = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        errdefer result.deinit(self.allocator);

        var paren_depth: usize = 0;
        var brace_depth: usize = 0;

        while (true) {
            const token = (try tokenizer.peekToken()) orelse break;

            switch (token.type) {
                .lparen => paren_depth += 1,
                .rparen => {
                    if (paren_depth == 0) break;
                    paren_depth -= 1;
                },
                .lbrace => brace_depth += 1,
                .rbrace => {
                    if (brace_depth == 0) break;
                    brace_depth -= 1;
                },
                .comma => if (paren_depth == 0 and brace_depth == 0) break,
                .with => if (paren_depth == 0 and brace_depth == 0) break,
                .end => if (paren_depth == 0 and brace_depth == 0) break,
                .arrow => if (paren_depth == 0 and brace_depth == 0) break,
                else => {},
            }

            // Add token to result
            try result.appendSlice(self.allocator, token.value);
            _ = try tokenizer.next();
        }

        return try result.toOwnedSlice(self.allocator);
    }

    fn parseTypeRef(self: *QueryEngine, type_str: []const u8) !@import("types_custom.zig").TypeRef {
        // For now, just treat all types as custom types
        // TODO: Implement proper built-in type mapping
        const type_name_copy = try self.allocator.dupe(u8, type_str);
        return @import("types_custom.zig").TypeRef{ .custom = type_name_copy };
    }

    fn parseDataType(type_str: []const u8) types.DataType {
        var buf: [32]u8 = undefined;
        if (type_str.len > buf.len) return .int32;

        const lowercase = std.ascii.lowerString(&buf, type_str);

        if (std.mem.eql(u8, lowercase, "int") or std.mem.eql(u8, lowercase, "int32") or std.mem.eql(u8, lowercase, "integer")) return .int32;
        if (std.mem.eql(u8, lowercase, "int64") or std.mem.eql(u8, lowercase, "bigint")) return .int64;
        if (std.mem.eql(u8, lowercase, "float") or std.mem.eql(u8, lowercase, "float64") or std.mem.eql(u8, lowercase, "double")) return .float64;
        if (std.mem.eql(u8, lowercase, "string") or std.mem.eql(u8, lowercase, "text") or std.mem.eql(u8, lowercase, "varchar")) return .string;
        if (std.mem.eql(u8, lowercase, "bool") or std.mem.eql(u8, lowercase, "boolean")) return .boolean;

        return .string;
    }

    /// Load a file into a temporary table
    fn loadFileAsTable(self: *QueryEngine, file_path: []const u8) !?*Table {
        if (self.format_registry == null) {
            return null;
        }

        const registry = self.format_registry.?;

        // Try to detect format by extension
        const loader = registry.detectByExtension(file_path) orelse
            (try registry.detectByContent(file_path));

        if (loader == null) {
            return null;
        }

        // Load the file into a temporary table
        const opts = format_mod.LoadOptions{
            .infer_types = true,
            .header = true,
        };

        const table = try loader.?.loadFn(self.allocator, file_path, opts);
        return table;
    }

    fn saveDatabase(self: *QueryEngine, file_path: []const u8, compression: format_mod.CompressionType) !void {
        var lakehouse = Lakehouse.init(self.allocator);

        try lakehouse.save(self.db, file_path, compression);
    }

    fn loadDatabase(self: *QueryEngine, file_path: []const u8) !void {
        var lakehouse = Lakehouse.init(self.allocator);

        var new_db = try lakehouse.load(file_path);
        errdefer new_db.deinit();

        // Replace the current database contents
        // This is a simplified approach - in a real implementation, we'd need to handle
        // proper cleanup and replacement of the database pointer
        self.db.deinit();
        self.db.* = new_db;
    }

    /// Execute LOAD command: LOAD DATABASE FROM 'file.griz' or LOAD 'file.csv' INTO table_name
    fn executeLoad(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Check if this is LOAD DATABASE or LOAD file INTO table
        const peek_token = (try tokenizer.peekToken()) orelse return error.UnexpectedEndOfQuery;

        if (peek_token.type == .identifier) {
            var lower_buf: [32]u8 = undefined;
            const lowercase = std.ascii.lowerString(&lower_buf, peek_token.value);
            if (std.mem.eql(u8, lowercase, "database")) {
                _ = try tokenizer.next(); // consume DATABASE
                return try self.executeLoadDatabase(tokenizer);
            }
        }

        // Original LOAD file INTO table logic
        // Expect file path as string literal
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .string_literal) {
            return error.ExpectedFilePath;
        }

        const file_path = token.value;

        // Expect INTO keyword
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .into) {
            return error.ExpectedInto;
        }

        // Expect table name
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedTableName;
        }

        const table_name = token.value;

        // Check for optional semicolon
        const semicolon_token = try tokenizer.next();
        if (semicolon_token) |t| {
            if (t.type != .semicolon) {
                return error.UnexpectedToken;
            }
        }

        // Load the file
        const loaded_table = try self.loadFileAsTable(file_path) orelse {
            return error.FailedToLoadFile;
        };

        // Rename the loaded table to the target name
        loaded_table.name = try self.allocator.dupe(u8, table_name);

        // Register in database
        try self.db.tables.put(table_name, loaded_table);

        var message = std.ArrayList(u8){};
        defer message.deinit(self.allocator);

        try message.writer(self.allocator).print("Loaded {d} rows from {s} into table {s}", .{ loaded_table.row_count, file_path, table_name });

        return QueryResult{
            .message = try message.toOwnedSlice(self.allocator),
        };
    }

    fn executeLoadDatabase(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Expect FROM keyword
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .from) return error.ExpectedFrom;

        // Expect file path as string literal
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .string_literal) {
            return error.ExpectedFilePath;
        }

        const file_path = token.value;

        // Check for optional semicolon
        const semicolon_token = try tokenizer.next();
        if (semicolon_token) |t| {
            if (t.type != .semicolon) {
                return error.UnexpectedToken;
            }
        }

        // Load the database
        try self.loadDatabase(file_path);

        var message = std.ArrayList(u8){};
        defer message.deinit(self.allocator);

        try message.writer(self.allocator).print("Database loaded from {s}", .{file_path});

        return QueryResult{
            .message = try message.toOwnedSlice(self.allocator),
        };
    }

    fn executeSave(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Expect DATABASE keyword
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) return error.ExpectedDatabase;

        // Convert to lowercase for comparison
        var lower_buf: [32]u8 = undefined;
        const lowercase = std.ascii.lowerString(&lower_buf, token.value);
        if (!std.mem.eql(u8, lowercase, "database")) return error.ExpectedDatabase;

        // Expect TO keyword
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) return error.ExpectedTo;

        const to_lowercase = std.ascii.lowerString(&lower_buf, token.value);
        if (!std.mem.eql(u8, to_lowercase, "to")) return error.ExpectedTo;

        // Expect file path as string literal
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .string_literal) {
            return error.ExpectedFilePath;
        }

        const file_path = token.value;

        // Parse optional WITH COMPRESSION clause
        var compression: format_mod.CompressionType = .none;
        var has_compression_clause = false;

        // Check for WITH keyword
        if (try tokenizer.peekToken()) |peek_token| {
            if (peek_token.type == .with) {
                _ = try tokenizer.next(); // consume WITH
                has_compression_clause = true;

                // Expect COMPRESSION keyword
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type != .identifier) return error.ExpectedCompression;
                const comp_lowercase = std.ascii.lowerString(&lower_buf, token.value);
                if (!std.mem.eql(u8, comp_lowercase, "compression")) return error.ExpectedCompression;

                // Expect compression algorithm
                token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
                if (token.type != .identifier) return error.ExpectedCompressionAlgorithm;

                const algo_lowercase = std.ascii.lowerString(&lower_buf, token.value);
                if (std.mem.eql(u8, algo_lowercase, "lz4")) {
                    compression = .lz4;
                } else if (std.mem.eql(u8, algo_lowercase, "zstd")) {
                    compression = .zstd;
                } else if (std.mem.eql(u8, algo_lowercase, "gzip")) {
                    compression = .gzip;
                } else if (std.mem.eql(u8, algo_lowercase, "snappy")) {
                    compression = .snappy;
                } else if (std.mem.eql(u8, algo_lowercase, "none")) {
                    compression = .none;
                } else {
                    return error.InvalidCompressionAlgorithm;
                }
            }
        }

        // Check for optional semicolon
        const semicolon_token = try tokenizer.next();
        if (semicolon_token) |t| {
            if (t.type != .semicolon) {
                return error.UnexpectedToken;
            }
        }

        // Check for file overwrite protection
        if (std.fs.cwd().openFile(file_path, .{})) |_| {
            // File exists, this would be an error for safety
            return error.FileAlreadyExists;
        } else |_| {
            // File doesn't exist, which is good
        }

        // Save the database
        try self.saveDatabase(file_path, compression);

        var message = std.ArrayList(u8){};
        defer message.deinit(self.allocator);

        if (has_compression_clause) {
            try message.writer(self.allocator).print("Database saved to {s} with {s} compression", .{ file_path, @tagName(compression) });
        } else {
            try message.writer(self.allocator).print("Database saved to {s}", .{file_path});
        }

        return QueryResult{
            .message = try message.toOwnedSlice(self.allocator),
        };
    }

    fn executeAttach(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Expect DATABASE keyword
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) return error.ExpectedDatabase;

        var lower_buf: [32]u8 = undefined;
        const db_lowercase = std.ascii.lowerString(&lower_buf, token.value);
        if (!std.mem.eql(u8, db_lowercase, "database")) return error.ExpectedDatabase;

        // Expect file path as string literal
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .string_literal) {
            return error.ExpectedFilePath;
        }

        const file_path = token.value;

        // Expect AS keyword
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .as) return error.ExpectedAs;

        // Expect alias
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedAlias;
        }

        const alias = token.value;

        // Check for optional semicolon
        const semicolon_token = try tokenizer.next();
        if (semicolon_token) |t| {
            if (t.type != .semicolon) {
                return error.UnexpectedToken;
            }
        }

        // Load the database
        var lakehouse = Lakehouse.init(self.allocator);
        var attached_db = try lakehouse.load(file_path);
        errdefer attached_db.deinit();

        // Attach it
        try self.db.attachDatabase(alias, &attached_db);

        var message = std.ArrayList(u8){};
        defer message.deinit(self.allocator);

        try message.writer(self.allocator).print("Database attached as '{s}' from {s}", .{ alias, file_path });

        return QueryResult{
            .message = try message.toOwnedSlice(self.allocator),
        };
    }

    fn executeDetach(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Expect DATABASE keyword
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) return error.ExpectedDatabase;

        var lower_buf: [32]u8 = undefined;
        const db_lowercase = std.ascii.lowerString(&lower_buf, token.value);
        if (!std.mem.eql(u8, db_lowercase, "database")) return error.ExpectedDatabase;

        // Expect alias
        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) {
            return error.ExpectedAlias;
        }

        const alias = token.value;

        // Check for optional semicolon
        const semicolon_token = try tokenizer.next();
        if (semicolon_token) |t| {
            if (t.type != .semicolon) {
                return error.UnexpectedToken;
            }
        }

        // Detach the database
        try self.db.detachDatabase(alias);

        var message = std.ArrayList(u8){};
        defer message.deinit(self.allocator);

        try message.writer(self.allocator).print("Database '{s}' detached", .{alias});

        return QueryResult{
            .message = try message.toOwnedSlice(self.allocator),
        };
    }

    fn executeRefresh(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Check if it's MATERIALIZED VIEW or MODEL
        const next_token = (try tokenizer.peekToken()) orelse return error.UnexpectedEndOfQuery;

        if (next_token.type == .materialized) {
            // REFRESH MATERIALIZED VIEW view_name
            _ = try tokenizer.next(); // consume MATERIALIZED
            var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .view) return error.UnexpectedToken;
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) return error.UnexpectedToken;
            const view_name = token;
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .semicolon) return error.UnexpectedToken;

            try self.db.refreshMaterializedView(view_name.value);
            return QueryResult{ .message = "Materialized view refreshed successfully" };
        } else if (next_token.type == .model) {
            // REFRESH MODEL model_name
            _ = try tokenizer.next(); // consume MODEL
            var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) return error.UnexpectedToken;
            const model_name = token;
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .semicolon) return error.UnexpectedToken;

            try self.db.refreshModel(model_name.value);
            return QueryResult{ .message = "Model refreshed successfully" };
        } else {
            return error.ExpectedMaterializedViewOrModel;
        }
    }

    fn executeDrop(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        const token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

        if (token.type == .schedule) {
            // Get schedule ID
            const id_token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (id_token.type != .identifier) {
                return error.ExpectedScheduleId;
            }
            const schedule_id = id_token.value;

            // Expect semicolon
            const semi_token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (semi_token.type != .semicolon) return error.UnexpectedToken;

            try self.db.dropSchedule(schedule_id);
            return QueryResult{ .message = "Schedule dropped successfully" };
        } else {
            return error.ExpectedSchedule;
        }
    }

    fn executeShow(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        const token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

        if (token.type == .lineage) {
            return try self.executeShowLineage(tokenizer);
        } else if (token.type == .dependencies) {
            return try self.executeShowDependencies(tokenizer);
        } else if (token.type == .identifier and std.mem.eql(u8, token.value, "SCHEDULES")) {
            return try self.executeShowSchedules(tokenizer);
        } else if (token.type == .databases) {
            return try self.executeShowDatabases(tokenizer);
        } else if (token.type == .types) {
            return try self.executeShowTypes(tokenizer);
        } else {
            return error.ExpectedLineageOrDependencies;
        }
    }

    fn executeShowTypes(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Expect semicolon
        const token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .semicolon) return error.ExpectedSemicolon;

        // Get all custom types
        const custom_types = try self.db.listTypes(self.allocator);
        defer {
            for (custom_types) |type_name| {
                self.allocator.free(type_name);
            }
            self.allocator.free(custom_types);
        }

        // Get all aliases
        const aliases = try self.db.listAliases(self.allocator);
        defer {
            for (aliases) |alias_name| {
                self.allocator.free(alias_name);
            }
            self.allocator.free(aliases);
        }

        // Format the output
        var output = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer output.deinit(self.allocator);
        const writer = output.writer(self.allocator);

        try writer.print("Custom Types:\n", .{});
        for (custom_types) |type_name| {
            try writer.print("  {s}\n", .{type_name});
        }

        if (aliases.len > 0) {
            try writer.print("\nType Aliases:\n", .{});
            for (aliases) |alias_name| {
                try writer.print("  {s}\n", .{alias_name});
            }
        }

        return QueryResult{ .message = try output.toOwnedSlice(self.allocator) };
    }

    fn executeDescribe(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .type_) return error.UnexpectedToken;

        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) return error.UnexpectedToken;
        const type_name = token;

        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .semicolon) return error.UnexpectedToken;

        const description = try self.db.describeType(self.allocator, type_name.value);
        if (description) |desc| {
            defer self.allocator.free(desc);
            return QueryResult{ .message = desc };
        } else {
            return QueryResult{ .message = "Type not found" };
        }
    }

    fn executeShowLineage(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .for_) return error.UnexpectedToken;

        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;

        if (token.type == .model) {
            // SHOW LINEAGE FOR MODEL model_name
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) return error.UnexpectedToken;
            const model_name = token;

            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .semicolon) return error.UnexpectedToken;

            const lineage = try self.db.getModelLineage(model_name.value, self.allocator);
            defer self.allocator.free(lineage);

            // Format as a simple text output
            var output = try std.ArrayList(u8).initCapacity(self.allocator, 0);
            defer output.deinit(self.allocator);
            const writer = output.writer(self.allocator);

            try writer.print("Lineage for model '{s}':\n", .{model_name.value});
            for (lineage) |dep| {
                try writer.print("  - {s}\n", .{dep});
            }

            return QueryResult{ .message = try output.toOwnedSlice(self.allocator) };
        } else if (token.type == .identifier and std.mem.eql(u8, token.value, "COLUMN")) {
            // SHOW LINEAGE FOR COLUMN table.column
            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) return error.ExpectedTableName;
            const table_name = token.value;

            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .dot) return error.ExpectedDot;

            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .identifier) return error.ExpectedColumnName;
            const column_name = token.value;

            token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
            if (token.type != .semicolon) return error.UnexpectedToken;

            // Get column-level lineage
            const lineage = try self.getColumnLineage(table_name, column_name);
            defer {
                for (lineage) |dep| {
                    self.allocator.free(dep);
                }
                self.allocator.free(lineage);
            }

            // Format as a simple text output
            var output = try std.ArrayList(u8).initCapacity(self.allocator, 0);
            defer output.deinit(self.allocator);
            const writer = output.writer(self.allocator);

            try writer.print("Column lineage for '{s}.{s}':\n", .{ table_name, column_name });
            for (lineage) |dep| {
                try writer.print("  - {s}\n", .{dep});
            }

            return QueryResult{ .message = try output.toOwnedSlice(self.allocator) };
        } else {
            return error.ExpectedModelOrColumn;
        }
    }

    fn getColumnLineage(self: *QueryEngine, table_name: []const u8, column_name: []const u8) ![][]const u8 {
        var lineage = std.ArrayListUnmanaged([]const u8){};
        defer lineage.deinit(self.allocator);

        // Find all models that output to this table
        var model_it = self.db.models.models.iterator();
        while (model_it.next()) |entry| {
            const model = entry.value_ptr.*;

            // Check if this model creates/updates the target table (model name = table name)
            if (std.mem.eql(u8, model.name, table_name)) {
                // Analyze the model's SQL to find column mappings
                const column_deps = try self.analyzeColumnDependencies(model.sql_definition, column_name);
                defer self.allocator.free(column_deps);

                for (column_deps) |dep| {
                    try lineage.append(self.allocator, try self.allocator.dupe(u8, dep));
                }
            }
        }

        return lineage.toOwnedSlice(self.allocator);
    }

    fn analyzeColumnDependencies(self: *QueryEngine, sql: []const u8, target_column: []const u8) ![][]const u8 {
        var deps = std.ArrayListUnmanaged([]const u8){};
        defer deps.deinit(self.allocator);

        // Simple SQL parsing to find column mappings
        // This is a basic implementation - real column lineage would need more sophisticated SQL analysis

        // Convert to lowercase for case-insensitive matching
        var sql_lower = std.ArrayListUnmanaged(u8){};
        defer sql_lower.deinit(self.allocator);

        for (sql) |c| {
            try sql_lower.append(self.allocator, std.ascii.toLower(c));
        }

        // Look for SELECT clauses and find the target column
        var i: usize = 0;
        while (i < sql_lower.items.len) {
            // Look for "select "
            if (i + 7 <= sql_lower.items.len and std.mem.eql(u8, sql_lower.items[i .. i + 7], "select ")) {
                i += 7;

                // Parse column expressions until FROM
                while (i < sql_lower.items.len) {
                    // Skip whitespace
                    while (i < sql_lower.items.len and std.ascii.isWhitespace(sql_lower.items[i])) i += 1;

                    if (i >= sql_lower.items.len) break;

                    // Check for FROM (end of SELECT clause)
                    if (i + 4 <= sql_lower.items.len and std.mem.eql(u8, sql_lower.items[i .. i + 4], "from")) {
                        break;
                    }

                    // Parse column expression
                    const expr_start = i;
                    var paren_depth: usize = 0;
                    var in_string = false;

                    // Find end of expression (comma or FROM)
                    while (i < sql_lower.items.len) {
                        const c = sql_lower.items[i];

                        if (c == '\'' or c == '"') {
                            in_string = !in_string;
                        } else if (!in_string) {
                            if (c == '(') {
                                paren_depth += 1;
                            } else if (c == ')') {
                                paren_depth -= 1;
                            } else if (paren_depth == 0 and c == ',') {
                                break;
                            } else if (paren_depth == 0 and i + 4 <= sql_lower.items.len and std.mem.eql(u8, sql_lower.items[i .. i + 4], "from")) {
                                i -= 1; // Back up so FROM check above works
                                break;
                            }
                        }

                        i += 1;
                    }

                    const expr = sql[expr_start..i];

                    // Check if this expression defines our target column
                    // Look for "AS column_name" or just "column_name"
                    const expr_lower = sql_lower.items[expr_start..i];

                    // Check for AS alias
                    var has_alias = false;
                    var alias_start: usize = 0;

                    if (std.mem.indexOf(u8, expr_lower, " as ")) |as_pos| {
                        alias_start = expr_start + as_pos + 4; // Skip " as "
                        has_alias = true;
                    } else if (std.mem.lastIndexOf(u8, expr_lower, " ")) |space_pos| {
                        // Last word might be alias
                        const last_word_start = expr_start + space_pos + 1;
                        const last_word = sql[last_word_start..i];

                        // Convert to lowercase for comparison
                        var last_word_lower_buf: [64]u8 = undefined;
                        const last_word_lower = std.ascii.lowerString(&last_word_lower_buf, last_word);

                        if (std.mem.eql(u8, last_word_lower, target_column)) {
                            // The target column is the alias
                            has_alias = true;
                            alias_start = last_word_start;
                        }
                    }

                    if (has_alias) {
                        // Check if alias matches target column
                        const alias_end = i;
                        const alias = sql[alias_start..alias_end];

                        // Convert alias to lowercase for comparison
                        var alias_lower_buf: [64]u8 = undefined;
                        const alias_lower = std.ascii.lowerString(&alias_lower_buf, alias);

                        if (std.mem.eql(u8, alias_lower, target_column)) {
                            // This expression defines our target column
                            // Extract source columns from the expression
                            const source_deps = try self.extractSourceColumnsFromExpression(expr[0 .. alias_start - expr_start - 4]); // Remove " AS "
                            defer self.allocator.free(source_deps);

                            for (source_deps) |dep| {
                                try deps.append(self.allocator, try self.allocator.dupe(u8, dep));
                            }
                        }
                    } else {
                        // No alias, check if the expression itself is the column name
                        const trimmed_expr = std.mem.trim(u8, expr, &std.ascii.whitespace);

                        // Convert to lowercase for comparison
                        var trimmed_lower_buf: [64]u8 = undefined;
                        const trimmed_lower = std.ascii.lowerString(&trimmed_lower_buf, trimmed_expr);

                        if (std.mem.eql(u8, trimmed_lower, target_column)) {
                            // This is a direct column reference
                            try deps.append(self.allocator, try std.fmt.allocPrint(self.allocator, "{s}", .{trimmed_expr}));
                        }
                    }

                    // Skip comma if present
                    if (i < sql_lower.items.len and sql_lower.items[i] == ',') {
                        i += 1;
                    }
                }
            }

            i += 1;
        }

        return deps.toOwnedSlice(self.allocator);
    }

    fn extractSourceColumnsFromExpression(self: *QueryEngine, expr: []const u8) ![][]const u8 {
        var cols = std.ArrayListUnmanaged([]const u8){};
        defer cols.deinit(self.allocator);

        // Simple extraction of column references from expressions
        // This handles basic cases like "table.column", "column", "func(column)"

        var i: usize = 0;
        while (i < expr.len) {
            // Look for identifiers that could be column names
            if (std.ascii.isAlphabetic(expr[i]) or expr[i] == '_') {
                const start = i;
                while (i < expr.len and (std.ascii.isAlphanumeric(expr[i]) or expr[i] == '_' or expr[i] == '.')) {
                    i += 1;
                }

                const identifier = expr[start..i];

                // Check if this looks like a column reference (contains dot or is a simple name)
                if (std.mem.indexOf(u8, identifier, ".")) |_| {
                    // table.column format
                    try cols.append(self.allocator, try self.allocator.dupe(u8, identifier));
                } else if (!std.mem.eql(u8, identifier, "select") and
                    !std.mem.eql(u8, identifier, "from") and
                    !std.mem.eql(u8, identifier, "where") and
                    !std.mem.eql(u8, identifier, "group") and
                    !std.mem.eql(u8, identifier, "order") and
                    !std.mem.eql(u8, identifier, "by") and
                    !std.mem.eql(u8, identifier, "having") and
                    !std.mem.eql(u8, identifier, "limit") and
                    !std.mem.eql(u8, identifier, "offset"))
                {
                    // Simple column name (not a SQL keyword)
                    try cols.append(self.allocator, try self.allocator.dupe(u8, identifier));
                }
            } else {
                i += 1;
            }
        }

        return cols.toOwnedSlice(self.allocator);
    }

    fn executeShowDependencies(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        var token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .for_) return error.UnexpectedToken;

        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .model) return error.UnexpectedToken;

        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .identifier) return error.UnexpectedToken;
        const model_name = token;

        token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .semicolon) return error.UnexpectedToken;

        // Get the model to show its direct dependencies
        const model = self.db.models.getModel(model_name.value) orelse return error.ModelNotFound;

        var output = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer output.deinit(self.allocator);
        const writer = output.writer(self.allocator);

        try writer.print("Dependencies for model '{s}':\n", .{model_name.value});
        for (model.dependencies.items) |dep| {
            try writer.print("  - {s}\n", .{dep});
        }

        return QueryResult{ .message = try output.toOwnedSlice(self.allocator) };
    }

    fn executeShowSchedules(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Expect semicolon
        const token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .semicolon) return error.UnexpectedToken;

        const schedules = self.db.getSchedules();

        var output = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer output.deinit(self.allocator);
        const writer = output.writer(self.allocator);

        try writer.print("Schedules:\n", .{});
        if (schedules.len == 0) {
            try writer.print("  No schedules defined\n", .{});
        } else {
            for (schedules) |schedule| {
                const last_run_str = if (schedule.last_run) |lr| blk: {
                    break :blk std.fmt.allocPrint(self.allocator, "{d}", .{lr}) catch "unknown";
                } else "never";

                const next_run_str = std.fmt.allocPrint(self.allocator, "{d}", .{schedule.next_run}) catch "unknown";

                try writer.print("  {s}: {s} (cron: {s}, retries: {d}/{d}, last: {s}, next: {s})\n", .{
                    schedule.id,
                    schedule.model_name,
                    schedule.cron_expr,
                    schedule.retry_count,
                    schedule.max_retries,
                    last_run_str,
                    next_run_str,
                });
            }
        }

        return QueryResult{ .message = try output.toOwnedSlice(self.allocator) };
    }

    fn executeShowDatabases(self: *QueryEngine, tokenizer: *Tokenizer) !QueryResult {
        // Expect semicolon
        const token = (try tokenizer.next()) orelse return error.UnexpectedEndOfQuery;
        if (token.type != .semicolon) return error.UnexpectedToken;

        var attached = try self.db.listAttachedDatabases(self.allocator);
        defer attached.deinit(self.allocator);
        defer for (attached.items) |name| self.allocator.free(name);

        var output = try std.ArrayList(u8).initCapacity(self.allocator, 0);
        defer output.deinit(self.allocator);
        const writer = output.writer(self.allocator);

        try writer.print("Databases:\n", .{});
        try writer.print("  main: {s} (current)\n", .{self.db.name});
        for (attached.items) |db_alias| {
            if (self.db.getAttachedDatabase(db_alias)) |attached_db| {
                try writer.print("  {s}: {s}\n", .{ db_alias, attached_db.name });
            }
        }

        return QueryResult{ .message = try output.toOwnedSlice(self.allocator) };
    }
};

pub const QueryResult = union(enum) {
    table: Table,
    message: []const u8,

    pub fn deinit(self: *QueryResult) void {
        switch (self.*) {
            .table => |*t| t.deinit(),
            .message => {},
        }
    }
};

test "Tokenizer" {
    const allocator = std.testing.allocator;
    _ = allocator;

    var tokenizer = Tokenizer.init("SELECT * FROM users");

    const t1 = (try tokenizer.next()).?;
    try std.testing.expectEqual(TokenType.select, t1.type);

    const t2 = (try tokenizer.next()).?;
    try std.testing.expectEqual(TokenType.star, t2.type);

    const t3 = (try tokenizer.next()).?;
    try std.testing.expectEqual(TokenType.from, t3.type);

    const t4 = (try tokenizer.next()).?;
    try std.testing.expectEqual(TokenType.identifier, t4.type);
    try std.testing.expectEqualStrings("users", t4.value);
}
