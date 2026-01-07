# REST API Extension for Mojo Grizzly DB
# Lightweight HTTP server for remote queries.

import asyncio
import time
from arrow import Table
from query import execute_query
from extensions.security import validate_token, sanitize_input

var global_table = Table(Schema(), 0)  # Assume one table for now
var tables = Dict[String, Table]()  # For attached DBs

struct ConnectionPool:
    var pool: List[asyncio.Connection]
    var max_size: Int

    fn __init__(out self, max_size: Int = 10):
        self.pool = List[asyncio.Connection]()
        self.max_size = max_size

    fn get_connection(mut self) -> asyncio.Connection:
        if len(self.pool) > 0:
            return self.pool.pop()
        # Create new connection (placeholder)
        return asyncio.Connection()  # Placeholder

    fn return_connection(mut self, conn: asyncio.Connection):
        if len(self.pool) < self.max_size:
            self.pool.append(conn)

var conn_pool = ConnectionPool()

# Rate limiting: simple counter per IP
var request_counts = Dict[String, Int]()
var last_reset = time.time()

fn check_rate_limit(ip: String) -> Bool:
    var now = time.time()
    if now - last_reset > 60:  # Reset every minute
        request_counts.clear()
        last_reset = now
    if ip not in request_counts:
        request_counts[ip] = 0
    request_counts[ip] += 1
    return request_counts[ip] <= 100  # Max 100 requests per minute

fn init():
    print("REST API extension loaded. Starting server on port 8080...")
    asyncio.run(start_server())

async fn start_server():
    # Simple TCP server
    let server = await asyncio.start_server(handle_client, "localhost", 8080)
    await server.serve_forever()

async fn handle_client(reader, writer):
    let data = await reader.read(1024)
    let request = String(data)
    let ip = "127.0.0.1"  # Placeholder for IP
    if not check_rate_limit(ip):
        await writer.write(b"HTTP/1.1 429 Too Many Requests\r\n\r\n")
        await writer.close()
        return
    if request.startswith("POST /query"):
        # Parse body
        let body_start = request.find("\r\n\r\n")
        if body_start != -1:
            let body = request[body_start+4:]
            # Assume JSON {"sql": "SELECT...", "token": "xxx"}
            let sql_start = body.find('"sql":"') + 7
            let sql_end = body.find('"', sql_start)
            let sql = body[sql_start:sql_end]
            let token_start = body.find('"token":"') + 9
            let token_end = body.find('"', token_start)
            let token = body[token_start:token_end]
            # Validate token
            let user_id = validate_token(token)
            if user_id != "":
                let sanitized_sql = sanitize_input(sql)
                let result = execute_query(global_table, sanitized_sql, tables)
                let response = '{"status":"ok","rows":' + str(result.num_rows) + '}'
                await writer.write(("HTTP/1.1 200 OK\r\nContent-Length: " + str(len(response)) + "\r\n\r\n" + response).as_bytes())
            else:
                await writer.write(b"HTTP/1.1 401 Unauthorized\r\n\r\n")
    else:
        await writer.write(b"HTTP/1.1 404 Not Found\r\n\r\n")
    await writer.close()