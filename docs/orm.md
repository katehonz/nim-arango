# ORM Layer

Higher-level `Model[T]` abstraction with save/delete/refresh, finders, and validation.

## Model[T]

A `Model[T]` wraps a Nim object with collection metadata and tracks whether it's new or persisted.

```nim
import nim_arango

type User = object
  name: string
  email: string
  age: int
```

### Creating Models

```nim
let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)
let db = client.createDatabase("myapp")
let col = db.createCollection("users")

# Create a new model (not yet persisted)
var model = newModel[User](col, User(name: "Alice", email: "alice@example.com", age: 30))

# Or create from an existing document
let doc = col.readDocument[User]("myKey")
var model = newModelFromDoc[User](col, doc)
```

### Save — Create or Replace

```nim
var model = newModel[User](col, User(name: "Alice", email: "alice@example.com", age: 30))
let meta = model.save()                      # inserts (isNew=true)
echo model.key   # auto-generated

model.data.age = 31
let meta2 = model.save()                     # replaces (isNew=false)
```

### Delete

```nim
model.delete()                               # removes from database
model.isNew == true                          # ready for re-save
```

### Refresh — Re-read From Database

```nim
model.refresh()                              # fetches latest version
echo model.rev                               # updated revision
```

### Key/ID/Rev Accessors

```nim
echo model.key()   # document key
echo model.id()    # "collection/key"
echo model.rev()   # current revision
```

## Finders (Class-Level)

All finders are called on a `Collection` and return `Model[T]`.

### findByKey

```nim
let user = col.findByKey[User]("myKey")
echo user.data.name
```

### findAll

```nim
let allUsers = col.findAll[User]()
for user in allUsers:
  echo user.data.name
```

### findWhere — Filter with AQL

```nim
import std/json

let users = col.findWhere[User](
  "doc.age >= @minAge AND doc.age <= @maxAge",
  bindVars = %*{"minAge": 18, "maxAge": 30}
)

for u in users:
  echo u.data.name
```

### findByQuery — Custom AQL

```nim
let users = col.findByQuery[User](
  "FOR u IN users FILTER u.email LIKE '%@example.com' SORT u.name RETURN u",
  bindVars = %*{}
)
```

### countDocuments

```nim
echo col.countDocuments[User]()  # total documents in collection
```

### exists

```nim
if col.exists[User]("myKey"):
  echo "found"
```

### removeByKey

```nim
discard col.removeByKey("myKey")
```

## Batch ORM Operations

```nim
var models = @[
  newModel[User](col, User(name: "Alice", email: "alice@example.com", age: 30)),
  newModel[User](col, User(name: "Bob", email: "bob@example.com", age: 25)),
]

let metas = models.saveAll()
# or
let metas = models.deleteAll()
```

## Validation

Define a validator function and check models before saving.

```nim
proc validateUser(user: User): ValidateResult =
  var errors: seq[string] = @[]
  if user.name.len == 0:
    errors.add("name is required")
  if user.age < 0:
    errors.add("age must be positive")
  result = ValidateResult(valid: errors.len == 0, errors: errors)

let validator: Validator[User] = validateUser

var model = newModel[User](col, User(name: "Alice", email: "alice@example.com", age: 30))

if model.isValid(validator):
  discard model.save()
else:
  let result = model.validate(validator)
  for err in result.errors:
    echo "Validation error: ", err
```

## Types

```nim
type
  Model*[T] = ref object
    col*: Collection
    meta*: DocumentMeta
    data*: T
    isNew*: bool

  ValidateResult* = object
    valid*: bool
    errors*: seq[string]

  Validator*[T] = proc(doc: T): ValidateResult
```

## Public API

```nim
# Constructors
proc newModel*[T](col: Collection, data: T, key: string = ""): Model[T]
proc newModelFromDoc*[T](col: Collection, doc: Document[T]): Model[T]

# Instance methods
proc save*[T](m: Model[T], optsArgs: varargs[WriteOpt]): DocumentMeta
proc delete*[T](m: Model[T], optsArgs: varargs[WriteOpt]): DocumentMeta
proc refresh*[T](m: Model[T])

# Accessors
proc key*[T](m: Model[T]): string
proc id*[T](m: Model[T]): string
proc rev*[T](m: Model[T]): string

# Finders (Collection-level)
proc findByKey*[T](col: Collection, key: string, optsArgs: varargs[WriteOpt]): Model[T]
proc findAll*[T](col: Collection, optsArgs: varargs[WriteOpt]): seq[Model[T]]
proc findWhere*[T](col: Collection, filter: string, bindVars: JsonNode = %*{}): seq[Model[T]]
proc findByQuery*[T](col: Collection, aql: string, bindVars: JsonNode = %*{}): seq[Model[T]]
proc countDocuments*[T](col: Collection): int64
proc exists*[T](col: Collection, key: string): bool
proc removeByKey*(col: Collection, key: string, optsArgs: varargs[WriteOpt]): DocumentMeta

# Validation
proc validate*[T](m: Model[T], validator: Validator[T]): ValidateResult
proc isValid*[T](m: Model[T], validator: Validator[T]): bool

# Batch
proc saveAll*[T](models: var seq[Model[T]], optsArgs: varargs[WriteOpt]): seq[DocumentMeta]
proc deleteAll*[T](models: var seq[Model[T]], optsArgs: varargs[WriteOpt]): seq[DocumentMeta]
```
