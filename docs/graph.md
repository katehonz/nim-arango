# Graph API

Vertex/edge collections, named graphs, and traversals.

## Creating a Graph

```nim
import nim_arango

let client = newClient(
  withEndpoint("http://localhost:8529"),
  withBasicAuth("root", "password")
)
let db = client.createDatabase("myapp")

# Define edge definitions
let edgeDefs = @[
  EdgeDefinition(
    collection: "knows",
    fromCollections: @["users"],
    toCollections: @["users"],
  ),
]

# Create named graph
let g = db.createGraph("social", edgeDefinitions = edgeDefs)
```

### EdgeDefinition

```nim
type
  EdgeDefinition* = object
    collection*: string          # edge collection name
    fromCollections*: seq[string]  # allowed source vertex collections
    toCollections*: seq[string]    # allowed target vertex collections
```

## Graph Instance Methods

```nim
# Get graph name
echo g.name()

# Get full graph info
let info = g.info()
echo info.name
for ed in info.edgeDefinitions:
  echo ed.collection, " from=", ed.fromCollections, " to=", ed.toCollections

# Drop graph
g.drop()
```

## Vertex and Edge Collections

```nim
# Create a vertex collection within the graph
let people = g.createVertexCollection("people")

# Create an edge collection connected to vertex collections
let relationships = g.createEdgeCollection("relationships",
  fromCols = @["users", "people"],
  toCols = @["users", "people"],
)

# Use vertex/edge collections for normal CRUD
discard people.createDocument(User(name: "Alice", email: "alice@example.com", age: 30))
```

## Traversal

Traverse a graph from a starting vertex, returning vertices along the path.

```nim
type Node = object
  name: string

# Simple traversal (single-hop)
let cursor = g.traversal[Node](
  "users/alice",
  withDirection("outbound"),
  withMaxDepth(2),
)

while cursor.next():
  let (node, meta) = cursor.read()
  echo node.name

cursor.close()
```

### Traversal Options

| Option                         | Description                                          |
|--------------------------------|------------------------------------------------------|
| `withDirection(dir)`           | `"outbound"`, `"inbound"`, or `"any"` (default: outbound) |
| `withMinDepth(depth)`          | Minimum traversal depth (default: 1)                 |
| `withMaxDepth(depth)`          | Maximum traversal depth (default: 1)                 |
| `withVertexUniqueness(mode)`   | `"path"` or `"global"` (default: path)               |
| `withEdgeUniqueness(mode)`     | `"path"` or `"global"` (default: path)               |

```nim
# Deep traversal with options
let cursor = g.traversal[Node](
  "users/alice",
  withDirection("any"),
  withMinDepth(1),
  withMaxDepth(5),
  withVertexUniqueness("global"),
  withEdgeUniqueness("path"),
)
```

## Database-level Graph Operations

```nim
# Get a graph handle (lazy)
let g = db.graph("social")

# List all graphs
for gInfo in db.graphs():
  echo gInfo.name
```

## GraphInfo Type

```nim
type
  GraphInfo* = object
    name*: string
    edgeDefinitions*: seq[EdgeDefinition]
    orphanCollections*: seq[string]
    isSmart*: bool
    numberOfShards*: int
    replicationFactor*: int
```

## Public API

```nim
# Graph management (Database)
proc graph*(db: Database, name: string): Graph
proc createGraph*(db: Database, name: string, edgeDefinitions: seq[EdgeDefinition] = @[],
                  orphanCollections: seq[string] = @[]): Graph
proc graphs*(db: Database): seq[GraphInfo]

# Graph instance
proc name*(g: Graph): string
proc info*(g: Graph): GraphInfo
proc drop*(g: Graph)

# Vertex & Edge collections
proc createVertexCollection*(g: Graph, name: string): Collection
proc createEdgeCollection*(g: Graph, name: string, fromCols, toCols: seq[string]): Collection

# Traversal
proc traversal*[T](g: Graph, startVertex: string, optsArgs: varargs[TraverseOpt]): Cursor[T]

# Traversal options
proc withDirection*(direction: string): TraverseOpt
proc withMinDepth*(depth: int): TraverseOpt
proc withMaxDepth*(depth: int): TraverseOpt
proc withVertexUniqueness*(mode: string): TraverseOpt
proc withEdgeUniqueness*(mode: string): TraverseOpt
```
