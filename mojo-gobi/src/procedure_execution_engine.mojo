"""
PL-GRIZZLY Procedure Execution Engine

This module provides runtime execution capabilities for stored procedures,
supporting both synchronous and asynchronous execution modes with error handling
and performance profiling.
"""

from collections import Dict, List
from python import Python
import time
from memory import UnsafePointer
from pl_grizzly_parser import ASTNode, PLGrizzlyParser
from pl_grizzly_lexer import PLGrizzlyLexer
from pl_grizzly_values import PLValue
from pl_grizzly_environment import Environment
from root_storage import RootStorage, Record
from orc_storage import ORCStorage
from ast_evaluator import ASTEvaluator
from profiling_manager import ProfilingManager, QueryProfile

# Procedure Execution Context
struct ProcedureExecutionContext(Movable):
    var procedure_name: String
    var parameters: Dict[String, PLValue]
    var execution_mode: String  # "sync" or "async"
    var raises_exception: String
    var return_type: String
    var receiver_type: String
    var start_time: Float64
    var end_time: Float64
    var success: Bool
    var error_message: String
    var result: Optional[PLValue]

    fn __init__(out self, procedure_name: String):
        self.procedure_name = procedure_name
        self.parameters = Dict[String, PLValue]()
        self.execution_mode = "sync"
        self.raises_exception = ""
        self.return_type = "void"
        self.receiver_type = ""
        self.start_time = 0.0
        self.end_time = 0.0
        self.success = False
        self.error_message = ""
        self.result = None

