"""
Debug PL-GRIZZLY lexer tokenization.
"""

from pl_grizzly_lexer import PLGrizzlyLexer

fn main() raises:
    var test_input = "(CREATE TABLE employees (id INT, name STRING))"
    print("Testing input:", test_input)

    var lexer = PLGrizzlyLexer(test_input)
    var tokens = lexer.tokenize()

    print("Tokens:")
    for i in range(len(tokens)):
        var token = tokens[i].copy()
        print("  ", token.type, ":", token.value)