# Document CRUD

Type-safe document operations using Nim generics.

## Single Document Operations

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
let col = db.createCollection("users")
```

### Create

```nim
let meta = col.createDocument(User(name: "Alice", email: "alice@example.com", age: 30))
echo meta.key   # auto-generated or custom
echo meta.id    # "users/key"
echo meta.rev   # revision id
```

### Read

```nim
let doc = col.readDocument[User](meta.key)
echo doc.data.name   # "Alice"
echo doc.meta.rev    # current revision
```

### Update (partial merge)

```nim
discard col.updateDocument(meta.key, User(name: "Alice Updated"))
```

### Replace (full replacement)

```nim
discard col.replaceDocument(meta.key, User(name: "Bob", email: "bob@example.com", age: 25))
```

### Remove

```nim
discard col.removeDocument(meta.key)
```

### Check Existence

```nim
if col.documentExists("myKey"):
  echo "exists"
```

## WriteOpt Options

All CRUD operations accept optional `WriteOpt` parameters:

| Option                     | Description                                    |
|----------------------------|------------------------------------------------|
| `withReturnNew()`          | Return the newly created/updated document      |
| `withReturnOld()`          | Return the old version of the document         |
| `withWaitForSync()`        | Wait for data to be synced to disk             |
| `withSilent()`             | Suppress output (no response body)             |
| `withKeepNull(true/false)` | Keep null attributes (default: true)           |
| `withMergeObjects(true/false)` | Merge objects during patch (default: true) |
| `withIgnoreRevs()`         | Ignore `_rev` version checks                   |
| `withOverwriteMode(mode)`  | Overwrite mode: `"ignore"`, `"replace"`, `"update"`, `"conflict"` |
| `withRevision(rev)`        | Set expected revision for conditional ops      |
| `withIfMatch(rev)`         | Only apply if revision matches                 |

```nim
# Create and get the full new document back
let meta = col.createDocument(
  User(name: "Alice", email: "alice@example.com", age: 30),
  withReturnNew()
)

# Update with revision check
discard col.updateDocument("key", User(age: 31), withIfMatch("_rev_value"))

# Delete silently
discard col.removeDocument("key", withSilent())
```

## Bulk Operations

```nim
# Batch create
let users = @[
  User(name: "Alice", email: "alice@example.com", age: 30),
  User(name: "Bob", email: "bob@example.com", age: 25),
]
let metas = col.createDocuments(users)
```

## Types

### Document[T]

```nim
type
  Document*[T] = object
    meta*: DocumentMeta    # key, id, rev
    data*: T               # your type-safe data
```

### DocumentMeta

```nim
type
  DocumentMeta* = object
    key*: string   # document key
    id*: string    # "collection/key"
    rev*: string   # revision id
```

## Serialization

```nim
proc toJson*[T](doc: T): string    # Serialize Nim object to JSON
proc fromJson*[T](j: JsonNode): T  # Deserialize JSON to Nim object
```

```nim
import std/json

let json = toJson(User(name: "Alice", age: 30))
# {"name":"Alice","age":30}

let user = fromJson[User](parseJson(json))
```

## Public API

```nim
# Single document
proc createDocument*[T](col: Collection, doc: T, optsArgs: varargs[WriteOpt]): DocumentMeta
proc readDocument*[T](col: Collection, key: string, optsArgs: varargs[WriteOpt]): Document[T]
proc updateDocument*[T](col: Collection, key: string, patch: T, optsArgs: varargs[WriteOpt]): DocumentMeta
proc replaceDocument*[T](col: Collection, key: string, doc: T, optsArgs: varargs[WriteOpt]): DocumentMeta
proc removeDocument*(col: Collection, key: string, optsArgs: varargs[WriteOpt]): DocumentMeta
proc documentExists*(col: Collection, key: string): bool

# Bulk
proc createDocuments*[T](col: Collection, docs: seq[T], optsArgs: varargs[WriteOpt]): seq[DocumentMeta]

# Serialization
proc toJson*[T](doc: T): string
proc fromJson*[T](j: JsonNode): T

# Write options
proc withReturnNew*(): WriteOpt
proc withReturnOld*(): WriteOpt
proc withWaitForSync*(): WriteOpt
proc withSilent*(): WriteOpt
proc withKeepNull*(v: bool): WriteOpt
proc withMergeObjects*(v: bool): WriteOpt
proc withIgnoreRevs*(): WriteOpt
proc withOverwriteMode*(mode: string): WriteOpt
proc withRevision*(rev: string): WriteOpt
proc withIfMatch*(rev: string): WriteOpt
```
