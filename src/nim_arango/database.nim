## Database API — collections, views, queries, and transactions.

import std/[json, tables]
import client, types, options as opts

proc name*(db: Database): string = db.name

proc info*(db: Database): DatabaseInfo =
  let j = db.client.doRequestJson("GET", "_api/database/current")
  let resultNode = j["result"]
  DatabaseInfo(
    name: resultNode{"name"}.getStr(""),
    id: resultNode{"id"}.getStr(""),
    path: resultNode{"path"}.getStr(""),
    isSystem: resultNode{"isSystem"}.getBool(false),
  )

proc remove*(db: Database) =
  db.client.dropDatabase(db.name)

# --- Collections ---

proc collection*(db: Database, name: string): Collection =
  Collection(db: db, name: name)

proc collections*(db: Database): seq[CollectionInfo] =
  let j = db.client.doRequestJson("GET", "_api/collection")
  result = @[]
  for node in j["result"].getElems():
    result.add(CollectionInfo(
      name: node{"name"}.getStr(""),
      id: node{"id"}.getStr(""),
      status: node{"status"}.getInt(0),
      `type`: CollectionType(node{"type"}.getInt(2)),
      isSystem: node{"isSystem"}.getBool(false),
    ))

proc createCollection*(db: Database, name: string, optsArgs: varargs[CreateCollectionOption]): Collection =
  var cfg = CreateCollectionConfig()
  for opt in optsArgs:
    opt(cfg)

  var body = %*{"name": name}
  if cfg.journalSize > 0:
    body["journalSize"] = %cfg.journalSize
  if cfg.replicationFactor > 0:
    body["replicationFactor"] = %cfg.replicationFactor
  if cfg.writeConcern > 0:
    body["writeConcern"] = %cfg.writeConcern
  body["waitForSync"] = %cfg.waitForSync
  if cfg.numberOfShards > 0:
    body["numberOfShards"] = %cfg.numberOfShards
  if cfg.shardKeys.len > 0:
    body["shardKeys"] = %cfg.shardKeys
  if cfg.keyOptions != nil:
    body["keyOptions"] = cfg.keyOptions
  if cfg.schema != nil:
    body["schema"] = cfg.schema

  discard db.client.doRequestJson("POST", "_api/collection", $body)
  result = Collection(db: db, name: name)

proc dropCollection*(db: Database, name: string) =
  discard db.client.doRequestJson("DELETE", "_api/collection/" & name)

# --- Views ---

proc views*(db: Database): seq[ViewInfo] =
  let j = db.client.doRequestJson("GET", "_api/view")
  result = @[]
  for node in j["result"].getElems():
    result.add(ViewInfo(
      name: node{"name"}.getStr(""),
      id: node{"id"}.getStr(""),
      `type`: node{"type"}.getStr(""),
    ))

# --- Query ---

proc query*(db: Database, aql: string): Query =
  Query(db: db, aql: aql, bindVars: initTable[string, JsonNode](), opts: initTable[string, JsonNode]())

# --- Transaction ---

proc beginTransaction*(db: Database;
                       readCollections: seq[string] = @[];
                       writeCollections: seq[string] = @[];
                       exclusiveCollections: seq[string] = @[];
                       waitForSync: bool = false;
                       allowImplicit: bool = true;
                       lockTimeout: int = 0): Transaction =
  var body = %*{
    "collections": {
      "read": %readCollections,
      "write": %writeCollections,
      "exclusive": %exclusiveCollections,
    },
    "waitForSync": waitForSync,
    "allowImplicit": allowImplicit,
  }
  if lockTimeout > 0:
    body["lockTimeout"] = %lockTimeout

  let j = db.client.doRequestJson("POST", "_api/transaction/begin", $body)
  result = Transaction(id: j{"result"}{"id"}.getStr(""), db: db)

proc commit*(tx: Transaction) =
  discard tx.db.client.doRequestJson("PUT", "_api/transaction/" & tx.id)

proc abort*(tx: Transaction) =
  discard tx.db.client.doRequestJson("DELETE", "_api/transaction/" & tx.id)

proc id*(tx: Transaction): string = tx.id

proc status*(tx: Transaction): string =
  ## Query the status of a streaming transaction ("running", "committed", "aborted").
  let j = tx.db.client.doRequestJson("GET", "_api/transaction/" & tx.id)
  result = j{"result"}{"status"}.getStr("")

proc runningTransactions*(db: Database): seq[JsonNode] =
  ## List all running streaming transactions.
  let j = db.client.doRequestJson("GET", "_api/transaction")
  result = @[]
  if j.hasKey("transactions"):
    for t in j["transactions"].getElems():
      result.add(t)

