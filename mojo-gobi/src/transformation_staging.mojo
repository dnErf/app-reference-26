from collections import Dict, List
from python import Python, PythonObject
from blob_storage import BlobStorage

@fieldwise_init
struct ValidationResult(Copyable, Movable):
    var is_valid: Bool
    var error_message: String

@fieldwise_init
struct TransformationModel(Copyable, Movable):
    var name: String
    var sql: String
    var dependencies: List[String]
    var created_at: String
    var updated_at: String
    var last_hash: String
    var last_execution: String

@fieldwise_init
struct Environment(Copyable, Movable):
    var name: String
    var desc: String
    var parent: String  # Parent environment name for inheritance
    var config: Dict[String, String]  # Configuration variables
    var env_type: String  # dev, staging, prod, etc.

struct PipelineExecution(Copyable, Movable):
    var id: String
    var environment: String
    var start_time: String
    var end_time: String
    var status: String
    var executed_models: List[String]
    var errors: List[String]

    fn __init__(out self, id: String, environment: String, start_time: String, end_time: String, status: String, executed_models: List[String], errors: List[String]):
        self.id = id
        self.environment = environment
        self.start_time = start_time
        self.end_time = end_time
        self.status = status
        self.executed_models = executed_models.copy()
        self.errors = errors.copy()

