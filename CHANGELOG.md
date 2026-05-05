# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-05-05

### Added
- Core transport layer with HTTP and Async HTTP support
- Connection pooling via std/httpclient with keep-alive
- Retry transport with exponential backoff and jitter
- Circuit breaker for resilience
- Basic, JWT, and raw authentication
- Type-safe document CRUD with Nim generics (`Document[T]`)
- AQL query builder with method chaining and `Cursor[T]` iterator
- Database and collection management APIs
- Graph API with traversals and edge definitions
- ArangoSearch views and text analyzers
- Index management (persistent, geo, TTL, inverted)
- Streaming transactions support
- Pregel distributed graph analytics
- Foxx microservice management
- User management with permissions
- Bulk import and JSON Lines import
- Backup and restore APIs
- Replication APIs
- Cluster management and health check APIs
- Structured logging with std/logging
- Prometheus-compatible metrics
- Batch document operations
- Integration tests with GitHub Actions CI
- Docker Compose for local ArangoDB testing
- Examples: CRUD, Query, Graph
- README in English and Bulgarian

## [Unreleased]

### Planned
- Async/await document API variants
- Connection pool monitoring and metrics
- VST protocol support (optional)
- ORM-like macro layer for compile-time type generation
- Performance benchmarks against Go driver
