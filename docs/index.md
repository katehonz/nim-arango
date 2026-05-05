# nim-arango Documentation

A modern, type-safe **ArangoDB driver for Nim**.

## Table of Contents

- [Getting Started](getting-started.md) — installation, connection, first query
- [Client Configuration](client.md) — endpoints, auth, timeout, retry
- [Document CRUD](documents.md) — create, read, update, replace, delete, bulk
- [AQL Queries](queries.md) — fluent query builder, cursors, parameter binding
- [ORM Layer](orm.md) — Model[T] wrapper, save/delete/refresh, finders, validation
- [Compile-time Macros](macros.md) — `documentApi()` for ergonomic CRUD
- [Graph API](graph.md) — vertex/edge collections, traversals
- [Indexes](indexes.md) — persistent, geo, TTL, inverted, fulltext
- [ArangoSearch Views](views.md) — full-text search configuration
- [Transactions](transactions.md) — streaming transactions, ACID
- [Replication](replication.md) — make follower, applier, batch sync
- [Backup & Restore](backup.md) — create, restore, transfer
- [Cluster Management](cluster.md) — endpoints, health, shard operations
- [Observability](metrics.md) — Prometheus metrics, logging, circuit breaker
- [Advanced](advanced.md) — Foxx, Pregel, User Management

## Quick Start

```nim
import nim_arango

type User = object
  name: string
  email: string
  age: int

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)

let db = client.createDatabase("myapp")
let users = db.createCollection("users")

# Create
let meta = users.createDocument(User(name: "Alice", email: "alice@example.com", age: 30))

# Read (type-safe!)
let doc = users.readDocument[User](meta.key)
echo doc.data.name  # "Alice"

# Query with parameters
let cursor = db.query("FOR u IN users FILTER u.age > @age RETURN u")
  .bindParam("age", 18)
  .exec[User](db)

while cursor.next():
  let (user, _) = cursor.read()
  echo user.name

cursor.close()
client.close()
```

## Features

- **Type-safe documents** via Nim generics — `readDocument[User](key)` returns `Document[User]`
- **Compile-time macro** — `documentApi(User)` generates `createUser`, `readUser`, etc.
- **ORM layer** — `Model[T]` with `save()`, `delete()`, `refresh()`, `findByKey()`
- **Fluent query builder** — method chaining with AQL parameter binding
- **Connection pooling** via `std/httpclient` with keep-alive
- **Retry with exponential backoff** — configurable per-client
- **Prometheus metrics** — counters, gauges, histograms
- **Graph API** — traversals, edge definitions, vertex collections
- **ArangoSearch Views** — full-text search configuration
- **Index management** — persistent, geo, TTL, inverted, fulltext
- **Streaming transactions** — ACID across multiple operations
- **Pregel** — distributed graph analytics
- **Foxx** — microservice management
- **User management** — permissions and access control
- **Replication** — batch sync, revision tree, applier control
- **Backup & Restore** — create, list, upload/download transfer
- **Cluster management** — endpoints, statistics, health, shard operations
- **Server administration** — mode, shutdown, metrics, logs
