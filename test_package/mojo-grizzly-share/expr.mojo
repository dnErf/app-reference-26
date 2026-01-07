# Grizzly PL AST for Mojo
# Abstract Syntax Tree for expressions, enabling robust parsing and evaluation

from pl import Value

enum Mode:
    runtime
    compile_time

struct PLFunction:
    var name: String
    var params: List[String]
    var body_ast: Expr
    var mode: Mode

# AST Node Types
enum ExprType:
    literal
    binary_op
    call
    match
    pipe
    try_catch
    template

struct Expr:
    var type: ExprType
    var literal_val: Int64  # For literals
    var op: String  # For binary ops
    var left: Pointer[Expr]  # Recursive
    var right: Pointer[Expr]
    var name: String  # For calls
    var args: List[Pointer[Expr]]
    var match_expr: Pointer[Expr]
    var cases: List[Tuple[Pointer[Expr], Pointer[Expr]]]  # pat => res
    var pipe_expr: Pointer[Expr]
    var pipe_ops: List[String]
    var try_expr: Pointer[Expr]
    var catch_expr: Pointer[Expr]
    var template_parts: List[String]  # For templates

    fn __init__(inout self, type: ExprType):
        self.type = type
        # Initialize others as needed

# Simple parser (tokenize and build AST)
fn parse_expr(s: String) -> Expr:
    # Basic tokenizer: split on spaces, operators
    var tokens = List[String]()
    var i = 0
    while i < len(s):
        if s[i] == ' ':
            i += 1
            continue
        elif s[i] in "+-*/":
            tokens.append(String(s[i]))
            i += 1
        elif s[i].isdigit():
            var num = ""
            while i < len(s) and s[i].isdigit():
                num += s[i]
                i += 1
            tokens.append(num)
        else:
            var word = ""
            while i < len(s) and s[i] not in " +-*/":
                word += s[i]
                i += 1
            tokens.append(word)
    # For now, assume simple: literal or binary
    if len(tokens) == 1 and tokens[0].isdigit():
        var e = Expr(ExprType.literal)
        e.literal_val = atol(tokens[0])
        return e
    elif len(tokens) == 3 and tokens[1] in "+-*/":
        var e = Expr(ExprType.binary_op)
        e.op = tokens[1]
        e.left = Pointer[Expr](parse_expr(tokens[0]))
        e.right = Pointer[Expr](parse_expr(tokens[2]))
        return e
    # Extend for others as needed
    return Expr(ExprType.literal)  # Default

# Evaluator
fn eval_ast(expr: Expr, vars: Dict[String, Int64]) -> Int64:
    if expr.type == ExprType.literal:
        return expr.literal_val
    elif expr.type == ExprType.binary_op:
        let left_val = eval_ast(expr.left[], vars)
        let right_val = eval_ast(expr.right[], vars)
        if expr.op == "+":
            return left_val + right_val
        elif expr.op == "-":
            return left_val - right_val
        elif expr.op == "*":
            return left_val * right_val
        elif expr.op == "/":
            return left_val // right_val  # Integer div
    # Extend for others
    return 0