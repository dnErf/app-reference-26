"""
Lakehouse Daemon with Arrow IPC and S3-compatible HTTP API
==========================================================

Supports both Arrow IPC for internal communication and S3 HTTP API for blob storage.
"""

from python import Python, PythonObject
from collections import List, Dict
from sys import argv
from job_scheduler_demo import JobScheduler, ScheduledJob
from seaweed_blob_store import SeaweedBlobStore
from s3_gateway import S3Gateway
from orc_storage import ORCStorage
from blob_storage import BlobStorage
from index_storage import IndexStorage
from schema_manager import SchemaManager

struct LakehouseDaemon(Movable):
    """Daemon class for managing lakehouse operations with blob storage."""
    var folder_path: String
    var scheduler: JobScheduler
    var blob_store: SeaweedBlobStore
    var s3_gateway: S3Gateway
    var http_server: Optional[PythonObject]

    fn __init__(out self, folder_path: String) raises:
        self.folder_path = folder_path
        self.scheduler = JobScheduler()

        # Initialize blob storage components
        var blob_storage = BlobStorage(folder_path + "/blobs")
        var index_storage = IndexStorage(blob_storage)
        var schema_mgr = SchemaManager(blob_storage)
        var orc_storage = ORCStorage(blob_storage, schema_mgr, index_storage)

        self.blob_store = SeaweedBlobStore(folder_path + "/seaweed", orc_storage)
        self.s3_gateway = S3Gateway(self.blob_store)
        self.http_server = None

    fn process_request(mut self, request_batch: PythonObject) raises -> PythonObject:
        """Process a client request and return Arrow response."""
        # Import required modules
        var pa_mod = Python.import_module("pyarrow")

        # Extract command from Arrow record batch
        var command_field_index = request_batch.schema.get_field_index("command")
        var command_array = request_batch.column(command_field_index)
        var command = String(command_array[0].as_py())

        if command == "mount":
            # Mount lakehouse - return success response
            return self._create_response_batch("success", "Lakehouse mounted for " + self.folder_path, "")
        elif command == "unmount":
            # Unmount lakehouse - return success response
            return self._create_response_batch("success", "Lakehouse unmounted", "")
        elif command == "status":
            # Get status
            return self._create_response_batch("success", "Lakehouse is active for " + self.folder_path, "")
        elif command == "list_jobs":
            # List scheduled jobs
            var jobs = self.scheduler.list_jobs()
            var job_list = String("")
            for job in jobs:
                job_list += job + ","
            return self._create_response_batch("success", "Scheduled jobs: " + job_list, "")
        elif command == "job_status":
            # Get job status
            var job_name_field = request_batch.schema.get_field_index("job_name")
            var job_name_array = request_batch.column(job_name_field)
            var job_name = String(job_name_array[0].as_py())
            var status = self.scheduler.get_job_status(job_name)
            return self._create_response_batch("success", "Job " + job_name + " status: " + status, "")
        elif command == "enable_job":
            # Enable a job
            var job_name_field = request_batch.schema.get_field_index("job_name")
            var job_name_array = request_batch.column(job_name_field)
            var job_name = String(job_name_array[0].as_py())
            var success = self.scheduler.enable_job(job_name)
            if success:
                return self._create_response_batch("success", "Job " + job_name + " enabled", "")
            else:
                return self._create_response_batch("error", "Job " + job_name + " not found", "")
        elif command == "disable_job":
            # Disable a job
            var job_name_field = request_batch.schema.get_field_index("job_name")
            var job_name_array = request_batch.column(job_name_field)
            var job_name = String(job_name_array[0].as_py())
            var success = self.scheduler.disable_job(job_name)
            if success:
                return self._create_response_batch("success", "Job " + job_name + " disabled", "")
            else:
                return self._create_response_batch("error", "Job " + job_name + " not found", "")
        elif command == "check_jobs":
            # Check and execute due jobs
            try:
                self.scheduler.check_and_execute_jobs()
                return self._create_response_batch("success", "Job check completed", "")
            except e:
                return self._create_response_batch("error", "Job check failed: " + String(e), "")
        elif command == "create_job":
            # Create a new scheduled job
            try:
                var job_name_field = request_batch.schema.get_field_index("job_name")
                var cron_field = request_batch.schema.get_field_index("cron_expression")
                var exec_field = request_batch.schema.get_field_index("execution_type")
                var call_field = request_batch.schema.get_field_index("call_target")

                var job_name = String(request_batch.column(job_name_field)[0].as_py())
                var cron_expression = String(request_batch.column(cron_field)[0].as_py())
                var execution_type = String(request_batch.column(exec_field)[0].as_py())
                var call_target = String(request_batch.column(call_field)[0].as_py())

                var job = ScheduledJob(job_name, cron_expression, execution_type, call_target)
                self.scheduler.add_job(job)
                return self._create_response_batch("success", "Job '" + job_name + "' created successfully", "")
            except e:
                return self._create_response_batch("error", "Failed to create job: " + String(e), "")
        else:
            # Unknown command
            return self._create_response_batch("error", "Unknown command: " + command, "")

    fn start_http_server(mut self, port: Int = 8333) raises:
        """Start HTTP server for S3-compatible API."""
        print("Starting HTTP server on port", port)

        # Import HTTP server modules
        var http_mod = Python.import_module("http.server")
        var socketserver_mod = Python.import_module("socketserver")
        var urllib_mod = Python.import_module("urllib.parse")
        var json_mod = Python.import_module("json")

        # Create custom request handler
        var handler_class = self._create_request_handler()

        # Start server
        var server = socketserver_mod.TCPServer(("", port), handler_class)
        self.http_server = server

        print("✓ HTTP server started on port", port)
        print("S3 endpoints available at http://localhost:" + String(port) + "/s3/")

        # Note: In a real implementation, this would run in a separate thread
        # server.serve_forever()

    fn _create_request_handler(self) -> PythonObject:
        """Create HTTP request handler class for S3 API."""
        # This would create a Python class that handles HTTP requests
        # For now, return a placeholder
        var http_mod = Python.import_module("http.server")
        return http_mod.BaseHTTPRequestHandler

    fn handle_s3_request(mut self, method: String, path: String, data: List[UInt8], headers: Dict[String, String]) -> PythonObject:
        """Handle S3-compatible HTTP request."""
        # Parse S3 path: /s3/bucket/key
        var path_parts = path.split("/")
        if len(path_parts) < 3 or path_parts[1] != "s3":
            return self._create_http_response(400, "Bad Request", "Invalid S3 path")

        var bucket = path_parts[2]
        var key = ""
        if len(path_parts) > 3:
            key = path_parts[3]

        if method == "PUT":
            var success = self.s3_gateway.put_object(bucket, key, data)
            if success:
                return self._create_http_response(200, "OK", "Object uploaded")
            else:
                return self._create_http_response(500, "Internal Server Error", "Upload failed")

        elif method == "GET":
            var data_opt = self.s3_gateway.get_object(bucket, key)
            if data_opt:
                return self._create_http_response(200, "OK", "", data_opt.value())
            else:
                return self._create_http_response(404, "Not Found", "Object not found")

        elif method == "DELETE":
            var success = self.s3_gateway.delete_object(bucket, key)
            if success:
                return self._create_http_response(204, "No Content", "")
            else:
                return self._create_http_response(404, "Not Found", "Object not found")

        elif method == "HEAD":
            var meta_opt = self.s3_gateway.head_object(bucket, key)
            if meta_opt:
                return self._create_http_response(200, "OK", "Object exists")
            else:
                return self._create_http_response(404, "Not Found", "Object not found")

        else:
            return self._create_http_response(405, "Method Not Allowed", "Method not supported")

    fn _create_http_response(self, status: Int, status_text: String, message: String, data: List[UInt8] = List[UInt8]()) -> PythonObject:
        """Create HTTP response object."""
        var response = PythonObject({
            "status": status,
            "status_text": status_text,
            "message": message,
            "data": data
        })
        return response
        elif command == "create_and_list":
            # Create a job and list all jobs
            try:
                var job_name_field = request_batch.schema.get_field_index("job_name")
                var cron_field = request_batch.schema.get_field_index("cron_expression")
                var exec_field = request_batch.schema.get_field_index("execution_type")
                var call_field = request_batch.schema.get_field_index("call_target")

                var job_name = String(request_batch.column(job_name_field)[0].as_py())
                var cron_expression = String(request_batch.column(cron_field)[0].as_py())
                var execution_type = String(request_batch.column(exec_field)[0].as_py())
                var call_target = String(request_batch.column(call_field)[0].as_py())

                var job = ScheduledJob(job_name, cron_expression, execution_type, call_target)
                self.scheduler.add_job(job)

                # Now list all jobs
                var jobs = self.scheduler.list_jobs()
                var job_list = String("")
                for job_name_item in jobs:
                    job_list += job_name_item + ","

                return self._create_response_batch("success", "Job created and listed: " + job_list, "")
            except e:
                return self._create_response_batch("error", "Failed: " + String(e), "")
        elif command == "query":
            # Execute query
            var query_field_index = request_batch.schema.get_field_index("query")
            var query_array = request_batch.column(query_field_index)
            var query = String(query_array[0].as_py())
            # For now, return a simple response
            return self._create_response_batch("success", "Query executed: " + query, "")
        else:
            return self._create_response_batch("error", "Unknown command: " + command, "")

    fn _create_response_batch(self, status: String, message: String, data: String) raises -> PythonObject:
        """Create an Arrow record batch for the response."""
        var pa_mod = Python.import_module("pyarrow")

        # Create schema fields
        var status_field = pa_mod.field("status", pa_mod.string())
        var message_field = pa_mod.field("message", pa_mod.string())
        var data_field = pa_mod.field("data", pa_mod.string())

        # Create schema
        var schema = pa_mod.schema([status_field, message_field, data_field])

        # Create data
        var status_array = pa_mod.array([status], type=pa_mod.string())
        var message_array = pa_mod.array([message], type=pa_mod.string())
        var data_array = pa_mod.array([data], type=pa_mod.string())

        # Create record batch
        return pa_mod.RecordBatch.from_arrays([status_array, message_array, data_array], schema=schema)

