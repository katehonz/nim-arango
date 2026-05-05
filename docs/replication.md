# Replication API

Set up follower replication, manage the applier, create batches, and sync revision trees.

## Make a Follower

Configure this ArangoDB instance to follow (replicate from) a leader:

```nim
import nim_arango

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)

let result = client.replicationMakeFollower(
  endpoint = "tcp://leader-host:8529",
  database = "myapp",
  username = "root",
  password = "password",
  verbose = true,
)
```

## Logger and Applier State

```nim
# Get replication logger state (what's been logged locally)
let loggerState = client.replicationLoggerState()
echo loggerState["state"]

# Get replication applier state (follower progress)
let state = client.replicationApplierState()
echo state.state       # "running" or "stopped"
echo state.synced      # true if fully synced
echo state.totalRequests
echo state.totalEvents
echo state.lastError
echo state.progress
```

## Applier Control

```nim
# Start the applier (optionally from a specific tick)
discard client.replicationApplierStart()
discard client.replicationApplierStart(fromTick = "12345")

# Stop the applier
discard client.replicationApplierStop()
```

## Inventory and Dump

```nim
# Get full inventory of collections and indexes
let inv = client.replicationInventory(includeSystem = false, global = false)

# Dump an entire collection's data
let data = client.replicationDump(
  collection = "users",
  fromTick = "1000",
  chunkSize = 5000,
)
```

## Batch API

Replication batches prevent WAL garbage collection during sync:

```nim
# Create a batch (TTL in seconds)
let batch = client.replicationCreateBatch(
  db = db,
  serverId = "SNGL-abc123",
  ttl = 600,
)
let batchId = batch["id"].getStr()

# Extend batch TTL
client.replicationExtendBatch(batchId, ttl = 600)

# Delete batch when done
client.replicationDeleteBatch(batchId)
```

## Revision Tree and Sync

```nim
# Get the Merkle revision tree for a collection
let tree = client.replicationGetRevisionTree(
  db = db,
  batchId = "123",
  collection = "users",
)

# Get revisions within specific ranges (for sync)
let revs = client.replicationGetRevisionsByRanges(
  db = db,
  batchId = "123",
  collection = "users",
  ranges = @[("rev-100", "rev-200"), ("rev-300", "rev-400")],
  resume = "",
)

# Fetch full documents by revision ID
let docs = client.replicationGetRevisionDocuments(
  db = db,
  batchId = "123",
  collection = "users",
  revisions = @["rev-100", "rev-101"],
)
```

## Types

```nim
type
  ReplicationApplierConfig* = object
    endpoint*: string
    database*: string
    username*: string
    password*: string
    maxConnectRetries*: int
    connectTimeout*: int
    requestTimeout*: int
    chunkSize*: int
    autoStart*: bool
    adaptivePolling*: bool
    autoResync*: bool
    includeSystem*: bool
    requireFromPresent*: bool
    idleMinWaitTime*: int
    idleMaxWaitTime*: int
    verbose*: bool

  ReplicationApplierState* = object
    state*: string
    lastProcessedContinuousTick*: string
    lastAppliedContinuousTick*: string
    lastAvailableContinuousTick*: string
    safeLastAppliedContinuousTick*: string
    synced*: bool
    totalRequests*: int64
    totalFailedConnects*: int64
    totalEvents*: int64
    totalOperationsExcluded*: int64
    progress*: JsonNode
    lastError*: JsonNode
    time*: string
```

## Public API

```nim
# Setup
proc replicationMakeFollower*(c: Client, endpoint: string, database: string = "",
                              username: string = "", password: string = "",
                              verbose: bool = false): JsonNode

# State
proc replicationLoggerState*(c: Client): JsonNode
proc replicationApplierState*(c: Client): ReplicationApplierState

# Applier control
proc replicationApplierStart*(c: Client, fromTick: string = ""): JsonNode
proc replicationApplierStop*(c: Client): JsonNode

# Inventory & Dump
proc replicationInventory*(c: Client, includeSystem: bool = false, global: bool = false): JsonNode
proc replicationDump*(c: Client, collection: string, fromTick: string = "", chunkSize: int = 0): JsonNode

# Batch API
proc replicationCreateBatch*(c: Client, db: Database, serverId: string, ttl: int = 600): JsonNode
proc replicationExtendBatch*(c: Client, batchId: string, ttl: int = 600)
proc replicationDeleteBatch*(c: Client, batchId: string)

# Revision sync
proc replicationGetRevisionTree*(c: Client, db: Database, batchId: string, collection: string): JsonNode
proc replicationGetRevisionsByRanges*(c: Client, db: Database, batchId: string,
                                       collection: string,
                                       ranges: seq[(string, string)],
                                       resume: string = ""): JsonNode
proc replicationGetRevisionDocuments*(c: Client, db: Database, batchId: string,
                                       collection: string,
                                       revisions: seq[string]): JsonNode
```
