# Getting Started

## Installation

```bash
nimble install nim_arango
```

Add to your `.nimble` file:

```nim
requires "nim_arango >= 0.1.0"
```

## Prerequisites

- Nim >= 2.0.0
- ArangoDB 3.11+ (for full feature support)

## Starting ArangoDB

```bash
docker run -d -p 8529:8529 -e ARANGO_ROOT_PASSWORD=password arangodb:3.11
```

Or with docker-compose:

```yaml
# docker-compose.yml
version: '3'
services:
  arangodb:
    image: arangodb:3.11
    environment:
      ARANGO_ROOT_PASSWORD: password
    ports:
      - "8529:8529"
```

## First Connection

```nim
import nim_arango

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)

echo client.version().version  # "3.11.x"
client.close()
```

## Create Database & Collection

```nim
let db = client.createDatabase("myapp")
let users = db.createCollection("users")
```

## Define Your Model

```nim
type User = object
  name: string
  email: string
  age: int
```

## First CRUD

```nim
# Create
let meta = users.createDocument(User(name: "Alice", email: "alice@example.com", age: 30))
echo "Key: ", meta.key

# Read
let doc = users.readDocument[User](meta.key)
echo "Name: ", doc.data.name

# Update
discard users.updateDocument(meta.key, User(name: "Alice Updated", email: "alice@example.com", age: 31))

# Delete
discard users.removeDocument(meta.key)
```

## First Query

```nim
let cursor = db.query("FOR u IN users FILTER u.age > @age SORT u.name ASC RETURN u")
  .bindParam("age", 18)
  .batchSize(10)
  .exec[User](db)

while cursor.next():
  let (user, meta) = cursor.read()
  echo user.name

cursor.close()
```

## Cleanup

```nim
db.dropCollection("users")
client.dropDatabase("myapp")
client.close()
```

## Next Steps

- [Document CRUD](documents.md) — full CRUD operations reference
- [AQL Queries](queries.md) — query builder, cursors
- [ORM Layer](orm.md) — higher-level model abstraction
- [Compile-time Macros](macros.md) — zero-boilerplate CRUD
