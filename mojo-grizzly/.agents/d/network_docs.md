# Networking and Distributed Documentation

## Overview
The Networking and Distributed features enable Mojo-Grizzly to operate as a distributed database system. This includes remote query execution, replication, failover, and federated queries across multiple nodes.

## Features

### TCP Server for Remote Queries
- **Server**: Runs on `localhost:8080` using asyncio (Python interop)
- **Protocol**: HTTP/JSON for query requests
- **Security**: Requires `token: "secure_token_2026"` in POST body
- **Usage**: Send POST to `/query` with `{"sql": "SELECT...", "token": "..."}`

### Connection Pooling
- **Pool Size**: Max 10 connections
- **Reuse**: Connections are returned to pool after use
- **Efficiency**: Reduces overhead for frequent remote queries

### Federated Queries
- **Syntax**: `SELECT * FROM host:port@table`
- **Execution**: Parses node, fetches table remotely, executes query locally
- **Example**: `SELECT * FROM 127.0.0.1:8080@users WHERE id > 10`

### Replication
- **Master-Slave**: WAL operations synced to replicas
- **Sync**: On WAL append, sends operation to all replicas
- **Setup**: Use `ADD REPLICA host:port` to add replica nodes

### Failover
- **Detection**: Placeholder for checking node health
- **Switch**: Automatically switch to backup replica if master fails
- **Implementation**: `failover_check()` and `switch_to_replica()` in network.mojo

### Distributed JOINs
- **Support**: JOINs work by fetching remote tables locally
- **Example**: `SELECT * FROM local_table l JOIN 127.0.0.1:8080@remote_table r ON l.id = r.id`

### Network Protocol
- **Serialization**: JSON for queries and responses
- **Deserialization**: Parse incoming JSON, serialize results
- **Transport**: HTTP over TCP

## Commands

### ADD REPLICA
```
ADD REPLICA host:port
```
Adds a replica node for replication.

## Implementation Details

### Files
- **network.mojo**: Client functions for remote queries, replication, failover
- **rest_api.mojo**: Server with connection pooling
- **query.mojo**: Federated query parsing
- **block.mojo**: WAL replication
- **cli.mojo**: ADD REPLICA command

### Dependencies
- Asyncio for networking (Python interop)
- Remote nodes assumed to run the same Grizzly instance

### Limitations
- Simulated remote queries (placeholders for actual HTTP calls)
- Basic failover detection
- No load balancing or partitioning yet