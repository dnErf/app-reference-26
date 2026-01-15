"""
PL-GRIZZLY Trigger Execution Engine

This module provides trigger execution capabilities for DML operations,
supporting BEFORE/AFTER timing with procedure and pipeline execution.
"""

from collections import Dict, List
from python import Python
import time
from pl_grizzly_parser import ASTNode, PLGrizzlyParser
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_values import PLValue
from pl_grizzly_environment import Environment
from root_storage import RootStorage, Record
from orc_storage import ORCStorage
from ast_evaluator import ASTEvaluator
from profiling_manager import ProfilingManager, QueryProfile

# Trigger Execution Context
struct TriggerExecutionContext(Movable):
    var trigger_name: String
    var timing: String  # "BEFORE" or "AFTER"
    var event: String   # "INSERT", "UPDATE", "DELETE", "UPSERT"
    var target: String  # table/collection name
    var procedure_name: String
    var start_time: Float64
    var end_time: Float64
    var success: Bool
    var error_message: String
    var affected_rows: Int

    fn __init__(out self, trigger_name: String, timing: String, event: String, target: String, procedure_name: String):
        self.trigger_name = trigger_name
        self.timing = timing
        self.event = event
        self.target = target
        self.procedure_name = procedure_name
        self.start_time = 0.0
        self.end_time = 0.0
        self.success = False
        self.error_message = ""
        self.affected_rows = 0

# Trigger Execution Engine
struct TriggerExecutionEngine(Movable):
    var execution_count: Int
    var success_count: Int
    var failure_count: Int

    fn __init__(out self):
        self.execution_count = 0
        self.success_count = 0
        self.failure_count = 0

    fn execute_before_triggers(mut self, procedure_storage: RootStorage, target: String, event: String) raises -> List[String]:
        """Get list of BEFORE trigger procedures to execute for a DML operation."""
        return self.get_triggers_to_execute(procedure_storage, target, event, "BEFORE")

    fn execute_after_triggers(mut self, procedure_storage: RootStorage, target: String, event: String) raises -> List[String]:
        """Get list of AFTER trigger procedures to execute for a DML operation."""
        return self.get_triggers_to_execute(procedure_storage, target, event, "AFTER")

    fn execute_trigger_procedure(mut self, procedure_name: String, context: TriggerExecutionContext, mut env: Environment, mut orc_storage: ORCStorage, evaluator: ASTEvaluator) raises -> Bool:
        """Execute a single trigger procedure."""
        try:
            # Create a procedure call AST node
            var call_node = ASTNode("PROCEDURE_CALL", "")
            call_node.set_attribute("name", procedure_name)

            # Execute the procedure
            var result = evaluator.eval_procedure_call(call_node, env, orc_storage)

            if result.type == "error":
                print("Trigger procedure '" + procedure_name + "' returned error: " + result.value)
                return False
            else:
                print("Trigger procedure '" + procedure_name + "' executed successfully")
                return True

        except e:
            print("Exception executing trigger procedure '" + procedure_name + "': " + String(e))
            return False

    fn get_triggers_to_execute(mut self, procedure_storage: RootStorage, target: String, event: String, timing: String) raises -> List[String]:
        """Get list of procedure names for triggers that should execute."""
        var triggers = procedure_storage.find_triggers(target, event, timing)
        var procedure_names = List[String]()

        for trigger_record in triggers:
            var procedure_name = trigger_record.get_value("body")  # body contains procedure name
            if procedure_name != "":
                procedure_names.append(procedure_name)

        return procedure_names ^

    fn get_trigger_statistics(self) -> Dict[String, Int]:
        """Get trigger execution statistics."""
        var stats = Dict[String, Int]()
        stats["execution_count"] = self.execution_count
        stats["success_count"] = self.success_count
        stats["failure_count"] = self.failure_count
        return stats