## Analyzer API — text analysis for ArangoSearch.

import std/[json, options, strformat]
import client, database, types

type
  AnalyzerOption* = proc(cfg: var AnalyzerConfig)

  AnalyzerConfig* = object
    `type`*: string
    properties*: JsonNode
    features*: seq[string]

  AnalyzerInfo* = object
    name*: string
    `type`*: string
    properties*: JsonNode
    features*: seq[string]

proc withAnalyzerType*(typ: string): AnalyzerOption =
  proc opt(cfg: var AnalyzerConfig) = cfg.`type` = typ
  opt

proc withProperties*(props: JsonNode): AnalyzerOption =
  proc opt(cfg: var AnalyzerConfig) = cfg.properties = props
  opt

proc withFeatures*(features: varargs[string]): AnalyzerOption =
  proc opt(cfg: var AnalyzerConfig) = cfg.features = @features
  opt

proc analyzers*(db: Database): seq[AnalyzerInfo] =
  let j = db.client.doRequestJson("GET", "_api/analyzer")
  result = @[]
  for node in j{"result"}.getElems():
    var features: seq[string] = @[]
    if node.hasKey("features"):
      for f in node["features"].getElems():
        features.add(f.getStr())
    result.add(AnalyzerInfo(
      name: node{"name"}.getStr(""),
      `type`: node{"type"}.getStr(""),
      properties: node{"properties"},
      features: features,
    ))

proc createAnalyzer*(db: Database, name: string, optsArgs: varargs[AnalyzerOption]): AnalyzerInfo =
  var cfg = AnalyzerConfig()
  for opt in optsArgs:
    opt(cfg)

  var body = %*{ "name": name, "type": cfg.`type` }
  if cfg.properties != nil:
    body["properties"] = cfg.properties
  if cfg.features.len > 0:
    body["features"] = %cfg.features

  let j = db.client.doRequestJson("POST", "_api/analyzer", $body)
  var features: seq[string] = @[]
  if j.hasKey("features"):
    for f in j["features"].getElems():
      features.add(f.getStr())
  result = AnalyzerInfo(
    name: j{"name"}.getStr(""),
    `type`: j{"type"}.getStr(""),
    properties: j{"properties"},
    features: features,
  )

proc removeAnalyzer*(db: Database, name: string) =
  discard db.client.doRequestJson("DELETE", "_api/analyzer/" & name)
