# AQL Queries

Fluent AQL query builder with method chaining and type-safe cursors.

## Building Queries

```nim
import nim_arango

type User = object
  name: string
  email: string
  age: int
```

### Creating a Query

Queries are created on a `Database` and built via method chaining:

```nim
let q = db.query("FOR u IN users FILTER u.age > @minAge RETURN u")
  .bindParam("minAge", 18)
  .batchSize(50)
```

### bindParam[T]

Binds typed parameters to the AQL query. Supports all common Nim types:

```nim
let q = db.query("""
  FOR u IN users
    FILTER u.age > @minAge
    AND u.name == @name
    AND u.active == @active
    AND u.score > @score
    RETURN u
""")
  .bindParam("minAge", 18)       # int -> JSON int64
  .bindParam("name", "Alice")    # string -> JSON string
  .bindParam("active", true)     # bool -> JSON bool
  .bindParam("score", 3.5)       # float -> JSON float
```

You can also bind objects, tuples, or raw values:

```nim
type Filter = object
  category: string
  minPrice: float

let filter = Filter(category: "electronics", minPrice: 10.0)
q.bindParam("filter", filter)
```

### Query Options

| Method                    | Description                                           |
|---------------------------|-------------------------------------------------------|
| `.batchSize(n)`           | Cursor batch size (rows per network round-trip)       |
| `.fullCount()`            | Include total count regardless of LIMIT               |
| `.profile(level)`         | Enable query profiling (0=off, 1=basic, 2=detailed)   |
| `.maxRuntime(seconds)`    | Set max execution time in seconds                     |
| `.memoryLimit(bytes)`     | Set memory limit for the query                        |
| `.cache(enabled)`         | Enable/disable result caching                         |

```nim
let q = db.query("FOR u IN users RETURN u")
  .batchSize(100)
  .fullCount()
  .profile(2)
  .maxRuntime(10.0)
  .memoryLimit(1024 * 1024 * 64)
```

## Executing Queries

### exec[T] — Returns Cursor[T]

```nim
let cursor = db.query("FOR u IN users FILTER u.age > @minAge RETURN u")
  .bindParam("minAge", 18)
  .exec[User](db)
```

### execOne[T] — Returns First Row

```nim
let user = db.query("FOR u IN users FILTER u.key == @key RETURN u")
  .bindParam("key", "12345")
  .execOne[User](db)
# Raises ValueError if no results
```

### execExplain — Get Query Plan

```nim
let plan = db.query("FOR u IN users FILTER u.age > 18 RETURN u")
  .execExplain(db)
echo plan["plan"]
```

## Cursor[T] Methods

Cursors lazily fetch results in batches. Always call `close()` when done.

```nim
let cursor = db.query("FOR u IN users RETURN u").exec[User](db)
```

### next() — Advance to Next Item

```nim
while cursor.next():
  let (user, meta) = cursor.read()
  echo user.name
```

### read() — Read Current Item

```nim
let (data: User, meta: DocumentMeta) = cursor.read()
```

### count() — Total Result Count

```nim
echo cursor.count()  # total matching documents
```

### all() — Collect All Results

```nim
let docs: seq[Document[User]] = cursor.all()
for doc in docs:
  echo doc.data.name, " rev=", doc.meta.rev
```

### each() — Iterate with Callback

```nim
cursor.each(proc(doc: Document[User]) =
  echo doc.data.name
)
```

### fetchMore() — Pre-fetch Next Batch

```nim
if cursor.hasMore:
  cursor.fetchMore()
```

### close() — Release Cursor

```nim
cursor.close()  # Always close cursors to free server resources
```

## Complete Example

```nim
let cursor = db.query("""
  FOR u IN users
    FILTER u.age >= @minAge AND u.age <= @maxAge
    SORT u.name ASC
    LIMIT @offset, @limit
    RETURN u
""")
  .bindParam("minAge", 18)
  .bindParam("maxAge", 65)
  .bindParam("offset", 0)
  .bindParam("limit", 20)
  .batchSize(10)
  .exec[User](db)

echo "Total: ", cursor.count()

while cursor.next():
  let (user, meta) = cursor.read()
  echo " ", user.name, " (key=", meta.key, ")"

cursor.close()
```

## Public API

```nim
# Query building
proc query*(db: Database, aql: string): Query
proc bindParam*[T](q: Query, name: string, value: T): Query
proc batchSize*(q: Query, n: int): Query
proc fullCount*(q: Query): Query
proc profile*(q: Query, level: int): Query
proc maxRuntime*(q: Query, seconds: float): Query
proc memoryLimit*(q: Query, bytes: int64): Query
proc cache*(q: Query, enabled: bool): Query

# Execution
proc exec*[T](q: Query, db: Database): Cursor[T]
proc execOne*[T](q: Query, db: Database): T
proc execExplain*(q: Query, db: Database): JsonNode

# Cursor[T]
proc next*[T](c: Cursor[T]): bool
proc read*[T](c: Cursor[T]): (T, DocumentMeta)
proc count*[T](c: Cursor[T]): int64
proc all*[T](c: Cursor[T]): seq[Document[T]]
proc each*[T](c: Cursor[T], fn: proc(doc: Document[T]))
proc fetchMore*[T](c: Cursor[T])
proc close*[T](c: Cursor[T])
```