struct TransformationStaging:
    var db_path: String
    var models: Dict[String, TransformationModel]
    var environments: Dict[String, Environment]
    var lineage_graph: Dict[String, List[String]]
    var execution_history: List[PipelineExecution]

    fn __init__(out self, db_path: String):
        self.db_path = db_path
        self.models = Dict[String, TransformationModel]()
        self.environments = Dict[String, Environment]()
        self.lineage_graph = Dict[String, List[String]]()
        self.execution_history = List[PipelineExecution]()

    fn _get_current_timestamp(self) raises -> String:
        var py_time = Python.import_module("time")
        return String(py_time.time())

    fn _get_storage(self) raises -> BlobStorage:
        return BlobStorage(self.db_path)

    fn create_model(mut self, name: String, sql: String, dependencies: List[String] = List[String]()) raises -> Bool:
        # Validate the model
        var validation_result = self.validate_model(name, sql)
        if not validation_result.is_valid:
            print("Model validation failed:", validation_result.error_message)
            return False

        # Determine final dependencies
        var temp_deps: List[String]
        if len(dependencies) == 0:
            try:
                temp_deps = self.extract_dependencies_from_sql(sql)
            except:
                temp_deps = List[String]()
        else:
            temp_deps = dependencies.copy()
        
        var deps = temp_deps.copy()
        
        # Validate environment references
        var refs_result = self.validate_environment_references(deps)
        if not refs_result.is_valid:
            print("Dependency validation failed:", refs_result.error_message)
            return False

        var py_time = Python.import_module("time")
        var current_time = String(py_time.time())
        var model = TransformationModel(name, sql, deps ^, current_time, current_time, sql, "never")

        # Persist model
        var storage = self._get_storage()
        var model_data = self._serialize_model(model)
        var success = storage.write_blob("models/" + name + ".json", model_data)
        if not success:
            return False

        self.models[name] = model ^
        self.lineage_graph[name] = temp_deps.copy()

        print("Created transformation model:", name, "with", len(temp_deps), "dependencies")
        return True

    fn create_environment(mut self, name: String, desc: String = "", parent: String = "", env_type: String = "dev") raises -> Bool:
        if self.environments.__contains__(name):
            print("Environment", name, "already exists")
            return False

        var env = Environment(name, desc, parent, Dict[String, String](), env_type)

        # Persist environment
        var storage = self._get_storage()
        var env_data = self._serialize_environment(env)
        var success = storage.write_blob("environments/" + name + ".json", env_data)
        if not success:
            return False

        self.environments[name] = env ^

        print("Created environment:", name)
        return True

    fn execute_pipeline(mut self, environment_name: String) raises -> PipelineExecution:
        var executed = List[String]()
        var errs = List[String]()

        if not self.environments.__contains__(environment_name):
            errs.append("Environment " + environment_name + " does not exist")
            return PipelineExecution("exec_1", environment_name, "now", "later", "failed", executed, errs)

        # Get models that need execution (incremental)
        var models_to_execute = self._get_models_to_execute(environment_name)
        
        # Sort by dependencies
        var sorted_models = self._topological_sort(models_to_execute)
        
        for model_name in sorted_models:
            var success = self._execute_model(model_name, environment_name)
            if success:
                executed.append(model_name)
                # Run data quality checks
                var quality_result = self._run_data_quality_checks(model_name, environment_name)
                if not quality_result.is_valid:
                    errs.append("Data quality check failed for " + model_name + ": " + quality_result.error_message)
            else:
                errs.append("Failed to execute model " + model_name)

        var status = "success" if len(errs) == 0 else "failed"
        var execution = PipelineExecution("exec_1", environment_name, "now", "later", status, executed, errs)
        self.execution_history.append(execution.copy())
        return execution.copy()

    fn _get_models_to_execute(self, environment_name: String) raises -> List[String]:
        """Determine which models need to be executed based on incremental changes."""
        var to_execute = List[String]()
        
        for model_name in self.models.keys():
            var model = self.models[model_name].copy()
            var current_hash = self._compute_model_hash(model_name)
            
            # Check if model itself changed
            if model.last_hash != current_hash:
                to_execute.append(model_name)
                continue
            
            # Check if any dependency changed
            var deps_changed = False
            for dep in model.dependencies:
                if self.models.__contains__(dep):
                    var dep_model = self.models[dep].copy()
                    var dep_hash = self._compute_model_hash(dep)
                    if dep_model.last_hash != dep_hash:
                        deps_changed = True
                        break
            
            if deps_changed:
                to_execute.append(model_name)
        
        return to_execute.copy()

    fn _compute_model_hash(self, model_name: String) raises -> String:
        """Compute hash of model including its dependencies."""
        if not self.models.__contains__(model_name):
            return ""
        
        var model = self.models[model_name].copy()
        var hash_input = model.sql
        
        # Include dependency hashes
        for dep in model.dependencies:
            if self.models.__contains__(dep):
                var dep_model = self.models[dep].copy()
                hash_input += dep_model.last_hash
        
        # Simple hash (in real implementation, use proper hashing)
        var hash_val = 0
        for c in hash_input.codepoints():
            hash_val = (hash_val * 31 + Int(c)) % 1000000007
        return String(hash_val)

    fn _run_data_quality_checks(mut self, model_name: String, environment: String) raises -> ValidationResult:
        """Run data quality checks on the output of a model."""
        if not self.models.__contains__(model_name):
            return ValidationResult(False, "Model does not exist")
        
        var model = self.models[model_name].copy()
        
        # Check 1: SQL syntax validation
        var sql_valid = self.validate_sql(model.sql)
        if not sql_valid.is_valid:
            return ValidationResult(False, "SQL syntax error: " + sql_valid.error_message)
        
        # Check 2: Dependency validation
        for dep in model.dependencies:
            if not self.models.__contains__(dep):
                return ValidationResult(False, "Dependency '" + dep + "' does not exist")
        
        # Check 3: Environment configuration
        if not self.environments.__contains__(environment):
            return ValidationResult(False, "Environment '" + environment + "' does not exist")
        
        # Check 4: Mock data integrity check (would integrate with actual database)
        # For example, check row counts, null values, etc.
        
        return ValidationResult(True, "")

    fn _execute_model(mut self, model_name: String, environment: String) raises -> Bool:
        if not self.models.__contains__(model_name):
            return False

        print("Executing model:", model_name, "in environment:", environment)
        # Update timestamp and hash after execution
        var model = self.models[model_name].copy()
        model.last_execution = self._get_current_timestamp()
        model.last_hash = self._compute_model_hash(model_name)
        self.models[model_name] = model ^
        # Persist the updated model
        self._persist_model(model_name)
        # Simulate execution
        return True

    fn _topological_sort(self, model_names: List[String]) raises -> List[String]:
        # Simple topological sort - process models with no dependencies first
        var result = List[String]()
        var processed = List[String]()
        
        # First pass: models with no dependencies
        for name in model_names:
            if not self.lineage_graph.__contains__(name) or len(self.lineage_graph[name]) == 0:
                result.append(name)
                processed.append(name)
        
        # Second pass: models whose dependencies are already processed
        for name in model_names:
            if processed.__contains__(name):
                continue
            var can_process = True
            if self.lineage_graph.__contains__(name):
                for dep in self.lineage_graph[name]:
                    if not processed.__contains__(dep):
                        can_process = False
                        break
            if can_process:
                result.append(name)
                processed.append(name)
        
        # Add remaining models (may have cycles)
        for name in model_names:
            if not processed.__contains__(name):
                result.append(name)
        
        return result.copy()

    fn _serialize_model(self, model: TransformationModel) raises -> String:
        var json_mod = Python.import_module("json")
        var data = Python.dict()
        data["name"] = model.name
        data["sql"] = model.sql
        data["dependencies"] = Python.list()
        for dep in model.dependencies:
            data["dependencies"].append(dep)
        data["created_at"] = model.created_at
        data["updated_at"] = model.updated_at
        data["last_hash"] = model.last_hash
        data["last_execution"] = model.last_execution
        var json_str = json_mod.dumps(data)
        return String(json_str)

    fn _deserialize_model(self, json_str: String) raises -> TransformationModel:
        var json_mod = Python.import_module("json")
        var data = json_mod.loads(json_str)
        var name = String(data["name"])
        var sql = String(data["sql"])
        var deps = List[String]()
        for dep in data["dependencies"]:
            deps.append(String(dep))
        var created_at = String(data["created_at"])
        var updated_at = String(data["updated_at"])
        var last_hash = String(data["last_hash"])
        var last_execution = String(data["last_execution"])
        return TransformationModel(name, sql, deps ^, created_at, updated_at, last_hash, last_execution)

    fn _serialize_environment(self, env: Environment) raises -> String:
        var json_mod = Python.import_module("json")
        var data = Python.dict()
        data["name"] = env.name
        data["desc"] = env.desc
        data["parent"] = env.parent
        data["env_type"] = env.env_type
        data["config"] = Python.dict()
        for key in env.config.keys():
            data["config"][key] = env.config[key]
        var json_str = json_mod.dumps(data)
        return String(json_str)

    fn _deserialize_environment(self, json_str: String) raises -> Environment:
        var json_mod = Python.import_module("json")
        var data = json_mod.loads(json_str)
        var name = String(data["name"])
        var desc = String(data["desc"])
        var parent = String(data["parent"])
        var env_type = String(data["env_type"])
        var config = Dict[String, String]()
        for key in data["config"]:
            config[String(key)] = String(data["config"][key])
        return Environment(name, desc, parent, config ^, env_type)

    fn _persist_model(mut self, model_name: String) raises:
        var model = self.models[model_name].copy()
        var json_str = self._serialize_model(model)
        var storage = self._get_storage()
        var key = "models/" + model_name + ".json"
        var success = storage.write_blob(key, json_str)
        if not success:
            print("Failed to persist model:", model_name)

    fn list_models(self) raises -> List[String]:
        var result = List[String]()
        for model_name in self.models.keys():
            result.append(model_name)
        return result ^

    fn get_model_dependencies(self, model_name: String) raises -> List[String]:
        if not self.models.__contains__(model_name):
            return List[String]()
        var model = self.models[model_name].copy()
        return model.dependencies.copy()

    fn get_execution_history(self) raises -> List[String]:
        var result = List[String]()
        for model_name in self.models.keys():
            var model = self.models[model_name].copy()
            if model.last_execution != "never":
                var entry = model_name + " - Last executed: " + model.last_execution
                result.append(entry)
            else:
                var entry = model_name + " - Never executed"
                result.append(entry)
        return result ^

    fn list_environments(self) raises -> List[String]:
        var result = List[String]()
        for env_name in self.environments.keys():
            result.append(env_name)
        return result ^

    fn get_environment_config(self, env_name: String) raises -> Dict[String, String]:
        """Get resolved configuration for an environment including inheritance."""
        var resolved_config = Dict[String, String]()
        var current_env = env_name
        
        # Walk up the inheritance chain
        while current_env != "":
            if not self.environments.__contains__(current_env):
                break
            
            var env = self.environments[current_env].copy()
            # Collect keys first to avoid aliasing issues
            var keys = List[String]()
            for key in env.config.keys():
                keys.append(key)
            
            # Parent config is overridden by child config, so we add parent first
            for key in keys:
                if not resolved_config.__contains__(key):
                    resolved_config[key] = env.config[key]
            
            current_env = env.parent
        
        return resolved_config ^

    fn set_environment_config(mut self, env_name: String, key: String, value: String) raises -> Bool:
        """Set a configuration value for an environment."""
        if self.environments.__contains__(env_name):
            # Create updated environment
            var original_env = self.environments[env_name].copy()
            var updated_config = original_env.config.copy()
            updated_config[key] = value
            var updated_env = Environment(original_env.name, original_env.desc, original_env.parent, updated_config ^, original_env.env_type)
            
            # Persist the updated environment first
            var storage = self._get_storage()
            var env_data = self._serialize_environment(updated_env)
            var persist_success = storage.write_blob("environments/" + env_name + ".json", env_data)
            
            if persist_success:
                self.environments[env_name] = updated_env ^
                return True
            
        return False

    fn validate_sql(mut self, sql: String) raises -> ValidationResult:
        """Validate SQL syntax and return ValidationResult."""
        try:
            # Use Python's sqlparse for basic validation
            var sqlparse = Python.import_module("sqlparse")
            var parsed = sqlparse.parse(sql)
            
            if len(parsed) == 0:
                return ValidationResult(False, "Empty or invalid SQL")
            
            # Basic checks
            var statements = parsed[0]
            if not statements.tokens:
                return ValidationResult(False, "No SQL statements found")
            
            return ValidationResult(True, "")
        except:
            return ValidationResult(False, "SQL parsing error")

    fn extract_dependencies_from_sql(mut self, sql: String) raises -> List[String]:
        """Extract table/model dependencies from SQL using basic parsing."""
        var dependencies = List[String]()
        
        try:
            # Simple parsing for FROM clauses
            # This is a basic implementation - in production, use proper SQL parsing
            var sql_lower = sql.lower()
            
            # Split by whitespace and look for table names after FROM
            var words = sql_lower.split()
            var i = 0
            while i < len(words):
                var word = String(words[i])
                if word == "from" and i + 1 < len(words):
                    var table_name_raw = String(words[i + 1])
                    var table_name = table_name_raw.replace(",", "").replace(";", "")
                    # Clean up table name (remove quotes, etc.)
                    if table_name.startswith('"') and table_name.endswith('"'):
                        table_name = table_name[1:len(table_name)-1]
                    elif table_name.startswith("'") and table_name.endswith("'"):
                        table_name = table_name[1:len(table_name)-1]
                    
                    # Add if not already in dependencies and not empty
                    if len(table_name) > 0 and table_name != "select":
                        var found = False
                        for dep in dependencies:
                            if dep == table_name:
                                found = True
                                break
                        if not found:
                            dependencies.append(table_name)
                i += 1
            
        except:
            # If parsing fails, return empty list
            pass
        
        return dependencies ^

    fn validate_model(mut self, name: String, sql: String) raises -> ValidationResult:
        """Validate a transformation model and return ValidationResult."""
        # Check name uniqueness
        if self.models.__contains__(name):
            return ValidationResult(False, "Model '" + name + "' already exists")
        
        # Validate SQL syntax
        var sql_result = self.validate_sql(sql)
        if not sql_result.is_valid:
            return ValidationResult(False, "SQL validation failed: " + sql_result.error_message)
        
        # Check for basic SQL structure (should have SELECT)
        if not sql.lower().strip().startswith("select"):
            return ValidationResult(False, "Model SQL must start with SELECT")
        
        return ValidationResult(True, "")

    fn validate_environment_references(mut self, dependencies: List[String]) raises -> ValidationResult:
        """Validate that referenced tables/models exist in the current environment."""
        # For now, just check if dependencies are reasonable
        # In a full implementation, this would check against schema
        for dep in dependencies:
            if dep == "":
                return ValidationResult(False, "Empty dependency found")
            # Check for basic SQL injection patterns
            if ";" in dep or "--" in dep or "/*" in dep:
                return ValidationResult(False, "Potentially unsafe dependency: " + dep)
        
        return ValidationResult(True, "")

    fn _determine_final_dependencies(mut self, dependencies: List[String], sql: String) -> List[String]:
        if len(dependencies) == 0:
            try:
                return self.extract_dependencies_from_sql(sql)
            except:
                return List[String]()
        else:
            return dependencies.copy()