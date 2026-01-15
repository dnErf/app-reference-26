#!/usr/bin/env python3
"""
Arrow IPC client for PL-GRIZZLY daemon
"""

import socket
import pyarrow as pa
import io

def create_request_batch(command, query=""):
    """Create an Arrow record batch for the request."""
    schema = pa.schema([
        ("command", pa.string()),
        ("query", pa.string())
    ])

    command_array = pa.array([command], type=pa.string())
    query_array = pa.array([query], type=pa.string())

    return pa.RecordBatch.from_arrays([command_array, query_array], schema=schema)

def send_request(socket_path, command, query=""):
    """Send a request to the daemon and receive response."""
    # Create request batch
    request_batch = create_request_batch(command, query)

    # Serialize request to Arrow IPC stream
    output_stream = io.BytesIO()
    writer = pa.ipc.new_stream(output_stream, request_batch.schema)
    writer.write_batch(request_batch)
    writer.close()

    request_data = output_stream.getvalue()

    # Connect to daemon
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(socket_path)

    # Send request
    client.sendall(request_data)

    # Receive response
    response_data = client.recv(4096)
    client.close()

    # Deserialize response from Arrow IPC stream
    input_stream = pa.input_stream(io.BytesIO(response_data))
    reader = pa.ipc.open_stream(input_stream)
    response_batch = reader.read_next_batch()

    # Extract response fields
    status = response_batch.column(0)[0].as_py()
    message = response_batch.column(1)[0].as_py()
    data = response_batch.column(2)[0].as_py()

    return {
        "status": status,
        "message": message,
        "data": data
    }

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python client.py <command> [query]")
        sys.exit(1)

    command = sys.argv[1]
    query = sys.argv[2] if len(sys.argv) > 2 else ""

    socket_path = ".gobi/daemon.sock"

    try:
        response = send_request(socket_path, command, query)
        print(f"Status: {response['status']}")
        print(f"Message: {response['message']}")
        if response['data']:
            print(f"Data: {response['data']}")
    except Exception as e:
        print(f"Error: {e}")