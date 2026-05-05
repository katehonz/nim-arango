## Core types for nim-arango.
##
## Central type definitions to avoid circular imports between modules.

import std/[json, tables, options]
import transport, auth, options

type
  Client* = ref object
    transport*: Transport
    auth*: Authenticator
    cfg*: ClientConfig

  Database* = ref object
    client*: Client
    name*: string

  CollectionType* = enum
    colDocument = 2
    colEdge = 3

  Collection* = ref object
    db*: Database
    name*: string

  DocumentMeta* = object
    key*: string
    id*: string
    rev*: string

  Document*[T] = object
    meta*: DocumentMeta
    data*: T

  DocumentResult*[T] = object
    meta*: DocumentMeta
    doc*: T
    old*: Option[T]
    newDoc*: Option[T]

  VersionInfo* = object
    server*: string
    license*: string
    version*: string

  DatabaseInfo* = object
    name*: string
    id*: string
    path*: string
    isSystem*: bool

  CollectionProperties* = object
    name*: string
    waitForSync*: bool
    journalSize*: int64
    replicationFactor*: int
    writeConcern*: int
    numberOfShards*: int
    shardKeys*: seq[string]
    status*: int
    `type`*: CollectionType

  CollectionInfo* = object
    name*: string
    id*: string
    status*: int
    `type`*: CollectionType
    isSystem*: bool

  # Forward declarations for future modules
  Graph* = ref object
    db*: Database
    name*: string

  View* = ref object of RootObj
    db*: Database
    name*: string

  IndexType* = enum
    idxPersistent, idxTTL, idxGeo, idxFulltext, idxZKD, idxInverted, idxPrimary, idxEdge, idxHash, idxSkiplist

  IndexInfo* = object
    id*: string
    `type`*: string
    name*: string
    fields*: seq[string]
    unique*: bool
    sparse*: bool

  ViewInfo* = object
    name*: string
    id*: string
    `type`*: string

  Query* = ref object
    db*: Database
    aql*: string
    bindVars*: Table[string, JsonNode]
    opts*: Table[string, JsonNode]

  Cursor*[T] = ref object
    db*: Database
    id*: string
    count*: int64
    items*: seq[JsonNode]
    hasMore*: bool
    pos*: int
    error*: ref CatchableError

  Transaction* = ref object
    id*: string
    db*: Database

  # Options objects for future use
  WriteConfigObj* = object
    returnNew*: bool
    returnOld*: bool
    waitForSync*: bool
    silent*: bool
    keepNull*: bool
    mergeObjects*: bool
    ignoreRevs*: bool
    overwriteMode*: string
    revision*: string
    ifMatch*: string
