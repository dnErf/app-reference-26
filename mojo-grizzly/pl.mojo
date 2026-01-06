# Grizzly PL for Mojo Arrow Database
# Inspired by Grizzly PL Functions

from expr import PLFunction, Expr, parse_expr, eval_ast

# enum Error:
#     DivisionByZero
#     InvalidArgument
#     ParseError

struct Value:


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