# REST API Extension for Mojo Grizzly DB
# Lightweight HTTP server for remote queries.

import asyncio
from arrow import Table
from query import execute_query
from extensions.secret import get_secret

var global_table = Table(Schema(), 0)  # Assume one table for now

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
            # Check token
            let stored_token = get_secret("api_token")
            if token == stored_token:
                let result = execute_query(global_table, sql)
                let response = '{"status":"ok","rows":' + str(result.num_rows) + '}'
                await writer.write(("HTTP/1.1 200 OK\r\nContent-Length: " + str(len(response)) + "\r\n\r\n" + response).as_bytes())
            else:
                await writer.write(b"HTTP/1.1 401 Unauthorized\r\n\r\n")
    else:
        await writer.write(b"HTTP/1.1 404 Not Found\r\n\r\n")
    await writer.close()