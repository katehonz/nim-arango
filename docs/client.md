# Client Configuration

Client setup, server admin, and database management.

## Creating a Client

```nim
import nim_arango

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)
```

### Functional Options

| Option                        | Description                                   |
|-------------------------------|-----------------------------------------------|
| `withEndpoint(url)`           | Add a single endpoint (at least one required) |
| `withEndpoints(url1, url2)`   | Add multiple endpoints for load balancing     |
| `withBasicAuth(user, pass)`   | HTTP Basic authentication                     |
| `withJwtAuth(user, pass)`     | JWT authentication (call `jwtLogin` after)    |
| `withRawAuth(header)`         | Raw `Authorization` header value              |
| `withTimeout(ms)`             | Request timeout in milliseconds (default 30s) |
| `withRetryConfig(...)`        | Configure exponential backoff retry           |
| `withUserAgent(ua)`           | Set the User-Agent header                     |
| `withDriverInfo(info)`        | Set driver info for ArangoDB tracking         |

```nim
let client = newClient(
  withEndpoints("http://host1:8529", "http://host2:8529"),
  withBasicAuth("root", "password"),
  withTimeout(10_000),
  withRetryConfig(maxRetries = 5, initialBackoffMs = 100, maxBackoffMs = 10_000)
)
```

### JWT Authentication

```nim
let client = newClient(
  withEndpoint("http://localhost:8529"),
  withJwtAuth("root", "password")
)

# Login to obtain token
client.jwtLogin()

# Later, refresh the token
client.jwtRefresh()
```

## Lifecycle

```nim
client.close()  # Clean up transport resources
```

## Server Info

```nim
let v = client.version()
echo v.server   # "arango"
echo v.license  # "community"
echo v.version  # "3.11.x"

echo client.license()               # "community"
echo client.ping()                   # true
echo client.isAvailable()           # true
echo client.serverID()              # "SNGL-..."
echo client.versionWithOptions(details = true)
```

## Server Administration

```nim
# Server mode
echo client.serverMode()           # smDefault
client.setServerMode(smReadOnly)

# Statistics & metrics
let stats = client.serverStatistics()
echo stats.system
echo stats.http
echo client.serverMetrics()  # Prometheus format

# Logs
let logs = client.serverLogs(level = "ERROR", start = 0, size = 500)

# Shutdown
client.shutdown()
client.shutdown(removeFromCluster = true)
```

## Database Management

```nim
# List databases
for db in client.databases():
  echo db.name

# Get a database handle (lazy, no verification)
let db = client.database("myapp")

# Create a database (optionally with users)
let db = client.createDatabase("myapp")
let db = client.createDatabase("myapp", users = @[
  (username: "user1", password: "secret")
])

# Drop a database
client.dropDatabase("myapp")
```

## Public API

```nim
proc newClient*(optsArgs: varargs[ClientOption]): Client

# Client options
proc withEndpoint*(endpoint: string): ClientOption
proc withEndpoints*(endpoints: varargs[string]): ClientOption
proc withBasicAuth*(username, password: string): ClientOption
proc withJwtAuth*(username, password: string): ClientOption
proc withRawAuth*(value: string): ClientOption
proc withTimeout*(ms: int): ClientOption
proc withUserAgent*(ua: string): ClientOption
proc withDriverInfo*(info: string): ClientOption
proc withRetryConfig*(maxRetries: int = 3, initialBackoffMs: int = 200,
                      maxBackoffMs: int = 5000, backoffFactor: float = 2.0): ClientOption

# Lifecycle
proc close*(c: Client)

# Server info
proc version*(c: Client): VersionInfo
proc license*(c: Client): string
proc ping*(c: Client): bool
proc isAvailable*(c: Client): bool
proc serverID*(c: Client): string
proc versionWithOptions*(c: Client, details: bool = false): JsonNode

# Server admin
proc serverMode*(c: Client): ServerMode
proc setServerMode*(c: Client, mode: ServerMode)
proc shutdown*(c: Client, removeFromCluster: bool = false)
proc serverMetrics*(c: Client): string
proc serverStatistics*(c: Client): ServerStatistics
proc serverLogs*(c: Client, level: string = "", start: int = 0, size: int = 1000): JsonNode

# JWT helpers
proc jwtLogin*(c: Client)
proc jwtRefresh*(c: Client)

# Database management
proc createDatabase*(c: Client, name: string, users: seq[...] = @[]): Database
proc dropDatabase*(c: Client, name: string)
proc databases*(c: Client): seq[DatabaseInfo]
proc database*(c: Client, name: string): Database
```
