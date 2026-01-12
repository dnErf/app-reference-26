"""
PL-GRIZZLY Environment Module

Variable scoping and environment management for PL-GRIZZLY.
"""

from collections import Dict
from pl_grizzly_values import PLValue

# Environment for variables
struct Environment(Copyable, Movable, ImplicitlyCopyable):
    var values: Dict[String, PLValue]

    fn __init__(out self):
        self.values = Dict[String, PLValue]()

    fn __copyinit__(out self, other: Environment):
        self.values = other.values.copy()

    fn define(mut self, name: String, value: PLValue):
        self.values[name] = value

    fn get(self, name: String) raises -> PLValue:
        if name in self.values:
            return self.values[name]
        # Error: undefined variable
        return PLValue.error("undefined variable: " + name)

    fn assign(mut self, name: String, value: PLValue):
        self.values[name] = value