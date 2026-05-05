## Functional options pattern for nim-arango.
##
## Provides a fluent, type-safe way to configure clients, documents, queries, etc.

import std/[times, tables, json]
import auth

type
  ClientConfig* = object
    endpoints*: seq[string]
    timeout*: int = 30000
    userAgent*: string = "nim-arango-driver/0.1.0"
    auth*: Authenticator
    driverInfo*: string
    maxRetries*: int = 3
    initialBackoffMs*: int = 200
    maxBackoffMs*: int = 5000
    backoffFactor*: float = 2.0
    retryOn*: seq[int]

  ClientOption* = proc(cfg: var ClientConfig)

  WriteConfig* = object
    returnNew*: bool
    returnOld*: bool
    waitForSync*: bool
    silent*: bool
    keepNull*: bool = true
    mergeObjects*: bool = true
    ignoreRevs*: bool = true
    overwriteMode*: string
    revision*: string
    ifMatch*: string

  WriteOpt* = proc(cfg: var WriteConfig)

  CreateCollectionConfig* = object
    journalSize*: int64
    replicationFactor*: int
    writeConcern*: int
    waitForSync*: bool
    doCompact*: bool
    isVolatile*: bool
    shardKeys*: seq[string]
    numberOfShards*: int
    isSystem*: bool
    keyOptions*: JsonNode
    schema*: JsonNode

  CreateCollectionOption* = proc(cfg: var CreateCollectionConfig)

proc defaultRetryOn*: seq[int] = @[429, 500, 502, 503, 504]

proc withEndpoint*(endpoint: string): ClientOption =
  proc opt(cfg: var ClientConfig) = cfg.endpoints.add(endpoint)
  opt

proc withEndpoints*(endpoints: varargs[string]): ClientOption =
  proc opt(cfg: var ClientConfig) = cfg.endpoints.add(endpoints)
  opt

proc withBasicAuth*(username, password: string): ClientOption =
  proc opt(cfg: var ClientConfig) = cfg.auth = newBasicAuth(username, password)
  opt

proc withJwtAuth*(username, password: string): ClientOption =
  proc opt(cfg: var ClientConfig) = cfg.auth = newJwtAuth(username, password)
  opt

proc withRawAuth*(value: string): ClientOption =
  proc opt(cfg: var ClientConfig) = cfg.auth = newRawAuth(value)
  opt

proc withTimeout*(ms: int): ClientOption =
  proc opt(cfg: var ClientConfig) = cfg.timeout = ms
  opt

proc withUserAgent*(ua: string): ClientOption =
  proc opt(cfg: var ClientConfig) = cfg.userAgent = ua
  opt

proc withDriverInfo*(info: string): ClientOption =
  proc opt(cfg: var ClientConfig) = cfg.driverInfo = info
  opt

proc withRetryConfig*(maxRetries: int = 3, initialBackoffMs: int = 200,
                     maxBackoffMs: int = 5000, backoffFactor: float = 2.0): ClientOption =
  proc opt(cfg: var ClientConfig) =
    cfg.maxRetries = maxRetries
    cfg.initialBackoffMs = initialBackoffMs
    cfg.maxBackoffMs = maxBackoffMs
    cfg.backoffFactor = backoffFactor
    cfg.retryOn = defaultRetryOn()
  opt

# --- Write options ---

proc withReturnNew*(): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.returnNew = true
  opt

proc withReturnOld*(): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.returnOld = true
  opt

proc withWaitForSync*(): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.waitForSync = true
  opt

proc withSilent*(): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.silent = true
  opt

proc withKeepNull*(v: bool): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.keepNull = v
  opt

proc withMergeObjects*(v: bool): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.mergeObjects = v
  opt

proc withIgnoreRevs*(): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.ignoreRevs = true
  opt

proc withOverwriteMode*(mode: string): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.overwriteMode = mode
  opt

proc withRevision*(rev: string): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.revision = rev
  opt

proc withIfMatch*(rev: string): WriteOpt =
  proc opt(cfg: var WriteConfig) = cfg.ifMatch = rev
  opt

# --- Collection options ---

proc withJournalSize*(size: int64): CreateCollectionOption =
  proc opt(cfg: var CreateCollectionConfig) = cfg.journalSize = size
  opt

proc withReplicationFactor*(n: int): CreateCollectionOption =
  proc opt(cfg: var CreateCollectionConfig) = cfg.replicationFactor = n
  opt

proc withWriteConcern*(n: int): CreateCollectionOption =
  proc opt(cfg: var CreateCollectionConfig) = cfg.writeConcern = n
  opt

proc withWaitForSyncCollection*(v: bool): CreateCollectionOption =
  proc opt(cfg: var CreateCollectionConfig) = cfg.waitForSync = v
  opt

proc withNumberOfShards*(n: int): CreateCollectionOption =
  proc opt(cfg: var CreateCollectionConfig) = cfg.numberOfShards = n
  opt

proc withShardKeys*(keys: varargs[string]): CreateCollectionOption =
  proc opt(cfg: var CreateCollectionConfig) = cfg.shardKeys = @keys
  opt