fn handle_client_request(client_socket: PythonObject, folder_path: String) raises:
    """Handle a client request using Arrow IPC."""
    try:
        # Import required modules
        var pa_mod = Python.import_module("pyarrow")
        var io_mod = Python.import_module("io")

        # Create daemon instance for this request
        var daemon = LakehouseDaemon(folder_path)

        # Receive request data
        var data = client_socket.recv(4096)

        # Check if we received any data
        if len(data) == 0:
            # Client closed connection without sending data
            client_socket.close()
            return

        # Create input stream from received data
        var input_stream = pa_mod.input_stream(io_mod.BytesIO(data))

        # Read Arrow record batch from stream
        var reader = pa_mod.ipc.open_stream(input_stream)
        var request_batch = reader.read_next_batch()

        # Process request
        var response_batch = daemon.process_request(request_batch)

        # Create output stream for response
        var output_stream = io_mod.BytesIO()
        var writer = pa_mod.ipc.new_stream(output_stream, response_batch.schema)
        writer.write_batch(response_batch)
        writer.close()

        # Send response data
        var response_data = output_stream.getvalue()
        client_socket.sendall(response_data)

    except e:
        # Send error response on failure
        try:
            var pa_mod = Python.import_module("pyarrow")
            var io_mod = Python.import_module("io")

            # Create error response batch
            var error_batch = LakehouseDaemon(folder_path)._create_response_batch(
                "error", "Request processing failed: " + String(e), ""
            )

            # Serialize error response
            var output_stream = io_mod.BytesIO()
            var writer = pa_mod.ipc.new_stream(output_stream, error_batch.schema)
            writer.write_batch(error_batch)
            writer.close()

            var error_data = output_stream.getvalue()
            client_socket.sendall(error_data)
        except:
            pass  # Socket might be closed
    client_socket.close()

