# nim-arango

A modern, type-safe **ArangoDB driver for Nim**.

## Features

- **Type-safe documents** with Nim generics — `readDocument[User](key)` returns `Document[User]`
- **Fluent query builder** with method chaining and AQL parameter binding
- **Connection pooling** via `std/httpclient` with keep-alive
- **Retry with exponential backoff** — configurable per-client
- **Graph API** — traversals, edge definitions, vertex collections
- **ArangoSearch Views** — full-text search configuration
- **Index management** — persistent, geo, TTL, inverted, and more
- **Streaming transactions** — ACID across multiple operations
- **Pregel** — distributed graph analytics
- **Foxx** — microservice management
- **User management** — permissions and access control

## Installation

```bash
nimble install nim_arango
```

Or add to your `.nimble` file:

```nim
requires "nim_arango >= 0.1.0"
```

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
echo "Created: ", meta.key

# Read (type-safe!)
let doc = users.readDocument[User](meta.key)
echo "Read: ", doc.data.name, " (", doc.data.age, ")"

# Query with parameters
let cursor = db.query("FOR u IN users FILTER u.age > @age RETURN u")
  .bindParam("age", 18)
  .batchSize(100)
  .exec[User]()

while cursor.next():
  let (user, m) = cursor.read()
  echo user.name

cursor.close()
client.close()
```

## API Overview

### Client

```nim
let client = newClient(
  withEndpoints("http://node1:8529", "http://node2:8529"),
  withBasicAuth("root", "password"),
  withTimeout(10000),
  withRetryConfig(maxRetries = 5)
)

let version = client.version()
let db = client.database("mydb")
```

### Database

```nim
let db = client.createDatabase("newdb")
db.dropCollection("oldcol")
let col = db.createCollection("users", withNumberOfShards(3))
```

### Collection & Documents

```nim
let users = db.collection("users")

# CRUD with generics
let meta = users.createDocument(User(name: "Alice", age: 30))
let doc = users.readDocument[User](meta.key)
users.updateDocument(meta.key, User(name: "Alice Updated", age: 31))
users.replaceDocument(meta.key, User(name: "Bob", age: 25))
users.removeDocument(meta.key)

# Bulk insert
let metas = users.createDocuments(@[u1, u2, u3])
```

### Query

```nim
let cursor = db.query("FOR p IN products FILTER p.price > @min RETURN p")
  .bindParam("min", 10.0)
  .fullCount()
  .exec[Product]()

let all = cursor.all()
cursor.close()
```

### Graph

```nim
let g = db.createGraph("social", @[
  EdgeDefinition(
    collection: "follows",
    fromCollections: @["people"],
    toCollections: @["people"]
  )
])

let cursor = g.traversal[Person]("people/alice",
  withDirection("outbound"),
  withMaxDepth(3)
)
```

### Index

```nim
discard col.createIndex(idxPersistent, @["email"], withUnique(true))
discard col.createGeoIndex(@["location"], geoJson = true)
discard col.createTTLIndex("createdAt", 3600)
```

### View

```nim
let view = db.createArangoSearchView("searchView",
  withLinks(%*{ "users": { "fields": { "name": { "analyzers": ["text_en"] }}})
)
```

## Project Structure

```
src/nim_arango/
├── transport.nim       # Base transport + Request/Response
├── transport/
│   ├── http.nim        # HTTP transport with keep-alive
│   └── retry.nim       # Retry wrapper with backoff
├── auth.nim            # Basic, JWT, Raw authentication
├── errors.nim          # ArangoError types and codes
├── options.nim         # Functional options pattern
├── types.nim           # Core type definitions
├── client.nim          # Client API
├── database.nim        # Database API
├── collection.nim      # Collection API
├── document.nim        # Document CRUD with generics
├── query.nim           # AQL query builder + Cursor[T]
├── graph.nim           # Graph API
├── view.nim            # ArangoSearch views
├── index.nim           # Index management
├── analyzer.nim        # Text analyzers
├── pregel.nim          # Pregel jobs
├── foxx.nim            # Foxx services
└── user.nim            # User management
```

## Testing

```bash
nimble test
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full development plan.

## License

MIT
