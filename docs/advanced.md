# Advanced Features

Foxx microservices, Pregel graph analytics, user management, batch import, health checks, and logging.

## Foxx API

Manage ArangoDB Foxx microservices.

```nim
import nim_arango

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)
```

### Install a Service

```nim
client.installFoxxService(
  dbName = "myapp",
  mount = "/my-service",
  zipPath = "/path/to/service.zip",
  withTeardown(false),
  withSetup(true),
)
```

### Replace a Service

```nim
client.replaceFoxxService(
  dbName = "myapp",
  mount = "/my-service",
  zipPath = "/path/to/service-v2.zip",
  withTeardown(true),
  withSetup(true),
  withForce(),
)
```

### Uninstall a Service

```nim
client.uninstallFoxxService("myapp", "/my-service")
client.uninstallFoxxService("myapp", "/my-service", teardown = false)
```

### List Services

```nim
let services = client.listFoxxServices("myapp")
for svc in services:
  echo svc.mount, " ", svc.name, " v", svc.version
  echo "  development: ", svc.development
  echo "  scripts: ", svc.scripts
```

### FoxxServiceInfo

```nim
type
  FoxxServiceInfo* = object
    mount*: string
    name*: string
    version*: string
    development*: bool
    legacy*: bool
    provides*: seq[JsonNode]
    scripts*: seq[string]
```

## Pregel API

Distributed graph analytics engine.

```nim
type User = object
  name: string

let db = client.createDatabase("myapp")
```

### Start a Pregel Job

```nim
import std/json

let jobId = db.startPregelJob(
  withAlgorithm("pagerank"),
  withGraphName("social"),
  withParams(%*{"resultField": "rank"}),
  withMaxGSS(500),
)

echo "Job started: ", jobId
```

Or specify vertex/edge collections directly:

```nim
let jobId = db.startPregelJob(
  withAlgorithm("connectedcomponents"),
  withVertexCollections("users"),
  withEdgeCollections("follows"),
  withStore(true),
  withResultField("component"),
)
```

### Monitor and Cancel

```nim
# Get job status
let job = db.getPregelJob(jobId)
echo job.state         # "running", "done", "canceled", "error"
echo job.totalRuntime  # seconds
echo job.gss           # global supersteps
echo job.reports       # per-superstep statistics

# Cancel a job
db.cancelPregelJob(jobId)

# List all jobs
for job in db.listPregelJobs():
  echo job.id, " ", job.algorithm, " ", job.state
```

### Pregel Options

| Option                        | Description                                  |
|-------------------------------|----------------------------------------------|
| `withAlgorithm(name)`         | Algorithm: `"pagerank"`, `"connectedcomponents"`, `"shortestpath"`, etc. |
| `withGraphName(name)`         | Named graph to run on                        |
| `withVertexCollections(...)`  | Vertex collections (if no named graph)       |
| `withEdgeCollections(...)`    | Edge collections (if no named graph)         |
| `withParams(json)`            | Algorithm-specific parameters                |
| `withMaxGSS(n)`               | Max global supersteps (default: 1000)        |
| `withAsync(bool)`             | Async execution (default: false)             |
| `withResultField(field)`      | Field name for results (default: "result")   |

### PregelJobInfo

```nim
type
  PregelJobInfo* = object
    id*: string
    algorithm*: string
    created*: string
    expires*: string
    ttl*: int
    state*: string
    gss*: int
    totalRuntime*: float
    startupTime*: float
    computationTime*: float
    storageTime*: float
    reports*: seq[JsonNode]
```

## User Management (ArangoDB Internal Users)

Manage ArangoDB database users and access permissions.

```nim
# Create a user
let user = client.createUser("app_user", "secure_password", active = true)

# Get user info
let info = client.user("app_user")
echo info.active

# List all users
for u in client.users():
  echo u.user, " active=", u.active

# Set password
client.setPassword("app_user", "new_password")

# Activate/deactivate
client.setActive("app_user", active = false)

# Remove user
client.removeUser("app_user")
```

### Access Control

```nim
# Database access
client.setDatabaseAccess("app_user", "myapp", "rw")
echo client.databaseAccess("app_user", "myapp")  # "rw"

# Collection access
client.setCollectionAccess("app_user", "myapp", "users", "ro")
echo client.collectionAccess("app_user", "myapp", "users")  # "ro"
```

Permissions: `"rw"` (read/write), `"ro"` (read only), `"none"`

## Batch Operations

Efficient batch document processing.

```nim
type User = object
  name: string
  email: string

let col = db.createCollection("users")
```

### Generic Batch

```nim
# Batch create
let metas = col.documentBatch(@[
  User(name: "Alice", email: "alice@example.com"),
  User(name: "Bob", email: "bob@example.com"),
], verb = "POST")

# Batch update
let metas = col.updateDocuments(@[
  (key: "123", patch: User(name: "Alice Updated")),
  (key: "456", patch: User(name: "Bob Updated")),
])

# Batch replace
let metas = col.replaceDocuments(@[
  (key: "123", doc: User(name: "Alice", email: "a@example.com")),
  (key: "456", doc: User(name: "Bob", email: "b@example.com")),
])

# Batch remove
let metas = col.removeDocuments(@["123", "456"])
```

