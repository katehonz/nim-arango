## View API — ArangoSearch and Search Alias views.

import std/[json, options, strformat]
import client, database, types

type
  CreateViewOption* = proc(cfg: var ViewConfig)

  ViewConfig* = object
    `type`*: string = "arangosearch"
    links*: JsonNode
    primarySort*: JsonNode
    storedValues*: JsonNode

  ArangoSearchViewProperties* = object
    cleanupIntervalStep*: int
    consolidationIntervalMsec*: int64
    consolidationPolicy*: JsonNode
    primarySort*: JsonNode
    storedValues*: JsonNode
    links*: JsonNode

proc withLinks*(links: JsonNode): CreateViewOption =
  proc opt(cfg: var ViewConfig) = cfg.links = links
  opt

proc withPrimarySort*(sort: JsonNode): CreateViewOption =
  proc opt(cfg: var ViewConfig) = cfg.primarySort = sort
  opt

proc withStoredValues*(values: JsonNode): CreateViewOption =
  proc opt(cfg: var ViewConfig) = cfg.storedValues = values
  opt

# --- View management on Database ---

proc createArangoSearchView*(db: Database, name: string, optsArgs: varargs[CreateViewOption]): View =
  var cfg = ViewConfig()
  for opt in optsArgs:
    opt(cfg)

  var body = %*{
    "name": name,
    "type": "arangosearch",
  }
  if cfg.links != nil:
    body["links"] = cfg.links
  if cfg.primarySort != nil:
    body["primarySort"] = cfg.primarySort
  if cfg.storedValues != nil:
    body["storedValues"] = cfg.storedValues

  discard db.client.doRequestJson("POST", "_api/view", $body)
  result = View(db: db, name: name)

proc createSearchAliasView*(db: Database, name: string, indexes: JsonNode): View =
  let body = %*{
    "name": name,
    "type": "search-alias",
    "indexes": indexes,
  }
  discard db.client.doRequestJson("POST", "_api/view", $body)
  result = View(db: db, name: name)

proc views*(db: Database): seq[ViewInfo] =
  let j = db.client.doRequestJson("GET", "_api/view")
  result = @[]
  for node in j{"result"}.getElems():
    result.add(ViewInfo(
      name: node{"name"}.getStr(""),
      id: node{"id"}.getStr(""),
      `type`: node{"type"}.getStr(""),
    ))

# --- View instance methods ---

proc properties*(v: View): ArangoSearchViewProperties =
  let j = v.db.client.doRequestJson("GET", "_api/view/" & v.name & "/properties")
  result = ArangoSearchViewProperties(
    cleanupIntervalStep: j{"cleanupIntervalStep"}.getInt(2),
    consolidationIntervalMsec: j{"consolidationIntervalMsec"}.getInt(1000).int64,
    consolidationPolicy: j{"consolidationPolicy"},
    primarySort: j{"primarySort"},
    storedValues: j{"storedValues"},
    links: j{"links"},
  )

proc setProperties*(v: View, props: ArangoSearchViewProperties) =
  var body = newJObject()
  body["cleanupIntervalStep"] = %props.cleanupIntervalStep
  body["consolidationIntervalMsec"] = %props.consolidationIntervalMsec
  if props.consolidationPolicy != nil:
    body["consolidationPolicy"] = props.consolidationPolicy
  if props.primarySort != nil:
    body["primarySort"] = props.primarySort
  if props.storedValues != nil:
    body["storedValues"] = props.storedValues
  if props.links != nil:
    body["links"] = props.links
  discard v.db.client.doRequestJson("PUT", "_api/view/" & v.name & "/properties", $body)

proc drop*(v: View) =
  discard v.db.client.doRequestJson("DELETE", "_api/view/" & v.name)