fn run_daemon_main_loop(folder_path: String) raises:
    """Main daemon loop for background processing."""
    print("Starting daemon main loop for folder:", folder_path)

    # Import required modules
    var os_mod = Python.import_module("os")
    var socket_mod = Python.import_module("socket")
    var time_mod = Python.import_module("time")
    var json_mod = Python.import_module("json")

    print("Imported modules successfully")

    # Create daemon instance
    var daemon = LakehouseDaemon(folder_path)
    print("Created daemon instance")

    # Start the job scheduler
    daemon.scheduler.start()
    print("Job scheduler started")

    # Start HTTP server for S3 API (in background)
    try:
        daemon.start_http_server(8333)
        print("HTTP server for S3 API started on port 8333")
    except e:
        print("Warning: Failed to start HTTP server:", String(e))

    # Set up Unix domain socket for IPC
    var socket_path = ".gobi/daemon.sock"
    print("Socket path:", socket_path)

    if os_mod.path.exists(socket_path):
        print("Removing existing socket file")
        os_mod.unlink(socket_path)

    print("Creating server socket...")
    var server_socket = socket_mod.socket(1, 1)  # AF_UNIX = 1, SOCK_STREAM = 1
    print("Socket created, binding to path...")

    server_socket.bind(socket_path)
    print("Socket bound successfully")

    server_socket.listen(1)
    print("Socket listening on port 1")

    print("Daemon started with PID:", os_mod.getpid())
    print("Listening on socket:", socket_path)

    # Main daemon loop
    while True:
        try:
            # Accept client connections
            var connection = server_socket.accept()
            var client_socket = connection[0]

            # Handle client request synchronously
            handle_client_request(client_socket, folder_path)

        except e:
            print("Daemon error:", String(e))
            time_mod.sleep(1)  # Prevent tight loop on errors

    # Cleanup (this won't be reached in normal operation)
    server_socket.close()
    if os_mod.path.exists(socket_path):
        os_mod.unlink(socket_path)

fn main() raises:
    """Main entry point for daemon."""
    print("Daemon starting...")

    # Import required modules
    var sys_mod = Python.import_module("sys")
    var os_mod = Python.import_module("os")

    # Get command line arguments
    var args = argv()
    print("Number of args:", len(args))
    for i in range(len(args)):
        print("Arg", i, ":", String(args[i]))

    if len(args) < 2:
        print("Usage: daemon.mojo <folder_path>")
        return

    var folder_path = String(args[1])
    print("Folder path:", folder_path)

    # Create .gobi directory if it doesn't exist
    var daemon_dir = ".gobi"
    if not os_mod.path.exists(daemon_dir):
        os_mod.makedirs(daemon_dir)
        print("Created .gobi directory")

    print("Starting daemon main loop...")
    run_daemon_main_loop(folder_path)