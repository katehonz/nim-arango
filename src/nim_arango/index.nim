## Index API — create, list, and drop collection indexes.

import std/[json]
import client, types

type
  CreateIndexOption* = proc(cfg: var IndexConfig)

  IndexConfig* = object
    name*: string
    unique*: bool
    sparse*: bool
    deduplicate*: bool = true
    inBackground*: bool
    estimates*: bool = true
    cacheEnabled*: bool
    fields*: seq[string]
    primarySort*: JsonNode
    storedValues*: JsonNode
    additional*: JsonNode

  # Specialized index configs
  GeoIndexConfig* = object
    geoJson*: bool

  TTLIndexConfig* = object
    expireAfter*: int

  InvertedIndexConfig* = object
    primarySort*: JsonNode
    storedValues*: JsonNode
    fields*: JsonNode
    analyzer*: string
    includeAllFields*: bool
    trackListPositions*: bool
    searchField*: bool

proc withIndexName*(name: string): CreateIndexOption =
  proc opt(cfg: var IndexConfig) = cfg.name = name
  opt

proc withUnique*(v: bool): CreateIndexOption =
  proc opt(cfg: var IndexConfig) = cfg.unique = v
  opt

proc withSparse*(v: bool): CreateIndexOption =
  proc opt(cfg: var IndexConfig) = cfg.sparse = v
  opt

proc withDeduplicate*(v: bool): CreateIndexOption =
  proc opt(cfg: var IndexConfig) = cfg.deduplicate = v
  opt

proc withInBackground*(): CreateIndexOption =
  proc opt(cfg: var IndexConfig) = cfg.inBackground = true
  opt

proc withCacheEnabled*(): CreateIndexOption =
  proc opt(cfg: var IndexConfig) = cfg.cacheEnabled = true
  opt

proc withAdditional*(j: JsonNode): CreateIndexOption =
  proc opt(cfg: var IndexConfig) = cfg.additional = j
  opt

proc indexTypeToString*(typ: IndexType): string =
  case typ
  of idxPersistent: "persistent"
  of idxTTL: "ttl"
  of idxGeo: "geo"
  of idxFulltext: "fulltext"
  of idxZKD: "zkd"
  of idxInverted: "inverted"
  of idxPrimary: "primary"
  of idxEdge: "edge"
  of idxHash: "hash"
  of idxSkiplist: "skiplist"

proc indexes*(col: Collection): seq[IndexInfo] =
  let j = col.db.client.doRequestJson("GET", "_api/index?collection=" & col.name)
  result = @[]
  for node in j{"indexes"}.getElems():
    var fields: seq[string] = @[]
    if node.hasKey("fields"):
      for f in node["fields"].getElems():
        fields.add(f.getStr())
    result.add(IndexInfo(
      id: node{"id"}.getStr(""),
      `type`: node{"type"}.getStr(""),
      name: node{"name"}.getStr(""),
      fields: fields,
      unique: node{"unique"}.getBool(false),
      sparse: node{"sparse"}.getBool(false),
    ))

proc createIndex*(col: Collection, typ: IndexType, fields: seq[string],
                  optsArgs: varargs[CreateIndexOption]): IndexInfo =
  var cfg = IndexConfig(fields: fields)
  for opt in optsArgs:
    opt(cfg)

  var body = %*{
    "type": indexTypeToString(typ),
    "fields": %fields,
  }
  if cfg.name.len > 0:
    body["name"] = %cfg.name
  body["unique"] = %cfg.unique
  body["sparse"] = %cfg.sparse
  body["deduplicate"] = %cfg.deduplicate
  if cfg.inBackground:
    body["inBackground"] = %true
  body["estimates"] = %cfg.estimates
  if cfg.cacheEnabled:
    body["cacheEnabled"] = %true
  if cfg.additional != nil:
    for k, v in cfg.additional:
      body[k] = v

  let j = col.db.client.doRequestJson("POST", "_api/index?collection=" & col.name, $body)
  var resultFields: seq[string] = @[]
  if j.hasKey("fields"):
    for f in j["fields"].getElems():
      resultFields.add(f.getStr())
  result = IndexInfo(
    id: j{"id"}.getStr(""),
    `type`: j{"type"}.getStr(""),
    name: j{"name"}.getStr(""),
    fields: resultFields,
    unique: j{"unique"}.getBool(false),
    sparse: j{"sparse"}.getBool(false),
  )

proc dropIndex*(col: Collection, id: string) =
  discard col.db.client.doRequestJson("DELETE", "_api/index/" & id)

# --- Specialized index creators ---

