# Grizzly PL for Mojo Arrow Database
# Inspired by Grizzly PL Functions

struct PLFunction:
    var name: String
    var params: List[String]
    var body: String

var functions = Dict[String, PLFunction]()

fn create_function(sql: String):
    # Parse CREATE FUNCTION name(params) RETURNS type { body }
    let start = sql.find("CREATE FUNCTION ")
    if start == -1: return
    let after = sql[start + 16:]
    let paren = after.find("(")
    let name = after[:paren].strip()
    let params_end = after.find(")")
    let params_str = after[paren+1:params_end]
    let params = params_str.split(",")
    let returns_start = after.find("RETURNS ")
    let returns_end = after.find(" {")
    let return_type = after[returns_start+8:returns_end].strip()
    let body_start = after.find("{") + 1
    let body_end = after.rfind("}")
    let body = after[body_start:body_end].strip()
    functions[name] = PLFunction(name, params, body)

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

fn call_function(name: String, args: List[Int64]) -> Int64:
    if name not in functions: return 0
    let func = functions[name]
    # Prepare vars for templating
    var vars = Dict[String, String]()
    for i in range(len(args)):
        vars["arg" + str(i)] = str(args[i])
    if len(args) > 0: vars["x"] = str(args[0])  # common
    # Eval template in body
    let templated_body = eval_template(func.body, vars)
    # Simple evaluation: assume body like "x * 2" or match or pipe
    if "match" in templated_body:
        # Parse match
        let match_start = templated_body.find("match ") + 6
        let var_name = templated_body[match_start:templated_body.find(" {")].strip()
        let cases_str = templated_body[templated_body.find("{") + 1:templated_body.rfind("}")]
        let cases = cases_str.split(",")
        var patterns = List[String]()
        var results = List[Int64]()
        for case in cases:
            let arrow = case.find("=>")
            let pat = case[:arrow].strip()
            let res_str = case[arrow+2:].strip()
            patterns.append(pat)
            results.append(atol(res_str))
        let value = args[0] if len(args) > 0 else 0
        return eval_match(value, patterns, results)
    elif "|>" in templated_body:
        # Pipe
        let parts = templated_body.split("|>")
        var ops = List[String]()
        for i in range(1, len(parts)):
            ops.append(parts[i].strip())
        let initial = args[0] if len(args) > 0 else 0
        return eval_pipe(initial, ops)
    elif "try" in templated_body:
        # Try catch
        let try_start = templated_body.find("try ") + 4
        let catch_start = templated_body.find(" catch ")
        let expr = templated_body[try_start:catch_start].strip()
        let catch_expr = templated_body[catch_start + 7:].strip()
        return eval_try(expr, catch_expr)
    elif templated_body == "x * 2" and len(args) > 0:
        return args[0] * 2
    return 0

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