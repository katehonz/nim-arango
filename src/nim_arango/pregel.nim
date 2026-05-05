## Pregel API — distributed graph analytics.

import std/[json]
import client, types

type
  PregelOption* = proc(cfg: var PregelConfig)

  PregelConfig* = object
    algorithm*: string
    graphName*: string
    vertexCollections*: seq[string]
    edgeCollections*: seq[string]
    params*: JsonNode
    store*: bool = true
    maxGSS*: int = 1000
    threadNumber*: int = 1
    async*: bool = false
    resultField*: string = "result"

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

proc withAlgorithm*(algo: string): PregelOption =
  proc opt(cfg: var PregelConfig) = cfg.algorithm = algo
  opt

proc withGraphName*(name: string): PregelOption =
  proc opt(cfg: var PregelConfig) = cfg.graphName = name
  opt

proc withVertexCollections*(cols: varargs[string]): PregelOption =
  proc opt(cfg: var PregelConfig) = cfg.vertexCollections = @cols
  opt

proc withEdgeCollections*(cols: varargs[string]): PregelOption =
  proc opt(cfg: var PregelConfig) = cfg.edgeCollections = @cols
  opt

proc withParams*(params: JsonNode): PregelOption =
  proc opt(cfg: var PregelConfig) = cfg.params = params
  opt

proc withMaxGSS*(gss: int): PregelOption =
  proc opt(cfg: var PregelConfig) = cfg.maxGSS = gss
  opt

proc withAsync*(async: bool): PregelOption =
  proc opt(cfg: var PregelConfig) = cfg.async = async
  opt

proc withResultField*(field: string): PregelOption =
  proc opt(cfg: var PregelConfig) = cfg.resultField = field
  opt

proc startPregelJob*(db: Database, optsArgs: varargs[PregelOption]): string =
  var cfg = PregelConfig()
  for opt in optsArgs:
    opt(cfg)

  var body = newJObject()
  body["algorithm"] = %cfg.algorithm
  if cfg.graphName.len > 0:
    body["graphName"] = %cfg.graphName
  if cfg.vertexCollections.len > 0:
    body["vertexCollections"] = %cfg.vertexCollections
  if cfg.edgeCollections.len > 0:
    body["edgeCollections"] = %cfg.edgeCollections
  if cfg.params != nil:
    body["params"] = cfg.params
  body["store"] = %cfg.store
  body["maxGSS"] = %cfg.maxGSS
  body["threadNumber"] = %cfg.threadNumber
  body["async"] = %cfg.async
  body["resultField"] = %cfg.resultField

  let j = db.client.doRequestJson("POST", "_api/control_pregel", $body)
  result = j.getStr()

proc getPregelJob*(db: Database, id: string): PregelJobInfo =
  let j = db.client.doRequestJson("GET", "_api/control_pregel/" & id)
  var reports: seq[JsonNode] = @[]
  if j.hasKey("reports"):
    for r in j["reports"].getElems():
      reports.add(r)
  result = PregelJobInfo(
    id: j{"id"}.getStr(""),
    algorithm: j{"algorithm"}.getStr(""),
    created: j{"created"}.getStr(""),
    expires: j{"expires"}.getStr(""),
    ttl: j{"ttl"}.getInt(0),
    state: j{"state"}.getStr(""),
    gss: j{"gss"}.getInt(0),
    totalRuntime: j{"totalRuntime"}.getFloat(0.0),
    startupTime: j{"startupTime"}.getFloat(0.0),
    computationTime: j{"computationTime"}.getFloat(0.0),
    storageTime: j{"storageTime"}.getFloat(0.0),
    reports: reports,
  )

proc cancelPregelJob*(db: Database, id: string) =
  discard db.client.doRequestJson("DELETE", "_api/control_pregel/" & id)

proc listPregelJobs*(db: Database): seq[PregelJobInfo] =
  let j = db.client.doRequestJson("GET", "_api/control_pregel")
  result = @[]
  for node in j.getElems():
    var reports: seq[JsonNode] = @[]
    if node.hasKey("reports"):
      for r in node["reports"].getElems():
        reports.add(r)
    result.add(PregelJobInfo(
      id: node{"id"}.getStr(""),
      algorithm: node{"algorithm"}.getStr(""),
      created: node{"created"}.getStr(""),
      expires: node{"expires"}.getStr(""),
      ttl: node{"ttl"}.getInt(0),
      state: node{"state"}.getStr(""),
      gss: node{"gss"}.getInt(0),
      totalRuntime: node{"totalRuntime"}.getFloat(0.0),
      startupTime: node{"startupTime"}.getFloat(0.0),
      computationTime: node{"computationTime"}.getFloat(0.0),
      storageTime: node{"storageTime"}.getFloat(0.0),
      reports: reports,
    ))
