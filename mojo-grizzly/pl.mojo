# Grizzly PL for Mojo Arrow Database
# Inspired by Grizzly PL Functions

from expr import PLFunction, Expr, parse_expr, eval_ast
from block import GraphStore, Block
from extensions.lakehouse import LakeTable

# enum Error:
#     DivisionByZero
#     InvalidArgument
#     ParseError

struct Value(Copyable, Movable):
    var type: String  # "int", "float", "string"
    var int_val: Int64
    var float_val: Float64
    var str_val: String

    fn __init__(out self, type: String, int_val: Int64, float_val: Float64, str_val: String):
        self.type = type
        self.int_val = int_val
        self.float_val = float_val
        self.str_val = str_val

    fn __copyinit__(out self, existing: Value):
        self.type = existing.type
        self.int_val = existing.int_val
        self.float_val = existing.float_val
        self.str_val = existing.str_val

    fn __moveinit__(out self, deinit existing: Value):
        self.type = existing.type
        self.int_val = existing.int_val
        self.float_val = existing.float_val
        self.str_val = existing.str_val

# Simple pattern matching evaluator
fn eval_match(value: Int64, patterns: List[String], results: List[Int64]) -> Int64:
    for i in range(len(patterns)):
        let pat = patterns[i]
        if pat == "_" or pat == str(value):
            return results[i]
        # Simple range like 1..10
        if ".." in pat:
            let parts = pat.split("..")
            if len(parts) == 2:
                let low = atol(parts[0])
                let high = atol(parts[1])
                if value >= low and value <= high:
                    return results[i]
    return 0  # default

# Pipe chaining (simple)
fn eval_pipe(initial: Int64, ops: List[String]) -> Int64:
    var result = initial
    for op in ops:
        if op.startswith("filter"):
            # Simple, assume > val
            let val_str = op[op.find(">") + 1:]
            let val = atol(val_str)
            if result <= val:
                return 0  # filtered out
        elif op.startswith("map"):
            # Simple * 2
            if "* 2" in op:
                result *= 2
    return result

# Try/catch simulation (no exceptions in Mojo, so eval expr, if fails return catch)
fn eval_try(expr: String, catch_expr: String) -> Int64:
    # Simple: try to eval expr, if contains "error" return catch, else expr as int
    if "error" in expr:
        return atol(catch_expr)
    return atol(expr)

fn call_function(name: String, args: List[Int64]) -> Value:
    if name == "test":
        return Value("int", 42, 0.0, "")
    return Value("int", 0, 0.0, "")

# Example: CREATE FUNCTION double(x int64) RETURNS int64 { x * 2 }

# Templating evaluator (basic if/else)
fn eval_template(template: String, vars: Dict[String, String]) -> String:
    var result = template
    # Simple {if cond then 'true' else 'false' end}
    while "{if" in result:
        let if_start = result.find("{if ")
        let then_pos = result.find(" then ", if_start)
        let else_pos = result.find(" else ", then_pos)
        let end_pos = result.find(" end}", else_pos)
        if if_start == -1 or then_pos == -1 or else_pos == -1 or end_pos == -1:
            break
        let cond = result[if_start+4:then_pos].strip()
        let true_part = result[then_pos+6:else_pos].strip()
        let false_part = result[else_pos+6:end_pos].strip()
        # Simple eval: assume cond like "x > 5", check vars
        var condition_true = False
        if ">" in cond:
            let parts = cond.split(">")
            if len(parts) == 2:
                let var_name = parts[0].strip()
                let val_str = parts[1].strip()
                if var_name in vars:
                    let var_val = atol(vars[var_name])
                    let cmp_val = atol(val_str)
                    condition_true = var_val > cmp_val
        let replacement = true_part[1:-1] if condition_true else false_part[1:-1]  # remove quotes
        result = result[:if_start] + replacement + result[end_pos+5:]
    return result

fn abs_val(x: Float64) -> Float64:
    return x if x >= 0 else -x

fn round_val(x: Float64) -> Int64:
    return Int64(x + 0.5) if x >= 0 else Int64(x - 0.5)

fn ceil_val(x: Float64) -> Int64:
    return Int64(x) if x == Float64(Int64(x)) else Int64(x) + 1 if x > 0 else Int64(x)