# Procedure Execution Engine
struct ProcedureExecutionEngine(Movable):
    var procedure_storage: RootStorage
    var profiler: ProfilingManager
    var active_executions: Dict[String, String]  # execution_id -> status

    fn __init__(out self) raises:
        # Initialize with defaults - will be set later
        self.procedure_storage = RootStorage("")
        self.profiler = ProfilingManager()
        self.active_executions = Dict[String, String]()

    fn set_procedure_storage(mut self, mut procedure_storage: RootStorage):
        """Set the procedure storage."""
        self.procedure_storage = procedure_storage ^

    fn set_profiler(mut self, mut profiler: ProfilingManager):
        """Set the profiler."""
        self.profiler = profiler ^

    fn execute_procedure(
        mut self,
        procedure_name: String,
        parameters: Dict[String, PLValue],
        mut env: Environment,
        mut orc_storage: ORCStorage,
        mut evaluator: ASTEvaluator
    ) raises -> PLValue:
        """Execute a stored procedure with the given parameters."""

        # Check if procedure exists
        if not self.procedure_storage.procedure_exists(procedure_name):
            return PLValue("error", "Procedure '" + procedure_name + "' does not exist")

        # Get procedure definition
        var procedure_entity = self.procedure_storage.get_entity("procedure", procedure_name)
        if not procedure_entity:
            return PLValue("error", "Procedure '" + procedure_name + "' not found")

        var procedure_record = procedure_entity.value().copy()
        var procedure_body = procedure_record.get_value("body")
        var metadata = procedure_record.get_value("metadata")

        if procedure_body == "":
            return PLValue("error", "Procedure '" + procedure_name + "' has no body")

        # Parse procedure metadata to get execution context
        var context = self.parse_procedure_metadata(procedure_name, metadata, parameters)

        # Start profiling
        context.start_time = Float64(Python.import_module("time").time()) if self.profiler.is_enabled() else 0.0

        # Execute based on mode
        if context.execution_mode == "async":
            return self.execute_async_procedure(context, procedure_body, env, orc_storage, evaluator)
        else:
            return self.execute_sync_procedure(context, procedure_body, env, orc_storage, evaluator)

    fn execute_sync_procedure(
        mut self,
        mut context: ProcedureExecutionContext,
        procedure_body: String,
        mut env: Environment,
        mut orc_storage: ORCStorage,
        mut evaluator: ASTEvaluator
    ) raises -> PLValue:
        """Execute procedure synchronously."""

        try:
            # Create execution environment
            var procedure_env = self.create_procedure_environment(context, env)

            # Parse and execute procedure body
            var result = self.execute_procedure_body(procedure_body, procedure_env, orc_storage, evaluator)

            # Mark as successful
            context.success = True
            context.result = result
            context.end_time = Float64(Python.import_module("time").time()) if self.profiler.is_enabled() else 0.0

            # Record profiling
            if self.profiler.is_enabled():
                var execution_time = context.end_time - context.start_time
                self.profiler.record_query_execution(
                    "PROCEDURE " + context.procedure_name,
                    execution_time,
                    False,
                    1,  # procedures typically return single result
                    False
                )

            return result

        except e:
            # Handle execution error
            context.success = False
            context.error_message = String(e)
            context.end_time = Float64(Python.import_module("time").time()) if self.profiler.is_enabled() else 0.0

            # Check if we should raise the specified exception
            if context.raises_exception != "":
                return PLValue("error", context.raises_exception + ": " + context.error_message)
            else:
                return PLValue("error", "Procedure execution failed: " + context.error_message)

    fn execute_async_procedure(
        mut self,
        mut context: ProcedureExecutionContext,
        procedure_body: String,
        mut env: Environment,
        mut orc_storage: ORCStorage,
        mut evaluator: ASTEvaluator
    ) raises -> PLValue:
        """Execute procedure asynchronously (simplified for now)."""

        # Generate execution ID
        var execution_id = context.procedure_name + "_" + String(Python.import_module("time").time())

        # For now, execute synchronously but mark as async
        var result = self.execute_sync_procedure(context, procedure_body, env, orc_storage, evaluator)

        # Store execution status
        self.active_executions[execution_id] = "completed"

        return PLValue("string", "Procedure '" + context.procedure_name + "' executed asynchronously with ID: " + execution_id)

    fn get_execution_status(self, execution_id: String) raises -> PLValue:
        """Get the status of an asynchronous procedure execution."""

        if execution_id not in self.active_executions:
            return PLValue("error", "Execution ID '" + execution_id + "' not found")

        var status = self.active_executions[execution_id]
        return PLValue("string", "Execution " + execution_id + " " + status)

    fn cancel_execution(mut self, execution_id: String) raises -> PLValue:
        """Cancel an asynchronous procedure execution."""

        if execution_id not in self.active_executions:
            return PLValue("error", "Execution ID '" + execution_id + "' not found")

        # Remove from active executions
        _ = self.active_executions.pop(execution_id)

        return PLValue("string", "Execution " + execution_id + " cancelled")

    fn parse_procedure_metadata(
        self,
        procedure_name: String,
        metadata: String,
        parameters: Dict[String, PLValue]
    ) raises -> ProcedureExecutionContext:
        """Parse procedure metadata to create execution context."""

        var context = ProcedureExecutionContext(procedure_name)

        # Copy parameters
        for param_name in parameters:
            context.parameters[param_name] = parameters[param_name]

        # Parse metadata JSON (simplified parsing)
        # In a real implementation, this would use a proper JSON parser
        if "execution_mode" in metadata:
            if "async" in metadata:
                context.execution_mode = "async"
            else:
                context.execution_mode = "sync"

        if "raises" in metadata:
            # Extract raises information (simplified)
            context.raises_exception = "RuntimeError"  # Default

        if "return_type" in metadata:
            # Extract return type (simplified)
            context.return_type = "void"  # Default

        if "receiver_type" in metadata:
            # Extract receiver type (simplified)
            context.receiver_type = ""  # Default

        return context^

    fn create_procedure_environment(
        self,
        context: ProcedureExecutionContext,
        parent_env: Environment
    ) raises -> Environment:
        """Create a new environment for procedure execution."""

        var procedure_env = Environment()

        # Copy parent environment values
        for key in parent_env.values:
            procedure_env.values[key] = parent_env.values[key]

        # Add parameters to environment
        for param_name in context.parameters:
            procedure_env.define(param_name, context.parameters[param_name])

        # Add procedure context variables
        procedure_env.define("__procedure_name__", PLValue("string", context.procedure_name))
        procedure_env.define("__execution_mode__", PLValue("string", context.execution_mode))

        return procedure_env

    fn execute_procedure_body(
        mut self,
        procedure_body: String,
        mut env: Environment,
        mut orc_storage: ORCStorage,
        mut evaluator: ASTEvaluator
    ) raises -> PLValue:
        """Execute the procedure body statements."""

        # Parse the procedure body
        var lexer = PLGrizzlyLexer(procedure_body)
        var tokens = lexer.tokenize()
        var parser = PLGrizzlyParser(tokens)

        # Parse as a block of statements
        # For now, we'll execute each statement individually
        # In a full implementation, this would handle control flow, loops, etc.

        var result = PLValue("void", "")

        try:
            var ast = parser.parse()

            # Evaluate the parsed AST
            result = evaluator.evaluate(ast, env, orc_storage)

        except e:
            raise Error("Procedure execution error: " + String(e))

        return result

    fn list_active_executions(self) -> List[String]:
        """List all active asynchronous executions."""

        var execution_ids = List[String]()
        for execution_id in self.active_executions:
            execution_ids.append(execution_id)

        return execution_ids.copy()

    fn cleanup_completed_executions(mut self):
        """Clean up completed executions from memory."""
        # For now, keep all executions
        # In a full implementation, this would clean up old completed executions
        pass