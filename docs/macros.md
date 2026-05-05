# Compile-time Macros

The `documentApi` macro generates type-safe, zero-boilerplate CRUD procs at compile time.

## documentApi(T)

```nim
import nim_arango

type User = object
  name: string
  email: string
  age: int

# Generate all CRUD procs for the User type
documentApi(User)
```

This one line generates the following procs, each taking `col: Collection` as the first parameter:

| Generated Proc          | Signature                                                      |
|-------------------------|----------------------------------------------------------------|
| `createUser`            | `(col: Collection, doc: User, ...WriteOpt): DocumentMeta`      |
| `readUser`              | `(col: Collection, key: string, ...WriteOpt): Document[User]`  |
| `updateUser`            | `(col: Collection, key: string, patch: User, ...WriteOpt): DocumentMeta` |
| `replaceUser`           | `(col: Collection, key: string, doc: User, ...WriteOpt): DocumentMeta` |
| `removeUser`            | `(col: Collection, key: string, ...WriteOpt): DocumentMeta`    |
| `userExists`            | `(col: Collection, key: string): bool`                         |
| `allUsers`              | `(col: Collection, ...WriteOpt): seq[Document[User]]`          |
| `batchCreateUsers`      | `(col: Collection, docs: seq[User], ...WriteOpt): seq[DocumentMeta]` |
| `countUsers`            | (via `countDocuments[User]`)                                   |

## Usage with User Type

```nim
let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)
let db = client.createDatabase("myapp")
let users = db.createCollection("users")

# Create
let meta = users.createUser(User(name: "Alice", email: "alice@example.com", age: 30))

# Read
let doc = users.readUser(meta.key)
echo doc.data.name

# Update
discard users.updateUser(meta.key, User(name: "Alice Updated"))

# Replace
discard users.replaceUser(meta.key, User(name: "Bob", email: "bob@example.com", age: 25))

# Remove
discard users.removeUser(meta.key)

# Check existence
echo users.userExists("someKey")

# List all
for d in users.allUsers():
  echo d.data.name

# Batch create
let newUsers = @[
  User(name: "Charlie", email: "charlie@example.com", age: 22),
  User(name: "Diana", email: "diana@example.com", age: 28),
]
let metas = users.batchCreateUsers(newUsers)

# With write options
let meta2 = users.createUser(User(name: "Eve", email: "eve@example.com", age: 35), withReturnNew())
```

## Multiple Types

You can generate APIs for any number of types:

```nim
type
  User = object
    name: string
    email: string
    age: int

  Product = object
    title: string
    price: float
    inStock: bool

documentApi(User)
documentApi(Product)

# Now use type-safe methods on different collections
let meta = users.createUser(User(name: "Alice", email: "alice@example.com", age: 30))
let prod = products.createProduct(Product(title: "Widget", price: 9.99, inStock: true))

let userDocs = users.allUsers()
let productDocs = products.allProducts()
```

## Naming Convention

For a type `T`, the generated procs follow these rules:

| Type `T`    | Create           | All               | Exists           | Batch Create         |
|-------------|------------------|-------------------|-------------------|----------------------|
| `User`      | `createUser`     | `allUsers`        | `userExists`      | `batchCreateUsers`   |
| `Product`   | `createProduct`  | `allProducts`     | `productExists`   | `batchCreateProducts`|
| `OrderItem` | `createOrderItem`| `allOrderItems`   | `orderitemExists` | `batchCreateOrderItems`|

The `exists` proc uses lowercase, while `create`/`read`/`update`/`replace`/`remove` use the original type name.

## Public API

```nim
macro documentApi*(T: typedesc): untyped
```
