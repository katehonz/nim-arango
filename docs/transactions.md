# Streaming Transactions

ACID transactions spanning multiple collections.

## Begin a Transaction

```nim
import nim_arango

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)
let db = client.createDatabase("myapp")
```

```nim
let tx = db.beginTransaction(
  readCollections = @["products"],
  writeCollections = @["orders", "inventory"],
  exclusiveCollections = @["counters"],
  waitForSync = true,
  allowImplicit = false,
  lockTimeout = 3000,      # ms
)
```

### Parameters

| Parameter              | Type         | Default | Description                               |
|------------------------|--------------|---------|-------------------------------------------|
| `readCollections`      | `seq[string]`| `@[]`   | Collections read from                     |
| `writeCollections`     | `seq[string]`| `@[]`   | Collections written to                    |
| `exclusiveCollections` | `seq[string]`| `@[]`   | Collections locked exclusively            |
| `waitForSync`          | `bool`       | `false` | Wait for sync to disk                     |
| `allowImplicit`        | `bool`       | `true`  | Allow implicit (single-collection) transactions |
| `lockTimeout`          | `int`        | `0`     | Lock timeout in ms (0 = no timeout)       |

## Transaction Lifecycle

```nim
# Begin
let tx = db.beginTransaction(
  writeCollections = @["orders"],
  allowImplicit = false,
)

echo tx.id()  # "12345"

# Execute operations within the transaction
# ... use collections as normal ...

# Commit
tx.commit()

# Or abort
tx.abort()
```

## Query Transaction Status

```nim
let tx = db.beginTransaction(writeCollections = @["orders"])

let status = tx.status()  # "running"
tx.commit()
let status2 = tx.status() # "committed"
```

## List Running Transactions

```nim
let txs = db.runningTransactions()
for tx in txs:
  echo tx
```

## Complete Example

```nim
type Order = object
  item: string
  quantity: int

let db = client.createDatabase("shop")
let orders = db.createCollection("orders")
let inventory = db.createCollection("inventory")

let tx = db.beginTransaction(
  writeCollections = @["orders", "inventory"],
  exclusiveCollections = @["inventory"],
)

# CRUD within transaction
discard orders.createDocument(Order(item: "widget", quantity: 3))
let doc = orders.readDocument[Order]("existingKey")

# Commit all changes atomically
tx.commit()
```

## Transaction Type

```nim
type
  Transaction* = ref object
    id*: string
    db*: Database
```

## Public API

```nim
proc beginTransaction*(db: Database;
                       readCollections: seq[string] = @[];
                       writeCollections: seq[string] = @[];
                       exclusiveCollections: seq[string] = @[];
                       waitForSync: bool = false;
                       allowImplicit: bool = true;
                       lockTimeout: int = 0): Transaction

proc commit*(tx: Transaction)
proc abort*(tx: Transaction)
proc status*(tx: Transaction): string
proc id*(tx: Transaction): string
proc runningTransactions*(db: Database): seq[JsonNode]
```
