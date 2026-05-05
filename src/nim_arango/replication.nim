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