fn floor_val(x: Float64) -> Int64:
    return Int64(x) if x == Float64(Int64(x)) else Int64(x) - 1 if x < 0 else Int64(x)

fn upper_str(s: String) -> String:
    return s.upper()

fn lower_str(s: String) -> String:
    return s.lower()

fn concat_str(s1: String, s2: String) -> String:
    return s1 + s2

fn substr(s: String, start: Int, length: Int) -> String:
    return s[start:start+length]

fn now_date() -> String:
    return "2026-01-06"  # Current date

fn date_func(s: String) -> String:
    # Simple date parsing, assume YYYY-MM-DD
    if len(s) == 10 and s[4] == '-' and s[7] == '-':
        return s
    return "invalid date"

fn extract_date(part: String, date: String) -> Int:
    # Extract year, month, day from YYYY-MM-DD
    if len(date) != 10:
        return 0
    if part.upper() == "YEAR":
        return atol(date[:4])
    elif part.upper() == "MONTH":
        return atol(date[5:7])
    elif part.upper() == "DAY":
        return atol(date[8:10])
    return 0

fn case_func(when_conditions: List[Bool], then_values: List[Value], else_value: Value) -> Value:
    for i in range(len(when_conditions)):
        if when_conditions[i]:
            return then_values[i]
    return else_value

fn row_number() -> Int64:
    return 1  # Window function, returns row number in partition

fn rank_func() -> Int64:
    return 1  # Rank function

fn sum_agg(values: List[Int64]) -> Int64:
    var s = 0
    for v in values:
        s += v
    return s

fn count_agg(values: List[Int64]) -> Int64:
    return len(values)

fn avg_agg(values: List[Int64]) -> Float64:
    return Float64(sum_agg(values)) / len(values)

fn min_agg(values: List[Int64]) -> Int64:
    var m = values[0]
    for v in values:
        if v < m:
            m = v
    return m

fn max_agg(values: List[Int64]) -> Int64:
    var m = values[0]
    for v in values:
        if v > m:
            m = v
    return m

# Advanced PL functions

fn shortest_path(graph: GraphStore, start: Int64, end: Int64) -> List[Int64]:
    # Dijkstra's algorithm
    var dist = Dict[Int64, Float64]()
    var prev = Dict[Int64, Int64]()
    var pq = List[Tuple[Float64, Int64]]()  # priority queue as list, simple
    dist[start] = 0.0
    pq.append((0.0, start))
    
    while len(pq) > 0:
        # Find min dist
        var min_idx = 0
        for i in range(1, len(pq)):
            if pq[i][0] < pq[min_idx][0]:
                min_idx = i
        let u = pq[min_idx][1]
        pq.remove(min_idx)
        
        if u == end:
            break
        
        # Neighbors
        for block in graph.edges.blocks:
            for row in range(block.data.num_rows()):
                if block.data.columns[0][row] == u:
                    let v = block.data.columns[1][row]
                    let weight = Float64(block.data.columns[2][row])
                    let alt = dist[u] + weight
                    if not v in dist or alt < dist[v]:
                        dist[v] = alt
                        prev[v] = u
                        pq.append((alt, v))
    
    # Reconstruct path
    var path = List[Int64]()
    var current = end
    while current in prev:
        path.insert(0, current)
        current = prev[current]
    if current == start:
        path.insert(0, start)
    return path

fn neighbors(graph: GraphStore, node_id: Int64) -> List[Int64]:
    # Find edges from node_id
    var neigh = List[Int64]()
    for block in graph.edges.blocks:
        for row in range(block.data.num_rows()):
            if block.data.columns[0][row] == node_id:
                neigh.append(block.data.columns[1][row])
    return neigh

fn as_of_timestamp(table: LakeTable, timestamp: String) -> Table:
    return table.query_as_of(timestamp)

fn verify_chain(blocks: List[Block]) -> Bool:
    return Block.verify_chain(blocks)

fn custom_agg(values: List[Int64], func: String) -> Int64:
    # Apply custom agg function
    if func == "sum":
        return sum_agg(values)
    elif func == "count":
        return count_agg(values)
    elif func == "min":
        return min_agg(values)
    elif func == "max":
        return max_agg(values)
    return 0

fn async_sum(values: List[Int64]) -> Int64:
    # Simulate async, just sum
    return sum_agg(values)