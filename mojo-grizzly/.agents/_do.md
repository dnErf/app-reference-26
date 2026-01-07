# Next Development Plan: Selected Topics

## 4. Extensions Ecosystem
- [ ] Implement missing core types (Block, GraphStore, Node, Edge, etc.) in block.mojo or separate modules
- [ ] Integrate extensions with core query engine (LOAD EXTENSION command)
- [ ] Add persistence layers for blockchain, graph, and lakehouse extensions
- [ ] Implement dynamic loading/unloading of extensions at runtime
- [ ] Develop plugin architecture with registration, dependency management, and isolation
- [ ] Support third-party plugins via shared libraries or embedded scripts
- [ ] Extend PL-Grizzly for advanced query capabilities:
  - Graph traversal functions (shortest_path, neighbors)
  - Time travel query functions (as_of_timestamp)
  - Blockchain validation functions (verify_chain)
  - Custom aggregation functions
  - Async PL functions for concurrent operations
- [ ] Add plugin metadata (version, dependencies, capabilities)
- [ ] Implement security sandboxing for untrusted plugins
- [ ] Create plugin discovery and marketplace integration
- [ ] Develop API for plugins to hook into query execution, storage, or CLI

## 2. Query Optimization & Performance
- [ ] Implement query planner with logical/physical plans
- [ ] Add cost-based optimization using PL functions for cost estimation
- [ ] Enhance indexing: B-tree indexes, composite indexes
- [ ] Predicate pushdown for joins and filters
- [ ] Query rewriting and optimization rules
- [ ] Statistics collection for cardinality estimation

## 3. Storage & Persistence
- [ ] Complete BLOCK storage with ACID transactions
- [ ] Add compression algorithms (LZ4, ZSTD) using PL
- [ ] Implement partitioning and bucketing
- [ ] Delta Lake integration for lakehouse features
- [ ] WAL (Write-Ahead Logging) for durability
- [ ] Storage format auto-detection and conversion

## 5. Concurrency & Scalability
- [ ] Multi-threaded query execution with PL async functions
- [ ] Parallel scan and aggregation using SIMD
- [ ] Connection pooling and session management
- [ ] Memory pooling and garbage collection optimization
- [ ] Distributed query execution framework
- [ ] Lock-free data structures for high concurrency

## 7. CLI & User Experience
- [ ] Interactive REPL mode with auto-completion
- [ ] Enhanced error messages with PL-based formatting
- [ ] Query profiling and execution plan visualization
- [ ] Import/export wizards for data migration
- [ ] Configuration management and environment setup
- [ ] User authentication and permission system

## 8. Testing & Quality
- [ ] Comprehensive test suite expansion (unit, integration, performance)
- [ ] TPC-H benchmark implementation
- [ ] Fuzz testing for SQL parsing
- [ ] Memory leak detection and profiling
- [ ] Cross-platform compatibility testing
- [ ] Continuous integration pipeline setup

## 10. Documentation & Community
- [ ] Complete API documentation with examples
- [ ] User guides and tutorials
- [ ] Performance tuning guide
- [ ] Extension development documentation
- [ ] Community contribution guidelines
- [ ] Blog posts and case studies
