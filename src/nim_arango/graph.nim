## Graph API — vertices, edges, and traversals.

import std/[json, options, strformat]
import client, database, types

type
  EdgeDefinition* = object
    collection*: string
    fromCollections*: seq[string]
    toCollections*: seq[string]

  GraphInfo* = object
    name*: string
    edgeDefinitions*: seq[EdgeDefinition]
    orphanCollections*: seq[string]
    isSmart*: bool
    numberOfShards*: int
    replicationFactor*: int

  TraverseOpt* = proc(cfg: var TraverseConfig)

  TraverseConfig* = object
    direction*: string = "outbound"
    minDepth*: int = 1
    maxDepth*: int = 1
    vertexUniqueness*: string = "path"
    edgeUniqueness*: string = "path"

proc withDirection*(direction: string): TraverseOpt =
  proc opt(cfg: var TraverseConfig) = cfg.direction = direction
  opt

proc withMinDepth*(depth: int): TraverseOpt =
  proc opt(cfg: var TraverseConfig) = cfg.minDepth = depth
  opt

proc withMaxDepth*(depth: int): TraverseOpt =
  proc opt(cfg: var TraverseConfig) = cfg.maxDepth = depth
  opt

proc withVertexUniqueness*(mode: string): TraverseOpt =
  proc opt(cfg: var TraverseConfig) = cfg.vertexUniqueness = mode
  opt

proc withEdgeUniqueness*(mode: string): TraverseOpt =
  proc opt(cfg: var TraverseConfig) = cfg.edgeUniqueness = mode
  opt

proc name*(g: Graph): string = g.name

proc info*(g: Graph): GraphInfo =
  let j = g.db.client.doRequestJson("GET", "_api/gharial/" & g.name)
  let gNode = j["graph"]
  var edgeDefs: seq[EdgeDefinition] = @[]
  if gNode.hasKey("edgeDefinitions"):
    for ed in gNode["edgeDefinitions"].getElems():
      var fromArr: seq[string] = @[]
      var toArr: seq[string] = @[]
      if ed.hasKey("from"):
        for f in ed["from"].getElems():
          fromArr.add(f.getStr())
      if ed.hasKey("to"):
        for t in ed["to"].getElems():
          toArr.add(t.getStr())
      edgeDefs.add(EdgeDefinition(
        collection: ed{"collection"}.getStr(""),
        fromCollections: fromArr,
        toCollections: toArr,
      ))
  var orphans: seq[string] = @[]
  if gNode.hasKey("orphanCollections"):
    for o in gNode["orphanCollections"].getElems():
      orphans.add(o.getStr())
  result = GraphInfo(
    name: gNode{"name"}.getStr(""),
    edgeDefinitions: edgeDefs,
    orphanCollections: orphans,
    isSmart: gNode{"isSmart"}.getBool(false),
    numberOfShards: gNode{"numberOfShards"}.getInt(1),
    replicationFactor: gNode{"replicationFactor"}.getInt(1),
  )

proc drop*(g: Graph) =
  discard g.db.client.doRequestJson("DELETE", "_api/gharial/" & g.name)

# --- Graph management on Database ---

proc graph*(db: Database, name: string): Graph =
  Graph(db: db, name: name)

proc createGraph*(db: Database, name: string, edgeDefinitions: seq[EdgeDefinition] = @[],
                  orphanCollections: seq[string] = @[]): Graph =
  var body = %*{"name": name}
  if edgeDefinitions.len > 0:
    var edArr = newJArray()
    for ed in edgeDefinitions:
      edArr.add(%*{
        "collection": ed.collection,
        "from": %ed.fromCollections,
        "to": %ed.toCollections,
      })
    body["edgeDefinitions"] = edArr
  if orphanCollections.len > 0:
    body["orphanCollections"] = %orphanCollections

  discard db.client.doRequestJson("POST", "_api/gharial", $body)
  result = Graph(db: db, name: name)

proc graphs*(db: Database): seq[GraphInfo] =
  let j = db.client.doRequestJson("GET", "_api/gharial")
  result = @[]
  for gNode in j{"graphs"}.getElems():
    var edgeDefs: seq[EdgeDefinition] = @[]
    if gNode.hasKey("edgeDefinitions"):
      for ed in gNode["edgeDefinitions"].getElems():
        var fromArr: seq[string] = @[]
        var toArr: seq[string] = @[]
        if ed.hasKey("from"):
          for f in ed["from"].getElems():
            fromArr.add(f.getStr())
        if ed.hasKey("to"):
          for t in ed["to"].getElems():
            toArr.add(t.getStr())
        edgeDefs.add(EdgeDefinition(
          collection: ed{"collection"}.getStr(""),
          fromCollections: fromArr,
          toCollections: toArr,
        ))
    var orphans: seq[string] = @[]
    if gNode.hasKey("orphanCollections"):
      for o in gNode["orphanCollections"].getElems():
        orphans.add(o.getStr())
    result.add(GraphInfo(
      name: gNode{"name"}.getStr(""),
      edgeDefinitions: edgeDefs,
      orphanCollections: orphans,
      isSmart: gNode{"isSmart"}.getBool(false),
      numberOfShards: gNode{"numberOfShards"}.getInt(1),
      replicationFactor: gNode{"replicationFactor"}.getInt(1),
    ))

# --- Vertex & Edge collections ---

proc createVertexCollection*(g: Graph, name: string): Collection =
  var body = newJObject()
  body["collection"] = %name
  discard g.db.client.doRequestJson("POST", "_api/gharial/" & g.name & "/vertex", $body)
  result = Collection(db: g.db, name: name)

proc createEdgeCollection*(g: Graph, name: string, fromCols, toCols: seq[string]): Collection =
  var body = newJObject()
  body["collection"] = %name
  body["from"] = %fromCols
  body["to"] = %toCols
  discard g.db.client.doRequestJson("POST", "_api/gharial/" & g.name & "/edge", $body)
  result = Collection(db: g.db, name: name)

# --- Traversal ---

proc traversal*[T](g: Graph, startVertex: string, optsArgs: varargs[TraverseOpt]): Cursor[T] =
  var cfg = TraverseConfig()
  for opt in optsArgs:
    opt(cfg)

  let aql = &"""
    FOR v, e, p IN {cfg.minDepth}..{cfg.maxDepth} {cfg.direction}
    '{startVertex}'
    GRAPH '{g.name}'
    RETURN v
  """.strip().replace("\n", " ")

  let q = g.db.query(aql)
  result = q.exec[T](g.db)
