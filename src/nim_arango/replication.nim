## Replication API.

import std/[json]
import client, types

type
  ReplicationApplierConfig* = object
    endpoint*: string
    database*: string
    username*: string
    password*: string
    maxConnectRetries*: int
    connectTimeout*: int
    requestTimeout*: int
    chunkSize*: int
    autoStart*: bool
    adaptivePolling*: bool
    autoResync*: bool
    includeSystem*: bool
    requireFromPresent*: bool
    idleMinWaitTime*: int
    idleMaxWaitTime*: int
    verbose*: bool

  ReplicationApplierState* = object
    state*: string
    lastProcessedContinuousTick*: string
    lastAppliedContinuousTick*: string
    lastAvailableContinuousTick*: string
    safeLastAppliedContinuousTick*: string
    synced*: bool
    totalRequests*: int64
    totalFailedConnects*: int64
    totalEvents*: int64
    totalOperationsExcluded*: int64
    progress*: JsonNode
    lastError*: JsonNode
    time*: string

proc replicationMakeFollower*(c: Client, endpoint: string, database: string = "",
                              username: string = "", password: string = "",
                              verbose: bool = false): JsonNode =
  var body = %*{
    "endpoint": endpoint,
    "verbose": verbose,
  }
  if database.len > 0: body["database"] = %database
  if username.len > 0: body["username"] = %username
  if password.len > 0: body["password"] = %password
  result = c.doRequestJson("PUT", "_api/replication/makeFollower", $body)

proc replicationLoggerState*(c: Client): JsonNode =
  result = c.doRequestJson("GET", "_api/replication/logger-state")

proc replicationApplierState*(c: Client): ReplicationApplierState =
  let j = c.doRequestJson("GET", "_api/replication/applier-state")
  let state = j{"state"}
  result = ReplicationApplierState(
    state: state{"state"}.getStr(""),
    lastProcessedContinuousTick: state{"lastProcessedContinuousTick"}.getStr(""),
    lastAppliedContinuousTick: state{"lastAppliedContinuousTick"}.getStr(""),
    lastAvailableContinuousTick: state{"lastAvailableContinuousTick"}.getStr(""),
    safeLastAppliedContinuousTick: state{"safeLastAppliedContinuousTick"}.getStr(""),
    synced: state{"synced"}.getBool(false),
    totalRequests: state{"totalRequests"}.getInt(0).int64,
    totalFailedConnects: state{"totalFailedConnects"}.getInt(0).int64,
    totalEvents: state{"totalEvents"}.getInt(0).int64,
    totalOperationsExcluded: state{"totalOperationsExcluded"}.getInt(0).int64,
    progress: state{"progress"},
    lastError: state{"lastError"},
    time: state{"time"}.getStr(""),
  )

proc replicationApplierStart*(c: Client, fromTick: string = ""): JsonNode =
  var body = newJObject()
  if fromTick.len > 0:
    body["from"] = %fromTick
  result = c.doRequestJson("PUT", "_api/replication/applier-start", $body)

proc replicationApplierStop*(c: Client): JsonNode =
  result = c.doRequestJson("PUT", "_api/replication/applier-stop")

proc replicationInventory*(c: Client, includeSystem: bool = false, global: bool = false): JsonNode =
  var path = "_api/replication/inventory?includeSystem=" & $includeSystem
  if global:
    path &= "&global=true"
  result = c.doRequestJson("GET", path)

proc replicationDump*(c: Client, collection: string, fromTick: string = "", chunkSize: int = 0): JsonNode =
  var path = "_api/replication/dump?collection=" & collection
  if fromTick.len > 0: path &= "&from=" & fromTick
  if chunkSize > 0: path &= "&chunkSize=" & $chunkSize
  result = c.doRequestJson("GET", path)

# --- Replication Batch API ---

proc replicationCreateBatch*(c: Client, db: Database, serverId: string, ttl: int = 600): JsonNode =
  ## Create a replication batch to prevent WAL state removal during sync.
  ## serverId: the server ID of the tcp connection endpoint
  ## ttl: time to live for the batch in seconds
  let body = %*{
    "serverId": serverId,
    "ttl": ttl,
  }
  result = c.doRequestJson("POST", "_api/replication/batch", $body)

proc replicationExtendBatch*(c: Client, batchId: string, ttl: int = 600) =
  ## Extend the TTL of a replication batch.
  let body = %*{"ttl": ttl}
  discard c.doRequestJson("PUT", "_api/replication/batch/" & batchId, $body)

proc replicationDeleteBatch*(c: Client, batchId: string) =
  ## Delete a replication batch.
  discard c.doRequestJson("DELETE", "_api/replication/batch/" & batchId)

# --- Replication Sync API ---

proc replicationGetRevisionTree*(c: Client, db: Database, batchId: string,
                                  collection: string): JsonNode =
  ## Retrieve the Merkle revision tree for a collection.
  var path = "_api/replication/revision/tree?collection=" & collection
  if batchId.len > 0:
    path &= "&batchId=" & batchId
  result = c.doRequestJson("GET", path)

proc replicationGetRevisionsByRanges*(c: Client, db: Database, batchId: string,
                                       collection: string,
                                       ranges: seq[(string, string)],
                                       resume: string = ""): JsonNode =
  ## Retrieve revision IDs within specified ranges.
  var body = %*{
    "collection": collection,
    "batchId": batchId,
  }
  var rangesArr = newJArray()
  for r in ranges:
    rangesArr.add(%*[r[0], r[1]])
  body["ranges"] = rangesArr
  if resume.len > 0:
    body["resume"] = %resume
  result = c.doRequestJson("PUT", "_api/replication/revisions/by-ranges", $body)

proc replicationGetRevisionDocuments*(c: Client, db: Database, batchId: string,
                                       collection: string,
                                       revisions: seq[string]): JsonNode =
  ## Retrieve documents by their revision IDs.
  let body = %*{
    "collection": collection,
    "batchId": batchId,
    "revisions": %revisions,
  }
  result = c.doRequestJson("POST", "_api/replication/revisions/tree", $body)