### High-Performance Import

```nim
# Import from objects
let result = col.importDocuments(
  @[User(name: "Alice", email: "alice@example.com"), User(name: "Bob", email: "bob@example.com")],
  ImportConfig(onDuplicate: "update"),
)
echo result["created"], " created, ", result["errors"], " errors"

# Import from JSON Lines
let lines = @[
  """{"name":"Alice","email":"alice@example.com"}""",
  """{"name":"Bob","email":"bob@example.com"}""",
]
let result = col.importJsonLines(lines, ImportConfig(complete: true))
```

### ImportConfig

```nim
type
  ImportConfig* = object
    waitForSync*: bool
    complete*: bool         # abort on first error if false
    details*: bool          # return per-document details
    overwrite*: bool        # overwrite existing documents
    onDuplicate*: string    # "error", "update", "replace", "ignore"
```

## Health Checks

```nim
# Ping
if client.ping():
  echo "reachable"

# Check availability
if client.isAvailable():
  echo "available"

# Server role
let role = client.serverRole()
case role
of srSingle: echo "standalone"
of srCoordinator: echo "coordinator"
of srPrimary: echo "primary DBServer"
of srAgent: echo "agency agent"
else: echo "undefined"

# Detailed cluster health
let health = client.clusterHealth()
echo health.status
for node in health.nodes:
  echo node.endpoint, " ", node.status
```

## Logging Module

```nim
# Built-in logger auto-initialized
# Control verbosity with setLogLevel

setLogLevel(lvlInfo)     # show info, warning, error
setLogLevel(lvlDebug)    # show all
setLogLevel(lvlError)    # show only errors

# Custom logging
logRequest("POST", "/_api/document/users", 201, 23, "localhost:8529")
logInfo("migration step 3 complete")
logDebug("cache hit ratio: 0.85")
logError("connection pool exhausted")
```

## Public API

```nim
# Foxx
proc installFoxxService*(c: Client, dbName, mount, zipPath: string, optsArgs: varargs[FoxxOption])
proc uninstallFoxxService*(c: Client, dbName, mount: string, teardown: bool = true)
proc replaceFoxxService*(c: Client, dbName, mount, zipPath: string, optsArgs: varargs[FoxxOption])
proc listFoxxServices*(c: Client, dbName: string): seq[FoxxServiceInfo]

# Pregel
proc startPregelJob*(db: Database, optsArgs: varargs[PregelOption]): string
proc getPregelJob*(db: Database, id: string): PregelJobInfo
proc cancelPregelJob*(db: Database, id: string)
proc listPregelJobs*(db: Database): seq[PregelJobInfo]

# User management
proc createUser*(c: Client, username, password: string, active: bool = true, extra: JsonNode = nil): UserInfo
proc user*(c: Client, username: string): UserInfo
proc users*(c: Client): seq[UserInfo]
proc removeUser*(c: Client, username: string)
proc setPassword*(c: Client, username, password: string)
proc setActive*(c: Client, username: string, active: bool)
proc databaseAccess*(c: Client, username, database: string): string
proc setDatabaseAccess*(c: Client, username, database, permission: string)
proc collectionAccess*(c: Client, username, database, collection: string): string
proc setCollectionAccess*(c: Client, username, database, collection, permission: string)

# Batch operations
proc documentBatch*[T](col: Collection, docs: seq[T], verb: string, optsArgs: varargs[WriteOpt]): seq[DocumentMeta]
proc updateDocuments*[T](col: Collection, docs: seq[tuple[key: string, patch: T]], optsArgs: varargs[WriteOpt]): seq[DocumentMeta]
proc replaceDocuments*[T](col: Collection, docs: seq[tuple[key: string, doc: T]], optsArgs: varargs[WriteOpt]): seq[DocumentMeta]
proc removeDocuments*(col: Collection, keys: seq[string], optsArgs: varargs[WriteOpt]): seq[DocumentMeta]
proc importDocuments*[T](col: Collection, docs: seq[T], cfg: ImportConfig = ImportConfig()): JsonNode
proc importJsonLines*(col: Collection, lines: seq[string], cfg: ImportConfig = ImportConfig()): JsonNode

# Health
proc serverRole*(c: Client): ServerRole
proc ping*(c: Client): bool
proc isAvailable*(c: Client): bool
proc clusterHealth*(c: Client): ClusterHealth

# Logging
proc logRequest*(verb, path: string, statusCode: int, durationMs: int64, endpoint: string, retryCount: int = 0)
proc logError*(msg: string)
proc logInfo*(msg: string)
proc logDebug*(msg: string)
proc setLogLevel*(level: Level)
```
