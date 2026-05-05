## Collection API — metadata, management, and CRUD operations.

import std/[json, strutils]
import client, types, options as opts

proc name*(c: Collection): string = c.name

proc count*(c: Collection): int64 =
  let j = c.db.client.doRequestJson("GET", "_api/collection/" & c.name & "/count")
  result = j{"count"}.getInt(0).int64

proc properties*(c: Collection): CollectionProperties =
  let j = c.db.client.doRequestJson("GET", "_api/collection/" & c.name & "/properties")
  result = CollectionProperties(
    name: j{"name"}.getStr(""),
    waitForSync: j{"waitForSync"}.getBool(false),
    journalSize: j{"journalSize"}.getInt(0).int64,
    replicationFactor: j{"replicationFactor"}.getInt(1),
    writeConcern: j{"writeConcern"}.getInt(1),
    numberOfShards: j{"numberOfShards"}.getInt(1),
    shardKeys: @[],
    status: j{"status"}.getInt(0),
    `type`: CollectionType(j{"type"}.getInt(2)),
  )
  if j.hasKey("shardKeys"):
    for k in j["shardKeys"].getElems():
      result.shardKeys.add(k.getStr())

proc truncate*(c: Collection) =
  discard c.db.client.doRequestJson("PUT", "_api/collection/" & c.name & "/truncate")

proc load*(c: Collection) =
  discard c.db.client.doRequestJson("PUT", "_api/collection/" & c.name & "/load")

proc unload*(c: Collection) =
  discard c.db.client.doRequestJson("PUT", "_api/collection/" & c.name & "/unload")

proc rename*(c: Collection, newName: string) =
  var body = %*{"name": newName}
  discard c.db.client.doRequestJson("PUT", "_api/collection/" & c.name & "/rename", $body)
  c.name = newName

proc drop*(c: Collection) =
  discard c.db.client.doRequestJson("DELETE", "_api/collection/" & c.name)

# --- Document helpers ---

proc buildWriteQueryString*(cfg: WriteConfig): string =
  var parts: seq[string]
  if cfg.returnNew: parts.add("returnNew=true")
  if cfg.returnOld: parts.add("returnOld=true")
  if cfg.waitForSync: parts.add("waitForSync=true")
  if cfg.silent: parts.add("silent=true")
  if cfg.keepNull: parts.add("keepNull=true")
  if cfg.mergeObjects: parts.add("mergeObjects=true")
  if cfg.ignoreRevs: parts.add("ignoreRevs=true")
  if cfg.overwriteMode.len > 0: parts.add("overwriteMode=" & cfg.overwriteMode)
  if cfg.revision.len > 0: parts.add("rev=" & cfg.revision)
  if cfg.ifMatch.len > 0: parts.add("ifMatch=" & cfg.ifMatch)
  if parts.len > 0:
    result = "?" & parts.join("&")
  else:
    result = ""

proc parseDocumentMeta*(j: JsonNode): DocumentMeta =
  DocumentMeta(
    key: j{"_key"}.getStr(""),
    id: j{"_id"}.getStr(""),
    rev: j{"_rev"}.getStr(""),
  )
