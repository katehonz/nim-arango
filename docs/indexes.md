# Index Management

Create, list, and drop collection indexes. Supports persistent, geo, TTL, inverted, and fulltext indexes.

## IndexType Enum

```nim
type
  IndexType* = enum
    idxPersistent, idxTTL, idxGeo, idxFulltext, idxZKD,
    idxInverted, idxPrimary, idxEdge, idxHash, idxSkiplist
```

## Listing Indexes

```nim
let col = db.createCollection("users")

for idx in col.indexes():
  echo idx.id, " ", idx.`type`, " ", idx.name, " on ", idx.fields
```

## Creating a Persistent Index

```nim
# Simple persistent index
let idx = col.createIndex(idxPersistent, @["email"], withUnique(true))

# With options
let idx = col.createIndex(idxPersistent, @["category", "price"], 
  withIndexName("myIdx"),
  withUnique(false),
  withSparse(true),
  withInBackground(),
  withCacheEnabled(),
)
```

## Geo Index

```nim
let idx = col.createGeoIndex(@["location"], geoJson = true, withIndexName("geo_location"))
```

## TTL Index

```nim
let idx = col.createTTLIndex("createdAt", expireAfter = 3600)  # seconds
```

## Inverted Index (ArangoSearch)

```nim
import std/json

let idx = col.createInvertedIndex(
  fields = %*[
    {"name": "name", "analyzer": "text_en"},
    {"name": "description", "analyzer": "text_en"},
  ],
  analyzer = "identity",
  includeAllFields = false,
  withIndexName("search_fields"),
)
```

## Fulltext Index (Deprecated in 3.10+)

```nim
let idx = col.createFulltextIndex(
  @["description"], 
  minLength = 3, 
  withIndexName("ft_desc"),
)
```

## Index Info & Lookup

```nim
# Check if index exists by name
if col.indexExists("myIdx"):
  echo "found"

# Get a single index by name
let idx = col.getIndex("myIdx")
echo idx.id, " ", idx.fields
```

## Drop Index

```nim
col.dropIndex("idx/12345")
```

## Index Config Options

| Option                  | Type    | Description                              |
|-------------------------|---------|------------------------------------------|
| `withIndexName(name)`   | string  | Custom name for the index                |
| `withUnique(v)`         | bool    | Enforce unique values (default: false)   |
| `withSparse(v)`         | bool    | Only index documents with the field (default: false) |
| `withDeduplicate(v)`    | bool    | Deduplicate array values (default: true) |
| `withInBackground()`    | —       | Build index in background                |
| `withCacheEnabled()`    | —       | Enable in-memory caching for the index   |
| `withAdditional(json)`  | JsonNode| Pass additional index config fields      |

## IndexInfo Type

```nim
type
  IndexInfo* = object
    id*: string
    `type`*: string
    name*: string
    fields*: seq[string]
    unique*: bool
    sparse*: bool
```

## Public API

```nim
# Index management
proc indexes*(col: Collection): seq[IndexInfo]
proc createIndex*(col: Collection, typ: IndexType, fields: seq[string],
                  optsArgs: varargs[CreateIndexOption]): IndexInfo
proc createGeoIndex*(col: Collection, fields: seq[string], geoJson: bool = false,
                     optsArgs: varargs[CreateIndexOption]): IndexInfo
proc createTTLIndex*(col: Collection, field: string, expireAfter: int): IndexInfo
proc createInvertedIndex*(col: Collection, fields: JsonNode,
                          analyzer: string = "identity",
                          includeAllFields: bool = false,
                          optsArgs: varargs[CreateIndexOption]): IndexInfo
proc createFulltextIndex*(col: Collection, fields: seq[string], minLength: int = 0,
                          optsArgs: varargs[CreateIndexOption]): IndexInfo
proc indexExists*(col: Collection, name: string): bool
proc getIndex*(col: Collection, name: string): IndexInfo
proc dropIndex*(col: Collection, id: string)

# Index options
proc withIndexName*(name: string): CreateIndexOption
proc withUnique*(v: bool): CreateIndexOption
proc withSparse*(v: bool): CreateIndexOption
proc withDeduplicate*(v: bool): CreateIndexOption
proc withInBackground*(): CreateIndexOption
proc withCacheEnabled*(): CreateIndexOption
proc withAdditional*(j: JsonNode): CreateIndexOption
```
