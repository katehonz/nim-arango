# Cluster Management

Manage ArangoDB cluster: endpoints, statistics, health, shard operations, and server lifecycle.

## Cluster Endpoints and Statistics

```nim
import nim_arango

let client = newClient(
  withEndpoint("http://coordinator:8529"),
  withBasicAuth("root", "password")
)

# List all cluster endpoints
for ep in client.clusterEndpoints():
  echo ep.endpoint, " ", ep.status, " ", ep.version

# Cluster statistics
let stats = client.clusterStatistics()
echo "DBServers: ", stats.dbServers
echo "Coordinators: ", stats.coordinators
echo "Agents: ", stats.agents
```

## Cluster Health

```nim
# Admin health (detailed)
let health = client.clusterHealth()
echo health.status
for node in health.nodes:
  echo node.endpoint, " ", node.status, " ", node.uptime, "s"

# API health
let apiHealth = client.clusterHealth()
echo apiHealth
```

## Shard Operations

```nim
# Move a shard from one DBServer to another
let result = client.moveShard(
  database = "myapp",
  collection = "users",
  shard = "s12345",
  fromServer = "DBServer1",
  toServer = "DBServer2",
)

# Rebalance shards across DBServers
let result = client.rebalanceShards()
let result = client.rebalanceShards(database = "myapp")
```

## Server Lifecycle (Cluster)

```nim
# Trigger cleanout — data migration off a DBServer
let result = client.cleanOutServer("SNGL-abc123")

# Resign all shards from a DBServer
let result = client.resignServer("SNGL-abc123")

# Check if a server has been cleaned out
if client.isCleanedOut("SNGL-abc123"):
  echo "ready for removal"

# Remove a server from the cluster
client.removeServer("SNGL-abc123")
```

## Database Inventory

```nim
let inv = client.databaseInventory("myapp")
echo inv["collections"]
echo inv["views"]
```

## Types

```nim
type
  ClusterEndpoint* = object
    endpoint*: string
    version*: string
    status*: string

  ClusterStatistics* = object
    dbServers*: int
    coordinators*: int
    agents*: int

  ClusterHealth* = object
    status*: string
    agency*: JsonNode
    nodes*: seq[NodeHealth]

  NodeHealth* = object
    endpoint*: string
    status*: string
    version*: string
    uptime*: int
```

## Public API

```nim
# Endpoints & Statistics
proc clusterEndpoints*(c: Client): seq[ClusterEndpoint]
proc clusterStatistics*(c: Client): ClusterStatistics
proc clusterHealth*(c: Client): JsonNode

# Shard operations
proc moveShard*(c: Client, database, collection, shard, fromServer, toServer: string): JsonNode
proc rebalanceShards*(c: Client, database: string = ""): JsonNode

# Server lifecycle
proc cleanOutServer*(c: Client, serverID: string): JsonNode
proc resignServer*(c: Client, serverID: string): JsonNode
proc isCleanedOut*(c: Client, serverID: string): bool
proc removeServer*(c: Client, serverID: string)

# Inventory
proc databaseInventory*(c: Client, dbName: string): JsonNode
```