proc createGeoIndex*(col: Collection, fields: seq[string], geoJson: bool = false,
                     optsArgs: varargs[CreateIndexOption]): IndexInfo =
  var cfg = IndexConfig(fields: fields)
  for opt in optsArgs:
    opt(cfg)

  var body = %*{
    "type": "geo",
    "fields": %fields,
    "geoJson": %geoJson,
  }
  if cfg.name.len > 0:
    body["name"] = %cfg.name
  let j = col.db.client.doRequestJson("POST", "_api/index?collection=" & col.name, $body)
  var resultFields: seq[string] = @[]
  if j.hasKey("fields"):
    for f in j["fields"].getElems():
      resultFields.add(f.getStr())
  result = IndexInfo(
    id: j{"id"}.getStr(""),
    `type`: j{"type"}.getStr(""),
    name: j{"name"}.getStr(""),
    fields: resultFields,
    unique: j{"unique"}.getBool(false),
    sparse: j{"sparse"}.getBool(false),
  )

proc createTTLIndex*(col: Collection, field: string, expireAfter: int): IndexInfo =
  let body = %*{
    "type": "ttl",
    "fields": %[field],
    "expireAfter": expireAfter,
  }
  let j = col.db.client.doRequestJson("POST", "_api/index?collection=" & col.name, $body)
  result = IndexInfo(
    id: j{"id"}.getStr(""),
    `type`: j{"type"}.getStr(""),
    name: j{"name"}.getStr(""),
    fields: @[field],
    unique: false,
    sparse: false,
  )

proc indexExists*(col: Collection, name: string): bool =
  ## Check if an index exists by name.
  try:
    let j = col.db.client.doRequestJson("GET", "_api/index/" & col.name & "/" & name)
    result = j.hasKey("id") and j{"id"}.getStr("").len > 0
  except CatchableError:
    result = false

proc getIndex*(col: Collection, name: string): IndexInfo =
  ## Get a single index by name.
  let j = col.db.client.doRequestJson("GET", "_api/index/" & col.name & "/" & name)
  var fields: seq[string] = @[]
  if j.hasKey("fields"):
    for f in j["fields"].getElems():
      fields.add(f.getStr())
  result = IndexInfo(
    id: j{"id"}.getStr(""),
    `type`: j{"type"}.getStr(""),
    name: j{"name"}.getStr(""),
    fields: fields,
    unique: j{"unique"}.getBool(false),
    sparse: j{"sparse"}.getBool(false),
  )

proc createInvertedIndex*(col: Collection, fields: JsonNode,
                          analyzer: string = "identity",
                          includeAllFields: bool = false,
                          optsArgs: varargs[CreateIndexOption]): IndexInfo =
  ## Create an inverted index for ArangoSearch.
  var cfg = IndexConfig()
  for opt in optsArgs:
    opt(cfg)

  var body = %*{
    "type": "inverted",
    "fields": fields,
    "analyzer": analyzer,
    "includeAllFields": includeAllFields,
  }
  if cfg.name.len > 0:
    body["name"] = %cfg.name
  if cfg.primarySort != nil:
    body["primarySort"] = cfg.primarySort
  if cfg.storedValues != nil:
    body["storedValues"] = cfg.storedValues

  let j = col.db.client.doRequestJson("POST", "_api/index?collection=" & col.name, $body)
  var resultFields: seq[string] = @[]
  if j.hasKey("fields"):
    for f in j["fields"].getElems():
      resultFields.add(f.getStr())
  result = IndexInfo(
    id: j{"id"}.getStr(""),
    `type`: j{"type"}.getStr(""),
    name: j{"name"}.getStr(""),
    fields: resultFields,
    unique: false,
    sparse: false,
  )

proc createFulltextIndex*(col: Collection, fields: seq[string], minLength: int = 0,
                          optsArgs: varargs[CreateIndexOption]): IndexInfo =
  ## Create a fulltext index (deprecated in 3.10+, use inverted index instead).
  var cfg = IndexConfig(fields: fields)
  for opt in optsArgs:
    opt(cfg)

  var body = %*{
    "type": "fulltext",
    "fields": %fields,
  }
  if minLength > 0:
    body["minLength"] = %minLength
  if cfg.name.len > 0:
    body["name"] = %cfg.name

  let j = col.db.client.doRequestJson("POST", "_api/index?collection=" & col.name, $body)
  var resultFields: seq[string] = @[]
  if j.hasKey("fields"):
    for f in j["fields"].getElems():
      resultFields.add(f.getStr())
  result = IndexInfo(
    id: j{"id"}.getStr(""),
    `type`: j{"type"}.getStr(""),
    name: j{"name"}.getStr(""),
    fields: resultFields,
    unique: false,
    sparse: false,
  )
